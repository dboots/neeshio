import 'package:json_annotation/json_annotation.dart';

part 'place_rating.g.dart';

@JsonSerializable()
class RatingCategory {
  RatingCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory RatingCategory.fromJson(Map<String, dynamic> json) =>
      _$RatingCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$RatingCategoryToJson(this);

  final String id;
  final String name;
  final String? description;
}

@JsonSerializable()
class RatingValue {
  RatingValue({
    required this.categoryId,
    required this.value,
  });

  factory RatingValue.fromJson(Map<String, dynamic> json) =>
      _$RatingValueFromJson(json);
  Map<String, dynamic> toJson() => _$RatingValueToJson(this);

  final String categoryId;
  final int value;
}
