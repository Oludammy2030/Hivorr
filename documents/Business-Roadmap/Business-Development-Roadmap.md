# Hivorr Business Development Roadmap

| Field | Value |
| --- | --- |
| **Document** | `documents/Business-Roadmap/Business-Development-Roadmap.md` |
| **Version** | 2.6 |
| **Date** | 3 November 2026 |
| **Status** | **Proposed — requires founder approval.** Not yet a committed plan. |
| **Supersedes** | Version 1.0, "Hivorr Business Development Roadmap" (previous product direction) |
| **Owner** | Founder (AfriNova Digital Limited) |
| **Scope** | Business strategy, commercial model, market entry, growth, partnerships, organisation |
| **Out of scope** | Architecture, engineering standards, schema, implementation, UI |

> **This is a business document.** It does not describe how anything is built, and it is not an input
> to engineering planning. Where a commercial idea depends on a capability that does not exist yet,
> the dependency is named rather than assumed.

## Label key

| Label | Meaning |
| --- | --- |
| **[APPROVED]** | Established by an approved document. Cite it; do not re-decide it. |
| **[COMMITTED]** | A strategic direction already recorded and treated as settled. |
| **[PROPOSED]** | This roadmap's recommendation. Not approved. |
| **[FOUNDER]** | Requires an explicit founder decision before anyone acts on it. |
| **[FUTURE]** | Long-term option. Not in current scope. |
| **[OPEN]** | Undecided in the approved documents. Blocks dependent work. |
| **[VERIFY]** | An assumption that needs research before it is trusted. |
| **[ASSUMPTION]** | Stated so it can be challenged, not because it is proven. |

---

## 1. Purpose and scope

This roadmap sets out how Hivorr becomes a commercially viable business: who it serves, what it
charges for, where it launches, how it builds liquidity, what it partners for, how the organisation
grows, and what must be true at each stage before the next stage is attempted.

It is deliberately separate from three other kinds of document:

| Question | Answered by |
| --- | --- |
| What is Hivorr, and what does it stand for? | `VISION.md` |
| Who may do what, and under which verification? | `Unified-Account-and-Activity-Permission-Matrix.md` |
| How is the system built and operated? | `ARCHITECTURE.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` |
| **How does Hivorr make money and grow?** | **This document** |

**What this document does not do.** It does not set prices, commissions, escrow periods or dispute
rules as decided facts, because those are open founder decisions. It does not name partners as if
they had agreed to anything. It does not contain revenue forecasts, because the inputs needed to
produce one honestly do not exist yet. Where a number is required, the document states the number
and the method needed to obtain it.

---

## 2. What changed from version 1.0

Version 1.0 was written against the previous product direction. It contained useful strategic
thinking, but it also made claims that are no longer true, treated unapproved ideas as settled, and
confused a product sequence with a business sequence. The review below is the audit trail.

### 2.1 Retained

- **Compound ecosystem thesis.** One acquired user, many roles, compounding value. This remains the
  central strategic bet, and the roadmap now states how it will be tested rather than asserted.
- **Supply-first, density-first market entry.** Seeding verified supply before demand, and
  concentrating geographically before expanding, are both correct for this business.
- **Trust as the competitive moat.** Verification lanes, escrow, name-matched deposits, bound payout
  accounts, structured disputes. These are the approved product rules and they are genuinely hard
  to copy.
- **Provider-agnostic financial principles.** Owning Hivorr's financial concepts while depending on
  regulated third parties is the right posture, and it matches the approved architecture.
- **Partnership categories.** Payments, communications, maps, professional bodies, logistics
  networks, regulators, cloud, AI providers.
- **The phase gate logic.** "Each stage earns the right to attempt the next" is sound.

### 2.2 Corrected

- **The third Explore activity.** Version 1.0 said "buy, hire, discover". `discover` is not an
  activity; it is the browse step inside Hire. The six activities are buy, hire, **errand**, sell,
  offer services, provide logistics.
- **Status.** Version 1.0 was labelled an approved strategic reference and a primary input to
  engineering planning. It was neither. This version is proposed, and it is not an engineering input.
- **Funds custody.** Version 1.0 described escrow, multi-currency accounts and stablecoins as
  strategic direction. Whether Hivorr holds funds at all, and under what licence, is an open founder
  decision. Everything financial in this version is conditional on that decision.
- **Named financial candidates.** Version 1.0 named Thunes as the primary international
  infrastructure candidate. That was a vendor hypothesis, not a business decision. This version
  keeps the selection principles and removes the presumption.
- **AI as a retention pillar.** Version 1.0 relied on AI personalisation for retention. AI launch
  scope is open. Retention must work without AI.

### 2.3 Removed

- **The seven-phase product sequence as a business plan.** Version 1.0 sequenced business phases by
  product surface (services → commerce → logistics → AI → ecosystem → global). That is a delivery
  order, not a commercial plan, and it conflicts with the current direction of six activities in one
  ecosystem. Business phases are now defined by market maturity and liquidity, not by which screen
  exists.
- **Claims of category creation and "operating system for modern human existence".** Aspirational,
  unmeasurable, and it conflicts with the positioning question that remains open. Removed from the
  active strategy; the ambition is preserved in plain language instead.
- **The "no competitor can replicate this" framing.** Structurally overconfident. It ignores that
  competitors can bundle, and that Hivorr's own breadth is a cost as well as a moat.

### 2.4 Added

- A Nigeria market assessment with sources and explicit uncertainty.
- A competitive map, including the companies most likely to compress Hivorr's margins.
- Segment and jobs-to-be-done definitions per activity.
- A revenue architecture that separates what is approved, what is proposed and what is blocked.
- A pricing framework, including affordability constraints in an inflationary market.
- Liquidity models per activity, because "marketplace" is six different cold-start problems.
- Unit economics definitions and the data needed to populate them.
- An organisational plan that grows in steps rather than departments.
- A risk register with owners and mitigations.
- A consolidated decision register of everything that needs founder sign-off.

---

## 3. Strategic foundation

### 3.1 Identity

**[APPROVED]** Hivorr is an AI-assisted platform operated by AfriNova Digital Limited, built around
one unified account that activates multiple activities.

**[COMMITTED]** Six initial activities, in two umbrellas:

| Umbrella | Activity | Dashboard |
| --- | --- | --- |
| Explore | I want to buy | Local Market |
| Explore | I want to hire | Client |
| Explore | Send an errand | Errand requester |
| Earn | I want to sell | Seller |
| Earn | I want to offer my services | Professional |
| Earn | I want to provide logistics | Logistics provider |

**[APPROVED]** Activities are capabilities, not account types. There is no "Both". Admin and Super
Admin are privileged roles, never selectable at registration.

### 3.2 The strategic bet, stated testably

The business case is not "six products". It is one claim:

> A person who transacts in two or more activities on Hivorr is worth materially more, and is
> materially harder to lose, than a person who uses one.

If that is true, acquisition cost is amortised across roles, retention improves with each activation,
and the platform compounds. If it is false, Hivorr is six sub-scale verticals sharing a login, and it
will lose to focused competitors in every one of them.

**[PROPOSED]** This claim is treated as the primary hypothesis of the business. It is measured from
the first cohort, using the cross-role activation rate (BD-K05). A roadmap that cannot show
multi-activity behaviour emerging is not working, regardless of transaction volume.

This is the single most important change from version 1.0, which assumed the thesis instead of
testing it.

### 3.3 Positioning

**[OPEN]** `VISION.md` §10 records the positioning question: is Hivorr "Africa's workforce
marketplace" or a much broader operating layer with Africa as the first market?

This matters commercially more than any other open question, because it determines:

- what the brand promises in the first year;
- which competitors are considered relevant;
- how much the product must prove before launch;
- what investors are told the company is.

**[PROPOSED] Working position for launch, pending the founder's decision:**

> Hivorr is the trusted way to get work done and things moved in Nigeria — hire verified
> professionals, buy from local sellers, and send errands — with one account that also lets you earn.

This is deliberately narrower than the long-term ambition and deliberately broader than "freelance
marketplace". It gives sales, marketing and partnerships one sentence to work from, and it does not
foreclose the larger vision. It is a working position, not an approved one.

### 3.4 Long-term ambition

**[COMMITTED]** Nigeria first, then Africa, then selected international markets.

**[PROPOSED]** Africa expansion is sequenced by payment-rail maturity and diaspora density, not by
GDP. A market where Hivorr cannot collect and pay out reliably is not a market, regardless of its
size.

---

## 4. Market analysis: Nigeria

### 4.1 Why Nigeria first

**[COMMITTED]** Nigeria is the initial market.

The commercial reasons are structural, not patriotic:

- **Scale of informality.** Most service work, trade and delivery already happens outside formal
  marketplaces. The opportunity is to formalise trust, not to create demand.
- **Mobile-first access.** Digital reach is broad enough to acquire users without physical branches,
  which keeps early distribution cost low.
- **Payment rails exist.** Instant bank transfers, card processing and mobile money are mature
  enough for marketplace settlement, which is the hard prerequisite for escrow.
- **Density.** Lagos alone contains enough overlapping demand and supply to reach liquidity in
  several activities without leaving one metropolitan area.

### 4.2 Market indicators

