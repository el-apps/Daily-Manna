import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'error_logger_service.dart';
import 'settings_service.dart';
import 'streak_service.dart';
import 'spaced_repetition_service.dart';

/// Service for managing daily reminder notifications.
class NotificationService {
  static const int _dailyNotificationId = 0;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily Reminders';
  static const String _notificationTitle = 'Daily Manna';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final SettingsService _settingsService;
  final StreakService _streakService;
  final SpacedRepetitionService _spacedRepetitionService;
  final ErrorLoggerService? _errorLogger;

  bool _isInitialized = false;

  NotificationService({
    required SettingsService settingsService,
    required StreakService streakService,
    required SpacedRepetitionService spacedRepetitionService,
    ErrorLoggerService? errorLogger,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  })  : _settingsService = settingsService,
        _streakService = streakService,
        _spacedRepetitionService = spacedRepetitionService,
        _errorLogger = errorLogger,
        _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  void _log(String message) {
    _errorLogger?.logError(message, context: 'Notification');
  }

  /// Initializes the notification plugin, timezone, and requests permissions.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();
      // Use device's UTC offset to find matching timezone
      final now = DateTime.now();
      final offsetDuration = now.timeZoneOffset;
      final location = tz.timeZoneDatabase.locations.values.firstWhere(
        (location) => location.currentTimeZone.offset == offsetDuration.inMilliseconds,
        orElse: () => tz.UTC,
      );
      tz.setLocalLocation(location);
      _log('Timezone set to ${location.name}');

      // Initialize the plugin with platform-specific settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      _log('Plugin initialized');

      // Request permissions on Android 13+
      await _requestPermissions();

      _isInitialized = true;
      _log('Initialization complete');
    } catch (e) {
      _log('Initialize error: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    // Request Android notification permissions (Android 13+)
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _log('Android permission granted: $granted');
    }

    // Request iOS permissions
    final iosPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _log('iOS permission granted: $granted');
    }
  }

  /// Schedules a daily notification at the configured time.
  /// If notifications are disabled, cancels any existing notification.
  Future<void> scheduleDailyNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    final enabled = _settingsService.getNotificationsEnabled();
    if (!enabled) {
      await cancelNotification();
      return;
    }

    // Cancel existing notification before scheduling a new one
    await cancelNotification();

    final notificationTime = _settingsService.getNotificationTime();
    final scheduledTime = _nextInstanceOfTime(notificationTime);

    // Get current stats for notification body
    final reviewCount = await _spacedRepetitionService.getDueCount();
    final streakState = await _streakService.getStreak();
    final body = buildNotificationBody(reviewCount, streakState.streakDays);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminder notifications for verse review',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: _dailyNotificationId,
        title: _notificationTitle,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _log('Scheduled for ${scheduledTime.toString()}: $body');
    } catch (e) {
      _log('Schedule error: $e');
      rethrow;
    }
  }

  /// Cancels the scheduled daily notification.
  Future<void> cancelNotification() async {
    await _notificationsPlugin.cancel(id: _dailyNotificationId);
  }

  /// Checks if notifications are enabled at the system level.
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    return true; // Assume enabled on non-Android
  }

  /// Shows a test notification immediately.
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminder notifications for verse review',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 99, // Different ID for test
        title: _notificationTitle,
        body: 'Test notification - notifications are working!',
        notificationDetails: notificationDetails,
      );
      _log('Test notification sent');
    } catch (e) {
      _log('Test notification error: $e');
      rethrow;
    }
  }

  /// Builds the notification body based on review count and streak days.
  String buildNotificationBody(int reviewCount, int streakDays) {
    final hasReviews = reviewCount > 0;
    final hasStreak = streakDays > 0;

    if (hasReviews && hasStreak) {
      final verseText = _pluralize(reviewCount, 'verse', 'verses');
      return 'You have $reviewCount $verseText to review. '
          'Keep your $streakDays day streak going!';
    } else if (hasStreak) {
      return 'Keep your $streakDays day streak going!';
    } else if (hasReviews) {
      final verseText = _pluralize(reviewCount, 'verse', 'verses');
      return 'You have $reviewCount $verseText to review.';
    } else {
      return 'Start a daily habit in the Word!';
    }
  }

  String _pluralize(int count, String singular, String plural) =>
      count == 1 ? singular : plural;

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
