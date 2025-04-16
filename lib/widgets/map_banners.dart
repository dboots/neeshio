import 'package:flutter/material.dart';
import '../models/place_list.dart';

/// A banner that appears at the top of the map when in pin adding mode
class AddPinBanner extends StatelessWidget {
  const AddPinBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Text(
          'Tap on the map to add a pin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A banner that appears at the top when adding places to a list
class AddToListBanner extends StatelessWidget {
  final PlaceList list;

  const AddToListBanner({
    super.key,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          'Tap on places to add them to "${list.name}"',
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
