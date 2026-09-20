import 'package:blackjack/design/theme.dart';
import 'package:blackjack/model/day_stats.dart';
import 'package:blackjack/state/day_stats_store.dart';
import 'package:blackjack/ui/calendar/calendar_screen.dart';
import 'package:blackjack/ui/calendar/day_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The calendar is a lot of grid maths on a small screen, so these are mostly
/// about it laying out at all: no overflow, no unbounded-constraint crash, on
/// both a short phone and a tall one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DayStatsStore> storeWith(Map<DateTime, int> nets) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DayStatsStore(prefs);
    for (final e in nets.entries) {
      store.now = () => e.key;
      store.recordRound(net: e.value, wagered: 50);
    }
    // Writes are debounced; flushing cancels the pending timer so the widget
    // binding does not report it as leaked at the end of the test.
    store.flush();
    addTearDown(store.dispose);
    return store;
  }

  /// Both screens are long lists, so anything past the first viewport has to
  /// be scrolled to before it exists to find.
  Future<void> reveal(WidgetTester tester, Finder target, {bool inSheet = false}) async {
    final scrollables = find.byType(Scrollable);
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: inSheet ? scrollables.last : scrollables.first,
    );
    await tester.pumpAndSettle();
  }

  Widget screen(DayStatsStore store) => ChangeNotifierProvider<DayStatsStore>.value(
        value: store,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: SafeArea(child: CalendarScreen())),
        ),
      );

  testWidgets('an empty calendar says so instead of drawing a blank grid',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(screen(DayStatsStore(prefs)));

    expect(find.text('No days on record'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a played month lays out and opens a day sheet', (tester) async {
    final now = DateTime.now();
    final store = await storeWith({
      DateTime(now.year, now.month, 1): 150,
      DateTime(now.year, now.month, 2): -80,
      DateTime(now.year, now.month, 3): 0,
    });

    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The 1st is a played day, so its cell opens the sheet.
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();

    expect(find.text('NET ON THE DAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the day sheet shows the same date in an earlier year',
      (tester) async {
    final now = DateTime.now();
    final store = await storeWith({
      DateTime(now.year, now.month, 4): 60,
      DateTime(now.year - 1, now.month, 4): -120,
      DateTime(now.year - 2, now.month, 4): 30,
    });

    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').first);
    await tester.pumpAndSettle();

    await reveal(tester, find.text('ON THIS DAY'), inSheet: true);
    expect(find.text('ON THIS DAY'), findsOneWidget);

    // Scoped to the sheet: the month view behind it also prints year labels.
    Finder inSheet(String text) =>
        find.descendant(of: find.byType(DaySheet), matching: find.text(text));
    expect(inSheet('${now.year - 1}'), findsOneWidget);
    expect(inSheet('${now.year - 2}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the year view draws a full heatmap without overflowing',
      (tester) async {
    final now = DateTime.now();
    final nets = <DateTime, int>{};
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= daysInMonth(now.year, m); d += 2) {
        nets[DateTime(now.year, m, d)] = (d % 5) * 40 - 80;
      }
    }
    final store = await storeWith(nets);

    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('THIS YEAR'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await reveal(tester, find.text('MONTH BY MONTH'));
    expect(find.text('MONTH BY MONTH'), findsOneWidget);

    // All-time totals are only computed once asked for.
    await reveal(tester, find.text('ALL TIME'));
    await tester.tap(find.text('ALL TIME'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Days played'));
    expect(find.text('Days played'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the month grid fits a narrow, short screen', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final store = await storeWith({DateTime(now.year, now.month, 15): 25});

    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('stepping back a month never runs past today', (tester) async {
    final now = DateTime.now();
    final store = await storeWith({DateTime(now.year, now.month, 10): 40});

    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    final prev = DateTime(now.year, now.month - 1);
    expect(
      find.text('${kMonthNames[prev.month - 1]} ${prev.year}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
