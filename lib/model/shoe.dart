import 'dart:math';

import 'card.dart';

/// A multi-deck shoe with a cut card. Tracks the running Hi-Lo count as cards
/// leave it, which is what the trainer turns into a true count.
class Shoe {
  Shoe({required this.decks, required this.penetration, int? seed})
      : _rng = Random(seed) {
    shuffle();
  }

  final int decks;
  final double penetration;
  final Random _rng;

  final List<PlayingCard> _cards = [];
  int _pos = 0;
  int _cutIndex = 0;
  int _nextId = 0;

  int runningCount = 0;

  int get cardsRemaining => _cards.length - _pos;
  int get cardsTotal => _cards.length;
  int get cardsToCut => (_cutIndex - _pos).clamp(0, _cards.length);

  /// How far into the dealable portion we are, for the shoe gauge.
  double get dealtFraction => _cutIndex == 0 ? 0 : (_pos / _cutIndex).clamp(0.0, 1.0);

  bool get pastCut => _pos >= _cutIndex;

  double get decksRemaining {
    final d = cardsRemaining / 52.0;
    return d < 0.25 ? 0.25 : d;
  }

  double get trueCount => runningCount / decksRemaining;

  void shuffle() {
    _cards.clear();
    for (var d = 0; d < decks; d++) {
      for (final s in Suit.values) {
        for (final r in Rank.values) {
          _cards.add(PlayingCard(r, s, _nextId++));
        }
      }
    }
    _cards.shuffle(_rng);
    _pos = 0;
    runningCount = 0;
    final base = (_cards.length * penetration).round();
    _cutIndex = base.clamp(20, _cards.length - 8);
  }

  PlayingCard draw() {
    if (_pos >= _cards.length) shuffle();
    final c = _cards[_pos++];
    runningCount += c.hiLo;
    return c;
  }
}
