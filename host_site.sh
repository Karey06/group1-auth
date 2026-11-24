#!/usr/bin/env bash
# Host the GROUP1 app on your own domain with HTTPS (Let's Encrypt).
# Usage (on the Azure VM, from inside the cloned repo, after setup.sh):
#     sudo bash host_site.sh example.com you@strathmore.edu
# Before running: the domain's A record (example.com -> VM public IP) and
# CNAME (www -> example.com) must already exist, and the Azure NSG must allow
# inbound TCP 80 and 443.
set -euo pipefail

DOMAIN="${1:?Usage: sudo bash host_site.sh <domain> <email>}"
EMAIL="${2:?Usage: sudo bash host_site.sh <domain> <email>}"
SRC="$(cd "$(dirname "$0")" && pwd)"
WEBROOT="/var/www/$DOMAIN"

shot() { echo; echo "📸 ==== SCREENSHOT $1: $2 ===="; echo; }
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

if command -v dnf >/dev/null; then
    PM=dnf; WEB_SVC=httpd; WEB_USER=apache
    VHOST="/etc/httpd/conf.d/$DOMAIN.conf"
    dnf install -y bind-utils mod_ssl epel-release
    dnf install -y certbot python3-certbot-apache
else
    PM=apt; WEB_SVC=apache2; WEB_USER=www-data
    VHOST="/etc/apache2/sites-available/$DOMAIN.conf"
    apt-get update -y
    apt-get install -y dnsutils certbot python3-certbot-apache
fi

# ---------- 1. DNS check ----------
PUBIP="$(curl -s --max-time 5 ifconfig.me || true)"
shot 1 "nslookup – domain resolves to this server ($PUBIP)"
nslookup "$DOMAIN"
nslookup "www.$DOMAIN"
RESOLVED="$(dig +short "$DOMAIN" A | tail -1)"
if [[ -n "$PUBIP" && "$RESOLVED" != "$PUBIP" ]]; then
    echo "⚠️  $DOMAIN resolves to '$RESOLVED' but this VM's public IP is '$PUBIP'."
    echo "    Fix the A record and wait for DNS to update before continuing."
    exit 1
fi

# ---------- 2. Copy site to its own web root ----------
mkdir -p "$WEBROOT"
rsync -a --exclude '.git' --exclude '*.sh' --exclude '*.sql' "$SRC/" "$WEBROOT/"
chown -R root:"$WEB_USER" "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} \;
find "$WEBROOT" -type f -exec chmod 644 {} \;
command -v restorecon >/dev/null && restorecon -R "$WEBROOT" || true

# ---------- 3. Virtual host ----------
cat > "$VHOST" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin $EMAIL
    DocumentRoot $WEBROOT
    DirectoryIndex index.php
    <Directory $WEBROOT>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR:-/var/log/httpd}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR:-/var/log/httpd}/$DOMAIN-access.log combined
</VirtualHost>
EOF
if [[ $PM == dnf ]]; then
    sed -i "s#\${APACHE_LOG_DIR:-/var/log/httpd}#/var/log/httpd#g" "$VHOST"
else
    sed -i "s#\${APACHE_LOG_DIR:-/var/log/httpd}#\${APACHE_LOG_DIR}#g" "$VHOST"
    a2enmod rewrite ssl headers >/dev/null
    a2ensite "$DOMAIN.conf" >/dev/null
    a2dissite 000-default.conf >/dev/null || true
fi
if command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http --add-service=https; firewall-cmd --reload
fi
if command -v ufw >/dev/null && ufw status | grep -q active; then ufw allow 'Apache Full'; fi

shot 2 "Virtual host config + syntax check"
cat "$VHOST"
if [[ $PM == dnf ]]; then httpd -t; else apache2ctl configtest; fi
systemctl reload "$WEB_SVC"
ls -la "$WEBROOT"

# ---------- 4. Let's Encrypt SSL + HTTP->HTTPS redirect ----------
certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" \
        -m "$EMAIL" --agree-tos --no-eff-email --redirect -n

shot 3 "Certificate issued (valid ~90 days) + auto-renew"
certbot certificates
systemctl list-timers | grep -i certbot || echo "(renewal handled by certbot cron/timer)"
certbot renew --dry-run

shot 4 "HTTP redirects to HTTPS"
curl -sI "http://$DOMAIN" | head -3
curl -sI "https://$DOMAIN/login.php" | head -1

echo
echo "✅ Live at: https://$DOMAIN   (open it in Chrome and screenshot the padlock)"
