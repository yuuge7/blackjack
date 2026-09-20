import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/theme.dart';
import 'design/tokens.dart';
import 'state/day_stats_store.dart';
import 'state/game_controller.dart';
import 'state/profile_store.dart';
import 'state/settings_store.dart';
import 'state/stats_store.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColor.rail,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  runApp(BlackjackApp(prefs: prefs));
}

class BlackjackApp extends StatelessWidget {
  const BlackjackApp({required this.prefs, super.key});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsStore(prefs)),
        ChangeNotifierProvider(create: (_) => DayStatsStore(prefs)),
        ChangeNotifierProvider(create: (_) => ProfileStore(prefs)),
        // The day ledger and the profile's high-water mark are both fed
        // through StatsStore rather than from the table, so there is exactly
        // one place a round gets counted.
        ChangeNotifierProxyProvider2<DayStatsStore, ProfileStore, StatsStore>(
          create: (ctx) => StatsStore(
            prefs,
            days: ctx.read<DayStatsStore>(),
            profile: ctx.read<ProfileStore>(),
          ),
          update: (_, __, ___, stats) => stats!,
        ),
        ChangeNotifierProxyProvider2<SettingsStore, StatsStore, GameController>(
          create: (ctx) => GameController(
            settings: ctx.read<SettingsStore>(),
            stats: ctx.read<StatsStore>(),
            prefs: prefs,
          ),
          update: (_, __, ___, game) => game!,
        ),
      ],
      child: MaterialApp(
        title: 'Blackjack',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}
