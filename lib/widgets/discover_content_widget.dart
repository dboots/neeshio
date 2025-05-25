// lib/widgets/discover/discover_content.dart
import 'package:flutter/material.dart';
import 'package:neesh/widgets/discover_states_widgets.dart';
import '../../services/discover_service.dart';
import 'categorized_lists_view.dart';
import 'filtered_lists_view.dart';

class DiscoverContent extends StatelessWidget {
  final bool isFirstLoad;
  final DiscoverService discoverService;
  final Map<String, List<NearbyList>> categorizedLists;
  final String selectedCategory;
  final Future<void> Function() onRefresh; // Changed from VoidCallback

  const DiscoverContent({
    super.key,
    required this.isFirstLoad,
    required this.discoverService,
    required this.categorizedLists,
    required this.selectedCategory,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isFirstLoad) {
      return const LoadingState();
    }

    if (discoverService.error != null) {
      return ErrorState(
        error: discoverService.error!,
        onRetry: () => onRefresh(), // Wrap in lambda to convert Future to void
      );
    }

    final nearbyLists = discoverService.filterByCategory(selectedCategory);

    if (categorizedLists.isEmpty ||
        (selectedCategory != 'All' && nearbyLists.isEmpty)) {
      return EmptyState(onRefresh: () => onRefresh()); // Wrap in lambda
    }

    return RefreshIndicator(
      onRefresh: onRefresh, // Now correctly typed
      child: selectedCategory == 'All'
          ? CategorizedListsView(categorizedLists: categorizedLists)
          : FilteredListsView(
              nearbyLists: nearbyLists,
              selectedCategory: selectedCategory,
            ),
    );
  }
}
