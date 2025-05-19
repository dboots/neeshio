import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/discover_service.dart';
import '../widgets/discover_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late DiscoverService _discoverService;
  bool _isLoading = true;
  List<NearbyList> _nearbyLists = [];
  LatLng? _currentLocation;
  String _filterCategory = 'All';
  final List<String> _categories = ['All', 'Food', 'Shopping', 'Activities', 'Sights'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _discoverService = DiscoverService();
    _loadNearbyLists();
  }

  Future<void> _loadNearbyLists() async {
    setState(() {
      _isLoading = true;
    });
    
    if (_currentLocation != null) {
      // Fetch nearby lists using the discover service
      final nearbyLists = await _discoverService.fetchNearbyLists(_currentLocation!);
      
      setState(() {
        _nearbyLists = nearbyLists;
        _isLoading = false;
      });
    } else {
      // Use default location if couldn't get user's location
      final defaultLocation = const LatLng(45.521563, -122.677433); // Portland
      final nearbyLists = await _discoverService.fetchNearbyLists(defaultLocation);
      
      setState(() {
        _nearbyLists = nearbyLists;
        _isLoading = false;
      });
      
      // Show a message about using default location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using default location. Enable location services for personalized results.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Filter Options',
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
              setState(() {
                _nearbyLists.sort((a, b) => a.distance.compareTo(b.distance));
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Sort by rating'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _nearbyLists.sort((a, b) => b.userRating.compareTo(a.userRating));
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered),
            title: const Text('Sort by number of places'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _nearbyLists.sort((a, b) => b.list.entries.length.compareTo(a.list.entries.length));
              });
            },
          ),
        ],
      ),
    );
  }

  void _onCategorySelected(String category) {
    setState(() {
      _filterCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Nearby'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNearbyLists,
              child: _buildContent(),
            ),
    );
  }
  
  Widget _buildContent() {
    final displayLists = _filterCategory == 'All'
        ? _nearbyLists
        : _discoverService.filterByCategory(_filterCategory);
    
    if (_nearbyLists.isEmpty) {
      return EmptyStateWidget(onRefresh: _loadNearbyLists);
    }
    
    return CustomScrollView(
      slivers: [
        // Featured lists section
        SliverToBoxAdapter(
          child: FeaturedListsWidget(nearbyLists: _nearbyLists),
        ),
        
        // Category filter
        SliverToBoxAdapter(
          child: CategoryFilterWidget(
            categories: _categories,
            selectedCategory: _filterCategory,
            onCategorySelected: _onCategorySelected,
          ),
        ),
        
        // List grid or empty category message
        if (displayLists.isEmpty)
          SliverFillRemaining(
            child: NoCategoryResultsWidget(
              onShowAllCategories: () => _onCategorySelected('All'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => NearbyListCard(nearbyList: displayLists[index]),
                childCount: displayLists.length,
              ),
            ),
          ),
      ],
    );
  }
}
