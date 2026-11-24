<?php
require __DIR__ . '/config.php';

$error = '';
$login = '';

if (!empty($_SESSION['user_id'])) {
    header('Location: dashboard.php');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $login = trim($_POST['login'] ?? '');
    $pass  = $_POST['password'] ?? '';

    if (!csrf_check()) {
        $error = 'Session expired, please try again.';
    } else {
        $stmt = $pdo->prepare('SELECT id, username, password FROM users WHERE username = ? OR email = ?');
        $stmt->execute([$login, $login]);
        $user = $stmt->fetch();

        // password_verify() compares the typed password against the stored bcrypt hash
        if ($user && password_verify($pass, $user['password'])) {
            session_regenerate_id(true);
            $_SESSION['user_id']  = $user['id'];
            $_SESSION['username'] = $user['username'];

            if (password_needs_rehash($user['password'], PASSWORD_DEFAULT)) {
                $pdo->prepare('UPDATE users SET password = ? WHERE id = ?')
                    ->execute([password_hash($pass, PASSWORD_DEFAULT), $user['id']]);
            }
            header('Location: dashboard.php');
            exit;
        }
        $error = 'Invalid username/email or password.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Log in – GROUP1</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="card">
  <h1>Log in</h1>
  <p class="sub">GROUP1 · Server Administration</p>
  <?php if ($error): ?><div class="msg err"><?= e($error) ?></div><?php endif; ?>
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <label for="login">Username or email</label>
    <input id="login" name="login" value="<?= e($login) ?>" required>
    <label for="password">Password</label>
    <input id="password" type="password" name="password" required>
    <button type="submit">Log in</button>
  </form>
  <p class="foot">No account? <a href="signup.php">Sign up</a></p>
</div>
</body>
</html>
