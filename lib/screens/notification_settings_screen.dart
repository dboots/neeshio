import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final stats = await notificationService.getNotificationStats();
    setState(() {
      _stats = stats;
    });
  }

  Future<void> _toggleCategory(String category, bool subscribe) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      
      if (subscribe) {
        await notificationService.subscribeToCategory(category);
      } else {
        await notificationService.unsubscribeFromCategory(category);
      }

      // Refresh stats
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              subscribe 
                ? 'Subscribed to $category notifications'
                : 'Unsubscribed from $category notifications'
            ),
            backgroundColor: subscribe ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.setNotificationsEnabled(enabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                ? 'Notifications enabled'
                : 'Notifications disabled'
            ),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllSubscriptions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Subscriptions'),
        content: const Text(
          'Are you sure you want to unsubscribe from all categories? '
          'You will no longer receive notifications for new lists.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        await notificationService.clearAllSubscriptions();
        await _loadStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All subscriptions cleared'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Attractions':
        return Icons.museum;
      case 'Outdoors':
        return Icons.park;
      case 'Entertainment':
        return Icons.movie;
      case 'Health & Fitness':
        return Icons.fitness_center;
      case 'Services':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return Colors.orange;
      case 'Shopping':
        return Colors.blue;
      case 'Attractions':
        return Colors.purple;
      case 'Outdoors':
        return Colors.green;
      case 'Entertainment':
        return Colors.red;
      case 'Health & Fitness':
        return Colors.teal;
      case 'Services':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          if (!notificationService.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Master toggle
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      notificationService.notificationsEnabled
                          ? 'Get notified about new lists in your subscribed categories'
                          : 'Enable to receive notifications about new lists',
                    ),
                    value: notificationService.notificationsEnabled,
                    onChanged: _isLoading ? null : _toggleNotifications,
                    secondary: Icon(
                      notificationService.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: notificationService.notificationsEnabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Statistics card
                if (_stats.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notification Statistics',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Subscriptions',
                                '${_stats['total_subscriptions'] ?? 0}',
                                Icons.subscriptions,
                                Colors.blue,
                              ),
                              _buildStatItem(
                                'This Week',
                                '${_stats['notifications_last_week'] ?? 0}',
                                Icons.notification_important,
                                Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Category subscriptions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category Subscriptions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (notificationService.subscribedCategories.isNotEmpty)
                      TextButton(
                        onPressed: _isLoading ? null : _clearAllSubscriptions,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Clear All'),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  'Choose which categories you\'d like to receive notifications for when new lists are created.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                // Category list
                ...NotificationService.availableCategories.map((category) {
                  final isSubscribed = notificationService.isSubscribedToCategory(category);
                  final categoryColor = _getCategoryColor(category);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      title: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            color: categoryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isSubscribed
                            ? 'You\'ll be notified about new $category lists'
                            : 'Tap to get notified about new $category lists',
                        style: TextStyle(
                          color: isSubscribed ? Colors.green[700] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      value: isSubscribed,
                      onChanged: !notificationService.notificationsEnabled || _isLoading
                          ? null
                          : (value) => _toggleCategory(category, value),
                      activeColor: categoryColor,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(category),
                          color: categoryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Help section
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• When someone creates a new public list in your area\n'
                          '• And it matches one of your subscribed categories\n'
                          '• You\'ll receive a push notification\n'
                          '• Tap the notification to view the new list',
                          style: TextStyle(
                            color: Colors.blue[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Error display
                if (notificationService.error != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Error',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                                Text(
                                  notificationService.error!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: notificationService.clearError,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}