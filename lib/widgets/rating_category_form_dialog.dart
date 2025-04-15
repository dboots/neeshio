import 'package:flutter/material.dart';
import '../models/place_rating.dart';

class RatingCategoryFormDialog extends StatefulWidget {
  final RatingCategory? existingCategory;
  final Function(String name, String? description) onSave;
  final String title;
  final String saveButtonText;

  const RatingCategoryFormDialog({
    super.key,
    this.existingCategory,
    required this.onSave,
    this.title = 'Add Rating Category',
    this.saveButtonText = 'Add',
  });

  @override
  State<RatingCategoryFormDialog> createState() =>
      _RatingCategoryFormDialogState();
}

class _RatingCategoryFormDialogState extends State<RatingCategoryFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingCategory?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingCategory?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g., Broth, Noodles, Service',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'e.g., Rate the quality of the broth',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final description = _descriptionController.text.trim();

            widget.onSave(
              name,
              description.isNotEmpty ? description : null,
            );

            Navigator.pop(context);
          },
          child: Text(widget.saveButtonText),
        ),
      ],
    );
  }
}
