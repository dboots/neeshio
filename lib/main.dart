import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/place_list_service.dart';
import 'services/marker_service.dart';
import 'services/discover_service.dart'; // Add DiscoverService import

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaceListService()),
        // Provide MarkerService as a singleton
        Provider(create: (_) => MarkerService()),
        // Add DiscoverService provider
        Provider(create: (_) => DiscoverService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Places List App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color.fromARGB(255, 48, 4, 137),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 48, 4, 137),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
