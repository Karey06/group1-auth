<?php
require __DIR__ . '/config.php';

if (empty($_SESSION['user_id'])) {
    header('Location: login.php');
    exit;
}

// List registered group members (no password hashes shown)
$members = $pdo->query('SELECT id, username, email, created_at FROM users ORDER BY id')->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashboard</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="card wide">
  <div class="top">
    <h1>Welcome, <?= e($_SESSION['username']) ?> 👋</h1>
    <a href="logout.php">Log out</a>
  </div>
  <div class="msg ok" style="margin-top:14px">Login successful — your password was verified with password_verify().</div>
  <h3>Registered group members (<?= count($members) ?>)</h3>
  <table>
    <tr><th>#</th><th>Username</th><th>Email</th><th>Registered</th></tr>
    <?php foreach ($members as $m): ?>
    <tr><td><?= (int)$m['id'] ?></td><td><?= e($m['username']) ?></td><td><?= e($m['email']) ?></td><td><?= e($m['created_at']) ?></td></tr>
    <?php endforeach; ?>
  </table>
</div>
</body>
</html>
