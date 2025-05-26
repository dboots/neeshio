import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_wrapper.dart';
import 'screens/notification_settings_screen.dart';
import 'services/auth_service.dart';
import 'services/place_list_service.dart';
import 'services/discover_service.dart';
import 'services/marker_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get environment variables
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Validate environment variables
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw Exception(
      'Missing required environment variables. '
      'Please set SUPABASE_URL and SUPABASE_KEY.',
    );
  }

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      debug: false, // Set to true for debugging in development
    );

    print('Supabase initialized successfully');
  } catch (e) {
    print('Failed to initialize Supabase: $e');
    throw Exception('Failed to initialize Supabase: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final LocationService locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Location service - should be early as other services may depend on it
        ChangeNotifierProvider(
          create: (_) => locationService..initialize(),
        ),

        // Auth service - should be early as other services depend on it
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),

        // Place list service - depends on auth state
        ChangeNotifierProxyProvider<AuthService, PlaceListService>(
          create: (_) => PlaceListService(),
          update: (context, authService, placeListService) {
            // Clear data when user signs out
            if (!authService.isAuthenticated && placeListService != null) {
              placeListService.clearData();
            }

            return placeListService ?? PlaceListService();
          },
        ),

        // Other services
        Provider(create: (_) => DiscoverService()),
        Provider(create: (_) => MarkerService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          return MaterialApp(
            title: 'NEESH',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color.fromARGB(255, 48, 4, 137),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 48, 4, 137),
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              // Enhanced card theme for better list appearance
              cardTheme: CardTheme(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Enhanced floating action button theme
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                elevation: 4,
              ),
              // Enhanced snackbar theme
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            home: const AuthWrapper(),
            // Add error handling for navigation
            builder: (context, widget) {
              // Add global error boundary
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Error'),
                    backgroundColor: Colors.red,
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please restart the app and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            // In a real app, you might want to restart or navigate to a safe screen
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Restart App'),
                        ),
                      ],
                    ),
                  ),
                );
              };

              return widget ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

/// Extension to add helpful methods to BuildContext
extension ContextExtensions on BuildContext {
  /// Get the current auth service
  AuthService get auth => read<AuthService>();

  /// Get the current place list service
  PlaceListService get placeLists => read<PlaceListService>();

  /// Get the current discover service
  DiscoverService get discover => read<DiscoverService>();

  /// Get the current marker service
  MarkerService get markers => read<MarkerService>();

  /// Get the current location service
  LocationService get location => read<LocationService>();

  /// Check if user is authenticated
  bool get isAuthenticated => auth.isAuthenticated;

  /// Show a snackbar with consistent styling
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a loading dialog
  void showLoadingDialog(String message) {
    showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Show notification settings
  Future<void> showNotificationSettings() async {
    Navigator.push(
      this,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }
}
