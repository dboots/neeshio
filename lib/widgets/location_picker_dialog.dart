// lib/widgets/discover/location_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerDialog extends StatelessWidget {
  final LatLng currentLocation;
  final Function(LatLng, String) onLocationSelected;

  const LocationPickerDialog({
    super.key,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  void _selectPresetLocation(
      BuildContext context, LatLng location, String name) {
    onLocationSelected(location, name);
    Navigator.pop(context);
  }

  void _showMapPicker(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          initialLocation: currentLocation,
          onLocationSelected: onLocationSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                const Text(
                  'Choose Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Preset locations
            _LocationOption(
              icon: Icons.my_location,
              title: 'Use current location',
              onTap: () {
                // TODO: Implement GPS location
                Navigator.pop(context);
              },
            ),
            _LocationOption(
              icon: Icons.location_city,
              title: 'Hudson, Ohio',
              onTap: () => _selectPresetLocation(
                context,
                const LatLng(41.2407, -81.4412),
                'Hudson, Ohio',
              ),
            ),
            _LocationOption(
              icon: Icons.location_city,
              title: 'Cleveland, Ohio',
              onTap: () => _selectPresetLocation(
                context,
                const LatLng(41.5085, -81.6954),
                'Cleveland, Ohio',
              ),
            ),
            _LocationOption(
              icon: Icons.location_city,
              title: 'Akron, Ohio',
              onTap: () => _selectPresetLocation(
                context,
                const LatLng(41.0814, -81.5191),
                'Akron, Ohio',
              ),
            ),
            _LocationOption(
              icon: Icons.map,
              title: 'Choose on map...',
              onTap: () => _showMapPicker(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LocationOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class MapLocationPicker extends StatefulWidget {
  final LatLng initialLocation;
  final Function(LatLng, String) onLocationSelected;

  const MapLocationPicker({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Location'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onLocationSelected(_selectedLocation, 'Selected Location');
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('DONE'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: 12,
        ),
        onTap: (LatLng location) {
          setState(() {
            _selectedLocation = location;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId('selected'),
            position: _selectedLocation,
          ),
        },
      ),
    );
  }
}
