import 'dart:math' as math;

import 'package:hivorr/engine/recommendation_engine/ranking_weights.dart';

/// Pure-Dart mirror of the SQL scoring in
/// `supabase/migrations/20260927090001_platform_config_and_ranking.sql:498-565`
/// (RANKING FORMULA v1).
///
/// **Never decides ordering.** The server RPC `service_ranking_search` is the
/// sole authority (`AGENT.md:7`, `ARCHITECTURE.md:158`). This class is
/// display-only for offline explainability (e.g., `HivorrChip` tooltip
/// `Verification 0.28×0.66=0.18`) and for `1e-9` parity tests against the
/// SQL `score`.
///
/// No I/O, no `DateTime.now()` inside `compute`/`explain` beyond the
/// caller-supplied `now` (determinism). No `Random`.
class RankingFormula {
  const RankingFormula._();

  /// Computes a single listing's `score` given pre-derived signals.
  ///
  /// Mirrors SQL:
  /// ```
  /// score = round((
  ///   w_verify*(kyc_weight+verify_bonus)
  ///   + w_rating*(least(bayesian_raw,5)/5)
  ///   + w_completion*least(completion_rate,1)
  ///   + w_recency*least(recency_decay,1)
  ///   + w_relevance*least(ts_rank,1)
  ///   + w_activity*least(activity_decay,1)
  /// )::numeric,6)
  /// ```
  ///
  /// Callers supply each signal already in `0..1` except `bayesianRaw` `0..5`
  /// (which is scaled `/5` here) and `tsRank` (capped). This matches the RPC
  /// lateral CTEs where raw signals are normalized before weighting.
  static double compute({
    required RankingWeights weights,
    required double kycTierWeight, // 0..1 (tier_3=1.0 tier_2=0.66 tier_1=0.33 else 0)
    required bool isTradeVerified,
    required double bayesianRaw, // 0..5 (prior blended); scaled /5
    required double completionRate, // 0..1 per professional
    required double recencyDecay, // 0..1 exp(-ln2*age/halfLife)
    required double tsRank, // 0..1 capped
    required double activityDecay, // 0..1
  }) {
    final double verify = (kycTierWeight.clamp(0.0, 1.0) +
            (isTradeVerified ? 0.15 : 0.0))
        .clamp(0.0, 1.15);
    final double bayesianNorm = (bayesianRaw.clamp(0.0, 5.0) / 5.0);
    final double completion = completionRate.clamp(0.0, 1.0);
    final double recency = recencyDecay.clamp(0.0, 1.0);
    final double relevance = tsRank.clamp(0.0, 1.0);
    final double activity = activityDecay.clamp(0.0, 1.0);
    final double raw = weights.wVerify * verify +
        weights.wRating * bayesianNorm +
        weights.wCompletion * completion +
        weights.wRecency * recency +
        weights.wRelevance * relevance +
        weights.wActivity * activity;
    // SQL round(::numeric,6)
    return double.parse(raw.toStringAsFixed(6));
  }

