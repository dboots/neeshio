import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';

import '../services/discover_service.dart';
import '../utils/location_utils.dart';
import '../widgets/star_rating_widget.dart';

class DiscoverDetailScreen extends StatefulWidget {
  final NearbyList nearbyList;

  const DiscoverDetailScreen({
    Key? key,
    required this.nearbyList,
  }) : super(key: key);

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
  void initState() {
    super.initState();
    _fetchListDetails();
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Fetch additional details if needed
  Future<void> _fetchListDetails() async {
    // In a real app, you might need to fetch additional details
    // For this example, we'll simulate a delay
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  Future<void> _saveToMyLists() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // This would typically fetch the places from the API
      // For now, show a success message
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
    // Simulate marker creation for places in the list
    // In a real app, you would use actual place data
    final markers = <Marker>{};

    // For demo purposes, create markers for simulated places
    for (int i = 0; i < widget.nearbyList.placeCount; i++) {
      // Create a marker at a slightly offset location from the center
      final offset = 0.002 * i;
      final marker = Marker(
        markerId: MarkerId('place_$i'),
        position: LatLng(
          widget.nearbyList.lat + offset * cos(i * 0.5),
          widget.nearbyList.lng + offset * sin(i * 0.5),
        ),
        infoWindow: InfoWindow(
          title: 'Place ${i + 1}',
          snippet: 'Part of ${widget.nearbyList.name}',
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
    if (_markers.isEmpty) return;

    final List<LatLng> positions =
        _markers.map((marker) => marker.position).toList();

    // Use LocationUtils to calculate bounds with padding
    final bounds = LocationUtils.calculateBounds(positions);

    // Move camera to show all markers
    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // padding in pixels
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

    return Scaffold(
      appBar: AppBar(
        title: Text(nearbyList.name),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Map preview
                  _buildMapSection(),

                  // List details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info and rating
                        _buildUserInfo(),

                        const SizedBox(height: 16),

                        // Description
                        if (nearbyList.description != null) ...[
                          Text(
                            nearbyList.description!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // List stats
                        _buildListStats(),

                        const SizedBox(height: 16),

                        // Rating categories
                        if (nearbyList.categories != null &&
                            nearbyList.categories!.isNotEmpty) ...[
                          _buildRatingCategories(),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  // Places list
                  _buildPlacesList(),

                  // Add some bottom padding to account for the bottom app bar
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: _buildSaveButton(),
      ),
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.nearbyList.lat, widget.nearbyList.lng),
              zoom: 14.0,
            ),
            markers: _markers,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final nearbyList = widget.nearbyList;

    return Row(
      children: [
        const Icon(Icons.person, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          nearbyList.userName,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        StarRatingDisplay(
          rating: nearbyList.averageRating,
          showValue: true,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildListStats() {
    final nearbyList = widget.nearbyList;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
          icon: Icons.place,
          value: '${nearbyList.placeCount}',
          label: 'Places',
        ),
        _buildStatCard(
          icon: Icons.category,
          value: '${nearbyList.categoryCount}',
          label: 'Categories',
        ),
        _buildStatCard(
          icon: Icons.near_me,
          value: nearbyList.getFormattedDistance(),
          label: 'Away',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCategories() {
    final categories = widget.nearbyList.categories ?? [];

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating Categories',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            return Chip(
              label: Text(category),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlacesList() {
    // Generate placeholder places for demo purposes
    // In a real app, use actual place data
    final places = List.generate(
      widget.nearbyList.placeCount,
      (index) => _buildPlaceholderItem(index),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Places in this list',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          itemBuilder: (context, index) => places[index],
        ),
      ],
    );
  }

  Widget _buildPlaceholderItem(int index) {
    // Create a placeholder place item
    // This would be replaced with actual place data in a real app

    final placeName = 'Place ${index + 1}';
    final categories = widget.nearbyList.categories ?? [];
    final ratingValue = 3 + (index % 3);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(),
                child: Icon(
                  _getCategoryIcon(),
                  color: Colors.white,
                ),
              ),
              title: Text(
                placeName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Part of ${widget.nearbyList.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  // Simulated position
                  final offset = 0.002 * index;
                  _zoomToPlace(
                    widget.nearbyList.lat + offset * cos(index * 0.5),
                    widget.nearbyList.lng + offset * sin(index * 0.5),
                  );
                },
              ),
            ),

            // Show ratings if categories exist
            if (categories.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Ratings:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...categories.take(3).map((category) {
                // Simulate different ratings
                final rating =
                    (ratingValue + categories.indexOf(category)) % 5 + 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      StarRatingDisplay(
                        rating: rating.toDouble(),
                        size: 14,
                        showValue: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$rating/5',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveToMyLists,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text('Save to My Lists'),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    final categories =
        widget.nearbyList.categories?.map((c) => c.toLowerCase()).toList() ??
            [];

    if (categories.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Colors.orange;
    } else if (categories
        .any((c) => c.contains('shop') || c.contains('store'))) {
      return Colors.blue;
    } else if (categories
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Colors.purple;
    } else if (categories
        .any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Colors.green;
    }

    return Colors.blueGrey;
  }

  IconData _getCategoryIcon() {
    final categories =
        widget.nearbyList.categories?.map((c) => c.toLowerCase()).toList() ??
            [];

    if (categories.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Icons.restaurant;
    } else if (categories
        .any((c) => c.contains('shop') || c.contains('store'))) {
      return Icons.shopping_bag;
    } else if (categories
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Icons.museum;
    } else if (categories
        .any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Icons.park;
    }

    return Icons.place;
  }
}

// Helper extension for NearbyList
extension NearbyListExtension on NearbyList {
  // Provide coordinates for map (use first place or fallback to a default)
  double get lat => distance > 0 ? 41.2407 : 41.2407; // Fallback to Hudson
  double get lng => distance > 0 ? -81.4412 : -81.4412; // Fallback to Hudson
}
