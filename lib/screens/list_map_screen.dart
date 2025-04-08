import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../models/place_list.dart';
import '../widgets/custom_marker_window.dart';

class ListMapScreen extends StatefulWidget {
  final PlaceList list;

  const ListMapScreen({
    Key? key,
    required this.list,
  }) : super(key: key);

  @override
  State<ListMapScreen> createState() => _ListMapScreenState();
}

class _ListMapScreenState extends State<ListMapScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  // Map of place IDs to custom marker icons
  final Map<String, BitmapDescriptor> _customMarkerIcons = {};
  bool _markersReady = false;

  @override
  void initState() {
    super.initState();
    // Markers will be created after the map is initialized
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

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

  Future<void> _createMarkers() async {
    // Create custom marker icons for each place
    for (final place in widget.list.places) {
      if (!_customMarkerIcons.containsKey(place.id)) {
        final customIcon = await createCustomMarkerWithName(place.name);
        _customMarkerIcons[place.id] = customIcon;
      }
    }

    // Create markers with custom icons
    final markers = widget.list.places.map((place) {
      final position = LatLng(place.lat, place.lng);
      return Marker(
        markerId: MarkerId(place.id),
        position: position,
        // Use custom icon with name if available, otherwise use default
        icon: _customMarkerIcons[place.id] ?? BitmapDescriptor.defaultMarker,
        onTap: () {
          // Show custom info window
          _customInfoWindowController.addInfoWindow!(
            CustomMarkerWindow(
              place: place,
              onTap: () {
                // You can add specific actions here if needed when tapped
                // in the list context, or navigate to place details, etc.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('${place.name} in ${widget.list.name} list')),
                );
              },
            ),
            position,
          );
        },
      );
    }).toSet();

    setState(() {
      _markers = markers;
      _markersReady = true;
    });
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;

    // Create markers with names now that the map is initialized
    await _createMarkers();

    if (widget.list.places.isNotEmpty) {
      _fitMapToMarkers();
    }
  }

  void _fitMapToMarkers() {
    if (widget.list.places.isEmpty) return;

    // If there's only one place, zoom to it
    if (widget.list.places.length == 1) {
      final place = widget.list.places.first;
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.lat, place.lng),
          14.0,
        ),
      );
      return;
    }

    // Calculate bounds for all places
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final place in widget.list.places) {
      minLat = minLat < place.lat ? minLat : place.lat;
      maxLat = maxLat > place.lat ? maxLat : place.lat;
      minLng = minLng < place.lng ? minLng : place.lng;
      maxLng = maxLng > place.lng ? maxLng : place.lng;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;

    // Move camera to show all markers
    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        50, // padding in pixels
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map: ${widget.list.name}'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0), // Will be overridden by _fitMapToMarkers
              zoom: 2,
            ),
            markers: _markers,
            onCameraMove: (position) {
              _customInfoWindowController.onCameraMove!();
            },
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 120,
            width: 220,
            offset: 35,
          ),
          if (!_markersReady && widget.list.places.isNotEmpty)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
