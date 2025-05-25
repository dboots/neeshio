import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/place_list.dart';
import '../models/place_rating.dart';

class PlaceListService extends ChangeNotifier {
  List<PlaceList> _lists = [];
  bool _isLoading = false;
  String? _error;

  List<PlaceList> get lists => _lists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _uuid = const Uuid();
  final _supabase = Supabase.instance.client;

  // Load lists from Supabase
  Future<void> loadLists() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // First, query all lists owned by the user
      final listsResponse =
          await _supabase.from('place_lists').select().eq('user_id', userId);

      // Temp storage for loaded lists
      final loadedLists = <PlaceList>[];

      // For each list, load its rating categories and entries
      for (final listData in listsResponse) {
        final listId = listData['id'];

        // Get rating categories for this list
        final categoriesResponse = await _supabase
            .from('rating_categories')
            .select()
            .eq('list_id', listId);

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
              place:places(*)
            ''').eq('list_id', listId);

        final entries = <PlaceEntry>[];

        for (final entryData in entriesResponse) {
          final entryId = entryData['id'];
          final placeData = entryData['place'];

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
            lat: placeData['lat'],
            lng: placeData['lng'],
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
        }

        // Create list
        final placeList = PlaceList(
          id: listId,
          name: listData['name'],
          description: listData['description'],
          entries: entries,
          ratingCategories: ratingCategories,
        );

        loadedLists.add(placeList);
      }

      _lists = loadedLists;
    } catch (e) {
      _error = 'Error loading lists: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new list
  Future<PlaceList> createList(String name,
      [String? description, List<RatingCategory>? ratingCategories]) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Generate ID for the new list
      final listId = _uuid.v4();

      // Insert list into Supabase
      await _supabase.from('place_lists').insert({
        'id': listId,
        'user_id': userId,
        'name': name,
        'description': description,
        'is_public': false, // Default to private list
      });

      // Insert rating categories if provided
      if (ratingCategories != null && ratingCategories.isNotEmpty) {
        final categoriesData = ratingCategories
            .map((category) => {
                  'id': category.id,
                  'list_id': listId,
                  'name': category.name,
                  'description': category.description,
                })
            .toList();

        await _supabase.from('rating_categories').insert(categoriesData);
      }

      // Create PlaceList object
      final newList = PlaceList(
        id: listId,
        name: name,
        description: description,
        entries: [],
        ratingCategories: ratingCategories ?? [],
      );

      // Add to local cache
      _lists.add(newList);
      _isLoading = false;
      notifyListeners();

      return newList;
    } catch (e) {
      _error = 'Error creating list: $e';
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }

  // Update a list
  Future<void> updateList(PlaceList updatedList) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Update list details in Supabase
      await _supabase.from('place_lists').update({
        'name': updatedList.name,
        'description': updatedList.description,
      }).eq('id', updatedList.id);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == updatedList.id);
      if (index != -1) {
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error updating list: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a list
  Future<void> deleteList(String listId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Delete list from Supabase - cascade delete should handle related records
      await _supabase.from('place_lists').delete().eq('id', listId);

      // Remove from local cache
      _lists.removeWhere((list) => list.id == listId);
    } catch (e) {
      _error = 'Error deleting list: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a rating category to a list
  Future<void> addRatingCategory(String listId, RatingCategory category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Insert category in Supabase
      await _supabase.from('rating_categories').insert({
        'id': category.id,
        'list_id': listId,
        'name': category.name,
        'description': category.description,
      });

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].addRatingCategory(category);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error adding rating category: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove a rating category from a list
  Future<void> removeRatingCategory(String listId, String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Delete category from Supabase
      await _supabase.from('rating_categories').delete().eq('id', categoryId);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].removeRatingCategory(categoryId);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error removing rating category: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a place to a list
  Future<void> addPlaceToList(String listId, Place place,
      {List<RatingValue>? ratings, String? notes}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if place already exists in the database
      final placeResponse = await _supabase
          .from('places')
          .select()
          .eq('id', place.id)
          .maybeSingle();

      // If the place doesn't exist, insert it
      if (placeResponse == null) {
        await _supabase.from('places').insert({
          'id': place.id,
          'name': place.name,
          'address': place.address,
          'lat': place.lat,
          'lng': place.lng,
          'image_url': place.image,
          'phone': place.phone,
        });
      }

      // Create a new entry
      final entryId = _uuid.v4();
      await _supabase.from('list_entries').insert({
        'id': entryId,
        'list_id': listId,
        'place_id': place.id,
        'notes': notes,
      });

      // Insert ratings if provided
      if (ratings != null && ratings.isNotEmpty) {
        final ratingsData = ratings
            .map((rating) => {
                  'id': _uuid.v4(),
                  'entry_id': entryId,
                  'category_id': rating.categoryId,
                  'value': rating.value,
                })
            .toList();

        await _supabase.from('rating_values').insert(ratingsData);
      }

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].addPlace(
          place,
          ratings: ratings,
          notes: notes,
        );
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error adding place to list: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update the rating for a category of a place in a list
  Future<void> updatePlaceRating(
      String listId, String placeId, String categoryId, int rating) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Find the entry
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        throw Exception('List not found');
      }

      final entryIndex = _lists[listIndex].entries.indexWhere(
            (entry) => entry.place.id == placeId,
          );
      if (entryIndex == -1) {
        throw Exception('Place not found in list');
      }

      // Find the entry in Supabase
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
          .select()
          .eq('entry_id', entryId)
          .eq('category_id', categoryId)
          .maybeSingle();

      if (existingRating != null) {
        // Update existing rating
        await _supabase
            .from('rating_values')
            .update({'value': rating}).eq('id', existingRating['id']);
      } else {
        // Insert new rating
        await _supabase.from('rating_values').insert({
          'id': _uuid.v4(),
          'entry_id': entryId,
          'category_id': categoryId,
          'value': rating,
        });
      }

      // Update local cache
      final updatedList =
          _lists[listIndex].updateRating(placeId, categoryId, rating);
      _lists[listIndex] = updatedList;
    } catch (e) {
      _error = 'Error updating rating: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update the notes for a place in a list
  Future<void> updatePlaceNotes(
      String listId, String placeId, String notes) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Find the entry in Supabase
      final entryResponse = await _supabase
          .from('list_entries')
          .select('id')
          .eq('list_id', listId)
          .eq('place_id', placeId)
          .single();

      final entryId = entryResponse['id'];

      // Update notes
      await _supabase
          .from('list_entries')
          .update({'notes': notes}).eq('id', entryId);

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].updateNotes(placeId, notes);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error updating notes: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove a place from a list
  Future<void> removePlaceFromList(String listId, String placeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Find the entry in Supabase
      final entryResponse = await _supabase
          .from('list_entries')
          .select('id')
          .eq('list_id', listId)
          .eq('place_id', placeId)
          .maybeSingle();

      if (entryResponse != null) {
        final entryId = entryResponse['id'];

        // Delete the entry
        await _supabase.from('list_entries').delete().eq('id', entryId);
      }

      // Update local cache
      final index = _lists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        final updatedList = _lists[index].removePlace(placeId);
        _lists[index] = updatedList;
      }
    } catch (e) {
      _error = 'Error removing place from list: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get lists that contain a place
  List<PlaceList> getListsWithPlace(String placeId) {
    return _lists
        .where((list) => list.entries.any((entry) => entry.place.id == placeId))
        .toList();
  }

  // Share a list with another user by email
  Future<void> shareListWithUser(String listId, String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the current user ID
      final sharedBy = _supabase.auth.currentUser?.id;
      if (sharedBy == null) {
        throw Exception('User not authenticated');
      }

      // Insert into shares table
      await _supabase.from('shares').insert({
        'id': _uuid.v4(),
        'list_id': listId,
        'shared_by': sharedBy,
        'email': email,
      });
    } catch (e) {
      _error = 'Error sharing list: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get shared lists
  Future<List<PlaceList>> getSharedLists() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get current user's email
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated or email not available');
      }

      // Get lists shared with the user's email
      final sharesResponse = await _supabase.from('shares').select('''
            *,
            list:place_lists(*)
          ''').eq('email', user.email!);

      final sharedLists = <PlaceList>[];

      for (final shareData in sharesResponse) {
        final listData = shareData['list'];
        final listId = listData['id'];

        // Get rating categories for this list
        final categoriesResponse = await _supabase
            .from('rating_categories')
            .select()
            .eq('list_id', listId);

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
              place:places(*)
            ''').eq('list_id', listId);

        final entries = <PlaceEntry>[];

        for (final entryData in entriesResponse) {
          final entryId = entryData['id'];
          final placeData = entryData['place'];

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
            lat: placeData['lat'],
            lng: placeData['lng'],
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
        }

        // Create list
        final placeList = PlaceList(
          id: listId,
          name: listData['name'],
          description: listData['description'],
          entries: entries,
          ratingCategories: ratingCategories,
        );

        sharedLists.add(placeList);
      }

      _isLoading = false;
      notifyListeners();

      return sharedLists;
    } catch (e) {
      _error = 'Error getting shared lists: $e';
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print(_error);
      }
      return [];
    }
  }

  // Make a list public or private
  Future<void> setListVisibility(String listId, bool isPublic) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Update visibility in Supabase
      await _supabase
          .from('place_lists')
          .update({'is_public': isPublic}).eq('id', listId);
    } catch (e) {
      _error = 'Error updating list visibility: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
