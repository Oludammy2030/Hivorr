# Hivorr — Flutter/Dart Premium UI Implementation & Beautification Rules

**Status:** Active — binding across the entire project (EP-01 → EP-08), alongside `VISUAL-IDENTITY.md`.
**Authority:** `VISUAL-IDENTITY.md` defines **what Hivorr looks like** (hexes, type scale, spacing, radius, elevation, motion values, role accents). This document defines **how Flutter/Dart implements it** (widgets, constraints, state, lists, animation, images, responsive, enforcement). If the two disagree on a *value*, `VISUAL-IDENTITY.md` wins. If they disagree on *how to write Dart*, this document wins.
**Scope:** `lib/` — `app/`, `shared/`, `systems/`, `workspace/`. Referenced by `AGENT.md` Rule 5.
**Reuse-first:** Every example maps to existing tokens. Do not invent `HivorrRadius.card` / `HivorrDimensions.buttonHeight`. Use:

```dart
context.colorScheme.*              // ColorScheme light/dark
context.textTheme.*                // Plus Jakarta Sans TextTheme — never fontFamily per-widget
context.appExtension.*             // AppThemeExtension: success/warning/info + radiusSm8/Xs12/Md16/Lg24 + spacing8
context.roleTheme.*                // RoleThemeExtension: clientPrimary/professionalPrimary/adminPrimary/adminAccent
HivorrSpacing.xs/sm/smMd/md/lg/xl/xxl  // 4/8/12/16/24/32/48
Breakpoints.tabletStart/desktopStart   // 600/1024 + tableCardFlip 720 (900 Admin-Users exception only)
HivorrMotion.short/medium/long     // 150/250/300ms + snackbar 4s + loader 1800ms
HivorrElevation.raised/overlay/floating
```

> How to use: read `VISUAL-IDENTITY.md` for values, then follow this file §§1–33 when writing Dart. No separate "make it beautiful" prompt is needed.

---

## PURPOSE

These rules govern **how Flutter/Dart code must be written and structured when implementing Hivorr's UI**. This is an implementation-quality standard. It does not replace `Virtual Identity.md` (`VISUAL-IDENTITY.md` defines what Hivorr should look and feel like; these rules define how Flutter/Dart implements that quality correctly, consistently, responsively, and efficiently).

---

## 1. USE FLUTTER'S STRENGTHS

Do not treat Flutter as HTML/CSS translated into Dart. Use widget composition, constraints-based layouts, `ThemeData`, `ColorScheme`, `TextTheme`, custom widgets, implicit/explicit animations, slivers, adaptive layouts, custom painting where justified, platform-aware behavior, efficient scrolling, composable state-driven UI. The implementation should feel **native to Flutter**, not like a web layout mechanically recreated in Dart.

Ban: `width: MediaQuery.of(context).size.width - 32`. Use `LayoutBuilder` + `ConstrainedBox` + `HivorrContentPane (720)` / list pane `(1120)` / auth split `(480)`.

Reference impls: `portfolio_grid.dart:42-60` (columns 1/2/3 + `tileWidth`), `discovery_results_view.dart:123-149` (`LayoutBuilder` → list/2-col/3-col), `auth_scaffold.dart:55-69`, `hivorr_content_pane.dart` (`Center+ConstrainedBox(720)`).

## 2. THEME EVERYTHING THAT SHOULD BE GLOBAL

Centralize colors, typography, buttons, inputs, cards, dialogs, navigation, chips, app bars, tabs, checkboxes, switches, progress indicators, surfaces in `lib/app/theme/`. Prefer `Theme.of(context)` and `context.*` extensions over arbitrary local values. No competing per-page themes (role accent only via `roleTheme`, never per-role `ThemeData`).

```dart
// GOOD
final colors = context.colorScheme;
final text = context.textTheme;
final ext = context.appExtension;
final role = context.roleTheme;
// BAD
Container(color: Color(0xFFF0F2F8)); // use colors.surface / scaffoldBackground
TextStyle(fontSize: 14.5);          // use text.bodyMedium
AppColors.textSecondary             // use colors.onSurfaceVariant (dark-safe)
```

