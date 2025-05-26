import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/place_list.dart';
import '../models/place_rating.dart';

class PlaceListService extends ChangeNotifier {
  List<PlaceList> _lists = [];
  List<PlaceList> _sharedLists = [];
  bool _isLoading = false;
  String? _error;

  List<PlaceList> get lists => _lists;
  List<PlaceList> get sharedLists => _sharedLists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _uuid = const Uuid();
  final _supabase = Supabase.instance.client;

  /// Clear all data when user signs out
  void clearData() {
    _lists = [];
    _sharedLists = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Load all lists (owned and shared) from Supabase
  Future<void> loadLists() async {
    try {
      _setLoading(true);
      _clearError();

      // Check authentication
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load owned lists and shared lists in parallel
      await Future.wait([
        _loadOwnedLists(userId),
        _loadSharedLists(),
      ]);
    } catch (e) {
      _setError('Failed to load lists: ${e.toString()}');
      if (kDebugMode) {
        print('Error loading lists: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Load lists owned by the current user
  Future<void> _loadOwnedLists(String userId) async {
    try {
      // Query all lists owned by the user
      final listsResponse = await _supabase
          .from('place_lists')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final loadedLists = <PlaceList>[];

      // Load detailed data for each list
      for (final listData in listsResponse) {
        try {
          final placeList = await _loadListWithDetails(listData['id']);
          if (placeList != null) {
            loadedLists.add(placeList);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading list ${listData['id']}: $e');
          }
          // Continue loading other lists even if one fails
        }
      }

      _lists = loadedLists;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading owned lists: $e');
      }
      rethrow;
    }
  }

  /// Load lists shared with the current user
  Future<void> _loadSharedLists() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user?.email == null) return;

      // Get lists shared with the user's email
      final sharesResponse = await _supabase.from('shares').select('''
            list_id,
            place_lists!inner(*)
          ''').eq('email', user!.email!);

      final loadedSharedLists = <PlaceList>[];

      for (final shareData in sharesResponse) {
        try {
          final listId = shareData['list_id'];
          final placeList = await _loadListWithDetails(listId);
          if (placeList != null) {
            loadedSharedLists.add(placeList);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading shared list: $e');
          }
        }
      }

      _sharedLists = loadedSharedLists;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading shared lists: $e');
      }
      // Don't throw error for shared lists, just log it
    }
  }

