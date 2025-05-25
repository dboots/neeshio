import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Service to manage shared location state across the app
class LocationService extends ChangeNotifier {
  LatLng? _currentLocation;
  String? _currentLocationName;
  bool _isLoading = false;
  String? _error;

  // Getters
  LatLng? get currentLocation => _currentLocation;
  String? get currentLocationName => _currentLocationName;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Default location (Hudson, Ohio)
  static const LatLng _defaultLocation = LatLng(41.2407, -81.4412);
  static const String _defaultLocationName = 'Hudson, Ohio';

  // Storage keys
  static const String _locationKey = 'current_location';
  static const String _locationNameKey = 'current_location_name';

  /// Initialize the location service
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load saved location first
      await _loadSavedLocation();

      // If no saved location, try to get current location
      if (_currentLocation == null) {
        await _getCurrentLocation();
      }

      // If still no location, use default
      if (_currentLocation == null) {
        _setLocation(_defaultLocation, _defaultLocationName);
      }
    } catch (e) {
      _error = e.toString();
      // Use default location on error
      _setLocation(_defaultLocation, _defaultLocationName);
      if (kDebugMode) {
        print('Error initializing location service: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load saved location from shared preferences
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_locationKey);
      final locationName = prefs.getString(_locationNameKey);

      if (locationJson != null && locationName != null) {
        final locationData = jsonDecode(locationJson) as Map<String, dynamic>;
        final lat = locationData['lat'] as double;
        final lng = locationData['lng'] as double;

        _currentLocation = LatLng(lat, lng);
        _currentLocationName = locationName;

        if (kDebugMode) {
          print('Loaded saved location: $locationName');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading saved location: $e');
      }
      // Continue without saved location
    }
  }

  /// Save current location to shared preferences
  Future<void> _saveLocation() async {
    if (_currentLocation == null || _currentLocationName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = jsonEncode({
        'lat': _currentLocation!.latitude,
        'lng': _currentLocation!.longitude,
      });

      await prefs.setString(_locationKey, locationJson);
      await prefs.setString(_locationNameKey, _currentLocationName!);

      if (kDebugMode) {
        print('Saved location: $_currentLocationName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location: $e');
      }
    }
  }

  /// Get the user's current GPS location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('Location permission denied');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permissions are permanently denied');
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final location = LatLng(position.latitude, position.longitude);
      final locationName = await _getLocationName(location);

      _setLocation(location, locationName);

      if (kDebugMode) {
        print('Got current location: $locationName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
      // Don't throw, just continue without GPS location
    }
  }

  /// Get a human-readable name for a location
  Future<String> _getLocationName(LatLng location) async {
    // Simplified location name detection
    // In a real app, you might use reverse geocoding

    // Check if near known locations
    if (_isNear(location, const LatLng(41.2407, -81.4412), 10)) {
      return 'Hudson, Ohio';
    } else if (_isNear(location, const LatLng(41.5085, -81.6954), 15)) {
      return 'Cleveland, Ohio';
    } else if (_isNear(location, const LatLng(41.0814, -81.5191), 15)) {
      return 'Akron, Ohio';
    } else if (_isNear(location, const LatLng(40.7128, -74.0060), 15)) {
      return 'New York City, NY';
    } else if (_isNear(location, const LatLng(34.0522, -118.2437), 15)) {
      return 'Los Angeles, CA';
    } else if (_isNear(location, const LatLng(41.8781, -87.6298), 15)) {
      return 'Chicago, IL';
    } else if (_isNear(location, const LatLng(37.7749, -122.4194), 15)) {
      return 'San Francisco, CA';
    } else {
      // Fallback to coordinates
      return 'Current Location (${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)})';
    }
  }

  /// Check if a location is within a certain distance (km) of another location
  bool _isNear(LatLng location1, LatLng location2, double radiusKm) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    final lat1Rad = location1.latitude * (pi / 180);
    final lat2Rad = location2.latitude * (pi / 180);
    final deltaLatRad = (location2.latitude - location1.latitude) * (pi / 180);
    final deltaLngRad =
        (location2.longitude - location1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance <= radiusKm;
  }

  /// Set the current location and save it
  void _setLocation(LatLng location, String locationName) {
    _currentLocation = location;
    _currentLocationName = locationName;
    _error = null;
    notifyListeners();

    // Save to preferences asynchronously
    _saveLocation();
  }

  /// Update the current location manually
  void updateLocation(LatLng location, String locationName) {
    _setLocation(location, locationName);

    if (kDebugMode) {
      print('Location updated to: $locationName');
    }
  }

  /// Reset to default location
  void resetToDefault() {
    _setLocation(_defaultLocation, _defaultLocationName);

    if (kDebugMode) {
      print('Location reset to default: $_defaultLocationName');
    }
  }

  /// Refresh the current GPS location
  Future<void> refreshCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _getCurrentLocation();
    } catch (e) {
      _error = 'Failed to get current location: ${e.toString()}';
      if (kDebugMode) {
        print('Error refreshing location: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear saved location data
  Future<void> clearSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_locationKey);
      await prefs.remove(_locationNameKey);

      if (kDebugMode) {
        print('Cleared saved location data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing saved location: $e');
      }
    }
  }

  /// Get a list of preset locations for quick selection
  List<LocationOption> getPresetLocations() {
    return [
      LocationOption(
        name: 'Hudson, Ohio',
        location: const LatLng(41.2407, -81.4412),
        description: 'Default location',
      ),
      LocationOption(
        name: 'Cleveland, Ohio',
        location: const LatLng(41.5085, -81.6954),
        description: 'Major city in Ohio',
      ),
      LocationOption(
        name: 'Akron, Ohio',
        location: const LatLng(41.0814, -81.5191),
        description: 'City in Summit County',
      ),
      LocationOption(
        name: 'New York City, NY',
        location: const LatLng(40.7128, -74.0060),
        description: 'The Big Apple',
      ),
      LocationOption(
        name: 'Los Angeles, CA',
        location: const LatLng(34.0522, -118.2437),
        description: 'City of Angels',
      ),
      LocationOption(
        name: 'Chicago, IL',
        location: const LatLng(41.8781, -87.6298),
        description: 'The Windy City',
      ),
      LocationOption(
        name: 'San Francisco, CA',
        location: const LatLng(37.7749, -122.4194),
        description: 'Golden Gate City',
      ),
    ];
  }

  /// Check if location services are available
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  /// Check location permission status
  Future<LocationPermission> getLocationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      return LocationPermission.denied;
    }
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      return LocationPermission.denied;
    }
  }
}

/// Data class for location options
class LocationOption {
  final String name;
  final LatLng location;
  final String description;

  const LocationOption({
    required this.name,
    required this.location,
    required this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationOption &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          location.latitude == other.location.latitude &&
          location.longitude == other.location.longitude;

  @override
  int get hashCode => name.hashCode ^ location.hashCode;

  @override
  String toString() => 'LocationOption(name: $name, location: $location)';
}
