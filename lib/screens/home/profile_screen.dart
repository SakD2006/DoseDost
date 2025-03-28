import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'home_screen.dart'; // Make sure HomeScreen is implemented

class ProfileScreen extends StatelessWidget {
  final String patientId;
  final String patientName;
  final int age;
  final String breakfast;
  final String lunch;
  final String dinner;

  const ProfileScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
    required this.age,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Decoration for information containers.
    final BoxDecoration infoBoxDecoration = BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // QR Code Section
            QrImageView(data: patientId, version: QrVersions.auto, size: 300),
            const SizedBox(height: 20),
            // Name Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: infoBoxDecoration,
              child: Text(
                'Name: $patientName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Age Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: infoBoxDecoration,
              child: Text(
                'Age: $age',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Meal Timing Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: infoBoxDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meal Timing:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Breakfast: $breakfast'),
                  Text('Lunch: $lunch'),
                  Text('Dinner: $dinner'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Profile is selected
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 0) {
            // Navigate to HomeScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(patientId: patientId),
              ),
            );
          }
          // When Profile (index 1) is tapped, no action is needed since we're already here.
        },
      ),
    );
  }
}
