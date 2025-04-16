import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/place_list.dart';
import '../services/place_list_service.dart';
import 'package:provider/provider.dart';

/// Utilities for working with places in the map
class PlaceUtils {
  static final Uuid _uuid = const Uuid();

  /// Create a new place from a map position
  static Place createPlaceFromPosition(LatLng position, String name) {
    return Place(
      id: _uuid.v4(),
      name: name,
      address: 'Location at ${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}',
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  /// Add a place to a list and show a confirmation message
  static Future<void> addPlaceToList(
    BuildContext context,
    PlaceList list,
    Place place,
  ) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);
    await listService.addPlaceToList(list.id, place);

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${place.name}" to "${list.name}" list'),
          action: SnackBarAction(
            label: 'View List',
            onPressed: () {
              // Navigate back to previous screen (list detail)
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
  }
}