  /// Returns a per-signal breakdown including the weighted contribution and total.
  ///
  /// Keys: `kyc_weight`, `verify_bonus`, `verify_contrib`, `bayesian_raw`,
  /// `bayesian_norm`, `rating_contrib`, `completion_rate`, `completion_contrib`,
  /// `recency_decay`, `recency_contrib`, `ts_rank`, `relevance_contrib`,
  /// `activity_decay`, `activity_contrib`, `total`.
  static Map<String, double> explain({
    required RankingWeights weights,
    required double kycTierWeight,
    required bool isTradeVerified,
    required double bayesianRaw,
    required double completionRate,
    required double recencyDecay,
    required double tsRank,
    required double activityDecay,
  }) {
    final double verifyWeight = kycTierWeight.clamp(0.0, 1.0);
    final double bonus = isTradeVerified ? 0.15 : 0.0;
    final double verify = (verifyWeight + bonus).clamp(0.0, 1.15);
    final double bayesianNorm = (bayesianRaw.clamp(0.0, 5.0) / 5.0);
    final double comp = completionRate.clamp(0.0, 1.0);
    final double rec = recencyDecay.clamp(0.0, 1.0);
    final double rel = tsRank.clamp(0.0, 1.0);
    final double act = activityDecay.clamp(0.0, 1.0);
    final double verifyContrib = weights.wVerify * verify;
    final double ratingContrib = weights.wRating * bayesianNorm;
    final double completionContrib = weights.wCompletion * comp;
    final double recencyContrib = weights.wRecency * rec;
    final double relevanceContrib = weights.wRelevance * rel;
    final double activityContrib = weights.wActivity * act;
    final double total = double.parse(
      (verifyContrib +
              ratingContrib +
              completionContrib +
              recencyContrib +
              relevanceContrib +
              activityContrib)
          .toStringAsFixed(6),
    );
    return <String, double>{
      'kyc_weight': verifyWeight,
      'verify_bonus': bonus,
      'verify_contrib': double.parse(verifyContrib.toStringAsFixed(6)),
      'bayesian_raw': bayesianRaw.clamp(0.0, 5.0),
      'bayesian_norm': double.parse(bayesianNorm.toStringAsFixed(6)),
      'rating_contrib': double.parse(ratingContrib.toStringAsFixed(6)),
      'completion_rate': comp,
      'completion_contrib': double.parse(completionContrib.toStringAsFixed(6)),
      'recency_decay': rec,
      'recency_contrib': double.parse(recencyContrib.toStringAsFixed(6)),
      'ts_rank': rel,
      'relevance_contrib': double.parse(relevanceContrib.toStringAsFixed(6)),
      'activity_decay': act,
      'activity_contrib': double.parse(activityContrib.toStringAsFixed(6)),
      'total': total,
    };
  }

  // ── Signal helpers matching SQL lateral expressions ─────────────────────

  /// Bayesian average: `(C*m + avg* n)/(C+n)` or `m` when `n==0`.
  static double bayesianAvg({
    required double priorCount, // C
    required double priorMean, // m
    required double avgRating, // 0..5
    required int reviewCount, // n
  }) {
    if (reviewCount <= 0) return priorMean.clamp(0.0, 5.0);
    final double avg = avgRating.clamp(0.0, 5.0);
    return ((priorCount * priorMean + avg * reviewCount) /
            (priorCount + reviewCount))
        .clamp(0.0, 5.0);
  }

  /// Recency decay: `exp(-ln2*ageDays/halfLife)`; `ageDays>=0`.
  ///
  /// Mirrors `exp(-ln(2)*extract(epoch FROM now()-published_at)/86400/half_life)`.
  static double recencyDecay({
    required DateTime publishedAt,
    required DateTime now,
    required double halfLifeDays,
  }) {
    final double ageDays =
        now.difference(publishedAt).inSeconds / 86400.0;
    if (ageDays <= 0) return 1.0;
    return math.exp(-math.log(2) * ageDays / halfLifeDays).clamp(0.0, 1.0);
  }

  /// Convenience overload accepting an explicit `ageDays` (tests).
  static double recencyDecayFromAge(
    double ageDays,
    double halfLifeDays,
  ) =>
      ageDays <= 0
          ? 1.0
          : math.exp(-math.log(2) * ageDays / halfLifeDays).clamp(0.0, 1.0);

  /// Activity decay over `lastSeenAt` (or `createdAt` fallback).
  static double activityDecay({
    required DateTime lastSeenAt,
    required DateTime now,
    required double halfLifeDays,
  }) {
    final double ageDays = now.difference(lastSeenAt).inSeconds / 86400.0;
    if (ageDays <= 0) return 1.0;
    return math.exp(-ageDays / halfLifeDays).clamp(0.0, 1.0);
  }

  static double activityDecayFromAge(double ageDays, double halfLifeDays) =>
      ageDays <= 0
          ? 1.0
          : math.exp(-ageDays / halfLifeDays).clamp(0.0, 1.0);

  /// KYC tier weight mapping `tier_code` → `0..1`.
  static double kycTierWeight(String tierCode, {String tierStatus = 'active'}) {
    if (tierStatus != 'active') return 0.0;
    switch (tierCode) {
      case 'tier_3':
        return 1.0;
      case 'tier_2':
        return 0.66;
      case 'tier_1':
        return 0.33;
      default:
        return 0.0;
    }
  }
}
