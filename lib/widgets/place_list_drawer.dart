import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/place_list_service.dart';

class PlaceListDrawer extends StatefulWidget {
  final Place place;
  final VoidCallback? onClose;

  const PlaceListDrawer({
    super.key,
    required this.place,
    this.onClose,
  });

  @override
  State<PlaceListDrawer> createState() => _PlaceListDrawerState();
}

class _PlaceListDrawerState extends State<PlaceListDrawer> {
  final _newListController = TextEditingController();
  final _newListDescriptionController = TextEditingController();
  bool _isCreatingNewList = false;

  @override
  void dispose() {
    _newListController.dispose();
    _newListDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isCreatingNewList 
                ? _buildCreateNewListForm() 
                : _buildExistingLists(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add to List',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.place.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.place.address,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create New List'),
            onPressed: () {
              setState(() {
                _isCreatingNewList = true;
              });
            },
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildCreateNewListForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create a New List',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newListController,
            decoration: const InputDecoration(
              labelText: 'List Name',
              hintText: 'e.g., Best Sourdough',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newListDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'e.g., Places with great sourdough bread',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCreatingNewList = false;
                    _newListController.clear();
                    _newListDescriptionController.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _createNewList(),
                child: const Text('Create & Add Place'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createNewList() async {
    final name = _newListController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final description = _newListDescriptionController.text.trim();
    final listService = Provider.of<PlaceListService>(context, listen: false);
    
    // Create new list and add place
    final newList = await listService.createList(
      name, 
      description.isNotEmpty ? description : null,
    );
    await listService.addPlaceToList(newList.id, widget.place);
    
    // Reset form
    setState(() {
      _isCreatingNewList = false;
      _newListController.clear();
      _newListDescriptionController.clear();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to "$name" list')),
      );
    }
  }

  Widget _buildExistingLists() {
    return Consumer<PlaceListService>(
      builder: (context, listService, child) {
        final lists = listService.lists;
        final listsWithPlace = listService.getListsWithPlace(widget.place.id);
        
        if (lists.isEmpty) {
          return const Center(
            child: Text('No lists yet. Create your first list!'),
          );
        }

        return ListView.builder(
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final list = lists[index];
            final isInList = listsWithPlace.any((l) => l.id == list.id);

            return ListTile(
              title: Text(list.name),
              subtitle: list.description != null 
                ? Text(list.description!, maxLines: 1, overflow: TextOverflow.ellipsis) 
                : null,
              trailing: isInList
                ? IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _removeFromList(list),
                  )
                : IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _addToList(list),
                  ),
            );
          },
        );
      },
    );
  }

  Future<void> _addToList(PlaceList list) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);
    await listService.addPlaceToList(list.id, widget.place);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to "${list.name}" list')),
      );
    }
  }

  Future<void> _removeFromList(PlaceList list) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);
    await listService.removePlaceFromList(list.id, widget.place.id);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed from "${list.name}" list')),
      );
    }
  }
}