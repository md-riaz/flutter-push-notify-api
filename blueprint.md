# Blueprint: NotifyHub - FCM Push Notification App

## Overview

This document outlines the project structure and features for **NotifyHub**, a modern Flutter application designed to test and demonstrate Firebase Cloud Messaging (FCM) push notifications. The app provides a user-friendly dashboard to manage and simulate push notifications via a mocked third-party API, ensuring a complete testing cycle from key generation to notification history tracking.

## Features & Design

### Core Functionality

- **FCM Integration:** Fully integrated with Firebase Cloud Messaging for robust notification handling.
- **Mock Third-Party API:** Includes a mock `ApiService` that simulates fetching a unique API key. The flow is as follows:
    1.  The app retrieves the device-specific FCM token from Firebase.
    2.  It sends this FCM token along with mock device info to the `ApiService`.
    3.  The service returns a unique, randomly generated API key, mimicking a real-world authentication process.
- **API Key Persistence:** The API key is persisted across app restarts using `shared_preferences`, ensuring a consistent user experience.
- **API Key Management:** The app securely manages and displays the API key, which is used for sending notifications.
- **Foreground & Background Notifications:** Handles incoming notifications seamlessly whether the app is active, in the background, or terminated.
- **Notification Permissions:** Automatically requests the necessary user permissions for receiving notifications.
- **Test Console:** A built-in form allows users to simulate sending a test push notification to the device itself.
- **Notification History:** All received notifications are stored locally using `shared_preferences` and displayed in a clean, chronological list.

### UI & Design (NotifyHub Theme)

- **Modern & Bold Aesthetics:** The UI is designed with Material 3 principles, featuring a clean layout, vibrant colors, and modern components.
- **Safe Area Implementation:** The UI is wrapped in a `SafeArea` widget to prevent interference with system elements on all devices.
- **Layout:** A `SingleChildScrollView` dashboard inspired by modern service panels, using `Card` widgets for clear separation of concerns (API Key, Endpoint, Test Console).
- **Color Scheme:**
    - **Primary:** Modern Indigo (`#6366F1`)
    - **Secondary:** Ocean Blue (`#0EA5E9`)
    - **Background:** Light Gray (`#F8FAFC`)
- **Typography:** Default system fonts are used for performance and consistency. The typography is clean and hierarchical, with bold weights for titles and a monospaced font for the API key.
- **Interactivity:**
    - Buttons and interactive elements provide clear visual feedback.
    - `SnackBar` is used for non-intrusive confirmations (e.g., "Copied to clipboard").
- **Dialogs & Navigation:**
    - A "Quick Start Guide" dialog explains the API usage.
    - A dedicated `HistoryScreen` is available for viewing past notifications.

### Automation

- **GitHub Actions:** A pre-configured workflow in `.github/workflows/release.yml` automates building and releasing an Android APK whenever a new tag is pushed.

## Plan

1.  **Setup Firebase & Dependencies:**
    *   Add `firebase_core`, `firebase_messaging`, `provider`, `shared_preferences`, and `intl` to `pubspec.yaml`.
    *   Configure the Android and iOS projects for Firebase integration.

2.  **Implement Core Services:**
    *   **`fcm_service.dart`:** Create a service to handle FCM token retrieval, background/foreground message handlers, and local notification storage.
    *   **`api_service.dart`:** Implement a mock API service to generate a unique API key based on the FCM token.

3.  **Develop the User Interface:**
    *   **`theme.dart`:** Define a centralized `AppTheme` for consistent styling.
    *   **`main.dart`:**
        *   Build the main `MyHomePage` with a `SingleChildScrollView` and `Card`-based layout.
        *   Create the `HistoryScreen` to display notification history.
        *   Implement the `_showHowToUseDialog` for user guidance.
        *   Use a `ChangeNotifier` (`AppState`) to manage the application state (API key, form inputs, history).

4.  **Connect UI to Services:**
    *   In `AppState`, first fetch the FCM token, then call `ApiService` to get the API key.
    *   Display the generated API key in the "API KEY" section.
    *   Implement the refresh button to trigger a full re-initialization (`refreshApiKey`).
    *   Update the "API ENDPOINT" card to dynamically display the correct API key.

5.  **Finalize and Test:**
    *   Ensure the app correctly handles notifications in all states (foreground, background, terminated).
    *   Verify UI responsiveness and visual polish across different screen sizes.
    *   Confirm that the GitHub Actions workflow successfully builds the APK.
