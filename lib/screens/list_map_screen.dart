import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/marker_service.dart'; // Import marker service

class ListMapScreen extends StatefulWidget {
  final PlaceList list;

  const ListMapScreen({
    super.key,
    required this.list,
  });

  @override
  State<ListMapScreen> createState() => _ListMapScreenState();
}

class _ListMapScreenState extends State<ListMapScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  // The marker service will be accessed through Provider

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

  Future<void> _createMarkers() async {
    // Use the marker service to create markers from places
    final markerService = Provider.of<MarkerService>(context, listen: false);
    final markers = await markerService.createMarkersFromPlaces(
      places: widget.list.places,
      onTap: (place) {
        // You can add specific actions here if needed when tapped
        // in the list context, or navigate to place details, etc.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${place.name} in ${widget.list.name} list')),
        );
      },
      controller: _customInfoWindowController,
    );

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
