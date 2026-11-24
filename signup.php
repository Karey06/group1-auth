<?php
require __DIR__ . '/config.php';

$errors = [];
$success = '';
$username = $email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $email    = trim($_POST['email'] ?? '');
    $pass     = $_POST['password'] ?? '';
    $confirm  = $_POST['confirm'] ?? '';

    if (!csrf_check())                                   $errors[] = 'Session expired, please try again.';
    if (!preg_match('/^[A-Za-z0-9_.]{3,50}$/', $username)) $errors[] = 'Username must be 3–50 letters, numbers, _ or .';
    if (!filter_var($email, FILTER_VALIDATE_EMAIL))      $errors[] = 'Enter a valid email address.';
    if (strlen($pass) < 8)                               $errors[] = 'Password must be at least 8 characters.';
    if ($pass !== $confirm)                              $errors[] = 'Passwords do not match.';

    if (!$errors) {
        $stmt = $pdo->prepare('SELECT id FROM users WHERE username = ? OR email = ?');
        $stmt->execute([$username, $email]);
        if ($stmt->fetch()) {
            $errors[] = 'That username or email is already registered.';
        }
    }

    if (!$errors) {
        // Password is hashed with bcrypt (PASSWORD_DEFAULT) — never stored in plain text
        $hash = password_hash($pass, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare('INSERT INTO users (username, password, email) VALUES (?, ?, ?)');
        $stmt->execute([$username, $hash, $email]);
        $success = "Account created for " . $username . ". You can now log in.";
        $username = $email = '';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign up</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="card">
  <h1>Create an account</h1>
  <p class="sub">Server Administration</p>

  <?php foreach ($errors as $err): ?><div class="msg err"><?= e($err) ?></div><?php endforeach; ?>
  <?php if ($success): ?><div class="msg ok"><?= e($success) ?></div><?php endif; ?>

  <form method="post" autocomplete="off">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <label for="username">Username</label>
    <input id="username" name="username" value="<?= e($username) ?>" required>
    <label for="email">Email</label>
    <input id="email" type="email" name="email" value="<?= e($email) ?>" required>
    <label for="password">Password</label>
    <input id="password" type="password" name="password" minlength="8" required>
    <label for="confirm">Confirm password</label>
    <input id="confirm" type="password" name="confirm" minlength="8" required>
    <button type="submit">Sign up</button>
  </form>
  <p class="foot">Already registered? <a href="login.php">Log in</a></p>
</div>
</body>
</html>
