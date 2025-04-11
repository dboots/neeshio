import 'package:json_annotation/json_annotation.dart';
import 'package:neesh/models/locations.dart';
import 'package:neesh/models/place_rating.dart';

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
    this.ratings = const [],
    this.notes,
  });

  factory PlaceEntry.fromJson(Map<String, dynamic> json) =>
      _$PlaceEntryFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceEntryToJson(this);

  final Place place;
  final List<RatingValue> ratings;
  final String? notes;

  // Get a specific rating by category ID
  int? getRating(String categoryId) {
    final rating = ratings.firstWhere(
      (r) => r.categoryId == categoryId,
      orElse: () => RatingValue(categoryId: categoryId, value: 0),
    );
    return rating.value > 0 ? rating.value : null;
  }

  // Get the average rating across all categories
  double? getAverageRating() {
    if (ratings.isEmpty) return null;

    final sum = ratings.fold<int>(0, (sum, rating) => sum + rating.value);
    return sum / ratings.length;
  }

  // Create a copy with updated ratings
  PlaceEntry copyWithRating(String categoryId, int value) {
    final updatedRatings = List<RatingValue>.from(ratings);
    final index = updatedRatings.indexWhere((r) => r.categoryId == categoryId);

    if (index >= 0) {
      // Update existing rating
      updatedRatings[index] = RatingValue(
        categoryId: categoryId,
        value: value,
      );
    } else {
      // Add new rating
      updatedRatings.add(RatingValue(
        categoryId: categoryId,
        value: value,
      ));
    }

    return PlaceEntry(
      place: place,
      ratings: updatedRatings,
      notes: notes,
    );
  }

  // Create a copy with updated notes
  PlaceEntry copyWithNotes(String? newNotes) {
    return PlaceEntry(
      place: place,
      ratings: ratings,
      notes: newNotes,
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
    this.ratingCategories = const [],
  });

  factory PlaceList.fromJson(Map<String, dynamic> json) =>
      _$PlaceListFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceListToJson(this);

  final String id;
  final String name;
  final String? description;
  final List<PlaceEntry> entries;
  final List<RatingCategory> ratingCategories;

  // For backward compatibility and convenience
  List<Place> get places => entries.map((entry) => entry.place).toList();

  // Create a new list
  factory PlaceList.create(String id, String name,
      [String? description, List<RatingCategory>? ratingCategories]) {
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: [],
      ratingCategories: ratingCategories ?? [],
    );
  }

  // Add a rating category to the list
  PlaceList addRatingCategory(RatingCategory category) {
    // Check if a category with this ID already exists
    if (ratingCategories.any((c) => c.id == category.id)) {
      return this;
    }

    final updatedCategories = List<RatingCategory>.from(ratingCategories)
      ..add(category);

    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: entries,
      ratingCategories: updatedCategories,
    );
  }

  // Remove a rating category from the list
  PlaceList removeRatingCategory(String categoryId) {
    final updatedCategories = ratingCategories
        .where((category) => category.id != categoryId)
        .toList();

    // Also remove this category's ratings from all entries
    final updatedEntries = entries.map((entry) {
      final updatedRatings = entry.ratings
          .where((rating) => rating.categoryId != categoryId)
          .toList();

      return PlaceEntry(
        place: entry.place,
        ratings: updatedRatings,
        notes: entry.notes,
      );
    }).toList();

    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
      ratingCategories: updatedCategories,
    );
  }

  // Add a place to the list with optional ratings
  PlaceList addPlace(Place place, {List<RatingValue>? ratings, String? notes}) {
    // Check if place already exists in the list
    final existingIndex =
        entries.indexWhere((entry) => entry.place.id == place.id);

    if (existingIndex != -1) {
      // If it exists and the ratings are different, update the ratings
      final currentEntry = entries[existingIndex];
      final shouldUpdate =
          (ratings != null && ratings != currentEntry.ratings) ||
              (notes != null && notes != currentEntry.notes);

      if (shouldUpdate) {
        final updatedEntries = List<PlaceEntry>.from(entries);
        updatedEntries[existingIndex] = PlaceEntry(
          place: place,
          ratings: ratings ?? currentEntry.ratings,
          notes: notes ?? currentEntry.notes,
        );

        return PlaceList(
          id: id,
          name: name,
          description: description,
          entries: updatedEntries,
          ratingCategories: ratingCategories,
        );
      }
      // If it exists with the same ratings, no change needed
      return this;
    }

    // If it doesn't exist, add it with the ratings
    final updatedEntries = List<PlaceEntry>.from(entries)
      ..add(PlaceEntry(
        place: place,
        ratings: ratings ?? [],
        notes: notes,
      ));

    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
      ratingCategories: ratingCategories,
    );
  }

  // Remove a place from the list
  PlaceList removePlace(String placeId) {
    final updatedEntries =
        entries.where((entry) => entry.place.id != placeId).toList();
    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
      ratingCategories: ratingCategories,
    );
  }

  // Update the rating for a place in the list
  PlaceList updateRating(String placeId, String categoryId, int value) {
    final entryIndex = entries.indexWhere((entry) => entry.place.id == placeId);

    if (entryIndex == -1) {
      return this; // Place not found, no change
    }

    final updatedEntries = List<PlaceEntry>.from(entries);
    updatedEntries[entryIndex] =
        entries[entryIndex].copyWithRating(categoryId, value);

    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
      ratingCategories: ratingCategories,
    );
  }

  // Update notes for a place in the list
  PlaceList updateNotes(String placeId, String notes) {
    final entryIndex = entries.indexWhere((entry) => entry.place.id == placeId);

    if (entryIndex == -1) {
      return this; // Place not found, no change
    }

    final updatedEntries = List<PlaceEntry>.from(entries);
    updatedEntries[entryIndex] = entries[entryIndex].copyWithNotes(notes);

    return PlaceList(
      id: id,
      name: name,
      description: description,
      entries: updatedEntries,
      ratingCategories: ratingCategories,
    );
  }

  // Find a place entry by ID
  PlaceEntry? findEntryById(String placeId) {
    final index = entries.indexWhere((entry) => entry.place.id == placeId);
    if (index == -1) return null;
    return entries[index];
  }
}
