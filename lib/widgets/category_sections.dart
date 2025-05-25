// lib/widgets/discover/featured_section.dart
import 'package:flutter/material.dart';
import '../../services/discover_service.dart';
import '../../widgets/discover_widgets.dart';

class FeaturedSection extends StatelessWidget {
  final List<NearbyList> featuredLists;

  const FeaturedSection({
    super.key,
    required this.featuredLists,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.amber[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Featured Lists',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: featuredLists.length,
            itemBuilder: (context, index) {
              return FeaturedListCard(nearbyList: featuredLists[index]);
            },
          ),
        ),
      ],
    );
  }
}

class CategorySection extends StatelessWidget {
  final String categoryName;
  final List<NearbyList> categoryLists;

  const CategorySection({
    super.key,
    required this.categoryName,
    required this.categoryLists,
  });

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'attractions':
        return Icons.museum;
      case 'outdoors':
        return Icons.park;
      default:
        return Icons.place;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Colors.orange;
      case 'shopping':
        return Colors.blue;
      case 'attractions':
        return Colors.purple;
      case 'outdoors':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(categoryName),
                color: _getCategoryColor(categoryName),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to filtered view for this category
                },
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: categoryLists.length,
            itemBuilder: (context, index) {
              return CategoryListCard(nearbyList: categoryLists[index]);
            },
          ),
        ),
      ],
    );
  }
}