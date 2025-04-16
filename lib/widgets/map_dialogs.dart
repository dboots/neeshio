import 'package:flutter/material.dart';

/// Dialog for entering a name for a custom pin
class PinNameDialog extends StatelessWidget {
  final TextEditingController controller;

  const PinNameDialog({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this pin'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter a name for this location',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Shows a dialog to enter a pin name and returns the entered name
Future<String?> showPinNameDialog(BuildContext context) async {
  final nameController = TextEditingController();
  
  try {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => PinNameDialog(controller: nameController),
    );
    return result;
  } finally {
    nameController.dispose();
  }
}
