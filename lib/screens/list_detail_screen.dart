import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';
import '../services/place_list_service.dart';
import 'list_map_screen.dart';
import 'map_screen.dart';
import 'place_detail_screen.dart';
import '../widgets/rating_category_form_dialog.dart';
import '../widgets/star_rating_widget.dart';

// Import the share dialog functionality
import '../widgets/share_list_dialog.dart';

class ListDetailScreen extends StatefulWidget {
  final PlaceList list;

  const ListDetailScreen({
    super.key,
    required this.list,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late PlaceList _currentList;
  bool _isEditing = false;
  bool _isEditingCategories = false;
  bool _isListPublic = false; // Track list visibility
  bool _isLoading = false;

  // For adding new rating categories
  final _uuid = const Uuid();
  final TextEditingController _newCategoryNameController =
      TextEditingController();
  final TextEditingController _newCategoryDescController =
      TextEditingController();
  // Store categories to be removed
  final List<String> _categoriesToRemove = [];

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _nameController = TextEditingController(text: _currentList.name);
    _descriptionController =
        TextEditingController(text: _currentList.description ?? '');
    _fetchListVisibility();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _newCategoryNameController.dispose();
    _newCategoryDescController.dispose();
    super.dispose();
  }

  // Fetch the list's public/private status
  Future<void> _fetchListVisibility() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // In a real implementation, you would fetch this from Supabase
      // For now, we'll simulate it with a delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Set a default value (in a real app, get from Supabase)
      setState(() {
        _isListPublic = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching list details: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final description = _descriptionController.text.trim();

    final updatedList = PlaceList(
      id: _currentList.id,
      name: name,
      description: description.isNotEmpty ? description : null,
      entries: _currentList.entries,
      ratingCategories: _currentList.ratingCategories,
    );

    await Provider.of<PlaceListService>(context, listen: false)
        .updateList(updatedList);

    setState(() {
      _currentList = updatedList;
      _isEditing = false;
    });
  }

  Future<void> _saveRatingCategories() async {
    final listService = Provider.of<PlaceListService>(context, listen: false);

    // Process categories to remove
    for (final categoryId in _categoriesToRemove) {
      await listService.removeRatingCategory(_currentList.id, categoryId);
    }

    // Refresh the list
    final updatedList =
        listService.lists.firstWhere((list) => list.id == _currentList.id);

    setState(() {
      _currentList = updatedList;
      _isEditingCategories = false;
      _categoriesToRemove.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating categories updated')),
    );
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

  Future<void> _updateRating(
      String placeId, String categoryId, int rating) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);

    await listService.updatePlaceRating(
        _currentList.id, placeId, categoryId, rating);

    // Refresh the list
    final updatedList =
        listService.lists.firstWhere((list) => list.id == _currentList.id);

    setState(() {
      _currentList = updatedList;
    });
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => RatingCategoryFormDialog(
        title: 'Add Rating Category',
        saveButtonText: 'Add',
        onSave: (name, description) async {
          final newCategory = RatingCategory(
            id: _uuid.v4(),
            name: name,
            description: description,
          );

          // Add to the list
          final listService =
              Provider.of<PlaceListService>(context, listen: false);
          await listService.addRatingCategory(_currentList.id, newCategory);

          // Refresh the list
          final updatedList = listService.lists
              .firstWhere((list) => list.id == _currentList.id);

          setState(() {
            _currentList = updatedList;
          });
        },
      ),
    );
  }

  // Show sharing dialog
  void _showShareDialog() {
    context.showShareDialog(_currentList);
  }

  // Toggle list visibility (public/private)
  Future<void> _toggleVisibility() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Update visibility in Supabase
      await Provider.of<PlaceListService>(context, listen: false)
          .setListVisibility(_currentList.id, !_isListPublic);

      setState(() {
        _isListPublic = !_isListPublic;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('List is now ${_isListPublic ? 'public' : 'private'}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating visibility: $e')),
        );
      }
    }
  }

  // Navigate to the map screen to add a place to the list
  void _navigateToMapToAddPlace() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(selectedListId: _currentList.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isEditing && !_isEditingCategories
            ? Text(_currentList.name)
            : _isEditing
                ? const Text('Edit List')
                : const Text('Edit Rating Categories'),
        actions: [
          if (!_isEditing && !_isEditingCategories) ...[
            // Share button
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share List',
              onPressed: _showShareDialog,
            ),
            // Public/Private toggle
            IconButton(
              icon: Icon(_isListPublic ? Icons.public : Icons.public_off),
              tooltip: _isListPublic ? 'Make Private' : 'Make Public',
              onPressed: _isLoading ? null : _toggleVisibility,
            ),
            IconButton(
              icon: const Icon(Icons.category),
              tooltip: 'Edit Rating Categories',
              onPressed: () {
                setState(() {
                  _isEditingCategories = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit List',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'View on Map',
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
        ],
      ),
      body: _isEditing
          ? _buildEditForm()
          : _isEditingCategories
              ? _buildEditCategories()
              : _buildListDetails(),
      floatingActionButton: !_isEditing && !_isEditingCategories
          ? FloatingActionButton(
              onPressed: _navigateToMapToAddPlace,
              tooltip: 'Add Place to List',
              child: const Icon(Icons.add_location_alt),
            )
          : null,
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

  Widget _buildEditCategories() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rating Categories',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
                onPressed: _showAddCategoryDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentList.ratingCategories.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No rating categories defined yet.\nAdd some categories to rate places on specific attributes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _currentList.ratingCategories.length,
                itemBuilder: (context, index) {
                  final category = _currentList.ratingCategories[index];
                  final isMarkedForRemoval =
                      _categoriesToRemove.contains(category.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isMarkedForRemoval ? Colors.red.shade50 : null,
                    child: ListTile(
                      title: Text(
                        category.name,
                        style: TextStyle(
                          decoration: isMarkedForRemoval
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: category.description != null
                          ? Text(
                              category.description!,
                              style: TextStyle(
                                decoration: isMarkedForRemoval
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: Icon(
                          isMarkedForRemoval
                              ? Icons.restore
                              : Icons.delete_outline,
                          color: isMarkedForRemoval ? Colors.green : Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isMarkedForRemoval) {
                              _categoriesToRemove.remove(category.id);
                            } else {
                              _categoriesToRemove.add(category.id);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingCategories = false;
                    _categoriesToRemove.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _saveRatingCategories,
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
        if (_isListPublic)
          Container(
            color: Colors.green.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'This list is public',
                  style: TextStyle(color: Colors.green),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _toggleVisibility,
                  child: const Text('Make Private'),
                ),
              ],
            ),
          ),
        if (_currentList.description != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _currentList.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Places (${_currentList.entries.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_currentList.ratingCategories.isNotEmpty)
                Text(
                  'Rating Categories: ${_currentList.ratingCategories.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (_currentList.ratingCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: _currentList.ratingCategories.map((category) {
                return Chip(
                  label:
                      Text(category.name, style: const TextStyle(fontSize: 12)),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: _currentList.entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No places in this list yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _navigateToMapToAddPlace,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add Places from Map'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _currentList.entries.length,
                  itemBuilder: (context, index) {
                    final entry = _currentList.entries[index];
                    final place = entry.place;

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
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  place.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(place.address),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      tooltip: 'View Details',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaceDetailScreen(
                                              list: _currentList,
                                              place: place,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Remove from List',
                                      onPressed: () =>
                                          _removePlaceFromList(place),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaceDetailScreen(
                                        list: _currentList,
                                        place: place,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Display ratings for each category
                              if (_currentList.ratingCategories.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const Text(
                                        'Ratings:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._currentList.ratingCategories
                                          .map((category) {
                                        final rating =
                                            entry.getRating(category.id);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    category.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                  if (category.description !=
                                                      null) ...[
                                                    const SizedBox(width: 4),
                                                    Tooltip(
                                                      message:
                                                          category.description!,
                                                      child: const Icon(
                                                          Icons.info_outline,
                                                          size: 16),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              StarRatingWidget(
                                                rating: rating ?? 0,
                                                size: 24,
                                                onRatingChanged: (value) =>
                                                    _updateRating(
                                                  place.id,
                                                  category.id,
                                                  value,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                      // Show average rating if there are actual ratings
                                      if (entry.ratings.isNotEmpty) ...[
                                        const Divider(),
                                        Row(
                                          children: [
                                            const Text(
                                              'Average Rating:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 8),
                                            StarRatingDisplay(
                                              rating:
                                                  entry.getAverageRating() ?? 0,
                                              color: Colors.amber[800]!,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    'No rating categories defined for this list.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 8),
                            ],
                          ),
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
