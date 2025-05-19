import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:custom_info_window/custom_info_window.dart';

import '../models/locations.dart' as locations;
import '../models/place_list.dart';
import '../services/place_list_service.dart';
import '../widgets/place_list_drawer.dart';
import '../widgets/location_change_dialog.dart';

// New imports for refactored code
import '../widgets/map_banners.dart';
import '../widgets/map_buttons.dart';
import '../widgets/map_dialogs.dart';
import '../services/place_utils.dart';
import '../services/map_search_service.dart';

class MapScreen extends StatefulWidget {
  final String? selectedListId;

  const MapScreen({
    super.key,
    this.selectedListId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {
  // Controllers
  late GoogleMapController _mapController;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  final Set<Marker> _markers = {};
  Place? _selectedPlace;
  bool _isLoading = true;
  locations.Locations? _locations;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng _currentPosition =
      const LatLng(45.521563, -122.677433); // Default to Portland
  bool _locationDetermined = false;
  bool _showSearchBar = false;
  bool _isAddingPin = false;

  // List-related state
  String? _selectedListId;
  PlaceList? _selectedList;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.selectedListId;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadData();

    if (_selectedListId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSelectedList();
      });
    }
  }

  void _loadSelectedList() {
    if (_selectedListId != null) {
      final listService = Provider.of<PlaceListService>(context, listen: false);
      try {
        _selectedList =
            listService.lists.firstWhere((list) => list.id == _selectedListId);
      } catch (e) {
        print('Selected list not found: $_selectedListId');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customInfoWindowController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final offices = await locations.getGoogleOffices();

    setState(() {
      _locations = offices;
      _isLoading = false;
    });

    await _updateMarkers();

    // Once data is loaded and map is initialized, zoom to current location
    if (_locationDetermined && mounted) {
      // Use null check to avoid null reference
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
      );
    }
  }

  Future<void> _updateMarkers() async {
    if (_locations == null) return;

    // Create basic markers from offices
    final markers = <Marker>{};
    
    for (final office in _locations!.offices) {
      final marker = Marker(
        markerId: MarkerId(office.id),
        position: LatLng(office.lat, office.lng),
        infoWindow: InfoWindow(
          title: office.name,
          snippet: office.address,
        ),
        onTap: () => _onMarkerTapped(office),
      );
      markers.add(marker);
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;

    if (_locationDetermined) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14.0),
      );
    }
  }

  void _showChangeLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => LocationChangeDialog(
        onLocationSelected: (location, locationName) {
          setState(() {
            _currentPosition = location;
          });

          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(location, 14.0),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location changed to $locationName')),
          );
        },
      ),
    );
  }

  //
  // Place and Marker Handling
  //

  void _onMarkerTapped(locations.Office office) {
    _handlePlaceSelection(Place.fromOffice(office));
  }

  void _onCustomMarkerTapped(Place place) {
    _handlePlaceSelection(place);
  }

  void _handlePlaceSelection(Place place) {
    setState(() {
      _selectedPlace = place;
    });

    _customInfoWindowController.hideInfoWindow!();

    if (_selectedList != null) {
      // If we have a selected list, add the place directly
      PlaceUtils.addPlaceToList(context, _selectedList!, place);
    } else {
      // Otherwise open the drawer to choose a list
      _scaffoldKey.currentState!.openEndDrawer();
    }
  }

  void _handleDrawerClose() {
    setState(() {
      _selectedPlace = null;
    });
  }

  void _addSelectedPlaceToList() {
    if (_selectedPlace != null && _selectedList != null) {
      PlaceUtils.addPlaceToList(context, _selectedList!, _selectedPlace!);
    }
  }

  //
  // Search Functionality
  //

  Future<void> _searchPlacesOnMap() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Searching places...')),
    );

    try {
      // Search for places
      final results =
          await MapSearchService.searchPlacesInArea(_mapController, query);

      // Show results message
      MapSearchService.showSearchResultMessage(context, results);

      if (results.isNotEmpty) {
        // Create markers from results
        final resultMarkers = MapSearchService.createSearchResultMarkers(
            results, _onCustomMarkerTapped);

        // Make sure widget is still mounted before updating state
        if (mounted) {
          setState(() {
            _markers.clear();
            _markers.addAll(resultMarkers);
            _showSearchBar = false;
          });

          // Null check to prevent errors
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(results.first.lat, results.first.lng),
              14.0,
            ),
          );
        }

        _searchController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  //
  // Custom Pin Functionality
  //

  void _toggleAddPin() {
    if (!mounted) return;

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
    String? pinName = await showPinNameDialog(context);
    if (pinName == null || pinName.trim().isEmpty) {
      pinName = 'Custom Pin';
    }

    // Create a place from the tapped position
    final newPlace = PlaceUtils.createPlaceFromPosition(position, pinName);

    // Create marker for the new place
    final marker = Marker(
      markerId: MarkerId(newPlace.id),
      position: LatLng(newPlace.lat, newPlace.lng),
      infoWindow: InfoWindow(
        title: newPlace.name,
        snippet: newPlace.address,
      ),
      onTap: () => _onCustomMarkerTapped(newPlace),
    );

    if (!mounted) return;

    setState(() {
      _markers.add(marker);
      _selectedPlace = newPlace;
      _isAddingPin = false; // Turn off pin adding mode
    });

    // Handle the new place
    if (_selectedList != null) {
      PlaceUtils.addPlaceToList(context, _selectedList!, newPlace);
    } else {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  //
  // UI Building
  //

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: _buildBody(),
      endDrawer: _buildEndDrawer(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          : _selectedList != null
              ? Text('Add to: ${_selectedList!.name}')
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
          icon: Icon(
              _isAddingPin ? Icons.push_pin : Icons.add_location_alt_outlined),
          tooltip: _isAddingPin ? 'Cancel adding pin' : 'Add custom pin',
          onPressed: _toggleAddPin,
        ),
        if (_selectedList != null)
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Done adding places',
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
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
        if (_showSearchBar) SearchButton(onPressed: _searchPlacesOnMap),
        if (_isAddingPin) const AddPinBanner(),
        if (_selectedList != null) AddToListBanner(list: _selectedList!),
        if (_selectedPlace != null && _selectedList != null)
          AddToListButton(
            onPressed: _addSelectedPlaceToList,
            listName: _selectedList!.name,
          ),
      ],
    );
  }

  Widget? _buildEndDrawer() {
    if (_selectedPlace != null && _selectedList == null) {
      return PlaceListDrawer(
        place: _selectedPlace!,
        onClose: _handleDrawerClose,
      );
    }
    return null;
  }
}