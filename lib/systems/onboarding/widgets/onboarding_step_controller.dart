import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Drives the shell-level primary CTA for the currently active onboarding step
/// (EP-02-18 FV-28).
///
/// The active step screen reports its validity + action through [configure];
/// the shell's bottom bar listens and renders the `Back` / `Continue`/`Submit`
/// [HivorrButton]s. Kept in the widget layer — no business logic lives here
/// (AGENT.md Rule 4).
class OnboardingStepController extends ChangeNotifier {
  String _primaryLabel = 'Continue';
  bool _canPrimary = false;
  bool _primaryLoading = false;
  VoidCallback? _onPrimary;
  bool _notifyScheduled = false;

  /// Primary CTA label (e.g. "Save & continue", "Upload & submit").
  String get primaryLabel => _primaryLabel;

  /// Whether the primary action is enabled.
  bool get canPrimary => _canPrimary;

  /// Whether the primary action is in flight (drives the spinner).
  bool get primaryLoading => _primaryLoading;

  /// The primary action to run when the CTA is tapped.
  VoidCallback? get onPrimary => _onPrimary;

  /// (Re)configures the primary CTA. Call from the active step's build.
  void configure({
    required String label,
    required bool canPrimary,
    VoidCallback? onPrimary,
    bool loading = false,
  }) {
    final bool changed = label != _primaryLabel ||
        canPrimary != _canPrimary ||
        loading != _primaryLoading ||
        onPrimary != _onPrimary;
    _primaryLabel = label;
    _canPrimary = canPrimary;
    _primaryLoading = loading;
    _onPrimary = onPrimary;
    if (changed) {
      _maybeNotify();
    }
  }

  /// Notifies listeners, deferring to the next frame when called during the
  /// build/layout/paint phase. Step screens call [configure] from `build`;
  /// notifying synchronously there would mark the shell's CTA listener dirty
  /// mid-build (an exception), so it is coalesced post-frame instead.
  void _maybeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) {
        return;
      }
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  /// Hides the primary CTA entirely for the current step.
  void hidePrimary() {
    configure(label: '', canPrimary: false, onPrimary: null);
  }
}