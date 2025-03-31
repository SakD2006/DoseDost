import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart'; // Ensure this file is implemented

class HomeScreen extends StatefulWidget {
  final String patientId;

  const HomeScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Local state to hold patient details
  String _patientName = '';
  int _patientAge = 0;
  String _patientBreakfast = '';
  String _patientLunch = '';
  String _patientDinner = '';

  // Function to update state from patient document
  void _updatePatientData(Map<String, dynamic> data) {
    setState(() {
      _patientName = data['Name'] ?? 'Unknown';
      _patientAge = data['Age'] ?? 0;
      final mealTiming = data['Meal-timing'] ?? {};
      _patientBreakfast = mealTiming['Breakfast'] ?? 'N/A';
      _patientLunch = mealTiming['Lunch'] ?? 'N/A';
      _patientDinner = mealTiming['Dinner'] ?? 'N/A';
    });
  }

  // Bottom navigation tap handler
  void _onItemTapped(int index) {
    if (index == 1) {
      // Navigate to ProfileScreen with all patient parameters
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProfileScreen(
                patientId: widget.patientId,
                patientName: _patientName,
                age: _patientAge,
                breakfast: _patientBreakfast,
                lunch: _patientLunch,
                dinner: _patientDinner,
              ),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('patients').doc(widget.patientId).snapshots(),
        builder: (context, patientSnapshot) {
          if (!patientSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!patientSnapshot.data!.exists) {
            return const Center(child: Text('Patient not found.'));
          }
          // Extract and update local state from patient data
          final patientData =
              patientSnapshot.data!.data() as Map<String, dynamic>;
          _updatePatientData(patientData);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting text
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hello $_patientName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Medications list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      db
                          .collection('patients')
                          .doc(widget.patientId)
                          .collection('medications')
                          .snapshots(),
                  builder: (context, medsSnapshot) {
                    if (!medsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = medsSnapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No prescriptions or medicines added yet.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final medicineName = data['medicineName'] ?? 'Unknown';
                        final dosage = data['dosage'] ?? '';
                        final frequency = data['frequency'] ?? '';
                        final beforeAfterMeal = data['beforeAfterMeal'] ?? '';
                        final coursePeriod =
                            data['coursePeriod']?.toString() ?? '';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(medicineName),
                            subtitle: Text(
                              'Dosage: $dosage\n'
                              'Frequency: $frequency\n'
                              'Before/After Meal: $beforeAfterMeal\n'
                              'Course: $coursePeriod days',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                // Handle "Taken" action if needed
                              },
                              child: const Text('Taken'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
