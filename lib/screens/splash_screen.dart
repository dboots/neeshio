import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.place,
              size: 100,
              color: Color.fromARGB(255, 48, 4, 137),
            ),
            const SizedBox(height: 24),
            const Text(
              'NEESH',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 48, 4, 137),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Places, Your Way',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
