import 'package:flutter/material.dart';

import '../models/place_list.dart';
import '../services/discover_service.dart';
import '../screens/discover_detail_screen.dart';

/// Widget for displaying category filter chips
class CategoryFilterWidget extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryFilterWidget({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              onSelected: (selected) {
                if (selected) {
                  onCategorySelected(category);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

/// Widget for displaying a horizontal list of featured lists
class FeaturedListsWidget extends StatelessWidget {
  final List<NearbyList> nearbyLists;

  const FeaturedListsWidget({
    super.key,
    required this.nearbyLists,
  });

  @override
  Widget build(BuildContext context) {
    // Select top 3 lists with highest ratings for featured section
    final featuredLists = List<NearbyList>.from(nearbyLists)
      ..sort((a, b) => b.userRating.compareTo(a.userRating));

    if (featuredLists.isEmpty) {
      return const SizedBox.shrink();
    }

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
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: featuredLists.length > 3 ? 3 : featuredLists.length,
            itemBuilder: (context, index) {
              final nearbyList = featuredLists[index];
              return FeaturedListCard(nearbyList: nearbyList);
            },
          ),
        ),
      ],
    );
  }
}

/// Card widget for displaying a featured list
class FeaturedListCard extends StatelessWidget {
  final NearbyList nearbyList;

  const FeaturedListCard({
    super.key,
    required this.nearbyList,
  });

  @override
  Widget build(BuildContext context) {
    final list = nearbyList.list;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscoverDetailScreen(nearbyList: nearbyList),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or placeholder
              SizedBox(
                height: 120,
                width: double.infinity,
                child: ListImageWidget(list: list),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge for featured status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Top Rated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // List name
                    Text(
                      list.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // User and rating
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.userName,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.userRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid item card for a nearby list
class NearbyListCard extends StatelessWidget {
  final NearbyList nearbyList;

  const NearbyListCard({
    super.key,
    required this.nearbyList,
  });

  @override
  Widget build(BuildContext context) {
    final list = nearbyList.list;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscoverDetailScreen(nearbyList: nearbyList),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category color
            Container(
              color: Theme.of(context).colorScheme.primary,
              height: 8,
            ),

            // List image or placeholder
            Expanded(
              flex: 5,
              child: ListImageWidget(list: list),
            ),

            // List info
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List name
                    Text(
                      list.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // User info
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.userName,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Place count and ratings
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.userRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${list.entries.length} places",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Distance
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.getFormattedDistance(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Category icons/chips
                    if (list.ratingCategories.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: list.ratingCategories
                                .take(3) // Limit to 3 categories
                                .map((category) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  category.name,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display list images or placeholders
class ListImageWidget extends StatelessWidget {
  final PlaceList list;

  const ListImageWidget({
    super.key,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    // Try to find a place with an image
    Place? placeWithImage;
    try {
      placeWithImage = list.entries.map((e) => e.place).firstWhere(
            (place) => place.image != null && place.image!.isNotEmpty,
          );
    } catch (e) {
      // No place with image found, use first place or null
      placeWithImage =
          list.entries.isNotEmpty ? list.entries.first.place : null;
    }

    if (placeWithImage != null && placeWithImage.image != null) {
      return Image.network(
        placeWithImage.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(list),
      );
    }

    return _buildPlaceholder(list);
  }

  Widget _buildPlaceholder(PlaceList list) {
    // Generate a color based on the list name
    final colorSeed = list.name.hashCode;
    final colors = [
      Colors.blueGrey,
      Colors.indigo,
      Colors.teal,
      Colors.purple,
      Colors.amber,
      Colors.deepOrange,
    ];

    final color = colors[colorSeed.abs() % colors.length];

    return Container(
      color: color.withOpacity(0.7),
      child: Center(
        child: Icon(
          _getCategoryIcon(list),
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(PlaceList list) {
    final name = list.name.toLowerCase();

    if (name.contains('food') ||
        name.contains('restaurant') ||
        name.contains('cafe')) {
      return Icons.restaurant;
    } else if (name.contains('shop') ||
        name.contains('store') ||
        name.contains('mall')) {
      return Icons.shopping_bag;
    } else if (name.contains('activity') ||
        name.contains('fun') ||
        name.contains('entertainment')) {
      return Icons.attractions;
    } else if (name.contains('sight') ||
        name.contains('museum') ||
        name.contains('landmark')) {
      return Icons.museum;
    } else if (name.contains('park') ||
        name.contains('nature') ||
        name.contains('hike')) {
      return Icons.park;
    }

    return Icons.place;
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyStateWidget({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.explore_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No nearby lists found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try changing your location or check back later',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRefresh,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying no results for a category
class NoCategoryResultsWidget extends StatelessWidget {
  final VoidCallback onShowAllCategories;

  const NoCategoryResultsWidget({
    super.key,
    required this.onShowAllCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No lists found for this category',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onShowAllCategories,
            child: const Text('Show all categories'),
          ),
        ],
      ),
    );
  }
}
