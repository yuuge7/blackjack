import 'package:blackjack/design/theme.dart';
import 'package:blackjack/main.dart';
import 'package:blackjack/model/card.dart';
import 'package:blackjack/model/hand.dart';
import 'package:blackjack/state/game_controller.dart';
import 'package:blackjack/state/settings_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:blackjack/ui/table/table_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Hand handOf(List<Rank> ranks, {int bet = 25, bool fromSplit = false}) {
  final h = Hand(bet: bet, fromSplit: fromSplit);
  for (var i = 0; i < ranks.length; i++) {
    h.cards.add(PlayingCard(ranks[i], Suit.values[i % 4], 100 + i + ranks.length * 10));
  }
  return h;
}

Future<GameController> controller() async {
  SharedPreferences.setMockInitialValues({'haptics': false, 'bankroll': 500});
  final prefs = await SharedPreferences.getInstance();
  return GameController(
    settings: SettingsStore(prefs),
    stats: StatsStore(prefs),
    prefs: prefs,
  );
}

Widget table(GameController game) => ChangeNotifierProvider<GameController>.value(
      value: game,
      child: MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: SafeArea(child: TableScreen())),
      ),
    );

void main() {
  testWidgets('the app opens on the table and moves between tabs', (tester) async {
    SharedPreferences.setMockInitialValues({'haptics': false});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(BlackjackApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('DEALER'), findsOneWidget);
    expect(find.text('DEAL'), findsOneWidget);
    expect(find.text('NICKEL'), findsOneWidget);

    await tester.tap(find.text('STATS'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to show yet'), findsOneWidget);

    await tester.tap(find.text('RULES'));
    await tester.pumpAndSettle();
    expect(find.text('HOUSE EDGE'), findsOneWidget);
  });

  testWidgets('three split hands and a long fan lay out without overflowing',
      (tester) async {
    final game = await controller();
    game.dealer = handOf([Rank.six, Rank.king]);
    game.hands = [
      handOf([Rank.eight, Rank.four], fromSplit: true),
      handOf([Rank.eight, Rank.two, Rank.three, Rank.four, Rank.five, Rank.two],
          fromSplit: true),
      handOf([Rank.eight, Rank.ace], fromSplit: true),
    ];
    game.phase = Phase.playerTurn;
    game.active = 1;

    await tester.pumpWidget(table(game));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // One badge per player hand, plus the dealer's.
    expect(find.text('12'), findsOneWidget); // hand one
    expect(find.text('19'), findsOneWidget); // the long fan
  });

  testWidgets('the table still fits a short screen', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final game = await controller();
    game.dealer = handOf([Rank.ace, Rank.nine]);
    game.hands = [handOf([Rank.king, Rank.seven])];
    game.phase = Phase.playerTurn;

    await tester.pumpWidget(table(game));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DEALER'), findsOneWidget);
  });
}