Allowed exceptions (only these): `Colors.transparent` for unselected/overlay layers; white `onPrimary` on verified brand fills/gradient per `VISUAL-IDENTITY.md` §2.

## 3. USE DESIGN TOKENS, NOT MAGIC NUMBERS

```dart
// BAD
padding: EdgeInsets.only(left: 19, right: 23, top: 14, bottom: 11);
BorderRadius.circular(17)
// GOOD
padding: EdgeInsets.all(HivorrSpacing.md);
borderRadius: BorderRadius.circular(context.appExtension.radiusMd); // 16
```

Binding: spacing `≥6dp` MUST be `HivorrSpacing` (`≤4dp` text-stack micro-gaps exempt; raw `6/10/12/14/20/22/28` fail; `20` retired → `16`). Radius raw `10→8`, `14→12/16`, `20→16`; pills `StadiumBorder/999` only. Type: never `fontSize:`/`fontFamily:` per-widget — map to §6 scale (`11→labelSmall`, `12→bodySmall/labelMedium`, `14→bodyMedium/titleSmall/labelLarge`, `16→titleMedium/bodyLarge`, `22→titleLarge`, `24→headlineSmall`); `w800` banned in functional UI. Elevation/shadow/motion: `HivorrElevation.*`, `HivorrMotion.*` only.

## 4. PREFER CONSTRAINTS OVER HARD-CODED DIMENSIONS

Prefer `Expanded`, `Flexible`, `ConstrainedBox`, `FractionallySizedBox`, `LayoutBuilder`, `AspectRatio`, `Wrap`, `SliverGrid`, `CustomScrollView`. Fixed dims only where genuine (icon tile `40`, drag handle `40×4`, page dots, auth logo). Fix gradually: direct `MediaQuery.sizeOf` (`login:53`, `admin_review_queue:322`, `conversation:308`) → `context.breakpoint`/`LayoutBuilder`; `mainAxisExtent:268` text cards → `childAspectRatio`/auto-height (clips at 1.3×); `profile:1398 Positioned(left:48)` → relative/`Align`.

## 5. BUILD REUSABLE VISUAL COMPONENTS

Reuse-before-creation (binding): 1. `grep lib/shared/` + barrel `shared.dart`. 2. Reuse or extend canonical. 3. New private duplicate of a canonical fails DoD. 4. Genuinely reusable → promote to `lib/shared/` + barrel + document in `VISUAL-IDENTITY.md` §30. Canonical: `HivorrButton/Card/Chip/Badge/Avatar/Divider/TextField/FormField/ListTile/SectionHeader/Dialog/BottomSheet/DataTable/TableAction/HeroPanel/StatCard+Grid/StatBand/FeatureCard/CtaBand/FaqItem/PricingTier/StepCard/MiniBars/TopBar/Empty/Loading/Error/Success/Snackbar/Loader/ContentPane/ScreenScaffold/Breakpoints/MobileCompact`. Do not duplicate `_Composer`, `_ApplySheet/_QuoteSheet`, timelines, KYC cards, nav-rows. Do not over-componentize one-use fragments.

## 6. KEEP WIDGETS SMALL ENOUGH TO REASON ABOUT

Break complex screens into `DashboardHeader()`, `QuickActions()`, `RecentOrders()`, `RecommendedServices()` — never one giant `build()`. Giants to split opportunistically (no big-bang): `dashboard_overview:4397`, `opportunities:2980`, `profile:2951`, `finance_hubs:2105`, `hires:1648`, `admin_review_queue:1357`, `login:830`. Split by tab/section. Do not split trivial one-use fragments merely to look modular.

## 7. USE `const` AGGRESSIVELY WHERE APPROPRIATE

`const` ctors + `const EdgeInsets/SizedBox/BoxConstraints/Duration` wherever compile-time constant. `shared/` is exemplary — copy it. Enable `prefer_const_constructors`, `prefer_const_literals`, `prefer_const_declarations` in `analysis_options.yaml`. Do not force `const` where theme-dependent.

