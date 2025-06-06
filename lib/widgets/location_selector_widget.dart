// lib/widgets/discover/location_selector.dart
import 'package:flutter/material.dart';

class LocationSelector extends StatelessWidget {
  final String currentLocationName;
  final bool isLoadingLocation;
  final VoidCallback onLocationTap;
  final String? error;
  final VoidCallback? onRetry;

  const LocationSelector({
    super.key,
    required this.currentLocationName,
    required this.isLoadingLocation,
    required this.onLocationTap,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: isLoadingLocation ? null : onLocationTap,
          child: Row(
            children: [
              Icon(
                error != null ? Icons.location_off : Icons.location_on,
                color: error != null
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      isLoadingLocation
                          ? 'Getting location...'
                          : error != null
                              ? 'Location error'
                              : currentLocationName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: error != null ? Colors.red : null,
                      ),
                    ),
                    // Show error message if there is one
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isLoadingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (error != null && onRetry != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Retry getting location',
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                )
              else
                const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }
}
