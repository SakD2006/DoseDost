import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'profile_screen.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';

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
  String _currentMeal = '';
  bool _initializedRecords = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentMealAndInitializeRecords();
    NotificationService.checkAndSendMedicationReminders();

    // Set loading to false after a brief delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkCurrentMealAndInitializeRecords() async {
    final db = FirebaseFirestore.instance;
    final snapshot =
        await db.collection('patients').doc(widget.patientId).get();

    if (snapshot.exists) {
      final patientData = snapshot.data() as Map<String, dynamic>;
      final mealTiming = patientData['Meal-timing'] ?? {};

      // Convert meal timings to minutes
      Map<String, int> mealMinutes = {};
      mealTiming.forEach((key, value) {
        if (value is Timestamp) {
          mealMinutes[key] = timestampToMinutes(value);
        }
      });

      final currentMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
      final currentMeal = getCurrentMealTime(currentMinutes, mealMinutes);

      setState(() {
        _currentMeal = currentMeal;
      });

      if (currentMeal.isNotEmpty && !_initializedRecords) {
        await initializeMedicationRecords(currentMeal);
        setState(() {
          _initializedRecords = true;
        });
      }
    }
  }

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

  Future<void> initializeMedicationRecords(String mealTime) async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final medications =
        await db
            .collection('patients')
            .doc(widget.patientId)
            .collection('medications')
            .get();

    // Get the meal index
    final meals = ['Breakfast', 'Lunch', 'Dinner'];
    final mealIndex = meals.indexOf(mealTime);

    for (var doc in medications.docs) {
      var data = doc.data();
      String frequency = data['frequency'] ?? '';
      List<String> freqParts = frequency.split('-');

      // Check if this medication should be taken at this meal
      if (freqParts.length == 3 && freqParts[mealIndex] == '1') {
        if (data['startDate'] != null && data['durationDays'] != null) {
          Timestamp startTimestamp = data['startDate'];
          DateTime startDate = startTimestamp.toDate();
          int durationDays = data['durationDays'];
          DateTime endDate = startDate.add(Duration(days: durationDays - 1));
          DateTime todayDate = DateTime.now();

          // Check if today is within the medication duration
          if (todayDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
              todayDate.isBefore(endDate.add(const Duration(days: 1)))) {
            // Check if a record already exists
            final existingRecord =
                await db
                    .collection('patients')
                    .doc(widget.patientId)
                    .collection('medicineIntakes')
                    .where('date', isEqualTo: today)
                    .where('medicineId', isEqualTo: doc.id)
                    .where('mealTime', isEqualTo: mealTime)
                    .get();

            // If no record exists, create one with taken=false
            if (existingRecord.docs.isEmpty) {
              await db
                  .collection('patients')
                  .doc(widget.patientId)
                  .collection('medicineIntakes')
                  .add({
                    'medicineName': data['medicineName'],
                    'dosage': data['dosage'],
                    'medicineId': doc.id,
                    'date': today,
                    'mealTime': mealTime,
                    'taken': false,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
            }
          }
        }
      }
    }
  }

  String _getMealIcon(String mealName) {
    switch (mealName) {
      case 'Breakfast':
        return '🍳';
      case 'Lunch':
        return '🍲';
      case 'Dinner':
        return '🍽️';
      default:
        return '⏰';
    }
  }

  String _getNextMealTime(Map<String, dynamic> mealTiming) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Get all meal times in minutes
    final mealMinutesMap = <String, int>{};
    for (final entry in mealTiming.entries) {
      if (entry.value is Timestamp) {
        final timestamp = entry.value as Timestamp;
        final dateTime = timestamp.toDate();
        mealMinutesMap[entry.key] = dateTime.hour * 60 + dateTime.minute;
      }
    }

    // Sort meal times to find the next one
    final sortedMeals =
        mealMinutesMap.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    for (final meal in sortedMeals) {
      if (meal.value > currentMinutes) {
        return '${meal.key} at ${formatTimestampToTime(mealTiming[meal.key])}';
      }
    }

    // If no meals are upcoming today, return the first meal for tomorrow
    if (sortedMeals.isNotEmpty) {
      return '${sortedMeals.first.key} tomorrow at ${formatTimestampToTime(mealTiming[sortedMeals.first.key])}';
    }

    return 'No upcoming meals';
  }

  Future<int> _getDailyMedicationCount() async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final intakes =
        await db
            .collection('patients')
            .doc(widget.patientId)
            .collection('medicineIntakes')
            .where('date', isEqualTo: today)
            .get();

    return intakes.docs.length;
  }

  Future<int> _getTakenMedicationCount() async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final intakes =
        await db
            .collection('patients')
            .doc(widget.patientId)
            .collection('medicineIntakes')
            .where('date', isEqualTo: today)
            .where('taken', isEqualTo: true)
            .get();

    return intakes.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayDate = DateTime.now();
    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('patients').doc(widget.patientId).snapshots(),
      builder: (context, patientSnapshot) {
        if (!patientSnapshot.hasData || _isLoading) {
          return _buildLoadingScreen(theme);
        }

        if (!patientSnapshot.data!.exists) {
          return _buildPatientNotFoundScreen();
        }

        final patientData =
            patientSnapshot.data!.data() as Map<String, dynamic>;
        final patientFirstName = patientData['First Name'] ?? 'Unknown';
        final patientLastName = patientData['Last Name'] ?? ' ';
        final patientAge = patientData['Age'] ?? 0;
        final patientHeight = patientData['Height'] ?? ' ';
        final patientWeight = patientData['Weight'] ?? ' ';
        final mealTiming = patientData['Meal-timing'] ?? {};
        final patientBloodType = patientData['Blood Group'] ?? 'Unknown';

        // Convert meal timings to minutes
        Map<String, int> mealMinutes = {};
        mealTiming.forEach((key, value) {
          if (value is Timestamp) {
            mealMinutes[key] = timestampToMinutes(value);
          }
        });

        // Get current meal time
        final currentMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
        final currentMeal = getCurrentMealTime(currentMinutes, mealMinutes);

        // Update state if meal time changed
        if (currentMeal != _currentMeal) {
          _currentMeal = currentMeal;
          if (currentMeal.isNotEmpty) {
            Future.microtask(() => initializeMedicationRecords(currentMeal));
          }
        }

        final meals = ['Breakfast', 'Lunch', 'Dinner'];

        // Format dates for display
        final formattedDate = DateFormat('EEEE, MMMM d').format(todayDate);
        final formattedTime = DateFormat('h:mm a').format(todayDate);

        // Get next meal time
        final nextMeal =
            _currentMeal.isEmpty ? _getNextMealTime(mealTiming) : '';

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern App Bar with Profile Info
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
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
                              Row(
                                children: [
                                  Text(
                                    'Hello, ',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  Text(
                                    patientFirstName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    ' 👋',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProfileScreen(
                                        patientId: widget.patientId,
                                        patientName:
                                            "$patientFirstName $patientLastName",
                                        age: patientAge,
                                        breakfast: formatTimestampToTime(
                                          mealTiming['Breakfast'],
                                        ),
                                        lunch: formatTimestampToTime(
                                          mealTiming['Lunch'],
                                        ),
                                        dinner: formatTimestampToTime(
                                          mealTiming['Dinner'],
                                        ),
                                        height: patientHeight,
                                        weight: patientWeight,
                                        bloodType: patientBloodType,
                                      ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  patientFirstName.isNotEmpty
                                      ? patientFirstName[0]
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Current or Next Meal Info
                      if (currentMeal.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getMealIcon(currentMeal),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT MEAL TIME',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentMeal,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else if (nextMeal.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⏰', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NEXT MEAL TIME',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nextMeal,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Medication Progress
                FutureBuilder<List<int>>(
                  future: Future.wait([
                    _getDailyMedicationCount(),
                    _getTakenMedicationCount(),
                  ]),
                  builder: (context, snapshot) {
                    int totalMeds =
                        snapshot.data != null ? snapshot.data![0] : 0;
                    int takenMeds =
                        snapshot.data != null ? snapshot.data![1] : 0;
                    double progress = totalMeds > 0 ? takenMeds / totalMeds : 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 20.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircularPercentIndicator(
                              radius: 35.0,
                              lineWidth: 8.0,
                              percent: progress,
                              center: Text(
                                '$takenMeds/$totalMeds',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.primaryColor,
                                ),
                              ),
                              progressColor: theme.primaryColor,
                              backgroundColor: theme.primaryColor.withOpacity(
                                0.1,
                              ),
                              circularStrokeCap: CircularStrokeCap.round,
                              animation: true,
                              animationDuration: 1000,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Today\'s Progress',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    progress >= 1
                                        ? 'Great job! All medications taken.'
                                        : 'Keep going! ${totalMeds - takenMeds} medications left to take.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Medication title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                      if (currentMeal.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'For ${currentMeal.toLowerCase()}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
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
                            .collection('patients')
                            .doc(widget.patientId)
                            .collection('medicineIntakes')
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
                              'You don\'t have any medications scheduled.\n'
                                  'Medicines will show as reminders once your Doctor adds a prescription for you.',
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
                                'Not meal time yet',
                                'It\'s not meal time yet. Check back later when it\'s time for your next meal.',
                              );
                            }
                            return _buildEmptyState(
                              'All caught up!',
                              'You\'ve taken all your medications for $currentMeal. Great job!',
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
                              final color = _getMedicineColor(index);

                              return _buildMedicationCard(
                                context,
                                medicineName,
                                dosage,
                                instructions,
                                durationDays,
                                doc.id,
                                currentMeal,
                                db,
                                color,
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  activeIcon: Icon(Icons.home_rounded, size: 28),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded, size: 28),
                  label: 'Profile',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: Colors.grey[400],
              selectedFontSize: 12,
              unselectedFontSize: 12,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
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
                            bloodType: patientBloodType,
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
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading Home Screen...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientNotFoundScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Patient Profile Not Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'We couldn\'t find your patient profile. Please log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Return to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 90, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getMedicineColor(int index) {
    final colors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFFFFA000), // Amber
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];
    return colors[index % colors.length];
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
    Color medicineColor,
  ) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: medicineColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: medicineColor,
                    size: 32,
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            context,
                            dosage,
                            Icons.straighten_rounded,
                            theme.primaryColor.withOpacity(0.1),
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            context,
                            '$instructions meal',
                            Icons.access_time_rounded,
                            theme.primaryColor.withOpacity(0.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoChip(
                        context,
                        'For $duration days',
                        Icons.calendar_today_rounded,
                        theme.primaryColor.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getInstructionText(instructions, dosage),
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Confirm Medication'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: theme.primaryColor,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Did you take $medicineName?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Dosage: $dosage',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Not Yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);

                                // Find the existing intake record
                                final existingRecords =
                                    await db
                                        .collection('patients')
                                        .doc(widget.patientId)
                                        .collection('medicineIntakes')
                                        .where('date', isEqualTo: today)
                                        .where(
                                          'medicineId',
                                          isEqualTo: medicineId,
                                        )
                                        .where(
                                          'mealTime',
                                          isEqualTo: currentMeal,
                                        )
                                        .get();

                                if (existingRecords.docs.isNotEmpty) {
                                  // Update existing record
                                  await db
                                      .collection('patients')
                                      .doc(widget.patientId)
                                      .collection('medicineIntakes')
                                      .doc(existingRecords.docs.first.id)
                                      .update({
                                        'taken': true,
                                        'timestamp':
                                            FieldValue.serverTimestamp(),
                                      });
                                } else {
                                  // Create new record if needed
                                  await db
                                      .collection('patients')
                                      .doc(widget.patientId)
                                      .collection('medicineIntakes')
                                      .add({
                                        'medicineName': medicineName,
                                        'dosage': dosage,
                                        'medicineId': medicineId,
                                        'date': today,
                                        'mealTime': currentMeal,
                                        'taken': true,
                                        'timestamp':
                                            FieldValue.serverTimestamp(),
                                      });
                                }

                                // Show success message
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('$medicineName marked as taken!'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(10),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Yes, I Took It'),
                            ),
                          ],
                        ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
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

  String _getInstructionText(String instructions, String dosage) {
    if (instructions.toLowerCase().contains('before')) {
      return 'Take $dosage $instructions your meal.';
    } else if (instructions.toLowerCase().contains('after')) {
      return 'Take $dosage $instructions your meal.';
    } else {
      return 'Take $dosage as prescribed by your doctor.';
    }
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    IconData icon,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
