import 'package:daily_manna/home_page.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/services/streak_service.dart';
import 'package:daily_manna/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
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
  late ErrorLoggerService _errorLoggerService;
  late SpacedRepetitionService _spacedRepetitionService;
  late StreakService _streakService;
  late NotificationService _notificationService;
  late Future _initFuture;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _bibleService = BibleService();
    _settingsService = SettingsService();
    _resultsService = ResultsService(_database);
    _errorLoggerService = ErrorLoggerService();
    _spacedRepetitionService = SpacedRepetitionService(_database);
    _streakService = StreakService(_database);
    _notificationService = NotificationService(
      settingsService: _settingsService,
      streakService: _streakService,
      spacedRepetitionService: _spacedRepetitionService,
      errorLogger: _errorLoggerService,
    );
    _initFuture = Future.wait([
      _settingsService.init().then((_) async {
        await _notificationService.initialize();
        await _notificationService.scheduleDailyNotification();
      }),
      _errorLoggerService.init(),
      _bibleService.load(context),
    ]);
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
              Provider.value(value: _spacedRepetitionService),
              Provider.value(value: _streakService),
              Provider.value(value: _notificationService),
              ChangeNotifierProvider.value(value: _errorLoggerService),
            ],
            child: MaterialApp(
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
              home: HomePage(),
            ),
          )
        : Center(child: CircularProgressIndicator()),
  );
}
