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
class PlaceList {
  PlaceList({
    required this.id,
    required this.name,
    required this.places,
    this.description,
  });

  factory PlaceList.fromJson(Map<String, dynamic> json) =>
      _$PlaceListFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceListToJson(this);

  final String id;
  final String name;
  final String? description;
  final List<Place> places;

  // Create a new list
  factory PlaceList.create(String id, String name, [String? description]) {
    return PlaceList(
      id: id,
      name: name,
      description: description,
      places: [],
    );
  }

  // Add a place to the list
  PlaceList addPlace(Place place) {
    // Check if place already exists in the list
    if (places.any((p) => p.id == place.id)) {
      return this;
    }

    final updatedPlaces = List<Place>.from(places)..add(place);
    return PlaceList(
      id: id,
      name: name,
      description: description,
      places: updatedPlaces,
    );
  }

  // Remove a place from the list
  PlaceList removePlace(String placeId) {
    final updatedPlaces = places.where((p) => p.id != placeId).toList();
    return PlaceList(
      id: id,
      name: name,
      description: description,
      places: updatedPlaces,
    );
  }
}
