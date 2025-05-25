// lib/widgets/discover/filtered_lists_view.dart
import 'package:flutter/material.dart';
import '../../services/discover_service.dart';
import '../../widgets/discover_widgets.dart';

class FilteredListsView extends StatelessWidget {
  final List<NearbyList> nearbyLists;
  final String selectedCategory;

  const FilteredListsView({
    super.key,
    required this.nearbyLists,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // List grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: nearbyLists.length,
            itemBuilder: (context, index) {
              return NearbyListCard(nearbyList: nearbyLists[index]);
            },
          ),
        ),

        // Bottom spacer for location selector
        const SizedBox(height: 70),
      ],
    );
  }
}