**[VERIFY]** Every figure below is a directional indicator, not a forecast input. Sources disagree
because they measure different things. All must be re-checked against primary sources (NCC, NBS,
CBN, NDPC) before any of them appears in an investor document or a target.

| Indicator | Reported value | Source and date | Confidence |
| --- | --- | --- | --- |
| Internet users | ~107 million, 45.4% penetration | DataReportal, Digital 2025: Nigeria (Jan 2025) | Medium — modelled |
| Active internet subscriptions | ~141 million | NCC industry data, reported June 2025 | High — operator-reported |
| Broadband penetration | Above 50% | NCC, reported November 2025 | Medium — definition varies |
| Gig workers | ~3 million, sector valued ~USD 5.2 billion | Bolt/Ipsos gig economy report, reported April 2026 | Low–medium — commissioned study |
| E-commerce market size | ~USD 9–15 billion depending on definition | Mordor Intelligence; Verified Market Research; range across 2024–2026 estimates | Low — definitions differ sharply |
| Modern e-commerce sales | ~NGN 492 billion across Jumia and Konga, +29% year on year | Reported 2025 industry analysis | Medium |
| Headline inflation | ~15% (2026, rebased CPI), down from ~33% in 2024 | NBS CPI; World Bank Nigeria monitoring | High — official series |
| Data protection regime | NDPA 2023 in force; registration and filing regime active | NDPC, GAID 2025 | High |

**What these numbers do and do not tell us.** They confirm that digital distribution is viable and
that payment infrastructure exists. They do **not** establish willingness to pay a platform fee, nor
the size of the addressable service market. The gap between large e-commerce projections and the
roughly NGN 492 billion actually transacted by the two largest modern players is the most important
signal on this page: **formal online commerce in Nigeria is still small relative to the informal
market, and projections should be treated with suspicion.**

### 4.3 Structural conditions that shape the model

| Condition | Commercial consequence |
| --- | --- |
| High inflation, recently easing but still elevated | Absolute fees must stay small. Percentage fees are more defensible than fixed fees. Price changes must be rare and well communicated. |
| Cash and transfer habits | Card-only checkout will lose transactions. Payment method coverage is a growth lever, not a technical detail. |
| Low trust in online counterparties | Verification, escrow and reviews are the product, not add-ons. |
| Verification is manual and slow | Reviewer capacity is a growth ceiling. Plan it like a sales capacity problem. |
| Informal competitors are free | Hivorr must be better, not merely digital. Convenience and protection justify a fee; "being an app" does not. |
| Delivery economics are brutal at low density | Commerce and errand growth must be geographically concentrated, or every order loses money. |

### 4.4 Regulatory context

**[VERIFY]** This section identifies obligations to plan around. It is not legal advice, and each
item needs confirmation from Nigerian counsel before launch.

| Area | Regulator | What it means commercially |
| --- | --- | --- |
| Data protection | Nigeria Data Protection Commission (NDPA 2023, GAID 2025) | Registration as a data controller of major importance is likely. Breach notification within 72 hours. Filing fees are tiered by data volume. Privacy is a cost line and a trust asset. |
| Payments and funds | Central Bank of Nigeria | Collection, holding and payout of customer funds is regulated. Licence category, capital and escrow requirements depend on the model chosen. **This is the open funds-custody decision (BD-D01).** |
| Consumer protection | Federal Competition and Consumer Protection Commission | Refund, dispute and misleading-claim exposure. Terms of service and refund policy must exist before launch, not after. |
| Virtual assets | Securities and Exchange Commission (ISA 2025) | Any stablecoin or digital-asset rail adds a licensing burden. Not pursued. |
| Employment and platform work | Federal and state labour rules | Classification of providers as independent contractors must be documented. |
| State and local operations | Lagos State and local government | Transport, levies and operating permits for logistics activity. |

**Commercial implication.** The funds-custody decision gates the entire escrow proposition, and
therefore the trust differentiator, and therefore launch. It is the highest-priority legal decision
in the business.

---

## 5. Competitive landscape

**[PROPOSED]** Hivorr does not compete with one company. It competes with a different incumbent in
each activity, plus one structural alternative: informality.

### 5.1 Direct and adjacent competitors

| Activity | Who already owns the customer | Their strength | Their gap Hivorr can exploit |
| --- | --- | --- | --- |
| Buy | Jumia, Konga, Jiji, Temu (cross-border) | Catalogue, logistics, brand, price | Jiji has reach but weak transaction trust; Jumia/Konga are retail-led, not local-merchant-led; Temu is price-only and cross-border |
| Hire | Word of mouth, LinkedIn, Jobberman, global freelance platforms | Reach, job volume | Local trust, verification of trade claims, local payment and escrow |
| Errand | Informal runners, WhatsApp groups, small errand startups | Price, familiarity | Reliability, tracking, protection, receipts |
| Sell | Jiji, Instagram/WhatsApp commerce, market associations | Zero friction, existing relationships | No trust layer, no fulfilment, no dispute process, no analytics |
| Offer services | Fiverr, Upwork, LinkedIn, referrals | Global demand, payments | Local demand, local currency, local verification, physical services |
| Logistics | Bolt, Uber, Gokada, Kwik, Chowdeck, Glovo | Fleet density, routing, brand | Single-purpose; cannot fill idle capacity with commerce and errand demand |

### 5.2 The competitors that actually threaten the strategy

Three categories matter more than the list above.

1. **Super-app fintechs (OPay, PalmPay, Moniepoint and similar).** They already own the wallet, the
   transaction relationship and enormous distribution. If they add service marketplaces, they start
   with the hardest asset Hivorr needs: daily financial habit.
2. **Vertical delivery and commerce operators (Chowdeck, Glovo, Kwik).** They are building
   logistics density in the same cities. Density is winner-takes-most locally, and they are ahead.
3. **Informal networks.** The default competitor. Free, trusted through kinship, and instant. Hivorr
   loses to informality whenever the transaction is low-value and the parties already know each
   other.

### 5.3 Differentiation that survives scrutiny

**[PROPOSED]** Three claims are defensible; the rest are marketing.

- **Cross-activity identity and trust.** One verification, one reputation, one wallet, usable across
  hiring, buying, errands and earning. No single-activity competitor can offer this without becoming
  a different company.
- **Protection on transactions between strangers.** Escrow, name-matched deposits, bound payouts,
  structured disputes. This is the difference between "a listing site" and "a place I will send
  money".
- **Earning and spending in one account.** A rider can deliver, a seller can buy, a professional can
  hire. This is the only structural answer to acquisition cost.

**Do not claim:** "we are the only platform that…", "no one can copy this", or global scale before it
exists. Breadth is copyable. Trust, density and habit are not, but they take years.

---

## 6. Customer segments and value propositions

**[PROPOSED]** Segments are defined by the job the person is trying to do, not by demographics.

| Segment | Primary job | What they need to believe | Activity |
| --- | --- | --- | --- |
| Urban household | Get a task, purchase or repair done without stress | "Someone accountable will show up, and my money is safe" | Buy, Hire, Errand |
| Small business owner | Sell more without building a sales channel | "This brings me customers I do not already have" | Sell |
| Skilled professional | Fill capacity with better-qualified leads | "The leads are real, and I get paid" | Offer services |
| Young urban earner | Add income flexibly around other work | "I can earn this week, on my schedule" | Logistics, Offer services |
| Informal trader | Reach customers beyond the stall | "I do not have to understand technology to use this" | Sell |
| Corporate buyer | Source services or delivery reliably, with paperwork | "Procurement will accept this" | Hire, Logistics |

### 6.1 Segment priority for launch

**[PROPOSED]** Launch is not for everyone. The first three segments to serve deliberately:

1. **Urban households in dense Lagos corridors** — they generate the demand that makes supply worth
   serving.
2. **Verified skilled professionals** — they create the trust impression and the first completed,
   reviewed transactions.
3. **Logistics providers** — they are the shared supply for both errands and commerce, so one
   recruitment effort serves two activities.

Sellers come next, because commerce without delivery density produces bad experiences. Corporate
buyers come after a track record exists, not before.

---

## 7. Business model and revenue architecture

### 7.1 What is already decided, and what is not

**[APPROVED]** The following business rules constrain monetisation and cannot be overridden by a
pricing idea:

- `tier_0` accounts have zero financial limits: no withdrawal, no payout, no conversion, no earning.
- Earning activities require both the activity verification lane and a KYC tier.
- Deposits require payer name to match the entity profile name.
- Payouts go only to bound, pre-verified bank accounts.
- Verification gates writes, not access: unverified users get a dashboard but cannot transact.

