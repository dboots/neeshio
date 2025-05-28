import 'package:flutter/material.dart';
import 'package:neesh/utils/user_profile_navigation.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/discover_service.dart';
import '../services/auth_service.dart';
import '../widgets/star_rating_widget.dart';
import '../models/place_list.dart';
import '../screens/place_map_screen.dart';

class DiscoverDetailScreen extends StatefulWidget {
  final NearbyList nearbyList;

  const DiscoverDetailScreen({
    Key? key,
    required this.nearbyList,
  }) : super(key: key);

  @override
  State<DiscoverDetailScreen> createState() => _DiscoverDetailScreenState();
}

class _DiscoverDetailScreenState extends State<DiscoverDetailScreen> {
  bool _isLoading = true;
  bool _isVoting = false;
  late NearbyList _currentList;

  @override
  void initState() {
    super.initState();
    _currentList = widget.nearbyList;
    _fetchListDetails();
  }

  // Fetch additional details if needed
  Future<void> _fetchListDetails() async {
    // In a real app, you might need to fetch additional details
    // For this example, we'll simulate a delay
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  Future<void> _handleVote(int voteValue) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated) {
      _showSignInRequired();
      return;
    }

    setState(() => _isVoting = true);

    try {
      final discoverService =
          Provider.of<DiscoverService>(context, listen: false);

      // Determine the actual vote value to send
      int actualVoteValue;
      if (_currentList.userVote == voteValue) {
        // User is removing their vote
        actualVoteValue = 0;
      } else {
        // User is voting or changing their vote
        actualVoteValue = voteValue;
      }

      // Call the service to vote
      await discoverService.voteOnList(_currentList.id, actualVoteValue);

      // Update local state
      setState(() {
        int newUpvotes = _currentList.upvotes;
        int newDownvotes = _currentList.downvotes;

        // Remove previous vote if any
        if (_currentList.userVote == 1) {
          newUpvotes--;
        } else if (_currentList.userVote == -1) {
          newDownvotes--;
        }

        // Add new vote if not removing
        if (actualVoteValue == 1) {
          newUpvotes++;
        } else if (actualVoteValue == -1) {
          newDownvotes++;
        }

        _currentList = _currentList.copyWithVote(
          newUpvotes: newUpvotes,
          newDownvotes: newDownvotes,
          newUserVote: actualVoteValue == 0 ? null : actualVoteValue,
        );
        _isVoting = false;
      });

      // Show feedback
      final String message = actualVoteValue == 0
          ? 'Vote removed'
          : actualVoteValue == 1
              ? 'Thanks for your upvote!'
              : 'Feedback recorded';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isVoting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSignInRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to vote on lists.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, you might navigate to login screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigate to login screen to sign in'),
                ),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showPlaceOnMap(String placeName, String address) {
    // Create a place object from the placeholder data
    final place = _createPlaceFromPlaceholder(placeName, address);

    // Navigate to the map screen with the specific place
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceMapScreen(
          place: place,
          title: 'Location: $placeName',
        ),
      ),
    );
  }

  Place _createPlaceFromPlaceholder(String placeName, String address) {
    // Generate a location based on the address
    // In a real app, you'd geocode the address or have stored coordinates
    final coordinates = _getCoordinatesForAddress(address);

    return Place(
      id: 'placeholder_${placeName.toLowerCase().replaceAll(' ', '_')}',
      name: placeName,
      address: address,
      lat: coordinates.latitude,
      lng: coordinates.longitude,
      image: null,
      phone: null,
    );
  }

  LatLng _getCoordinatesForAddress(String address) {
    // Simple geocoding simulation based on city
    // In a real app, you'd use proper geocoding services
    if (address.contains('Hudson, OH')) {
      return const LatLng(41.2407, -81.4412);
    } else if (address.contains('Cleveland, OH')) {
      return const LatLng(41.5085, -81.6954);
    } else if (address.contains('Akron, OH')) {
      return const LatLng(41.0814, -81.5191);
    } else if (address.contains('Canton, OH')) {
      return const LatLng(40.7989, -81.3789);
    } else if (address.contains('Medina, OH')) {
      return const LatLng(41.1384, -81.8637);
    }

    // Default to Hudson with some random offset
    final random = address.hashCode % 1000;
    return LatLng(
      41.2407 + (random % 100 - 50) * 0.001, // Small random offset
      -81.4412 + (random % 100 - 50) * 0.001,
    );
  }

  String _generatePlaceholderAddress(int index) {
    // Generate realistic placeholder addresses
    final streets = [
      'Main Street',
      'Oak Avenue',
      'Park Boulevard',
      'First Street',
      'Market Street',
      'Broadway',
      'Cedar Lane',
      'Elm Street',
      'Pine Avenue',
      'Washington Street',
    ];

    final cities = [
      'Hudson, OH',
      'Cleveland, OH',
      'Akron, OH',
      'Canton, OH',
      'Medina, OH',
    ];

    final streetNumber = 100 + (index * 47) % 900;
    final street = streets[index % streets.length];
    final city = cities[index % cities.length];

    return '$streetNumber $street, $city';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentList.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // List details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info and rating
                        _buildUserInfo(),
                        const SizedBox(height: 16),

                        // Description
                        if (_currentList.description != null) ...[
                          Text(
                            _currentList.description!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Voting section
                        _buildVotingSection(),

                        const SizedBox(height: 16),

                        // Rating categories
                        if (_currentList.categories != null &&
                            _currentList.categories!.isNotEmpty) ...[
                          _buildRatingCategories(),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  // Places list
                  _buildPlacesList(),

                  // Add some bottom padding
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      spacing: 10,
      children: [
        // Clickable user avatar
        UserProfileNavigation.createUserAvatar(
          context: context,
          userId: _currentList.userId,
          userName: _currentList.userName,
          avatarUrl: null, // You could add avatar URL to NearbyList model
          radius: 24,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clickable user name
              UserProfileNavigation.createUserProfileTap(
                context: context,
                userId: _currentList.userId,
                userName: _currentList.userName,
                child: Text(
                  _currentList.userName,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey,
                  ),
                ),
              ),
              const Text(
                '312 Lists', // This could be dynamic from user stats
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
        // Follow button
        IconButton(
          padding: const EdgeInsets.all(7),
          constraints: const BoxConstraints(),
          onPressed: () {
            // This could integrate with user following functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Follow functionality coming soon!')),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red,
          ),
          iconSize: 18,
          icon: const Icon(Icons.favorite),
        ),
        // Subscribe button
        TextButton(
          onPressed: () {
            // Navigate to user profile instead of generic subscribe
            UserProfileNavigation.navigateToUserProfile(
              context,
              userId: _currentList.userId,
              userName: _currentList.userName,
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: const Text('View Profile'),
        ),
        const Text('\$1.49'), // This could be dynamic pricing
      ],
    );
  }

  Widget _buildVotingSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate this list',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Upvote button
                _buildVoteButton(
                  icon: Icons.thumb_up,
                  count: _currentList.upvotes,
                  isSelected: _currentList.userVote == 1,
                  onPressed: _isVoting ? null : () => _handleVote(1),
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                // Downvote button
                _buildVoteButton(
                  icon: Icons.thumb_down,
                  count: _currentList.downvotes,
                  isSelected: _currentList.userVote == -1,
                  onPressed: _isVoting ? null : () => _handleVote(-1),
                  color: Colors.red,
                ),
                const Spacer(),
                // Vote ratio indicator
                if (_currentList.upvotes + _currentList.downvotes > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_currentList.votePercentage.round()}% positive',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_currentList.upvotes + _currentList.downvotes} total votes',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (_isVoting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(
        count.toString(),
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[100],
        foregroundColor: isSelected ? Colors.white : color,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCategories() {
    final categories = _currentList.categories ?? [];

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
          runSpacing: 8,
          children: categories.map((category) {
            return Chip(
              label: Text(category),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlacesList() {
    // Generate placeholder places for demo purposes
    // In a real app, use actual place data
    final places = List.generate(
      _currentList.placeCount,
      (index) => _buildPlaceholderItem(index),
    );

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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          itemBuilder: (context, index) => places[index],
        ),
      ],
    );
  }

  Widget _buildPlaceholderItem(int index) {
    // Create a placeholder place item
    // This would be replaced with actual place data in a real app

    final placeName = 'Place ${index + 1}';
    final categories = _currentList.categories ?? [];
    final ratingValue = 3 + (index % 3);
    final placeAddress = _generatePlaceholderAddress(index);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(),
                child: Icon(
                  _getCategoryIcon(),
                  color: Colors.white,
                ),
              ),
              title: Text(
                placeName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          placeAddress,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.map, color: Colors.blue),
                tooltip: 'Show on map',
                onPressed: () => _showPlaceOnMap(placeName, placeAddress),
              ),
            ),

            // Show ratings if categories exist
            if (categories.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Ratings:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...categories.take(3).map((category) {
                // Simulate different ratings
                final rating =
                    (ratingValue + categories.indexOf(category)) % 5 + 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
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
              }),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    final categories =
        _currentList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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
        _currentList.categories?.map((c) => c.toLowerCase()).toList() ?? [];

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
