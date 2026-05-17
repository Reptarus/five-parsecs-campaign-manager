# Closed Alpha Plan — 5PFH Digital v0.9.7

**Owner**: Elijah Rhyne
**Created**: 2026-04-29 (post Modiphius meeting)
**Target kickoff**: Mon May 25, 2026 (or May 18 if A0 sanity-check passes early)
**Window**: 6 weeks (May 25 → Jul 6, 2026)
**Cohort**: 10-20 testers from Ivan's private playtesting Discord
**Distribution**: signed Windows .exe via Discord/Drive
**Build cadence**: weekly (Mondays)
**Status**: DRAFT v1 — for review with Ivan before kickoff

---

## 1. What This Alpha Is

This is the closed alpha phase for the **5PFH Digital** app — the partnership-blessed digital version of Five Parsecs From Home, currently in development with Modiphius for Steam Early Access launch in Q3-Q4 2026.

The alpha has **two goals**, equal weight:

1. **Find blocking bugs** before we open it up wider. Crashes, save corruption, mode interactions, anything that breaks the experience.
2. **Help us figure out what's worth paying for**. The app does a lot — campaign creation, multi-phase turns, battle assistance, character events, multiple game modes (Standard 5PFH, Bug Hunt, Planetfall, Tactics). We need testers who know the tabletop game to tell us **which parts feel valuable enough to justify a paid app** and which parts feel like noise.

Bug-finding is the obvious part. The pricing-validation part matters more long-term — the testers that complete this alpha shape what the Steam EA build looks like.

---

## 1.5 Alpha-1 vs Alpha-2 Scoping (added 2026-05-01)

**Alpha-1 scope (this document covers May 25 → Jul 6):** Standard 5PFH 9-phase campaign mode + the 3 Compendium DLC packs (33 ContentFlags) only.

**Deferred to alpha-2 or beta:** Bug Hunt gamemode (38 files), Planetfall gamemode (63 files), Tactics gamemode (59 files), cross-mode isolation testing, character-transfer service.

**Why narrow alpha-1 to one game mode + DLC layered on top:**

- The Standard 5PFH surface is the most-tested in the codebase (925/925 data values verified, 18+ MCP test sessions, Sessions 47-59 deep-dive coverage). Alpha-1 stresses the highest-confidence surface first.
- Alpha-1 validates the *alpha process* + the *price-point of the core experience*, not catalog breadth. Cohort size (10-20 testers) is appropriate for one-mode depth, not four-mode breadth.
- Pricing-band convergence (Gate 4) anchors to "Standard 5PFH + Compendium DLC". When alpha-2 widens the surface, testers re-anchor higher (more content = more value), so alpha-1's band becomes the EA price *floor*, not its ceiling.
- Alpha-2 (post-refinement, late Jul or Aug) widens the surface once the alpha *process* is proven.

**Operational impact on this plan:**

- §6 mid-alpha checkpoint reads only Standard 5PFH retention/comprehension data (not 4-mode comparison)
- §7 graduation gates measure against Standard 5PFH only
- §10 risk register's "Modiphius wants formal NDA after alpha starts" applies to alpha-1; alpha-2 may be re-scoped
- §11 open items are alpha-1 specific

Alpha-1 QA execution detail lives in [`docs/testing/ALPHA_1_QA_PLAN.md`](testing/ALPHA_1_QA_PLAN.md). Alpha-1 readiness workback (May 1 → May 25) lives in `C:\Users\admin\.claude\plans\warm-weaving-llama.md`.

---

## 2. Tester Profile

### Who's a good fit

- Someone who has played 5PFH on the tabletop (any game mode — Standard, Bug Hunt, Planetfall, Tactics)
- Patient with rough edges — this is alpha, not beta
- Willing to give blunt feedback (not "this is great" — what's *broken* and what's *missing*)
- Can run the build for 2-3 sessions per week across 6 weeks
- Comfortable using Discord for bug reports and weekly debriefs

### Who's not a good fit

- Folks who haven't played the tabletop game (the app is a campaign manager — without ground truth, feedback is shallow)
- Anyone expecting polish (the app works, but UX rough edges exist)
- Streamers / content creators (this is closed alpha — no public coverage until beta or later; see §6)

### Recruitment

- **Source**: Ivan's private playtesting Discord community
- **Target size**: 10-20 testers
- **Recruitment timing**: Phase A.2 (week of May 5-11, 2026)
- **Coordinated by Ivan** — he knows his community better than I do

---

## 3. What Testers Get

### Build distribution

- **Windows-only for alpha** (signed .exe distributed via Discord pinned link or shared Drive folder)
- Mac/Linux support deferred to beta (Phase D)
- Build size: ~150-200MB
- Defender whitelist instructions included in the onboarding doc — no code-signing cert at this stage, so first launch may flag SmartScreen

