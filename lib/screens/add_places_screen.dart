import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neesh/services/location_service.dart';
import 'package:provider/provider.dart';

import '../models/place_list.dart';
import '../services/place_search_service.dart' as search;
import '../widgets/place_list_drawer.dart';

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
  bool _isChangingLocation = false;
  Place? _selectedPlace;

  // Default location (Portland, OR)
  LatLng _currentLocation = const LatLng(45.521563, -122.677433);
  String _currentLocationName = 'Portland, OR';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _getCurrentLocation();
    await _loadNearbyPlaces();
  }

  Future<void> _getCurrentLocation() async {
    final locationService =
        Provider.of<LocationService>(context, listen: false);
    setState(() {
      _currentLocation = locationService.currentLocation!;
      _currentLocationName = locationService.currentLocationName!;
    });
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
      final searchService = search.PlaceSearchService();
      final results = await searchService.searchNearbyPlaces(
        search.LatLng(
          lat: _currentLocation.latitude,
          lng: _currentLocation.longitude,
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
    setState(() {
      _isChangingLocation = true;
    });

    try {
      // Search for the new location
      final searchService = search.PlaceSearchService();
      final results = await showDialog<search.PlaceSearchResult?>(
        context: context,
        builder: (context) =>
            _LocationSearchDialog(searchService: searchService),
      );

      if (results != null) {
        setState(() {
          _currentLocation = LatLng(results.lat, results.lng);
          _currentLocationName = results.name;
          _isChangingLocation = false;
        });

        // Reload nearby places for the new location
        await _loadNearbyPlaces();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Location changed to $_currentLocationName')),
          );
        }
      } else {
        setState(() {
          _isChangingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _isChangingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change location: $e')),
        );
      }
    }
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
      final searchService = search.PlaceSearchService();
      final results = await searchService.searchPlaces(
        query,
        location: search.LatLng(
          lat: _currentLocation.latitude,
          lng: _currentLocation.longitude,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                child: InkWell(
                  onTap: _isChangingLocation ? null : _changeLocation,
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
                                _currentLocationName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_isChangingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No nearby places found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for specific places',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNearbyPlaces,
              child: const Text('Retry'),
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

// Location search dialog widget
class _LocationSearchDialog extends StatefulWidget {
  final search.PlaceSearchService searchService;

  const _LocationSearchDialog({required this.searchService});

  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final TextEditingController _locationController = TextEditingController();
  List<search.PlaceSearchResult> _locationResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocations() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Search for locations (cities, states, etc.)
      final results = await widget.searchService.searchPlaces('$query city');

      // Filter results to prefer cities and administrative areas
      final filteredResults = results.where((result) {
        final types = result.types ?? [];
        return types.contains('locality') ||
            types.contains('administrative_area_level_1') ||
            types.contains('administrative_area_level_2') ||
            types.contains('sublocality') ||
            result.name.toLowerCase().contains('city') ||
            result.address
                .contains(','); // Likely to be a city if it has a comma
      }).toList();

      setState(() {
        _locationResults = filteredResults.isEmpty ? results : filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location search failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Location'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Search for a city or location',
                hintText: 'e.g., New York, Tokyo, San Francisco',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchLocations(),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _searchLocations,
                child: const Text('Search'),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_locationResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _locationResults.length,
                  itemBuilder: (context, index) {
                    final result = _locationResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_city),
                      title: Text(result.name),
                      subtitle: Text(
                        result.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(context).pop(result);
                      },
                    );
                  },
                ),
              )
            else if (_locationController.text.isNotEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No locations found.\nTry searching for a city name.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
