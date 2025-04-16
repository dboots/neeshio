import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/place_list.dart';
import '../services/place_search_service.dart' as search;
import '../services/marker_service.dart';
import 'package:custom_info_window/custom_info_window.dart';

/// A service for handling map search functionality
class MapSearchService {
  /// Perform a place search within the current map view
  static Future<List<search.PlaceSearchResult>> searchPlacesInArea(
    GoogleMapController mapController,
    String query,
  ) async {
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
  static Future<Set<Marker>> createSearchResultMarkers(
    BuildContext context,
    List<search.PlaceSearchResult> results,
    Function(Place) onTap,
    CustomInfoWindowController controller,
  ) async {
    final markerService = Provider.of<MarkerService>(context, listen: false);
    final resultMarkers = <Marker>{};
    
    for (final result in results) {
      final place = result.toPlace();
      final marker = await markerService.createMarkerFromPlace(
        place: place,
        onTap: onTap,
        controller: controller,
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
