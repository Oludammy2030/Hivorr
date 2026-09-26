/// EP-03-06 seam reservation for EP-04 spatial & 3-party dispatch routing.
///
/// Per `ARCHITECTURE.md:71` the matching engine owns *spatial* and *logistics*
/// dispatch (multi-stop delivery hub `lib/systems/logistics_dispatch`). The
/// recommendation engine (`lib/engine/recommendation_engine`) owns marketplace
/// ranking. This stub documents the boundary so EP-03 does not bleed into
/// EP-04 and no parallel ranking system is created (`AGENT.md:7` Deterministic
/// Core remains `recommendation_engine` SQL).
///
/// No logic in EP-03 — only the seam. EP-04 will implement:
///   * rider proximity & 3-party broadcast (`distance`, `ETA`, `load balancing`)
///   * multi-stop delivery hub assignment
/// without reimplementing ranking. Ranking weights remain in
/// `public.platform_config` `service_ranking_weights` (EP-03-06 §0).
class MatchingEngineSeam {
  const MatchingEngineSeam._();

  /// Human-readable boundary note for code-review gate.
  static const String boundaryNote =
      'EP-04 spatial routing seam — no ranking logic here. '
      'Marketplace ranking lives in '
      'lib/engine/recommendation_engine/ranking_formula.dart '
      'and public.service_ranking_search (SECURITY INVOKER STABLE).';
}
