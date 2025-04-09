import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../models/locations.dart' as Locations;
import '../models/place_list.dart';
import '../widgets/custom_marker_window.dart';

class MarkerService {
  // Map to cache custom marker icons to prevent recreating them
  final Map<String, BitmapDescriptor> _customMarkerIcons = {};

  // Getter to access cached marker icons
  Map<String, BitmapDescriptor> get cachedMarkerIcons => _customMarkerIcons;

  // Method to create a custom marker with a name label
  Future<BitmapDescriptor> createCustomMarkerWithName(String name) async {
    // Create a TextPainter to measure text dimensions
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 30,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Create a PictureRecorder and Canvas
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw the marker pin
    const double pinSize = 40;
    final Paint pinPaint = Paint()..color = Colors.red;
    canvas.drawCircle(
      const Offset(pinSize / 2, pinSize / 2),
      pinSize / 2,
      pinPaint,
    );

    // Draw the text background
    final double textWidth = textPainter.width + 16;
    final double textHeight = textPainter.height + 8;
    final Paint bgPaint = Paint()..color = Colors.white.withOpacity(0.8);
    final RRect bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pinSize + 4, // Position text to the right of the marker
        (pinSize - textHeight) / 2,
        textWidth,
        textHeight,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Draw outline around text
    final Paint outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(bgRect, outlinePaint);

    // Draw the text
    textPainter.paint(
      canvas,
      Offset(
        pinSize + 12, // Position text to the right of the marker with padding
        (pinSize - textPainter.height) / 2 + 4,
      ),
    );

    // Convert the Canvas to an image
    final ui.Image image = await pictureRecorder.endRecording().toImage(
          (pinSize + textWidth + 20).ceil(), // Width
          pinSize.ceil(), // Height
        );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final Uint8List uint8List = byteData.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(uint8List);
    } else {
      return BitmapDescriptor.defaultMarker;
    }
  }

  // Get or create a custom marker icon
  Future<BitmapDescriptor> getOrCreateCustomMarkerIcon(
      String id, String name) async {
    if (!_customMarkerIcons.containsKey(id)) {
      final customIcon = await createCustomMarkerWithName(name);
      _customMarkerIcons[id] = customIcon;
    }
    return _customMarkerIcons[id]!;
  }

  // Convert an Office to a Marker with custom marker and info window
  Future<Marker> createMarkerFromOffice({
    required Locations.Office office,
    required Function(Locations.Office) onTap,
    required CustomInfoWindowController controller,
  }) async {
    final place = Place.fromOffice(office);
    final icon = await getOrCreateCustomMarkerIcon(office.id, office.name);

    return Marker(
      markerId: MarkerId(office.id),
      position: LatLng(office.lat, office.lng),
      icon: icon,
      consumeTapEvents: true,
      onTap: () {
        // First close any existing info window
        controller.hideInfoWindow!();

        // Then add the new info window with a slight delay to ensure proper rendering
        Future.delayed(const Duration(milliseconds: 50), () {
          if (controller.googleMapController != null) {
            controller.addInfoWindow!(
              CustomMarkerWindow(
                place: place,
                onTap: () => onTap(office),
              ),
              LatLng(office.lat, office.lng),
            );
          }
        });

        // Also directly call the onTap callback to ensure the marker is always recognized as tapped
        onTap(office);
      },
    );
  }

  // Convert a Place to a Marker with custom marker and info window
  Future<Marker> createMarkerFromPlace({
    required Place place,
    required Function(Place) onTap,
    required CustomInfoWindowController controller,
  }) async {
    final icon = await getOrCreateCustomMarkerIcon(place.id, place.name);

    return Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.lat, place.lng),
      icon: icon,
      consumeTapEvents: true,
      onTap: () {
        // First close any existing info window
        controller.hideInfoWindow!();

        // Then add the new info window with a slight delay to ensure proper rendering
        Future.delayed(const Duration(milliseconds: 50), () {
          if (controller.googleMapController != null) {
            controller.addInfoWindow!(
              CustomMarkerWindow(
                place: place,
                onTap: () => onTap(place),
              ),
              LatLng(place.lat, place.lng),
            );
          }
        });

        // Also directly call the onTap callback to ensure the marker is always recognized as tapped
        onTap(place);
      },
    );
  }

  // Create a basic clickable marker (fallback for troubleshooting)
  Marker createBasicMarker({
    required String id,
    required LatLng position,
    required VoidCallback onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      onTap: onTap,
    );
  }

  // Create markers from a list of offices with custom markers and info windows
  Future<Set<Marker>> createMarkersFromOffices({
    required List<Locations.Office> offices,
    required Function(Locations.Office) onTap,
    required CustomInfoWindowController controller,
  }) async {
    final markers = <Marker>{};

    for (final office in offices) {
      try {
        final marker = await createMarkerFromOffice(
          office: office,
          onTap: onTap,
          controller: controller,
        );
        markers.add(marker);
      } catch (e) {
        // Fallback to basic marker if custom marker creation fails
        print('Error creating custom marker for office ${office.name}: $e');
        markers.add(createBasicMarker(
          id: office.id,
          position: LatLng(office.lat, office.lng),
          onTap: () => onTap(office),
        ));
      }
    }

    return markers;
  }

  // Create markers from a list of places with custom markers and info windows
  Future<Set<Marker>> createMarkersFromPlaces({
    required List<Place> places,
    required Function(Place) onTap,
    required CustomInfoWindowController controller,
  }) async {
    final markers = <Marker>{};

    for (final place in places) {
      try {
        final marker = await createMarkerFromPlace(
          place: place,
          onTap: onTap,
          controller: controller,
        );
        markers.add(marker);
      } catch (e) {
        // Fallback to basic marker if custom marker creation fails
        print('Error creating custom marker for place ${place.name}: $e');
        markers.add(createBasicMarker(
          id: place.id,
          position: LatLng(place.lat, place.lng),
          onTap: () => onTap(place),
        ));
      }
    }

    return markers;
  }

  // Create a marker from a place search result
  Future<Marker> createMarkerFromSearchResult({
    required Place place,
    required Function(Place) onTap,
    required CustomInfoWindowController controller,
  }) async {
    return createMarkerFromPlace(
      place: place,
      onTap: onTap,
      controller: controller,
    );
  }
}
