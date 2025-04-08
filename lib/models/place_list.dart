import 'package:json_annotation/json_annotation.dart';
import 'package:neesh/models/locations.dart';

part 'place_list.g.dart';

@JsonSerializable()
class Place {
  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.image,
    this.phone,
  });

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceToJson(this);

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? image;
  final String? phone;

  // Create a Place from an Office
  factory Place.fromOffice(Office office) {
    return Place(
      id: office.id,
      name: office.name,
      address: office.address,
      lat: office.lat,
      lng: office.lng,
      image: office.image,
      phone: office.phone,
    );
  }
}

@JsonSerializable()
class PlaceEntry {
  PlaceEntry({
    required this.place,
    this.rating,
  });

  factory PlaceEntry.fromJson(Map<String, dynamic> json) => _$PlaceEntryFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceEntryToJson(this);

  final Place place;
  final int? rating;

  // Create a copy with a new rating
  PlaceEntry copyWithRating(int? rating) {
    return PlaceEntry(
      place: place,
      rating: rating,
    );
  }
}

@JsonSerializable()
class PlaceList {
  PlaceList({
    required this.id,
    required this.name,
    required this.entries,
    this.description,
  });

  factory PlaceList.fromJson(Map<String, dynamic> json) =>
      _$PlaceListFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceListToJson(this);

  final String id;
  final String name;
  final String? description;
  final List<PlaceEntry> entries;

  // For backward compatibility and convenience
  List<Place> get places => entries.map((entry) => entry.place).toList();

  // Create a new list
  factory PlaceList.create(String id, String name, [String? description]) {
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: [],
    );
  }

  // Add a place to the list with optional rating
  PlaceList addPlace(Place place, {int? rating}) {
    // Check if place already exists in the list
    final existingIndex = entries.indexWhere((entry) => entry.place.id == place.id);
    
    if (existingIndex != -1) {
      // If it exists and the rating is different, update the rating
      if (entries[existingIndex].rating != rating) {
        final updatedEntries = List<PlaceEntry>.from(entries);
        updatedEntries[existingIndex] = PlaceEntry(place: place, rating: rating);
        
        return PlaceList(
          id: id,
          name: name,
          description: description,
          entries: updatedEntries,
        );
      }
      // If it exists with the same rating, no change needed
      return this;
    }
    
    // If it doesn't exist, add it with the rating
    final updatedEntries = List<PlaceEntry>.from(entries)
      ..add(PlaceEntry(place: place, rating: rating));
    
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
    );
  }

  // Remove a place from the list
  PlaceList removePlace(String placeId) {
    final updatedEntries = entries.where((entry) => entry.place.id != placeId).toList();
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
    );
  }

  // Update the rating for a place in the list
  PlaceList updateRating(String placeId, int? rating) {
    final entryIndex = entries.indexWhere((entry) => entry.place.id == placeId);
    
    if (entryIndex == -1) {
      return this; // Place not found, no change
    }
    
    final updatedEntries = List<PlaceEntry>.from(entries);
    updatedEntries[entryIndex] = entries[entryIndex].copyWithRating(rating);
    
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
    );
  }

  // Find a place entry by ID
  PlaceEntry? findEntryById(String placeId) {
    final index = entries.indexWhere((entry) => entry.place.id == placeId);
    if (index == -1) return null;
    return entries[index];
  }
}