import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'database/database.dart';
import 'error_logger_service.dart';
import 'settings_service.dart';
import 'spaced_repetition_service.dart';
import 'streak_service.dart';

/// Task name for the daily notification background task.
const String dailyNotificationTask = 'dailyNotificationTask';

/// Time buffer in seconds to prevent same-day rescheduling when called
/// very close to the scheduled time.
const int _schedulingBufferSeconds = 60;

/// Top-level callback dispatcher for workmanager.
/// Must be a top-level function with @pragma annotation.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailyNotificationTask) {
      await _executeDailyNotificationTask();
    }
    return true;
  });
}

/// Executes the daily notification task in the background.
/// Opens database, computes fresh data, shows notification, reschedules.
Future<void> _executeDailyNotificationTask() async {
  // Check if notifications are enabled
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // Ensure fresh data in background isolate
  final enabled = prefs.getBool('notifications_enabled') ?? true;
  if (!enabled) return;

  // Open database and compute fresh counts
  final database = AppDatabase();
  try {
    final spacedRepService = SpacedRepetitionService(database);
    final streakService = StreakService(database);

    final reviewCount = await spacedRepService.getDueCount();
    final streakState = await streakService.getStreak();

    // Build notification body
    final body = NotificationService.buildNotificationBody(
      reviewCount,
      streakState.streakDays,
    );

    // Show notification immediately
    await _showNotification(body);

    // Reschedule for tomorrow
    final timeMinutes = prefs.getInt('notification_time') ?? (6 * 60);
    final time = TimeOfDay(hour: timeMinutes ~/ 60, minute: timeMinutes % 60);
    await _scheduleNextNotification(time);
  } finally {
    await database.close();
  }
}

/// Shows a notification immediately with the given body.
Future<void> _showNotification(String body) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await plugin.initialize(settings: initSettings);

  const androidDetails = AndroidNotificationDetails(
    'daily_reminder',
    'Daily Reminders',
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

  await plugin.show(
    id: 0,
    title: 'Daily Manna',
    body: body,
    notificationDetails: notificationDetails,
  );
}

/// Schedules the next notification task for the given time tomorrow.
Future<void> _scheduleNextNotification(TimeOfDay time) async {
  final delay = _calculateDelayUntilTomorrow(time);
  await Workmanager().registerOneOffTask(
    dailyNotificationTask,
    dailyNotificationTask,
    initialDelay: delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
    ),
  );
}

/// Calculates the duration until the given time tomorrow.
/// Uses Duration addition to properly handle month/year boundaries and DST.
Duration _calculateDelayUntilTomorrow(TimeOfDay time) {
  final now = DateTime.now();
  final todayAtTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  final tomorrowAtTime = todayAtTime.add(const Duration(days: 1));
  return tomorrowAtTime.difference(now);
}

/// Service for managing daily reminder notifications.
class NotificationService {
  final SettingsService _settingsService;
  final ErrorLoggerService? _errorLogger;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _workmanagerInitialized = false;
  bool _pluginInitialized = false;

  NotificationService({
    required SettingsService settingsService,
    ErrorLoggerService? errorLogger,
  })  : _settingsService = settingsService,
        _errorLogger = errorLogger,
        _notificationsPlugin = FlutterLocalNotificationsPlugin();

  void _log(String message) {
    _errorLogger?.logError(message, context: 'Notification');
  }

  /// Initializes the notification plugin once.
  Future<void> _ensurePluginInitialized() async {
    if (_pluginInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
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
    _pluginInitialized = true;
  }

  /// Initializes the notification system and requests permissions.
  Future<void> initialize() async {
    try {
      // Initialize workmanager
      if (!_workmanagerInitialized) {
        await Workmanager().initialize(notificationCallbackDispatcher);
        _workmanagerInitialized = true;
        _log('Workmanager initialized');
      }

      // Request notification permissions
      await _requestPermissions();
      _log('Initialization complete');
    } catch (e) {
      _log('Initialize error: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    await _ensurePluginInitialized();

    // Request Android notification permissions (Android 13+)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _log('Android permission granted: $granted');
    }

    // Request iOS permissions
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
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

  /// Schedules the daily notification at the configured time.
  /// If notifications are disabled, cancels any existing task.
  Future<void> scheduleDailyNotification() async {
    final enabled = _settingsService.getNotificationsEnabled();
    if (!enabled) {
      await cancelNotification();
      _log('Notifications disabled, cancelled task');
      return;
    }

    final notificationTime = _settingsService.getNotificationTime();
    final delay = calculateDelayUntilTime(notificationTime);

    try {
      await Workmanager().registerOneOffTask(
        dailyNotificationTask,
        dailyNotificationTask,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
      final scheduledTime = DateTime.now().add(delay);
      _log('Scheduled task for $scheduledTime');
    } catch (e) {
      _log('Schedule error: $e');
      rethrow;
    }
  }

  /// Cancels the scheduled daily notification task.
  Future<void> cancelNotification() async {
    await Workmanager().cancelByUniqueName(dailyNotificationTask);
  }

  /// Checks if notifications are enabled at the system level.
  Future<bool> areNotificationsEnabled() async {
    await _ensurePluginInitialized();

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    return true; // Assume enabled on non-Android
  }

  /// Builds the notification body based on review count and streak days.
  static String buildNotificationBody(int reviewCount, int streakDays) {
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

  static String _pluralize(int count, String singular, String plural) =>
      count == 1 ? singular : plural;

  /// Calculates the duration until the next occurrence of the given time.
  /// Uses Duration addition to properly handle month/year boundaries and DST.
  /// Includes a small buffer to prevent same-day rescheduling when called
  /// very close to the scheduled time.
  @visibleForTesting
  static Duration calculateDelayUntilTime(TimeOfDay time, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final todayAtTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      time.hour,
      time.minute,
    );

    // Add buffer to prevent edge case where we schedule for "now"
    final bufferTime = currentTime.add(
      const Duration(seconds: _schedulingBufferSeconds),
    );

    if (todayAtTime.isAfter(bufferTime)) {
      // Schedule for today
      return todayAtTime.difference(currentTime);
    } else {
      // Schedule for tomorrow
      final tomorrowAtTime = todayAtTime.add(const Duration(days: 1));
      return tomorrowAtTime.difference(currentTime);
    }
  }
}
