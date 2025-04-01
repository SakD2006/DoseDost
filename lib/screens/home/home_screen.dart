import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart'; // Ensure ProfileScreen is implemented

class HomeScreen extends StatefulWidget {
  final String patientId;
  final String
  patientName; // initial patientName if available, can be overridden from Firestore
  const HomeScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    // Wrap the entire Scaffold with a StreamBuilder to fetch patient data
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('patients').doc(widget.patientId).snapshots(),
      builder: (context, patientSnapshot) {
        if (!patientSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!patientSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Patient not found.')),
          );
        }
        // Extract patient data from the snapshot
        final patientData =
            patientSnapshot.data!.data() as Map<String, dynamic>;
        final patientName = patientData['Name'] ?? 'Unknown';
        final patientAge = patientData['Age'] ?? 0;
        final mealTiming = patientData['Meal-timing'] ?? {};
        final patientBreakfast = mealTiming['Breakfast'] ?? 'N/A';
        final patientLunch = mealTiming['Lunch'] ?? 'N/A';
        final patientDinner = mealTiming['Dinner'] ?? 'N/A';

        return Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Text
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hello $patientName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Medications List
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
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: (index) {
              if (index == 1) {
                // Navigate to ProfileScreen with the patient data
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ProfileScreen(
                          patientId: widget.patientId,
                          patientName: patientName,
                          age: patientAge,
                          breakfast: patientBreakfast,
                          lunch: patientLunch,
                          dinner: patientDinner,
                        ),
                  ),
                );
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
          ),
        );
      },
    );
  }
}
