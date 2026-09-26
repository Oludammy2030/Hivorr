/// Typed, immutable value object for `platform_config.key='service_ranking_weights'`.
///
/// Mirrors the JSONB `value` validated by CHECKs in
/// `20260927090001_platform_config_and_ranking.sql:70-106` (range 0..1,
/// sum ~1.0, priors). Used by [RankingFormula] and serialized by the
/// `service_ranking_search` RPC (see migration §0 RANKING FORMULA v1).
///
/// No I/O, no framework dependency — pure Dart for client-side
/// explainability only. Ordering is **never** decided here; the server RPC
/// is the sole authority (`AGENT.md:7` Deterministic Core Supremacy).
class RankingWeights {
  const RankingWeights({
    required this.wVerify,
    required this.wRating,
    required this.wCompletion,
    required this.wRecency,
    required this.wRelevance,
    required this.wActivity,
    this.bayesianPriorCount = 5,
    this.bayesianPriorMean = 3.0,
    this.recencyHalfLifeDays = 30,
    this.activityHalfLifeDays = 14,
    this.tsRankNormalization = 32,
  });

  /// Weight for verification signal (KYC + trade bonus).
  final double wVerify;

  /// Weight for bayesian rating signal.
  final double wRating;

  /// Weight for completion-rate signal.
  final double wCompletion;

  /// Weight for recency-decay signal.
  final double wRecency;

  /// Weight for FTS relevance signal.
  final double wRelevance;

  /// Weight for login-recency signal.
  final double wActivity;

  /// Prior pseudo-count for Bayesian average (C).
  final double bayesianPriorCount;

  /// Prior mean for Bayesian average (m).
  final double bayesianPriorMean;

  /// Half-life in days for `published_at` decay.
  final double recencyHalfLifeDays;

  /// Half-life in days for `last_seen_at` decay.
  final double activityHalfLifeDays;

  /// `ts_rank` normalization flag (Postgres 0..32).
  final int tsRankNormalization;

  /// Documented v1 defaults seeded in `platform_config`
  /// (`20260927090001_platform_config_and_ranking.sql:159`).
  static const RankingWeights defaults = RankingWeights(
    wVerify: 0.28,
    wRating: 0.26,
    wCompletion: 0.16,
    wRecency: 0.12,
    wRelevance: 0.12,
    wActivity: 0.06,
    bayesianPriorCount: 5,
    bayesianPriorMean: 3.0,
    recencyHalfLifeDays: 30,
    activityHalfLifeDays: 14,
    tsRankNormalization: 32,
  );

  /// Parses the `platform_config.value` JSONB map.
  ///
  /// Tolerates missing keys by falling back to [defaults] (graceful bootstrap
  /// when seed row is absent — mirrors RPC `coalesce` in §2).
  factory RankingWeights.fromJson(Map<String, dynamic> json) {
    double d(String key, double fallback) {
      final Object? v = json[key];
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    int i(String key, int fallback) {
      final Object? v = json[key];
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return RankingWeights(
      wVerify: d('w_verify', defaults.wVerify),
      wRating: d('w_rating', defaults.wRating),
      wCompletion: d('w_completion', defaults.wCompletion),
      wRecency: d('w_recency', defaults.wRecency),
      wRelevance: d('w_relevance', defaults.wRelevance),
      wActivity: d('w_activity', defaults.wActivity),
      bayesianPriorCount: d('bayesian_prior_count', defaults.bayesianPriorCount),
      bayesianPriorMean: d('bayesian_prior_mean', defaults.bayesianPriorMean),
      recencyHalfLifeDays: d('recency_half_life_days', defaults.recencyHalfLifeDays),
      activityHalfLifeDays: d('activity_half_life_days', defaults.activityHalfLifeDays),
      tsRankNormalization: i('ts_rank_normalization', defaults.tsRankNormalization),
    );
  }

  /// Serializes to the `platform_config.value` JSONB shape (snake_case).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'w_verify': wVerify,
        'w_rating': wRating,
        'w_completion': wCompletion,
        'w_recency': wRecency,
        'w_relevance': wRelevance,
        'w_activity': wActivity,
        'bayesian_prior_count': bayesianPriorCount,
        'bayesian_prior_mean': bayesianPriorMean,
        'recency_half_life_days': recencyHalfLifeDays,
        'activity_half_life_days': activityHalfLifeDays,
        'ts_rank_normalization': tsRankNormalization,
      };

  /// Sum of the six primary weights; should be `~1.0` per CHECK `0.999..1.001`.
  double get weightSum =>
      wVerify + wRating + wCompletion + wRecency + wRelevance + wActivity;

  @override
  bool operator ==(Object other) =>
      other is RankingWeights &&
      (wVerify - other.wVerify).abs() < 1e-9 &&
      (wRating - other.wRating).abs() < 1e-9 &&
      (wCompletion - other.wCompletion).abs() < 1e-9 &&
      (wRecency - other.wRecency).abs() < 1e-9 &&
      (wRelevance - other.wRelevance).abs() < 1e-9 &&
      (wActivity - other.wActivity).abs() < 1e-9 &&
      (bayesianPriorCount - other.bayesianPriorCount).abs() < 1e-9 &&
      (bayesianPriorMean - other.bayesianPriorMean).abs() < 1e-9 &&
      recencyHalfLifeDays == other.recencyHalfLifeDays &&
      activityHalfLifeDays == other.activityHalfLifeDays &&
      tsRankNormalization == other.tsRankNormalization;

  @override
  int get hashCode => Object.hash(
        wVerify, wRating, wCompletion, wRecency, wRelevance, wActivity,
        bayesianPriorCount, bayesianPriorMean, recencyHalfLifeDays,
        activityHalfLifeDays, tsRankNormalization,
      );

  @override
  String toString() =>
      'RankingWeights(wVerify:$wVerify, wRating:$wRating, wCompletion:$wCompletion, wRecency:$wRecency, wRelevance:$wRelevance, wActivity:$wActivity)';
}
