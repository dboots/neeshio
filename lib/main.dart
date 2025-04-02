import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';

const kGoogleApiKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  final places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
  final LatLng _center = const LatLng(45.521563, -122.677433);
  final TextEditingController _searchController = TextEditingController();
  List<Prediction> _predictions = [];
  Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onSearchChanged() async {
    if (_searchController.text.isNotEmpty) {
      final response = await places.autocomplete(
        _searchController.text,
        components: [Component(Component.country, 'us')],
      );

      if (response.isOkay) {
        setState(() {
          _predictions = response.predictions;
        });
      }
    } else {
      setState(() {
        _predictions = [];
      });
    }
  }

  Future<void> _selectPlace(Prediction prediction) async {
    final details = await places.getDetailsByPlaceId(
      prediction.placeId!,
    );

    if (details.isOkay) {
      final geometry = details.result.geometry!;
      final lat = geometry.location.lat;
      final lng = geometry.location.lng;
      final latLng = LatLng(lat, lng);

      // Create a marker for the selected place
      final marker = Marker(
        markerId: MarkerId(prediction.placeId!),
        position: latLng,
        infoWindow: InfoWindow(
          title: details.result.name,
          snippet: details.result.formattedAddress,
        ),
      );

      // Update state with the new marker and cleared predictions
      setState(() {
        _searchController.text = prediction.description!;
        _predictions = [];
        _markers = {marker}; // Replace any existing markers
      });

      // Animate the camera to the selected location
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: latLng,
            zoom: 16.0, // Closer zoom for better visibility of the location
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Neesh.io'),
          elevation: 2,
        ),
        body: Stack(
          children: [
            // Map takes the full screen
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 11.0,
              ),
              markers: _markers,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),

            // Search box at the top
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search places...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _predictions = [];
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // Predictions list
            if (_predictions.isNotEmpty)
              Positioned(
                top: 65, // Position below the search box
                left: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxHeight: 300, // Limit the height of the prediction list
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final prediction = _predictions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                            prediction.structuredFormatting?.mainText ?? ''),
                        subtitle: Text(
                            prediction.structuredFormatting?.secondaryText ??
                                ''),
                        onTap: () => _selectPlace(prediction),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
