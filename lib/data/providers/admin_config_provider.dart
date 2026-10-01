// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/database/storage_engine.dart';

/// Provider exposing staged platform-configuration state to the widget tree.
///
/// Mirrors the [LocaleProvider] persistence pattern: values live in Hive
/// through the injected [StorageEngine] (best-effort writes — a failed write
/// never blocks the in-memory update), keyed under a dedicated box.
///
/// Scope honesty: there is currently no platform-config backend RPC
/// (`platform_config` only carries ranking weights and is service-role
/// writable), so these values are staged on this device for admin review —
/// they are NOT enforced platform-wide until a config RPC lands. The Admin
/// Settings screen labels this explicitly instead of implying enforcement.
/// No duplicate storage: the shared [StorageEngine] instance is injected,
/// never constructed here.
class AdminConfigProvider extends ChangeNotifier {
  AdminConfigProvider({required StorageEngine storage}) : _storage = storage;

  final StorageEngine _storage;

  static const String box = 'admin_platform_config';
  static const String _key = 'platform_settings';

  /// Factory defaults matching the Admin Settings reference prototype.
  static const double defaultPlatformFeePercent = 3;
  static const int defaultEscrowReleaseDays = 3;
  static const double defaultMaxJobBudgetUsd = 50000;
  static const double defaultMinJobBudgetUsd = 10;

  double _platformFeePercent = defaultPlatformFeePercent;
  int _escrowReleaseDays = defaultEscrowReleaseDays;
  double _maxJobBudgetUsd = defaultMaxJobBudgetUsd;
  double _minJobBudgetUsd = defaultMinJobBudgetUsd;
  bool _registrationsEnabled = true;
  bool _jobPostingEnabled = true;
  bool _autoKycApprovalEnabled = false;
  bool _maintenanceModeEnabled = false;

  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  /// Platform fee percentage (0–100).
  double get platformFeePercent => _platformFeePercent;

  /// Escrow auto-release period in days (>= 1).
  int get escrowReleaseDays => _escrowReleaseDays;

  /// Maximum job budget in USD (>= 0).
  double get maxJobBudgetUsd => _maxJobBudgetUsd;

  /// Minimum job budget in USD (>= 0, <= max).
  double get minJobBudgetUsd => _minJobBudgetUsd;

  /// Whether new user registrations are open.
  bool get registrationsEnabled => _registrationsEnabled;

  /// Whether job posting is open.
  bool get jobPostingEnabled => _jobPostingEnabled;

  /// Whether KYC approvals are automatic.
  bool get autoKycApprovalEnabled => _autoKycApprovalEnabled;

  /// Whether the platform is in maintenance mode.
  bool get maintenanceModeEnabled => _maintenanceModeEnabled;

  /// Whether staged values have been read at least once.
  bool get isHydrated => _hydrated;

  /// Whether a save is in flight.
  bool get isSaving => _saving;

  /// The latest persistence error, if any.
  String? get lastError => _error;

  /// Reads staged values (or factory defaults when nothing is stored).
  /// Best-effort: storage failures keep defaults and never throw.
  Future<void> load() async {
    try {
      final Map<String, dynamic>? raw = await _storage.get(box, _key);
      if (raw != null) {
        _applyMap(raw);
      }
    } catch (_) {
      // Keep defaults on read failure.
    }
    _hydrated = true;
    notifyListeners();
  }

