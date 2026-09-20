import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/rules.dart';
import '../model/table_tier.dart';

/// Which table you are sitting at, the rules you set up on your own table,
/// and the trainer switches. Saved as soon as they change.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  String _tierId = kTiers.first.id;
  RuleSet _customRules = const RuleSet();
  int _customMin = 5;
  int _customMax = 500;
  bool _coach = true;
  bool _flagMistakes = true;
  bool _showCount = false;
  bool _haptics = true;
  bool _fastDeal = false;

  /// The table you are sitting at. The house-rules table is rebuilt from the
  /// limits you set for it rather than the constant in [kTiers].
  TableTier get tier => _tierId == 'custom'
      ? customTierWith(min: _customMin, max: _customMax)
      : tierById(_tierId);

  /// Stakes at your own table. Anything from [kMinStake] up.
  int get customMin => _customMin;
  int get customMax => _customMax;

  /// Your own table as it currently stands, whichever table you are sitting
  /// at. The tables list needs this to show your limits rather than the
  /// defaults baked into [kTiers].
  TableTier get customTier => customTierWith(min: _customMin, max: _customMax);

  /// The conditions actually in play: the table's, unless you are at your own.
  RuleSet get rules => tier.isCustom ? _customRules : tier.rules;

  /// Editable only at the house-rules table.
  RuleSet get customRules => _customRules;
  bool get canEditRules => tier.isCustom;

  /// Shows what basic strategy would play, before you act.
  bool get coach => _coach;

  /// Calls out a deviation from basic strategy after you act.
  bool get flagMistakes => _flagMistakes;

  /// Hi-Lo running and true count on the table.
  bool get showCount => _showCount;

  bool get haptics => _haptics;
  bool get fastDeal => _fastDeal;

  void _load() {
    final raw = _prefs.getString('rules');
    if (raw != null) {
      try {
        _customRules = RuleSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _customRules = const RuleSet();
      }
    }
    _tierId = _prefs.getString('tier') ?? kTiers.first.id;
    if (!kTiers.any((t) => t.id == _tierId)) _tierId = kTiers.first.id;
    _setLimits(_prefs.getInt('customMin') ?? 5, _prefs.getInt('customMax') ?? 500);
    _coach = _prefs.getBool('coach') ?? true;
    _flagMistakes = _prefs.getBool('flagMistakes') ?? true;
    _showCount = _prefs.getBool('showCount') ?? false;
    _haptics = _prefs.getBool('haptics') ?? true;
    _fastDeal = _prefs.getBool('fastDeal') ?? false;
  }

  void setTier(String id) {
    if (_tierId == id) return;
    _tierId = tierById(id).id;
    _prefs.setString('tier', _tierId);
    notifyListeners();
  }

  /// Sets the stakes at your own table. The two are clamped against each
  /// other, so a maximum can never end up under its own minimum.
  void setCustomLimits({int? min, int? max}) {
    final before = (_customMin, _customMax);
    _setLimits(min ?? _customMin, max ?? _customMax);
    if (before == (_customMin, _customMax)) return;
    _prefs
      ..setInt('customMin', _customMin)
      ..setInt('customMax', _customMax);
    notifyListeners();
  }

  void _setLimits(int min, int max) {
    _customMin = min.clamp(kMinStake, kMaxStake);
    _customMax = max.clamp(_customMin, kMaxStake);
  }

  /// Edits the house-rules table. Preset tables post their own conditions.
  void setRules(RuleSet r) {
    _customRules = r;
    _prefs.setString('rules', jsonEncode(r.toJson()));
    notifyListeners();
  }

  void setCoach(bool v) => _flag('coach', v, () => _coach = v);
  void setFlagMistakes(bool v) => _flag('flagMistakes', v, () => _flagMistakes = v);
  void setShowCount(bool v) => _flag('showCount', v, () => _showCount = v);
  void setHaptics(bool v) => _flag('haptics', v, () => _haptics = v);
  void setFastDeal(bool v) => _flag('fastDeal', v, () => _fastDeal = v);

  void _flag(String key, bool value, VoidCallback apply) {
    apply();
    _prefs.setBool(key, value);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'tier': _tierId,
        'rules': _customRules.toJson(),
        'customMin': _customMin,
        'customMax': _customMax,
        'coach': _coach,
        'flagMistakes': _flagMistakes,
        'showCount': _showCount,
        'haptics': _haptics,
        'fastDeal': _fastDeal,
      };

  /// Replaces everything from a restored save.
  void applyImported(Map<String, dynamic> j) {
    final tier = j['tier'];
    if (tier is String && kTiers.any((t) => t.id == tier)) _tierId = tier;
    final r = j['rules'];
    if (r is Map<String, dynamic>) _customRules = RuleSet.fromJson(r);
    _setLimits(
      (j['customMin'] as num?)?.toInt() ?? _customMin,
      (j['customMax'] as num?)?.toInt() ?? _customMax,
    );
    _coach = j['coach'] as bool? ?? _coach;
    _flagMistakes = j['flagMistakes'] as bool? ?? _flagMistakes;
    _showCount = j['showCount'] as bool? ?? _showCount;
    _haptics = j['haptics'] as bool? ?? _haptics;
    _fastDeal = j['fastDeal'] as bool? ?? _fastDeal;

    _prefs
      ..setString('tier', _tierId)
      ..setString('rules', jsonEncode(_customRules.toJson()))
      ..setInt('customMin', _customMin)
      ..setInt('customMax', _customMax)
      ..setBool('coach', _coach)
      ..setBool('flagMistakes', _flagMistakes)
      ..setBool('showCount', _showCount)
      ..setBool('haptics', _haptics)
      ..setBool('fastDeal', _fastDeal);
    notifyListeners();
  }
}
