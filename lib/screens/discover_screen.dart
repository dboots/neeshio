import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/discover_service.dart';
import '../utils/location_utils.dart';
import '../screens/discover_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late DiscoverService _discoverService;

  // Default location (Hudson, OH)
  LatLng _currentLocation = const LatLng(41.2407, -81.4412);
  String _currentLocationName = 'Hudson, Ohio';
  bool _isLoadingLocation = true;

  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Food',
    'Attractions',
    'Shopping',
    'Outdoors'
  ];

  Map<String, List<NearbyList>> _categorizedLists = {};
  bool _isFirstLoad = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _discoverService = DiscoverService();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _getCurrentLocation();
    await _loadNearbyLists();
    setState(() => _isFirstLoad = false);
  }

  // Get the user's current location with proper permission handling
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check location permission
      final status = await Permission.location.request();

      if (status.isGranted) {
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Get location name from coordinates (reverse geocoding)
        // This would typically use a geocoding service, but simplified for this example
        _updateLocationName();
      } else {
        // Use default location if permission denied
        setState(() => _isLoadingLocation = false);

        // Show permission explanation only on first load
        if (_isFirstLoad && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location permission denied. Using default location.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Handle errors (timeout, service not available, etc.)
      setState(() => _isLoadingLocation = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Simplified location name update - in a real app, use reverse geocoding
  void _updateLocationName() {
    // Within 10km of Hudson
    if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.2407, -81.4412) <
        10) {
      _currentLocationName = 'Hudson, Ohio';
    }
    // Near Cleveland
    else if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.5085, -81.6954) <
        15) {
      _currentLocationName = 'Cleveland, Ohio';
    }
    // Near Akron
    else if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.0814, -81.5191) <
        15) {
      _currentLocationName = 'Akron, Ohio';
    }
    // Fallback
    else {
      _currentLocationName = 'Current Location';
    }
  }

  Future<void> _loadNearbyLists() async {
    if (_discoverService.isLoading) return;

    try {
      await _discoverService
          .getNearbyListsByCategory(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        radiusKm: 50.0, // 50km radius for more results
      )
          .then((categorized) {
        setState(() => _categorizedLists = categorized);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lists: ${e.toString()}')),
        );
      }
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
  }

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Use current location'),
            leading: const Icon(Icons.my_location),
            onTap: () {
              Navigator.pop(context);
              _getCurrentLocation().then((_) => _loadNearbyLists());
            },
          ),
          ListTile(
            title: const Text('Hudson, Ohio'),
            leading: const Icon(Icons.location_on),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentLocation = const LatLng(41.2407, -81.4412);
                _currentLocationName = 'Hudson, Ohio';
              });
              _loadNearbyLists();
            },
          ),
          ListTile(
            title: const Text('Cleveland, Ohio'),
            leading: const Icon(Icons.location_on),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentLocation = const LatLng(41.5085, -81.6954);
                _currentLocationName = 'Cleveland, Ohio';
              });
              _loadNearbyLists();
            },
          ),
          ListTile(
            title: const Text('Akron, Ohio'),
            leading: const Icon(Icons.location_on),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentLocation = const LatLng(41.0814, -81.5191);
                _currentLocationName = 'Akron, Ohio';
              });
              _loadNearbyLists();
            },
          ),
          ListTile(
            title: const Text('Choose on map...'),
            leading: const Icon(Icons.map),
            onTap: () {
              Navigator.pop(context);
              _showMapLocationPicker();
            },
          ),
        ],
      ),
    );
  }

  void _showMapLocationPicker() {
    // This would open a map where the user can pick a location
    // Simplified version for this example
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Choose Location')),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 12,
            ),
            onTap: (LatLng location) {
              setState(() {
                _currentLocation = location;
                _currentLocationName = 'Selected Location';
              });
              Navigator.pop(context);
              _loadNearbyLists();
            },
          ),
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sort Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Sort by distance'),
            onTap: () {
              Navigator.pop(context);
              _discoverService.sortNearbyLists(SortOption.distance);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Sort by rating'),
            onTap: () {
              Navigator.pop(context);
              _discoverService.sortNearbyLists(SortOption.rating);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered),
            title: const Text('Sort by number of places'),
            onTap: () {
              Navigator.pop(context);
              _discoverService.sortNearbyLists(SortOption.placeCount);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter options',
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNearbyLists,
          ),
        ],
      ),
      body: _buildBody(),
      // Location selector in bottom app bar
      bottomSheet: _buildLocationSelector(),
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: _showLocationOptions,
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _isLoadingLocation
                          ? 'Getting location...'
                          : _currentLocationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_discoverService.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${_discoverService.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNearbyLists,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final nearbyLists = _discoverService.filterByCategory(_selectedCategory);

    if (_categorizedLists.isEmpty ||
        (_selectedCategory != 'All' && nearbyLists.isEmpty)) {
      return EmptyStateWidget(onRefresh: _loadNearbyLists);
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyLists,
      child: _buildContent(nearbyLists),
    );
  }

  Widget _buildContent(List<NearbyList> filteredLists) {
    if (_selectedCategory == 'All') {
      // Show categorized layout with sections
      return ListView(
        children: [
          // Featured lists section (if available)
          if (_categorizedLists.containsKey('Featured') &&
              _categorizedLists['Featured']!.isNotEmpty)
            _buildFeaturedSection(_categorizedLists['Featured']!),

          // Category filter chips
          CategoryFilterWidget(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategorySelected,
          ),

          // Each category section
          for (final entry in _categorizedLists.entries)
            if (entry.key != 'Featured' && entry.value.isNotEmpty)
              _buildCategorySection(entry.key, entry.value),

          // Add some bottom padding for the location selector
          const SizedBox(height: 70),
        ],
      );
    } else {
      // Show grid layout for filtered results
      return Column(
        children: [
          // Category filter
          CategoryFilterWidget(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategorySelected,
          ),

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
              itemCount: filteredLists.length,
              itemBuilder: (context, index) {
                return NearbyListCard(nearbyList: filteredLists[index]);
              },
            ),
          ),

          // Bottom spacer for location selector
          const SizedBox(height: 70),
        ],
      );
    }
  }

  Widget _buildFeaturedSection(List<NearbyList> featuredLists) {
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

  Widget _buildCategorySection(String category, List<NearbyList> lists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _getCategoryIcon(category),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = category;
                  });
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
            itemCount: lists.length,
            itemBuilder: (context, index) {
              return CategoryListCard(nearbyList: lists[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData iconData;
    Color iconColor;

    switch (category.toLowerCase()) {
      case 'food & dining':
        iconData = Icons.restaurant;
        iconColor = Colors.orange;
        break;
      case 'shopping':
        iconData = Icons.shopping_bag;
        iconColor = Colors.blue;
        break;
      case 'attractions':
        iconData = Icons.museum;
        iconColor = Colors.purple;
        break;
      case 'outdoors':
        iconData = Icons.park;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.place;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor, size: 20);
  }
}

// Card widget for featured lists
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
              // Image or placeholder (getting first image from places)
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
                        'Featured',
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
    // This is a simplified version - in a real app, you would get the image from the first place
    return Container(
      color: Colors.blueGrey[300],
      child: const Center(
        child: Icon(
          Icons.photo,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

// Card widget for category lists
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
    // This is a simplified version - in a real app, you would get the image from the first place
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

// Regular grid card for nearby lists
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

                    // Rating and distance
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

// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyStateWidget({Key? key, required this.onRefresh}) : super(key: key);

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

// Category filter widget
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
