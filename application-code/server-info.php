<?php
/**
 * Server Information Script for AWS Blog Application
 * Demonstrates connectivity to AWS services including RDS and instance metadata
 */

header('Content-Type: application/json');

// Database configuration for RDS MySQL
$db_config = [
    'host' => getenv('RDS_HOSTNAME') ?: 'blog-db.cluster-xxxxxx.us-east-1.rds.amazonaws.com',
    'username' => getenv('RDS_USERNAME') ?: 'admin',
    'password' => getenv('RDS_PASSWORD') ?: 'password123',
    'database' => getenv('RDS_DATABASE') ?: 'blogdb',
    'port' => 3306
];

// Initialize response array
$response = [
    'hostname' => gethostname(),
    'server_ip' => $_SERVER['SERVER_ADDR'] ?? 'unknown',
    'client_ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
    'server_time' => date('Y-m-d H:i:s'),
    'php_version' => phpversion(),
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'unknown',
    'load_average' => function_exists('sys_getloadavg') ? sys_getloadavg() : [0,0,0],
    'memory_usage' => memory_get_usage(true),
    'peak_memory' => memory_get_peak_usage(true),
    'disk_free_space' => disk_free_space('/'),
    'disk_total_space' => disk_total_space('/'),
    'aws_region' => get_aws_region(),
    'availability_zone' => get_availability_zone(),
    'instance_id' => get_instance_id(),
    'db_status' => 'Disconnected',
    'db_info' => null,
    'services' => [
        'sns' => check_sns_topic(),
        'sqs' => check_sqs_queue(),
        's3' => check_s3_bucket()
    ]
];

// Test RDS MySQL Connection
try {
    $dsn = sprintf("mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4", 
        $db_config['host'], 
        $db_config['port'], 
        $db_config['database']
    );
    
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_TIMEOUT => 5
    ]);
    
    $response['db_status'] = 'Connected';
    
    // Get database info
    $stmt = $pdo->query("SELECT VERSION() as version");
    $response['db_info'] = [
        'version' => $stmt->fetch()['version'],
        'database' => $db_config['database'],
        'host' => $db_config['host']
    ];
    
    // Create sample table if not exists
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS blog_visits (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ip_address VARCHAR(45),
            user_agent TEXT,
            visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            page_visited VARCHAR(255)
        )
    ");
    
    // Log this visit
    $stmt = $pdo->prepare("
        INSERT INTO blog_visits (ip_address, user_agent, page_visited) 
        VALUES (?, ?, ?)
    ");
    $stmt->execute([
        $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
        $_SERVER['REQUEST_URI'] ?? '/'
    ]);
    
    // Get visit count
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM blog_visits");
    $response['total_visits'] = $stmt->fetch()['count'];
    
} catch (PDOException $e) {
    $response['db_status'] = 'Error: ' . $e->getMessage();
    $response['db_error'] = $e->getCode();
}

/**
 * Get AWS region from instance metadata
 */
function get_aws_region() {
    $region = @file_get_contents('http://169.254.169.254/latest/meta-data/placement/region', false, stream_context_create(['http' => ['timeout' => 2]]));
    return $region ?: 'unknown';
}

/**
 * Get availability zone from instance metadata
 */
function get_availability_zone() {
    $az = @file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone', false, stream_context_create(['http' => ['timeout' => 2]]));
    return $az ?: 'unknown';
}

/**
 * Get instance ID from instance metadata
 */
function get_instance_id() {
    $instance_id = @file_get_contents('http://169.254.169.254/latest/meta-data/instance-id', false, stream_context_create(['http' => ['timeout' => 2]]));
    return $instance_id ?: 'unknown';
}

/**
 * Check SNS topic (simulated)
 */
function check_sns_topic() {
    // In production, use AWS SDK
    return [
        'status' => 'configured',
        'topic_arn' => 'arn:aws:sns:us-east-1:123456789012:Blog-Notifications'
    ];
}

/**
 * Check SQS queue (simulated)
 */
function check_sqs_queue() {
    return [
        'status' => 'configured',
        'queue_url' => 'https://sqs.us-east-1.amazonaws.com/123456789012/Image-Processing-Queue'
    ];
}

/**
 * Check S3 bucket (simulated)
 */
function check_s3_bucket() {
    return [
        'status' => 'configured',
        'bucket_name' => 'blog-static-assets-prod-123456789012'
    ];
}

// Output JSON response
echo json_encode($response, JSON_PRETTY_PRINT);
?>