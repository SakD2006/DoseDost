//home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart';
//import '../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const HomeScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Convert timestamp to minutes since midnight
  int timestampToMinutes(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return dateTime.hour * 60 + dateTime.minute;
  }

  // Format timestamp to readable time string (e.g., "8:00 AM")
  String formatTimestampToTime(dynamic value) {
    if (value is Timestamp) {
      DateTime dateTime = value.toDate();
      return DateFormat('h:mm a').format(dateTime);
    }
    return 'N/A';
  }

  // Determine current meal time based on time windows
  String getCurrentMealTime(int currentMinutes, Map<String, int> mealMinutes) {
    const window = 60; // ±1 hour window
    if (mealMinutes['Breakfast'] != null &&
        currentMinutes >= mealMinutes['Breakfast']! - window &&
        currentMinutes <= mealMinutes['Breakfast']! + window) {
      return 'Breakfast';
    } else if (mealMinutes['Lunch'] != null &&
        currentMinutes >= mealMinutes['Lunch']! - window &&
        currentMinutes <= mealMinutes['Lunch']! + window) {
      return 'Lunch';
    } else if (mealMinutes['Dinner'] != null &&
        currentMinutes >= mealMinutes['Dinner']! - window &&
        currentMinutes <= mealMinutes['Dinner']! + window) {
      return 'Dinner';
    }
    return ''; // No current meal
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final today =
        DateTime.now().toIso8601String().split('T')[0]; // e.g., "2023-10-01"
    final currentMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final todayDate = DateTime.now();
    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('patients').doc(widget.patientId).snapshots(),
      builder: (context, patientSnapshot) {
        if (!patientSnapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your profile...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }
        if (!patientSnapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Patient profile not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final patientData =
            patientSnapshot.data!.data() as Map<String, dynamic>;
        final patientFirstName = patientData['First Name'] ?? 'Unknown';
        final patientLastName = patientData['Last Name'] ?? ' ';
        final patientAge = patientData['Age'] ?? 0;
        final patientHeight = patientData['Height'] ?? ' ';
        final patientWeight = patientData['Weight'] ?? ' ';
        final mealTiming = patientData['Meal-timing'] ?? {};

        // Convert meal timings to minutes
        Map<String, int> mealMinutes = {};
        mealTiming.forEach((key, value) {
          if (value is Timestamp) {
            mealMinutes[key] = timestampToMinutes(value);
          }
        });

        // Get current meal time
        final currentMeal = getCurrentMealTime(currentMinutes, mealMinutes);
        final meals = ['Breakfast', 'Lunch', 'Dinner'];

        // Format current date for display
        final formattedDate = DateFormat('EEEE, MMMM d').format(todayDate);

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom App Bar with Profile Info
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Hello, $patientFirstName! 👋',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.primaryColor,
                            child: Text(
                              patientFirstName.isNotEmpty
                                  ? patientFirstName[0]
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Current meal info
                      if (currentMeal.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentMeal == 'Breakfast'
                                    ? Icons.breakfast_dining
                                    : currentMeal == 'Lunch'
                                    ? Icons.lunch_dining
                                    : Icons.dinner_dining,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Meal: $currentMeal',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Medication title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.medication, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Your Medications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Medication List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        db
                            .collection('medicineIntakes')
                            .where('patientId', isEqualTo: widget.patientId)
                            .where('date', isEqualTo: today)
                            .snapshots(),
                    builder: (context, intakesSnapshot) {
                      // Build set of taken medicines
                      Set<String> takenMedicines = {};
                      if (intakesSnapshot.hasData) {
                        for (var doc in intakesSnapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          if (data['taken'] == true) {
                            takenMedicines.add(
                              '${data['medicineId']}-${data['mealTime']}',
                            );
                          }
                        }
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream:
                            db
                                .collection('patients')
                                .doc(widget.patientId)
                                .collection('medications')
                                .snapshots(),
                        builder: (context, medsSnapshot) {
                          if (!medsSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = medsSnapshot.data!.docs;
                          if (docs.isEmpty) {
                            return _buildEmptyState(
                              'No medications added yet.',
                            );
                          }

                          // Filter medicines
                          List<DocumentSnapshot> filteredDocs = [];
                          for (var doc in docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            String frequency = data['frequency'] ?? '';
                            List<String> freqParts = frequency.split('-');
                            if (freqParts.length != 3)
                              continue; // Invalid frequency

                            if (currentMeal.isNotEmpty) {
                              int mealIndex = meals.indexOf(currentMeal);
                              if (freqParts[mealIndex] == '1') {
                                String medicineId = doc.id;
                                if (!takenMedicines.contains(
                                  '$medicineId-$currentMeal',
                                )) {
                                  if (data['startDate'] != null &&
                                      data['durationDays'] != null) {
                                    Timestamp startTimestamp =
                                        data['startDate'];
                                    DateTime startDate =
                                        startTimestamp.toDate();
                                    int durationDays = data['durationDays'];
                                    DateTime endDate = startDate.add(
                                      Duration(days: durationDays - 1),
                                    );
                                    if (todayDate.isAfter(
                                          startDate.subtract(
                                            const Duration(days: 1),
                                          ),
                                        ) &&
                                        todayDate.isBefore(
                                          endDate.add(const Duration(days: 1)),
                                        )) {
                                      filteredDocs.add(doc);
                                    }
                                  }
                                }
                              }
                            }
                          }

                          if (filteredDocs.isEmpty) {
                            if (currentMeal.isEmpty) {
                              return _buildEmptyState(
                                'It\'s not meal time yet. Check back later.',
                              );
                            }
                            return _buildEmptyState(
                              'No medicines to take right now.',
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final medicineName =
                                  data['medicineName'] ?? 'Unknown';
                              final dosage = data['dosage'] ?? '';
                              final instructions =
                                  data['beforeAfterMeal'] ?? '';
                              final durationDays =
                                  data['durationDays']?.toString() ?? '';

                              return _buildMedicationCard(
                                context,
                                medicineName,
                                dosage,
                                instructions,
                                durationDays,
                                doc.id,
                                currentMeal,
                                db,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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
            selectedItemColor: theme.primaryColor,
            onTap: (index) {
              if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ProfileScreen(
                          patientId: widget.patientId,
                          patientName: "$patientFirstName $patientLastName",
                          age: patientAge,
                          breakfast: formatTimestampToTime(
                            mealTiming['Breakfast'],
                          ),
                          lunch: formatTimestampToTime(mealTiming['Lunch']),
                          dinner: formatTimestampToTime(mealTiming['Dinner']),
                          height: patientHeight,
                          weight: patientWeight,
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    BuildContext context,
    String medicineName,
    String dosage,
    String instructions,
    String duration,
    String medicineId,
    String currentMeal,
    FirebaseFirestore db,
  ) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final theme = Theme.of(context);
    final pillColor = theme.primaryColor.withOpacity(0.8);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pillColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: pillColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Medicine details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            context,
                            dosage,
                            Icons.straighten,
                            theme.primaryColor.withOpacity(0.1),
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            context,
                            instructions,
                            Icons.access_time,
                            theme.primaryColor.withOpacity(0.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoChip(
                        context,
                        '$duration days',
                        Icons.calendar_today,
                        theme.primaryColor.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Confirm'),
                          content: Text('Mark $medicineName as taken?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await db.collection('medicineIntakes').add({
                                  'patientId': widget.patientId,
                                  'medicineId': medicineId,
                                  'date': today,
                                  'mealTime': currentMeal,
                                  'taken': true,
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$medicineName marked as taken!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Mark as Taken',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    IconData icon,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
