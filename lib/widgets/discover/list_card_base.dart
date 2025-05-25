// lib/widgets/discover/list_card_base.dart
import 'package:flutter/material.dart';
import '../../services/discover_service.dart';
import '../../screens/discover_detail_screen.dart';

/// Base card component for all list cards to ensure consistent behavior
class ListCardBase extends StatelessWidget {
  final NearbyList nearbyList;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets margin;
  final double borderRadius;
  final double elevation;

  const ListCardBase({
    Key? key,
    required this.nearbyList,
    required this.child,
    this.width,
    this.height,
    this.margin = const EdgeInsets.all(8),
    this.borderRadius = 12,
    this.elevation = 2,
  }) : super(key: key);

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscoverDetailScreen(nearbyList: nearbyList),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );

    if (width != null || height != null) {
      cardContent = SizedBox(
        width: width,
        height: height,
        child: cardContent,
      );
    }

    return Container(
      margin: margin,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () => _navigateToDetail(context),
        child: cardContent,
      ),
    );
  }
}