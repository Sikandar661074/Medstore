import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../utils/constants.dart';

const String expiryCheckTask = 'expiryCheckTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == expiryCheckTask) {
      await NotificationService().showExpiryNotification();
    }
    return Future.value(true);
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Request permission Android 13+
    try {
      final plugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  Future<void> registerBackgroundTask() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'medstore-expiry-check',
      expiryCheckTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  Future<void> showExpiryNotification() async {
    await initialize();
    await _showNotification(
      id: AppConstants.notifExpiryId,
      title: '💊 MedStore — Expiry Check',
      body: 'Open the app to check medicines expiring soon.',
      channel: 'expiry_channel',
      channelName: 'Expiry Alerts',
    );
  }

  Future<void> showExpiredAlert(int count) async {
    await _showNotification(
      id: AppConstants.notifExpiryId,
      title: '🚨 $count Medicine(s) Expired!',
      body: 'Remove expired medicines from shelf immediately.',
      channel: 'expiry_channel',
      channelName: 'Expiry Alerts',
    );
  }

  Future<void> showExpiringAlert(int count, int days) async {
    await _showNotification(
      id: AppConstants.notifExpiryId + 1,
      title: '⚠️ $count Medicine(s) Expiring in $days Days',
      body: 'Tap to view medicines expiring soon.',
      channel: 'expiry_channel',
      channelName: 'Expiry Alerts',
    );
  }

  Future<void> checkAndNotify(List<Medicine> medicines) async {
    final expired = medicines.where((m) => m.isExpired).length;
    final critical = medicines.where((m) => m.isCritical).length;
    final warning = medicines.where((m) => m.isWarning).length;

    // Build a unique signature for the current notification state
    final sig = 'expiry_$expired\_$critical\_$warning';
    
    // Check SharedPreferences to see if we already notified this state today
    final prefs = await SharedPreferences.getInstance();
    final lastSig = prefs.getString('last_notif_sig');
    final lastDate = prefs.getString('last_notif_date');
    final today = DateTime.now().toIso8601String().split('T').first;

    // If the state is exactly the same and we already notified today, skip it.
    if (lastSig == sig && lastDate == today) {
      return;
    }

    if (expired > 0) {
      await showExpiredAlert(expired);
    } else if (critical > 0) {
      await showExpiringAlert(critical, 7);
    } else if (warning > 0) {
      await showExpiringAlert(warning, 30);
    }

    // Save the new state
    if (expired > 0 || critical > 0 || warning > 0) {
      await prefs.setString('last_notif_sig', sig);
      await prefs.setString('last_notif_date', today);
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: 'MedStore Manager Alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}