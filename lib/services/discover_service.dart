import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';

/// A service for discovering lists from other users
class DiscoverService extends ChangeNotifier {
  List<NearbyList> _nearbyLists = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  /// All discovered nearby lists
  List<NearbyList> get nearbyLists => _nearbyLists;
  
  /// Whether the service is currently loading data
  bool get isLoading => _isLoading;
  
  /// Whether the last operation resulted in an error
  bool get hasError => _hasError;
  
  /// Error message if an operation failed
  String? get errorMessage => _errorMessage;

  static const String _storageKey = 'nearby_lists';
  final _uuid = const Uuid();
  final _random = Random();

  /// Fetches nearby lists for the given location
  /// 
  /// In a real app, this would connect to a backend service
  /// For this demo, it generates mock data based on the location
  Future<List<NearbyList>> fetchNearbyLists(LatLng location, {double radiusKm = 5.0}) async {
    try {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      notifyListeners();
      
      // Simulate network request
      await Future.delayed(const Duration(milliseconds: 800));
      
      // In a real app, would fetch from backend
      // For now, load from cache or generate mock data
      await _loadFromCache();
      
      if (_nearbyLists.isEmpty) {
        await _generateMockNearbyLists(location, radiusKm);
        await _saveToCache();
      }
      
      _isLoading = false;
      notifyListeners();
      return _nearbyLists;
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Failed to load nearby lists: $e';
      notifyListeners();
      return [];
    }
  }

  /// Filters nearby lists by category
  List<NearbyList> filterByCategory(String category) {
    if (category == 'All') {
      return _nearbyLists;
    }
    
    return _nearbyLists.where((list) => 
      list.categories.contains(category.toLowerCase()) ||
      list.list.name.toLowerCase().contains(category.toLowerCase())
    ).toList();
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _nearbyLists = [];
    notifyListeners();
  }

  /// Load nearby lists from cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLists = prefs.getString(_storageKey);

      if (storedLists != null) {
        final List<dynamic> decodedLists = jsonDecode(storedLists) as List<dynamic>;
        _nearbyLists = decodedLists
            .map((json) => NearbyList.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading nearby lists from cache: $e');
      }
      // If loading fails, we'll generate new data
      _nearbyLists = [];
    }
  }

  /// Save nearby lists to cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedLists = jsonEncode(_nearbyLists.map((list) => list.toJson()).toList());
      await prefs.setString(_storageKey, encodedLists);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving nearby lists to cache: $e');
      }
    }
  }

  /// Generate random mock data for demonstration
  Future<void> _generateMockNearbyLists(LatLng center, double radiusKm) async {
    // Pre-defined list categories
    const categories = [
      ['food', 'restaurant', 'dining'],
      ['shopping', 'retail', 'stores'],
      ['attractions', 'sightseeing', 'landmarks'],
      ['entertainment', 'activities', 'fun'],
      ['nightlife', 'bars', 'clubs'],
      ['parks', 'nature', 'outdoors'],
      ['museums', 'culture', 'art'],
      ['cafes', 'coffee', 'bakery']
    ];

    // Pre-defined list names
    const listNames = [
      'Best %s in Town',
      'My Favorite %s',
      'Must-Visit %s',
      'Hidden Gem %s',
      'Top-Rated %s',
      'Local %s Guide',
      'Weekend %s Spots',
      'Affordable %s Places'
    ];

    // Pre-defined user names
    const userNames = [
      'FoodieExplorer',
      'TravelGuru',
      'LocalExpert',
      'CityWanderer',
      'UrbanDiscoverer',
      'PlaceHunter',
      'AdventureSeeker',
      'CulinaryNomad',
      'CityInsider'
    ];

    _nearbyLists = [];

    // Generate 12 random lists
    for (int i = 0; i < 12; i++) {
      // Select random category set
      final categoryIndex = _random.nextInt(categories.length);
      final categorySet = categories[categoryIndex];
      final categoryName = categorySet[0].capitalize();
      
      // Select random list name format
      final nameIndex = _random.nextInt(listNames.length);
      final listNameFormat = listNames[nameIndex];
      final listName = listNameFormat.replaceAll('%s', categoryName);
      
      // Create places
      final placeCount = 3 + _random.nextInt(8); // 3-10 places
      final places = <Place>[];
      
      for (int j = 0; j < placeCount; j++) {
        // Generate random location within radius
        final randomAngle = _random.nextDouble() * 2 * pi;
        final randomRadius = _random.nextDouble() * radiusKm;
        
        // Convert km to lat/lng degrees (approximate)
        final latOffset = randomRadius * cos(randomAngle) / 111.0;
        final lngOffset = randomRadius * sin(randomAngle) / (111.0 * cos(center.latitude * pi / 180));
        
        final placeLat = center.latitude + latOffset;
        final placeLng = center.longitude + lngOffset;
        
        places.add(Place(
          id: _uuid.v4(),
          name: 'Place ${j + 1}',
          address: 'Address for Place ${j + 1}',
          lat: placeLat,
          lng: placeLng,
        ));
      }
      
      // Create rating categories
      final ratingCategories = <RatingCategory>[];
      final categoryCount = 1 + _random.nextInt(3); // 1-3 categories
      
      for (int k = 0; k < categoryCount; k++) {
        ratingCategories.add(RatingCategory(
          id: _uuid.v4(),
          name: 'Rating Category ${k + 1}',
        ));
      }
      
      // Create entries with ratings
      final entries = <PlaceEntry>[];
      for (final place in places) {
        final ratings = <RatingValue>[];
        
        // Add random ratings for each category
        for (final category in ratingCategories) {
          ratings.add(RatingValue(
            categoryId: category.id,
            value: 1 + _random.nextInt(5), // 1-5 stars
          ));
        }
        
        entries.add(PlaceEntry(
          place: place,
          ratings: ratings,
        ));
      }
      
      // Create the list
      final list = PlaceList(
        id: _uuid.v4(),
        name: listName,
        description: 'A curated list of ${categoryName.toLowerCase()} places',
        entries: entries,
        ratingCategories: ratingCategories,
      );
      
      // Create the NearbyList with user info
      _nearbyLists.add(NearbyList(
        list: list,
        userName: userNames[_random.nextInt(userNames.length)],
        userRating: 3.0 + _random.nextDouble() * 2.0, // 3.0-5.0 rating
        categories: categorySet,
        distance: (_random.nextDouble() * radiusKm), // Random distance within radius
      ));
    }
  }
}

/// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// A class representing a list from another user
class NearbyList {
  final PlaceList list;
  final String userName;
  final double userRating;
  final List<String> categories;
  final double distance;

  NearbyList({
    required this.list,
    required this.userName,
    required this.userRating,
    required this.categories,
    required this.distance,
  });

  Map<String, dynamic> toJson() {
    return {
      'list': list.toJson(),
      'userName': userName,
      'userRating': userRating,
      'categories': categories,
      'distance': distance,
    };
  }

  factory NearbyList.fromJson(Map<String, dynamic> json) {
    return NearbyList(
      list: PlaceList.fromJson(json['list'] as Map<String, dynamic>),
      userName: json['userName'] as String,
      userRating: json['userRating'] as double,
      categories: (json['categories'] as List<dynamic>).cast<String>(),
      distance: json['distance'] as double,
    );
  }

  /// Format the distance as a string
  String getFormattedDistance() {
    if (distance < 1) {
      return "${(distance * 1000).toInt()} m";
    } else {
      return "${distance.toStringAsFixed(1)} km";
    }
  }
}
