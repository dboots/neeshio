import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neesh/services/location_service.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/place_search_service.dart' as search;
import '../widgets/place_list_drawer.dart';
import '../widgets/location_change_dialog.dart';

class AddPlacesScreen extends StatefulWidget {
  const AddPlacesScreen({super.key});

  @override
  State<AddPlacesScreen> createState() => _AddPlacesScreenState();
}

class _AddPlacesScreenState extends State<AddPlacesScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<search.PlaceSearchResult> _searchResults = [];
  List<search.PlaceSearchResult> _nearbyPlaces = [];
  bool _isSearching = false;
  bool _isLoadingNearby = true;
  Place? _selectedPlace;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Wait for location service to be ready
    final locationService =
        Provider.of<LocationService>(context, listen: false);

    // If location service isn't initialized yet, wait a bit
    if (locationService.currentLocation == null && !locationService.isLoading) {
      await locationService.initialize();
    }

    await _loadNearbyPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoadingNearby = true;
    });

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final currentLocation = locationService.currentLocation;

      if (currentLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Location not available. Please set your location.')),
          );
        }
        setState(() {
          _isLoadingNearby = false;
        });
        return;
      }

      final searchService = search.PlaceSearchService();
      final results = await searchService.searchNearbyPlaces(
        search.LatLng(
          lat: currentLocation.latitude,
          lng: currentLocation.longitude,
        ),
        radius: 2000, // 2km radius
      );

      setState(() {
        _nearbyPlaces = results;
        _isLoadingNearby = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingNearby = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load nearby places: $e')),
        );
      }
    }
  }

  Future<void> _changeLocation() async {
    showDialog(
      context: context,
      builder: (context) => LocationChangeDialog(
        onLocationSelected: (location, locationName) async {
          final locationService =
              Provider.of<LocationService>(context, listen: false);

          // Update the location service with the new location
          await locationService.updateLocationWithGeocoding(location);

          // Reload nearby places for the new location
          await _loadNearbyPlaces();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location changed to $locationName')),
            );
          }
        },
      ),
    );
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final currentLocation = locationService.currentLocation;

      if (currentLocation == null) {
        throw Exception('Location not available');
      }

      final searchService = search.PlaceSearchService();
      final results = await searchService.searchPlaces(
        query,
        location: search.LatLng(
          lat: currentLocation.latitude,
          lng: currentLocation.longitude,
        ),
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _onPlaceTapped(search.PlaceSearchResult result) {
    final place = result.toPlace();
    setState(() {
      _selectedPlace = place;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _handleDrawerClose() {
    setState(() {
      _selectedPlace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Add Places'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for places...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _searchPlaces(),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlaces(),
                ),
              ),
              // Location selector
              Consumer<LocationService>(
                builder: (context, locationService, child) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                    child: InkWell(
                      onTap: locationService.isLoading ? null : _changeLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    locationService.isLoading
                                        ? 'Getting location...'
                                        : locationService.currentLocationName ??
                                            'Unknown location',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Show error if there is one
                                  if (locationService.error != null)
                                    Text(
                                      'Error: ${locationService.error}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (locationService.isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (locationService.error != null)
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.grey.shade600,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNearbyPlaces,
        child: _buildBody(),
      ),
      endDrawer: _selectedPlace != null
          ? PlaceListDrawer(
              place: _selectedPlace!,
              onClose: _handleDrawerClose,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show search results if there's a search query
    if (_searchController.text.isNotEmpty) {
      return _buildSearchResults();
    }

    // Otherwise show nearby places
    return _buildNearbyPlaces();
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No places found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Search Results (${_searchResults.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return _buildPlaceCard(result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyPlaces() {
    if (_isLoadingNearby) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbyPlaces.isEmpty) {
      return Consumer<LocationService>(
        builder: (context, locationService, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    locationService.error != null
                        ? Icons.location_off
                        : Icons.place,
                    size: 64,
                    color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  locationService.error != null
                      ? 'Location Error'
                      : 'No nearby places found',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  locationService.error != null
                      ? 'Please check your location settings'
                      : 'Try searching for specific places or changing your location',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await locationService.refreshCurrentLocation();
                        await _loadNearbyPlaces();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _changeLocation,
                      icon: const Icon(Icons.edit_location),
                      label: const Text('Change Location'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.near_me,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Nearby Places (${_nearbyPlaces.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadNearbyPlaces,
                tooltip: 'Refresh nearby places',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _nearbyPlaces.length,
            itemBuilder: (context, index) {
              final result = _nearbyPlaces[index];
              return _buildPlaceCard(result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(search.PlaceSearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildPlaceIcon(result),
        title: Text(
          result.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (result.rating != null) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    result.rating!.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (result.userRatingsTotal != null) ...[
                    const Text(' • '),
                    Text(
                      '${result.userRatingsTotal} reviews',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
                if (result.priceLevel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    result.priceLevel!,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            if (result.openNow != null) ...[
              const SizedBox(height: 4),
              Text(
                result.openNow! ? 'Open now' : 'Closed',
                style: TextStyle(
                  color: result.openNow! ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => _onPlaceTapped(result),
      ),
    );
  }

  Widget _buildPlaceIcon(search.PlaceSearchResult result) {
    IconData iconData;
    Color iconColor;

    switch (result.getPrimaryType()) {
      case 'restaurant':
      case 'food':
      case 'cafe':
      case 'bakery':
        iconData = Icons.restaurant;
        iconColor = Colors.orange;
        break;
      case 'store':
      case 'shopping_mall':
        iconData = Icons.shopping_bag;
        iconColor = Colors.blue;
        break;
      case 'lodging':
      case 'hotel':
        iconData = Icons.hotel;
        iconColor = Colors.purple;
        break;
      case 'tourist_attraction':
      case 'museum':
        iconData = Icons.museum;
        iconColor = Colors.brown;
        break;
      case 'park':
        iconData = Icons.park;
        iconColor = Colors.green;
        break;
      case 'bar':
        iconData = Icons.local_bar;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.place;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor),
    );
  }
}
