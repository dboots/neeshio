import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';
import '../services/place_list_service.dart';
import 'list_detail_screen.dart';
import 'list_map_screen.dart';

class SavedListsScreen extends StatefulWidget {
  const SavedListsScreen({Key? key}) : super(key: key);

  @override
  State<SavedListsScreen> createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _newListController = TextEditingController();
  final TextEditingController _newListDescriptionController =
      TextEditingController();

  // For rating categories
  final _uuid = const Uuid();
  final List<RatingCategory> _newListRatingCategories = [];
  final TextEditingController _newCategoryNameController =
      TextEditingController();
  final TextEditingController _newCategoryDescController =
      TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newListController.dispose();
    _newListDescriptionController.dispose();
    _newCategoryNameController.dispose();
    _newCategoryDescController.dispose();
    super.dispose();
  }

  void _showCreateListDialog() {
    // Reset the state
    _newListController.clear();
    _newListDescriptionController.clear();
    _newListRatingCategories.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Create New List'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _newListController,
                  decoration: const InputDecoration(
                    labelText: 'List Name',
                    hintText: 'e.g., Best Ramen Places',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newListDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., My favorite places for authentic ramen',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Rating Categories Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rating Categories:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // TextButton.icon(
                    //   icon: const Icon(Icons.add, size: 18),
                    //   label: const Text('Add'),
                    //   onPressed: () => _showAddCategoryDialog(setState),
                    // ),
                  ],
                ),

                if (_newListRatingCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'No categories added yet. Add categories to rate places on specific attributes.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _newListRatingCategories.length,
                    itemBuilder: (context, index) {
                      final category = _newListRatingCategories[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(category.name),
                        subtitle: category.description != null
                            ? Text(
                                category.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              _newListRatingCategories.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = _newListController.text.trim();
                if (name.isEmpty) return;

                final description = _newListDescriptionController.text.trim();

                await Provider.of<PlaceListService>(context, listen: false)
                    .createList(
                  name,
                  description.isNotEmpty ? description : null,
                  _newListRatingCategories.isNotEmpty
                      ? _newListRatingCategories
                      : null,
                );

                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      }),
    );
  }

  void _showAddCategoryDialog(StateSetter setState) {
    _newCategoryNameController.clear();
    _newCategoryDescController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Rating Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCategoryNameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Broth, Noodles, Service',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newCategoryDescController,
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
              final name = _newCategoryNameController.text.trim();
              if (name.isEmpty) return;

              final description = _newCategoryDescController.text.trim();

              setState(() {
                _newListRatingCategories.add(
                  RatingCategory(
                    id: _uuid.v4(),
                    name: name,
                    description: description.isNotEmpty ? description : null,
                  ),
                );
              });

              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteList(BuildContext context, PlaceList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        await Provider.of<PlaceListService>(context, listen: false)
            .deleteList(list.id);
      }
    }
  }

  String _getListSummary(PlaceList list) {
    final placesCount = list.entries.length;
    final ratedPlacesCount =
        list.entries.where((entry) => entry.ratings.isNotEmpty).length;
    final categoriesCount = list.ratingCategories.length;

    final buffer = StringBuffer('$placesCount places');

    if (categoriesCount > 0) {
      buffer.write(' • $categoriesCount categories');
    }

    if (ratedPlacesCount > 0) {
      buffer.write(' • $ratedPlacesCount rated');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateListDialog,
          ),
        ],
      ),
      body: Consumer<PlaceListService>(
        builder: (context, listService, child) {
          final lists = listService.lists;

          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No saved lists yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create a List'),
                    onPressed: _showCreateListDialog,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Dismissible(
                key: Key(list.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete List'),
                      content: Text(
                          'Are you sure you want to delete "${list.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  Provider.of<PlaceListService>(context, listen: false)
                      .deleteList(list.id);
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      list.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (list.description != null &&
                            list.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Text(
                              list.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(_getListSummary(list)),

                        // Show category chips if there are any
                        if (list.ratingCategories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 0,
                              children: list.ratingCategories.map((category) {
                                return Chip(
                                  label: Text(
                                    category.name,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: list.description != null &&
                        list.description!.isNotEmpty,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.list, color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.map_outlined),
                          tooltip: 'View on map',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ListMapScreen(list: list),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete list',
                          onPressed: () => _confirmDeleteList(context, list),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListDetailScreen(list: list),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateListDialog,
        tooltip: 'Create new list',
        child: const Icon(Icons.add),
      ),
    );
  }
}
