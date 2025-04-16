import 'package:flutter/material.dart';

/// A floating action button for searching places
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
