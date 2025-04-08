import 'package:flutter/material.dart';
import '../models/place_list.dart';

enum MarkerActionType {
  addToList,
  viewDetails,
  navigate,
  share,
}

class MarkerAction {
  final String label;
  final IconData icon;
  final MarkerActionType type;
  final Function() onPressed;

  MarkerAction({
    required this.label,
    required this.icon,
    required this.type,
    required this.onPressed,
  });
}

class EnhancedMapMarkerWindow extends StatelessWidget {
  final Place place;
  final List<MarkerAction> actions;
  final Color? backgroundColor;
  final Color? accentColor;
  final bool showImage;
  final Widget? additionalContent;
  final double? rating;

  const EnhancedMapMarkerWindow({
    Key? key,
    required this.place,
    required this.actions,
    this.backgroundColor,
    this.accentColor,
    this.showImage = true,
    this.additionalContent,
    this.rating,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? Colors.white;
    final accent = accentColor ?? theme.colorScheme.primary;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if (showImage) _buildImageSection(place, accent),

          // Content section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rating != null) _buildRatingIndicator(rating!),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  place.address,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place.phone != null && place.phone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        place.phone!,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],

                // Additional custom content
                if (additionalContent != null) ...[
                  const SizedBox(height: 8),
                  additionalContent!,
                ],

                const SizedBox(height: 12),

                // Actions row
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: actions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return ElevatedButton.icon(
                        icon: Icon(action.icon, size: 16),
                        label: Text(action.label),
                        onPressed: action.onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(Place place, Color accentColor) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: place.image != null && place.image!.isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    place.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Icon(
                Icons.location_on,
                size: 40,
                color: accentColor,
              ),
            ),
    );
  }

  Widget _buildRatingIndicator(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 16,
          color: Colors.amber[700],
        ),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.amber[800],
          ),
        ),
      ],
    );
  }
}
