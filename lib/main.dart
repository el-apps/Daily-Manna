import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/home_page.dart';
import 'package:daily_manna/verse_memorization.dart';
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
  late BibleService _bibleService;
  late Future _bibleFuture;

  @override
  void initState() {
    super.initState();
    _bibleService = BibleService();
    _bibleFuture = _bibleService.load(context);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bibleFuture,
    builder: (context, asyncSnapshot) => _bibleService.isLoaded
        ? Provider.value(
            value: _bibleService,
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
