import 'package:blackjack/design/theme.dart';
import 'package:blackjack/state/day_stats_store.dart';
import 'package:blackjack/state/profile_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:blackjack/ui/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProfileStore, StatsStore, DayStatsStore)> stores({
    int rounds = 0,
    int correct = 0,
    String? name,
    int peak = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final days = DayStatsStore(prefs)..now = () => DateTime(2026, 9, 20);
    final profile = ProfileStore(prefs);
    final stats = StatsStore(prefs, days: days, profile: profile);

    for (var i = 0; i < rounds; i++) {
      stats.recordRound(net: 20, wagered: 50, bankroll: 500 + i * 20);
    }
    for (var i = 0; i < correct; i++) {
      stats.recordDecision('16 v 10', true, 'Hit');
    }
    if (name != null) profile.setName(name);
    if (peak > 0) profile.noteBankroll(peak);

    stats.flush();
    addTearDown(days.dispose);
    return (profile, stats, days);
  }

  Widget screen(ProfileStore p, StatsStore s, DayStatsStore d) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileStore>.value(value: p),
          ChangeNotifierProvider<StatsStore>.value(value: s),
          ChangeNotifierProvider<DayStatsStore>.value(value: d),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: SafeArea(child: ProfileScreen())),
        ),
      );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a new player sees how levelling works, not an empty bar',
      (tester) async {
    final (p, s, d) = await stores();
    await tester.pumpWidget(screen(p, s, d));
    await tester.pumpAndSettle();

    expect(find.text('Nothing earned yet'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsWidgets);
    expect(find.text('Walk-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a played profile shows rank, breakdown, badges and career',
      (tester) async {
    final (p, s, d) = await stores(rounds: 60, correct: 150, name: 'Ionel', peak: 12000);
    await tester.pumpWidget(screen(p, s, d));
    await tester.pumpAndSettle();

    expect(find.text('IONEL'), findsOneWidget);
    expect(find.text('Nothing earned yet'), findsNothing);
    expect(tester.takeException(), isNull);

    await reveal(tester, find.text('WHERE IT CAME FROM'));
    expect(find.text('Rounds dealt'), findsWidgets);

    await reveal(tester, find.text('BADGES'));
    expect(find.text('First Hand'), findsOneWidget);

    await reveal(tester, find.text('CAREER'));
    expect(find.text('Peak bankroll'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the name can be edited from the card', (tester) async {
    final (p, s, d) = await stores(rounds: 5);
    await tester.pumpWidget(screen(p, s, d));
    await tester.pumpAndSettle();

    expect(find.text('PLAYER'), findsOneWidget);

    await tester.tap(find.text('PLAYER'));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ionel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(p.name, 'Ionel');
    expect(find.text('IONEL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the profile lays out on a narrow, short screen', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (p, s, d) = await stores(rounds: 400, correct: 1200, name: 'Bartholomew', peak: 250000);
    await tester.pumpWidget(screen(p, s, d));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await reveal(tester, find.text('CAREER'));
    expect(tester.takeException(), isNull);
  });
}