## 8. AVOID UNNECESSARY REBUILDS

Stack is `provider` only. `watch` in `build`, `read` in callbacks/`initState`. Never top-level `watch` a high-churn provider in a 2k-line screen (`dashboard_overview:196`, `finance_hubs:64`, `dashboard_shell:48`).

```dart
// BAD: onChanged: (_) => setState(() {}) // whole form per keystroke (register:126-228)
// GOOD: TextEditingController + ValueListenableBuilder / Selector / Consumer on the small subtree
```

`HivorrLoader`'s `AnimatedBuilder` must pass `child` + wrap in `RepaintBoundary`.

## 9. USE LAZY LISTS AND GRIDS

Paged/unbounded → `ListView.builder`, `GridView.builder`, `SliverList`, `SliverGrid`. Bounded small-N → `Wrap`/`Column`. Critical for Local Market, search, professional listings, messages, orders, admin tables, notifications. Exemplars: `conversation:206 builder`, `messages:350/625`, `opportunities:1679/1723/2243`, `discovery_results_view:128/138 + ValueKey(listing.id)`, `service_listing_media:252 + childAspectRatio:1`, `intro:94 PageView.builder`. Eager `Column+map` in overviews (`dashboard_overview:618/1469/3585`, `finance_hubs:618/1904`, `hires:650`) migrates when lists grow.

## 10. USE `CustomScrollView` AND SLIVERS WHEN THEY IMPROVE THE EXPERIENCE

Collapsing marketplace headers, sticky category controls, mixed product sections, large profile headers, dashboard sections, scrolling filters. Only exemplar: `contract_list_screen.dart:97`. Candidates: `dashboard_overview:132`, `finance_hubs:71`, `service_detail:189`, `job_detail:139`. Never for short static forms.

## 11. USE `AnimatedSwitcher`, `AnimatedContainer`, AND OTHER IMPLICIT ANIMATIONS INTENTIONALLY

Button loading swap, selected filters, expanding sections, card status changes, empty → populated, success feedback. Only exemplar: `intro_screen:173 AnimatedContainer 200ms` dots. Static swaps (`HivorrButton:100` loader, `dashboard_shell:134` bar hide, `super_admin_shell:101` collapse) → animate with `HivorrMotion.short/medium`. Animate continuity, never everything.

## 12. USE EXPLICIT ANIMATIONS FOR IMPORTANT EXPERIENCES

Hero transitions, shared transitions, onboarding (`PageView`), marketplace image transitions, interactive cards, meaningful dashboard motion. Only explicit today: `HivorrLoader` (`repeat/dispose/didUpdateWidget/shouldRepaint` — exemplary breathing, no spin). No `Hero` yet — add for `ServiceMediaCarousel` → detail when scheduled. Keep smooth, short, purposeful, interruptible, performant; durations from `HivorrMotion`.

## 13. AVOID EXPENSIVE VISUAL EFFECTS BY DEFAULT

No casual blur, large shadows, multi-opacity, clipping, custom paint, shaders, continuous animation. `0` `BackdropFilter/ShaderMask/saveLayer` in scope (keep). `withValues(alpha:)` ~57× is cheap (keep). Static `blurRadius 12/8` via `HivorrElevation` (good); per-screen duplicates in scroll path (`messages:854` bubbles) → drop or centralize. `ClipRRect` 9 hits, all single-level + `Stack/Image` (keep).

## 14. USE `RepaintBoundary` WHEN APPROPRIATE

`0` in `lib/` today. Candidates only (profile before adding): `HivorrLoader`, chat `_Bubble`, `DiscoveryServiceCard` grid tiles, shadowed cards, `MiniBars`. Do not blanket-wrap.

## 15. IMAGE HANDLING MUST BE PREMIUM

No `cached_network_image` dep today — all `Image.network` refetch on scroll. Mandate:

