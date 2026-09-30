<?php
$host = getenv('DB_HOST');
$user = getenv('DB_USER');
$pass = getenv('DB_PASSWORD');
$db   = getenv('DB_NAME');

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db", $user, $pass);
    echo "Connected to MySQL successfully!<br>";

    $stmt = $pdo->query("SELECT NOW() as db_time");
    $row = $stmt->fetch();
    echo "Current DB time: " . $row['db_time'];
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}
?>
