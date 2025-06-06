// lib/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/discover_service.dart';
import '../services/location_service.dart';
import '../widgets/location_selector_widget.dart';
import '../widgets/category_filter_widget.dart';
import '../widgets/discover_content_widget.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late DiscoverService _discoverService;

  // Filter state
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Food',
    'Attractions',
    'Shopping',
    'Outdoors'
  ];

  // Data state
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
    // Wait for location service to initialize
    final locationService =
        Provider.of<LocationService>(context, listen: false);

    // If location service isn't initialized yet, wait for it
    if (locationService.currentLocation == null && locationService.isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await _loadNearbyLists();
    setState(() {
      _isFirstLoad = false;
    });
  }

  Future<void> _loadNearbyLists() async {
    if (_discoverService.isLoading) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final currentLocation = locationService.currentLocation;

      if (currentLocation == null) {
        // Use default location if none available
        await _discoverService
            .getNearbyListsByCategory(
          latitude: 41.2407, // Default to Hudson, Ohio
          longitude: -81.4412,
          radiusKm: 50.0,
        )
            .then((categorized) {
          setState(() => _categorizedLists = categorized);
        });
      } else {
        await _discoverService
            .getNearbyListsByCategory(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          radiusKm: 50.0,
        )
            .then((categorized) {
          setState(() => _categorizedLists = categorized);
        });
      }
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
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('Sort by popularity'),
            onTap: () {
              Navigator.pop(context);
              _discoverService.sortNearbyLists(SortOption.popularity);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location picker coming soon!'),
        duration: Duration(seconds: 2),
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
      body: Stack(
        children: [
          Column(
            children: [
              // Category filter
              CategoryFilter(
                categories: _categories,
                selectedCategory: _selectedCategory,
                onCategorySelected: _onCategorySelected,
              ),

              // Main content
              Expanded(
                child: Padding(
                  // Add bottom padding to account for location selector
                  padding: const EdgeInsets.only(bottom: 80),
                  child: DiscoverContent(
                    isFirstLoad: _isFirstLoad,
                    discoverService: _discoverService,
                    categorizedLists: _categorizedLists,
                    selectedCategory: _selectedCategory,
                    onRefresh: _loadNearbyLists,
                  ),
                ),
              ),
            ],
          ),

          // Location selector at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<LocationService>(
              builder: (context, locationService, child) {
                return LocationSelector(
                  currentLocationName: locationService.currentLocationName ??
                      'Getting location...',
                  isLoadingLocation: locationService.isLoading,
                  onLocationTap: _showLocationPicker,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
