<?php
/**
 * NotifyHub REST API
 * 
 * This PHP script provides a REST API for the NotifyHub Flutter app.
 * It handles API key registration and FCM push notification sending.
 * 
 * Endpoints:
 * - POST /api.php?action=register - Register a device and get an API key
 * - POST /api.php?action=send - Send a push notification
 * - GET /api.php?action=message - Send a push notification (GET method)
 * 
 * Configuration:
 * - Set NOTIFYHUB_SECRET_KEY environment variable or update the constant below
 * - Set FCM_SERVICE_ACCOUNT_JSON environment variable or update the path below
 */

// Enable CORS for API access
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Secret-Key, Authorization');
header('Content-Type: application/json');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Configuration
define('SECRET_KEY', getenv('NOTIFYHUB_SECRET_KEY') ?: 'your-secret-key-here');
define('FCM_SERVICE_ACCOUNT_PATH', getenv('FCM_SERVICE_ACCOUNT_JSON') ?: __DIR__ . '/firebase-service-account.json');
define('SQLITE_DB_PATH', __DIR__ . '/notifyhub.db');

/**
 * Send JSON response
 */
function sendResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode($data);
    exit();
}

/**
 * Send error response
 */
function sendError($message, $statusCode = 400) {
    sendResponse(['success' => false, 'error' => $message], $statusCode);
}

/**
 * Validate secret key from request headers or query parameters
 */
function validateSecretKey() {
    $secretKey = null;
    
    // Check header first
    $headers = getallheaders();
    if (isset($headers['X-Secret-Key'])) {
        $secretKey = $headers['X-Secret-Key'];
    } elseif (isset($headers['x-secret-key'])) {
        $secretKey = $headers['x-secret-key'];
    }
    
    // Fall back to query parameter
    if (!$secretKey && isset($_GET['secret'])) {
        $secretKey = $_GET['secret'];
    }
    
    // Fall back to POST parameter
    if (!$secretKey && isset($_POST['secret'])) {
        $secretKey = $_POST['secret'];
    }
    
    if (!$secretKey || $secretKey !== SECRET_KEY) {
        sendError('Invalid or missing secret key', 401);
    }
    
    return true;
}

/**
 * Get SQLite database connection
 */
function getDatabase() {
    static $db = null;
    
    if ($db === null) {
        try {
            $db = new PDO('sqlite:' . SQLITE_DB_PATH);
            $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
            
            // Create devices table if it doesn't exist
            $db->exec('
                CREATE TABLE IF NOT EXISTS devices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    fcm_token TEXT UNIQUE NOT NULL,
                    api_key TEXT UNIQUE NOT NULL,
                    device_info TEXT,
                    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            ');
            
            // Create index on api_key for faster lookups
            $db->exec('CREATE INDEX IF NOT EXISTS idx_api_key ON devices(api_key)');
            
        } catch (PDOException $e) {
            sendError('Database connection failed: ' . $e->getMessage(), 500);
        }
    }
    
    return $db;
}

/**
 * Generate a unique API key
 */
function generateApiKey() {
    return 'API-' . strtoupper(bin2hex(random_bytes(12)));
}

/**
 * Find device by FCM token
 */
function findDeviceByFcmToken($fcmToken) {
    $db = getDatabase();
    $stmt = $db->prepare('SELECT * FROM devices WHERE fcm_token = :fcm_token');
    $stmt->execute([':fcm_token' => $fcmToken]);
    return $stmt->fetch();
}

/**
 * Find device by API key
 */
function findDeviceByApiKey($apiKey) {
    $db = getDatabase();
    $stmt = $db->prepare('SELECT * FROM devices WHERE api_key = :api_key');
    $stmt->execute([':api_key' => $apiKey]);
    return $stmt->fetch();
}

/**
 * Register a new device
 */
function registerDevice($fcmToken, $apiKey, $deviceInfo) {
    $db = getDatabase();
    $stmt = $db->prepare('
        INSERT INTO devices (fcm_token, api_key, device_info) 
        VALUES (:fcm_token, :api_key, :device_info)
    ');
    return $stmt->execute([
        ':fcm_token' => $fcmToken,
        ':api_key' => $apiKey,
        ':device_info' => $deviceInfo
    ]);
}

/**
 * Update device FCM token
 */
function updateDeviceFcmToken($apiKey, $newFcmToken) {
    $db = getDatabase();
    $stmt = $db->prepare('
        UPDATE devices 
        SET fcm_token = :fcm_token, updated_at = CURRENT_TIMESTAMP 
        WHERE api_key = :api_key
    ');
    return $stmt->execute([
        ':fcm_token' => $newFcmToken,
        ':api_key' => $apiKey
    ]);
}

/**
 * Get OAuth2 access token from service account
 */
function getAccessToken() {
    if (!file_exists(FCM_SERVICE_ACCOUNT_PATH)) {
        return null;
    }
    
    $serviceAccount = json_decode(file_get_contents(FCM_SERVICE_ACCOUNT_PATH), true);
    
    if (!$serviceAccount) {
        return null;
    }
    
    // Create JWT header
    $header = base64_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    
    // Create JWT claim set
    $now = time();
    $claims = [
        'iss' => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600
    ];
    $claimsEncoded = base64_encode(json_encode($claims));
    
    // Create signature
    $signatureInput = str_replace(['+', '/', '='], ['-', '_', ''], $header) . '.' . 
                      str_replace(['+', '/', '='], ['-', '_', ''], $claimsEncoded);
    
    $privateKey = openssl_pkey_get_private($serviceAccount['private_key']);
    if (!$privateKey) {
        return null;
    }
    
    openssl_sign($signatureInput, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    $signatureEncoded = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
    
    $jwt = $signatureInput . '.' . $signatureEncoded;
    
    // Exchange JWT for access token
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt
    ]));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode !== 200) {
        return null;
    }
    
    $tokenData = json_decode($response, true);
    return $tokenData['access_token'] ?? null;
}

