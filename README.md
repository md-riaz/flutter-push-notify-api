# NotifyHub - Firebase Cloud Messaging Push Notification App

NotifyHub is a modern and comprehensive Flutter application designed to serve as a powerful tool for testing and demonstrating Firebase Cloud Messaging (FCM) push notifications. This app provides a user-friendly dashboard to manage and simulate push notifications through a mocked third-party API, offering a complete and intuitive testing cycle from API key generation to notification history tracking.

## Features

- **FCM Integration:** Fully integrated with Firebase Cloud Messaging for robust and reliable notification handling.
- **Mock Third-Party API:** Includes a mock `ApiService` that simulates fetching a unique API key, mirroring a real-world authentication process where a device-specific FCM token is exchanged for an API key.
- **API Key Persistence:** The API key is persisted across app restarts using `shared_preferences`, providing a consistent and seamless user experience.
- **API Key Management:** The app securely manages and displays the API key, which can be easily copied to the clipboard or refreshed with a single tap.
- **Foreground & Background Notifications:** Handles incoming notifications seamlessly, whether the app is in the foreground, background, or terminated.
- **Notification Permissions:** Automatically requests the necessary user permissions for receiving notifications, ensuring a smooth user experience.
- **Test Console:** A built-in form allows you to simulate sending a test push notification to the device itself, making it easy to test your notification setup.
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
