import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Service for handling push notifications using Supabase realtime and Edge Functions
class NotificationService extends ChangeNotifier {
  static const String _subscriptionsKey = 'notification_subscriptions';
  static const String _deviceIdKey = 'device_id';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotifications;

  List<String> _subscribedCategories = [];
  bool _isInitialized = false;
  bool _notificationsEnabled = false;
  String? _deviceId;
  String? _error;
  RealtimeChannel? _notificationChannel;
  Timer? _heartbeatTimer;
  StreamSubscription? _authSubscription;

  // Available categories for subscription
  static const List<String> availableCategories = [
    'Food & Dining',
    'Shopping',
    'Attractions',
    'Outdoors',
    'Entertainment',
    'Health & Fitness',
    'Services',
    'Other'
  ];

  // Getters
  List<String> get subscribedCategories => List.from(_subscribedCategories);
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;
  String? get deviceId => _deviceId;
  String? get error => _error;

  NotificationService({
    SupabaseClient? supabase,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      _error = null;

      if (kDebugMode) {
        print('Initializing NotificationService...');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Generate or load device ID
      await _initializeDeviceId();

      // Load saved preferences
      await _loadPreferences();

      // Request permissions if enabled
      if (_notificationsEnabled) {
        await _requestPermissions();
      }

      // Load saved subscriptions
      await _loadSubscriptions();

      // Setup auth state listener
      _setupAuthListener();

      // Setup realtime subscription for notifications if authenticated
      if (_supabase.auth.currentUser != null && _notificationsEnabled) {
        await _setupRealtimeNotifications();
      }

      _isInitialized = true;
      notifyListeners();

      if (kDebugMode) {
        print('NotificationService initialized successfully');
        print('Device ID: $_deviceId');
        print('Notifications enabled: $_notificationsEnabled');
        print('Subscribed categories: $_subscribedCategories');
      }
    } catch (e) {
      _error = 'Failed to initialize notifications: ${e.toString()}';
      if (kDebugMode) {
        print(_error);
      }
      notifyListeners();
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request this separately
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (kDebugMode) {
      print('Local notifications initialized');
    }
  }

  /// Initialize or load device ID
  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId == null) {
      // Generate a unique device ID
      _deviceId =
          'device_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, _deviceId!);

      if (kDebugMode) {
        print('Generated new device ID: $_deviceId');
      }
    } else {
      if (kDebugMode) {
        print('Loaded existing device ID: $_deviceId');
      }
    }
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;

      if (kDebugMode) {
        print(
            'Loaded notification preferences: enabled=$_notificationsEnabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading preferences: $e');
      }
    }
  }

  /// Save preferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving preferences: $e');
      }
    }
  }

  /// Setup auth state listener
  void _setupAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (kDebugMode) {
        print('Auth state changed: $event');
      }

      if (event == AuthChangeEvent.signedIn && session != null) {
        // User signed in - setup notifications if enabled
        if (_notificationsEnabled) {
          _setupRealtimeNotifications();
          loadSubscriptionsFromServer();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // User signed out - cleanup
        _cleanupRealtimeConnection();
        _subscribedCategories = [];
        _saveSubscriptions();
        notifyListeners();
      }
    });
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    bool granted = false;

    if (Platform.isAndroid) {
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      granted = await androidImplementation?.requestNotificationsPermission() ??
          false;
    } else if (Platform.isIOS) {
      final iosImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      granted = await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else {
      granted = true; // Web and other platforms
    }

    if (!granted) {
      _notificationsEnabled = false;
      await _savePreferences();
    }

    if (kDebugMode) {
      print('Notification permissions: ${granted ? 'granted' : 'denied'}');
    }
  }

  /// Setup realtime notifications using Supabase realtime
  Future<void> _setupRealtimeNotifications() async {
    if (!_notificationsEnabled ||
        _deviceId == null ||
        _supabase.auth.currentUser == null) {
      if (kDebugMode) {
        print(
            'Skipping realtime setup - notifications disabled or not authenticated');
      }
      return;
    }

    try {
      // Clean up existing connection
      await _cleanupRealtimeConnection();

      // Create a realtime channel for this device
      _notificationChannel = _supabase.channel('notifications:$_deviceId');

      // Listen for notification events
      _notificationChannel!.onBroadcast(
          event: 'notification',
          callback: (payload) => _handleRealtimeNotification(payload));

      // Listen for connection state
      _notificationChannel!.onBroadcast(
          event: '*',
          callback: (payload) => {print('Realtime system event: $payload')});

      // Subscribe to the channel
      _notificationChannel!.subscribe();

      // Start heartbeat to keep connection alive
      _startHeartbeat();

      if (kDebugMode) {
        print(
            'Realtime notification channel subscribed for device: $_deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up realtime notifications: $e');
      }
      _error = 'Failed to setup realtime notifications: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Cleanup realtime connection
  Future<void> _cleanupRealtimeConnection() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_notificationChannel != null) {
      try {
        await _notificationChannel!.unsubscribe();
      } catch (e) {
        if (kDebugMode) {
          print('Error unsubscribing from channel: $e');
        }
      }
      _notificationChannel = null;
    }
  }

  /// Start heartbeat to keep realtime connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_notificationChannel != null) {
        try {
          _notificationChannel!.sendBroadcastMessage(
            event: 'heartbeat',
            payload: {
              'device_id': _deviceId,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error sending heartbeat: $e');
          }
        }
      }
    });
  }

  /// Handle realtime notification
  void _handleRealtimeNotification(Map<String, dynamic> payload) {
    if (kDebugMode) {
      print('Received realtime notification: $payload');
    }

    try {
      final notificationData = payload['payload'] as Map<String, dynamic>?;
      if (notificationData != null) {
        _showLocalNotification(
          title: notificationData['title'] ?? 'New List Available',
          body: notificationData['body'] ?? 'Check out a new list in your area',
          data: notificationData['data'] as Map<String, dynamic>? ?? {},
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling realtime notification: $e');
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'neesh_new_lists',
      'New Lists',
      channelDescription:
          'Notifications for new lists in subscribed categories',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF300489),
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: data != null ? jsonEncode(data) : null,
    );

    if (kDebugMode) {
      print('Local notification shown: $title');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        if (data['type'] == 'new_list' && data['list_id'] != null) {
          _navigateToList(data['list_id']);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Navigate to list detail (placeholder - implement navigation logic)
  void _navigateToList(String listId) {
    // TODO: Implement navigation to list detail screen
    // This would typically use your app's navigation system
    if (kDebugMode) {
      print('Navigate to list: $listId');
    }
  }

  /// Subscribe to a category
  Future<void> subscribeToCategory(String category) async {
    if (!availableCategories.contains(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    if (_subscribedCategories.contains(category)) {
      return; // Already subscribed
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (_deviceId == null) {
        throw Exception('Device ID not available');
      }

      // Add to Supabase
      await _supabase.from('push_subscriptions').insert({
        'user_id': userId,
        'category': category,
        'device_id': _deviceId,
        'platform': _getPlatform(),
        'is_active': true,
      });

      // Update local state
      _subscribedCategories = [..._subscribedCategories, category];
      await _saveSubscriptions();

      notifyListeners();

      if (kDebugMode) {
        print('Subscribed to category: $category');
      }
    } catch (e) {
      _error = 'Failed to subscribe to $category: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Unsubscribe from a category
  Future<void> unsubscribeFromCategory(String category) async {
    if (!_subscribedCategories.contains(category)) {
      return; // Not subscribed
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Remove from Supabase
      await _supabase
          .from('push_subscriptions')
          .delete()
          .eq('user_id', userId)
          .eq('category', category)
          .eq('device_id', _deviceId ?? '');

      // Update local state
      _subscribedCategories =
          _subscribedCategories.where((c) => c != category).toList();
      await _saveSubscriptions();

      notifyListeners();

      if (kDebugMode) {
        print('Unsubscribed from category: $category');
      }
    } catch (e) {
      _error = 'Failed to unsubscribe from $category: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle subscription for a category
  Future<void> toggleCategorySubscription(String category) async {
    if (_subscribedCategories.contains(category)) {
      await unsubscribeFromCategory(category);
    } else {
      await subscribeToCategory(category);
    }
  }

  /// Check if subscribed to a category
  bool isSubscribedToCategory(String category) {
    return _subscribedCategories.contains(category);
  }

  /// Load subscriptions from server
  Future<void> loadSubscriptionsFromServer() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          print('Cannot load subscriptions - user not authenticated');
        }
        return;
      }

      final response = await _supabase
          .from('push_subscriptions')
          .select('category')
          .eq('user_id', userId)
          .eq('device_id', _deviceId ?? '')
          .eq('is_active', true);

      _subscribedCategories =
          (response as List).map((sub) => sub['category'] as String).toList();

      await _saveSubscriptions();
      notifyListeners();

      if (kDebugMode) {
        print(
            'Loaded ${_subscribedCategories.length} subscriptions from server');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading subscriptions from server: $e');
      }
    }
  }

  /// Clear all subscriptions
  Future<void> clearAllSubscriptions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('push_subscriptions')
          .delete()
          .eq('user_id', userId)
          .eq('device_id', _deviceId ?? '');

      _subscribedCategories = [];
      await _saveSubscriptions();
      notifyListeners();

      if (kDebugMode) {
        print('Cleared all subscriptions');
      }
    } catch (e) {
      _error = 'Failed to clear subscriptions: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Save subscriptions to local storage
  Future<void> _saveSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_subscriptionsKey, _subscribedCategories);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving subscriptions: $e');
      }
    }
  }

  /// Load subscriptions from local storage
  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _subscribedCategories = prefs.getStringList(_subscriptionsKey) ?? [];

      if (kDebugMode) {
        print(
            'Loaded ${_subscribedCategories.length} subscriptions from local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading subscriptions: $e');
      }
    }
  }

  /// Get platform string
  String _getPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  /// Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled && !_notificationsEnabled) {
      // Request permissions first
      await _requestPermissions();

      if (_notificationsEnabled) {
        // Setup realtime connection
        if (_supabase.auth.currentUser != null) {
          await _setupRealtimeNotifications();
        }

        // Re-enable subscriptions in database
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase
              .from('push_subscriptions')
              .update({'is_active': true})
              .eq('user_id', userId)
              .eq('device_id', _deviceId ?? '');
        }
      }
    } else if (!enabled) {
      // Disable all subscriptions
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('push_subscriptions')
            .update({'is_active': false})
            .eq('user_id', userId)
            .eq('device_id', _deviceId ?? '');
      }

      // Close realtime connection
      await _cleanupRealtimeConnection();
    }

    _notificationsEnabled = enabled;
    await _savePreferences();
    notifyListeners();

    if (kDebugMode) {
      print('Notifications ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Get notification statistics
  Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      // Get subscription count by category
      final subscriptions = await _supabase
          .from('push_subscriptions')
          .select('category')
          .eq('user_id', userId)
          .eq('device_id', _deviceId ?? '')
          .eq('is_active', true);

      // Get recent notification count
      final weekAgo =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final monthAgo =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final recentNotifications = await _supabase
          .from('notification_history')
          .select('sent_at')
          .eq('device_id', _deviceId ?? '')
          .gte('sent_at', weekAgo);

      final monthlyNotifications = await _supabase
          .from('notification_history')
          .select('sent_at')
          .eq('device_id', _deviceId ?? '')
          .gte('sent_at', monthAgo);

      return {
        'total_subscriptions': subscriptions.length,
        'subscribed_categories': _subscribedCategories,
        'notifications_last_week': recentNotifications.length,
        'notifications_last_month': monthlyNotifications.length,
        'notifications_enabled': _notificationsEnabled,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting notification stats: $e');
      }
      return {};
    }
  }

  /// Test notification (for debugging)
  Future<void> sendTestNotification() async {
    if (!_notificationsEnabled) {
      throw Exception('Notifications are not enabled');
    }

    await _showLocalNotification(
      title: 'Test Notification',
      body: 'This is a test notification from NEESH! 🎉',
      data: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (kDebugMode) {
      print('Test notification sent');
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupRealtimeConnection();
    _authSubscription?.cancel();
    super.dispose();
  }
}