  /// Validates and persists a full fee-configuration set.
  ///
  /// Returns `null` on success, otherwise a user-facing validation message
  /// and nothing is written.
  Future<String?> saveConfig({
    required double platformFeePercent,
    required int escrowReleaseDays,
    required double maxJobBudgetUsd,
    required double minJobBudgetUsd,
  }) async {
    final String? invalid = validateConfig(
      platformFeePercent: platformFeePercent,
      escrowReleaseDays: escrowReleaseDays,
      maxJobBudgetUsd: maxJobBudgetUsd,
      minJobBudgetUsd: minJobBudgetUsd,
    );
    if (invalid != null) return invalid;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _platformFeePercent = platformFeePercent;
      _escrowReleaseDays = escrowReleaseDays;
      _maxJobBudgetUsd = maxJobBudgetUsd;
      _minJobBudgetUsd = minJobBudgetUsd;
      await _persist();
    } catch (_) {
      _error = 'Could not save configuration on this device.';
    } finally {
      _saving = false;
      notifyListeners();
    }
    return _error;
  }

  /// Flips a platform toggle and persists it. On storage failure the
  /// previous value is restored so the switch never lies.
  Future<String?> setToggle(AdminConfigToggle toggle, bool enabled) async {
    final bool previous = _valueOf(toggle);
    _setValue(toggle, enabled);
    _error = null;
    notifyListeners();
    try {
      await _persist();
    } catch (_) {
      _setValue(toggle, previous);
      _error = 'Could not save this setting on this device.';
      notifyListeners();
      return _error;
    }
    return null;
  }

  /// Pure validation for a fee-configuration set. Returns `null` when valid.
  static String? validateConfig({
    required double platformFeePercent,
    required int escrowReleaseDays,
    required double maxJobBudgetUsd,
    required double minJobBudgetUsd,
  }) {
    if (platformFeePercent.isNaN ||
        platformFeePercent < 0 ||
        platformFeePercent > 100) {
      return 'Platform fee must be between 0 and 100%.';
    }
    if (escrowReleaseDays < 1) {
      return 'Escrow release period must be at least 1 day.';
    }
    if (maxJobBudgetUsd.isNaN || maxJobBudgetUsd < 0) {
      return 'Max job budget must be zero or more.';
    }
    if (minJobBudgetUsd.isNaN || minJobBudgetUsd < 0) {
      return 'Min job budget must be zero or more.';
    }
    if (minJobBudgetUsd > maxJobBudgetUsd) {
      return 'Min job budget cannot exceed the max job budget.';
    }
    return null;
  }

  bool _valueOf(AdminConfigToggle toggle) => switch (toggle) {
        AdminConfigToggle.registrations => _registrationsEnabled,
        AdminConfigToggle.jobPosting => _jobPostingEnabled,
        AdminConfigToggle.autoKycApproval => _autoKycApprovalEnabled,
        AdminConfigToggle.maintenanceMode => _maintenanceModeEnabled,
      };

  void _setValue(AdminConfigToggle toggle, bool enabled) {
    switch (toggle) {
      case AdminConfigToggle.registrations:
        _registrationsEnabled = enabled;
      case AdminConfigToggle.jobPosting:
        _jobPostingEnabled = enabled;
      case AdminConfigToggle.autoKycApproval:
        _autoKycApprovalEnabled = enabled;
      case AdminConfigToggle.maintenanceMode:
        _maintenanceModeEnabled = enabled;
    }
  }

  void _applyMap(Map<String, dynamic> raw) {
    double asDouble(Object? value, double fallback) {
      if (value is num) return value.toDouble();
      return fallback;
    }

    int asInt(Object? value, int fallback) {
      if (value is num) return value.toInt();
      return fallback;
    }

    bool asBool(Object? value, bool fallback) {
      if (value is bool) return value;
      return fallback;
    }

    _platformFeePercent = asDouble(
        raw['platformFeePercent'], defaultPlatformFeePercent);
    _escrowReleaseDays =
        asInt(raw['escrowReleaseDays'], defaultEscrowReleaseDays);
    _maxJobBudgetUsd =
        asDouble(raw['maxJobBudgetUsd'], defaultMaxJobBudgetUsd);
    _minJobBudgetUsd =
        asDouble(raw['minJobBudgetUsd'], defaultMinJobBudgetUsd);
    _registrationsEnabled = asBool(raw['registrationsEnabled'], true);
    _jobPostingEnabled = asBool(raw['jobPostingEnabled'], true);
    _autoKycApprovalEnabled =
        asBool(raw['autoKycApprovalEnabled'], false);
    _maintenanceModeEnabled =
        asBool(raw['maintenanceModeEnabled'], false);
  }

  Future<void> _persist() => _storage.put(box, _key, <String, dynamic>{
        'platformFeePercent': _platformFeePercent,
        'escrowReleaseDays': _escrowReleaseDays,
        'maxJobBudgetUsd': _maxJobBudgetUsd,
        'minJobBudgetUsd': _minJobBudgetUsd,
        'registrationsEnabled': _registrationsEnabled,
        'jobPostingEnabled': _jobPostingEnabled,
        'autoKycApprovalEnabled': _autoKycApprovalEnabled,
        'maintenanceModeEnabled': _maintenanceModeEnabled,
      });
}

/// The four platform toggles from the Admin Settings reference.
enum AdminConfigToggle {
  registrations,
  jobPosting,
  autoKycApproval,
  maintenanceMode,
}
