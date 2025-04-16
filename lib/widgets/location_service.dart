import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  /// Get the current device location with permission handling
  /// Returns LatLng if successful, null otherwise
  static Future<LatLng?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
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
        _showSnackBar(
          context,
          'Location permission denied. Using default location.',
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
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
      _showSnackBar(context, 'Failed to get current location: $e');
      return null;
    }
  }
  
  /// Show a snackbar message
  static void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
