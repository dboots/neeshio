// lib/widgets/discover/categorized_lists_view.dart
import 'package:flutter/material.dart';
import 'package:neesh/widgets/category_sections.dart';
import '../../services/discover_service.dart';

class CategorizedListsView extends StatelessWidget {
  final Map<String, List<NearbyList>> categorizedLists;

  const CategorizedListsView({
    super.key,
    required this.categorizedLists,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Featured lists section
        if (categorizedLists.containsKey('Featured') &&
            categorizedLists['Featured']!.isNotEmpty)
          FeaturedSection(featuredLists: categorizedLists['Featured']!),

        // Each category section
        for (final entry in categorizedLists.entries)
          if (entry.key != 'Featured' && entry.value.isNotEmpty)
            CategorySection(
              categoryName: entry.key,
              categoryLists: entry.value,
            ),

        // Add bottom padding for the location selector
        const SizedBox(height: 70),
      ],
    );
  }
}