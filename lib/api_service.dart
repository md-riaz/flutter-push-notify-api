import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

/// Configuration for the NotifyHub API
class ApiConfig {
  /// The base URL of your NotifyHub REST API
  /// IMPORTANT: Change this to your actual API URL before deploying
  /// Note: Use HTTPS in production for secure communication
  static const String baseUrl = 'https://your-domain.com/api.php';

  /// Secret key for authentication between the app and API
  /// IMPORTANT: Change this to a strong, unique secret key before deploying
  /// This should match the SECRET_KEY in your PHP api.php
  static const String secretKey = 'CHANGE_THIS_SECRET_KEY';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Register device with the API and get an API key
  ///
  /// Sends the FCM token to the server which returns a unique API key
  /// that can be used to send push notifications to this device.
  Future<String> getApiKey(String fcmToken, String deviceInfo) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}?action=register');

      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Secret-Key': ApiConfig.secretKey,
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'device_info': deviceInfo,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['api_key'] != null) {
            developer.log(
              'API: Successfully registered device. API Key: ${data['api_key']}',
              name: 'com.notifyhub.app',
            );
            return data['api_key'];
          }
          throw Exception(data['error'] ?? 'Failed to get API key');
        } on FormatException catch (e) {
          developer.log(
            'API Error: Invalid JSON response - $e',
            name: 'com.notifyhub.app',
            level: 900,
          );
          throw Exception('Invalid server response');
        }
      } else {
        String errorMessage = 'Server error: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } on FormatException {
          // Response is not JSON, use default error message
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      developer.log(
        'API Error: Failed to register device - $e',
        name: 'com.notifyhub.app',
        level: 900,
      );
      // Fall back to mock API key generation for offline/dev mode
      return _generateMockApiKey();
    }
  }

  /// Send a push notification via the REST API
  ///
  /// This sends a push notification to the device associated with the given API key.
  Future<Map<String, dynamic>> sendNotification({
    required String apiKey,
    required String title,
    required String content,
    String? url,
  }) async {
    try {
      final queryParams = {
        'action': 'send',
        'k': apiKey,
        't': title,
        'c': content,
      };

      if (url != null && url.isNotEmpty) {
        queryParams['u'] = url;
      }

      final uri = Uri.parse(ApiConfig.baseUrl).replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          developer.log(
            'API: Notification sent successfully',
            name: 'com.notifyhub.app',
          );
          return {
            'success': true,
            'message': data['message'] ?? 'Notification sent',
            'message_id': data['message_id'],
          };
        }
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send notification',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? 'Server error: ${response.statusCode}',
          };
        } on FormatException catch (e) {
          developer.log(
            'API Error: Failed to parse error response - $e',
            name: 'com.notifyhub.app',
            level: 800,
          );
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      developer.log(
        'API Error: Failed to send notification - $e',
        name: 'com.notifyhub.app',
        level: 900,
      );
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Generate a mock API key for offline/development mode
  String _generateMockApiKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'MOCK-${timestamp.toRadixString(16).toUpperCase().padLeft(12, '0')}';
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}
