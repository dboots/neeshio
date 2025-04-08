import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/place_list.dart';

class PlaceSearchResult {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? photoReference;
  final String? vicinity;
  final double? rating;
  final int? userRatingsTotal;
  final List<String>? types;
  final String? placeUrl;
  final bool? openNow;
  final String? priceLevel;

  PlaceSearchResult({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoReference,
    this.vicinity,
    this.rating,
    this.userRatingsTotal,
    this.types,
    this.placeUrl,
    this.openNow,
    this.priceLevel,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    List<String>? typesList;
    if (json['types'] != null) {
      typesList = List<String>.from(json['types']);
    }

    bool? isOpenNow;
    if (json['opening_hours'] != null &&
        json['opening_hours']['open_now'] != null) {
      isOpenNow = json['opening_hours']['open_now'] as bool;
    }

    String? price;
    if (json['price_level'] != null) {
      final int level = json['price_level'] as int;
      price = '\$' * level;
    }

    return PlaceSearchResult(
      id: json['place_id'] as String,
      name: json['name'] as String,
      address: json['formatted_address'] ?? json['vicinity'] ?? '',
      lat: json['geometry']['location']['lat'],
      lng: json['geometry']['location']['lng'],
      photoReference:
          json['photos'] != null && (json['photos'] as List).isNotEmpty
              ? json['photos'][0]['photo_reference']
              : null,
      vicinity: json['vicinity'],
      rating: json['rating']?.toDouble(),
      userRatingsTotal: json['user_ratings_total'],
      types: typesList,
      placeUrl: json['url'],
      openNow: isOpenNow,
      priceLevel: price,
    );
  }

  // Convert to Place model
  Place toPlace() {
    // Build image URL if photo reference exists
    String? imageUrl;
    if (photoReference != null) {
      // Use place photo from Google Maps Platform if you have an API key
      // Replace YOUR_API_KEY with your actual Google Maps API key
      // This is a placeholder, in production you'd use:
      // imageUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=YOUR_API_KEY';

      // For now, use a placeholder image
      imageUrl =
          'https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/geocode-71.png';
    }

    return Place(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      image: imageUrl,
      phone: null, // Phone number would require an additional API call
    );
  }

  // Get primary place type (for categorization)
  String getPrimaryType() {
    if (types == null || types!.isEmpty) {
      return 'unknown';
    }

    // Priority list for display purposes
    final priorityTypes = [
      'restaurant',
      'cafe',
      'bakery',
      'bar',
      'food',
      'store',
      'shopping_mall',
      'lodging',
      'hotel',
      'tourist_attraction',
      'museum',
      'park',
      'point_of_interest',
    ];

    // Return the first matching type in our priority list
    for (final type in priorityTypes) {
      if (types!.contains(type)) {
        return type;
      }
    }

    // If no match in priority, return the first type
    return types!.first;
  }
}

class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});
}

class PlaceSearchService {
  // You would add your Google Places API key here
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

  // Search for places based on a text query (e.g., "diners in Portland")
  Future<List<PlaceSearchResult>> searchPlaces(String query,
      {LatLng? location}) async {
    try {
      // Build the request URL
      final Uri url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query': query,
          'key': _apiKey,
          if (location != null) 'location': '${location.lat},${location.lng}',
          if (location != null) 'radius': '5000', // 5km radius
        },
      );

      // Send the request
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((place) => PlaceSearchResult.fromJson(place))
              .toList();
        } else {
          if (kDebugMode) {
            print('Places API error: ${data['status']}');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('Failed to load search results: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during place search: $e');
      }
      return [];
    }
  }

  // Search for places nearby a specific location
  Future<List<PlaceSearchResult>> searchNearbyPlaces(
    LatLng location, {
    String? type,
    int radius = 1500,
  }) async {
    try {
      final Uri url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '${location.lat},${location.lng}',
          'radius': radius.toString(),
          'key': _apiKey,
          if (type != null) 'type': type,
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((place) => PlaceSearchResult.fromJson(place))
              .toList();
        } else {
          if (kDebugMode) {
            print('Places API error: ${data['status']}');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('Failed to load nearby places: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during nearby search: $e');
      }
      return [];
    }
  }

  // Get details for a specific place by ID
  Future<PlaceSearchResult?> getPlaceDetails(String placeId) async {
    try {
      final Uri url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'key': _apiKey,
          'fields':
              'name,formatted_address,geometry,photo,vicinity,rating,url,opening_hours,price_level,type',
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          return PlaceSearchResult.fromJson(result);
        } else {
          if (kDebugMode) {
            print('Place Details API error: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('Failed to load place details: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during place details request: $e');
      }
      return null;
    }
  }
}
