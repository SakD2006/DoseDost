// lib/services/notification_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static Map<String, Timer> _activeTimers = {};

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'medication_reminder',
        initialNotificationTitle: 'Medication Reminder Service',
        initialNotificationContent: 'Running in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    service.on('setAsForeground').listen((event) {
      service.invoke('setAsForeground');
    });

    service.on('setAsBackground').listen((event) {
      service.invoke('setAsBackground');
    });

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      await checkAndSendMedicationReminders();
    });
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'medication_reminders',
          'Medication Reminders',
          channelDescription: 'Reminders to take medications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> checkAndSendMedicationReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? patientId = prefs.getString('patientId');
    if (patientId == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final currentTime = DateTime.now();
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    final patientDoc = await _db.collection('patients').doc(patientId).get();
    if (!patientDoc.exists) return;

    final patientData = patientDoc.data() as Map<String, dynamic>;
    final mealTiming = patientData['Meal-timing'] ?? {};

    Map<String, int> mealMinutes = {};
    mealTiming.forEach((key, value) {
      if (value is Timestamp) {
        DateTime mealTime = value.toDate();
        mealMinutes[key] = mealTime.hour * 60 + mealTime.minute;
      }
    });

    String currentMeal = '';
    const window = 60;

    for (var entry in mealMinutes.entries) {
      if (currentMinutes >= entry.value - window &&
          currentMinutes <= entry.value + window) {
        currentMeal = entry.key;
        break;
      }
    }

    if (currentMeal.isEmpty) return;

    final mealIndex = ['Breakfast', 'Lunch', 'Dinner'].indexOf(currentMeal);
    if (mealIndex == -1) return;

    final medicationsSnapshot =
        await _db
            .collection('patients')
            .doc(patientId)
            .collection('medications')
            .get();

    final takenMedsSnapshot =
        await _db
            .collection('patients')
            .doc(patientId)
            .collection('medicineIntakes')
            .where('date', isEqualTo: today)
            .where('mealTime', isEqualTo: currentMeal)
            .where('taken', isEqualTo: true)
            .get();

    Set<String> takenMedicineIds = {};
    for (var doc in takenMedsSnapshot.docs) {
      takenMedicineIds.add(doc['medicineId']);
    }

    for (var doc in medicationsSnapshot.docs) {
      final medicineId = doc.id;
      final data = doc.data();

      if (takenMedicineIds.contains(medicineId)) {
        if (_activeTimers.containsKey('$medicineId-$currentMeal')) {
          _activeTimers['$medicineId-$currentMeal']?.cancel();
          _activeTimers.remove('$medicineId-$currentMeal');
        }
        continue;
      }

      String frequency = data['frequency'] ?? '';
      List<String> freqParts = frequency.split('-');

      if (freqParts.length == 3 && freqParts[mealIndex] == '1') {
        if (data['startDate'] != null && data['durationDays'] != null) {
          Timestamp startTimestamp = data['startDate'];
          DateTime startDate = startTimestamp.toDate();
          int durationDays = data['durationDays'];
          DateTime endDate = startDate.add(Duration(days: durationDays - 1));

          if (currentTime.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ) &&
              currentTime.isBefore(endDate.add(const Duration(days: 1)))) {
            final medicineName = data['medicineName'] ?? 'Unknown Medicine';
            final timerKey = '$medicineId-$currentMeal';

            if (!_activeTimers.containsKey(timerKey)) {
              showNotification(
                id: medicineId.hashCode,
                title: 'Time to take your medicine',
                body: 'Please take $medicineName for $currentMeal',
                payload: '$medicineId-$currentMeal',
              );

              _activeTimers[timerKey] = Timer.periodic(
                const Duration(minutes: 5),
                (timer) async {
                  final checkSnapshot =
                      await _db
                          .collection('patients')
                          .doc(patientId)
                          .collection('medicineIntakes')
                          .where('medicineId', isEqualTo: medicineId)
                          .where('date', isEqualTo: today)
                          .where('mealTime', isEqualTo: currentMeal)
                          .where('taken', isEqualTo: true)
                          .get();

                  if (checkSnapshot.docs.isNotEmpty) {
                    timer.cancel();
                    _activeTimers.remove(timerKey);
                  } else {
                    showNotification(
                      id: medicineId.hashCode,
                      title: 'Reminder: Take your medicine',
                      body: 'Please take $medicineName for $currentMeal',
                      payload: '$medicineId-$currentMeal',
                    );
                  }
                },
              );
            }
          }
        }
      }
    }
  }

  static Future<void> setPatientId(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patientId', patientId);
  }

  static void cancelAllReminders() {
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}
