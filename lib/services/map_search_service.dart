import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_list.dart';
import '../services/place_search_service.dart' as search;

/// A service for handling map search functionality
class MapSearchService {
  /// Perform a place search within the current map view
  static Future<List<search.PlaceSearchResult>> searchPlacesInArea(
    GoogleMapController? mapController,
    String query,
  ) async {
    if (mapController == null) {
      return [];
    }

    // Get current map bounds
    final bounds = await mapController.getVisibleRegion();
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    // Convert to search service LatLng
    final searchLocation = search.LatLng(
      lat: center.latitude,
      lng: center.longitude,
    );

    // Perform the search
    final searchService = search.PlaceSearchService();
    return await searchService.searchPlaces(
      query,
      location: searchLocation,
    );
  }

  /// Create markers from search results
  static Set<Marker> createSearchResultMarkers(
    List<search.PlaceSearchResult> results,
    Function(Place) onTap,
  ) {
    final resultMarkers = <Marker>{};

    for (final result in results) {
      final place = result.toPlace();
      final marker = Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.lat, place.lng),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: place.address,
        ),
        onTap: () => onTap(place),
      );
      resultMarkers.add(marker);
    }

    return resultMarkers;
  }

  /// Show a message about search results
  static void showSearchResultMessage(
    BuildContext context,
    List<search.PlaceSearchResult> results,
  ) {
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No places found')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${results.length} places')),
      );
    }
  }
}