### What's included in the alpha build

- All four game modes operational: Standard 5PFH, Bug Hunt, Planetfall, Tactics
- Full campaign creation (7-phase wizard) + 9-phase campaign turns
- Battle assistant (TacticalBattleUI), Battle Simulator standalone mode
- 925/925 Core Rules data values verified, 170/170 game mechanics implemented
- Story Track, Character Events, Red & Black Zone Jobs
- Save/load, journal, accessibility settings (4 colorblind modes, reduced motion, font size)

### What's NOT in the alpha (yet)

- DLC paywall enforcement is OFF — testers see all Compendium content unlocked (helps gather feedback on full scope)
- No purchase flows (Steam/iOS/Android adapters disabled; the test build runs in offline mode)
- No telemetry by default — opt-in toggle on first run, default OFF, anonymous if enabled

### Privacy + NDA

- **No formal NDA** — this is a gentleman's agreement. Industry standard for indie closed alphas.
- **Don't post screenshots, streams, or recordings publicly** until we open beta or later
- Talking with friends about it is fine; sharing the build is not
- One exception: **don't reveal anything about Modiphius's other licensed projects** that comes up incidentally — that part is the only NDA-grade content
- Telemetry (if opted in) collects: session start/end, mode visits, save events, build crash logs. **No PII** — no email, no save content, no personal identifiers.

---

## 4. How Testers Give Feedback

### Discord-based feedback

Two structured channels in Ivan's Discord:

- **#5pfh-alpha-bugs** — bug reports, structured template (pinned at top of channel)
- **#5pfh-alpha-feedback** — open-ended thoughts, "what worked / what felt off / what's missing"

### Bug report template (pinned in #5pfh-alpha-bugs)

```
**Build version**: A1 / A2 / A3 / etc
**Game mode**: Standard / Bug Hunt / Planetfall / Tactics
**What happened**: [1-2 sentences]
**What you expected**: [1-2 sentences]
**Repro steps**: 1) ... 2) ... 3) ...
**Save file** (if applicable): attach
**Screenshot/video** (optional): attach
**Severity**: P0 (game-breaking) / P1 (major UX issue) / P2 (annoying) / P3 (cosmetic)
```

### Weekly debriefs

- **30-min Discord voice call**, rotating 2-3 testers per week
- Casual conversation — what they played that week, what stood out, what felt rough
- I take notes; don't expect testers to take notes
- First debrief end of week 1; final debrief end of week 6

### Pricing-perception survey

- Single in-app survey at session-end (5-7 questions, <3 min)
- Asks at-the-time pricing questions when context is fresh, not in retrospect
- Optional, but encouraged at end of session
- Replicated as a Google Form for testers who prefer that

---

## 5. Build Cadence

### Weekly drops, Mondays at 10AM Pacific

- **Build A0** (release-candidate, sent to Ivan only) — Wed May 20 for sanity-check
- **Build A1** — Mon May 25 — kickoff, distributed to full cohort
- **Build A2** — Mon Jun 1
- **Build A3** — Mon Jun 8 (mid-alpha checkpoint week)
- **Build A4** — Mon Jun 15
- **Build A5** — Mon Jun 22
- **Build A6** — Mon Jun 29 — final build, week ends Jul 6

### What's in each build

- A1: kickoff baseline (current `master` + alpha branding + telemetry scaffolding)
- A2-A6: weekly fixes + small improvements, **no new features**
- P0/P1 hotfixes between weekly builds as needed (out-of-band, same Discord channel)

### What's NOT in builds

- New features. Alpha refines what exists, doesn't expand scope.
- The only exception: telemetry / survey scaffolding (foundational infrastructure — must be in by A1).

---

## 6. Mid-Alpha Checkpoint (Week 3, Jun 8-14)

By the end of week 3, the data should tell us:

- Which game mode is testers' favorite (Standard / Bug Hunt / Planetfall / Tactics)
- Which features feel "must have" vs "I'd skip this"
- Pricing perception range (rough — converging toward a band, not a single number yet)
- Top 3 P0/P1 bug categories (so weeks 4-6 can focus there)
- **Category-perception data** (see §6.1 below) — what testers *call* the product

**Mid-alpha decision**: re-prioritize the back-half of alpha around the price-justifying anchor. If retention is strong on one game mode and weak on another, the strong one gets polish first.

### 6.1 Category-perception probe (added Apr 30, ties to MUTUALLY AGREED THESIS T2)

