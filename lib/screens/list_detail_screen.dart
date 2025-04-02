import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/place_list_service.dart';
import 'list_map_screen.dart';

class ListDetailScreen extends StatefulWidget {
  final PlaceList list;

  const ListDetailScreen({
    Key? key,
    required this.list,
  }) : super(key: key);

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late PlaceList _currentList;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _nameController = TextEditingController(text: _currentList.name);
    _descriptionController =
        TextEditingController(text: _currentList.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final description = _descriptionController.text.trim();

    final updatedList = PlaceList(
      id: _currentList.id,
      name: name,
      description: description.isNotEmpty ? description : null,
      places: _currentList.places,
    );

    await Provider.of<PlaceListService>(context, listen: false)
        .updateList(updatedList);

    setState(() {
      _currentList = updatedList;
      _isEditing = false;
    });
  }

  Future<void> _removePlaceFromList(Place place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Place'),
        content: Text('Remove "${place.name}" from this list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<PlaceListService>(context, listen: false)
          .removePlaceFromList(_currentList.id, place.id);

      // Refresh the list
      final updatedList = Provider.of<PlaceListService>(context, listen: false)
          .lists
          .firstWhere((list) => list.id == _currentList.id);

      setState(() {
        _currentList = updatedList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isEditing ? Text(_currentList.name) : const Text('Edit List'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListMapScreen(list: _currentList),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildListDetails(),
    );
  }

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'List Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _nameController.text = _currentList.name;
                    _descriptionController.text =
                        _currentList.description ?? '';
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentList.description != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _currentList.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Places (${_currentList.places.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: _currentList.places.isEmpty
              ? const Center(
                  child: Text('No places in this list yet'),
                )
              : ListView.builder(
                  itemCount: _currentList.places.length,
                  itemBuilder: (context, index) {
                    final place = _currentList.places[index];
                    return Dismissible(
                      key: Key(place.id),
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
                            title: const Text('Remove Place'),
                            content:
                                Text('Remove "${place.name}" from this list?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _removePlaceFromList(place);
                      },
                      child: ListTile(
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removePlaceFromList(place),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
