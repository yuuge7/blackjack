import 'dart:async';
import 'dart:io';

import 'package:blackjack/design/theme.dart';
import 'package:blackjack/model/stats.dart';
import 'package:blackjack/state/save_file.dart';
import 'package:blackjack/state/save_transfer.dart';
import 'package:blackjack/ui/settings/restore_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final staged = StagedSave(
    file: File('pending.bjsave'),
    name: 'blackjack-2026-09-20.bjsave',
    summary: SaveSummary(
      version: SaveFile.version,
      savedAt: DateTime(2026, 9, 20),
      bankroll: 4200,
      bet: 25,
      stats: StatsData(),
      playerName: 'Ionel',
      peakBankroll: 48200,
      dayCount: 12,
      dayRounds: 340,
      dayNet: 1200,
      firstYear: 2026,
      lastYear: 2026,
      bytes: 2048,
    ),
  );

  const kept = ExportOutcome.saved(
    name: 'blackjack-2026-09-20-before-import.bjsave',
    bytes: 3072,
    where: null,
  );

  /// Opens the dialog behind a button, the way the transfer panel does, and
  /// hands back whatever it closes with.
  Future<ValueNotifier<RestoreChoice?>> open(
    WidgetTester tester,
    Future<ExportOutcome> Function() onDownload,
  ) async {
    final closedWith = ValueNotifier<RestoreChoice?>(null);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              closedWith.value = await showDialog<RestoreChoice>(
                context: context,
                builder: (_) => RestoreDialog(staged: staged, onDownload: onDownload),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return closedWith;
  }

  testWidgets('downloading the current save reports where it went and keeps the choice open',
      (tester) async {
    var calls = 0;
    final closedWith = await open(tester, () async {
      calls++;
      return kept;
    });

    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Kept blackjack-2026-09-20-before-import.bjsave · 3.0 KB'), findsOneWidget);
    expect(find.text('Download again'), findsOneWidget);
    expect(find.byType(RestoreDialog), findsOneWidget);

    await tester.tap(find.text('Merge days'));
    await tester.pumpAndSettle();
    expect(closedWith.value, RestoreChoice.merge);
  });

  testWidgets('the dialog cannot be closed or applied while a download is running',
      (tester) async {
    final pending = Completer<ExportOutcome>();
    final closedWith = await open(tester, () => pending.future);

    await tester.tap(find.text('Download current save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await tester.tap(find.text('Replace everything'));
    await tester.pump();
    await tester.tapAt(const Offset(4, 4)); // the barrier
    await tester.pump();
    expect(find.byType(RestoreDialog), findsOneWidget);
    expect(closedWith.value, isNull);

    pending.complete(kept);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace everything'));
    await tester.pumpAndSettle();
    expect(closedWith.value, RestoreChoice.replace);
  });

  testWidgets('backing out of the save dialog changes nothing', (tester) async {
    await open(tester, () async => const ExportOutcome.cancelled());

    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();

    expect(find.text('Download current save'), findsOneWidget);
    expect(find.textContaining('Kept'), findsNothing);
  });

  testWidgets('a failed download says why and can be retried', (tester) async {
    var fail = true;
    await open(tester, () async {
      if (fail) throw const SaveFileError('The save could not be written there.');
      return kept;
    });

    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();
    expect(find.text('The save could not be written there.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();
    expect(find.text('The save could not be written there.'), findsNothing);
    expect(find.textContaining('Kept'), findsOneWidget);
  });

  testWidgets('a failed second copy is not hidden behind the first one', (tester) async {
    var fail = false;
    await open(tester, () async {
      if (fail) throw const SaveFileError('The save could not be written there.');
      return kept;
    });

    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kept'), findsOneWidget);

    fail = true;
    await tester.tap(find.text('Download again'));
    await tester.pumpAndSettle();
    expect(find.text('The save could not be written there.'), findsOneWidget);
    expect(find.textContaining('Kept'), findsNothing);
  });

  testWidgets('the dialog lays out on a narrow, short screen', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await open(tester, () async => kept);
    expect(tester.takeException(), isNull);

    // The content scrolls at this height; the button has to be reachable.
    await tester.ensureVisible(find.text('Download current save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download current save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
