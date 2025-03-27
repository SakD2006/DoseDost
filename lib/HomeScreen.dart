import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ProfileScreen.dart';

// Replace this with your actual patientId or pass it from the login/setup flow
class HomeScreen extends StatelessWidget {
  final String patientId;

  const HomeScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to profile screen (to be implemented)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(patientId: patientId),
                ),
              );
            },
          ),
        ],
      ),
      // 1) First, stream the patient doc to get the patient's name
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('patients').doc(patientId).snapshots(),
        builder: (context, patientSnapshot) {
          if (!patientSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // If the patient doc doesn't exist
          if (!patientSnapshot.data!.exists) {
            return const Center(child: Text('Patient not found.'));
          }

          // Extract the patient's name from the doc
          final patientData =
              patientSnapshot.data!.data() as Map<String, dynamic>;
          final patientName = patientData['Name'] ?? 'Unknown';

          // 2) Now stream the 'medications' subcollection for this patient
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Hello, patientName"
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hello, $patientName',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              // Medications list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      db
                          .collection('patients')
                          .doc(patientId)
                          .collection('medications')
                          .snapshots(),
                  builder: (context, medsSnapshot) {
                    if (!medsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final medsDocs = medsSnapshot.data!.docs;
                    if (medsDocs.isEmpty) {
                      return const Center(
                        child: Text('No prescriptions or medicines added yet.'),
                      );
                    }

                    // Build a ListView of medication docs
                    return ListView.builder(
                      itemCount: medsDocs.length,
                      itemBuilder: (context, index) {
                        final medData =
                            medsDocs[index].data() as Map<String, dynamic>;
                        final medicineName =
                            medData['medicineName'] ?? 'Unknown';
                        final dosage = medData['dosage'] ?? '';
                        final frequency = medData['frequency'] ?? '';
                        final durationDays = medData['durationDays'] ?? 0;

                        return ListTile(
                          title: Text(medicineName),
                          subtitle: Text(
                            'Dosage: $dosage\n'
                            'Frequency: $frequency\n'
                            'Duration: $durationDays days',
                          ),
                          // You can add trailing icons, etc. if needed
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
    );
  }
}