The Apr 30 forecast deep-dive (`MODIPHIUS_DIGITAL_FORECAST.md` §11.1d) confirmed that 5PFH on Steam is **establishing a category** — solo-RPG/wargame digital companion apps essentially do not exist on Steam yet. Empty category = both moat AND discovery risk. Closed alpha is the cheapest way to validate which side dominates.

**What we collect**:

- **Open-ended language probe (Week 1, Week 3, Week 6)**: ask testers verbatim "How would you describe this app to a friend in one sentence?" Capture the *exact words* they use. Do not lead them. Do not offer suggestions. Repeat at three checkpoints to track language drift as familiarity grows.
- **Forced-choice category probe (Week 3, Week 6)**: present 5-6 candidate category labels and ask testers which fits best. Candidates: "campaign manager", "solo RPG companion", "digital edition", "tabletop assistant", "campaign tracker", "gamemaster tool". Track distribution.
- **Discovery hypothetical (Week 6)**: "If you were searching the Steam store for an app like this, what would you type into search?" — captures real Steam discovery keywords from the audience that already plays the game.

**What we do with the data**:

- Feeds directly into the Phase C **Steam-store-positioning brief** (capsule images, store-page copy, "Why Early Access?" answers, search keywords)
- The words testers use become the words on the store page — not the words we'd use internally
- If language *converges* across testers → category is forming, store positioning has clear targets, low discovery risk
- If language *diverges* widely → category is unstable; risk of audience-confusion in Steam discovery; needs marketing clarity work before EA

**Owner**: Elijah captures, Ivan helps moderate during Discord debriefs. **Output**: `docs/CATEGORY_PERCEPTION_REPORT.md` (alongside `PRICING_PERCEPTION_REPORT.md`) at end of alpha.

---

## 6.5 Digital→Physical Conversion Mechanism Specs (added Apr 30, ties to MUTUALLY AGREED THESIS T4)

The Apr 30 forecast deep-dive (`MODIPHIUS_DIGITAL_FORECAST.md` §11.5a) established 5 in-app conversion mechanisms designed to drive Steam users toward physical book purchases. These are now Phase B alpha deliverables — must be designed, prototyped, and at least mocked-up by alpha kickoff so testers can react to them.

| Mechanism | Phase B deliverable | Where it lives in the app |
|---|---|---|
| **Discount code for physical book** | Mock dialog at first-launch + Settings → "Get the Book" entry. Real discount code requires Modiphius coordination on sizing (15-20% placeholder, awaiting Gavin confirmation). | First-launch dialog, Settings, post-tutorial completion |
| **"Get the Physical Edition" CTA** | Persistent low-friction link with co-branded landing page mock-up. URL parameter to track Steam-source clicks if Modiphius store supports it. | Main menu footer, Help screen, post-campaign-completion screen |
| **Bundled-PDF reminder** | Tooltip / dialog that surfaces at the right moments — "physical includes free PDF — you don't lose your digital purchase if you upgrade to physical." | Compendium screen, expansion-purchase upsell flows |
| **Tier-locked physical pre-order incentives** | Lower-priority for alpha; mock-up only. Real implementation post-EA when expansions cycle. | Expansion pack store screen, news/updates panel (post-EA) |
| **Modiphius newsletter capture** | Optional opt-in flow with explicit consent (legal stack). Email + name → posted to Modiphius newsletter API once endpoint provided. | Settings, post-purchase success screens |

**Coordination with Modiphius required before alpha**:

- Discount code sizing (placeholder 15-20% in forecast §11.5a)
- Discount code generation/redemption mechanism (one-time codes? promo codes? URL parameter?)
- Co-branded landing page on Modiphius store (or generic store-link for alpha mock-up)
- Newsletter API endpoint or sign-up form URL

**Why these are alpha deliverables, not post-launch polish**:

T4 is one of the four mutually agreed strategic theses (see `MEETING_FOLLOWUPS_2026-04-29.md` §1.5). If the partnership pitch is "the app is a sales channel for the books, not a competitor to them," the app needs to *demonstrably execute on T4* before the Definitive Agreement gets signed (target Aug-Sep). Alpha is the cheapest place to validate that testers respond to the conversion mechanisms naturally, not as an afterthought.

**Owner**: Elijah designs and prototypes; coordinates with Gavin on Modiphius-side dependencies. **Tester signal we want**: do testers describe the mechanisms as "helpful" / "respectful" / "obvious" — or "annoying" / "pushy" / "salesy"? The latter means the mechanism placement / framing needs work before EA.

---

## 7. Alpha Graduation Gates

End-of-alpha success means **all six gates pass** (AND, not OR — five-out-of-six is a fail). If gates miss, alpha extends 2 weeks (not 4).

