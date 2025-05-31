// lib/screens/public_user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/user_profile_service.dart';
import '../services/auth_service.dart';
import '../screens/list_detail_screen.dart';
import '../screens/list_map_screen.dart';
import '../widgets/star_rating_widget.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isSubscribed = false;
  String? _error;

  // User profile data
  Map<String, dynamic>? _userProfile;
  List<PlaceList> _publicLists = [];
  Map<String, dynamic> _profileStats = {};

  // Subscription data
  double _subscriptionPrice =
      2.99; // Default price, could be fetched from profile
  bool _isProcessingSubscription = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProfileService =
          Provider.of<UserProfileService>(context, listen: false);

      // Load user profile data
      final profileData =
          await userProfileService.getPublicUserProfile(widget.userId);

      if (profileData != null) {
        setState(() {
          _userProfile = profileData['profile'];
          _publicLists = profileData['public_lists'] as List<PlaceList>;
          _profileStats = profileData['stats'] as Map<String, dynamic>;
          _isFollowing = profileData['is_following'] as bool;
          _isSubscribed = profileData['is_subscribed'] as bool? ?? false;
          _subscriptionPrice =
              profileData['subscription_price'] as double? ?? 2.99;
        });
      } else {
        setState(() {
          _error = 'User profile not found';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubscription() async {
    if (_isSubscribed) {
      _showUnsubscribeConfirmation();
    } else {
      _showSubscriptionDialog();
    }
  }

  Future<void> _handleFollow() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated) {
      _showSignInRequired();
      return;
    }

    try {
      final userProfileService =
          Provider.of<UserProfileService>(context, listen: false);

      if (_isFollowing) {
        await userProfileService.unfollowUser(widget.userId);
      } else {
        await userProfileService.followUser(widget.userId);
      }

      setState(() {
        _isFollowing = !_isFollowing;
        // Update follower count in stats
        final currentFollowers = _profileStats['followers_count'] as int? ?? 0;
        _profileStats['followers_count'] =
            _isFollowing ? currentFollowers + 1 : currentFollowers - 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? 'Following user' : 'Unfollowed user'),
            backgroundColor: _isFollowing ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe to Creator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Subscribe to ${_userProfile?['name'] ?? 'this creator'} for exclusive benefits:'),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text('Access to premium lists'),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.notification_important,
                    color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Early access to new places'),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.message, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Direct messaging'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monthly subscription:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '\$${_subscriptionPrice.toStringAsFixed(2)}/month',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingSubscription ? null : _processSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isProcessingSubscription
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  void _showUnsubscribeConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to cancel your subscription to ${_userProfile?['name'] ?? 'this creator'}?'),
            const SizedBox(height: 16),
            const Text(
              'You will lose access to:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• Premium lists'),
            const Text('• Early access to new places'),
            const Text('• Direct messaging'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your subscription will remain active until the end of the current billing period.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: _isProcessingSubscription ? null : _cancelSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _isProcessingSubscription
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSubscription() async {
    setState(() {
      _isProcessingSubscription = true;
    });

    try {
      // Simulate payment processing - in a real app, integrate with Stripe, PayPal, etc.
      await Future.delayed(const Duration(seconds: 2));

      final userProfileService =
          Provider.of<UserProfileService>(context, listen: false);
      await userProfileService.subscribeToUser(
          widget.userId, _subscriptionPrice);

      setState(() {
        _isSubscribed = true;
        _isProcessingSubscription = false;
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Successfully subscribed to ${_userProfile?['name']}!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Benefits',
              textColor: Colors.white,
              onPressed: () {
                // Could show benefits or navigate to subscriber content
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingSubscription = false;
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelSubscription() async {
    setState(() {
      _isProcessingSubscription = true;
    });

    try {
      final userProfileService =
          Provider.of<UserProfileService>(context, listen: false);
      await userProfileService.unsubscribeFromUser(widget.userId);

      setState(() {
        _isSubscribed = false;
        _isProcessingSubscription = false;
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingSubscription = false;
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel subscription: ${e.toString()}'),
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
        content: const Text('Please sign in to follow users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
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

  String _formatJoinDate(String? createdAt) {
    if (createdAt == null) return 'Unknown';

    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return 'Joined ${years} year${years > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return 'Joined ${months} month${months > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return 'Joined ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else {
        return 'Joined recently';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildProfileHeader() {
    final userName = _userProfile?['name'] ?? widget.userName ?? 'Unknown User';
    final bio = _userProfile?['bio'] as String?;
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final joinDate = _userProfile?['created_at'] as String?;

    final currentUserId =
        Provider.of<AuthService>(context, listen: false).user?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          // Profile picture
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 36,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // User name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Join date
          Text(
            _formatJoinDate(joinDate),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),

          // Bio
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(
                'Lists',
                '${_profileStats['public_lists_count'] ?? 0}',
                Icons.list,
              ),
              _buildStatColumn(
                'Places',
                '${_profileStats['total_places_count'] ?? 0}',
                Icons.place,
              ),
              _buildStatColumn(
                'Followers',
                '${_profileStats['followers_count'] ?? 0}',
                Icons.people,
              ),
              _buildStatColumn(
                'Following',
                '${_profileStats['following_count'] ?? 0}',
                Icons.person_add,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Follow and Subscribe buttons (only show if not own profile)
          if (!isOwnProfile) ...[
            Row(
              children: [
                // Follow button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleFollow,
                    icon: Icon(
                        _isFollowing ? Icons.person_remove : Icons.person_add),
                    label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _isFollowing ? Colors.grey[600] : Colors.white,
                      side: BorderSide(
                          color:
                              _isFollowing ? Colors.grey[600]! : Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Subscribe button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleSubscription,
                    icon: Icon(_isSubscribed ? Icons.star : Icons.star_border),
                    label: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isSubscribed ? Colors.amber : Colors.white,
                      foregroundColor: _isSubscribed
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Subscription price display
            if (!_isSubscribed) ...[
              Center(
                child: Text(
                  '\$${_subscriptionPrice.toStringAsFixed(2)}/month',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Premium Subscriber',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildPublicLists() {
    if (_publicLists.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.list_alt,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No public lists yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                'This user hasn\'t shared any public lists',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Public Lists (${_publicLists.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _publicLists.length,
          itemBuilder: (context, index) {
            final list = _publicLists[index];
            return _buildListCard(list);
          },
        ),
      ],
    );
  }

  Widget _buildListCard(PlaceList list) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListDetailScreen(list: list),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // List icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.list,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getListSummary(list),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Action menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'map':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListMapScreen(list: list),
                            ),
                          );
                          break;
                        case 'share':
                          _shareList(list);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'map',
                        child: Row(
                          children: [
                            Icon(Icons.map_outlined),
                            SizedBox(width: 8),
                            Text('View on Map'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),

              // Description
              if (list.description != null && list.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  list.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Rating categories chips
              if (list.ratingCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: list.ratingCategories.take(3).map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (list.ratingCategories.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${list.ratingCategories.length - 3} more categories',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],

              // Average rating if available
              if (_hasRatedPlaces(list)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Average Rating:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StarRatingDisplay(
                      rating: _calculateAverageRating(list),
                      showValue: true,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getListSummary(PlaceList list) {
    final placesCount = list.entries.length;
    final ratedPlacesCount =
        list.entries.where((entry) => entry.ratings.isNotEmpty).length;
    final categoriesCount = list.ratingCategories.length;

    final buffer = StringBuffer();

    if (placesCount == 0) {
      buffer.write('Empty list');
    } else if (placesCount == 1) {
      buffer.write('1 place');
    } else {
      buffer.write('$placesCount places');
    }

    if (categoriesCount > 0) {
      buffer.write(
          ' • $categoriesCount rating categor${categoriesCount == 1 ? 'y' : 'ies'}');
    }

    if (ratedPlacesCount > 0) {
      buffer.write(' • $ratedPlacesCount rated');
    }

    return buffer.toString();
  }

  bool _hasRatedPlaces(PlaceList list) {
    return list.entries.any((entry) => entry.ratings.isNotEmpty);
  }

  double _calculateAverageRating(PlaceList list) {
    final ratedEntries =
        list.entries.where((entry) => entry.ratings.isNotEmpty).toList();

    if (ratedEntries.isEmpty) return 0.0;

    double totalRating = 0.0;
    for (final entry in ratedEntries) {
      final averageRating = entry.getAverageRating();
      if (averageRating != null) {
        totalRating += averageRating;
      }
    }

    return totalRating / ratedEntries.length;
  }

  void _shareList(PlaceList list) {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing "${list.name}" list...'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.red[600],
                                  ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadUserProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        _buildPublicLists(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }
}
