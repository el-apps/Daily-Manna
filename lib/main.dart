import 'dart:async';

import 'package:daily_manna/app_router.dart';
import 'package:daily_manna/services/auth_service.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/services/streak_service.dart';
import 'package:daily_manna/services/sync_service.dart';
import 'package:daily_manna/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  usePathUrlStrategy();
  // Keep pushed screens bookmarkable while retaining the native navigation stack.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const DailyMannaApp());
}

class DailyMannaApp extends StatefulWidget {
  const DailyMannaApp({super.key});

  @override
  State<DailyMannaApp> createState() => _DailyMannaAppState();
}

class _DailyMannaAppState extends State<DailyMannaApp> {
  late AppDatabase _database;
  late BibleService _bibleService;
  late SettingsService _settingsService;
  late ResultsService _resultsService;
  late StudyNotesService _studyNotesService;
  late ErrorLoggerService _errorLoggerService;
  late SpacedRepetitionService _spacedRepetitionService;
  late StreakService _streakService;
  late NotificationService _notificationService;
  late SyncService _syncService;
  late AuthService _authService;
  late Future _initFuture;
  AppLifecycleListener? _appLifecycle;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _bibleService = BibleService();
    _settingsService = SettingsService();
    _resultsService = ResultsService(_database);
    _studyNotesService = StudyNotesService(_database);
    _errorLoggerService = ErrorLoggerService();
    _spacedRepetitionService = SpacedRepetitionService(
      _database,
      _bibleService,
    );
    _streakService = StreakService(_database);
    _notificationService = NotificationService(
      settingsService: _settingsService,
      errorLogger: _errorLoggerService,
    );
    _authService = AuthService();
    _syncService = SyncService(
      _database,
      authTokenProvider: _authService.tokenProvider,
      errorLogger: _errorLoggerService,
      onUnauthorized: _authService.signOut,
    );
    _resultsService.onLocalChange = _syncService.requestSync;
    _studyNotesService.onLocalChange = _syncService.requestSync;
    _initFuture =
        Future.wait([
          _authService.init(),
          _settingsService.init(),
          _errorLoggerService.init(),
          _bibleService.load(context),
        ]).then((_) {
          if (!mounted) return;
          _authService.addListener(_updateAutomaticSync);
          _appLifecycle = AppLifecycleListener(
            onStateChange: (_) => _updateAutomaticSync(),
          );
          _updateAutomaticSync();
          unawaited(_initializeNotifications());
        });
  }

  Future<void> _initializeNotifications() async {
    if (kIsWeb) return;
    try {
      await _notificationService.initialize();
      await _notificationService.scheduleDailyNotification();
    } catch (_) {
      // NotificationService logs failures; reminders must not prevent account sync.
    }
  }

  void _updateAutomaticSync() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_authService.isSignedIn &&
        (state == null || state == AppLifecycleState.resumed)) {
      unawaited(_syncService.startAutomaticSync());
    } else {
      _syncService.stopAutomaticSync();
    }
  }

  @override
  void dispose() {
    _appLifecycle?.dispose();
    _authService.removeListener(_updateAutomaticSync);
    _syncService.stopAutomaticSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _initFuture,
    builder: (context, asyncSnapshot) => _bibleService.isLoaded
        ? MultiProvider(
            providers: [
              Provider.value(value: _database),
              Provider.value(value: _bibleService),
              Provider.value(value: _settingsService),
              Provider.value(value: _resultsService),
              Provider.value(value: _studyNotesService),
              Provider.value(value: _spacedRepetitionService),
              Provider.value(value: _streakService),
              Provider.value(value: _notificationService),
              Provider.value(value: _syncService),
              ChangeNotifierProvider.value(value: _authService),
              ChangeNotifierProvider.value(value: _errorLoggerService),
            ],
            child: MaterialApp.router(
              title: 'Daily Manna',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.brown,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              routerConfig: appRouter,
            ),
          )
        : Center(child: CircularProgressIndicator()),
  );
}
