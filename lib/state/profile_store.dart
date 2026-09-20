import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only two things about a player that are not already implied by the
/// records: what they call themselves, and the high-water mark of their
/// bankroll.
///
/// Everything else on the profile — level, rank, badges — is computed from the
/// lifetime stats and the calendar by [Profile.of]. Storing a second copy of
/// any of it would only give it a way to drift.
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._prefs) {
    _name = _prefs.getString('playerName') ?? '';
    _peakBankroll = _prefs.getInt('peakBankroll') ?? 0;
  }

  static const int nameLimit = 18;

  final SharedPreferences _prefs;

  String _name = '';
  int _peakBankroll = 0;

  /// Empty means the player never set one; the UI shows a neutral default
  /// rather than pretending they chose it.
  String get name => _name;

  bool get hasName => _name.isNotEmpty;

  String get displayName => _name.isEmpty ? 'Player' : _name;

  /// The most chips ever held at once. Drives the table-reached badges, which
  /// should stay earned after a bad run gives the chips back.
  int get peakBankroll => _peakBankroll;

  void setName(String value) {
    final trimmed = value.trim();
    final capped =
        trimmed.length > nameLimit ? trimmed.substring(0, nameLimit) : trimmed;
    if (capped == _name) return;
    _name = capped;
    _prefs.setString('playerName', _name);
    notifyListeners();
  }

  /// Called once a round has settled. Only a new high does anything.
  void noteBankroll(int bankroll) {
    if (bankroll <= _peakBankroll) return;
    _peakBankroll = bankroll;
    _prefs.setInt('peakBankroll', _peakBankroll);
    notifyListeners();
  }

  void reset() {
    _name = '';
    _peakBankroll = 0;
    _prefs
      ..remove('playerName')
      ..remove('peakBankroll');
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'name': _name,
        'peak': _peakBankroll,
      };

  void applyImported(Map<String, dynamic> j) {
    final n = j['name'];
    if (n is String) setName(n);
    final peak = (j['peak'] as num?)?.toInt();
    if (peak != null && peak > 0) {
      // A restore replaces rather than merges, so this is set outright rather
      // than going through noteBankroll's high-water check.
      _peakBankroll = peak;
      _prefs.setInt('peakBankroll', _peakBankroll);
    }
    notifyListeners();
  }
}