  /// Load a complete list with all its details
  Future<PlaceList?> _loadListWithDetails(String listId) async {
    try {
      // Get list basic info
      final listResponse = await _supabase
          .from('place_lists')
          .select()
          .eq('id', listId)
          .single();

      // Get rating categories for this list
      final categoriesResponse = await _supabase
          .from('rating_categories')
          .select()
          .eq('list_id', listId)
          .order('name');

      final ratingCategories = categoriesResponse
          .map((category) => RatingCategory(
                id: category['id'],
                name: category['name'],
                description: category['description'],
              ))
          .toList();

      // Get entries (places) in this list with their ratings
      final entriesResponse = await _supabase.from('list_entries').select('''
            *,
            places!inner(*)
          ''').eq('list_id', listId).order('created_at');

      final entries = <PlaceEntry>[];

      for (final entryData in entriesResponse) {
        try {
          final entryId = entryData['id'];
          final placeData = entryData['places'];

          // Get ratings for this entry
          final ratingsResponse = await _supabase
              .from('rating_values')
              .select()
              .eq('entry_id', entryId);

          final ratings = ratingsResponse
              .map((rating) => RatingValue(
                    categoryId: rating['category_id'],
                    value: rating['value'],
                  ))
              .toList();

          // Create Place from place data
          final place = Place(
            id: placeData['id'],
            name: placeData['name'],
            address: placeData['address'],
            lat: placeData['lat']?.toDouble() ?? 0.0,
            lng: placeData['lng']?.toDouble() ?? 0.0,
            image: placeData['image_url'],
            phone: placeData['phone'],
          );

          // Create entry
          final entry = PlaceEntry(
            place: place,
            ratings: ratings,
            notes: entryData['notes'],
          );

          entries.add(entry);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading entry: $e');
          }
          // Continue with other entries
        }
      }

      // Create and return the complete list
      return PlaceList(
        id: listId,
        name: listResponse['name'],
        description: listResponse['description'],
        entries: entries,
        ratingCategories: ratingCategories,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading list details for $listId: $e');
      }
      return null;
    }
  }

  /// Create a new list
  Future<PlaceList> createList(String name,
      [String? description, List<RatingCategory>? ratingCategories]) async {
    try {
      _setLoading(true);
      _clearError();

      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final listId = _uuid.v4();

      // Start a transaction-like approach
      try {
        // Insert list into Supabase with is_public defaulting to false
        await _supabase.from('place_lists').insert({
          'id': listId,
          'user_id': userId,
          'name': name.trim(),
          'description': description?.trim(),
          'is_public': false, // New lists start as private
          'created_at': DateTime.now().toIso8601String(),
        });

        // Insert rating categories if provided
        if (ratingCategories != null && ratingCategories.isNotEmpty) {
          final categoriesData = ratingCategories
              .map((category) => {
                    'id': category.id,
                    'list_id': listId,
                    'name': category.name.trim(),
                    'description': category.description?.trim(),
                    'created_at': DateTime.now().toIso8601String(),
                  })
              .toList();

          await _supabase.from('rating_categories').insert(categoriesData);
        }

        // Create PlaceList object
        final newList = PlaceList(
          id: listId,
          name: name.trim(),
          description: description?.trim(),
          entries: [],
          ratingCategories: ratingCategories ?? [],
        );

        // Add to local cache
        _lists.insert(0, newList); // Add to beginning for recency

        if (kDebugMode) {
          print('Created new list: ${newList.name} (ID: $listId)');
        }

        return newList;
      } catch (e) {
        // If something went wrong, try to cleanup
        try {
          await _supabase.from('place_lists').delete().eq('id', listId);
        } catch (cleanupError) {
          if (kDebugMode) {
            print('Failed to cleanup after create error: $cleanupError');
          }
        }
        rethrow;
      }
    } catch (e) {
      _setError('Failed to create list: ${e.toString()}');
      throw Exception('Failed to create list: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Update a list's basic information
  Future<void> updateList(PlaceList updatedList) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.from('place_lists').update({
        'name': updatedList.name.trim(),
        'description': updatedList.description?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', updatedList.id);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == updatedList.id);
      if (index != -1) {
        _lists[index] = updatedList;
      }
    } catch (e) {
      _setError('Failed to update list: ${e.toString()}');
      throw Exception('Failed to update list: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a list and all its associated data
  Future<void> deleteList(String listId) async {
    try {
      _setLoading(true);
      _clearError();

      // Supabase should handle cascade deletes via foreign key constraints
      // This will delete the list and all related data (entries, ratings, etc.)
      await _supabase.from('place_lists').delete().eq('id', listId);

      // Remove from local cache
      _lists.removeWhere((list) => list.id == listId);
      _sharedLists.removeWhere((list) => list.id == listId);
    } catch (e) {
      _setError('Failed to delete list: ${e.toString()}');
      throw Exception('Failed to delete list: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a rating category to a list
  Future<void> addRatingCategory(String listId, RatingCategory category) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.from('rating_categories').insert({
        'id': category.id,
        'list_id': listId,
        'name': category.name.trim(),
        'description': category.description?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].addRatingCategory(category);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _setError('Failed to add rating category: ${e.toString()}');
      throw Exception('Failed to add rating category: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a rating category from a list
  Future<void> removeRatingCategory(String listId, String categoryId) async {
    try {
      _setLoading(true);
      _clearError();

      // Delete category from Supabase (ratings should cascade delete)
      await _supabase.from('rating_categories').delete().eq('id', categoryId);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].removeRatingCategory(categoryId);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _setError('Failed to remove rating category: ${e.toString()}');
      throw Exception('Failed to remove rating category: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a string is a valid UUID
  bool _isValidUuid(String id) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }

  /// Get or create a place and return the internal UUID
  Future<String> _getOrCreatePlaceId(Place place) async {
    try {
      // If the place ID is already a UUID, check if it exists
      if (_isValidUuid(place.id)) {
        final existingPlace = await _supabase
            .from('places')
            .select('id')
            .eq('id', place.id)
            .maybeSingle();

        if (existingPlace != null) {
          return place.id;
        }
      } else {
        // Check if we already have this external place in our database
        final existingPlace = await _supabase
            .from('places')
            .select('id')
            .eq('external_id', place.id)
            .maybeSingle();

        if (existingPlace != null) {
          return existingPlace['id'];
        }
      }

      // Place doesn't exist, create it
      return await _createPlace(place);
    } catch (e) {
      throw Exception('Failed to get or create place ID: ${e.toString()}');
    }
  }

  /// Create a new place and return its internal UUID
  Future<String> _createPlace(Place place) async {
    try {
      // Generate UUID if needed
      String internalId = _isValidUuid(place.id) ? place.id : _uuid.v4();

      // Validate required fields
      if (place.name.trim().isEmpty) {
        throw Exception('Place name cannot be empty');
      }
      if (place.address.trim().isEmpty) {
        throw Exception('Place address cannot be empty');
      }

      // Prepare the insert data
      final insertData = <String, dynamic>{
        'id': internalId,
        'name': place.name.trim(),
        'address': place.address.trim(),
        'lat': place.lat,
        'lng': place.lng,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add external_id if the original ID was not a UUID
      if (!_isValidUuid(place.id)) {
        insertData['external_id'] = place.id;
      }

      // Only add optional fields if they have values
      if (place.image != null && place.image!.trim().isNotEmpty) {
        insertData['image_url'] = place.image!.trim();
      }
      if (place.phone != null && place.phone!.trim().isNotEmpty) {
        insertData['phone'] = place.phone!.trim();
      }

      // Insert the place
      await _supabase.from('places').insert(insertData);

      if (kDebugMode) {
        print('Successfully created place: ${place.name} with ID: $internalId');
      }

      return internalId;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating place: $e');
        print('Place data: ${place.toJson()}');
      }
      throw Exception('Failed to create place: ${e.toString()}');
    }
  }

  /// Add a place to a list with optional ratings and notes
  Future<void> addPlaceToList(String listId, Place place,
      {List<RatingValue>? ratings, String? notes}) async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        print('Adding place to list: ${place.name} -> List ID: $listId');
        print('Original place ID: ${place.id}');
      }

      // Validate inputs
      if (listId.trim().isEmpty) {
        throw Exception('List ID cannot be empty');
      }

      // Check if the list exists and user has permission
      final listExists = await _supabase
          .from('place_lists')
          .select('id, user_id')
          .eq('id', listId)
          .maybeSingle();

      if (listExists == null) {
        throw Exception('List not found');
      }

      final currentUserId = _getCurrentUserId();
      if (currentUserId != listExists['user_id']) {
        throw Exception('You do not have permission to modify this list');
      }

      // Get or create the place and get the correct internal UUID
      final internalPlaceId = await _getOrCreatePlaceId(place);

      if (kDebugMode) {
        print('Using internal place ID: $internalPlaceId');
      }

      // Check if place is already in the list (using internal ID)
      final existingEntry = await _supabase
          .from('list_entries')
          .select('id')
          .eq('list_id', listId)
          .eq('place_id', internalPlaceId)
          .maybeSingle();

      if (existingEntry != null) {
        throw Exception('Place is already in this list');
      }

      // Create entry using the internal place ID
      final entryId = _uuid.v4();
      final entryData = <String, dynamic>{
        'id': entryId,
        'list_id': listId,
        'place_id': internalPlaceId,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Only add notes if they have content
      if (notes != null && notes.trim().isNotEmpty) {
        entryData['notes'] = notes.trim();
      }

      await _supabase.from('list_entries').insert(entryData);

      if (kDebugMode) {
        print('Successfully created list entry with ID: $entryId');
      }

      // Insert ratings if provided
      if (ratings != null && ratings.isNotEmpty) {
        final ratingsData = ratings
            .where(
                (rating) => rating.value > 0) // Only include non-zero ratings
            .map((rating) => {
                  'id': _uuid.v4(),
                  'entry_id': entryId,
                  'category_id': rating.categoryId,
                  'value': rating.value,
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList();

        if (ratingsData.isNotEmpty) {
          await _supabase.from('rating_values').insert(ratingsData);

          if (kDebugMode) {
            print('Successfully inserted ${ratingsData.length} ratings');
          }
        }
      }

      // Update local cache - create a new Place object with the correct internal ID
      final placeWithCorrectId = Place(
        id: internalPlaceId,
        name: place.name,
        address: place.address,
        lat: place.lat,
        lng: place.lng,
        image: place.image,
        phone: place.phone,
      );

      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].addPlace(
          placeWithCorrectId,
          ratings: ratings?.where((r) => r.value > 0).toList(),
          notes: notes?.trim(),
        );
        _lists[index] = updatedList;

        if (kDebugMode) {
          print('Successfully updated local cache');
        }
      }
    } catch (e) {
      final errorMessage = 'Failed to add place to list: ${e.toString()}';
      _setError(errorMessage);
      if (kDebugMode) {
        print('Error in addPlaceToList: $e');
        print('Place: ${place.toJson()}');
        print('List ID: $listId');
        print('Ratings: ${ratings?.map((r) => r.toJson()).toList()}');
      }
      throw Exception(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a place from a list
  Future<void> removePlaceFromList(String listId, String placeId) async {
    try {
      _setLoading(true);
      _clearError();

      // Delete the entry (ratings should cascade delete)
      await _supabase
          .from('list_entries')
          .delete()
          .eq('list_id', listId)
          .eq('place_id', placeId);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].removePlace(placeId);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _setError('Failed to remove place from list: ${e.toString()}');
      throw Exception('Failed to remove place from list: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Update rating for a place in a list
  Future<void> updatePlaceRating(
      String listId, String placeId, String categoryId, int rating) async {
    try {
      _setLoading(true);
      _clearError();

      // Find the entry
      final entryResponse = await _supabase
          .from('list_entries')
          .select('id')
          .eq('list_id', listId)
          .eq('place_id', placeId)
          .single();

      final entryId = entryResponse['id'];

      // Check if rating already exists
      final existingRating = await _supabase
          .from('rating_values')
          .select('id')
          .eq('entry_id', entryId)
          .eq('category_id', categoryId)
          .maybeSingle();

      if (existingRating != null) {
        // Update existing rating
        await _supabase.from('rating_values').update({
          'value': rating,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingRating['id']);
      } else {
        // Insert new rating
        await _supabase.from('rating_values').insert({
          'id': _uuid.v4(),
          'entry_id': entryId,
          'category_id': categoryId,
          'value': rating,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update local cache
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex != -1) {
        final updatedList =
            _lists[listIndex].updateRating(placeId, categoryId, rating);
        _lists[listIndex] = updatedList;
      }
    } catch (e) {
      _setError('Failed to update rating: ${e.toString()}');
      throw Exception('Failed to update rating: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Update notes for a place in a list
  Future<void> updatePlaceNotes(
      String listId, String placeId, String notes) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase
          .from('list_entries')
          .update({
            'notes': notes.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('list_id', listId)
          .eq('place_id', placeId);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].updateNotes(placeId, notes.trim());
        _lists[index] = updatedList;
      }
    } catch (e) {
      _setError('Failed to update notes: ${e.toString()}');
      throw Exception('Failed to update notes: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Share a list with another user by email
  Future<void> shareListWithUser(String listId, String email) async {
    try {
      _setLoading(true);
      _clearError();

      final sharedBy = _getCurrentUserId();
      if (sharedBy == null) {
        throw Exception('User not authenticated');
      }

      // Check if already shared with this email
      final existingShare = await _supabase
          .from('shares')
          .select('id')
          .eq('list_id', listId)
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (existingShare != null) {
        throw Exception('List is already shared with this email');
      }

      // Insert into shares table
      await _supabase.from('shares').insert({
        'id': _uuid.v4(),
        'list_id': listId,
        'shared_by': sharedBy,
        'email': email.trim().toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _setError('Failed to share list: ${e.toString()}');
      throw Exception('Failed to share list: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Set list visibility (public/private) with notification support
  Future<void> setListVisibility(String listId, bool isPublic) async {
    try {
      _setLoading(true);
      _clearError();

      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify ownership
      final listData = await _supabase
          .from('place_lists')
          .select('user_id, is_public')
          .eq('id', listId)
          .single();

      if (listData['user_id'] != userId) {
        throw Exception('You can only modify your own lists');
      }

      final wasPublic = listData['is_public'] as bool?;

      // Update visibility - this will trigger the database function if becoming public
      await _supabase.from('place_lists').update({
        'is_public': isPublic,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', listId);

      // Log the visibility change
      if (kDebugMode) {
        if (isPublic && (wasPublic != true)) {
          print(
              'List $listId made public - notifications will be triggered by database trigger');
        } else if (!isPublic && (wasPublic == true)) {
          print('List $listId made private');
        }
      }
    } catch (e) {
      _setError('Failed to update list visibility: ${e.toString()}');
      throw Exception('Failed to update list visibility: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Get lists that contain a specific place
  List<PlaceList> getListsWithPlace(String placeId) {
    return _lists
        .where((list) => list.entries.any((entry) => entry.place.id == placeId))
        .toList();
  }

  /// Get the current user ID
  String? _getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _error = null;
  }

  /// Retry last failed operation
  Future<void> retry() async {
    _clearError();
    await loadLists();
  }
}
