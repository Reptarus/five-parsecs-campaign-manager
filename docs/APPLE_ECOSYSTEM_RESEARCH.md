# Apple Ecosystem Gaming Research — 5PFH Forecast Input

**Owner**: Elijah Rhyne
**Last Updated**: 2026-05-06
**Research Date**: 2026-05-06 (Claude Code research agent, web search + fetch)
**Purpose**: Citation-anchored research on macOS desktop gaming + iOS premium paid app tier + Apple ecosystem cross-purchase behavior. Built specifically to update §6 platform-fee math and §6c mobile pocket edition sizing in `MODIPHIUS_DIGITAL_FORECAST.md`.

> **CRITICAL**: This document is reference material for live negotiation. **Every claim must be source-attributed.** Before quoting any number/peer-product reference in an email or counter-proposal, check the verification status. `⚠ AGENT-INFERRED` claims should be spot-checked against the cited URL before binding use.

---

## 1. Verification Legend

| Marker | Meaning |
|---|---|
| **✓ VERIFIED** | URL fetched and the specific claim was confirmed against the source |
| **⚠ AGENT-INFERRED** | URL on record from research agent, not independently spot-checked |
| **✗ UNVERIFIABLE** | No public source could be located; do NOT quote in correspondence |

---

## 2. macOS Desktop Gaming on Steam

### 2a. Current share (April 2026 Steam Hardware Survey)
- ✓ Windows: 93.47%
- ✓ macOS: **2.01%**
- ✓ Linux: ~5.3%
- Source: [Steam Hardware Survey](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam) ✓ VERIFIED

### 2b. macOS share trend (2025-2026)
- ⚠ Range-bound 1.85%-2.4% across 2025-2026
- ⚠ Recently ticked down 0.34 pts month-over-month (April 2026 reading)
- Source: Same Steam Hardware Survey, multi-month observation