**[DECIDED 3 November 2026]** The fee *structure* is settled (BD-D02): delivery and errand fees from
day one, no transaction commission for two quarters, then 8–10% on services and 5–8% seller-side.
The exact rates remain open until cost data exists. The escrow holding period and dispute rules
remain undecided (`ARCHITECTURE.md` §16.4 #11, BD-D03). The KYC tier ladder and limits are undecided
(#6, BD-D05). The currency model is undecided (#8, BD-D07). Nothing may be published or charged
beyond the decided structure until those are settled.

### 7.2 Revenue streams

**[PROPOSED]** Ranked by how soon they can realistically produce revenue. Every stream is labelled.

| # | Stream | Mechanism | Earliest stage | Status |
| --- | --- | --- | --- | --- |
| 1 | Service commission | Percentage of completed Hire and Offer-services transactions | Launch | **[PROPOSED]** — rate **[FOUNDER]** |
| 2 | Delivery fee | Distance and weight-based fee on Buy orders and errands | Launch | **[PROPOSED]** — structure **[FOUNDER]** |
| 3 | Seller commission | Percentage of completed marketplace orders, or a per-order fee | Phase 2 | **[PROPOSED]** |
| 4 | Promoted placement | Paid visibility for sellers and professionals, clearly labelled | Phase 2 | **[PROPOSED]** |
| 5 | Verification services | Expedited or premium verification tiers | Phase 2 | **[PROPOSED]** — must not become pay-to-pass |
| 6 | Subscriptions for earners | Analytics, bulk tools, priority support | Phase 3 | **[PROPOSED]** |
| 7 | Logistics as a service | Delivery for external businesses using Hivorr capacity | Phase 3 | **[PROPOSED]** |
| 8 | Enterprise and team accounts | Multi-user buying, procurement, invoicing | Phase 3–4 | **[FUTURE]** — blocked by BD-D06 |
| 9 | Financial products | Working capital, invoice financing, insurance | Phase 4+ | **[FUTURE]** — licensing required |
| 10 | Aggregated market insight | Anonymised trend reporting | Phase 4+ | **[FUTURE]** — constrained by NDPA |

### 7.3 Pricing principles

**[PROPOSED]** These principles govern any future pricing decision. They do not set a price.

1. **Free until liquidity exists.** Charging a take rate before there is repeat demand suppresses the
   very behaviour the marketplace needs. Early revenue should come from delivery and from optional
   promotion, not from taxing first-time trust.
2. **Percentage, not fixed, wherever possible.** A fixed fee is punitive on small transactions in an
   inflationary market and is the most common reason low-income users abandon a platform.
3. **The fee is visible before commitment.** No hidden deductions at payout. Trust is the product;
   opaque fees destroy it faster than a high fee does.
4. **Earners must be able to predict take-home pay.** Show gross, fee and net in the same view.
5. **Price changes are announced, dated and grandfather-able.** Verification tightening already has
   a grandfathering question; pricing needs the same discipline.
6. **Never charge for the trust controls.** Verification, escrow and dispute handling are the
   proposition. Charging separately for protection signals that unprotected use is available.
7. **One currency of pricing per market at launch.** Multi-currency pricing before the currency model
   is decided creates accounting ambiguity.

### 7.4 Affordability

**[VERIFY]** The binding constraint is not willingness to pay, it is transaction size. A 15% take on
a NGN 4,000 errand is 600 naira — visible, and easily undercut by an informal runner. This has three
consequences:

- Errand and delivery economics should lean toward a fixed logistics fee paid by the requester, not
  a service commission.
- High-value services (Hire, Offer services) can carry a percentage take because the absolute amount
  is small relative to the job.
- Low-value commerce needs either seller-side commission or promoted placement, not buyer-side fees.

**[PROPOSED]** Validate all three with real transaction data in the first 90 days before publishing
any rate card.

### 7.5 Unit economics — definitions and what is missing

**[PROPOSED]** Define the model now; populate it later. Do not present a fabricated CAC or LTV.

| Metric | Definition | Data source | Available today? |
| --- | --- | --- | --- |
| Gross transaction value (GTV) | Total value of completed transactions, before fees | Ledger | No — pre-build |
| Net revenue | GTV × take rate, plus non-transaction revenue | Ledger | No |
| Take rate | Net revenue ÷ GTV, reported per activity | Derived | No |
| Contribution margin per order | Net revenue − payment cost − delivery subsidy − support cost | Finance | No |
| CAC | Fully loaded acquisition cost ÷ activated accounts | Marketing + CRM | No |
| Activation rate | Registered → first completed transaction | Product analytics | No |
| Cross-role rate | Activated accounts with 2+ activities | Product analytics | No |
| Retention | Repeat transaction within 30/90 days, per activity | Product analytics | No |
| Payback | CAC ÷ monthly contribution per account | Derived | No |

**Honest position:** the company cannot state unit economics today. The roadmap's first financial
deliverable is not a forecast — it is the instrumentation and the 90-day cohort data that make a
forecast meaningful.

---

## 8. Market entry and liquidity strategy

### 8.1 Entry principle

**[COMMITTED]** Supply-first, demand-following, geography-concentrated.

**[PROPOSED]** Concentrate at the level where liquidity actually forms. "Nigeria" is not a market.
"Lagos" is barely a market. The operating unit is a cluster of contiguous neighbourhoods where a
rider can complete a delivery inside an acceptable time and where households and merchants already
transact.

### 8.2 The six activities are six different cold-start problems

**[PROPOSED]** This is the most important operational insight missing from version 1.0.

| Activity | Liquidity type | Scarce side at launch | Constraint |
| --- | --- | --- | --- |
| Hire | Low frequency, high value, 2-party | Supply (verified professionals) | Verification capacity and quality |
| Buy | Medium frequency, 3-party | Demand | Merchant catalogue and delivery density |
| Errand | High frequency, low value, hyperlocal | Supply (providers) | Rider density in a small radius |
| Sell | Supply-led | Demand | Seller activation and order volume |
| Offer services | Supply-led | Demand | Qualified leads, not sign-ups |
| Provide logistics | Supply-led | Demand | Enough jobs per rider per day |

**Consequence:** the internal demand engine is **Buy + Errand**. The internal supply engine is
**Sell + Offer services + Logistics**. **Hire** is the trust anchor that gives the brand its
credibility and its highest-value transactions.

This changes the launch design: recruiting riders and sellers without demand produces churn, and
recruiting demand without supply produces bad first experiences.

### 8.3 Launch configuration

**[OPEN]** MVP activity scope is undecided: all six at launch, or Explore-first
(`ARCHITECTURE.md` §16.4 #3). Two viable configurations exist. The founder must choose; the
roadmap does not assume either.

| | **Configuration A — Six activities, thin depth** | **Configuration B — Explore-first, three activities** |
| --- | --- | --- |
| Launch set | Buy, Hire, Errand, Sell, Offer services, Logistics | Buy, Hire, Errand |
| Narrative | "One account, everything" | "Get things done, safely" |
| Strength | Matches the ecosystem thesis immediately; one onboarding for all roles | Fewer surfaces to support; faster to a good experience; seller/earner promise deferred |
| Weakness | Six support queues, six quality bars, thin liquidity everywhere | Contradicts "one account activates multiple activities" in the first impression; delays earning |
| Recommended if | Verification and delivery operations are ready on day one | They are not |

**[PROPOSED]** Whichever is chosen, launch depth in **one Lagos cluster** beats shallow coverage of
the whole city. A user who cannot get a rider in 40 minutes does not care that the platform also
offers legal services.

### 8.4 Penetration sequence

**[PROPOSED]**

1. **Anchor cluster (months 0–6).** One dense area. Hire + Errand depth, Buy in pilot with a limited
   merchant set. Target a completed-transaction base large enough to produce reviews.
2. **Second cluster (months 6–12).** Replicate the playbook within Lagos. Do not open a new city
   until cluster one is contribution-positive or deliberately subsidised with a stated budget.
3. **Second city (months 12–24).** Abuja or Port Harcourt, chosen on merchant supply and rider
   availability, not on population alone.
4. **National coverage (year 2+).** Only where a local operator or partner can supply delivery
   density.

### 8.5 Supply acquisition

**[PROPOSED]** Supply is recruited, not marketed.

| Supply type | Channel | Cost driver |
| --- | --- | --- |
| Professionals | Professional bodies, trade associations, alumni networks, targeted outreach | Field time, verification |
| Sellers | Market associations, physical clusters, existing merchant referrals | Field time, catalogue support |
| Logistics providers | Rider communities, existing dispatch groups, referrals from active riders | Recruitment bonus, onboarding |
| Errand providers | Same pool as logistics, plus part-time urban earners | Onboarding, first-job guarantee |

**Rule:** every recruited supplier is verified before their first paid transaction. Verification
capacity, not marketing budget, is the growth ceiling in year one.

### 8.6 Demand acquisition

**[PROPOSED]** Prioritised by cost per activated account, cheapest first:

1. **Supply-side referral.** Every verified provider brings demand through their own customers, who
   are told to transact on-platform.
2. **Cross-activity prompt.** A buyer is shown "you can also send an errand" at the moment of a
   completed order. This is the cheapest activation available because the trust already exists.
3. **Neighbourhood presence.** Physical activation in the anchor cluster: market days, estate
   associations, campus and office clusters.
4. **Word of mouth with a trust condition.** Rewards for referrals that complete a verified
   transaction, never for sign-ups.
5. **Paid digital, last.** Retargeting and search only, once activation and retention are known.
   Broad paid acquisition before product-market fit is the fastest way to burn a seed round.

### 8.7 Retention

**[PROPOSED]** Retention must not depend on AI, because AI launch scope is open.

- **Reputation lock-in.** Reviews and completed work are non-transferable.
- **Recurring need.** Push repeat categories first: cleaning, repairs, deliveries, groceries.
- **Predictable earning.** Riders and professionals stay for reliable daily volume, not gamification.
- **Protection.** One resolved dispute handled well retains a user longer than any discount.
- **Cross-role activation.** The strongest retention mechanism, and the one to instrument first.

---

## 9. Cross-activity growth engine

**[PROPOSED]** Six concrete loops. Each has an owner and a measurable rate.

| # | Loop | Mechanism | Measure |
| --- | --- | --- | --- |
| L1 | Earner → buyer | A rider or professional spends earnings on the platform | Share of earners who also buy within 60 days |
| L2 | Buyer → earner | A satisfied buyer activates selling or services | Buyer → earner activation rate |
| L3 | Hire → Buy | A client who hired also shops local | Cross-activity rate among Hire users |
| L4 | Buy → Errand | Delivery habit becomes errand habit | Errand attach rate among repeat buyers |
| L5 | Errand → Logistics supply | Frequent requesters become providers | Requester → provider conversion |
| L6 | Merchant → Professional | A seller needs a service (design, accounting, delivery) | Merchant service purchase rate |

**What breaks the engine:** if users activate multiple roles but transact in only one, the thesis
fails quietly. Activation is not the metric; *transacting* in two activities is.

---

## 10. Strategic partnerships

**[PROPOSED]** Partnerships are pursued for distribution, trust or capability — never for
credibility by association. No partner is named here as committed. All are approaches to be made.

### 10.1 Priority order

| Priority | Category | Why | What Hivorr gives them |
| --- | --- | --- | --- |
| 1 | Payment and settlement providers | Prerequisite for escrow and payout | Transaction volume, merchant acquisition |
| 2 | Map, address and geolocation providers | Errand and delivery dispatch depend on it | Usage at scale |
| 3 | Professional and trade associations | Fast, credible supply seeding and credential signals | Member income, digital presence |
| 4 | Market and merchant associations | Merchant clusters with existing trust | Sales channel, delivery |
| 5 | Logistics operators and fleet owners | Capacity without owning vehicles | Utilisation, demand |
| 6 | Corporates and SMEs | High-value, repeat, invoiced demand | Verified supplier access, procurement visibility |
| 7 | Identity and KYC providers | Faster verification, lower fraud | Volume |
| 8 | Communications providers (SMS, email, push) | OTP and notifications at low cost | Volume |
| 9 | Government and development institutions | Legitimacy, SME programmes, grants | Formalisation of informal work |
| 10 | Technology and cloud providers | Cost and credits | Growth-stage commitment |

### 10.2 Partnership discipline

**[PROPOSED]** A partnership is worth doing only if it produces at least one of: users, supply,
reduced cost, or regulatory standing. Otherwise it is a press release.

- No exclusivity in year one, in either direction, except where a payment or identity provider
  requires it for compliance.
- Every partnership has a named owner, a written objective and a review date.
- Nothing is announced before it is signed and delivering.
- Data-sharing partnerships are reviewed against NDPA obligations before signature, not after.

---

## 11. Brand, trust and demand generation

### 11.1 Brand promise

**[PROPOSED]** "You will not get cheated." Everything else — breadth, convenience, speed — is
secondary in year one, because the market's default expectation is that online counterparties
disappoint.

### 11.2 Trust as marketing

**[APPROVED]** The trust controls exist as product rules: verification lanes, escrow, name-matched
deposits, bound payout accounts, double-blind reviews, structured disputes.

**[PROPOSED]** These are the marketing. Publicise:

- how verification works, in plain language;
- what happens when something goes wrong;
- how long a dispute takes;
- how many providers were removed for fraud, and why.

Publishing enforcement is uncomfortable and it is the most credible trust signal available. It also
raises the cost of being a bad actor on the platform.

### 11.3 Channels

| Channel | Role | Stage |
| --- | --- | --- |
| Neighbourhood activation | Trust, onboarding, demonstration | Launch |
| Referral | Cheapest growth; must reward completed transactions | Launch |
| Content and search | Category intent ("hire a plumber in Lagos") | Phase 2 |
| Social and creator partnerships | Awareness, especially for earning opportunities | Phase 2 |
| Corporate and association channels | Bulk supply and demand | Phase 2–3 |
| Paid performance | Scale only after unit economics are known | Phase 3 |

### 11.4 Reputation management

**[PROPOSED]**

- A single owner for public response, with a response standard (time, tone, escalation).
- Every public complaint is logged and traced to a transaction. Unresolved public complaints are a
  leading indicator of operational failure, not a communications problem.
- Fraud incidents are handled as incidents, with a written post-mortem, not deleted.

---

## 12. Organisation and operating model

**[PROPOSED]** Hire in the order the constraint appears, not by department chart.

### 12.1 Functions and when they appear

| Function | Phase 0–1 | Phase 2 | Phase 3+ |
| --- | --- | --- | --- |
| Founder / general management | Founder | Founder + GM | CEO + leadership |
| Business development and partnerships | Founder | 1–2 BD | BD team + partnerships lead |
| Supply acquisition | Field agents (contract) | City launchers | Regional leads |
| Verification and trust & safety | Founder + 1 reviewer | Review team + T&S lead | Scaled review + fraud analytics |
| Marketing | Founder + agency | Growth lead | Growth + brand |
| Customer support | Founder + shared inbox | Support lead + agents | Tiered support |
| Finance and reconciliation | Founder + accountant | Finance manager | Finance team |
| Legal and compliance | External counsel | External + compliance owner | In-house or retained |
| Data and business intelligence | None | Analyst | Analytics team |

### 12.2 The first five hires

**[PROPOSED]** In order:

1. **City launcher / supply acquisition lead.** The person who signs professionals, merchants and
   riders. This is the growth engine in year one.
2. **Verification and trust reviewer.** Protects the core promise and sets the operational ceiling.
3. **Operations and support lead.** Owns disputes, delivery exceptions and provider quality.
4. **Growth marketer.** Starts only after activation and retention are measured.
5. **Finance and reconciliation officer.** Owns payouts, fees and provider settlement. Becomes
   critical the moment real money moves.

### 12.3 Operating cadence

**[PROPOSED]** Weekly: liquidity, verification backlog, dispute ageing, fraud. Monthly: cohort
retention, contribution margin, supply health by cluster. Quarterly: roadmap gate review against
Section 14.

---

## 13. Financial and commercial planning

### 13.1 Position

**[PROPOSED]** No revenue target is stated here. Any target without a take rate, a transaction
volume, and a cost base is fiction. Instead, the roadmap defines the measurement system and the
milestones that make targets possible.

### 13.2 Milestones that replace targets

| Milestone | Definition of achieved | Why it matters |
| --- | --- | --- |
| M1 — Trust proven | 100 completed transactions with zero unresolved fraud and a median dispute resolution inside the published SLA | The proposition is credible |
| M2 — Repeat proven | 30% of activated accounts transact again within 30 days | Demand is real, not curiosity |
| M3 — Cross-role proven | 15% of active accounts transact in 2+ activities | The core thesis holds |
| M4 — Unit positive | Contribution margin per order ≥ 0 in one cluster, before central overhead | Growth is not buying losses |
| M5 — Replicable | Second cluster reaches M2 within half the time of the first | The playbook works |
| M6 — Investable | Cohort payback under a defined threshold with a stable take rate | The business can raise or scale |

All thresholds are **[PROPOSED]** and must be set with real cost data. They are deliberately modest.

### 13.3 Cost structure

**[PROPOSED]** Categories, not figures:

- Verification and trust operations (people-intensive; the largest early cost).
- Payment processing and settlement fees (per transaction).
- Delivery subsidy, if any (the most dangerous line; must be capped and dated).
- Support operations.
- Field acquisition (agents, activations, materials).
- Technology and hosting (low at this stage).
- Legal, compliance and licensing.
- Marketing.

**Rule:** every subsidy has an expiry date and a stated purpose. A subsidy without an exit condition
is a permanently lower price.

### 13.4 Funding

**[PROPOSED]** The business is fundable on evidence, not on vision. In order:

1. **Founder capital / revenue** through Phase 0–1.
2. **Pre-seed or angel** once M1–M2 are demonstrated, to fund cluster replication.
3. **Seed** once M4–M5 are demonstrated, to fund a second city.
4. **Growth capital** once cross-role behaviour and take rate are proven across cities.

**[PROPOSED]** Do not raise against the six-activity narrative alone. Raise against retention and
cross-role data, because that is what a sophisticated investor will test.

---

## 14. Phased roadmap

**[PROPOSED]** Phases are defined by business maturity, not by which features exist. Dates are
deliberately absent; each phase has an entry gate and an exit gate. Entry gates are the important
part — they prevent the most expensive mistake, which is scaling an unproven model.

### Phase 0 — Foundation and preparation

**Objective.** Make the business legally, financially and operationally able to take money and
resolve disputes before a single user transacts.

**Key activities**

- Resolve funds custody and obtain the appropriate licence or partner structure (BD-D01).
- Register with the NDPC; publish privacy notice and terms.
- Confirm take-rate and fee model (BD-D02) and escrow and dispute rules (BD-D03).
- Appoint Nigerian counsel; draft provider terms, refund policy and dispute policy.
- Set the verification standard per lane and the reviewer workflow, including SLA.
- Select anchor cluster and build the supply target list.
- Define the pilot merchant set and the first professional categories.
- Establish the measurement instrument: account, activation, transaction, dispute, fraud.

**Exit gate.** Legal structure for funds settled; policies published; reviewer capacity able to
process the target supply volume; fee model decided and documented; measurement live.

**Risks.** Licensing takes longer than expected; policy work is underestimated; supply targets are
unrealistic.

---

### Phase 1 — Anchor cluster launch

**Objective.** Prove that strangers will transact safely on Hivorr, and that they will come back.

**Key activities**

- Launch in one dense Lagos cluster with the configuration chosen under BD-D04.
- Seed supply: professionals first, then riders, then a limited merchant set.
- Run neighbourhood activation and supply-side referral.
- Operate an explicit trust programme: publish dispute outcomes, remove bad actors.
- Instrument every funnel step from sign-up to second transaction.
- Hold pricing at introduction level; do not optimise revenue yet.

**Outcomes.** A completed-transaction base large enough to produce reviews; a functioning dispute
process; first evidence on repeat behaviour.

**KPIs.** Activation rate, first-transaction time, repeat rate at 30 days, dispute rate, verification
SLA, provider retention at 30 days.

**Dependencies.** Funds custody; verification operations; delivery capacity in the cluster.

**Risks.** Cold-start imbalance; verification backlog; delivery failure at peak; fraud in the first
cohort causing reputational damage.

---

### Phase 2 — Depth and repeat behaviour

**Objective.** Turn first use into habit, and prove contribution margin in one cluster.

**Key activities**

- Expand categories within the cluster rather than expanding geography.
- Introduce seller-side monetisation and promoted placement, if the data supports it.
- Launch the cross-activity prompt and measure cross-role rate (BD-K05).
- Build merchant tooling that reduces churn: catalogue help, order management, simple analytics.
- Formalise provider quality management: ratings thresholds, suspension, appeals.
- Begin B2B pilots with local businesses for delivery and services.

**Outcomes.** Contribution-positive orders in the cluster; cross-role behaviour measurable; seller
and professional retention improving.

**KPIs.** Contribution margin per order, 90-day repeat, cross-role rate, merchant churn, rider
utilisation, dispute resolution time.

**Dependencies.** Reliable reconciliation; support capacity; a fee model that survives real data.

**Risks.** Subsidy dependency; merchant churn after the launch push; support quality degrading with
volume.

---

### Phase 3 — Replication and second city

**Objective.** Prove the playbook is repeatable, not founder-dependent.

**Key activities**

- Replicate the cluster playbook in a second Lagos cluster, then a second city.
- Hire city launchers and give them a written operating manual.
- Introduce earned subscriptions for professionals and sellers.
- Launch logistics-as-a-service for external businesses.
- Establish the partnership programme with associations and corporates.
- Add the second-city regulatory workstream (state levies, permits).

**Outcomes.** Two clusters at or above the first cluster's maturity; a documented playbook; a second
city operating without founder presence.

**KPIs.** Time-to-maturity per cluster, CAC per city, cross-city comparability, partner-sourced
volume, subscription attach rate.

**Dependencies.** M4 achieved; cash for replication; operational leadership hired.

**Risks.** Overextension; quality divergence between cities; founder bottleneck.

---

### Phase 4 — African expansion

**Objective.** Enter markets where payment rails, regulation and diaspora demand make expansion
viable.

**Key activities**

- Market selection on rail maturity, not population.
- Local payment and payout partnerships; confirm the multi-currency model (BD-D07).
- Local verification approach: identity, credential and address norms differ per country.
- Diaspora corridor pilots: cross-border service purchase and remittance-adjacent use cases.
- Localisation of language, currency, support hours and dispute norms.
- Establish local entity and compliance in each market.

**Outcomes.** At least one market outside Nigeria reaching Phase 2 maturity; cross-border
transactions with acceptable settlement and FX cost.

**KPIs.** Time-to-liquidity per market, cross-border volume, FX cost as share of transaction value,
local retention versus Nigeria benchmark.

**Dependencies.** Multi-currency model decided; provider coverage; local legal entity; capital.

**Risks.** Regulatory fragmentation; FX volatility; provider concentration; expansion before the
home market is durable.

---

### Phase 5 — Long-term platform and global options

**Objective.** Extend the ecosystem where it creates durable advantage, and decline the rest.

**Options, in order of evidence required**

1. **Enterprise and team accounts.** Requires the business-as-account decision (BD-D06).
2. **Financial products.** Requires licensing and a credit model with real repayment data.
3. **Third-party integrations and developer access.** Requires proven API stability and demand.
4. **Additional verticals** (education, healthcare, property). Requires the trust model to transfer
   and a partner-led entry.
5. **Selective global markets** where diaspora demand exists and regulation is tractable.

**Explicit non-goals**

- Custody of cryptocurrency or digital assets.
- Lending before a licensing position and repayment data exist.
- Selling personal data in any form.
- White-label licensing of the platform before the core business is profitable.

---

## 15. KPIs and success measures

**[PROPOSED]** One north star, four health dimensions. Everything else is diagnostic.

**North star:** weekly transacting accounts — distinct accounts completing at least one transaction
in a week, in any activity.

| ID | Metric | Definition | Why it matters |
| --- | --- | --- | --- |
| BD-K01 | Weekly transacting accounts | Distinct accounts with ≥1 completed transaction per week | The only measure of real usage |
| BD-K02 | Activation rate | Registered → first completed transaction, 30 days | Onboarding quality |
| BD-K03 | Repeat rate | Second transaction within 30/90 days | Habit formation |
| BD-K04 | GTV per activity | Completed transaction value, by activity | Scale and mix |
| BD-K05 | Cross-role rate | Active accounts transacting in 2+ activities | The core thesis |
| BD-K06 | Take rate | Net revenue ÷ GTV, by activity | Monetisation health |
| BD-K07 | Contribution margin per order | Net revenue − variable costs | Viability |
| BD-K08 | Dispute rate and resolution time | Disputes per 100 transactions; median hours to close | Trust |
| BD-K09 | Fraud loss rate | Confirmed fraud value ÷ GTV | Trust and cost |
| BD-K10 | Verification SLA | Median time from submission to decision | Growth ceiling |
| BD-K11 | Provider utilisation | Active days per provider per week | Supply health |
| BD-K12 | CAC and payback | Fully loaded cost per activated account; months to recover | Efficiency |
| BD-K13 | Cluster maturity index | Composite of the above, per cluster | Replicability |

**Rule:** no KPI is reported without its definition and its data source. A metric that changes
definition is a new metric.

---

## 16. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| BD-R01 | Funds custody not resolved, blocking escrow and launch | Medium | Critical | Decide BD-D01 early; launch in a structure that does not require Hivorr to hold funds | Founder |
| BD-R02 | Cold-start failure: supply without demand or demand without supply | High | Critical | Cluster concentration; drive demand first in Buy/Errand; guarantee first jobs to new providers | Founder |
| BD-R03 | Fraud in the first cohort destroys trust | Medium | Critical | Verification before first transaction; name-matched deposits; payout binding; fast removal and publication | T&S |
| BD-R04 | Delivery economics never reach contribution-positive | High | High | Distance pricing; cluster density; cap and date every subsidy; measure cost per delivery weekly | Operations |
| BD-R05 | Verification capacity becomes the growth ceiling | High | High | Hire reviewers ahead of supply targets; tiered verification; clear SLA | T&S |
| BD-R06 | Incumbent super-app or delivery player bundles the same proposition | Medium | High | Depth in the trust layer and cross-role identity; avoid head-on price competition | Founder |
| BD-R07 | Regulatory action on payments, data or platform work | Medium | High | Counsel retained; NDPC registration; published policies; conservative posture on money movement | Legal |
| BD-R08 | Inflation and affordability pressure suppress transaction size | High | Medium | Percentage pricing; low absolute fees; avoid subscriptions early | Founder |
| BD-R09 | Cross-role behaviour never materialises | Medium | Critical | Instrument early; make cross-activity prompts a product priority; stop expanding activities if it fails | Founder |
| BD-R10 | Founder dependency in supply acquisition and partnerships | High | Medium | Written playbooks; hire the city launcher first | Founder |
| BD-R11 | Provider quality variance damages brand | High | Medium | Ratings thresholds; suspension and appeals; category-specific quality bars | Operations |
| BD-R12 | Cash constraint before M4 | Medium | Critical | Phase gates; no geographic expansion before cluster economics; raise on evidence | Founder |
| BD-R13 | FX and provider concentration on cross-border expansion | Medium | Medium | Multiple providers; currency of transaction held; no forced conversion | Finance |
| BD-R14 | Single payment and custody provider (VFD) fails, is delayed, or its licence scope proves narrower than required | Medium | Critical | **Accepted 3 November 2026.** Mitigations: written scope confirmation before integration; production certification before money moves; settlement SLA; legal segregation; provider-agnostic ledger so a second rail can be added without redesign; quarterly review of the decision | Founder |

**Standing rule:** any risk rated Critical has a named owner and a monthly review. A risk register
that is not reviewed is a decoration.

---

## 17. Dependencies and blockers

**[PROPOSED]** Business activities that cannot start until something else is decided or built.

| Dependency | Blocks | Status |
| --- | --- | --- |
| Funds custody and licensing model | Escrow, wallet, payouts, launch | **[DECIDED 3 Nov 2026]** — VFD as single payment and custody partner (BD-D01, BD-D11) |
| Platform fee, escrow period, dispute rules | Any published pricing | **Partly decided** — fee structure decided (BD-D02); exact rates and escrow timing still open (BD-D03) |
| KYC tier ladder and limits | Financial gating, earning activation | **[OPEN]** — BD-D05 |
| Currency model | Multi-currency accounts, cross-border pricing | **[OPEN]** — BD-D07 |
| MVP activity scope | Launch configuration and supply plan | **[OPEN]** — BD-D04 |
| Business as account or profile | Enterprise and team offering | **[OPEN]** — BD-D06 |
| Verification vendor | Verification cost and SLA | **[OPEN]** |
| AI launch scope | Any AI-based retention or pricing feature | **[OPEN]** |
| Working product | Every phase after Phase 0 | In progress |

**Note.** The product does not exist yet. Every commercial timeline in this document is therefore
conditional, and no phase can start before Phase 0's legal and financial foundations are in place.

---

## 18. Decision register

**[FOUNDER]** Rows marked **DECIDED** are settled. Everything else in this table is not decided, and
each blocks concrete work.

| ID | Decision | Blocks | Position |
| --- | --- | --- | --- |
| BD-D01 | Funds custody: licensed partner holds funds, or Hivorr pursues a licence | Escrow, wallet, launch | **DECIDED 3 November 2026** — partner-held. A licensed deposit-taking institution holds escrow balances; a licensed processor collects and pays out. One provider may fill both roles if scope is confirmed in writing (§21). Hivorr never holds customer funds |
| BD-D02 | Take rate by activity, and who pays it | Pricing, revenue, provider terms | **DECIDED 3 November 2026** — delivery and errand fees from day one; zero transaction commission for the first two quarters; then 8–10% on Hire and Offer services and 5–8% seller-side, with no buyer-side fee. Exact rates await cost data |
| BD-D03 | Escrow holding period and dispute rules | Escrow lifecycle, refunds, support model | Short holding period with a defined inspection window |
| BD-D04 | Launch configuration: six activities thin, or Explore-first | Supply plan, support model, marketing | Explore-first if verification and delivery capacity are not ready |
| BD-D05 | KYC tier ladder and limits | Earning activation, financial gating | Minimal tiers at launch; raise limits with evidence volume |
| BD-D06 | Business as a profile on the account, or its own account | Enterprise offering, team features | Profile at launch; revisit with corporate demand |
| BD-D07 | Single-currency or multi-currency | Cross-border pricing, expansion | NGN at launch; multi-currency when a second market opens |
| BD-D08 | Positioning: workforce marketplace or broader operating layer | Brand, marketing, fundraising narrative | The working position in §3.3, for the first year |
| BD-D09 | Anchor cluster and second city | Supply plan, operations | One dense Lagos cluster, then a second within Lagos |
| BD-D10 | Verification standard per lane and who performs it | Supply onboarding cost and SLA | In-house review with a contracted identity provider |
| BD-D11 | Payment stack: single provider or layered | Collections, custody, payout, integration scope | **DECIDED 3 November 2026** — VFD as single payment and custody partner, replacing Paystack/Flutterwave. Conditional on written licence-scope confirmation; risk accepted with mitigations (BD-R14) |

---

## 19. Governance and change control

**[PROPOSED]**

- **Owner.** The founder approves every change to this document.
- **Review cadence.** Quarterly, or on any gate decision, whichever comes first.
- **Change classes.** A new revenue stream, a pricing change, a new market or a new partnership
  category requires founder approval. Wording and KPI clarifications do not.
- **Evidence rule.** Any change to a strategic claim must cite the data that prompted it.
- **No silent promotion.** A **[PROPOSED]** item becomes **[COMMITTED]** only by an explicit recorded
  decision, and the decision date goes in the changelog.
- **Cross-document rule.** If a business decision conflicts with an approved product or permission
  document, the approved document wins until it is amended. Record the conflict; do not work around
  it.

---

## 20. Research log and sources

Checked 3 November 2026. Figures are directional; methodology differs between sources and several
are modelled rather than measured.

| # | Source | Used for | Note |
| --- | --- | --- | --- |
| 1 | DataReportal, *Digital 2025: Nigeria* | Internet users and penetration | Modelled from platform and survey data |
| 2 | Nigerian Communications Commission, industry statistics (reported 2025) | Active internet subscriptions, broadband penetration | Operator-reported; definitions vary |
| 3 | National Bureau of Statistics, CPI (rebased to 2024) | Inflation trend | Official series; rebasing changed headline levels |
| 4 | World Bank, Nigeria macroeconomic monitoring (2026) | Inflation trajectory | Secondary analysis of NBS data |
| 5 | Bolt and Ipsos, gig economy report (reported April 2026) | Gig worker count and sector value | Commissioned study; treat as an estimate |
| 6 | Mordor Intelligence; Verified Market Research | E-commerce market size range | Vendor estimates; definitions differ materially |
| 7 | 2025 industry analysis of Jumia and Konga sales | Actual modern e-commerce scale | Secondary; useful as a reality check |
| 8 | Nigeria Data Protection Act 2023; NDPC GAID 2025 | Data obligations, breach notification, filing fees | Primary legislation and guidance |
| 9 | Central Bank of Nigeria, payments licensing framework | Licence categories and capital expectations | Primary regulator material; confirm current circulars |
| 10 | Securities and Exchange Commission, ISA 2025 | Virtual asset licensing | Primary; reason for the digital-asset non-goal |
| 11 | VFD Group / Product Studio Limited, BaaS API documentation (checked 3 November 2026) | Wallet, virtual account, payout and verification capabilities; banking partner | Primary vendor documentation. Confirms capability, not contractual scope |

**What was not verified and must be.** Willingness to pay a platform fee; average transaction values
by category; rider cost per delivery in the target cluster; merchant acquisition cost; verification
cost per provider; dispute frequency. These are the six numbers that decide whether the model works,
and none can be obtained without operating.

---

## 21. Decision briefs

Each open item below is written so it can be decided in one sitting. A brief states the real options,
the evidence, a recommendation, what it unblocks, and how reversible it is. BD-D01 and BD-D02 were
decided on 3 November 2026 and are marked as such; the rest remain open.

### BD-D01 — Funds custody

**Question.** Does Hivorr hold customer money, or does a licensed third party hold it?

**Decision — 3 November 2026: partner-held, in two distinct roles.** A licensed payment processor
collects funds and executes payouts; a licensed deposit-taking institution is the account of record
holding escrow balances. Hivorr never takes possession of customer money at any point, including in
transit. Provider selection is a procurement exercise, not a strategy decision.

**Why two roles.** The providers are not interchangeable:

| Role | What it must be licensed to do | Candidate categories |
| --- | --- | --- |
| Collection, split and payout instruction | Payment processing / switching | Payment processors such as Paystack |
| Holding escrow balances | Deposit-taking | Microfinance bank such as VFD, or a commercial bank's escrow service |

**On the option of implementing escrow logic without a custodian.** Collecting into Hivorr's own
settlement account and releasing later is functionally unlicensed deposit-taking. It is not a
shortcut; it is the specific activity the licensing framework regulates. It is rejected.

**Can one provider do both roles?** Possibly, and VFD is the most plausible single candidate, because
the group contains both a licensed deposit-taking bank and a banking-as-a-service platform.

As checked on 3 November 2026, the VFD Group BaaS platform (Product Studio Limited) documents:
customer wallets, virtual accounts for collections, bank transfers and payouts, bank-account and
customer identity verification, card issuing, and multi-channel payment acceptance. Banking services
are provided in partnership with VFD Microfinance Bank. Onboarding requires compliance and KYC review,
sandbox testing, and certification before production.

That covers collection and custody in one contract — but four conditions must be met before it is
treated as settled:

1. **Written confirmation of scope.** Ask VFD, in writing, whether a marketplace escrow use case is
   supported: buyer funds collected, held, and released to a different party after a condition is
   met. A wallet product and an escrow arrangement are not the same thing.
2. **Legal segregation.** The funds must sit in a designated collection or trust arrangement, not a
   general corporate deposit. If the account is Hivorr's own balance, the money is Hivorr's money in
   law, and a creditor or insolvency event could reach it.
3. **Limits.** Confirm the microfinance bank's licence category and any per-customer or per-account
   balance limits, because they cap transaction size and escrow exposure.
4. **Concentration.** One provider for collection, custody and payout means one outage, one
   settlement delay and one licence problem become an escrow failure. Keep a documented fallback.

**Do not rely on deposit insurance as the escrow argument.** Deposit insurance protects depositors up
to a coverage limit; it is not a substitute for contractual segregation of counterparty funds, and it
does not automatically protect a marketplace user whose money sits in a pooled balance.

**Who is the counterparty?** Two legal entities, two roles, and the distinction matters.

| Entity | Role | What Hivorr gets |
| --- | --- | --- |
| Product Studio Limited (PSL), a VFD Group subsidiary | Technology and banking-as-a-service platform | API, dashboard, sandbox and production access, integration support |
| VFD Microfinance Bank | Licensed deposit-taking bank | The account holding funds; statements and transaction records |

In practice Hivorr would contract with PSL for the platform while the banking relationship — account,
KYC and the licence covering the money — sits with VFD Microfinance Bank. PSL holds no banking
licence.

**The gap to close.** If the agreement is only with PSL, the entity promising escrow is not the entity
licensed to hold funds. Ask for:

1. The named counterparty for the escrow balance, and whether the custody terms bind VFD MFB.
2. A tripartite arrangement if the platform and the bank are separate parties.
3. Escrow scope confirmation from VFD MFB itself, not only from PSL.
4. Segregation wording: a designated collection or trust arrangement, not Hivorr's corporate balance.
5. VFD MFB's licence category and any balance limits.

**Comparison worth making.** A commercial bank's escrow agency service makes the custodian and the
licensed counterparty the same entity from the start. That is a simpler legal structure, even where
the developer experience is worse. Evaluate both on legal clarity first and API convenience second.

**Ownership and licence note.** VFD is not a single company, and the corporate structure matters for
escrow.

| Level | Entity | What it is |
| --- | --- | --- |
| Parent | VFD Group Plc | Nigerian investment holding company, listed on the Nigerian Exchange (ticker `VFDGROUP`), with more than twenty portfolio companies |
| Subsidiary | VFD Microfinance Bank Limited | The licensed deposit-taking bank behind VBank |
| Subsidiary | Product Studio Limited | The banking-as-a-service platform |

VFD Group Plc is publicly listed, so its shareholders are institutional and retail investors rather
than a single owner. The founder and group managing director holds a significant stake. Exact
shareholdings change and should be read from the latest annual report, not from press summaries.

**The licence point that needs checking.** VFD Microfinance Bank's own audited financial statements
describe it as a **Unit Microfinance Bank**. That is a specific licence category with geographic and
operating restrictions under the central bank's rules. It does not disqualify VFD, but a nationwide
marketplace with pooled escrow balances is a different proposition from a Lagos-based unit bank, and
the two must be reconciled in writing before integration.

VFD Group has also publicly stated an intention to obtain a commercial banking licence. Confirm the
current position, because it changes what the bank can do.

**What to request.** The licence certificate and category; written confirmation that the specific
model is in scope (nationwide collection, escrow balances, release to a third party); and the
contracting entity for each role.

**What still argues for two providers.** Separation keeps the processor and the custodian
independently replaceable. A single provider is acceptable only if item 1 above is confirmed and item
4 has a written fallback.

**Caveat on any single provider.** A payment processor's licence does not extend to holding
balances, and Nigerian regulators enforce that boundary against well-funded companies, not only
small ones. Confirm the scope of every provider's licence in writing before integration.

**Alternatives considered** are in the table below.

| Option | What it means | Capital and time | Control | Risk |
| --- | --- | --- | --- | --- |
| **A. Partner-held (recommended)** | A licensed institution holds funds in a regulated account; Hivorr records obligations and instructs releases | Low capital; weeks to integrate | Medium — constrained by partner capability and settlement timing | Partner dependency; per-transaction cost; reputational coupling |
| **B. Own licence** | Hivorr obtains the licence needed to hold funds directly | Reported minimum paid-up capital is ₦100m for a Payment Solution Service Provider and ₦2bn for a Mobile Money Operator, with capital lodged with the central bank; months of licensing | High | Regulatory, audit and capital burden before revenue exists |
| **C. Hybrid** | Partner now, apply for a licence once volume justifies it | Low now, high later | Rises over time | Migration cost; two integrations |

**Evidence.** Nigeria's payment licensing framework categorises operators and attaches capital
requirements; a payment solution service licence does not by itself settle the question of holding
customer balances, which is why the operator category matters. Licensed escrow and payment providers
already serve Nigerian marketplaces, and commercial banks offer escrow agency services. That means
option A is available in the market today without Hivorr building a regulated balance sheet.

**Recommendation.** **Option C.** Launch on a licensed partner, with a contractual right to migrate.
Do not take possession of customer funds at any point, including in transit. Revisit an own licence
only when monthly processed value makes the capital and compliance cost smaller than the partner fee.

**Status.** Adopted on 3 November 2026 as the two-role structure above.

**Unblocks.** Escrow, wallet presentation, payouts, launch, and the trust proposition.

**Reversible?** Yes, at a migration cost. Partner integration should be written so the ledger treats
the provider as a settlement rail, not as the source of truth.

---

### BD-D02 — Take rate and who pays

**Question.** What does Hivorr charge, on which activities, and to which side?

**Decision — 3 November 2026: Option B.** Delivery and errand fees from day one, priced to cover
rider cost plus a stated margin. Zero transaction commission for the first two quarters. After that,
8–10% on Hire and Offer services and 5–8% seller-side on Buy and Sell, with no buyer-side fee.
Promoted placement from Phase 2.

**What is still not decided.** The exact percentages within those ranges. They cannot be set honestly
until average transaction values and delivery cost per order are measured in the anchor cluster. The
ranges are the mandate; the numbers are a Phase 1 deliverable.

**Fallback if the data disagrees.** If repeat rate is strong but take rate suppresses volume, move to
the bottom of the range before changing the model. If contribution margin is negative on delivery at
any price users accept, the problem is density, not pricing.

| Option | Structure | Strength | Weakness |
| --- | --- | --- | --- |
| **A. Commission from day one** | Percentage on services and seller orders | Revenue immediately; proves willingness to pay | Suppresses first transactions; hardest moment to ask |
| **B. No transaction commission initially, fee on delivery and promotion** | Delivery fee is real cost recovery; transaction commission introduced later at a dated milestone | Maximises early liquidity; fee feels fair | Delayed revenue; requires discipline to actually introduce the fee later |
| **C. Graduated** | Zero commission for a provider's first N completed jobs, then standard | Rewards supply seeding | Complex to communicate; gaming risk |

**Benchmarks, for calibration only — not recommendations.** Category-based marketplace commissions
in Nigeria commonly sit in a mid single-digit to mid-teens percentage range. Ride-hailing charges a
booking fee in the low single digits of fare in Lagos. Global freelance platforms commonly charge
between ten and twenty percent. Local bike delivery is priced per trip and is sensitive to fuel cost.

**Recommendation.** **Option B with a hard end date.**

- Delivery and errand fees from day one, priced to cover rider cost plus a stated margin.
- Services (Hire, Offer services): zero commission for the first two quarters, then 8–10%.
- Marketplace (Buy, Sell): seller-side commission of 5–8% when introduced. No buyer-side fee.
- Promotion and featured placement from Phase 2.
- The end date and the trigger are published internally in advance, so the change is a plan and not
  a surprise.

**Why not commission first.** The first transaction is a trust test, not a purchase decision. A fee
at that moment reduces the number of tests, and the number of tests is the only thing that matters in
the first two quarters.

**Constraint.** The exact rate cannot be set until average transaction values and delivery cost per
order are known. Until then, publish the *structure* and hold the *number*.

**Reversible?** Yes, but price increases are harder than price cuts. Start low, move once, explain.

---

### BD-D03 — Escrow holding and dispute rules

**Question.** How long are funds held, and what triggers release?

**Recommendation.**

| Activity | Release trigger | Dispute window |
| --- | --- | --- |
| Hire / Offer services | Milestone acceptance, or automatic release after an agreed review period | Short window after delivery, before release |
| Buy | Delivery confirmation, or automatic release after a stated inspection period | Inspection period, category-dependent |
| Errand | Completion confirmation by requester, or automatic release after a short period | Short window, because the value is low and speed matters |

Cancellation, partial release, failed payment and chargeback handling must all be defined in the same
policy, not left to support judgement. The holding period must be short enough that providers do not
feel their money is trapped, and long enough that a real defect can be raised.

**Unblocks.** Provider terms, refund policy, support scripts, and the escrow state model.

---

### BD-D04 — Launch configuration

**Question.** Six activities at launch, or Explore-first?

**Recommendation.** **Explore-first (Buy, Hire, Errand)** unless verification capacity and delivery
capacity are both demonstrably ready on day one.

Reason: earning activities create an obligation to produce income for real people. Launching them
thinly — few jobs, slow payouts, weak demand — converts early goodwill into churn and public
complaints. Demand activities create an obligation to produce a good experience, which is cheaper to
meet and compounds trust.

**Reversible?** Yes. Adding earning activities later is a launch, not a migration.

---

### BD-D05 — KYC ladder

**Question.** How many tiers, what evidence, what limits?

**Recommendation.** Start with the smallest ladder that satisfies the approved rules and the
regulator: an unverified tier with zero financial limits, a verified tier with identity plus
selfie, and a higher tier adding address and source-of-funds evidence for larger balances. Raise
limits only when fraud data justifies it, never to remove friction.

**Constraint.** Collect the minimum evidence required. Every additional field is a data-protection
obligation and a drop-off point.

---

### BD-D06 — Business as profile or account

**Question.** Is a business a profile on a personal account, or its own account?

**Recommendation.** **Profile at launch.** Team features and multi-user access are a Phase 3–4
question, and deciding them now adds complexity to onboarding before there is corporate demand.

---

### BD-D07 — Currency model

**Question.** Single currency, or multi-currency from the start?

**Recommendation.** **NGN at launch.** Multi-currency becomes necessary when a second market opens,
not before. Designing the ledger to support multiple currencies is an engineering decision; exposing
multiple wallets to users at launch is a business decision that adds support and compliance load for
no launch benefit.

---

### BD-D08 — Positioning

**Question.** Workforce marketplace, or the broader operating layer?

**Recommendation.** Use the working position in §3.3 for the first year: trusted way to get work done
and things moved in Nigeria, with one account that also lets you earn. Revisit at Phase 3, when there
is evidence for or against the broader claim.

---

### BD-D09 — Anchor cluster

**Question.** Where does Hivorr launch first?

**Recommendation.** Choose by criteria, not by reputation:

1. Contiguous residential and commercial mix within a short delivery radius.
2. Existing merchant clusters that can supply catalogue quickly.
3. Reachable rider supply, including part-time.
4. A professional base that can be recruited through one or two associations.
5. Manageable local levies and permits.

Evaluate two or three candidate clusters against these criteria and pick one. Do not launch across a
whole city.

---

### BD-D10 — Verification standard

**Question.** Who verifies, to what standard, at what speed?

**Recommendation.** In-house review for trade and seller evidence, with a contracted identity provider
for document and selfie checks. Publish a service-level target. Hire reviewers ahead of the supply
target, because review capacity is the ceiling on growth.

**Constraint.** Verification must not become pay-to-pass. Expedited review is acceptable; a paid
shortcut to approval is not.

---

### BD-D11 — Payment stack

**Question.** Does Hivorr use a layered payment stack, or one partner for collections, custody and
payouts?

**Decision — 3 November 2026: one partner, VFD.** VFD becomes the single payment and custody partner.
This replaces the Paystack-primary, Flutterwave-secondary arrangement previously recorded in
`ARCHITECTURE.md` §3.1, and that row has been amended accordingly.

**Why the founder chose it.** One integration, one reconciliation surface, one counterparty, and the
custodian is also the collection point — which removes the movement of funds between a processor and a
bank before escrow.

**What this decision accepts.** Concentration. One provider means one outage, one settlement delay and
one licence event reaches customers directly. That risk is recorded as BD-R14 and is accepted rather
than mitigated away. The mitigations below reduce it; they do not remove it.

**Conditions before go-live.** These do not reopen the decision; they are the evidence required before
any money moves.

1. Written confirmation from VFD Microfinance Bank — not only the platform company — that marketplace
   escrow, nationwide operation and third-party release are within its licence.
2. Licence category and balance limits stated in writing. A Unit Microfinance Bank category must be
   reconciled with nationwide use before launch.
3. Legal segregation of escrow balances: a designated collection or trust arrangement, not Hivorr's
   operational account.
4. Confirmed channel coverage: cards, bank transfer, USSD and any international acceptance required.
   If a channel is not covered, a processor remains necessary for that channel, and the "single
   partner" position becomes "single custodian, multiple rails".
5. Production certification and a written settlement SLA.
6. A documented fallback: even if unused, the ability to add a second collection rail without
   changing the ledger.

**What remains true regardless.** The ledger stays provider-agnostic in design, as the database rules
require: a new provider is a new adapter and a provider reference column, never a new ledger. Using one
provider today must not make a second one expensive tomorrow.

---

## 22. Changelog

### 3 November 2026 — version 2.6, VFD selected as single payment partner

- **BD-D11 decided.** VFD becomes the single payment and custody partner: collections, escrow
  balances and payouts. This replaces the Paystack-primary / Flutterwave-secondary arrangement.
- `ARCHITECTURE.md` §3.1 row 10 amended to record the decision and its conditions. This is the first
  time a business decision has overridden a decided architecture component; it is recorded as an
  explicit amendment, not a silent change.
- Added **BD-R14**, an accepted risk: single provider failure, delay, or a narrower-than-required
  licence scope. Mitigations recorded; the risk is accepted, not eliminated.
- Added six go-live conditions to BD-D11, including written licence-scope confirmation from the
  licensed bank rather than the platform company, and channel-coverage confirmation.
- Preserved the rule that the ledger stays provider-agnostic, so a second rail can be added without
  redesign.

### 3 November 2026 — version 2.5, VFD ownership and licence category

- Recorded the ownership chain: VFD Group Plc (NGX-listed, `VFDGROUP`) owns VFD Microfinance Bank
  and Product Studio Limited.
- Noted that VFD Microfinance Bank's audited statements describe it as a **Unit Microfinance Bank**,
  a licence category with geographic and operating restrictions that must be reconciled with a
  nationwide marketplace and pooled escrow balances.
- Added the licence certificate and scope confirmation to the due-diligence list.

### 3 November 2026 — version 2.4, custody counterparty clarified

- Separated the two legal entities involved in a VFD arrangement: Product Studio Limited (platform)
  and VFD Microfinance Bank (licensed deposit-taker).
- Added the counterparty gap: if the agreement is only with the platform company, the entity
  promising escrow is not the entity licensed to hold funds.
- Added the five written confirmations to request, and the comparison against a commercial bank's
  escrow agency service where custodian and licensee are the same party.

### 3 November 2026 — version 2.3, single-provider custody assessed

- Assessed whether one provider can fill both custody roles. VFD Group's banking-as-a-service
  documentation records customer wallets, virtual accounts for collections, payouts and identity
  verification, with banking services provided by VFD Microfinance Bank. That makes a single-provider
  arrangement plausible.
- Added four conditions before a single provider is accepted: written confirmation of marketplace
  escrow scope, legal segregation of funds, confirmation of licence category and balance limits, and
  a documented fallback for concentration risk.
- Added the caution that deposit insurance is not a substitute for contractual segregation of
  counterparty funds.
- Added the VFD BaaS documentation to the research log.

### 3 November 2026 — version 2.2, two gating decisions taken

- **BD-D01 decided.** Funds are held by a licensed deposit-taking institution; collection and payout
  are executed by a licensed payment processor. Hivorr never takes possession of customer money.
  Implementing escrow logic on Hivorr's own settlement account was considered and rejected as
  unlicensed deposit-taking. Provider selection is now procurement, not strategy.
- **BD-D02 decided.** Delivery and errand fees from day one; zero transaction commission for two
  quarters; then 8–10% on services and 5–8% seller-side; no buyer-side fee. The exact percentages
  remain a Phase 1 deliverable, because they depend on measured transaction values and delivery cost.
- Added a provider-role table distinguishing payment processing from deposit-taking, and a caveat
  that a processor's licence does not extend to holding balances.
- Updated §7.1, §17 and §18 to reflect both decisions.

**Consequence outside this document.** `ARCHITECTURE.md` §16.4 #11 still lists the platform fee as
open. It should be updated to record that the structure is decided and only the rate remains. That
edit was not made here, because this task is scoped to the business roadmap.

### 3 November 2026 — version 2.1, decision briefs

- Added §21: a decision brief for each of the ten open business decisions, each with options,
  evidence, a recommendation, what it unblocks and whether it is reversible.
- Added market evidence for funds custody (licensing categories, reported capital requirements,
  availability of licensed escrow and bank escrow services in Nigeria).
- Added pricing benchmarks for calibration only, with an explicit rule that the number cannot be set
  until transaction values and delivery cost per order are known.
- No decision was made. Every brief is a recommendation.

### 3 November 2026 — version 2.0, rebuilt for the current direction

- Restructured from a seven-phase product sequence into business phases defined by market maturity,
  with entry and exit gates.
- Corrected the activity model: six activities, errand as the third Explore activity, `discover` as
  the Hire browse step.
- Downgraded the document's status from "approved strategic reference" to a proposal, and removed
  its role as an engineering input.
- Removed vendor presumptions (named international provider, stablecoin direction) and replaced them
  with selection principles and an explicit open decision.
- Added Nigeria market analysis with sourced indicators and stated confidence levels.
- Added a competitive map, including super-app fintechs and vertical delivery operators as the real
  threats.
- Added segment and jobs-to-be-done definitions, and a deliberate segment priority for launch.
- Added pricing principles and affordability analysis; no price is set.
- Added per-activity liquidity models and a launch configuration choice.
- Added unit-economics definitions and an explicit statement of what data is missing.
- Added milestone gates (M1–M6) in place of fabricated targets.
- Added organisational plan, first-five-hires order and operating cadence.
- Added a risk register with owners, a decision register, and a research log with sources.
- Removed category-creation language and unfalsifiable competitive claims.

### Version 1.0 — previous direction

Superseded. Retained ideas are listed in §2.1. The original file is preserved unchanged outside the
repository and is not an active reference.

---

> **Document status:** Proposed. Requires founder approval before any commercial commitment.
> **Next step:** BD-D03 (escrow timing and dispute rules) and BD-D04 (launch configuration) are the
> next gates. BD-D05 to BD-D10 can follow in any order.
