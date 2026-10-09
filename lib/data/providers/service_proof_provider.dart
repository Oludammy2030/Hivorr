// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

/// Load lifecycle of the listing-proof provider (EP-03-15).
enum ServiceProofLoadState {
  /// No load attempted yet.
  idle,

  /// A load or mutation round-trip is in flight.
  loading,

  /// The latest operation succeeded.
  loaded,

  /// The latest operation failed (see [ServiceProofProvider.lastError]).
  error,
}

/// Provider exposing one listing's linked proof-of-work to the widget tree
/// (EP-03-15).
///
/// Thin state over [ServiceListingService] proof methods: [load]/[refresh]
/// read via `service_listing_portfolio_list`, while [link]/[unlink] write via
/// the link RPCs and adopt the authoritative returned set (no optimistic
/// tiles — every mutation awaits the server, mirroring the scheduling
/// restraint for server-authoritative relationships). Server order is kept
/// verbatim and never re-sorted. Holds no bytes, only entities.
class ServiceProofProvider extends ChangeNotifier {
  /// Creates the provider bound to [service] for [listingId].
  ServiceProofProvider({
    required ServiceListingService service,
    required this.listingId,
  }) : _service = service;

  /// The service backing this provider.
  final ServiceListingService _service;

  /// The listing whose proof is managed.
  final String listingId;

  ServiceProofLoadState _state = ServiceProofLoadState.idle;
  List<LinkedPortfolioItem> _proofs = const <LinkedPortfolioItem>[];
  ApiException? _error;
  bool _disposed = false;

  /// Current lifecycle state.
  ServiceProofLoadState get state => _state;

  /// Whether an operation is in flight.
  bool get isLoading => _state == ServiceProofLoadState.loading;

  /// Whether the latest operation succeeded.
  bool get isLoaded => _state == ServiceProofLoadState.loaded;

  /// The linked proof in server order, or empty before a successful load.
  List<LinkedPortfolioItem> get proofs => _proofs;

  /// Whether the loaded set is empty.
  bool get isEmpty => isLoaded && _proofs.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads the linked proof for [listingId].
  Future<List<LinkedPortfolioItem>> load() async {
    if (isLoading) return _proofs;
    _transition(ServiceProofLoadState.loading);
    try {
      final List<LinkedPortfolioItem> proofs = await _service.fetchProofs(
        listingId,
      );
      _proofs = List<LinkedPortfolioItem>.unmodifiable(proofs);
      _transition(ServiceProofLoadState.loaded);
      return _proofs;
    } on ApiException catch (e) {
      _error = e;
      _transition(ServiceProofLoadState.error);
      rethrow;
    }
  }

  /// Re-reads the authoritative linked set (e.g. after a sheet save).
  Future<List<LinkedPortfolioItem>> refresh() => load();

  /// Replaces the linked set with [portfolioItemIds] in order and adopts the
  /// authoritative returned set.
  Future<List<LinkedPortfolioItem>> link(List<String> portfolioItemIds) async {
    if (isLoading) return _proofs;
    _transition(ServiceProofLoadState.loading);
    try {
      final List<LinkedPortfolioItem> proofs = await _service.linkProofs(
        listingId: listingId,
        portfolioItemIds: portfolioItemIds,
      );
      _proofs = List<LinkedPortfolioItem>.unmodifiable(proofs);
      _transition(ServiceProofLoadState.loaded);
      return _proofs;
    } on ApiException catch (e) {
      _error = e;
      _transition(ServiceProofLoadState.error);
      rethrow;
    }
  }

  /// Removes a single proof link and adopts the authoritative returned set.
  Future<List<LinkedPortfolioItem>> unlink(String portfolioItemId) async {
    if (isLoading) return _proofs;
    _transition(ServiceProofLoadState.loading);
    try {
      final List<LinkedPortfolioItem> proofs = await _service.unlinkProof(
        listingId: listingId,
        portfolioItemId: portfolioItemId,
      );
      _proofs = List<LinkedPortfolioItem>.unmodifiable(proofs);
      _transition(ServiceProofLoadState.loaded);
      return _proofs;
    } on ApiException catch (e) {
      _error = e;
      _transition(ServiceProofLoadState.error);
      rethrow;
    }
  }

  void _transition(ServiceProofLoadState next) {
    _state = next;
    if (next != ServiceProofLoadState.error) _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