```dart
AspectRatio(aspectRatio: 16/9, child: Image.network(url,
  fit: BoxFit.cover,
  loadingBuilder: (_, c, p) => p == null ? c : _MediaPlaceholder(),
  errorBuilder: (_, __, ___) => _MediaPlaceholder(),
  gaplessPlayback: true, cacheWidth: 800, filterQuality: FilterQuality.medium))
```

Exemplar: `service_media_carousel` AspectRatio + loadingBuilder + errorBuilder + Stack badges (copy). Framework-first caching is binding: every `Image.network` sets `cacheWidth` (grid 600 / hero 1200 / document 1600 / thumb 2x), `filterQuality: medium`, `gaplessPlayback: true`, plus a placeholder `loadingBuilder` and fallback `errorBuilder`. `HivorrAvatar` still needs an `errorBuilder` when network avatars land. A `cached_network_image` dependency is deferred — revisit only with founder sign-off if scroll jank or refetch persists after these caps. Never layout-jump: always `AspectRatio`/`childAspectRatio`.

## 16. RESPONSIVE ARCHITECTURE

One adaptable architecture, not parallel UIs. Vary spacing/columns/nav/density/layout/controls by constraints via `LayoutBuilder` + `Breakpoints` + `MobileCompact` + `HivorrStatGrid`. Grid contract per `VISUAL-IDENTITY.md` §21a: `<600` stats 2 / content 1 / media 2 / tables→cards; `600-1023` stats 2-3 / content 2 / media 3 / table; `≥1024` stats 3-4 / content 3 / media 3 / table. `720` table→card flip (`900` Admin-Users exception with call-site comment). `auth ≥900` custom point migrates to `600/1024`.

## 17. ADAPT NAVIGATION PROPERLY

| Width | Dashboard | Admin | Public |
|---|---|---|---|
| `<600` | `AppBar` + `NavigationBar` primaries + `MoreSheet` + hide bar when `viewInsets>0` (no drawer) | `Drawer(280)` + `_AdminTopBar` | inline CTAs + `PopupMenu` |
| `600-1023` | rail/sidebar `264` + 2-col | collapsible `248` | inline links |
| `≥1024` | sidebar `264` + 3-col | sidebar `248` | inline links |

Fix: `HivorrResponsiveScaffold:280` generic → `sidebarWidth` param; tablet distinct 2-col, not stretched desktop; dashboard `AppBar(title: Text('Hivorr'))` → logo lockup; remove dead `openDrawer` calls in dashboard; chrome hit-area `≥48dp` (`super_admin_shell:240 _ChromeButton40×40` violates §13a).

## 18. USE SAFE AREAS CORRECTLY

`SafeArea` 62 hits (good). `MobileSafeBody(top:true,bottom:false)`, dashboard shell `top:true/bottom:false` + `NavigationBar` wrapped `SafeArea(bottom:true,minimum:4)`, conversation/messages composer `SafeArea(top:false,bottom:true)`. Never hide critical controls behind status/nav/notch/gesture. `HivorrBottomSheet:32 bottom: md + viewInsets.bottom + isScrollControlled:true` (copy).

## 19. KEYBOARD-AWARE UI

`viewInsets.bottom` hides dashboard bar (`dashboard_shell:134` — copy); sheets pad with `MediaQuery.viewInsetsOf(sheetCtx).bottom` (`opportunities:1046` — copy). Bug to fix: `job_detail:620` / `hire_detail:394` capture outer `context` → use builder `sheetCtx`. Forms: `SingleChildScrollView`, `textInputAction: next/done`, `FocusScope.nextFocus` traversal (add `focusNode` passthrough to `HivorrTextField`), never cover composer/send.

## 20. AVOID NESTED SCROLL VIEW PROBLEMS

No `shrinkWrap`/`NeverScrollableScrollPhysics` in `lib` (keep, except `tapTargetSize.shrinkWrap`). Correct: header `Column` + `Expanded(RefreshIndicator+ListView/GridView)` (`discovery_results_view:120`); `SingleChildScrollView+Column(min)` forms; cross-axis `SingleChildScrollView` + horizontal `PageView` (`service_detail:189` — safe). Verify before nesting: `opportunities:1679 ListView` vs `1295 sheet scroll`, `hires:291` vs `435 scroll`, `profile:2496 primary:false ListView` — if nested, prefer `CustomScrollView+Slivers`.

