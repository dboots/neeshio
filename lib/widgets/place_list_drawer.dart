import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';
import '../services/place_list_service.dart';
import '../widgets/rating_category_form_dialog.dart';
import '../widgets/star_rating_widget.dart';

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
  final Map<String, int> _selectedRatings = {}; // categoryId -> rating value
  final _uuid = const Uuid();

  // For new list creation with rating categories
  final List<RatingCategory> _newListRatingCategories = [];
  final _newCategoryNameController = TextEditingController();
  final _newCategoryDescController = TextEditingController();

  @override
  void dispose() {
    _newListController.dispose();
    _newListDescriptionController.dispose();
    _newCategoryNameController.dispose();
    _newCategoryDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
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

  Widget _buildHeader(PlaceList? list) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                list == null ? 'Add to List' : 'Add to ${list.name}',
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
        ],
      ),
    );
  }

  Widget _buildRatingSelector(PlaceList list, PlaceEntry? existingEntry) {
    // Initialize ratings with existing values if place is already in list
    if (existingEntry != null && _selectedRatings.isEmpty) {
      for (final rating in existingEntry.ratings) {
        _selectedRatings[rating.categoryId] = rating.value;
      }
    }

    if (list.ratingCategories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('This list has no rating categories defined.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...list.ratingCategories
              .map((category) => _buildCategoryRating(list, category)),
          const SizedBox(height: 8),
          // Add a "Clear all ratings" button if there are any ratings
          if (_selectedRatings.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedRatings.clear();
                });
              },
              child: const Text('Clear All Ratings'),
            ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryRating(PlaceList list, RatingCategory category) {
    final rating = _selectedRatings[category.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                category.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (category.description != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: category.description!,
                  child: const Icon(Icons.info_outline, size: 16),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          StarRatingWidget(
            rating: rating,
            size: 32,
            onRatingChanged: (value) {
              setState(() {
                if (_selectedRatings[category.id] == value) {
                  // Tap again on the same star to clear the rating
                  _selectedRatings.remove(category.id);
                } else {
                  _selectedRatings[category.id] = value;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewListForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(null),
            Text(
              'Create a New List',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newListController,
              decoration: const InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., Best Ramen Places',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newListDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., Places with great ramen dishes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Rating Categories Section
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rating Categories',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Show list of added categories
            if (_newListRatingCategories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Add categories to rate places on specific attributes',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey),
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
                    title: Text(category.name),
                    subtitle: category.description != null
                        ? Text(category.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          _newListRatingCategories.removeAt(index);
                        });
                      },
                    ),
                  );
                },
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
                      _newListRatingCategories.clear();
                      _selectedRatings.clear();
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
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => RatingCategoryFormDialog(
        onSave: (name, description) {
          setState(() {
            _newListRatingCategories.add(
              RatingCategory(
                id: _uuid.v4(),
                name: name,
                description: description,
              ),
            );
          });
        },
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

    // Create new list with rating categories
    final newList = await listService.createList(
      name,
      description.isNotEmpty ? description : null,
      _newListRatingCategories,
    );

    // Convert selected ratings to RatingValue objects
    final ratings = _selectedRatings.entries
        .map((entry) => RatingValue(
              categoryId: entry.key,
              value: entry.value,
            ))
        .toList();

    // Add place with ratings
    await listService.addPlaceToList(
      newList.id,
      widget.place,
      ratings: ratings.isNotEmpty ? ratings : null,
    );

    // Reset form
    setState(() {
      _isCreatingNewList = false;
      _newListController.clear();
      _newListDescriptionController.clear();
      _newListRatingCategories.clear();
      _selectedRatings.clear();
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
          return Column(
            children: [
              _buildHeader(null),
              const Expanded(
                child: Center(
                  child: Text('No lists yet. Create your first list!'),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildHeader(null),
            Expanded(
              child: ListView.builder(
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final isInList = listsWithPlace.any((l) => l.id == list.id);

                  // Find the entry if this place is in the list
                  PlaceEntry? existingEntry;
                  if (isInList) {
                    existingEntry = list.findEntryById(widget.place.id);
                  }

                  return ExpansionTile(
                    title: Text(list.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (list.description != null)
                          Text(list.description!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (isInList &&
                            existingEntry != null &&
                            existingEntry.ratings.isNotEmpty)
                          Text(
                            'Rated: ${existingEntry.ratings.length} categories',
                            style: const TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: isInList
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.add_circle_outline),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            // Show rating categories for this list
                            if (list.ratingCategories.isNotEmpty)
                              _buildRatingSelector(list, existingEntry),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isInList)
                                  TextButton(
                                    onPressed: () => _removeFromList(list),
                                    child: const Text('Remove from List'),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => _addToList(list),
                                    child: const Text('Add to List'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToList(PlaceList list) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);
    // Convert selected ratings to RatingValue objects
    final ratings = _selectedRatings.entries
        .map((entry) => RatingValue(
              categoryId: entry.key,
              value: entry.value,
            ))
        .toList();
    // Add place with ratings
    await listService.addPlaceToList(
      list.id,
      widget.place,
      ratings: ratings.isNotEmpty ? ratings : null,
    );

  
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to "${list.name}" list')),
      );
      // Clear selections for next operation
      setState(() {
        _selectedRatings.clear();
      });
    }
  }

  Future<void> _removeFromList(PlaceList list) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);
    await listService.removePlaceFromList(list.id, widget.place.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed from "${list.name}" list')),
      );
      // Clear selections for next operation
      setState(() {
        _selectedRatings.clear();
      });
    }
  }
}
