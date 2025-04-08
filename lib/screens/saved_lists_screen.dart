import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
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

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newListController.dispose();
    _newListDescriptionController.dispose();
    super.dispose();
  }

  void _showCreateListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newListController,
              decoration: const InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., Best Coffee Shops',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newListDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., My favorite places for coffee',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newListController.clear();
              _newListDescriptionController.clear();
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
              );

              Navigator.pop(context);
              _newListController.clear();
              _newListDescriptionController.clear();
            },
            child: const Text('Create'),
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

  String _getRatingsSummary(List<PlaceEntry> entries) {
    final ratedEntries = entries.where((entry) => entry.rating != null).length;
    if (ratedEntries == 0) {
      return '';
    }
    return ' • $ratedEntries rated';
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
                        Text(
                            '${list.entries.length} places${_getRatingsSummary(list.entries)}'),
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
