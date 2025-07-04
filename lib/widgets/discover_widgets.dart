// lib/widgets/discover_widgets.dart
import 'package:flutter/material.dart';
import '../services/discover_service.dart';
import 'discover/list_card_base.dart';

/// Base mixin for category-related functionality
mixin CategoryMixin {
  Color getCategoryColor(List<String>? categories) {
    final cats = categories?.map((c) => c.toLowerCase()).toList() ?? [];

    if (cats.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Colors.orange;
    } else if (cats.any((c) => c.contains('shop') || c.contains('store'))) {
      return Colors.blue;
    } else if (cats
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Colors.purple;
    } else if (cats.any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Colors.green;
    }
    return Colors.blueGrey;
  }

  IconData getCategoryIcon(List<String>? categories) {
    final cats = categories?.map((c) => c.toLowerCase()).toList() ?? [];

    if (cats.any((c) => c.contains('food') || c.contains('restaurant'))) {
      return Icons.restaurant;
    } else if (cats.any((c) => c.contains('shop') || c.contains('store'))) {
      return Icons.shopping_bag;
    } else if (cats
        .any((c) => c.contains('museum') || c.contains('attraction'))) {
      return Icons.museum;
    } else if (cats.any((c) => c.contains('park') || c.contains('outdoor'))) {
      return Icons.park;
    }
    return Icons.place;
  }
}

/// Widget to display vote information
class VoteDisplay extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final double size;
  final bool showCounts;

  const VoteDisplay({
    Key? key,
    required this.upvotes,
    required this.downvotes,
    this.size = 12,
    this.showCounts = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalVotes = upvotes + downvotes;
    final percentage = totalVotes > 0 ? (upvotes / totalVotes) * 100 : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.thumb_up,
          size: size,
          color: Colors.green,
        ),
        if (showCounts) ...[
          const SizedBox(width: 2),
          Text(
            upvotes.toString(),
            style: TextStyle(
              fontSize: size - 2,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Icon(
          Icons.thumb_down,
          size: size,
          color: Colors.red,
        ),
        if (showCounts) ...[
          const SizedBox(width: 2),
          Text(
            downvotes.toString(),
            style: TextStyle(
              fontSize: size - 2,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (!showCounts && totalVotes > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${percentage.round()}%',
            style: TextStyle(
              fontSize: size - 2,
              color: percentage >= 70
                  ? Colors.green
                  : percentage >= 50
                      ? Colors.orange
                      : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card widget for featured lists
class FeaturedListCard extends StatelessWidget with CategoryMixin {
  final NearbyList nearbyList;

  const FeaturedListCard({Key? key, required this.nearbyList})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListCardBase(
      nearbyList: nearbyList,
      width: 250,
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with category color
          Container(
            height: 120,
            width: double.infinity,
            color: getCategoryColor(nearbyList.categories).withOpacity(0.7),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    getCategoryIcon(nearbyList.categories),
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                // Vote score indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: VoteDisplay(
                      upvotes: nearbyList.upvotes,
                      downvotes: nearbyList.downvotes,
                      size: 10,
                      showCounts: false,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Featured badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // User and rating row
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        nearbyList.userName,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Distance and votes
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      nearbyList.getFormattedDistance(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    VoteDisplay(
                      upvotes: nearbyList.upvotes,
                      downvotes: nearbyList.downvotes,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for category lists
class CategoryListCard extends StatelessWidget with CategoryMixin {
  final NearbyList nearbyList;

  const CategoryListCard({Key? key, required this.nearbyList})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListCardBase(
      nearbyList: nearbyList,
      width: 180,
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 100,
            width: double.infinity,
            color: getCategoryColor(nearbyList.categories).withOpacity(0.3),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    getCategoryIcon(nearbyList.categories),
                    color: getCategoryColor(nearbyList.categories),
                    size: 30,
                  ),
                ),
                // Vote indicator
                if (nearbyList.upvotes + nearbyList.downvotes > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: VoteDisplay(
                        upvotes: nearbyList.upvotes,
                        downvotes: nearbyList.downvotes,
                        size: 10,
                        showCounts: false,
                      ),
                    ),
                  ),
              ],
            ),
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
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Places count and distance
                Row(
                  children: [
                    Text(
                      '${nearbyList.placeCount} places',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      nearbyList.getFormattedDistance(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Rating stars and vote score
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (i) => Icon(
                              i < nearbyList.averageRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: Colors.amber[700],
                            )),
                    const Spacer(),
                    if (nearbyList.voteScore != 0)
                      Text(
                        nearbyList.voteScore > 0
                            ? '+${nearbyList.voteScore}'
                            : '${nearbyList.voteScore}',
                        style: TextStyle(
                          fontSize: 10,
                          color: nearbyList.voteScore > 0
                              ? Colors.green
                              : Colors.red,
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
    );
  }
}

/// Regular grid card for nearby lists
class NearbyListCard extends StatelessWidget with CategoryMixin {
  final NearbyList nearbyList;

  const NearbyListCard({Key? key, required this.nearbyList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListCardBase(
      nearbyList: nearbyList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category color indicator
          Container(
            color: getCategoryColor(nearbyList.categories),
            height: 8,
          ),

          // List image placeholder
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      getCategoryIcon(nearbyList.categories),
                      color: getCategoryColor(nearbyList.categories),
                      size: 40,
                    ),
                  ),
                  // Vote score
                  if (nearbyList.voteScore != 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: nearbyList.voteScore > 0
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          nearbyList.voteScore > 0
                              ? '+${nearbyList.voteScore}'
                              : '${nearbyList.voteScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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
                        fontWeight: FontWeight.bold, fontSize: 14),
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
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 10),
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),

                  // Distance and votes
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        nearbyList.getFormattedDistance(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                      const Spacer(),
                      if (nearbyList.upvotes + nearbyList.downvotes > 0)
                        VoteDisplay(
                          upvotes: nearbyList.upvotes,
                          downvotes: nearbyList.downvotes,
                          size: 10,
                          showCounts: false,
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
                          children:
                              nearbyList.categories!.take(3).map((category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(category,
                                  style: const TextStyle(fontSize: 8)),
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
    );
  }
}
