import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';
import '../services/place_list_service.dart';
import '../services/auth_service.dart';
import 'list_detail_screen.dart';
import 'list_map_screen.dart';

class SavedListsScreen extends StatefulWidget {
  const SavedListsScreen({super.key});

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

  bool _isRefreshing = false;
  bool _isCreatingList = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _newListController.dispose();
    _newListDescriptionController.dispose();
    _newCategoryNameController.dispose();
    _newCategoryDescController.dispose();
    super.dispose();
  }

  /// Initialize data when screen loads
  Future<void> _initializeData() async {
    // Check if user is authenticated
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      setState(() {
        _errorMessage = 'Please sign in to view your lists';
      });
      return;
    }

    await _refreshLists();
  }

  /// Refresh lists from Supabase
  Future<void> _refreshLists() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      await Provider.of<PlaceListService>(context, listen: false).loadLists();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load lists: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Show dialog to create a new list
  void _showCreateListDialog() {
    // Reset the state
    _newListController.clear();
    _newListDescriptionController.clear();
    _newListRatingCategories.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New List'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // List name field
                  TextField(
                    controller: _newListController,
                    decoration: const InputDecoration(
                      labelText: 'List Name',
                      hintText: 'e.g., Best Ramen Places',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: _newListDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g., My favorite places for authentic ramen',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Rating Categories Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rating Categories:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        onPressed: () => _showAddCategoryDialog(setState),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Categories list or empty state
                  if (_newListRatingCategories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.category_outlined,
                              size: 32, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No categories added yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Add categories to rate places on specific attributes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _newListRatingCategories.length,
                        itemBuilder: (context, index) {
                          final category = _newListRatingCategories[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: category.description != null
                                  ? Text(
                                      category.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                tooltip: 'Remove category',
                                onPressed: () {
                                  setState(() {
                                    _newListRatingCategories.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    _isCreatingList ? null : () => _createNewList(context),
                child: _isCreatingList
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Create a new list with Supabase integration
  Future<void> _createNewList(BuildContext dialogContext) async {
    final name = _newListController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a list name');
      return;
    }

    setState(() {
      _isCreatingList = true;
    });

    try {
      // Check authentication
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        throw Exception('Please sign in to create lists');
      }

      final description = _newListDescriptionController.text.trim();
      final listService = Provider.of<PlaceListService>(context, listen: false);

      // Create the list in Supabase
      await listService.createList(
        name,
        description.isNotEmpty ? description : null,
        _newListRatingCategories.isNotEmpty ? _newListRatingCategories : null,
      );

      // Close dialog and show success message
      if (mounted) {
        Navigator.pop(dialogContext);
        _showSnackBar('Created list "$name" successfully');

        // Clear the form data
        _newListController.clear();
        _newListDescriptionController.clear();
        _newListRatingCategories.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error creating list: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingList = false;
        });
      }
    }
  }

  /// Show dialog to add a rating category
  void _showAddCategoryDialog(StateSetter dialogSetState) {
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
              autofocus: true,
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
          ElevatedButton(
            onPressed: () {
              final name = _newCategoryNameController.text.trim();
              if (name.isEmpty) {
                _showSnackBar('Please enter a category name');
                return;
              }

              final description = _newCategoryDescController.text.trim();

              dialogSetState(() {
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

  /// Confirm and delete a list
  Future<void> _confirmDeleteList(PlaceList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${list.name}"?'),
            const SizedBox(height: 8),
            if (list.entries.isNotEmpty)
              Text(
                'This will permanently remove ${list.entries.length} places from this list.',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteList(list);
    }
  }

  /// Delete a list from Supabase
  Future<void> _deleteList(PlaceList list) async {
    try {
      _showLoadingDialog('Deleting list...');

      await Provider.of<PlaceListService>(context, listen: false)
          .deleteList(list.id);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Deleted "${list.name}" successfully');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Error deleting list: ${e.toString()}');
      }
    }
  }

  /// Show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Generate list summary text
  String _getListSummary(PlaceList list) {
    final placesCount = list.entries.length;
    final ratedPlacesCount =
        list.entries.where((entry) => entry.ratings.isNotEmpty).length;
    final categoriesCount = list.ratingCategories.length;

    final buffer = StringBuffer();

    if (placesCount == 0) {
      buffer.write('Empty list');
    } else if (placesCount == 1) {
      buffer.write('1 place');
    } else {
      buffer.write('$placesCount places');
    }

    if (categoriesCount > 0) {
      buffer.write(
          ' • $categoriesCount rating categor${categoriesCount == 1 ? 'y' : 'ies'}');
    }

    if (ratedPlacesCount > 0) {
      buffer.write(' • $ratedPlacesCount rated');
    }

    return buffer.toString();
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No saved lists yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first list to start saving places',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateListDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First List'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state widget
  Widget _buildError(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Lists',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshLists,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build authentication error widget
  Widget _buildAuthError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to view and manage your saved lists',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.orange[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to login screen
                // This depends on your navigation structure
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual list card
  Widget _buildListCard(PlaceList list) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListDetailScreen(list: list),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // List icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.list,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // List name and actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getListSummary(list),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'map':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListMapScreen(list: list),
                            ),
                          );
                          break;
                        case 'delete':
                          _confirmDeleteList(list);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'map',
                        child: Row(
                          children: [
                            Icon(Icons.map_outlined),
                            SizedBox(width: 8),
                            Text('View on Map'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete List',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),

              // Description
              if (list.description != null && list.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  list.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Rating categories chips
              if (list.ratingCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: list.ratingCategories.take(3).map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (list.ratingCategories.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${list.ratingCategories.length - 3} more categories',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Lists'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refreshLists,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New List',
            onPressed: _showCreateListDialog,
          ),
        ],
      ),
      body: Consumer2<PlaceListService, AuthService>(
        builder: (context, listService, authService, child) {
          // Check authentication first
          if (!authService.isAuthenticated) {
            return _buildAuthError();
          }

          // Show loading spinner when first loading
          if (listService.isLoading && !_isRefreshing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your lists...'),
                ],
              ),
            );
          }

          // Show error if there is one
          if (_errorMessage != null || listService.error != null) {
            return _buildError(_errorMessage ?? listService.error!);
          }

          final lists = listService.lists;

          // Show empty state if no lists
          if (lists.isEmpty) {
            return _buildEmptyState();
          }

          // Show list of lists with pull-to-refresh
          return RefreshIndicator(
            onRefresh: _refreshLists,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                return Dismissible(
                  key: Key(list.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete List'),
                        content: Text(
                          'Are you sure you want to delete "${list.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    _deleteList(list);
                  },
                  child: _buildListCard(list),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateListDialog,
        tooltip: 'Create new list',
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }
}
