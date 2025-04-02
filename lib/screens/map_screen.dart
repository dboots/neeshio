import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/locations.dart' as Locations;
import '../models/place_list.dart';
import '../services/place_list_service.dart';
import '../services/place_search_service.dart' as search;
import '../widgets/place_list_drawer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final _uuid = const Uuid();

  Locations.Office? _selectedOffice;
  Place? _selectedPlace;
  bool _isLoading = true;
  Locations.Locations? _locations;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // User's current location (default to Portland, OR)
  final LatLng _initialPosition = const LatLng(45.521563, -122.677433);

  // For location search within the map
  final _searchController = TextEditingController();
  bool _showSearchBar = false;

  // For custom pins
  bool _isAddingPin = false;

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

    // Create a set of markers for each office location
    final markers = _locations!.offices.map((office) {
      return Marker(
        markerId: MarkerId(office.id),
        position: LatLng(office.lat, office.lng),
        onTap: () => _onMarkerTapped(office),
      );
    }).toSet();

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _onMarkerTapped(Locations.Office office) {
    setState(() {
      _selectedOffice = office;
      _selectedPlace = Place.fromOffice(office);
    });

    // Explicitly open the drawer using the scaffold key
    _scaffoldKey.currentState!.openEndDrawer();
  }

  void _onCustomMarkerTapped(Place place) {
    setState(() {
      _selectedPlace = place;
    });

    // Explicitly open the drawer using the scaffold key
    _scaffoldKey.currentState!.openEndDrawer();
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
          onTap: () => _onCustomMarkerTapped(result.toPlace()),
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

  void _toggleAddPin() {
    setState(() {
      _isAddingPin = !_isAddingPin;
    });

    final message = _isAddingPin
        ? 'Tap on the map to add a pin'
        : 'Pin adding mode disabled';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onMapTap(LatLng position) async {
    if (!_isAddingPin) return;

    // Create a place from the tapped position
    final newPlace = Place(
      id: _uuid.v4(),
      name: 'Custom Pin',
      address:
          'Location at ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      lat: position.latitude,
      lng: position.longitude,
    );

    // Add a marker for this place
    final marker = Marker(
      markerId: MarkerId(newPlace.id),
      position: position,
      onTap: () => _onCustomMarkerTapped(newPlace),
    );

    setState(() {
      _markers.add(marker);
      _selectedPlace = newPlace;
      _isAddingPin = false; // Turn off pin adding mode
    });

    // Explicitly open the drawer
    _scaffoldKey.currentState!.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      key: _scaffoldKey, // Use scaffold key to control the drawer
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
            tooltip: 'Search places',
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(_isAddingPin
                ? Icons.push_pin
                : Icons.add_location_alt_outlined),
            tooltip: _isAddingPin ? 'Cancel adding pin' : 'Add custom pin',
            onPressed: _toggleAddPin,
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
                  onTap: _onMapTap,
                ),
                if (_showSearchBar)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _searchPlacesOnMap,
                      tooltip: 'Search',
                      child: const Icon(Icons.search),
                    ),
                  ),
                if (_isAddingPin)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: const Text(
                        'Tap on the map to add a pin',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
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
