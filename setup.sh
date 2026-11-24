#!/usr/bin/env bash
# GROUP1 – PHP/MySQL signup & login setup
# Run on the VM from inside the cloned repo:   sudo bash setup.sh
# Works on CentOS/Rocky/RHEL (dnf) and Ubuntu/Debian (apt).
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="GROUP1"
DB_USER="group1_app"
CONF_DIR="/etc/group1-auth"

shot() { echo; echo "📸 ==== SCREENSHOT $1: $2 ===="; echo; }

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash setup.sh"; exit 1; }

# ---------- 1. Detect distro ----------
if command -v dnf >/dev/null; then
    PM=dnf; WEB_SVC=httpd; WEB_USER=apache
    PKGS="httpd mariadb-server php php-mysqlnd php-cli git"
else
    PM=apt; WEB_SVC=apache2; WEB_USER=www-data
    PKGS="apache2 mariadb-server php php-mysql libapache2-mod-php git"
    apt-get update -y
fi
. /etc/os-release
echo "Detected: $PRETTY_NAME (package manager: $PM)"

# ---------- 2. LAMP prerequisites ----------
$PM install -y $PKGS
systemctl enable --now "$WEB_SVC" mariadb
if command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http --add-service=https
    firewall-cmd --reload
fi
shot 1 "LAMP stack + git versions"
git --version; php -v | head -1; mysql --version
systemctl --no-pager status "$WEB_SVC" mariadb | grep -E "●|Active:"

# ---------- 3. Database, table and dedicated DB user ----------
if [[ -f "$CONF_DIR/db.ini" ]]; then   # re-run: keep existing password
    DB_PASS="$(sed -n 's/^pass = "\(.*\)"$/\1/p' "$CONF_DIR/db.ini")"
else
    DB_PASS="$(openssl rand -hex 12)"
fi
mysql < "$APP_DIR/schema.sql"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
          ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
          GRANT SELECT, INSERT, UPDATE ON $DB_NAME.* TO '$DB_USER'@'localhost';
          FLUSH PRIVILEGES;"
shot 2 "Database GROUP1 and users table"
mysql -e "SHOW DATABASES; USE $DB_NAME; SHOW TABLES; DESCRIBE users;"

# ---------- 4. Credentials stored OUTSIDE the web root ----------
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/db.ini" <<EOF
host = localhost
name = $DB_NAME
user = $DB_USER
pass = "$DB_PASS"
EOF
chown root:"$WEB_USER" "$CONF_DIR" "$CONF_DIR/db.ini"
chmod 750 "$CONF_DIR"; chmod 640 "$CONF_DIR/db.ini"
shot 3 "Credentials file permissions (password NOT shown)"
ls -ld "$CONF_DIR"; ls -l "$CONF_DIR/db.ini"
grep -v '^pass' "$CONF_DIR/db.ini"; echo "pass = ********  (hidden)"

# ---------- 5. Permissions / SELinux for the app ----------
chown -R root:"$WEB_USER" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;
chmod 700 "$APP_DIR/setup.sh" "$APP_DIR/host_site.sh" 2>/dev/null || true
# Block web access to .git, .sql and .sh files
cat > "$APP_DIR/.htaccess" <<'EOF'
<FilesMatch "\.(sql|sh|ini|md)$">
    Require all denied
</FilesMatch>
RedirectMatch 404 /\.git
EOF
if command -v getenforce >/dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
    restorecon -R "$APP_DIR" "$CONF_DIR"
fi
# allow .htaccess in /var/www/html
if [[ $PM == dnf ]]; then
    cat > /etc/httpd/conf.d/group1.conf <<EOF
<Directory "$APP_DIR">
    AllowOverride All
    Options -Indexes
</Directory>
EOF
else
    cat > /etc/apache2/conf-available/group1.conf <<EOF
<Directory "$APP_DIR">
    AllowOverride All
    Options -Indexes
</Directory>
EOF
    a2enconf group1 >/dev/null
fi
systemctl restart "$WEB_SVC"

# ---------- 6. Smoke test ----------
URL_PATH="${APP_DIR#/var/www/html}"
IP="$(curl -s --max-time 4 ifconfig.me || hostname -I | awk '{print $1}')"
shot 4 "App files in /var/www/html and HTTP check"
ls -la "$APP_DIR"
curl -s -o /dev/null -w "signup.php -> HTTP %{http_code}\n" "http://localhost$URL_PATH/signup.php"
curl -s -o /dev/null -w "login.php  -> HTTP %{http_code}\n" "http://localhost$URL_PATH/login.php"

echo
echo "✅ Done. Open in your browser:"
echo "   Sign up:  http://$IP$URL_PATH/signup.php"
echo "   Log in:   http://$IP$URL_PATH/login.php"
echo
echo "After every group member signs up, show the stored hashes with:"
echo "   sudo mysql -e \"SELECT id, username, email, LEFT(password,30) AS password_hash, created_at FROM GROUP1.users;\""
