import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  // Default fallback position (Portland, OR)
  static const LatLng defaultPosition = LatLng(45.521563, -122.677433);

  /// Get the current device location.
  /// Returns the current position as a LatLng, or null if unable to determine location.
  static Future<LatLng?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, inform user
      _showMessage(
        context,
        'Location services are disabled. Please enable to use your current location.',
      );
      return null;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied, inform user
        _showMessage(
          context,
          'Location permission denied. Using default location.',
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, inform user
      _showMessage(
        context,
        'Location permission permanently denied. Using default location.',
      );
      return null;
    }

    // Permission granted, get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      _showMessage(context, 'Failed to get current location: $e');
      return null;
    }
  }

  /// Show a message to the user about location status
  static void _showMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get distance between two locations in kilometers
  static double getDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // Convert meters to kilometers
  }

  /// Convert an address to coordinates
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    // This would normally use the Geocoding API
    // For simplicity, we'll just return null for now
    return null;
  }
}
