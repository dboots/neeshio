// Enhanced DiscoverService with sort options and caching mechanisms

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../utils/location_utils.dart';

// Sort options for nearby lists
enum SortOption {
  distance, // Sort by closest first
  rating, // Sort by highest rating first
  placeCount, // Sort by most places first
  newest, // Sort by newest lists first
}

/// A model class representing a nearby list
class NearbyList {
  final String id;
  final String name;
  final String? description;
  final String userId;
  final String userName;
  final double distance;
  final int placeCount;
  final int categoryCount;
  final double averageRating;
  final List<String>? categories;
  final DateTime? createdAt;

  NearbyList({
    required this.id,
    required this.name,
    this.description,
    required this.userId,
    required this.userName,
    required this.distance,
    required this.placeCount,
    required this.categoryCount,
    required this.averageRating,
    this.categories,
    this.createdAt,
  });

  factory NearbyList.fromJson(Map<String, dynamic> json) {
    return NearbyList(
      id: json['list_id'],
      name: json['list_name'],
      description: json['list_description'],
      userId: json['user_id'],
      userName: json['user_name'],
      distance: json['distance']?.toDouble() ?? 0.0,
      placeCount: json['place_count'] ?? 0,
      categoryCount: json['category_count'] ?? 0,
      averageRating: json['avg_rating']?.toDouble() ?? 0.0,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'list_id': id,
      'list_name': name,
      'list_description': description,
      'user_id': userId,
      'user_name': userName,
      'distance': distance,
      'place_count': placeCount,
      'category_count': categoryCount,
      'avg_rating': averageRating,
      'categories': categories,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Format the distance as a string
  String getFormattedDistance() {
    return LocationUtils.formatDistance(distance);
  }
}

/// Enhanced service class to handle discovery functionality with caching and sorting
class DiscoverService extends ChangeNotifier {
  final SupabaseClient _supabase;

  List<NearbyList> _nearbyLists = [];
  bool _isLoading = false;
  String? _error;
  SortOption _currentSortOption = SortOption.distance;

  // Cache variables
  final Duration _cacheExpiration = const Duration(minutes: 30);
  DateTime? _lastFetchTime;
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastRadius;

  /// All discovered nearby lists
  List<NearbyList> get nearbyLists => _nearbyLists;

  /// Whether the service is currently loading data
  bool get isLoading => _isLoading;

  /// Error message if the last operation failed
  String? get error => _error;

  /// Current sort option
  SortOption get currentSortOption => _currentSortOption;

  DiscoverService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch nearby lists for a given location with caching support
  Future<List<NearbyList>> getNearbyLists({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int maxResults = 20,
    String? categoryFilter,
    bool forceRefresh = false,
  }) async {
    // Check if we can use cached data
    if (!forceRefresh && _canUseCachedData(latitude, longitude, radiusKm)) {
      // Apply filters and sorting if needed
      if (categoryFilter != null) {
        return filterByCategory(categoryFilter);
      }
      return _nearbyLists;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase.rpc(
        'get_nearby_lists',
        params: {
          'lat': latitude,
          'lng': longitude,
          'radius_km': radiusKm,
          'max_results': maxResults,
          'category_filter': categoryFilter,
        },
      );

      final results = (response as List<dynamic>)
          .map((json) => NearbyList.fromJson(json))
          .toList();

      // Update cache information
      _nearbyLists = results;
      _lastFetchTime = DateTime.now();
      _lastLatitude = latitude;
      _lastLongitude = longitude;
      _lastRadius = radiusKm;

      // Save to local storage cache
      _saveToCache();

      // Apply default sorting (by distance)
      sortNearbyLists(_currentSortOption);

      _isLoading = false;
      notifyListeners();

      return results;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to fetch nearby lists: ${e.toString()}';
      notifyListeners();
      if (kDebugMode) {
        print(_error);
      }

      // Try to load from cache as fallback
      await _loadFromCache();

      return _nearbyLists;
    }
  }

  /// Get nearby lists organized by category
  Future<Map<String, List<NearbyList>>> getNearbyListsByCategory({
    required double latitude,
    required double longitude,
    double radiusKm = 20.0,
    bool forceRefresh = false,
  }) async {
    final allLists = await getNearbyLists(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      maxResults: 100,
      forceRefresh: forceRefresh,
    );

    // Create category mapping
    final Map<String, List<NearbyList>> categorizedLists = {
      'Featured': [],
      'Food & Dining': [],
      'Attractions': [],
      'Shopping': [],
      'Outdoors': [],
      'Other': [],
    };

    // Get featured lists (top rated)
    final featuredLists = List<NearbyList>.from(allLists)
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));

    if (featuredLists.isNotEmpty) {
      categorizedLists['Featured'] = featuredLists.take(5).toList();
    }

    // Categorize all lists
    for (final list in allLists) {
      final categories =
          list.categories?.map((c) => c.toLowerCase()).toList() ?? [];

      if (categories.any((c) =>
          c.contains('food') ||
          c.contains('restaurant') ||
          c.contains('cafe') ||
          c.contains('dining'))) {
        categorizedLists['Food & Dining']!.add(list);
      } else if (categories.any((c) =>
          c.contains('attraction') ||
          c.contains('museum') ||
          c.contains('entertainment'))) {
        categorizedLists['Attractions']!.add(list);
      } else if (categories.any((c) =>
          c.contains('shop') || c.contains('store') || c.contains('mall'))) {
        categorizedLists['Shopping']!.add(list);
      } else if (categories.any((c) =>
          c.contains('park') ||
          c.contains('outdoor') ||
          c.contains('nature') ||
          c.contains('trail'))) {
        categorizedLists['Outdoors']!.add(list);
      } else {
        categorizedLists['Other']!.add(list);
      }
    }

    // Remove empty categories
    categorizedLists
        .removeWhere((key, value) => value.isEmpty && key != 'Featured');

    return categorizedLists;
  }