## 21. USE SEMANTIC WIDGET STRUCTURE

```text
Page
├── Header (HivorrDashboardTopBar / PublicSection)
├── Search (TaxonomySearchField)
├── Filters (Wrap HivorrChip + count)
├── Content (Section → Items: List/Grid/Table)
└── Actions (HivorrButton / TableAction)
```

No arbitrary nesting that happens to render. `shared/` + verification/marketplace wrap `Semantics(label/selected/toggled/enabled/button/textField)` + `tooltip` (copy); shells (`_NavItem/_ProNavRow/_MoreRow`, `Users` expand, bell count, avatar) lack it — add.

## 22. USE CLIPPING AND DECORATION INTENTIONALLY

Single-level `ClipRRect` + `Stack/Image` only (9 hits — keep). No `ClipRRect` per card/row. Decoration only for hierarchy/usability/trust/brand.

## 23. PREFER `DecoratedBox` / APPROPRIATE WIDGETS OVER EXCESSIVE CONTAINERS

`Container(` 100+ hits — replace color-only/padding-only cases:

```dart
// BAD
Container(height: 1, color: colors.outline) // → Divider / ColoredBox
Container(color: fill)                      // → ColoredBox
Container(padding: ...)                     // → Padding
Container(width:48,height:48,decoration:...)// → SizedBox + DecoratedBox
// GOOD (combined constraint+pad+deco): chat _Bubble, HivorrCard/Chip — keep Container
```

Copy: `dashboard_shell:66 DecoratedBox`, `:107 ColoredBox`, `hivorr_list_tile:29 Padding`, `hivorr_stat_card:135 SizedBox`.

## 24. USE THE RIGHT LAYOUT WIDGET

`Wrap` 95 hits for chips/grids (copy — avoids `Row` overflow at 320px); `Stack` 8 hits justified (`carousel badges`, `busy overlay`, `IndexedStack` onboarding); `GridView` only virtualized, else `Wrap+HivorrStatGrid` for variable heights. `profile:1414 Row[Spacer+Edit+Preview]` overflows at 320 → `Wrap`. Audit header `Row`s (`dashboard_overview:870/963/1124`, `finance_hubs:352/421`, `hires:766`) for missing `Expanded`.

## 25. AVOID `IntrinsicHeight` AND `IntrinsicWidth` UNNECESSARILY

2 hits, both justified — do not expand: `login:131 IntrinsicHeight` split card (could be `CrossAxisAlignment.stretch`, harmless desktop-only bounded), `contract_timeline:71` rail (canonical). Prefer constraint layouts.

## 26. USE `TextOverflow` AND CONSTRAINTS PROPERLY

100+ `maxLines+ellipsis` (copy: `admin_review_queue:712/792/1263`, `dashboard_cards:67`, `my_jobs:625`). Holes: `HivorrStatCard label/value/sub` no clamp (long sub wraps → ragged grid → add `sub maxLines:2 ellipsis`), `HivorrChip:71 Flexible(Text)` no `ellipsis`, `contract_timeline:99 label` no clamp. Marketplace names/locations/messages must never overflow/break layout/h-scroll.

## 27. DON'T USE SCREENSHOT-BASED UI HACKS

No `width-32` math found (good). Ban enormous `Positioned`, pixel offsets, fake spacers, invisible pushers. `service_media_carousel:122 top/left/sm` + `activities:245 top/right/sm` overlays OK (token offsets, `StackFit.expand`); `profile:1398/1534` avatar/badge pixels fragile → relative/`Align` + `Transform.translate`.

## 28. USE CUSTOM PAINTING ONLY WHEN JUSTIFIED

1 hit, exemplary: `hivorr_loader.dart:80/92` brand node-network breathing (relative offsets, correct `shouldRepaint`). Charts/decorative/progress/marketplace visuals only. Never for buttons/cards/layouts.

