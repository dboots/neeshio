import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final Function(int)? onRatingChanged;
  final MainAxisAlignment alignment;
  final EdgeInsets padding;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 24,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.onRatingChanged,
    this.alignment = MainAxisAlignment.start,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: List.generate(maxRating, (index) {
          return InkWell(
            onTap: onRatingChanged != null
                ? () => onRatingChanged!(index + 1)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: index < rating ? activeColor : inactiveColor,
                size: size,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final int maxRating;
  final double size;
  final Color color;
  final bool showValue;
  final MainAxisAlignment alignment;
  final TextStyle? textStyle;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 16,
    this.color = Colors.amber,
    this.showValue = true,
    this.alignment = MainAxisAlignment.start,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Icon(
          Icons.star,
          color: color,
          size: size,
        ),
        const SizedBox(width: 4),
        if (showValue)
          Text(
            rating.toStringAsFixed(1),
            style: textStyle ??
                TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size - 2,
                  color: color,
                ),
          ),
      ],
    );
  }
}
