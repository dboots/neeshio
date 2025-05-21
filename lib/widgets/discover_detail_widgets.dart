import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:neesh/models/place_rating.dart';

import '../models/place_list.dart';
import '../services/discover_service.dart';
import '../widgets/star_rating_widget.dart';

/// Widget for displaying map with places from a list
class ListMapWidget extends StatefulWidget {
  final PlaceList list;
  final Function(GoogleMapController) onMapCreated;
  final CustomInfoWindowController customInfoWindowController;
  final Set<Marker> markers;
  final bool isLoading;

  const ListMapWidget({
    super.key,
    required this.list,
    required this.onMapCreated,
    required this.customInfoWindowController,
    required this.markers,
    required this.isLoading,
  });

  @override
  State<ListMapWidget> createState() => _ListMapWidgetState();
}

class _ListMapWidgetState extends State<ListMapWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: widget.onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0), // Will be overridden by _fitMapToMarkers
              zoom: 2,
            ),
            markers: widget.markers,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onCameraMove: (position) {
              widget.customInfoWindowController.onCameraMove!();
            },
          ),
          CustomInfoWindow(
            controller: widget.customInfoWindowController,
            height: 120,
            width: 220,
            offset: 35,
          ),
          if (widget.isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Widget for displaying user info and rating
class UserInfoWidget extends StatelessWidget {
  final NearbyList nearbyList;

  const UserInfoWidget({
    super.key,
    required this.nearbyList,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Widget for displaying a stat card
class StatCardWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const StatCardWidget({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Widget for displaying list stats (places, categories, distance)
class ListStatsWidget extends StatelessWidget {
  final PlaceList list;
  final NearbyList nearbyList;

  const ListStatsWidget({
    super.key,
    required this.list,
    required this.nearbyList,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatCardWidget(
          icon: Icons.place,
          value: '${list.entries.length}',
          label: 'Places',
        ),
        StatCardWidget(
          icon: Icons.category,
          value: '${list.ratingCategories.length}',
          label: 'Categories',
        ),
        StatCardWidget(
          icon: Icons.near_me,
          value: nearbyList.getFormattedDistance(),
          label: 'Away',
        ),
      ],
    );
  }
}

/// Widget for displaying rating categories
class RatingCategoriesWidget extends StatelessWidget {
  final List<RatingCategory> categories;

  const RatingCategoriesWidget({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
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
          children: categories.map((category) {
            return Chip(
              label: Text(category.name),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Widget for displaying a place item in a list
/// Widget for displaying a place item in a list
class PlaceItemWidget extends StatelessWidget {
  final PlaceEntry entry;
  final List<RatingCategory> ratingCategories;
  final VoidCallback onTap;

  const PlaceItemWidget({
    super.key,
    required this.entry,
    required this.ratingCategories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Place title and basic info
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place),
              title: Text(
                entry.place.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                entry.place.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: entry.ratings.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          (entry.getAverageRating() ?? 0).toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    )
                  : null,
              onTap: onTap,
            ),

            // Show ratings for each category if they exist
            if (entry.ratings.isNotEmpty && ratingCategories.isNotEmpty) ...[
              const Divider(height: 16),
              const Text(
                'Ratings:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...ratingCategories.map((category) {
                final rating = entry.getRating(category.id);
                if (rating == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
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
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying the places list
class PlacesListWidget extends StatelessWidget {
  final PlaceList list;
  final Function(double lat, double lng) onPlaceSelected;

  const PlacesListWidget({
    super.key,
    required this.list,
    required this.onPlaceSelected,
  });

  @override
  Widget build(BuildContext context) {
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
        Expanded(
          child: ListView.builder(
            itemCount: list.entries.length,
            itemBuilder: (context, index) {
              final entry = list.entries[index];
              return PlaceItemWidget(
                entry: entry,
                onTap: () => onPlaceSelected(entry.place.lat, entry.place.lng),
                ratingCategories: list.ratingCategories
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Widget for the save button
class SaveButtonWidget extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const SaveButtonWidget({
    super.key,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: isSaving
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
}
