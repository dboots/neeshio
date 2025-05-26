import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_list.dart';

class PlaceMapScreen extends StatefulWidget {
  final Place place;
  final String title;

  const PlaceMapScreen({
    super.key,
    required this.place,
    required this.title,
  });

  @override
  State<PlaceMapScreen> createState() => _PlaceMapScreenState();
}

class _PlaceMapScreenState extends State<PlaceMapScreen> {
  late GoogleMapController _mapController;
  late Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    _markers = {
      Marker(
        markerId: MarkerId(widget.place.id),
        position: LatLng(widget.place.lat, widget.place.lng),
        infoWindow: InfoWindow(
          title: widget.place.name,
          snippet: widget.place.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _centerOnPlace() {
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.place.lat, widget.place.lng),
        16.0,
      ),
    );
  }

  void _openInExternalMaps() {
    // In a real app, you would use url_launcher to open external maps
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${widget.place.name} in external maps...'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on place',
            onPressed: _centerOnPlace,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in external maps',
            onPressed: _openInExternalMaps,
          ),
        ],
      ),
      body: Column(
        children: [
          // Place info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.place.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.place.address,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.place.phone != null &&
                    widget.place.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        widget.place.phone!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.place.lat, widget.place.lng),
                zoom: 15.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // We have our own button
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
              compassEnabled: true,
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoom_in",
            mini: true,
            onPressed: () {
              _mapController.animateCamera(CameraUpdate.zoomIn());
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "zoom_out",
            mini: true,
            onPressed: () {
              _mapController.animateCamera(CameraUpdate.zoomOut());
            },
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "directions",
            onPressed: () {
              // In a real app, you would integrate with navigation services
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Getting directions to ${widget.place.name}...'),
                  action: SnackBarAction(
                    label: 'OK',
                    onPressed: () {},
                  ),
                ),
              );
            },
            child: const Icon(Icons.directions),
          ),
        ],
      ),
    );
  }
}