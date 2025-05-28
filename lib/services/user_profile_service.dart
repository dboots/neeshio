// lib/services/user_profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place_list.dart';
import '../models/place_rating.dart';

class UserProfileService extends ChangeNotifier {
  final SupabaseClient _supabase;

  // Cache for user profiles to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _profileCache = {};

  UserProfileService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get a public user profile with their public lists and stats
  Future<Map<String, dynamic>?> getPublicUserProfile(String userId) async {
    try {
      // Check cache first (cache for 5 minutes)
      if (_profileCache.containsKey(userId)) {
        final cachedData = _profileCache[userId]!;
        final cacheTime = cachedData['_cache_time'] as DateTime;
        if (DateTime.now().difference(cacheTime).inMinutes < 5) {
          if (kDebugMode) {
            print('Returning cached profile for user: $userId');
          }
          return cachedData;
        }
      }

      if (kDebugMode) {
        print('Fetching fresh profile data for user: $userId');
      }

      // Fetch user profile from profiles table
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, name, bio, avatar_url, created_at')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        if (kDebugMode) {
          print('Profile not found for user: $userId');
        }
        return null;
      }

      // Fetch public lists for this user
      final publicLists = await _getPublicListsForUser(userId);

      // Calculate profile statistics
      final stats = await _getProfileStats(userId);

      // Check if current user is following this user
      final isFollowing = await _isFollowingUser(userId);

      // Check if current user is subscribed to this user
      final isSubscribed = await _isSubscribedToUser(userId);

      // Get subscription price for this user
      final subscriptionPrice = await _getUserSubscriptionPrice(userId);

      final result = {
        'profile': profileResponse,
        'public_lists': publicLists,
        'stats': stats,
        'is_following': isFollowing,
        'is_subscribed': isSubscribed,
        'subscription_price': subscriptionPrice,
        '_cache_time': DateTime.now(),
      };

