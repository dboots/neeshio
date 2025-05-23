import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/place_list.dart';
import '../models/place_rating.dart';

class PlaceListService extends ChangeNotifier {
  List<PlaceList> _lists = [];

  List<PlaceList> get lists => _lists;

  static const String _storageKey = 'place_lists';
  final _uuid = const Uuid();

  // Load lists from persistent storage
  Future<void> loadLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLists = prefs.getString(_storageKey);

      if (storedLists != null) {
        final List<dynamic> decodedLists =
            jsonDecode(storedLists) as List<dynamic>;
        _lists = decodedLists
            .map((list) => PlaceList.fromJson(list as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading lists: $e');
      }
    }
  }

  // Save lists to persistent storage
  Future<void> _saveLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedLists =
          jsonEncode(_lists.map((list) => list.toJson()).toList());
      await prefs.setString(_storageKey, encodedLists);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving lists: $e');
      }
    }
  }

  // Create a new list
  Future<PlaceList> createList(String name,
      [String? description, List<RatingCategory>? ratingCategories]) async {
    final newList = PlaceList.create(
      _uuid.v4(),
      name,
      description,
      ratingCategories,
    );
    _lists.add(newList);
    notifyListeners();
    await _saveLists();
    return newList;
  }

  // Update a list
  Future<void> updateList(PlaceList updatedList) async {
    final index = _lists.indexWhere((list) => list.id == updatedList.id);
    if (index != -1) {
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Delete a list
  Future<void> deleteList(String listId) async {
    _lists.removeWhere((list) => list.id == listId);
    notifyListeners();
    await _saveLists();
  }

  // Add a rating category to a list
  Future<void> addRatingCategory(String listId, RatingCategory category) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList = _lists[index].addRatingCategory(category);
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Remove a rating category from a list
  Future<void> removeRatingCategory(String listId, String categoryId) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList = _lists[index].removeRatingCategory(categoryId);
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Add a place to a list
  Future<void> addPlaceToList(String listId, Place place,
      {List<RatingValue>? ratings, String? notes}) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList = _lists[index].addPlace(
        place,
        ratings: ratings,
        notes: notes,
      );
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Update the rating for a category of a place in a list
  Future<void> updatePlaceRating(
      String listId, String placeId, String categoryId, int rating) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList =
          _lists[index].updateRating(placeId, categoryId, rating);
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Update the notes for a place in a list
  Future<void> updatePlaceNotes(
      String listId, String placeId, String notes) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList = _lists[index].updateNotes(placeId, notes);
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Remove a place from a list
  Future<void> removePlaceFromList(String listId, String placeId) async {
    final index = _lists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      final updatedList = _lists[index].removePlace(placeId);
      _lists[index] = updatedList;
      notifyListeners();
      await _saveLists();
    }
  }

  // Get lists that contain a place
  List<PlaceList> getListsWithPlace(String placeId) {
    return _lists
        .where((list) => list.entries.any((entry) => entry.place.id == placeId))
        .toList();
  }
}
