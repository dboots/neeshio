import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:provider/provider.dart';

import '../services/discover_service.dart';
import '../services/place_list_service.dart';
import '../widgets/discover_detail_widgets.dart';

class DiscoverDetailScreen extends StatefulWidget {
  final NearbyList nearbyList;

  const DiscoverDetailScreen({
    super.key,
    required this.nearbyList,
  });

  @override
  State<DiscoverDetailScreen> createState() => _DiscoverDetailScreenState();
}

class _DiscoverDetailScreenState extends State<DiscoverDetailScreen> {
  late GoogleMapController _mapController;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _saveToMyLists() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final listService = Provider.of<PlaceListService>(context, listen: false);

      // Create a copy of the list with a new ID
      final savedList = await listService.createList(
        '${widget.nearbyList.list.name} (Saved)',
        widget.nearbyList.list.description,
        widget.nearbyList.list.ratingCategories,
      );

      // Add all places to the new list
      for (final entry in widget.nearbyList.list.entries) {
        await listService.addPlaceToList(
          savedList.id,
          entry.place,
          ratings: entry.ratings,
          notes: entry.notes,
        );
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('List saved to your lists!')),
        );

        // Return to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving list: $e')),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;
    _createMarkers();
  }

  Future<void> _createMarkers() async {
    // Create basic markers for all places in the list
    final markers = <Marker>{};

    for (final place in widget.nearbyList.list.places) {
      final marker = Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.lat, place.lng),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: place.address,
        ),
      );
      markers.add(marker);
    }

    setState(() {
      _markers = markers;
      _isLoading = false;
    });

    // Fit map to show all markers
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (widget.nearbyList.list.places.isEmpty) return;

    // If there's only one place, zoom to it
    if (widget.nearbyList.list.places.length == 1) {
      final place = widget.nearbyList.list.places.first;
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

    for (final place in widget.nearbyList.list.places) {
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

  void _zoomToPlace(double lat, double lng) {
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(lat, lng),
        16.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyList = widget.nearbyList;
    final list = nearbyList.list;

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map preview
            ListMapWidget(
              list: list,
              onMapCreated: _onMapCreated,
              customInfoWindowController: _customInfoWindowController,
              markers: _markers,
              isLoading: _isLoading,
            ),

            // List details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info and rating
                  UserInfoWidget(nearbyList: nearbyList),

                  const SizedBox(height: 16),

                  // Description
                  if (list.description != null) ...[
                    Text(
                      list.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // List stats
                  ListStatsWidget(list: list, nearbyList: nearbyList),

                  const SizedBox(height: 16),

                  // Rating categories
                  if (list.ratingCategories.isNotEmpty) ...[
                    RatingCategoriesWidget(categories: list.ratingCategories),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),

            // Places list - using a fixed height container
            Container(
              height: 300, // Fixed height to prevent overflow
              child: PlacesListWidget(
                list: list,
                onPlaceSelected: (lat, lng) => _zoomToPlace(lat, lng),
              ),
            ),

            // Add some bottom padding to account for the bottom app bar
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: SaveButtonWidget(
          isSaving: _isSaving,
          onSave: _saveToMyLists,
        ),
      ),
    );
  }
}