| # | Gate | Threshold |
|---|------|-----------|
| 1 | **Stability** | P0 = 0; P1 < 5; save/load round-trip clean across all 4 modes; <1 crash per 10 sessions |
| 2 | **Comprehension** | ≥80% of testers can describe the value prop in one sentence after 2 sessions |
| 3 | **Retention** | ≥60% of testers complete 3+ sessions; ≥40% reach Turn 5 in a campaign |
| 4 | **Pricing band converges** | Test feedback narrows perceived price range to ±$3, expected band $14.99-$24.99 |
| 5 | **Recommendation signal** | ≥7/10 testers say they'd recommend the app to a friend (NPS proxy) |
| 6 | **Bug discovery rate trending down** | New P1+ bugs/build declining by week 5 |

If any gate misses → extend alpha by 2 weeks; ship 2 more patches; re-evaluate.

---

## 8. After Alpha (What Happens Next)

- **Refinement phase (2 weeks, Jul 7 → Jul 20)**: I act on alpha findings. UX redesigns, bug fixes, scope decisions. No new testers. Marketing prep starts in parallel (capsule art commission, Coming Soon page draft).
- **Beta / Steam Playtest (6 weeks, Jul 21 → Sep 1)**: bigger cohort (100-200) via Steam Playtest. Wishlist accumulation begins. Localization decisions.
- **Marketing lock + EA prep (3 weeks, Sep 2 → Sep 22)**: store page populated, trailer cut, capsule art final, EA pricing locked.
- **Steam Early Access launch (target ~Sep 23-30)**: public release, Modiphius cross-promo, support channels live.
- **6-12 months in EA → 1.0 launch**: monthly minor / quarterly major content drops, then 1.0 with $5 price increase.

Closed alpha testers stay in the loop after alpha ends — invited to beta cohort, get acknowledgment in credits, early Steam keys at 1.0 if they want.

---

## 9. Communication Rhythm

| Channel | Frequency | Purpose |
|---------|-----------|---------|
| Build drops | Weekly Monday | Get latest into testers' hands |
| Bug reports | As-needed | Structured template, Discord channel |
| Open feedback | As-needed | Casual thoughts in dedicated channel |
| Tester debriefs | Weekly (rotating 2-3) | Voice call, casual, I take notes |
| Modiphius cadence | Weekly with Gavin | Status share, blockers surfaced |
| Mid-alpha checkpoint | Once, end of week 3 | Re-prioritize back-half of alpha |
| End-alpha report | Once, end of week 6 | Synthesis: pricing, retention, EA-ready scope |

---

## 10. Risks (Alpha-Specific)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cohort under-recruits (<10 testers) | Low | Med | Confirm count with Ivan in Phase A.2. If under 10, supplement with 2-3 trusted Modiphius community contacts before kickoff. |
| Tester fatigue / churn past week 5 | Med | Low | Weekly debriefs (rotating 2-3) keep engagement high. If a tester drops, don't replace mid-alpha — adjust expectations and proceed. |
| P0 bug discovered late (week 5-6) | Med | High | Hotfix builds permitted between weekly drops. If P0 surfaces in final week, extend by 1-2 weeks. |
| Pricing data inconclusive | Low | Med | Supplement with Prolific paid survey (n=200) running in parallel — broader cohort gives statistical confidence beyond 10-20 directional. |
| Tester can't get the build running (Defender, missing dependencies) | Med | Low | Onboarding doc with step-by-step Defender whitelist + dependency check. Discord channel for troubleshooting. |
| Tester leaks build / streams publicly | Low | Med | No-NDA gentleman's agreement covered in onboarding. Recovery: ask them to take it down; minor incident, don't escalate. |
| Modiphius wants formal NDA after alpha starts | Low | Med | Raise this in Apr 29 followup ask #4. Get answer before kickoff. |

---

## 11. Open Items Before Kickoff

To resolve in Phase A.2 (May 5-11) before alpha launches:

- [ ] Confirm exact cohort size with Ivan (target 10-20)
- [ ] Confirm Modiphius's NDA stance (per Apr 29 followup ask #4)
- [ ] Telemetry tooling decision (Talo vs GameAnalytics) — recommend Talo (Godot-native, open-source)
- [ ] Discord channel structure agreed with Ivan (use existing community channels or set up dedicated ones)
- [ ] Bug intake template finalized (pinned message draft)
- [ ] Pricing-perception survey questions finalized (separate `docs/PRICING_RESEARCH_PLAN.md`)
- [ ] Onboarding doc drafted (1-pager that ships with the build)
- [ ] A0 sanity-check build verified by Ivan before broader distribution

---

*Document drafted Apr 29 2026 post Modiphius meeting. Review with Ivan in Phase A.2 (week of May 5). Update as kickoff approaches.*
