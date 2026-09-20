import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/hand.dart';
import '../model/stats.dart';
import 'day_stats_store.dart';
import 'profile_store.dart';

enum StatsScope { session, lifetime }

/// Keeps three ledgers in step: this session, everything ever played, and — if
/// one is wired up — the per-day record the calendar reads.
class StatsStore extends ChangeNotifier {
  StatsStore(this._prefs, {this.days, this.profile}) {
    final raw = _prefs.getString('stats');
    if (raw != null) {
      try {
        _lifetime = StatsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _lifetime = StatsData();
      }
    }
  }

  final SharedPreferences _prefs;

  /// The calendar's ledger, when one is wired up. Null in tests that only
  /// care about the session and lifetime totals.
  final DayStatsStore? days;

  /// Holds the bankroll high-water mark the profile's badges read.
  final ProfileStore? profile;

  StatsData _lifetime = StatsData();
  StatsData _session = StatsData();
  Timer? _saveTimer;

  StatsData get lifetime => _lifetime;
  StatsData get session => _session;

  StatsData of(StatsScope scope) => scope == StatsScope.session ? _session : _lifetime;

  void recordDecision(String key, bool correct, String played) {
    _session.recordDecision(key, correct, played);
    _lifetime.recordDecision(key, correct, played);
    days?.recordDecision(correct: correct);
  }

  void recordHand(Hand h) {
    _session.recordHand(h);
    _lifetime.recordHand(h);
    days?.recordHand(h);
  }

  void recordInsurance({required bool won}) {
    _session.insuranceTaken++;
    _lifetime.insuranceTaken++;
    if (won) {
      _session.insuranceWon++;
      _lifetime.insuranceWon++;
    }
    days?.recordInsurance(won: won);
  }

  void recordMarker(int amount) {
    _session.recordMarker(amount);
    _lifetime.recordMarker(amount);
    days?.recordMarker(amount);
    _scheduleSave();
    notifyListeners();
  }

  /// Replaces the lifetime record from a restored save. The session starts over.
  void replaceLifetime(StatsData data) {
    _lifetime = data;
    _session = StatsData();
    flush();
    notifyListeners();
  }

  void recordRound({required int net, required int wagered, required int bankroll}) {
    _session.recordRound(roundNet: net, roundWagered: wagered, bankroll: bankroll);
    _lifetime.recordRound(roundNet: net, roundWagered: wagered, bankroll: bankroll);
    days?.recordRound(net: net, wagered: wagered);
    profile?.noteBankroll(bankroll);
    _scheduleSave();
    notifyListeners();
  }

  void resetSession() {
    _session = StatsData();
    notifyListeners();
  }

  /// Clears the lifetime record. The day-by-day calendar is a separate
  /// ledger and survives, unless [includeCalendar] says otherwise.
  void resetLifetime({bool includeCalendar = false}) {
    _lifetime = StatsData();
    _session = StatsData();
    _prefs.remove('stats');
    if (includeCalendar) days?.clear();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), flush);
  }

  void flush() {
    _saveTimer?.cancel();
    _prefs.setString('stats', jsonEncode(_lifetime.toJson()));
    days?.flush();
  }

  @override
  void dispose() {
    flush();
    _saveTimer?.cancel();
    super.dispose();
  }
}
