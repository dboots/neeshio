// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Place _$PlaceFromJson(Map<String, dynamic> json) => Place(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      image: json['image'] as String?,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$PlaceToJson(Place instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'lat': instance.lat,
      'lng': instance.lng,
      'image': instance.image,
      'phone': instance.phone,
    };

PlaceEntry _$PlaceEntryFromJson(Map<String, dynamic> json) => PlaceEntry(
      place: Place.fromJson(json['place'] as Map<String, dynamic>),
      rating: json['rating'] as int?,
    );

Map<String, dynamic> _$PlaceEntryToJson(PlaceEntry instance) =>
    <String, dynamic>{
      'place': instance.place,
      'rating': instance.rating,
    };

PlaceList _$PlaceListFromJson(Map<String, dynamic> json) => PlaceList(
      id: json['id'] as String,
      name: json['name'] as String,
      entries: (json['entries'] as List<dynamic>)
          .map((e) => PlaceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PlaceListToJson(PlaceList instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'entries': instance.entries,
    };
