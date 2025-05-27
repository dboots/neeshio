import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../screens/notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  Map<String, dynamic> _notificationStats = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotificationStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profile = await authService.getUserProfile();

      setState(() {
        if (profile != null && profile['name'] != null) {
          _nameController.text = profile['name'];
        } else if (authService.user?.userMetadata?['name'] != null) {
          _nameController.text = authService.user!.userMetadata!['name'];
        } else {
          _nameController.text = 'User';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadNotificationStats() async {
    try {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      if (notificationService.isInitialized) {
        final stats = await notificationService.getNotificationStats();
        setState(() {
          _notificationStats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notification stats: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateProfile(
        name: _nameController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }

      // Reload profile to get updated data
      _loadProfile();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
    }
  }

  Future<void> _testNotification() async {
    // try {
    //   final notificationService =
    //       Provider.of<NotificationService>(context, listen: false);
    //   await notificationService.sendTestNotification();

    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('Test notification sent!'),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //   }
    // } catch (e) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text('Error sending test notification: $e'),
    //         backgroundColor: Colors.red,
    //       ),
    //     );
    //   }
    // }
  }

  Widget _buildStatColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: color),
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

  Widget _buildNotificationCard() {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      notificationService.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: notificationService.notificationsEnabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            notificationService.notificationsEnabled
                                ? 'Enabled • ${notificationService.subscribedCategories.length} subscriptions'
                                : 'Disabled',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationSettingsScreen(),
                          ),
                        ).then((_) => _loadNotificationStats());
                      },
                      icon: const Icon(Icons.settings),
                      tooltip: 'Notification Settings',
                    ),
                  ],
                ),

                // Stats if notifications are enabled
                if (notificationService.notificationsEnabled &&
                    _notificationStats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(
                        'This Week',
                        '${_notificationStats['notifications_last_week'] ?? 0}',
                        Icons.notification_important,
                        Colors.blue,
                      ),
                      _buildStatColumn(
                        'Categories',
                        '${_notificationStats['total_subscriptions'] ?? 0}',
                        Icons.category,
                        Colors.orange,
                      ),
                      _buildStatColumn(
                        'Total',
                        '${_notificationStats['notifications_last_month'] ?? 0}',
                        Icons.history,
                        Colors.purple,
                      ),
                    ],
                  ),
                ],

                // Action buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: notificationService.isInitialized
                            ? _testNotification
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Test Notification'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationSettingsScreen(),
                            ),
                          ).then((_) => _loadNotificationStats());
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Configure'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
              tooltip: 'Save changes',
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile picture and basic info
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name display/edit
            if (_isEditing)
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
              )
            else
              Text(
                _nameController.text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),

            // Email
            Text(
              user?.email ?? 'No email',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Notification settings card
            _buildNotificationCard(),

            // Account info card
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Account Information'),
                    subtitle: Text('Basic account details'),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Email'),
                    subtitle: Text(user?.email ?? 'No email'),
                    leading: const Icon(Icons.email),
                  ),
                  ListTile(
                    title: const Text('Member Since'),
                    subtitle: Text(
                      user?.createdAt != null
                          ? _formatDate(DateTime.parse(user!.createdAt!))
                          : 'Unknown',
                    ),
                    leading: const Icon(Icons.calendar_today),
                  ),
                  ListTile(
                    title: const Text('Last Sign In'),
                    subtitle: Text(
                      user?.lastSignInAt != null
                          ? _formatDate(DateTime.parse(user!.lastSignInAt!))
                          : 'Unknown',
                    ),
                    leading: const Icon(Icons.login),
                  ),
                ],
              ),
            ),

            // Settings Card
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
                    subtitle: Text('App preferences and options'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      try {
                        final authService =
                            Provider.of<AuthService>(context, listen: false);
                        await authService.resetPassword(user?.email ?? '');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Password reset link sent to your email'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language'),
                    subtitle: const Text('English'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Multiple languages coming soon!'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Help center coming soon!'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'NEESH',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(Icons.place, size: 48),
                        children: [
                          const Text('Your Places, Your Way'),
                          const SizedBox(height: 16),
                          const Text(
                              'Create and share lists of your favorite places with friends and discover new places in your area.'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
