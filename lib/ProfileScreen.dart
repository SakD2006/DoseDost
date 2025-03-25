import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // <-- Import qr_flutter

class ProfileScreen extends StatelessWidget {
  final String patientId;

  const ProfileScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('patients').doc(patientId).snapshots(),
        builder: (context, patientSnapshot) {
          if (!patientSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // If doc doesn't exist, handle gracefully
          if (!patientSnapshot.data!.exists) {
            return const Center(child: Text('Patient not found.'));
          }

          final patientData =
              patientSnapshot.data!.data() as Map<String, dynamic>;
          final patientName = patientData['Name'];
          final patientAge = patientData['Age'];
          final mealTiming = patientData['Meal-timing'] ?? {};
          final patientBreakfast = mealTiming['Breakfast'] ?? 'N/A';
          final patientLunch = mealTiming['Lunch'] ?? 'N/A';
          final patientDinner = mealTiming['Dinner'] ?? 'N/A';

          return Column(
            children: [
              // TOP SECTION: White background with the QR code
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  // Replace black box with QrImage
                  child: QrImageView(data: patientId, size: 300.0),
                ),
              ),

              // BOTTOM SECTION: Gray area with patient info
              Container(
                color: Colors.grey[300],
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name: $patientName',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Age: $patientAge',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Meal Timing:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Breakfast: $patientBreakfast'),
                    Text('Lunch: $patientLunch'),
                    Text('Dinner: $patientDinner'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
