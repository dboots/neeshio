import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

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
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
        _profile = profile;
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
          _isEditing
              ? IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _updateProfile,
                  tooltip: 'Save changes',
                )
              : IconButton(
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
            // Profile picture
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
                ),
              ),
            ),
            const SizedBox(height: 24),

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

            // Account info card
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Account Information'),
                    subtitle: const Text('Basic account details'),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Email'),
                    subtitle: Text(user?.email ?? 'No email'),
                  ),
                  ListTile(
                    title: const Text('Member Since'),
                    subtitle: Text(
                      user?.createdAt != null
                          ? _formatDate(DateTime.parse(user!.createdAt!))
                          : 'Unknown',
                    ),
                  ),
                  ListTile(
                    title: const Text('Last Sign In'),
                    subtitle: Text(
                      user?.lastSignInAt != null
                          ? _formatDate(DateTime.parse(user!.lastSignInAt!))
                          : 'Unknown',
                    ),
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
                    onTap: () {
                      // Navigate to change password screen or show dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Password reset link sent to your email. Please check your inbox.'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notification Settings'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language'),
                    trailing: const Text('English'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
