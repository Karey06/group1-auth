# GROUP1 – PHP/MySQL Signup & Login

Built from scratch for ICS 3206 Server Administration (PHP MySQL – Gitclone).

- Passwords hashed with `password_hash()` (bcrypt) and checked with `password_verify()`
- PDO prepared statements (no SQL injection), CSRF tokens, `session_regenerate_id()` on login
- DB credentials kept in `/etc/group1-auth/db.ini`, outside the web root and outside Git
- Dedicated least-privilege DB user (`group1_app`: SELECT/INSERT/UPDATE on GROUP1 only)

## Deploy
```bash
cd /var/www/html
sudo git clone https://github.com/<you>/group1-auth.git
cd group1-auth
sudo bash setup.sh
```
Then open `http://<VM-IP>/group1-auth/signup.php`.

## Host on a domain with HTTPS
```bash
sudo bash host_site.sh example.com you@example.com
```