      // Cache the result
      _profileCache[userId] = result;

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching public user profile: $e');
      }
      rethrow;
    }
  }

  /// Get all public lists for a specific user
  Future<List<PlaceList>> _getPublicListsForUser(String userId) async {
    try {
      // Get basic list info
      final listsResponse = await _supabase
          .from('place_lists')
          .select('id, name, description, created_at')
          .eq('user_id', userId)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(50); // Limit to most recent 50 lists

      final publicLists = <PlaceList>[];

      // Load detailed data for each list
      for (final listData in listsResponse) {
        try {
          final placeList = await _loadListWithDetails(listData['id']);
          if (placeList != null) {
            publicLists.add(placeList);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading list ${listData['id']}: $e');
          }
          // Continue loading other lists even if one fails
        }
      }

      return publicLists;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching public lists for user $userId: $e');
      }
      return [];
    }
  }

  /// Load a complete list with all its details (similar to PlaceListService)
  Future<PlaceList?> _loadListWithDetails(String listId) async {
    try {
      // Get list basic info
      final listResponse = await _supabase
          .from('place_lists')
          .select('id, name, description, user_id, created_at')
          .eq('id', listId)
          .single();

      // Get rating categories for this list
      final categoriesResponse = await _supabase
          .from('rating_categories')
          .select('id, name, description')
          .eq('list_id', listId)
          .order('name');

      final ratingCategories = categoriesResponse
          .map((category) => RatingCategory(
                id: category['id'],
                name: category['name'],
                description: category['description'],
              ))
          .toList();

      // Get entries (places) in this list with their ratings
      final entriesResponse = await _supabase.from('list_entries').select('''
            id, notes, created_at,
            places!inner(id, name, address, lat, lng, image_url, phone)
          ''').eq('list_id', listId).order('created_at');

      final entries = <PlaceEntry>[];

      for (final entryData in entriesResponse) {
        try {
          final entryId = entryData['id'];
          final placeData = entryData['places'];

          // Get ratings for this entry
          final ratingsResponse = await _supabase
              .from('rating_values')
              .select('category_id, value')
              .eq('entry_id', entryId);

          final ratings = ratingsResponse
              .map((rating) => RatingValue(
                    categoryId: rating['category_id'],
                    value: rating['value'],
                  ))
              .toList();

          // Create Place from place data
          final place = Place(
            id: placeData['id'],
            name: placeData['name'],
            address: placeData['address'],
            lat: placeData['lat']?.toDouble() ?? 0.0,
            lng: placeData['lng']?.toDouble() ?? 0.0,
            image: placeData['image_url'],
            phone: placeData['phone'],
          );

          // Create entry
          final entry = PlaceEntry(
            place: place,
            ratings: ratings,
            notes: entryData['notes'],
          );

          entries.add(entry);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading entry: $e');
          }
          // Continue with other entries
        }
      }

      // Create and return the complete list
      return PlaceList(
        id: listId,
        name: listResponse['name'],
        description: listResponse['description'],
        entries: entries,
        ratingCategories: ratingCategories,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading list details for $listId: $e');
      }
      return null;
    }
  }

  /// Calculate profile statistics for a user
  Future<Map<String, dynamic>> _getProfileStats(String userId) async {
    try {
      // Get count of public lists
      final publicListsCount = await _supabase
          .from('place_lists')
          .select('id')
          .eq('user_id', userId)
          .eq('is_public', true);

      // Get total places count across all public lists
      final totalPlacesResponse =
          await _supabase.rpc('get_user_total_places_count', params: {
        'user_id': userId,
      });

      // Get followers count
      final followersCount = await _supabase
          .from('user_follows')
          .select('id')
          .eq('following_id', userId);

      // Get following count
      final followingCount = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', userId);

      return {
        'public_lists_count': publicListsCount.length,
        'total_places_count': totalPlacesResponse,
        'followers_count': followersCount.length,
        'following_count': followingCount.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating profile stats for user $userId: $e');
      }
      return {
        'public_lists_count': 0,
        'total_places_count': 0,
        'followers_count': 0,
        'following_count': 0,
      };
    }
  }

  /// Check if the current user is following the specified user
  Future<bool> _isFollowingUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId == userId) {
        return false; // Can't follow yourself or not authenticated
      }

      final followResponse = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle();

      return followResponse != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking follow status: $e');
      }
      return false;
    }
  }

  /// Check if the current user is subscribed to the specified user
  Future<bool> _isSubscribedToUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId == userId) {
        return false; // Can't subscribe to yourself or not authenticated
      }

      final subscriptionResponse = await _supabase
          .from('user_subscriptions')
          .select('id, status')
          .eq('subscriber_id', currentUserId)
          .eq('creator_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      return subscriptionResponse != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
      return false;
    }
  }

  /// Get the subscription price for a user
  Future<double> _getUserSubscriptionPrice(String userId) async {
    try {
      final priceResponse = await _supabase
          .from('profiles')
          .select('subscription_price')
          .eq('id', userId)
          .maybeSingle();

      return (priceResponse?['subscription_price'] as num?)?.toDouble() ?? 2.99;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscription price: $e');
      }
      return 2.99; // Default price
    }
  }

  /// Follow a user
  Future<void> followUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == userId) {
        throw Exception('Cannot follow yourself');
      }

      // Check if already following
      final existingFollow = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle();

      if (existingFollow != null) {
        throw Exception('Already following this user');
      }

      // Insert follow relationship
      await _supabase.from('user_follows').insert({
        'follower_id': currentUserId,
        'following_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Clear cache for this user to force refresh
      _profileCache.remove(userId);

      if (kDebugMode) {
        print('Successfully followed user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error following user $userId: $e');
      }
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Delete follow relationship
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);

      // Clear cache for this user to force refresh
      _profileCache.remove(userId);

      if (kDebugMode) {
        print('Successfully unfollowed user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unfollowing user $userId: $e');
      }
      rethrow;
    }
  }

  /// Get users that the current user is following
  Future<void> subscribeToUser(String userId, double price) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == userId) {
        throw Exception('Cannot subscribe to yourself');
      }

      // Check if already subscribed
      final existingSubscription = await _supabase
          .from('user_subscriptions')
          .select('id, status')
          .eq('subscriber_id', currentUserId)
          .eq('creator_id', userId)
          .maybeSingle();

      if (existingSubscription != null) {
        if (existingSubscription['status'] == 'active') {
          throw Exception('Already subscribed to this user');
        } else {
          // Reactivate existing subscription
          await _supabase.from('user_subscriptions').update({
            'status': 'active',
            'price': price,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existingSubscription['id']);
        }
      } else {
        // Create new subscription
        await _supabase.from('user_subscriptions').insert({
          'subscriber_id': currentUserId,
          'creator_id': userId,
          'price': price,
          'status': 'active',
          'billing_cycle': 'monthly',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Clear cache for this user to force refresh
      _profileCache.remove(userId);

      if (kDebugMode) {
        print('Successfully subscribed to user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to user $userId: $e');
      }
      rethrow;
    }
  }

  /// Unsubscribe from a user
  Future<void> unsubscribeFromUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Update subscription status to cancelled instead of deleting
      await _supabase
          .from('user_subscriptions')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('subscriber_id', currentUserId)
          .eq('creator_id', userId);

      // Clear cache for this user to force refresh
      _profileCache.remove(userId);

      if (kDebugMode) {
        print('Successfully unsubscribed from user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from user $userId: $e');
      }
      rethrow;
    }
  }

  /// Get list of users the current user is subscribed to
  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('user_subscriptions')
          .select('''
            creator_id, price, created_at,
            profiles!user_subscriptions_creator_id_fkey(id, name, avatar_url)
          ''')
          .eq('subscriber_id', currentUserId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return response.map((subscription) {
        final profile = subscription['profiles'];
        return {
          'id': profile['id'],
          'name': profile['name'],
          'avatar_url': profile['avatar_url'],
          'price': subscription['price'],
          'subscribed_at': subscription['created_at'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscriptions: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowing() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('user_follows')
          .select('''
            following_id,
            profiles!user_follows_following_id_fkey(id, name, avatar_url)
          ''')
          .eq('follower_id', currentUserId)
          .order('created_at', ascending: false);

      return response.map((follow) {
        final profile = follow['profiles'];
        return {
          'id': profile['id'],
          'name': profile['name'],
          'avatar_url': profile['avatar_url'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting following list: $e');
      }
      return [];
    }
  }

  /// Get users that are following the current user
  Future<List<Map<String, dynamic>>> getFollowers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('user_follows')
          .select('''
            follower_id,
            profiles!user_follows_follower_id_fkey(id, name, avatar_url)
          ''')
          .eq('following_id', currentUserId)
          .order('created_at', ascending: false);

      return response.map((follow) {
        final profile = follow['profiles'];
        return {
          'id': profile['id'],
          'name': profile['name'],
          'avatar_url': profile['avatar_url'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting followers list: $e');
      }
      return [];
    }
  }

  /// Search for users by name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final response = await _supabase
          .from('profiles')
          .select('id, name, avatar_url')
          .ilike('name', '%${query.trim()}%')
          .limit(20);

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching users: $e');
      }
      return [];
    }
  }

  /// Update the current user's public profile
  Future<void> updatePublicProfile({
    required String name,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('profiles').upsert({
        'id': currentUserId,
        'name': name.trim(),
        'bio': bio?.trim(),
        'avatar_url': avatarUrl?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Clear cache for current user
      _profileCache.remove(currentUserId);

      if (kDebugMode) {
        print('Successfully updated public profile');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating public profile: $e');
      }
      rethrow;
    }
  }

  /// Get recommended users to follow (users with popular public lists)
  Future<List<Map<String, dynamic>>> getRecommendedUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // Get users with public lists, excluding users already followed and current user
      String query = '''
        SELECT DISTINCT 
          p.id, 
          p.name, 
          p.avatar_url,
          COUNT(pl.id) as list_count
        FROM profiles p
        INNER JOIN place_lists pl ON p.id = pl.user_id
        WHERE pl.is_public = true
      ''';

      if (currentUserId != null) {
        query += '''
          AND p.id != '$currentUserId'
          AND p.id NOT IN (
            SELECT following_id 
            FROM user_follows 
            WHERE follower_id = '$currentUserId'
          )
        ''';
      }

      query += '''
        GROUP BY p.id, p.name, p.avatar_url
        ORDER BY list_count DESC
        LIMIT 10
      ''';

      final response = await _supabase.rpc('get_recommended_users', params: {
        'current_user_id': currentUserId,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recommended users: $e');
      }
      return [];
    }
  }

  /// Clear profile cache (useful for testing or when data becomes stale)
  void clearProfileCache() {
    _profileCache.clear();
    if (kDebugMode) {
      print('Profile cache cleared');
    }
  }

  /// Get cached profile if available
  Map<String, dynamic>? getCachedProfile(String userId) {
    return _profileCache[userId];
  }
}
