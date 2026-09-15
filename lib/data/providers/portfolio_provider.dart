import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';

/// Load lifecycle of the portfolio provider (EP-02-19).
enum PortfolioLoadState {
  /// No load attempted yet.
  idle,

  /// A load is in flight.
  loading,

  /// The latest load succeeded.
  loaded,

  /// The latest load failed (see [PortfolioProvider.lastError]).
  error,
}

/// Provider exposing public professional profile state to the widget tree
/// (EP-02-19).
///
/// Depends only on the [PortfolioRepository] abstraction and surfaces a single
/// [ApiException] on failure. Holds one immutable [PublicProfile] — no per-frame
/// allocations; view-models derived once by the service layer.
class PortfolioProvider extends ChangeNotifier {
  /// Creates the provider bound to [repository].
  PortfolioProvider({required this.repository});

  /// The repository backing this provider.
  final PortfolioRepository repository;

  PortfolioLoadState _state = PortfolioLoadState.idle;
  PublicProfile? _profile;
  ApiException? _error;
  bool _disposed = false;

  /// Current lifecycle state.
  PortfolioLoadState get state => _state;

  /// Whether a load is in flight.
  bool get isLoading => _state == PortfolioLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _state == PortfolioLoadState.loaded;

  /// The loaded public profile, or `null` before a successful load.
  PublicProfile? get profile => _profile;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads the public profile for [entityId].
  ///
  /// Returns the profile on success; throws normalized [ApiException] for the
  /// screen to map (PLT004 → not-found, network → retry). `null` return means
  /// not-found (entity inactive or zero approved professions).
  Future<PublicProfile?> load(String entityId) async {
    if (isLoading) return _profile;
    _state = PortfolioLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _profile = await repository.getPublicProfile(entityId);
      _state = PortfolioLoadState.loaded;
      return _profile;
    } on ApiException catch (e) {
      _error = e;
      _state = PortfolioLoadState.error;
      if (!_disposed) notifyListeners();
      rethrow;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
