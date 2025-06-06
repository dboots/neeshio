import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import '../models/place_list.dart';

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
  final LatLng _currentPosition =
      const LatLng(45.521563, -122.677433); // Default to Portland
  bool _locationDetermined = false;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  bool _isLoading = true;
  bool _markersReady = false;

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    // Markers will be created after the map is initialized
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

  Future<void> _createMarkers() async {
    // Create basic markers from places
    final markers = <Marker>{};

    for (final place in widget.list.places) {
      final marker = Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.lat, place.lng),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: place.address,
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${place.name} in ${widget.list.name} list')),
          );
        },
      );
      markers.add(marker);
    }

    setState(() {
      _markers = markers;
      _markersReady = true;
    });
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;

    // Create markers now that the map is initialized
    await _createMarkers();

    if (widget.list.places.isNotEmpty) {
      _fitMapToMarkers();
    }

    if (_locationDetermined) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
      );
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Map: ${widget.list.name}'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 14.0,
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
