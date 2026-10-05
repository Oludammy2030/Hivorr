/// Activity catalogue for the unified-account launcher (Explore / Earn).
///
/// Activities are **intent entry points, not permissions**: tapping a card
/// routes into the matching live experience or starts the matching onboarding
/// flow. Server RPCs + RLS remain authoritative for what the entity may
/// actually write (AGENT.md Rule 4).
///
/// One Hivorr account ([entities.id]) holds one switchable focus at a time
/// (hire | offer) and can change it any time — never a new account, and
/// never a combined identity.
library;

import 'package:flutter/material.dart';

/// Which shelf an activity belongs to on the launcher.
enum HivorrActivitySection {
  /// Things a user can explore, discover, buy, or use.
  explore('Explore with Hivorr'),

  /// Ways a user can participate to generate income.
  earn('Earn with Hivorr');

  const HivorrActivitySection(this.title);

  /// Section header label.
  final String title;
}

/// A single launcher activity (Explore or Earn card).
enum HivorrActivity {
  /// Shop goods & local stores. No goods backend exists yet
  /// (`/store/:storeId` is an honest placeholder) — card is waitlist-only.
  buy(
    section: HivorrActivitySection.explore,
    title: 'I Want to Buy',
    subtitle: 'Shop goods and local stores near you.',
    icon: Icons.shopping_bag_outlined,
    isLive: false,
    comingSoonLabel: 'Coming soon',
  ),

  /// Post a job and hire a verified professional (live: jobs → hires →
  /// contracts → escrow). Consumer capability; no extra wizard.
  hire(
    section: HivorrActivitySection.explore,
    title: 'I Want to Hire',
    subtitle: 'Post a job and hire a verified professional.',
    icon: Icons.search_rounded,
    isLive: true,
  ),

  /// Browse verified professionals and service listings (live, public-capable:
  /// `/services`, `/services/search`). No gate.
  exploreServices(
    section: HivorrActivitySection.explore,
    title: 'Explore Services',
    subtitle: 'Browse verified pros and what they offer.',
    icon: Icons.compass_calibration_outlined,
    isLive: true,
  ),

  /// Open a storefront and sell goods. No seller backend exists yet
  /// (no stores/products/orders tables) — card is waitlist-only.
  sell(
    section: HivorrActivitySection.earn,
    title: 'I Want to Sell',
    subtitle: 'Open a storefront and sell to nearby buyers.',
    icon: Icons.storefront_outlined,
    isLive: false,
    comingSoonLabel: 'Coming soon',
  ),

  /// Bind a profession, verify, list services and win work (live:
  /// industry → profession → identity → trade proof → listings →
  /// opportunities → earnings). Professional capability; full wizard.
  offerServices(
    section: HivorrActivitySection.earn,
    title: 'I Want to Offer My Services',
    subtitle: 'Verify your trade and win work as a professional.',
    icon: Icons.work_outline,
    isLive: true,
  ),

  /// Deliver and earn via hyper-local logistics. Only taxonomy seeds exist
  /// today (delivery-rider / logistics-coordinator professions); no dispatch,
  /// tracking, or proof-of-delivery backend — card is waitlist-only.
  logistics(
    section: HivorrActivitySection.earn,
    title: 'I Want to Provide Logistics',
    subtitle: 'Deliver orders and earn for moving the city.',
    icon: Icons.delivery_dining_outlined,
    isLive: false,
    comingSoonLabel: 'Coming soon',
  );

  const HivorrActivity({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLive,
    this.comingSoonLabel,
  });

  /// Explore vs Earn shelf.
  final HivorrActivitySection section;

  /// Card title (verb-first so first-time users understand the action).
  final String title;

  /// One-line supporting copy.
  final String subtitle;

  /// Card icon tile.
  final IconData icon;

  /// Whether the destination experience is live today. `false` renders an
  /// honest "coming soon" state that never implies a backend exists.
  final bool isLive;

  /// Badge text for not-live cards.
  final String? comingSoonLabel;

  /// Live explore activities in launcher order.
  static List<HivorrActivity> get explore =>
      HivorrActivity.values
          .where(
            (HivorrActivity activity) =>
                activity.section == HivorrActivitySection.explore,
          )
          .toList(growable: false);

  /// Live + soon earn activities in launcher order.
  static List<HivorrActivity> get earn =>
      HivorrActivity.values
          .where(
            (HivorrActivity activity) =>
                activity.section == HivorrActivitySection.earn,
          )
          .toList(growable: false);
}