/**
 * Send FCM notification using HTTP v1 API
 */
function sendFcmNotification($fcmToken, $title, $body, $data = []) {
    // Get service account for project ID
    if (!file_exists(FCM_SERVICE_ACCOUNT_PATH)) {
        return ['success' => false, 'error' => 'FCM service account not configured'];
    }
    
    $serviceAccount = json_decode(file_get_contents(FCM_SERVICE_ACCOUNT_PATH), true);
    if (!$serviceAccount || !isset($serviceAccount['project_id'])) {
        return ['success' => false, 'error' => 'Invalid service account configuration'];
    }
    
    $projectId = $serviceAccount['project_id'];
    
    // Get access token
    $accessToken = getAccessToken();
    if (!$accessToken) {
        return ['success' => false, 'error' => 'Failed to obtain access token'];
    }
    
    // Build FCM message
    $message = [
        'message' => [
            'token' => $fcmToken,
            'notification' => [
                'title' => $title,
                'body' => $body
            ]
        ]
    ];
    
    // Add custom data if provided
    if (!empty($data)) {
        $message['message']['data'] = array_map('strval', $data);
    }
    
    // Send to FCM HTTP v1 API
    $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $accessToken
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        return ['success' => false, 'error' => 'CURL error: ' . $error];
    }
    
    if ($httpCode >= 200 && $httpCode < 300) {
        $responseData = json_decode($response, true);
        return ['success' => true, 'message_id' => $responseData['name'] ?? null];
    }
    
    $errorResponse = json_decode($response, true);
    $errorMessage = $errorResponse['error']['message'] ?? 'Unknown FCM error';
    return ['success' => false, 'error' => $errorMessage];
}

/**
 * Handle device registration
 */
function handleRegister() {
    validateSecretKey();
    
    // Get request body
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Fall back to POST data
    if (!$input) {
        $input = $_POST;
    }
    
    $fcmToken = $input['fcm_token'] ?? null;
    $deviceInfo = $input['device_info'] ?? 'Unknown device';
    
    if (!$fcmToken) {
        sendError('FCM token is required');
    }
    
    // Check if device is already registered
    $existingDevice = findDeviceByFcmToken($fcmToken);
    
    if ($existingDevice) {
        sendResponse([
            'success' => true,
            'api_key' => $existingDevice['api_key'],
            'message' => 'Device already registered'
        ]);
    }
    
    // Generate new API key and register device
    $apiKey = generateApiKey();
    
    try {
        registerDevice($fcmToken, $apiKey, $deviceInfo);
        
        sendResponse([
            'success' => true,
            'api_key' => $apiKey,
            'message' => 'Device registered successfully'
        ]);
    } catch (PDOException $e) {
        sendError('Failed to register device: ' . $e->getMessage(), 500);
    }
}

/**
 * Handle sending notification
 */
function handleSendNotification() {
    // Get parameters from various sources
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
    
    // Merge with GET and POST parameters
    $params = array_merge($_GET, $_POST, $input);
    
    // Get API key (k parameter or api_key)
    $apiKey = $params['k'] ?? $params['api_key'] ?? null;
    $title = $params['t'] ?? $params['title'] ?? null;
    $content = $params['c'] ?? $params['content'] ?? $params['body'] ?? null;
    $url = $params['u'] ?? $params['url'] ?? '';
    
    // Validate required parameters
    if (!$apiKey) {
        sendError('API key (k) is required');
    }
    if (!$title) {
        sendError('Title (t) is required');
    }
    if (!$content) {
        sendError('Content (c) is required');
    }
    
    // Find device by API key using SQLite
    $device = findDeviceByApiKey($apiKey);
    
    if (!$device) {
        sendError('Invalid API key', 401);
    }
    
    $fcmToken = $device['fcm_token'];
    
    // Prepare notification data
    $notificationData = [];
    if ($url) {
        $notificationData['url'] = $url;
    }
    
    // Send notification via FCM
    $result = sendFcmNotification($fcmToken, $title, $content, $notificationData);
    
    if ($result['success']) {
        sendResponse([
            'success' => true,
            'message' => 'Notification sent successfully',
            'message_id' => $result['message_id'] ?? null
        ]);
    } else {
        sendError($result['error'], 500);
    }
}

// Main routing
$action = $_GET['action'] ?? 'message';

switch ($action) {
    case 'register':
        handleRegister();
        break;
    
    case 'send':
    case 'message':
        handleSendNotification();
        break;
    
    default:
        sendError('Invalid action', 400);
}
