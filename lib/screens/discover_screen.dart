// lib/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/discover_service.dart';
import '../utils/location_utils.dart';
import '../widgets/location_selector_widget.dart';
import '../widgets/category_filter_widget.dart';
import '../widgets/discover_content_widget.dart';
import '../widgets/location_picker_dialog.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late DiscoverService _discoverService;

  // Location state
  LatLng _currentLocation = const LatLng(41.2407, -81.4412);
  String _currentLocationName = 'Hudson, Ohio';
  bool _isLoadingLocation = true;

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
    await _getCurrentLocation();
    await _loadNearbyLists();
    setState(() => _isFirstLoad = false);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final status = await Permission.location.request();

      if (status.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        _updateLocationName();
      } else {
        setState(() => _isLoadingLocation = false);

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

  void _updateLocationName() {
    if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.2407, -81.4412) <
        10) {
      _currentLocationName = 'Hudson, Ohio';
    } else if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.5085, -81.6954) <
        15) {
      _currentLocationName = 'Cleveland, Ohio';
    } else if (LocationUtils.calculateDistance(_currentLocation.latitude,
            _currentLocation.longitude, 41.0814, -81.5191) <
        15) {
      _currentLocationName = 'Akron, Ohio';
    } else {
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
        radiusKm: 50.0,
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

  void _onLocationChanged(LatLng location, String locationName) {
    setState(() {
      _currentLocation = location;
      _currentLocationName = locationName;
    });
    _loadNearbyLists();
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

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(
        currentLocation: _currentLocation,
        onLocationSelected: _onLocationChanged,
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
      body: Column(
        children: [
          // Category filter
          CategoryFilter(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategorySelected,
          ),

          // Main content
          Expanded(
            child: DiscoverContent(
              isFirstLoad: _isFirstLoad,
              discoverService: _discoverService,
              categorizedLists: _categorizedLists,
              selectedCategory: _selectedCategory,
              onRefresh: _loadNearbyLists,
            ),
          ),
        ],
      ),
      bottomSheet: LocationSelector(
        currentLocationName: _currentLocationName,
        isLoadingLocation: _isLoadingLocation,
        onLocationTap: _showLocationPicker,
      ),
    );
  }
}
