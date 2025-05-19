import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/place_list_service.dart';
import 'saved_lists_screen.dart';
import 'discover_screen.dart';
import 'add_places_screen.dart'; // Import the new Add Places screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Load saved lists when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlaceListService>(context, listen: false).loadLists();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping
        children: const [
          DiscoverScreen(),
          AddPlacesScreen(), // Add the new screen
          SavedListsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search), // Magnifying glass icon for Discover
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location), // Icon for Add Places
            label: 'Add Places',
          ),
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Lists',
          ),
        ],
      ),
    );
  }
}