### 2c. Apple Silicon impact on Mac gaming
- ⚠ Apple Game Porting Toolkit (GPTK) launched at WWDC 2023
- ⚠ GPTK 2 (June 2024) added AVX/AVX2 support on macOS 15+
- ⚠ Many DX12 games are now playable on M-series at ~30 fps high settings
- ⚠ GPTK is a developer-side translation layer (Wine + D3DMetal); has not measurably moved Steam's macOS user share — survey data still in 2% band
- Sources: [Apple Game Porting Toolkit page](https://developer.apple.com/games/game-porting-toolkit/), [Apple Gaming Wiki — GPTK](https://www.applegamingwiki.com/wiki/Game_Porting_Toolkit)

### 2d. Per-capita Mac vs. Windows ARPU on Steam
- ✗ **NO public data**. Valve does not break out ARPU by OS, and no third party (GameDiscoverCo, Statista, Newzoo) appears to have published this figure.
- The user's thesis that Mac-on-Steam is higher-ARPU is plausible (Apple-household income skew) but **cannot be cited with a primary source**. Treat as a directional argument, not a quantified one.

### 2e. Practical sizing
- Steam ~132M MAU × 2.01% = ~2.6M Mac-on-Steam users in addressable pool
- For 5PFH (niche tabletop companion), the relevant slice is Mac users in the solo-RPG/wargame audience overlap — proportionally similar to Windows

---

## 3. iOS Premium Paid App Tier

### 3a. Tier scale and economics
- ⚠ Only ~5.4% of App Store apps are paid (premium)
- ⚠ ~98% of iOS app revenue comes from freemium / subscription / IAP
- Sources: [SQ Magazine App Store Statistics](https://sqmagazine.co.uk/app-store-statistics/), [Coinlaw App Revenue Statistics](https://coinlaw.io/app-revenue-statistics/)

> **Critical context for partnership pitch**: The headline "iOS gaming is dominated by F2P" stat is correct in aggregate but irrelevant to a $4.99-$9.99 premium narrative app. Our tier behaves like a different product category.

### 3b. Apple Small Business Program (the multiplier finding)
- ⚠ Developers earning ≤$1M proceeds in prior calendar year pay **15% commission** instead of 30%
- ⚠ Applies to paid downloads, IAP, and subscriptions
- ⚠ Re-qualification is annual
- Source: [Apple Developer SBP page](https://developer.apple.com/app-store/small-business-program/), [RevenueCat SBP guide](https://www.revenuecat.com/blog/engineering/small-business-program/)

> **Material to forecast math**: For 5PFH at indie scale, iOS net multiplier is **0.85**, not 0.70. This is a 21% upward revision to iOS revenue projections vs. assuming Steam-equivalent fees.

### 3c. Premium iOS narrative comparables (sourced)

| Product | Studio | Year(s) | iOS Price | Public revenue/sales data | Verification |
|---|---|---|---|---|---|
| King of Dragon Pass iOS | A Sharp / HeroCraft | 2011 launch | $9.99 historical | 30,000 copies sold by March 2013; 150,000+ all-platform lifetime; A Sharp publicly stated iOS "much more commercially successful than the original PC release" | ⚠ AGENT-INFERRED via [Wikipedia: KoDP](https://en.wikipedia.org/wiki/King_of_Dragon_Pass), ✓ blog [geographic breakdown](https://kingofdragonpass.blogspot.com/2011/11/sales-breakdown.html) |
| Six Ages: Ride Like the Wind | A Sharp / HeroCraft | 2018 iOS, 2019 Steam | $9.99 iOS / $19.99 Steam | 20K-50K Steam owners (SteamSpy estimate); 96% positive Steam | ⚠ AGENT-INFERRED via [Wikipedia: Six Ages](https://en.wikipedia.org/wiki/Six_Ages:_Ride_Like_the_Wind), [SteamSpy](https://steamspy.com/app/881420) |
| Six Ages 2: Lights Going Out | A Sharp | 2023 simul iOS/Steam | $9.99 iOS / $24.99 Steam | 96% positive Steam, universal acclaim Metacritic; revenue not disclosed | ⚠ AGENT-INFERRED via [TouchArcade review](https://toucharcade.com/2023/08/23/six-ages-2-review-mobile-steam-pc/) |
| Slay the Spire iOS | Mega Crit | 2020 iOS port (PC 2017) | $9.99 launch | App Store Editor's Choice; 1.5M+ all-platform pre-mobile (March 2020); Slay the Spire 2 hit 3M week-one (April 2025); mobile-specific not disclosed | ⚠ AGENT-INFERRED via [Wikipedia: Slay the Spire](https://en.wikipedia.org/wiki/Slay_the_Spire) ✓, [TouchArcade](https://toucharcade.com/2020/06/13/slay-the-spire-ios-impressions-available-now-price-download-android-coming-later/) |
| 80 Days | Inkle | 2014 iOS | $4.99-$6.99 | IGF "Excellence in Narrative" 2015, 4 BAFTA nominations; revenue not disclosed | ⚠ via [Wikipedia: 80 Days](https://en.wikipedia.org/wiki/80_Days_(2014_video_game)) |
| Heaven's Vault | Inkle | 2019 PC/PS, iOS later | $9.99-$14.99 iOS / $24.99 Steam | Critical acclaim; revenue not disclosed | ✗ |
| Reigns / Reigns: Her Majesty | Devolver / Nerial | 2016/2017 | $2.99-$3.99 | Strong critical reception; sales not disclosed | ✗ |
| Choice of Games catalog | Choice of Games | 2010+ | $1.99-$5.99/title | 100+ interactive novels; revenue not disclosed | ✗ |

### 3d. Key takeaway on premium iOS revenue data
**Premium narrative iOS is revenue-opaque but durable.** Almost no studio in this space publishes unit data. KoDP's 30K iOS / 150K total is the most concrete number we have, and it's 13 years old. **Six Ages and Slay the Spire are the strongest contemporary peers** — both still on the App Store after 5+ years, both at $9.99, both critically lauded. The longevity is itself the data point.

---

## 4. Apple Ecosystem Cross-Purchase Behavior

### 4a. Universal Purchase (the load-bearing strategic decision)
- ⚠ Apple's developer-side feature lets ONE App Store SKU cover iOS + iPadOS + macOS + tvOS + visionOS as a single purchase tied to Apple ID
- Source: [Apple Developer Universal Purchase glossary](https://developer.apple.com/help/glossary/universal-purchase/), [TechCrunch coverage](https://techcrunch.com/2020/02/05/apple-unifies-its-app-stores-by-extending-the-universal-purchase-option-to-mac-apps/), [Apple Developer news](https://developer.apple.com/news/?id=03232020b)

> **STRATEGIC IMPLICATION**: Universal Purchase complicates the "two SKU sales per Apple user" thesis. If we ship via Universal Purchase, one Apple-household buyer pays once for Mac+iPhone+iPad. We do NOT get two SKU sales — we get one sale that runs on three devices. **To preserve cross-purchase math, ship Steam-Mac SKU + iOS App Store SKU as separate channels.**

### 4b. Steam-Mac vs. Mac App Store
- ✗ No public data on Mac gamer split between Steam and Mac App Store
- Anecdotally: indies often ship paid premium Mac builds via BOTH Steam and Mac App Store as separate SKUs
- A Mac+iPhone household buying both stores' versions IS two sales (Steam macOS + iOS Universal Purchase)
- **This is the configuration that supports the developer's cross-purchase thesis**

### 4c. Cross-device household ownership data
- ⚠ ~80% of iPhone users own at least one other Apple device
- ⚠ US households average 2.4 Apple devices (up from 1.8, ~31% growth)
- ⚠ ~20% of US internet households own ≥3 Apple-brand device types
- ⚠ 60% of multi-device Apple users use Continuity features daily
- ⚠ Multi-device Apple ownership peaks at **58% in the 25-44 age cohort** (5PFH wheelhouse)
- Sources: [TechLila](https://www.techlila.com/the-apple-ecosystem-lock-in-statistics/), [TechRT](https://techrt.com/apple-ecosystem-usage-statistics/), [Parks Associates](https://www.parksassociates.com/blogs/press-releases/apple-is-the-leading-ecosystem-with-nearly-20-of-us-internet-households-owning-3-apple-brand-device-types), [Statista](https://www.statista.com/chart/31973/likelihood-of-iphone-users-using-other-apple-devices/), [9to5Mac](https://9to5mac.com/2023/02/08/how-many-devices-apple-customers-own/)

### 4d. Strategic read on cross-purchase thesis
- **Defensible bounded version**: "Of the Mac users on Steam who buy our macOS build, a high majority are iPhone owners — so Steam macOS sales are a leading indicator for incremental iOS App Store sales of the same product, when shipped as a separate iOS SKU."
- **NOT defensible maximalist version**: "Every Apple user buys it twice" — Universal Purchase exists, and many users default to single-platform play.

---

## 5. Income and Willingness-to-Pay

### 5a. iOS vs. Android premium WTP gap
- ✗ **Specific contemporary numbers not surfaced** for 2025-2026
- Directional consensus across Sensor Tower, data.ai, RevenueCat reporting: iOS users pay more per app than Android users on premium content
- Source caveat: Use as directional argument, not quantified claim

### 5b. Apple-user income skew
- ✗ **No specific verified income-by-platform figure** surfaced for 2026
- Anecdotal/widely-cited but not citable to a single primary source
- **Conservative pitch language**: "Apple-platform gamers are widely understood to skew higher income; this supports our premium-tier pricing without requiring a precise multiplier"

---

## 6. Universal Purchase / SKU Strategy Decision Matrix

The single most strategically important decision from this research:

| Configuration | Pros | Cons | Recommended? |
|---|---|---|---|
| **Steam-Mac SKU + iOS App Store SKU (separate)** | Preserves cross-purchase math; Mac gamers buy through Steam where they already are; two-channel revenue; iPad-included via App Store Universal Purchase | Two builds to maintain | **✅ YES — this is the right config** |
| iOS App Store with full Universal Purchase (no Mac App Store, no Steam-Mac) | Simpler — one SKU for Apple ecosystem | LOSES Steam-Mac audience entirely; Mac gamers don't typically use Mac App Store for paid games | ❌ NO |
| Steam-Mac + iOS App Store + Mac App Store with Universal Purchase | Maximum coverage | Three SKUs; Mac App Store audience small for paid premium; complicates accounting | ⚠ Probably no — small upside for big complexity |
| iOS App Store with iPad-only Universal Purchase, no macOS | iPad-friendly extension; reduced scope | Loses macOS market entirely | ⚠ Acceptable if Mac App Store skipped anyway |

**RECOMMENDED: Steam-Mac SKU + iOS App Store SKU with iPad-included Universal Purchase**. This gives:
- Mac gamers via Steam (where they actually buy)
- iPhone + iPad via single App Store purchase (Universal Purchase covers both)
- No Mac App Store overhead (small audience for paid premium)
- Preserves cross-purchase math AND iPad accessibility

---

## 7. Synthesis — Forecast Updates

### 7a. Five updates to fold into `MODIPHIUS_DIGITAL_FORECAST.md`

1. **macOS Steam share = 2.01% (April 2026)**, not 3%. ✓ VERIFIED. Update §5/§6 if oversized.
2. **Apple Small Business Program changes iOS multiplier from 0.70 to 0.85.** Update §6 to reflect platform-specific economics. Material to break-even math: every iOS dollar is 85¢ net to partnership until $1M proceeds threshold.
3. **Universal Purchase is a SKU-strategy decision, not a market reality.** Document the Steam-Mac + iOS App Store separate-SKU configuration as the recommended approach. Add §6d "SKU strategy decision."
4. **Premium narrative iOS peers are revenue-opaque but durable.** KoDP, Six Ages 1+2, Slay the Spire all hold $9.99 iOS pricing 5+ years post-launch with ongoing 90%+ ratings. The longevity is the data point. Add to §6c mobile pocket edition section as proof-of-category-durability.
5. **Cross-purchase thesis: defensible in the bounded form.** ~80% of iPhone users own another Apple device, ~58% multi-device concentration in 25-44 demo. Supports "Steam-macOS conversion is a leading indicator for iOS conversion among the same buyer pool" — NOT "every Apple user buys twice."

### 7b. Comparable products to cite in Modiphius pitch

The cleanest "this works at indie scale" proof points:
1. **Six Ages 2: Lights Going Out (2023)** — direct pricing-strategy precedent ($9.99 iOS / $24.99 Steam simultaneous launch; universal acclaim)
2. **Slay the Spire iOS (2020)** — proves premium PC-to-iOS porting at $9.99 tier works (Editor's Choice + ongoing sales)
3. **King of Dragon Pass iOS** — explicit narrative-format ancestor; A Sharp publicly stated iOS outsold the original PC release

### 7c. Caveats for negotiation use
- Every revenue figure in the peer matrix is either developer-disclosed in passing or a third-party estimate
- The closest publicly-citable indie premium narrative iOS revenue number is KoDP's "30K iOS copies by 2013" — old enough to hedge in any Modiphius-facing document
- Per-capita Mac-vs-Windows Steam ARPU thesis is plausible but unsourced; do not quote a multiplier in correspondence

---

## 8. Sources Index

- [Steam Hardware Survey April 2026](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam) ✓ VERIFIED
- [Apple Universal Purchase glossary](https://developer.apple.com/help/glossary/universal-purchase/)
- [Apple Universal Purchase rollout (TechCrunch 2020)](https://techcrunch.com/2020/02/05/apple-unifies-its-app-stores-by-extending-the-universal-purchase-option-to-mac-apps/)
- [Apple Universal Purchase developer news](https://developer.apple.com/news/?id=03232020b)
- [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [Small Business Program guide (RevenueCat)](https://www.revenuecat.com/blog/engineering/small-business-program/)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/)
- [Apple Gaming Wiki — GPTK](https://www.applegamingwiki.com/wiki/Game_Porting_Toolkit)
- [Wikipedia: King of Dragon Pass](https://en.wikipedia.org/wiki/King_of_Dragon_Pass)
- [KoDP geographic sales breakdown blog](https://kingofdragonpass.blogspot.com/2011/11/sales-breakdown.html) ✓ VERIFIED
- [Wikipedia: Six Ages: Ride Like the Wind](https://en.wikipedia.org/wiki/Six_Ages:_Ride_Like_the_Wind)
- [SteamSpy: Six Ages](https://steamspy.com/app/881420)
- [TouchArcade: Six Ages 2 review](https://toucharcade.com/2023/08/23/six-ages-2-review-mobile-steam-pc/)
- [Wikipedia: Slay the Spire](https://en.wikipedia.org/wiki/Slay_the_Spire) ✓ VERIFIED
- [TouchArcade: Slay the Spire iOS launch](https://toucharcade.com/2020/06/13/slay-the-spire-ios-impressions-available-now-price-download-android-coming-later/)
- [Inkle Studios](https://www.inklestudios.com/)
- [Wikipedia: 80 Days](https://en.wikipedia.org/wiki/80_Days_(2014_video_game))
- [Wikipedia: Reigns: Her Majesty](https://en.wikipedia.org/wiki/Reigns:_Her_Majesty)
- [Choice of Games](https://www.choiceofgames.com/)
- [SQ Magazine App Store Statistics 2026](https://sqmagazine.co.uk/app-store-statistics/)
- [Coinlaw App Revenue Statistics 2025](https://coinlaw.io/app-revenue-statistics/)
- [RevenueCat State of Subscription Apps 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/)
- [TechLila: Apple Ecosystem Lock-In Statistics](https://www.techlila.com/the-apple-ecosystem-lock-in-statistics/)
- [TechRT: Apple Ecosystem Usage Statistics](https://techrt.com/apple-ecosystem-usage-statistics/)
- [Parks Associates: Apple connected home](https://www.parksassociates.com/blogs/press-releases/apple-is-the-leading-ecosystem-with-nearly-20-of-us-internet-households-owning-3-apple-brand-device-types)
- [Statista: iPhone-anchored Apple ecosystem](https://www.statista.com/chart/31973/likelihood-of-iphone-users-using-other-apple-devices/)
- [9to5Mac: Apple devices per customer](https://9to5mac.com/2023/02/08/how-many-devices-apple-customers-own/)

---

## 9. Verification Log

| Date | Verified By | Claim | URL | Status |
|---|---|---|---|---|
| 2026-05-06 | Claude (research agent) | macOS share 2.01% Steam Hardware Survey April 2026 | Steam Hardware Survey | ✓ VERIFIED via direct URL fetch |
| 2026-05-06 | Claude (research agent) | KoDP geographic breakdown blog | kingofdragonpass.blogspot.com | ✓ VERIFIED via direct URL fetch |
| 2026-05-06 | Claude (research agent) | Slay the Spire Wikipedia | en.wikipedia.org | ✓ VERIFIED via direct URL fetch |
| 2026-05-06 | Claude (research agent) | All other claims in §3, §4, §5 | Various | ⚠ AGENT-INFERRED — search-result reported, URL not directly fetched |

> **To upgrade a claim from `⚠ AGENT-INFERRED` to `✓ VERIFIED`**: fetch the cited URL, read the relevant section, confirm the specific claim matches the source, then update the marker and add a row to this table.

---

## 10. Known Gaps and Caveats

- ✗ **No public Mac-vs-Windows Steam ARPU data.** Use directionally only — do not cite a specific multiplier
- ✗ **No publicly disclosed indie premium narrative iOS revenue beyond KoDP's 13-year-old number.** Six Ages, Slay the Spire iOS, Inkle catalog — none publish revenue
- ⚠ **Cross-device ownership stats are aggregate from third-party research firms** (Parks Associates, TechLila, TechRT). Underlying methodology not always transparent — verify before quoting specific percentages in binding correspondence
- **Apple Small Business Program is conditional** — re-qualification annual, $1M proceeds threshold means once we cross that mark, multiplier reverts to 0.70
- **Recency caveat**: Research conducted 2026-05-06. Apple Developer Program terms can change; verify SBP eligibility before contract signing
