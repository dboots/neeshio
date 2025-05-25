import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place_list.dart';
import '../services/place_list_service.dart';

class ShareListDialog extends StatefulWidget {
  final PlaceList list;

  const ShareListDialog({
    super.key,
    required this.list,
  });

  @override
  State<ShareListDialog> createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<ShareListDialog> {
  final TextEditingController _emailController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailValid = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current list values - in a real app, you'd fetch the is_public status
    _isPublic = false; // Default to private
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      _emailValid = email.isNotEmpty && emailRegex.hasMatch(email);
    });
  }

  Future<void> _shareWithEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<PlaceListService>(context, listen: false)
          .shareListWithUser(widget.list.id, email);

      if (mounted) {
        // Close dialog and show success message
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List shared with $email')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to share list: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVisibility(bool isPublic) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<PlaceListService>(context, listen: false)
          .setListVisibility(widget.list.id, isPublic);

      setState(() {
        _isPublic = isPublic;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('List is now ${isPublic ? 'public' : 'private'}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update visibility: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.share),
                const SizedBox(width: 8),
                Text(
                  'Share "${widget.list.name}"',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Public/Private toggle
            SwitchListTile(
              title: const Text('Make list public'),
              subtitle:
                  const Text('Public lists can be discovered by users nearby'),
              value: _isPublic,
              onChanged: _isLoading ? null : _updateVisibility,
            ),

            const SizedBox(height: 16),

            // Share with specific user
            const Text(
              'Share with a specific person:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter email to share with',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: _validateEmail,
            ),

            const SizedBox(height: 8),

            // Error message if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 16),

            // Share button
            ElevatedButton(
              onPressed: _isLoading || !_emailValid ? null : _shareWithEmail,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Share via Email'),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension method for showing the share dialog
extension ShareListExt on BuildContext {
  Future<void> showShareDialog(PlaceList list) async {
    return showDialog(
      context: this,
      builder: (context) => ShareListDialog(list: list),
    );
  }
}
