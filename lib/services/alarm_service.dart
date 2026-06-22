import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/medicine_model.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the Alarm/Notification Service
  static Future<void> init() async {
    // 1. Initialize timezone database using distinct namespace
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = _normalizeTimeZone(tzInfo.identifier);
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone initialized to: $timeZoneName');
    } catch (e) {
      debugPrint('Error setting local timezone: $e');
      // Fallback to Etc/UTC if timezone detection fails or zone not found
      try {
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
        debugPrint('Fallback local timezone initialized to: Etc/UTC');
      } catch (ex) {
        debugPrint('Fallback to Etc/UTC failed: $ex');
      }
    }

    // 2. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 3. Initialize the plugin
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 4. Request Android permissions (specifically post notifications for Android 13+)
    await requestPermissions();
  }

  /// Normalize timezone name to standard IANA timezone formats
  static String _normalizeTimeZone(String name) {
    if (name == 'UTC' || name == 'GMT') {
      return 'Etc/UTC';
    }
    return name;
  }

  /// Request necessary notification and exact alarm permissions
  static Future<void> requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  /// Helper to calculate unique 32-bit notification ID
  static int _getNotificationId(String medId, int dayOfWeek, int timeIndex) {
    // Ensure the ID is a valid 32-bit positive integer
    final int hash = medId.hashCode;
    return ((hash + dayOfWeek * 100 + timeIndex) & 0x7FFFFFFF);
  }

  /// Schedule daily or weekly alarms for a medicine
  static Future<void> scheduleAlarm(MedicineModel med) async {
    // First, cancel any existing alarms for this medicine
    await cancelAlarm(med);

    if (!med.active) return;

    final androidDetails = AndroidNotificationDetails(
      med.vibrate ? 'medication_alarm_vibrate_v3' : 'medication_alarm_silent_v3', // channelId
      'Medication Alarms', // channelName
      channelDescription: 'Alarms for scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('medication'),
      playSound: true,
      vibrationPattern: med.vibrate ? Int64List.fromList([0, 1000, 500, 1000]) : null,
      enableVibration: med.vibrate,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // For each time scheduled in the medication
    for (int timeIdx = 0; timeIdx < med.times.length; timeIdx++) {
      final String timeStr = med.times[timeIdx];
      final parts = timeStr.split(':');
      if (parts.length < 2) continue;

      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      // For each active day of week (1=Mon, 7=Sun)
      for (final int dayOfWeek in med.daysOfWeek) {
        final int notificationId = _getNotificationId(med.medId, dayOfWeek, timeIdx);
        
        final scheduledDate = _nextInstanceOfDayOfWeekAndTime(dayOfWeek, hour, minute);

        try {
          await _notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: 'Medication Reminder',
            body: 'Time to take ${med.name} (${med.dosage})',
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: med.medId,
          );
          debugPrint('Scheduled alarm $notificationId for ${med.name} on day $dayOfWeek at $hour:$minute');
        } catch (e) {
          debugPrint('Failed to schedule exact alarm $notificationId: $e');
        }
      }
    }
  }

  /// Cancel all alarms for a medicine
  static Future<void> cancelAlarm(MedicineModel med) async {
    // Since we don't know the exact previous times, we cancel all possible slots (e.g., up to 10 time indices)
    // for all days of the week (1 to 7) to ensure no orphaned alarms remain.
    for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
      for (int timeIdx = 0; timeIdx < 10; timeIdx++) {
        final int id = _getNotificationId(med.medId, dayOfWeek, timeIdx);
        await _notificationsPlugin.cancel(id: id);
      }
    }
    debugPrint('Cancelled alarms for medicine: ${med.medId}');
  }

  /// Calculate the next TZDateTime instance for a given day of the week (1=Mon, 7=Sun) and time
  static tz.TZDateTime _nextInstanceOfDayOfWeekAndTime(int dayOfWeek, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If scheduled time is in the past, or if we want a different day of the week, find the next occurrence
    int daysToAdd = dayOfWeek - now.weekday;
    if (daysToAdd < 0 || (daysToAdd == 0 && scheduledDate.isBefore(now))) {
      daysToAdd += 7;
    }

    scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
    return scheduledDate;
  }

  /// Show an immediate notification
  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'carely_immediate_channel',
      'Carely Alerts',
      channelDescription: 'Important alerts and notifications from Carely',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
