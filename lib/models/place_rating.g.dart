// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_rating.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RatingCategory _$RatingCategoryFromJson(Map<String, dynamic> json) =>
    RatingCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$RatingCategoryToJson(RatingCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
    };

RatingValue _$RatingValueFromJson(Map<String, dynamic> json) => RatingValue(
      categoryId: json['categoryId'] as String,
      value: json['value'] as int,
    );

Map<String, dynamic> _$RatingValueToJson(RatingValue instance) =>
    <String, dynamic>{
      'categoryId': instance.categoryId,
      'value': instance.value,
    };
