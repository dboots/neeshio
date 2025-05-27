import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background service to process notification queue and send push notifications
/// This would typically run as a separate service or cloud function
class BackgroundNotificationProcessor {
  final SupabaseClient _supabase;
  final String _fcmServerKey;
  
  // FCM endpoint
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  
  BackgroundNotificationProcessor({
    required SupabaseClient supabase,
    required String fcmServerKey,
  }) : _supabase = supabase,
       _fcmServerKey = fcmServerKey;

  /// Process pending notifications from the queue
  Future<void> processPendingNotifications() async {
    try {
      // Get pending notifications with subscription details
      final pendingNotifications = await _supabase
          .from('notification_queue')
          .select('''
            *,
            push_subscriptions!inner(
              device_token,
              platform,
              is_active
            )
          ''')
          .eq('status', 'pending')
          .eq('push_subscriptions.is_active', true)
          .lt('attempts', 3)  // Don't retry more than 3 times
          .order('created_at', ascending: true)
          .limit(100);  // Process in batches

      if (pendingNotifications.isEmpty) {
        if (kDebugMode) {
          print('No pending notifications to process');
        }
        return;
      }

      if (kDebugMode) {
        print('Processing ${pendingNotifications.length} pending notifications');
      }

      // Process each notification
      for (final notification in pendingNotifications) {
        await _processNotification(notification);
        
        // Add small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing pending notifications: $e');
      }
    }
  }

  /// Process a single notification
  Future<void> _processNotification(Map<String, dynamic> notification) async {
    try {
      final subscriptionData = notification['push_subscriptions'];
      final deviceToken = subscriptionData['device_token'] as String;
      final platform = subscriptionData['platform'] as String;
      
      // Build notification payload
      final payload = _buildNotificationPayload(
        notification: notification,
        deviceToken: deviceToken,
        platform: platform,
      );

      // Send the notification
      final success = await _sendPushNotification(payload);

      // Update notification status
      await _updateNotificationStatus(
        notificationId: notification['id'],
        success: success,
        attempts: (notification['attempts'] as int) + 1,
      );

      if (success) {
        // Log successful notification to history
        await _logNotificationHistory(notification);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing notification ${notification['id']}: $e');
      }
      
      // Mark as failed
      await _updateNotificationStatus(
        notificationId: notification['id'],
        success: false,
        attempts: (notification['attempts'] as int) + 1,
        errorMessage: e.toString(),
      );
    }
  }

