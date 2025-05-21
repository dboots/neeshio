import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/place_list_service.dart';
import 'services/discover_service.dart';
import 'services/marker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  // Initialize Supabase
  print(supabaseUrl);
  await Supabase.initialize(
    url: supabaseUrl, // Replace with your Supabase URL
    anonKey: supabaseKey, // Replace with your Supabase anon key
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PlaceListService()),
        Provider(create: (_) => DiscoverService()),
        Provider(create: (_) => MarkerService()),
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
      title: 'NEESH',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color.fromARGB(255, 48, 4, 137),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 48, 4, 137),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
