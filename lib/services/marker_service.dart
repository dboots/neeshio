import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../models/locations.dart' as Locations;
import '../models/place_list.dart';
import '../widgets/custom_marker_window.dart';

class MarkerService {
  // Map to cache custom marker icons
  final Map<String, BitmapDescriptor> _customMarkerIcons = {};

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
        pinSize +
            12, // Position text to the right of the marker with some padding
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

  // Convert an Office to a Marker with custom marker and info window
  Future<Marker> createMarkerFromOffice({
    required Locations.Office office,
    required Function(Locations.Office) onTap,
    required CustomInfoWindowController controller,
  }) async {
    final place = Place.fromOffice(office);

    // Create or get cached custom marker icon
    if (!_customMarkerIcons.containsKey(office.id)) {
      final customIcon = await createCustomMarkerWithName(office.name);
      _customMarkerIcons[office.id] = customIcon;
    }

    return Marker(
      markerId: MarkerId(office.id),
      position: LatLng(office.lat, office.lng),
      icon: _customMarkerIcons[office.id]!,
      onTap: () {
        // Show custom info window
        controller.addInfoWindow!(
          CustomMarkerWindow(
            place: place,
            onTap: () => onTap(office),
          ),
          LatLng(office.lat, office.lng),
        );
      },
    );
  }

  // Convert a Place to a Marker with custom marker and info window
  Future<Marker> createMarkerFromPlace({
    required Place place,
    required Function(Place) onTap,
    required CustomInfoWindowController controller,
  }) async {
    // Create or get cached custom marker icon
    if (!_customMarkerIcons.containsKey(place.id)) {
      final customIcon = await createCustomMarkerWithName(place.name);
      _customMarkerIcons[place.id] = customIcon;
    }

    return Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.lat, place.lng),
      icon: _customMarkerIcons[place.id]!,
      onTap: () {
        // Show custom info window
        controller.addInfoWindow!(
          CustomMarkerWindow(
            place: place,
            onTap: () => onTap(place),
          ),
          LatLng(place.lat, place.lng),
        );
      },
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
      final marker = await createMarkerFromOffice(
        office: office,
        onTap: onTap,
        controller: controller,
      );
      markers.add(marker);
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
      final marker = await createMarkerFromPlace(
        place: place,
        onTap: onTap,
        controller: controller,
      );
      markers.add(marker);
    }

    return markers;
  }
}