  /// Build FCM notification payload
  Map<String, dynamic> _buildNotificationPayload({
    required Map<String, dynamic> notification,
    required String deviceToken,
    required String platform,
  }) {
    final data = notification['payload'] as Map<String, dynamic>;
    
    return {
      'to': deviceToken,
      'notification': {
        'title': notification['title'],
        'body': notification['body'],
        'sound': 'default',
        'badge': 1,
        if (platform == 'android') ...{
          'icon': 'ic_launcher',
          'color': '#300489',
          'channel_id': 'neesh_new_lists',
        },
        if (platform == 'ios') ...{
          'badge': 1,
          'sound': 'default',
        },
      },
      'data': {
        ...data['data'] as Map<String, dynamic>,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
      'priority': 'high',
      if (platform == 'android') ...{
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'neesh_new_lists',
            'priority': 'high',
            'visibility': 'public',
          },
        },
      },
      if (platform == 'ios') ...{
        'apns': {
          'headers': {
            'apns-priority': '10',
          },
          'payload': {
            'aps': {
              'alert': {
                'title': notification['title'],
                'body': notification['body'],
              },
              'badge': 1,
              'sound': 'default',
            },
          },
        },
      },
    };
  }

  /// Send push notification via FCM
  Future<bool> _sendPushNotification(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final success = responseData['success'] as int? ?? 0;
        final failure = responseData['failure'] as int? ?? 0;
        
        if (kDebugMode) {
          print('FCM Response: success=$success, failure=$failure');
        }
        
        return success > 0;
      } else {
        if (kDebugMode) {
          print('FCM request failed: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending push notification: $e');
      }
      return false;
    }
  }

  /// Update notification status in the queue
  Future<void> _updateNotificationStatus({
    required String notificationId,
    required bool success,
    required int attempts,
    String? errorMessage,
  }) async {
    final updateData = {
      'status': success ? 'sent' : (attempts >= 3 ? 'failed' : 'pending'),
      'attempts': attempts,
      'sent_at': success ? DateTime.now().toIso8601String() : null,
      'error_message': errorMessage,
    };

    await _supabase
        .from('notification_queue')
        .update(updateData)
        .eq('id', notificationId);
  }

  /// Log successful notification to history
  Future<void> _logNotificationHistory(Map<String, dynamic> notification) async {
    await _supabase.from('notification_history').insert({
      'subscription_id': notification['subscription_id'],
      'list_id': notification['list_id'],
      'title': notification['title'],
      'body': notification['body'],
      'sent_at': DateTime.now().toIso8601String(),
      'status': 'sent',
    });
  }

  /// Clean up old processed notifications from queue
  Future<int> cleanupProcessedNotifications({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysOld))
          .toIso8601String();

      final result = await _supabase
          .from('notification_queue')
          .delete()
          .contains('status', ['sent', 'failed'])
          .lt('created_at', cutoffDate);

      if (kDebugMode) {
        print('Cleaned up old notifications');
      }

      return result.length;
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up notifications: $e');
      }
      return 0;
    }
  }

  /// Get notification processing statistics
  Future<Map<String, dynamic>> getProcessingStats() async {
    try {
      // Get counts by status
      final stats = await _supabase
          .from('notification_queue')
          .select('status')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String());

      final statusCounts = <String, int>{};
      for (final row in stats) {
        final status = row['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      // Get recent notification history
      final recentHistory = await _supabase
          .from('notification_history')
          .select('*')
          .gte('sent_at', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String());

      return {
        'queue_stats': statusCounts,
        'notifications_sent_24h': recentHistory.length,
        'pending_count': statusCounts['pending'] ?? 0,
        'failed_count': statusCounts['failed'] ?? 0,
        'sent_count': statusCounts['sent'] ?? 0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting processing stats: $e');
      }
      return {};
    }
  }

  /// Test notification sending (for debugging)
  Future<bool> sendTestNotification({
    required String deviceToken,
    required String platform,
    String title = 'Test Notification',
    String body = 'This is a test notification from NEESH',
  }) async {
    final payload = {
      'to': deviceToken,
      'notification': {
        'title': title,
        'body': body,
        'sound': 'default',
      },
      'data': {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
      'priority': 'high',
    };

    return await _sendPushNotification(payload);
  }
}

/// Notification scheduler for running background processing
class NotificationScheduler {
  static const Duration _processingInterval = Duration(minutes: 5);
  static const Duration _cleanupInterval = Duration(hours: 6);
  
  final BackgroundNotificationProcessor _processor;
  bool _isRunning = false;

  NotificationScheduler(this._processor);

  /// Start the notification processing scheduler
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Start processing timer
    _startProcessingTimer();
    
    // Start cleanup timer
    _startCleanupTimer();
    
    if (kDebugMode) {
      print('Notification scheduler started');
    }
  }

  /// Stop the scheduler
  void stop() {
    _isRunning = false;
    if (kDebugMode) {
      print('Notification scheduler stopped');
    }
  }

  void _startProcessingTimer() {
    Future.delayed(_processingInterval, () async {
      if (!_isRunning) return;
      
      try {
        await _processor.processPendingNotifications();
      } catch (e) {
        if (kDebugMode) {
          print('Error in scheduled processing: $e');
        }
      }
      
      // Schedule next run
      _startProcessingTimer();
    });
  }

  void _startCleanupTimer() {
    Future.delayed(_cleanupInterval, () async {
      if (!_isRunning) return;
      
      try {
        await _processor.cleanupProcessedNotifications();
      } catch (e) {
        if (kDebugMode) {
          print('Error in scheduled cleanup: $e');
        }
      }
      
      // Schedule next cleanup
      _startCleanupTimer();
    });
  }
}