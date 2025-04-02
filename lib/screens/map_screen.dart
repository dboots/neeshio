import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/locations.dart' as Locations;
import '../models/place_list.dart';
import '../services/marker_service.dart';
import '../services/place_search_service.dart' as search;
import '../widgets/place_list_drawer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final MarkerService _markerService = MarkerService();
  
  Locations.Office? _selectedOffice;
  Place? _selectedPlace;
  bool _isLoading = true;
  Locations.Locations? _locations;

  // User's current location (default to Portland, OR)
  final LatLng _initialPosition = const LatLng(45.521563, -122.677433);
  
  // For location search within the map
  final _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load Google office locations
    final locations = await Locations.getGoogleOffices();
    
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
    
    _updateMarkers();
  }

  void _updateMarkers() {
    if (_locations == null) return;
    
    final markers = _markerService.createMarkersFromOffices(
      offices: _locations!.offices,
      onTap: _handleOfficeTap,
    );
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _handleOfficeTap(Locations.Office office) {
    setState(() {
      _selectedOffice = office;
      _selectedPlace = Place.fromOffice(office);
    });
    
    // Open the drawer
    Scaffold.of(context).openEndDrawer();
  }

  void _handleDrawerClose() {
    setState(() {
      _selectedOffice = null;
      _selectedPlace = null;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _searchPlacesOnMap() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Get current map bounds
    final bounds = await _mapController.getVisibleRegion();
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    // Calculate approximate radius in meters
    final latDiff = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final lngDiff = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
    final approximateRadius = (latDiff + lngDiff) * 55000; // rough conversion to meters

    // Convert to search service LatLng
    final searchLocation = search.LatLng(
      lat: center.latitude,
      lng: center.longitude,
    );

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Searching places...')),
      );
    }

    try {
      // Perform the search
      final searchService = search.PlaceSearchService();
      final results = await searchService.searchPlaces(
        query,
        location: searchLocation,
      );

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No places found')),
          );
        }
        return;
      }

      // Add markers for search results
      final resultMarkers = results.map((result) {
        return Marker(
          markerId: MarkerId(result.id),
          position: LatLng(result.lat, result.lng),
          infoWindow: InfoWindow(
            title: result.name,
            snippet: result.address,
          ),
          onTap: () {
            setState(() {
              _selectedPlace = result.toPlace();
            });
            Scaffold.of(context).openEndDrawer();
          },
        );
      }).toSet();

      setState(() {
        _markers.clear();
        _markers.addAll(resultMarkers);
      });

      // Move camera to first result
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(results.first.lat, results.first.lng),
          14.0,
        ),
      );

      // Clear search bar
      setState(() {
        _showSearchBar = false;
      });
      _searchController.clear();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search places on map...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _searchPlacesOnMap(),
                autofocus: true,
              )
            : const Text('Maps List App'),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 11.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                if (_showSearchBar)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _searchPlacesOnMap,
                      child: const Icon(Icons.search),
                    ),
                  ),
              ],
            ),
      endDrawer: _selectedPlace != null
          ? PlaceListDrawer(
              place: _selectedPlace!,
              onClose: _handleDrawerClose,
            )
          : null,
    );
  }
}