## 29. PLATFORM-AWARE POLISH

`LayoutBuilder/kIsWeb/EntryPlatform` + `SafeArea`/keyboard correct. Missing (add as needed, no Hivorr-theme conflict): `TargetPlatform/Cupertino` where idiomatic, `MouseRegion` + `WidgetStateProperty.hovered/focused` styling, keyboard shortcuts, `textScaler 1.3×` overflow harness. Never force platform behavior against unified Explore/Earn/Admin experience.

## 30. ERROR-FREE VISUAL STATES

Every reachable state intentional: `HivorrButton` default/pressed/disabled/loading covered; add hovered/focused `WidgetStateProperty`. `HivorrTextField` enabled/focused-2px/error covered; add hover/disabled-fill distinction. `HivorrChip` selected/splash covered; add hover/pressed/focus-ring + disabled. `HivorrCard` tap splash covered; add hover/selected/disabled where interactive. Lists: full-area `Empty/Loading/Error/Success + HivorrLoader + Snackbar 4s` (copy); add skeleton rows for tables/grids; inline field success where valuable. Status never color-alone (`HivorrBadge` + domain registries).

## 31. DON'T USE PLACEHOLDER UI IN PRODUCTION IMPLEMENTATION

No lorem in `lib/` (good). Honest placeholders with CTA required: `comingSoon` waitlist, media `errorBuilder` placeholders, env guards, initials fallback. Residual `MOCK`s must stay labeled + actionable or be removed: `client_overview_mock.dart`, `finance_hubs:202/696/1681`, `dashboard_overview:2638 TODO`. Dead-ends fail review.

## 32. DO NOT SACRIFICE ARCHITECTURE FOR VISUAL SPEED

Beautiful-but-fragile is unfinished. Ban duplicated components/styling, theme bypass, hardcoded colors, state-management bypass, isolated/page-specific tokens. `login _BrandPanel/_FormPanel` own deco/shadow/type → `HivorrCard/HeroPanel/ContentPane`; overviews' inline gradients → `HivorrHeroPanel/StatBand`; triplicated nav-rows → one shared row. Violations fail DoD per `VISUAL-IDENTITY.md` §28.

## 33. FINAL FLUTTER BEAUTIFICATION CHECK

**Visual:** polished? intentional spacing? clear hierarchy? balanced surfaces? type/icon aligned?
**Flutter:** sensible tree? constraints correct? no wasteful rebuilds? lazy lists? effects controlled? `const` where free?
**Responsive:** `320/360/600/1024/1920 × light/dark` deliberate? tablet distinct? table→card `720`? touch `≥48` / data `≥40`?
**Interaction:** smooth state change (`HivorrMotion`)? loading/error/keyboard/touch OK? semantics/live-region?
**Architecture:** shared reused? centralized styling? no magic? no duplicates?
**Performance:** smooth scroll? efficient images? performant animation? no `saveLayer`/jank?

> **Final rule:** Do not write Dart that merely produces a working screen. Write Dart that produces a maintainable, responsive, performant, polished visual system. Beautiful + clean architecture + constraints + reuse + efficient rendering + intentional motion + consistent styling. If generic-looking, unfinished. If beautiful-but-fragile, unfinished. Both required.

---

## Change process & enforcement

* Change a *value* → `VISUAL-IDENTITY.md` first (§29), then `lib/app/theme/*` + tests. Change *how* → this doc first, then `lib/shared/` + barrel + tests.
* CI (expand gradually): `trust_theme_token_scan` to all of `lib/` + scans for `BorderRadius.circular(8|10|12|20)`, `fontSize:`, `w800`, `MediaQuery.sizeOf` screen-math, raw `<600|900|1000|1100` breakpoints, `Color(0x`, `AppColors.` at call sites + `320/360/600/1024/1920 light/dark` harness + `1.3×` overflow gate.
* Adoption: doc + lint expansion now; code refactors incrementally per-feature. No full rewrite.
