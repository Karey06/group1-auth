-- GROUP1 database schema (matches the assignment guide)
CREATE DATABASE IF NOT EXISTS GROUP1 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE GROUP1;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,          -- bcrypt hash from password_hash()
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
