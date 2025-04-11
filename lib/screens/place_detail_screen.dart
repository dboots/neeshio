import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_list.dart';
import '../models/place_rating.dart';
import '../services/place_list_service.dart';
import '../widgets/star_rating_widget.dart';

class PlaceDetailScreen extends StatefulWidget {
  final PlaceList list;
  final Place place;

  const PlaceDetailScreen({
    Key? key,
    required this.list,
    required this.place,
  }) : super(key: key);

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late PlaceList _currentList;
  late PlaceEntry? _entry;
  final TextEditingController _notesController = TextEditingController();
  final Map<String, int> _ratings = {};

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _entry = _currentList.findEntryById(widget.place.id);

    // Initialize ratings map and notes from the entry
    if (_entry != null) {
      for (final rating in _entry!.ratings) {
        _ratings[rating.categoryId] = rating.value;
      }

      if (_entry!.notes != null) {
        _notesController.text = _entry!.notes!;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateRating(String categoryId, int value) async {
    final listService = Provider.of<PlaceListService>(context, listen: false);

    // Update the rating
    await listService.updatePlaceRating(
        _currentList.id, widget.place.id, categoryId, value);

    // Update local state
    setState(() {
      _ratings[categoryId] = value;

      // Refresh the list and entry references
      _currentList =
          listService.lists.firstWhere((list) => list.id == _currentList.id);
      _entry = _currentList.findEntryById(widget.place.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating updated')),
    );
  }

  Future<void> _updateNotes() async {
    if (_notesController.text.isEmpty) return;

    final listService = Provider.of<PlaceListService>(context, listen: false);

    await listService.updatePlaceNotes(
      _currentList.id,
      widget.place.id,
      _notesController.text,
    );

    // Refresh the list and entry references
    setState(() {
      _currentList =
          listService.lists.firstWhere((list) => list.id == _currentList.id);
      _entry = _currentList.findEntryById(widget.place.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Place image or map preview
            SizedBox(
              height: 200,
              child:
                  widget.place.image != null && widget.place.image!.isNotEmpty
                      ? Image.network(
                          widget.place.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildMapPreview(),
                        )
                      : _buildMapPreview(),
            ),

            // Place details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.place.address,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (widget.place.phone != null &&
                      widget.place.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.place.phone!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Notes section
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Add your notes about this place...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _updateNotes,
                      child: const Text('Save Notes'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Ratings section
                  Text(
                    'Ratings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  if (_currentList.ratingCategories.isEmpty)
                    const Text(
                      'No rating categories defined for this list.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentList.ratingCategories.length,
                      itemBuilder: (context, index) {
                        final category = _currentList.ratingCategories[index];
                        final rating = _ratings[category.id] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (category.description != null) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: category.description!,
                                        child: const Icon(Icons.info_outline,
                                            size: 16),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (rating > 0)
                                      Text(
                                        '$rating/5',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                StarRatingWidget(
                                  rating: rating,
                                  size: 36,
                                  alignment: MainAxisAlignment.center,
                                  onRatingChanged: (value) =>
                                      _updateRating(category.id, value),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Show average rating if there are ratings
                  if (_entry != null && _entry!.ratings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Text(
                              'Overall Average:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber[800],
                                  size: 28,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _entry!
                                          .getAverageRating()
                                          ?.toStringAsFixed(1) ??
                                      'N/A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Colors.amber[800],
                                  ),
                                ),
                                const Text(
                                  ' / 5',
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.place.lat, widget.place.lng),
        zoom: 15,
      ),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      markers: {
        Marker(
          markerId: MarkerId(widget.place.id),
          position: LatLng(widget.place.lat, widget.place.lng),
          infoWindow: InfoWindow(title: widget.place.name),
        ),
      },
    );
  }
}
