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

  PlaceSearchResult({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoReference,
    this.vicinity,
    this.rating,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
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
    );
  }

  // Convert to Place model
  Place toPlace() {
    return Place(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      // If you have an API key, you can build the image URL here
      image: photoReference != null
          ? 'https://placeholder.com/150' // Placeholder, replace with actual Google Places photo URL
          : null,
      phone: null, // Phone number would require an additional API call
    );
  }
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
}

// Helper class for location
class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});
}
