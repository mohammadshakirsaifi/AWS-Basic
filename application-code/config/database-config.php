<?php
/**
 * Database Configuration for RDS MySQL Connection
 * Task 4: RDS MySQL Setup and Connection
 */

// Database configuration from environment variables or defaults
define('DB_HOST', getenv('RDS_HOSTNAME') ?: 'blog-db.cluster-xxxxxx.us-east-1.rds.amazonaws.com');
define('DB_NAME', getenv('RDS_DATABASE') ?: 'blogdb');
define('DB_USER', getenv('RDS_USERNAME') ?: 'admin');
define('DB_PASSWORD', getenv('RDS_PASSWORD') ?: 'YourSecurePassword123!');
define('DB_PORT', getenv('RDS_PORT') ?: 3306);
define('DB_CHARSET', 'utf8mb4');

/**
 * Get database connection using PDO
 * @return PDO|null
 */
function getDBConnection() {
    try {
        $dsn = sprintf(
            "mysql:host=%s;port=%d;dbname=%s;charset=%s",
            DB_HOST,
            DB_PORT,
            DB_NAME,
            DB_CHARSET
        );
        
        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => 5,
            PDO::MYSQL_ATTR_SSL_CA => '/etc/ssl/certs/rds-ca-2019-root.pem', // RDS SSL certificate
            PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true
        ];
        
        $pdo = new PDO($dsn, DB_USER, DB_PASSWORD, $options);
        
        // Test connection and create tables if needed
        initializeDatabase($pdo);
        
        return $pdo;
        
    } catch (PDOException $e) {
        error_log("Database connection failed: " . $e->getMessage());
        return null;
    }
}

/**
 * Initialize database tables
 * @param PDO $pdo
 */
function initializeDatabase($pdo) {
    // Create posts table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS posts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            content TEXT,
            excerpt TEXT,
            featured_image VARCHAR(500),
            author VARCHAR(100),
            status ENUM('draft', 'published') DEFAULT 'draft',
            views INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            published_at TIMESTAMP NULL,
            INDEX idx_status (status),
            INDEX idx_created (created_at),
            FULLTEXT idx_search (title, content)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
    
    // Create comments table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            author_name VARCHAR(100),
            author_email VARCHAR(255),
            content TEXT,
            status ENUM('pending', 'approved', 'spam') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
            INDEX idx_post_status (post_id, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
    
    // Create visitors table for analytics
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS visitors (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ip_address VARCHAR(45),
            user_agent TEXT,
            page_visited VARCHAR(500),
            referrer VARCHAR(500),
            visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            session_id VARCHAR(100),
            INDEX idx_visit_time (visit_time),
            INDEX idx_ip (ip_address)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
    
    // Insert sample data if table is empty
    $count = $pdo->query("SELECT COUNT(*) FROM posts")->fetchColumn();
    if ($count == 0) {
        insertSampleData($pdo);
    }
}

/**
 * Insert sample blog posts
 * @param PDO $pdo
 */
function insertSampleData($pdo) {
    $samplePosts = [
        [
            'title' => 'Getting Started with AWS Cloud',
            'content' => 'Amazon Web Services (AWS) is the world\'s most comprehensive and broadly adopted cloud platform...',
            'excerpt' => 'Learn the basics of AWS cloud computing',
            'author' => 'Admin',
            'status' => 'published',
            'published_at' => date('Y-m-d H:i:s')
        ],
        [
            'title' => 'Building Scalable Applications on AWS',
            'content' => 'Learn how to build highly scalable applications using AWS services like EC2, ALB, and Auto Scaling...',
            'excerpt' => 'Scale your applications effectively',
            'author' => 'Admin',
            'status' => 'published',
            'published_at' => date('Y-m-d H:i:s', strtotime('-1 day'))
        ],
        [
            'title' => 'AWS Security Best Practices',
            'content' => 'Security is top priority at AWS. Learn about IAM, WAF, KMS, and other security services...',
            'excerpt' => 'Keep your cloud resources secure',
            'author' => 'Security Team',
            'status' => 'published',
            'published_at' => date('Y-m-d H:i:s', strtotime('-2 days'))
        ]
    ];
    
    $stmt = $pdo->prepare("
        INSERT INTO posts (title, content, excerpt, author, status, published_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    
    foreach ($samplePosts as $post) {
        $stmt->execute([
            $post['title'],
            $post['content'],
            $post['excerpt'],
            $post['author'],
            $post['status'],
            $post['published_at']
        ]);
    }
}

/**
 * Log visitor for analytics
 * @param string $page
 */
function logVisitor($page = '/') {
    $pdo = getDBConnection();
    if ($pdo) {
        $stmt = $pdo->prepare("
            INSERT INTO visitors (ip_address, user_agent, page_visited, referrer, session_id)
            VALUES (?, ?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
            $page,
            $_SERVER['HTTP_REFERER'] ?? 'direct',
            session_id()
        ]);
    }
}
?>