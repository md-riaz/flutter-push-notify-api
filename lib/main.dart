import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await FcmService().init();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotifyHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MyHomePage(),
    );
  }
}

class AppState with ChangeNotifier {
  final ApiService _apiService = ApiService();
  String? _fcmToken;
  String? _apiKey;
  String? get apiKey => _apiKey;
  bool _isSending = false;
  bool get isSending => _isSending;

  final TextEditingController titleController = TextEditingController(text: 'Hello World');
  final TextEditingController contentController = TextEditingController(text: 'Push notification test content');
  final TextEditingController urlController = TextEditingController(text: 'https://flutter.dev');

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => _history;

  AppState() {
    _loadHistory();
    _initServices();
  }

  Future<void> _initServices({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storedApiKey = prefs.getString('api_key');

    if (storedApiKey != null && storedApiKey.isNotEmpty && !forceRefresh) {
      _apiKey = storedApiKey;
      notifyListeners();
      return;
    }

    _apiKey = null;
    notifyListeners();

    try {
      _fcmToken = await FcmService().getToken();
    } catch (e) {
      _fcmToken = "Mock-FCM-Token-${DateTime.now().millisecondsSinceEpoch}";
    }

    const deviceInfo = "Flutter App v1.0";
    final newApiKey = await _apiService.getApiKey(_fcmToken!, deviceInfo);
    
    await prefs.setString('api_key', newApiKey);
    _apiKey = newApiKey;

    notifyListeners();
  }

  void refreshApiKey() {
    _initServices(forceRefresh: true);
  }

  /// Send a test push notification via the REST API
  Future<Map<String, dynamic>> sendTestNotification() async {
    if (_apiKey == null) {
      return {'success': false, 'error': 'API key not available'};
    }

    _isSending = true;
    notifyListeners();

    try {
      final result = await _apiService.sendNotification(
        apiKey: _apiKey!,
        title: titleController.text,
        content: contentController.text,
        url: urlController.text,
      );
      return result;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getStringList('notification_history') ?? [];
    _history = historyString.map((h) => jsonDecode(h) as Map<String, dynamic>).toList();
    notifyListeners();
  }

  void clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
    _history = [];
    notifyListeners();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NotifyHub'),
        actions: [
          IconButton(
            onPressed: () => _showHowToUseDialog(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              if (appState.history.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(theme),
              const SizedBox(height: 32),
              _buildTokenSection(context, appState, theme),
              const SizedBox(height: 24),
              _buildUrlSection(context, appState, theme),
              const SizedBox(height: 32),
              _buildTestFormSection(context, appState, theme),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Dashboard',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Push Notification API',
          style: theme.textTheme.displayLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenSection(BuildContext context, AppState appState, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'API KEY',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    appState.apiKey ?? 'Generating key...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (appState.apiKey != null) {
                      Clipboard.setData(ClipboardData(text: appState.apiKey!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  color: theme.colorScheme.primary,
                ),
                IconButton(
                  onPressed: () => appState.refreshApiKey(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrlSection(BuildContext context, AppState appState, ThemeData theme) {
    final apiUrl = '${ApiConfig.baseUrl}?action=send&k=${appState.apiKey ?? 'YOUR_API_KEY'}&t=title&c=contents&u=url';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'API ENDPOINT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base URL',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    apiUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestFormSection(BuildContext context, AppState appState, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'TEST CONSOLE',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextField(
                  controller: appState.titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: appState.contentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Content Message',
                    prefixIcon: Icon(Icons.message_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: appState.urlController,
                  decoration: const InputDecoration(
                    labelText: 'Deep Link URL',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: appState.isSending || appState.apiKey == null
                      ? null
                      : () async {
                          final result = await appState.sendTestNotification();
                          if (!context.mounted) return;
                          
                          if (result['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade600,
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(child: Text('Push notification sent successfully!')),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red.shade600,
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(result['error'] ?? 'Failed to send notification')),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                  child: appState.isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Send Test Push'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showHowToUseDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Quick Start Guide'),
          ],
        ),
        content: const SingleChildScrollView(
          child: ListBody(
            children: [
              _GuideItem(
                step: '1',
                title: 'Copy API Key',
                desc: 'Your unique API key is used to authenticate with the push notification service.',
              ),
              _GuideItem(
                step: '2',
                title: 'Construct Request',
                desc: 'Send a GET or POST request to the endpoint with required parameters: k (key), t (title), c (content).',
              ),
              _GuideItem(
                step: '3',
                title: 'Handle Deep Links',
                desc: 'Use the optional "u" parameter to redirect users to a specific URL when they tap the notification.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('GOT IT'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _GuideItem({required this.step, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(desc, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        actions: [
          if (appState.history.isNotEmpty)
            TextButton.icon(
              onPressed: () => appState.clearHistory(),
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              label: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: appState.history.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appState.history.length,
                itemBuilder: (context, index) {
                  final item = appState.history[index];
                  final timestamp = DateTime.parse(item['timestamp']);
                  final formattedDate = DateFormat('MMM d, HH:mm').format(timestamp);
        
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'],
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            item['body'],
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          if (item['url'] != null && item['url'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_rounded, size: 14, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['url'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
