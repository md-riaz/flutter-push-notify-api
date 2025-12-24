# NotifyHub - Firebase Cloud Messaging Push Notification App

NotifyHub is a modern and comprehensive Flutter application designed to serve as a powerful tool for testing and demonstrating Firebase Cloud Messaging (FCM) push notifications. This app provides a user-friendly dashboard to manage and simulate push notifications through a REST API, offering a complete and intuitive testing cycle from API key generation to notification history tracking.

## Features

- **FCM Integration:** Fully integrated with Firebase Cloud Messaging for robust and reliable notification handling.
- **REST API Backend:** Includes a PHP REST API (`api.php`) that handles device registration and FCM notification sending using Firebase Admin SDK.
- **SQLite Database:** Device registrations and API keys are stored in a SQLite database for persistence.
- **Secret Key Authentication:** Secure communication between the app and API using a shared secret key.
- **API Key Persistence:** The API key is persisted across app restarts using `shared_preferences`, providing a consistent and seamless user experience.
- **API Key Management:** The app securely manages and displays the API key, which can be easily copied to the clipboard or refreshed with a single tap.
- **Foreground & Background Notifications:** Handles incoming notifications seamlessly, whether the app is in the foreground, background, or terminated.
- **Notification Permissions:** Automatically requests the necessary user permissions for receiving notifications, ensuring a smooth user experience.
- **Test Console:** A built-in form allows you to send a real push notification to the device via the REST API.
- **Notification History:** All received notifications are stored locally using `shared_preferences` and displayed in a clean, chronological list, allowing you to review past notifications at any time.

## Getting Started

To get started with NotifyHub, you'll need to have Flutter and the Firebase CLI installed on your local machine. You will also need to have a Firebase project set up.

### Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/your-username/notify-hub.git
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Run the app:**

    ```bash
    flutter run
    ```

## REST API Setup

The `api.php` file in the root directory provides a REST API for device registration and FCM notification sending.

### Requirements

- PHP 7.4+ with PDO SQLite extension
- cURL extension for PHP
- Firebase service account JSON file

### Configuration

1. **Set up Firebase Service Account:**
   - Go to Firebase Console > Project Settings > Service Accounts
   - Generate a new private key and download the JSON file
   - Save it as `firebase-service-account.json` in the same directory as `api.php`
   - **Security:** The included `.htaccess` file blocks HTTP access to this file on Apache servers

2. **Configure Secret Key:**
   - **IMPORTANT:** Change the default secret key before deploying!
   - Set the `NOTIFYHUB_SECRET_KEY` environment variable, or
   - Edit the `SECRET_KEY` constant in `api.php`
   - Update `ApiConfig.secretKey` in `lib/api_service.dart` to match

3. **Configure API URL:**
   - Update `ApiConfig.baseUrl` in `lib/api_service.dart` to point to your server

4. **Production Security:**
   - Set `APP_ENV=production` environment variable to enable default key detection
   - Use HTTPS for all API communication
   - The `.htaccess` file protects sensitive files on Apache servers

### API Endpoints

#### Register Device
```
POST /api.php?action=register
Headers:
  Content-Type: application/json
  X-Secret-Key: your-secret-key-here
Body:
  {
    "fcm_token": "device-fcm-token",
    "device_info": "Flutter App v1.0"
  }
Response:
  {
    "success": true,
    "api_key": "API-XXXXXXXXXXXX",
    "message": "Device registered successfully"
  }
```

#### Send Notification
```
GET /api.php?action=send&k=API_KEY&t=Title&c=Content&u=URL
Parameters:
  k - API key (required)
  t - Notification title (required)
  c - Notification content (required)
  u - Deep link URL (optional)
Response:
  {
    "success": true,
    "message": "Notification sent successfully",
    "message_id": "projects/xxx/messages/xxx"
  }
```

## Usage

Upon launching the app, you will be greeted with the main dashboard, which is divided into three sections:

- **API Key:** This section displays your unique API key, which you can copy to the clipboard or refresh.
- **API Endpoint:** This section shows the API endpoint for sending push notifications, with your API key already included in the URL.
- **Test Console:** This section provides a form for sending a test push notification to your device.

### Sending a Test Notification

1.  **Enter a title and content** for your notification in the Test Console.
2.  **Click the "Send Test Push" button** to send the notification.
3.  **You will receive a notification** on your device, and the notification will be added to the history screen.

### Viewing Notification History

To view your notification history, tap the notification icon in the top-right corner of the screen. This will take you to the history screen, where you can see a list of all the notifications you have received.

## Contributing

Contributions are welcome! If you have any ideas for new features or improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
