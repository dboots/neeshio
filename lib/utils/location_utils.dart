import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A utility class for location-related calculations and operations
class LocationUtils {
  /// Calculate distance between two coordinates using Haversine formula
  /// 
  /// Parameters:
  /// - lat1: Latitude of first point in degrees
  /// - lng1: Longitude of first point in degrees
  /// - lat2: Latitude of second point in degrees
  /// - lng2: Longitude of second point in degrees
  /// 
  /// Returns:
  /// - Distance in kilometers
  static double calculateDistance(
    double lat1, 
    double lng1, 
    double lat2, 
    double lng2
  ) {
    // Earth's radius in kilometers
    const earthRadius = 6371.0;
    
    // Convert degrees to radians
    final lat1Rad = _degreesToRadians(lat1);
    final lng1Rad = _degreesToRadians(lng1);
    final lat2Rad = _degreesToRadians(lat2);
    final lng2Rad = _degreesToRadians(lng2);
    
    // Differences in coordinates
    final dLat = lat2Rad - lat1Rad;
    final dLng = lng2Rad - lng1Rad;
    
    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1Rad) * cos(lat2Rad) * 
              sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    // Calculate distance
    return earthRadius * c;
  }
  
  /// Calculate distance between two LatLng points using Haversine formula
  /// 
  /// Parameters:
  /// - point1: First LatLng point
  /// - point2: Second LatLng point
  /// 
  /// Returns:
  /// - Distance in kilometers
  static double calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude, 
      point1.longitude, 
      point2.latitude, 
      point2.longitude
    );
  }
  
  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }
  
  /// Format distance for display
  /// 
  /// Parameters:
  /// - distanceKm: Distance in kilometers
  /// - useMetric: Whether to use metric units (default: true)
  /// 
  /// Returns:
  /// - Formatted distance string (e.g., "2.5 km" or "500 m")
  static String formatDistance(double distanceKm, {bool useMetric = true}) {
    if (useMetric) {
      // Metric formatting (kilometers/meters)
      if (distanceKm < 1) {
        // Show in meters if less than 1km
        final meters = (distanceKm * 1000).round();
        return '$meters m';
      } else if (distanceKm < 10) {
        // Show 1 decimal place if under 10km
        return '${distanceKm.toStringAsFixed(1)} km';
      } else {
        // Show as integer if 10km or more
        return '${distanceKm.round()} km';
      }
    } else {
      // Imperial formatting (miles/feet)
      final miles = distanceKm * 0.621371;
      if (miles < 0.1) {
        // Show in feet if less than 0.1 miles
        final feet = (miles * 5280).round();
        return '$feet ft';
      } else if (miles < 10) {
        // Show 1 decimal place if under 10 miles
        return '${miles.toStringAsFixed(1)} mi';
      } else {
        // Show as integer if 10 miles or more
        return '${miles.round()} mi';
      }
    }
  }
  
  /// Find the center point of multiple coordinates
  /// 
  /// Parameters:
  /// - points: List of LatLng points
  /// 
  /// Returns:
  /// - LatLng representing the center point
  static LatLng findCenterPoint(List<LatLng> points) {
    if (points.isEmpty) {
      // Default to a central location (or handle according to your app's needs)
      return const LatLng(0, 0);
    }
    
    if (points.length == 1) {
      return points[0];
    }
    
    double totalLat = 0.0;
    double totalLng = 0.0;
    
    for (final point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }
    
    return LatLng(
      totalLat / points.length,
      totalLng / points.length
    );
  }
  
  /// Calculate viewport bounds to fit all points with padding
  /// 
  /// Parameters:
  /// - points: List of LatLng points to include in the bounds
  /// - paddingPercent: Padding to add around the bounds as a percentage (default: 0.1 or 10%)
  /// 
  /// Returns:
  /// - LatLngBounds that includes all points plus padding
  static LatLngBounds calculateBounds(List<LatLng> points, {double paddingPercent = 0.1}) {
    if (points.isEmpty) {
      // Default to a small area if no points
      const defaultCenter = LatLng(0, 0);
      return LatLngBounds(
        southwest: const LatLng(-0.1, -0.1),
        northeast: const LatLng(0.1, 0.1),
      );
    }
    
    if (points.length == 1) {
      // For a single point, create a small area around it
      final point = points[0];
      final offset = 0.01; // About 1km at the equator
      return LatLngBounds(
        southwest: LatLng(point.latitude - offset, point.longitude - offset),
        northeast: LatLng(point.latitude + offset, point.longitude + offset),
      );
    }
    
    // Find min and max coordinates
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;
    
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    
    // Calculate the size of the current bounds
    final latDelta = maxLat - minLat;
    final lngDelta = maxLng - minLng;
    
    // Add padding
    final latPadding = latDelta * paddingPercent;
    final lngPadding = lngDelta * paddingPercent;
    
    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }
}