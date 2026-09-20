import 'package:blackjack/model/shoe.dart';
import 'package:blackjack/ui/stats/outcome_bar.dart';
import 'package:blackjack/ui/stats/stat_tile.dart';
import 'package:blackjack/ui/table/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Childless DecoratedBox and ColoredBox collapse to nothing under loose
/// constraints, which makes a bar silently disappear. These pin the sizes.
Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

void main() {
  testWidgets('every outcome segment is actually drawn', (tester) async {
    await tester.pumpWidget(wrap(const OutcomeBar(wins: 9, pushes: 2, losses: 13)));

    // The legend dots are decorated boxes too, so match on the bar's height.
    final boxes = find.descendant(
      of: find.byType(OutcomeBar),
      matching: find.byType(DecoratedBox),
    );
    final bars = tester
        .widgetList(boxes)
        .toList()
        .asMap()
        .keys
        .map((i) => tester.getSize(boxes.at(i)))
        .where((s) => s.height == 14)
        .toList();

    expect(bars.length, 3, reason: 'a segment collapsed to zero height');
    for (final s in bars) {
      expect(s.width, greaterThan(0));
    }
  });

  testWidgets('a meter fills to its value', (tester) async {
    await tester.pumpWidget(
      wrap(const Meter(value: 0.5, colour: Colors.amber, height: 6)),
    );

    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(ColoredBox),
    );
    final size = tester.getSize(fill);
    expect(size.height, 6);
    expect(size.width, closeTo(160, 0.5));
  });

  testWidgets('the shoe gauge shows how much has been dealt', (tester) async {
    final shoe = Shoe(decks: 6, penetration: 0.75, seed: 3);
    for (var i = 0; i < 100; i++) {
      shoe.draw();
    }

    await tester.pumpWidget(
      wrap(TableTopBar(bankroll: 500, shoe: shoe, showCount: true)),
    );

    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );
    final size = tester.getSize(fill);
    expect(size.height, 5);
    expect(size.width, greaterThan(0));
  });
}
