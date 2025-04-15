import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'dart:async';

import '../models/locations.dart' as locations;
import '../models/place_list.dart';
import '../services/place_search_service.dart' as search;
import '../services/marker_service.dart';
import '../widgets/place_list_drawer.dart';
import '../widgets/location_change_dialog.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final _uuid = const Uuid();

  // Custom info window controller
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  // The marker service will be accessed through Provider

  Place? _selectedPlace;
  bool _isLoading = true;
  locations.Locations? _locations;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Default fallback position (Portland, OR)
  LatLng _currentPosition = const LatLng(45.521563, -122.677433);
  bool _locationDetermined = false;

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
    _getCurrentLocation();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customInfoWindowController.dispose();
    super.dispose();
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, inform user and return
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location services are disabled. Please enable to use your current location.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _locationDetermined = true;
      });
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied, inform user and return
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location permission denied. Using default location.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _locationDetermined = true;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, inform user and return
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission permanently denied. Using default location.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _locationDetermined = true;
      });
      return;
    }

    // Permission granted, get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _locationDetermined = true;
      });

      // If map is already initialized, move to current location
      if (_isLoading == false) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _locationDetermined = true;
      });
    }
  }

  Future<void> _loadData() async {
    // Load Google office locations
    final offices = await locations.getGoogleOffices();

    setState(() {
      _locations = offices;
      _isLoading = false;
    });

    await _updateMarkers();

    // Once data is loaded and map is initialized, zoom to current location
    if (_locationDetermined) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
      );
    }
  }

  Future<void> _updateMarkers() async {
    if (_locations == null) return;

    // Use the marker service to create markers from offices
    final markerService = Provider.of<MarkerService>(context, listen: false);
    final markers = await markerService.createMarkersFromOffices(
      offices: _locations!.offices,
      onTap: _onMarkerTapped,
      controller: _customInfoWindowController,
    );

    // Debug info
    print('Created ${markers.length} markers');
    if (markers.isNotEmpty) {
      final firstMarker = markers.first;
      print('First marker ID: ${firstMarker.markerId}');
      print('First marker position: ${firstMarker.position}');
      print('First marker has tap handler: ${firstMarker.onTap != null}');
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _onMarkerTapped(locations.Office office) {
    setState(() {
      _selectedPlace = Place.fromOffice(office);
    });

    // Close any open info window
    _customInfoWindowController.hideInfoWindow!();

    // Explicitly open the drawer using the scaffold key
    _scaffoldKey.currentState!.openEndDrawer();
  }

  void _onCustomMarkerTapped(Place place) {
    setState(() {
      _selectedPlace = place;
    });

    // Close any open info window
    _customInfoWindowController.hideInfoWindow!();

    // Explicitly open the drawer using the scaffold key
    _scaffoldKey.currentState!.openEndDrawer();
  }

  void _handleDrawerClose() {
    setState(() {
      _selectedPlace = null;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;

    // If location is already determined, move camera to current location
    if (_locationDetermined) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
      );
    }
  }

  // Show dialog to change location
  void _showChangeLocationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LocationChangeDialog(
          onLocationSelected: (LatLng location, String locationName) {
            setState(() {
              _currentPosition = location;
            });

            // Move camera to new location
            _mapController.animateCamera(
              CameraUpdate.newLatLngZoom(location, 14.0),
            );

            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location changed to $locationName')),
            );
          },
        );
      },
    );
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

      // Create markers for search results using the marker service
      final markerService = Provider.of<MarkerService>(context, listen: false);
      final resultMarkers = <Marker>{};
      for (final result in results) {
        final place = result.toPlace();
        final marker = await markerService.createMarkerFromPlace(
          place: place,
          onTap: _onCustomMarkerTapped,
          controller: _customInfoWindowController,
        );
        resultMarkers.add(marker);
      }

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

  Future<void> _onMapTap(LatLng position) async {
    if (!_isAddingPin) return;

    // Ask user for a name for the pin
    String? pinName = await _showPinNameDialog();
    if (pinName == null || pinName.trim().isEmpty) {
      pinName = 'Custom Pin';
    }

    // Create a place from the tapped position
    final newPlace = Place(
      id: _uuid.v4(),
      name: pinName,
      address:
          'Location at ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      lat: position.latitude,
      lng: position.longitude,
    );

    // Create marker using the marker service
    final markerService = Provider.of<MarkerService>(context, listen: false);
    final marker = await markerService.createMarkerFromPlace(
      place: newPlace,
      onTap: _onCustomMarkerTapped,
      controller: _customInfoWindowController,
    );

    setState(() {
      _markers.add(marker);
      _selectedPlace = newPlace;
      _isAddingPin = false; // Turn off pin adding mode
    });

    // Explicitly open the drawer
    _scaffoldKey.currentState!.openEndDrawer();
  }

  Future<String?> _showPinNameDialog() async {
    final nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Name this pin'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter a name for this location',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _searchPlacesOnMap(),
                autofocus: true,
              )
            : const Text('NEESH'),
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
            icon: const Icon(Icons.location_on),
            tooltip: 'Change location',
            onPressed: _showChangeLocationDialog,
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
                    target: _currentPosition,
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: _isAddingPin ? _onMapTap : null,
                  onCameraMove: (position) {
                    _customInfoWindowController.onCameraMove!();
                  },
                ),
                CustomInfoWindow(
                  controller: _customInfoWindowController,
                  height: 120,
                  width: 220,
                  offset: 35,
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
