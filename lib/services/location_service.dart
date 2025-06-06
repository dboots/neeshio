import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  static const LatLng _defaultLocation = LatLng(0, 0);
  static const String _defaultLocationName = 'Loading';

  // Storage keys
  static const String _locationKey = 'current_location';
  static const String _locationNameKey = 'current_location_name';

  // Google Geocoding API key - should be set via environment variable
  static const String _geocodingApiKey =
      String.fromEnvironment('GOOGLE_MAPS_KEY');

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
        print(
            'Got current location: $locationName at ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
      // Don't throw, just continue without GPS location
    }
  }

  /// Get a human-readable name for a location using reverse geocoding
  Future<String> _getLocationName(LatLng location) async {
    try {
      // Try reverse geocoding with Google Maps API
      if (_geocodingApiKey.isNotEmpty) {
        final geocodedName = await _reverseGeocode(location);
        if (geocodedName != null) {
          if (kDebugMode) {
            print('Geocoded location: $geocodedName');
          }
          return geocodedName;
        }
      } else {
        if (kDebugMode) {
          print('Google Maps API key not found for geocoding');
        }
      }

      // Fallback: Use coordinates if geocoding fails
      return 'Location (${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)})';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location name: $e');
      }
      return 'Location (${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)})';
    }
  }

  /// Reverse geocode using Google Maps Geocoding API
  Future<String?> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${location.latitude},${location.longitude}'
          '&key=$_geocodingApiKey'
          '&result_type=locality|administrative_area_level_1|administrative_area_level_2|sublocality');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Try to extract city and state/country from the response
          return _parseGeocodingResult(data['results']);
        } else if (data['status'] == 'ZERO_RESULTS') {
          if (kDebugMode) {
            print('No geocoding results found for location');
          }
        } else {
          if (kDebugMode) {
            print('Geocoding API error: ${data['status']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('Geocoding API HTTP error: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Reverse geocoding error: $e');
      }
    }
    return null;
  }

  /// Parse geocoding results to extract the best location name
  String? _parseGeocodingResult(List<dynamic> results) {
    try {
      // Priority order for location names:
      // 1. City (locality) + State/Province
      // 2. Sublocality + State/Province
      // 3. Administrative Area Level 2 (County) + State/Province
      // 4. Administrative Area Level 1 (State/Province) only
      // 5. Country only

      String? locality;
      String? sublocality;
      String? adminArea1; // State/Province
      String? adminArea2; // County
      String? country;

      // Parse all results to find the best components
      for (final result in results) {
        final components = result['address_components'] as List;

        for (final component in components) {
          final types = component['types'] as List<dynamic>;
          final longName = component['long_name'] as String;
          final shortName = component['short_name'] as String;

          if (types.contains('locality') && locality == null) {
            locality = longName;
          } else if (types.contains('sublocality') && sublocality == null) {
            sublocality = longName;
          } else if (types.contains('administrative_area_level_1') &&
              adminArea1 == null) {
            // Use short name for US states, long name for other countries
            adminArea1 = shortName.length <= 3 ? shortName : longName;
          } else if (types.contains('administrative_area_level_2') &&
              adminArea2 == null) {
            adminArea2 = longName;
          } else if (types.contains('country') && country == null) {
            country = longName;
          }
        }

        // If we found a locality and state, we can stop searching
        if (locality != null && adminArea1 != null) {
          break;
        }
      }

      // Build the location name based on available components
      if (locality != null && adminArea1 != null) {
        return '$locality, $adminArea1';
      } else if (locality != null && country != null) {
        return '$locality, $country';
      } else if (sublocality != null && adminArea1 != null) {
        return '$sublocality, $adminArea1';
      } else if (sublocality != null && country != null) {
        return '$sublocality, $country';
      } else if (adminArea2 != null && adminArea1 != null) {
        return '$adminArea2, $adminArea1';
      } else if (adminArea1 != null) {
        return adminArea1;
      } else if (country != null) {
        return country;
      }

      // If we still don't have a good name, try the formatted address
      if (results.isNotEmpty) {
        final firstResult = results[0];
        final formattedAddress = firstResult['formatted_address'] as String?;
        if (formattedAddress != null) {
          // Try to extract just the relevant parts (remove street numbers, etc.)
          return _simplifyFormattedAddress(formattedAddress);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing geocoding result: $e');
      }
    }
    return null;
  }

  /// Simplify a formatted address to extract city, state
  String _simplifyFormattedAddress(String formattedAddress) {
    try {
      final parts = formattedAddress.split(', ');

      // Remove street address (usually the first part contains numbers)
      final filteredParts = parts.where((part) {
        // Remove parts that look like street addresses (contain numbers)
        return !RegExp(r'^\d+').hasMatch(part.trim());
      }).toList();

      if (filteredParts.length >= 2) {
        // Take the first two relevant parts (usually city, state)
        return '${filteredParts[0]}, ${filteredParts[1]}';
      } else if (filteredParts.isNotEmpty) {
        return filteredParts[0];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error simplifying formatted address: $e');
      }
    }

    return formattedAddress;
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    final lat1Rad = lat1 * (pi / 180);
    final lat2Rad = lat2 * (pi / 180);
    final deltaLatRad = (lat2 - lat1) * (pi / 180);
    final deltaLonRad = (lon2 - lon1) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLonRad / 2) *
            sin(deltaLonRad / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
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

  /// Update location and get name via geocoding
  Future<void> updateLocationWithGeocoding(LatLng location) async {
    _isLoading = true;
    notifyListeners();

    try {
      final locationName = await _getLocationName(location);
      _setLocation(location, locationName);
    } catch (e) {
      _error = 'Failed to get location name: ${e.toString()}';
      // Still update location with coordinates as fallback
      final fallbackName =
          'Location (${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)})';
      _setLocation(location, fallbackName);
    } finally {
      _isLoading = false;
      notifyListeners();
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