  /// Filter nearby lists by category
  List<NearbyList> filterByCategory(String category) {
    if (category.toLowerCase() == 'all') {
      return _nearbyLists;
    }

    return _nearbyLists.where((list) {
      final categories =
          list.categories?.map((c) => c.toLowerCase()).toList() ?? [];
      return categories.contains(category.toLowerCase()) ||
          list.name.toLowerCase().contains(category.toLowerCase());
    }).toList();
  }

  /// Sort nearby lists by the given option
  void sortNearbyLists(SortOption option) {
    _currentSortOption = option;

    switch (option) {
      case SortOption.distance:
        _nearbyLists.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case SortOption.rating:
        _nearbyLists.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case SortOption.placeCount:
        _nearbyLists.sort((a, b) => b.placeCount.compareTo(a.placeCount));
        break;
      case SortOption.newest:
        _nearbyLists.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }

    notifyListeners();
  }

  /// Check if we can use the cached data
  bool _canUseCachedData(double latitude, double longitude, double radiusKm) {
    if (_nearbyLists.isEmpty ||
        _lastFetchTime == null ||
        _lastLatitude == null ||
        _lastLongitude == null ||
        _lastRadius == null) {
      return false;
    }

    // Check if cache is expired
    if (DateTime.now().difference(_lastFetchTime!) > _cacheExpiration) {
      return false;
    }

    // Check if location has changed significantly
    final distance = LocationUtils.calculateDistance(
        latitude, longitude, _lastLatitude!, _lastLongitude!);

    // If we moved more than 25% of the radius, refresh the data
    return distance < (radiusKm * 0.25);
  }

  /// Save current data to local cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save lists
      final jsonLists = _nearbyLists.map((list) => list.toJson()).toList();
      await prefs.setString('nearby_lists_cache', jsonEncode(jsonLists));

      // Save metadata
      final cacheMetadata = {
        'timestamp': _lastFetchTime?.millisecondsSinceEpoch,
        'latitude': _lastLatitude,
        'longitude': _lastLongitude,
        'radius': _lastRadius,
      };
      await prefs.setString('nearby_lists_metadata', jsonEncode(cacheMetadata));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to cache: $e');
      }
    }
  }

  /// Load data from local cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load metadata first
      final metadataJson = prefs.getString('nearby_lists_metadata');
      if (metadataJson == null) return;

      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      _lastFetchTime =
          DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
      _lastLatitude = metadata['latitude'];
      _lastLongitude = metadata['longitude'];
      _lastRadius = metadata['radius'];

      // Load lists
      final listsJson = prefs.getString('nearby_lists_cache');
      if (listsJson == null) return;

      final jsonLists = jsonDecode(listsJson) as List<dynamic>;
      _nearbyLists =
          jsonLists.map((json) => NearbyList.fromJson(json)).toList();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading from cache: $e');
      }
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nearby_lists_cache');
      await prefs.remove('nearby_lists_metadata');

      _nearbyLists = [];
      _lastFetchTime = null;
      _lastLatitude = null;
      _lastLongitude = null;
      _lastRadius = null;

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  // Remove the duplicate calculateDistance methods as they've been moved to LocationUtils
}
