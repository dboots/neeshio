import 'package:flutter/material.dart';
import '../models/place_list.dart';

/// A banner that appears at the top of the map in different modes
class MapBanner extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;

  const MapBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A banner specifically for the "add to list" mode
class AddToListBanner extends StatelessWidget {
  final PlaceList list;

  const AddToListBanner({
    super.key,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return MapBanner(
      message: 'Tap on places to add them to "${list.name}"',
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      textColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}

/// A banner for the pin adding mode
class AddPinBanner extends StatelessWidget {
  const AddPinBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapBanner(
      message: 'Tap on the map to add a pin',
      backgroundColor: Colors.black87,
    );
  }
}

/// A floating action button for adding a place to a list
class AddToListButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String listName;

  const AddToListButton({
    super.key,
    required this.onPressed,
    required this.listName,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: 'Add to $listName',
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A floating action button for searching
class SearchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SearchButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: 'Search',
        child: const Icon(Icons.search),
      ),
    );
  }
}

/// A dialog for naming a custom pin
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
