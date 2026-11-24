<?php
// Database connection settings.
// The real credentials live OUTSIDE the web root and outside Git, in
// /etc/group1-auth/db.ini (created by setup.sh, readable only by root + Apache).
// Nothing secret is stored in this repository.

$iniPath = getenv('GROUP1_DB_INI') ?: '/etc/group1-auth/db.ini';
$cfg = @parse_ini_file($iniPath);
if ($cfg === false) {
    http_response_code(500);
    exit('Database configuration missing. Run setup.sh on the server.');
}

$servername = $cfg['host'] ?? 'localhost';
$username   = $cfg['user'] ?? '';
$password   = $cfg['pass'] ?? '';
$dbname     = $cfg['name'] ?? 'GROUP1';

try {
    $pdo = new PDO(
        "mysql:host=$servername;dbname=$dbname;charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    error_log('DB connection failed: ' . $e->getMessage());
    http_response_code(500);
    exit('Could not connect to the database.');
}

// Secure session cookie settings
if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params([
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => !empty($_SERVER['HTTPS']),
    ]);
    session_start();
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_check(): bool
{
    return isset($_POST['csrf'], $_SESSION['csrf'])
        && hash_equals($_SESSION['csrf'], $_POST['csrf']);
}
