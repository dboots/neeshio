import 'package:flutter/material.dart';

import '../services/discover_service.dart';
import '../screens/discover_detail_screen.dart';

/// Widget for displaying category filter chips
class CategoryFilterWidget extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryFilterWidget({
    Key? key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
  final VoidCallback? onSeeAllPressed;

  const FeaturedListsWidget({
    Key? key,
    required this.nearbyLists,
    this.onSeeAllPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nearbyLists.isEmpty) {
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
              const Spacer(),
              if (onSeeAllPressed != null)
                TextButton(
                  onPressed: onSeeAllPressed,
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: nearbyLists.length,
            itemBuilder: (context, index) {
              return FeaturedListCard(nearbyList: nearbyLists[index]);
            },
          ),
        ),
      ],
    );
  }
}

/// Card widget for featured lists
class FeaturedListCard extends StatelessWidget {
  final NearbyList nearbyList;

  const FeaturedListCard({Key? key, required this.nearbyList})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or placeholder
              SizedBox(
                height: 120,
                width: double.infinity,
                child: _getListImage(),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Featured badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                      nearbyList.name,
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
                          nearbyList.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Distance
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getListImage() {

    final color = _getCategoryColor();
    final icon = _getCategoryIcon();

    return Container(
      color: color.withOpacity(0.7),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    final categories =
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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

/// Card widget for category lists
class CategoryListCard extends StatelessWidget {
  final NearbyList nearbyList;

  const CategoryListCard({Key? key, required this.nearbyList})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        width: 180,
        margin: const EdgeInsets.all(8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or placeholder
              SizedBox(
                height: 100,
                width: double.infinity,
                child: _getListImage(),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List name
                    Text(
                      nearbyList.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Places count and distance
                    Row(
                      children: [
                        Text(
                          '${nearbyList.placeCount} places',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          nearbyList.getFormattedDistance(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Rating stars
                    Row(
                      children: [
                        for (int i = 1; i <= 5; i++)
                          Icon(
                            i <= nearbyList.averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber[700],
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

  Widget _getListImage() {
    return Container(
      color: _getCategoryColor(),
      child: Center(
        child: Icon(
          _getCategoryIcon(),
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    final categories =
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

    if (categories.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Colors.orange[300]!;
    } else if (categories
        .any((c) => c.contains('shop') || c.contains('store'))) {
      return Colors.blue[300]!;
    } else if (categories
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Colors.purple[300]!;
    } else if (categories
        .any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Colors.green[300]!;
    }

    return Colors.blueGrey[300]!;
  }

  IconData _getCategoryIcon() {
    final categories =
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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

/// Regular grid card for nearby lists
class NearbyListCard extends StatelessWidget {
  final NearbyList nearbyList;

  const NearbyListCard({Key? key, required this.nearbyList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category color indicator
            Container(
              color: _getCategoryColor(),
              height: 8,
            ),

            // List image or placeholder
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: Center(
                  child: Icon(
                    _getCategoryIcon(),
                    color: _getCategoryColor(),
                    size: 40,
                  ),
                ),
              ),
            ),

            // List details
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List name
                    Text(
                      nearbyList.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // User info
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            nearbyList.userName,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Rating and places
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${nearbyList.placeCount} places',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                    // Distance
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          nearbyList.getFormattedDistance(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                    // Category chips
                    if (nearbyList.categories != null &&
                        nearbyList.categories!.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: nearbyList.categories!
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
                                  category,
                                  style: const TextStyle(fontSize: 8),
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

  Color _getCategoryColor() {
    final categories =
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

    if (categories.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Colors.orange[700]!;
    } else if (categories
        .any((c) => c.contains('shop') || c.contains('store'))) {
      return Colors.blue[700]!;
    } else if (categories
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Colors.purple[700]!;
    } else if (categories
        .any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Colors.green[700]!;
    }

    return Colors.blueGrey[700]!;
  }

  IconData _getCategoryIcon() {
    final categories =
        nearbyList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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

/// Widget for category headers
class CategoryHeaderWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllPressed;

  const CategoryHeaderWidget({
    Key? key,
    required this.title,
    this.onSeeAllPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(title),
            color: _getCategoryColor(title),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (onSeeAllPressed != null)
            TextButton(
              onPressed: onSeeAllPressed,
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('food') || lowerCategory.contains('dining')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('shop') ||
        lowerCategory.contains('boutique')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('museum') ||
        lowerCategory.contains('attraction')) {
      return Icons.museum;
    } else if (lowerCategory.contains('park') ||
        lowerCategory.contains('outdoor')) {
      return Icons.park;
    }

    return Icons.category;
  }

  Color _getCategoryColor(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('food') || lowerCategory.contains('dining')) {
      return Colors.orange;
    } else if (lowerCategory.contains('shop') ||
        lowerCategory.contains('boutique')) {
      return Colors.blue;
    } else if (lowerCategory.contains('museum') ||
        lowerCategory.contains('attraction')) {
      return Colors.purple;
    } else if (lowerCategory.contains('park') ||
        lowerCategory.contains('outdoor')) {
      return Colors.green;
    }

    return Colors.blueGrey;
  }
}

/// Widget for displaying when no nearby lists are found
class EmptyStateWidget extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyStateWidget({
    Key? key,
    required this.onRefresh,
  }) : super(key: key);

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
            'Try changing your location or search radius',
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

/// Widget for displaying when search returned no results
class NoResultsWidget extends StatelessWidget {
  final String category;
  final VoidCallback onShowAllCategories;

  const NoResultsWidget({
    Key? key,
    required this.category,
    required this.onShowAllCategories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No lists found for "$category"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different category or expand your search area',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onShowAllCategories,
            child: const Text('Show All Categories'),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying a loading indicator with a message
class LoadingWidget extends StatelessWidget {
  final String message;

  const LoadingWidget({
    Key? key,
    this.message = 'Loading nearby lists...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
