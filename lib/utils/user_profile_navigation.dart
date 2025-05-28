// lib/utils/user_profile_navigation.dart
import 'package:flutter/material.dart';
import '../screens/public_user_profile_screen.dart';

/// Helper class for navigating to user profiles
class UserProfileNavigation {
  /// Navigate to a user's public profile
  static void navigateToUserProfile(
    BuildContext context, {
    required String userId,
    String? userName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicUserProfileScreen(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  /// Create a tappable widget that navigates to a user profile when tapped
  static Widget createUserProfileTap({
    required Widget child,
    required BuildContext context,
    required String userId,
    String? userName,
  }) {
    return InkWell(
      onTap: () => navigateToUserProfile(
        context,
        userId: userId,
        userName: userName,
      ),
      child: child,
    );
  }

  /// Create a user avatar with tap-to-profile functionality
  static Widget createUserAvatar({
    required BuildContext context,
    required String userId,
    required String userName,
    String? avatarUrl,
    double radius = 20,
    VoidCallback? onTap,
  }) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: radius * 0.8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );

    return InkWell(
      onTap: onTap ?? () => navigateToUserProfile(
        context,
        userId: userId,
        userName: userName,
      ),
      borderRadius: BorderRadius.circular(radius),
      child: avatar,
    );
  }

  /// Create a user name chip with tap-to-profile functionality
  static Widget createUserNameChip({
    required BuildContext context,
    required String userId,
    required String userName,
    String? avatarUrl,
    bool showAvatar = true,
    TextStyle? textStyle,
  }) {
    return InkWell(
      onTap: () => navigateToUserProfile(
        context,
        userId: userId,
        userName: userName,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAvatar) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              userName,
              style: textStyle ?? TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}