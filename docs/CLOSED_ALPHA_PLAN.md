# Closed Alpha Plan — 5PFH Digital v0.9.7

**Owner**: Elijah Rhyne
**Created**: 2026-04-29 (post Modiphius meeting)
**Target kickoff**: TBD. Deferred by Modiphius on Jul 27 2026 (journal Entry #27, provisional); do not propose one. ~~Mon May 25, 2026~~
**Window**: 6 weeks from kickoff. ~~May 25 → Jul 6, 2026~~
**Cohort**: Google-Form signup funnel across the official Discord, Ivan's community and the 5PFH Facebook group (journal Entry #12; `docs/ALPHA_SIGNUP_FORM_QUESTIONS.md`). ~~10-20 testers from Ivan's private playtesting Discord~~
**Distribution**: Android via Google Play closed testing track (invite-only email allowlist under Modiphius's Play account). Build: `0.9.7-alpha1` (`project.godot:22`), AAB, min SDK 29 / Android 10+ (`export_presets.cfg:34`), target SDK 35 (`:35`), versionCode 18 (`:41`).
**Build cadence**: weekly (Mondays)
**Status**: DRAFT v2, updated 2026-09-21 (blockers re-checked at `ca6172011`; Alpha-1 scope is now enforced in the build, §1.5). Previously 2026-09-13 (status lines, §3 build facts, open items). Body otherwise still v1.
**Timeline stale (flagged 2026-06-18)**: every date below (the May 25 to Jul 6 window, the A0-A6 build cadence in §5, the §8 pipeline) predates the mobile-first re-pivot and has passed. Re-anchor the whole schedule once Modiphius commits a hard kickoff date (and Play Console access lands). Dates left in place until then.

**Blocking kickoff as of 2026-09-21** (detail in journal §3.0). ⚠ Nothing on this list moved between Sep 13 and Sep 21; Modiphius has not replied since Sep 11:

1. LOI on Modiphius letterhead — ⚠ **OVERDUE**: promised for Mon Sep 14 (Entry #32), never arrived, and two comment threads on the Doc are still open (Entry #34). Chased Sep 20 (Entry #35).
2. Play Console access for Elijah (asked Jun 18, Entry #21, no answer).
3. NDA stance for an invite-only cohort (§3 below).
4. Kickoff date from Modiphius.
5. A tester DLC unlock mechanism (engineering; §3 below).
6. The tester reward term (what a tester gets for completing). **Agreed in substance 2026-09-21** — the owner accepted Chris's "free access to the base app not paid extra content", so the clause is now in `docs/LOI_DRAFT.md:66` and nothing is left to negotiate. Still blocking only in the mechanical sense: Chris's LOI comment thread is unresolved and the letter has not issued, and the **duration** (permanent vs "free X months") has never been stated by either party. Tester-facing docs may carry the base-app grant once the letter issues; they may not state a duration.

---

## 1. What This Alpha Is

This is the closed alpha phase for the **5PFH Digital** app — the partnership-blessed digital version of Five Parsecs From Home, in development with Modiphius. Launch is Android through Google Play, and that is the only platform we can currently ship to: `steam_appid.txt` holds `480`, Valve's public Spacewar placeholder rather than a real App ID, and `export_presets.cfg` has no iOS preset at all (its three presets are Android, Linux and Windows Desktop). ⚠ Other platforms are aspiration, not plan. No alpha or tester-facing document may name one (owner instruction, 2026-09-21).

The alpha has **two goals**, equal weight:

1. **Find blocking bugs** before we open it up wider. Crashes, save corruption, mode interactions, anything that breaks the experience.
2. **Help us figure out what's worth paying for**. The app does a lot — campaign creation, multi-phase turns, battle assistance, character events, multiple game modes (Standard 5PFH, Bug Hunt, Planetfall, Tactics). We need testers who know the tabletop game to tell us **which parts feel valuable enough to justify a paid app** and which parts feel like noise.

Bug-finding is the obvious part. The pricing-validation part matters more long-term — the testers that complete this alpha shape what the launch build looks like.

---

## 1.5 Alpha-1 vs Alpha-2 Scoping (added 2026-05-01)

**Alpha-1 scope (this document covers May 25 → Jul 6):** Standard 5PFH 9-phase campaign mode + the 3 Compendium DLC packs (33 ContentFlags) only.

**Deferred to alpha-2 or beta:** Bug Hunt gamemode (38 files), Planetfall gamemode (63 files), Tactics gamemode (59 files), cross-mode isolation testing, character-transfer service.

✅ **This split is now ENFORCED IN THE BUILD (verified 2026-09-21 at `ca6172011`)** — it used to be a scoping intention this document held alone. `const A1_BUILD := true` (`src/ui/screens/mainmenu/MainMenu.gd:20`) drives `_apply_a1_scope()`, which rebinds the Co-op, Bug Hunt, Tactics and Planetfall menu buttons to a "Coming in a later release" note. So an Alpha-1 tester reaches the **Standard 5PFH campaign and the Battle Simulator**, and cannot reach the other four modes.

⚠ **The four buttons are still VISIBLE and still enabled**, dimmed via `modulate` and carrying a tooltip. That is deliberate and documented at the call site: a `disabled` Button emits no `pressed` signal, so it could never explain itself. **Testers will see four modes they cannot open** — the onboarding doc has to say so, or every tester files the same bug.

⚠ Alpha-1 scope is therefore NOT affected by the Bug Hunt Sprint 1 work committed Sep 20 (`d1e541ccb`, `ca6172011`). That sprint is Alpha-2 content and is out of tester reach; it does not change what this plan covers.

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

Alpha-1 QA execution detail lives in [`docs/testing/ALPHA_1_QA_PLAN.md`](testing/ALPHA_1_QA_PLAN.md). ~~Alpha-1 readiness workback (May 1 → May 25) lives in `C:\Users\admin\.claude\plans\warm-weaving-llama.md`.~~ (That file does not exist as of 2026-09-13.)

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

> ⚠ SUPERSEDED May 25 2026 (journal Entry #12): recruitment is the Google-Form funnel named in the header, not Ivan's Discord alone. The form goes live only after a Modiphius bias-check and once a kickoff date exists. Lines below kept for history.

- **Source**: Ivan's private playtesting Discord community
- **Target size**: 10-20 testers
- **Recruitment timing**: Phase A.2 (week of May 5-11, 2026)
- **Coordinated by Ivan** — he knows his community better than I do

---

## 3. What Testers Get

### Build distribution

- **Android-only for alpha** (installed through Google Play's closed testing track under Modiphius's Play account; testers opt in via an email-allowlisted link shared in Discord)
- Android only. No iOS preset and no Steamworks app exist, so no other platform is in scope or may be named
- Build size: Android App Bundle, target under 150MB
- Install steps in the onboarding doc: accept the Play test invite, then install from the Play listing. No Defender or SmartScreen step (that was the Windows path); the tester's Gmail must match the device they install on

### What's included in the alpha build

- Alpha-1 surface per §1.5: Standard 5PFH 9-phase campaign + the 3 Compendium DLC packs. Bug Hunt, Planetfall, and Tactics exist in the build but are out of alpha-1 testing scope (deferred to alpha-2)
- Full campaign creation (7-phase wizard) + 9-phase campaign turns
- Battle assistant (TacticalBattleUI), Battle Simulator standalone mode
- 925/925 Core Rules data values verified, 170/170 game mechanics implemented
- Story Track, Character Events, Red & Black Zone Jobs
- Save/load, journal, accessibility settings (4 colorblind modes, reduced motion, font size)

### What's NOT in the alpha (yet)

- ⚠ **CORRECTED 2026-09-13: the Compendium is NOT unlocked in the current build, and a tester has no way to unlock it.** `_owned_dlcs` starts empty (`src/core/systems/DLCManager.gd:128`) and `is_feature_enabled()` requires ownership (`:181-184`). The Settings "Manage Features" button only appears when something is already owned (`src/ui/screens/settings/SettingsScreen.gd:589`); the store card's "Manage Features" is the owned-state restyle of the buy button (`src/ui/screens/store/DLCPackCard.gd:252-255`); the only non-debug ownership writer is `src/ui/dialogs/DLCManagementDialog.gd:263`. The line this replaces ("DLC paywall enforcement is OFF, testers see all Compendium content unlocked") was a plan, never built. **Open item: choose an alpha unlock mechanism before A0** (§11).
- No purchase flows. The Android adapter reports an error and returns when no `BillingClient` class exists (`src/core/store/AndroidStoreAdapter.gd:23-25`). Billing is PARKED by owner decision pending the letterhead LOI (`docs/QA_STATUS_DASHBOARD.md:939-945`).
- No telemetry by default: analytics consent defaults to false (`src/core/legal/LegalConsentManager.gd:29`) and the Talo adapter drops events without it (`src/core/analytics/TaloAnalyticsAdapter.gd:92-93`).

### Privacy + NDA

> ⚠ UNRESOLVED as of 2026-09-13. Chris, May 8 (journal Entry #8): "We also get play testers to sign NDA's on tabletop closed beta projects. If they're open testing we don't." This alpha is invite-only, which is the closed case. Ask on the week-of-Sep-14 call. The "no formal NDA" line below is a draft position, not an agreed one.

- **No formal NDA** — this is a gentleman's agreement. Industry standard for indie closed alphas.
- **Don't post screenshots, streams, or recordings publicly** until we open beta or later
- Talking with friends about it is fine; sharing the build is not
- One exception: **don't reveal anything about Modiphius's other licensed projects** that comes up incidentally — that part is the only NDA-grade content
- Telemetry (if opted in) collects: session start/end, mode visits, save events, build crash logs. **No PII** — no email, no save content, no personal identifiers.

---

## 4. How Testers Give Feedback

### In-app bug reporter (built)

`src/ui/components/common/BugReportDialog.gd`, titled "Report a Bug" (`:77`). Six categories (`:24-29`), attaches the last 100 log lines (`:37`), saves to `user://bug_reports/` (`BugReportStore.gd:14`) and has a "Save & Copy" button (`:213`). Opened from the button beside the settings gear (`src/autoload/SettingsOverlay.gd:13,161`) and from Settings (`SettingsScreen.gd:730`). An optional Discord webhook exists but is off unless its gitignored config holds a URL (`BugReportWebhook.gd:32,51`).

### Discord-based feedback

Two structured channels in Ivan's Discord (⚠ channel home not decided since the funnel replaced the Ivan-only cohort):

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

> ⚠ **Platform note (2026-09-21)**: this section and §6.5 below were written in Apr 2026 against a Steam-first plan. **We have no Steamworks app** (`steam_appid.txt` holds `480`, Valve's public Spacewar placeholder rather than a real App ID, and `export_presets.cfg` has no iOS preset at all (its three presets are Android, Linux and Windows Desktop)). The category analysis itself is unaffected and is kept for that reason, but the storefront nouns have been generalised: read them as "whichever storefront we publish on", which today is Google Play. The one place the word mattered was the Week 6 discovery question, which is asked to a TESTER and now names no storefront.

The Apr 30 forecast deep-dive (`MODIPHIUS_DIGITAL_FORECAST.md` §11.1d) confirmed that 5PFH is **establishing a category** — solo-RPG/wargame digital companion apps essentially do not exist on the major storefronts yet. Empty category = both moat AND discovery risk. Closed alpha is the cheapest way to validate which side dominates.

**What we collect**:

- **Open-ended language probe (Week 1, Week 3, Week 6)**: ask testers verbatim "How would you describe this app to a friend in one sentence?" Capture the *exact words* they use. Do not lead them. Do not offer suggestions. Repeat at three checkpoints to track language drift as familiarity grows.
- **Forced-choice category probe (Week 3, Week 6)**: present 5-6 candidate category labels and ask testers which fits best. Candidates: "campaign manager", "solo RPG companion", "digital edition", "tabletop assistant", "campaign tracker", "gamemaster tool". Track distribution.
- **Discovery hypothetical (Week 6)**: "If you were searching an app store for an app like this, what would you type into search?" — captures real discovery keywords from the audience that already plays the game.

**What we do with the data**:

- Feeds directly into the Phase C **store-positioning brief** (capsule images, store-page copy, "Why Early Access?" answers, search keywords)
- The words testers use become the words on the store page — not the words we'd use internally
- If language *converges* across testers → category is forming, store positioning has clear targets, low discovery risk
- If language *diverges* widely → category is unstable; risk of audience-confusion in store discovery; needs marketing clarity work before launch

**Owner**: Elijah captures, Ivan helps moderate during Discord debriefs. **Output**: `docs/CATEGORY_PERCEPTION_REPORT.md` (alongside `PRICING_PERCEPTION_REPORT.md`) at end of alpha.

---

## 6.5 Digital→Physical Conversion Mechanism Specs (added Apr 30, ties to MUTUALLY AGREED THESIS T4)

The Apr 30 forecast deep-dive (`MODIPHIUS_DIGITAL_FORECAST.md` §11.5a) established 5 in-app conversion mechanisms designed to drive app buyers toward physical book purchases. These are now Phase B alpha deliverables — must be designed, prototyped, and at least mocked-up by alpha kickoff so testers can react to them.

| Mechanism | Phase B deliverable | Where it lives in the app |
|---|---|---|
| **Discount code for physical book** | Mock dialog at first-launch + Settings → "Get the Book" entry. Real discount code requires Modiphius coordination on sizing (15-20% placeholder, awaiting Gavin confirmation). | First-launch dialog, Settings, post-tutorial completion |
| **"Get the Physical Edition" CTA** | Persistent low-friction link with co-branded landing page mock-up. URL parameter to track in-app-source clicks if Modiphius store supports it. | Main menu footer, Help screen, post-campaign-completion screen |
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
| 4 | **Pricing band converges** | Test feedback narrows perceived price range to ±$3, expected band $14.99-$24.99. ⚠ SUPERSEDED Jul 27 2026: model approved as $9.99 one-time base + per-book unlocks (journal Entry #27, provisional). Gate needs rewriting against that model. |
| 5 | **Recommendation signal** | ≥7/10 testers say they'd recommend the app to a friend (NPS proxy) |
| 6 | **Bug discovery rate trending down** | New P1+ bugs/build declining by week 5 |

If any gate misses → extend alpha by 2 weeks; ship 2 more patches; re-evaluate.

---

## 8. After Alpha (What Happens Next)

> **Platform (2026-09-21, owner instruction): Android only.** We hold no Steamworks app and no iOS account: `steam_appid.txt` holds `480`, Valve's public Spacewar placeholder rather than a real App ID, and `export_presets.cfg` has no iOS preset at all (its three presets are Android, Linux and Windows Desktop). Neither is a plan, and neither may be named in tester-facing or Modiphius-facing material. ⚠ **The dated Steam pipeline that used to sit below is cut, not re-dated.** It named a "Beta / Steam Playtest (Jul 21 → Sep 1)" and a "Steam Early Access launch (target ~Sep 23-30)"; both dates have passed AND both described access we do not have, and there is nothing to re-anchor them to while kickoff is still TBD. The sequence below is kept because the ORDER of the phases is still right; every date in it is from the original May plan and is dead.

- **Refinement phase (2 weeks, Jul 7 → Jul 20)**: I act on alpha findings. UX redesigns, bug fixes, scope decisions. No new testers. Marketing prep starts in parallel (capsule art commission, Coming Soon page draft).
- **Beta (6 weeks, dates TBD)**: bigger cohort (100-200) through the same Google Play test route, widened. Localization decisions.
- **Marketing lock + launch prep (3 weeks, dates TBD)**: Play listing populated, trailer cut, feature graphic final, launch pricing locked.
- **Public release (date TBD)**: Google Play, Modiphius cross-promo, support channels live.
- **6-12 months in EA → 1.0 launch**: monthly minor / quarterly major content drops, then 1.0 with $5 price increase.

Closed alpha testers stay in the loop after alpha ends: invited to the beta cohort and acknowledged in credits. ⚠ This line used to end "early Steam keys at 1.0 if they want", cut 2026-09-21 because there is no Steamworks app to issue a key from.

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
| Tester can't install the build (Play opt-in confusion, device/OS-version compatibility, Gmail does not match device) | Med | Low | Onboarding doc with step-by-step Play opt-in flow; confirm each tester's Gmail matches their device; state the minimum Android version up front. Discord channel for troubleshooting. |
| Tester leaks build / streams publicly | Low | Med | No-NDA gentleman's agreement covered in onboarding. Recovery: ask them to take it down; minor incident, don't escalate. |
| Modiphius wants formal NDA after alpha starts | ~~Low~~ **Med** (2026-09-13) | Med | Chris's May 8 rule (NDAs for closed tabletop betas) points to an NDA for this cohort. Never answered. Ask on the week-of-Sep-14 call. |

---

## 11. Open Items Before Kickoff

Updated 2026-09-21 (was 2026-09-13). Original list said "resolve in Phase A.2 (May 5-11)". ⚠ Nothing here moved between Sep 13 and Sep 21; Modiphius has not replied since Sep 11.

- [ ] ~~Confirm exact cohort size with Ivan (target 10-20)~~ Superseded by the signup funnel; cohort size comes from form responses.
- [ ] Modiphius Play Console access confirmed (Elijah added to their Play account with rights to manage the closed test track + tester allowlist). **Asked Jun 18, never answered.**
- [ ] LOI received on Modiphius letterhead and diffed against the Google Doc before signing. ⚠ **OVERDUE** — promised for Mon Sep 14, never arrived (Entry #34); two comment threads on the Doc are also still open, so the Doc is not signable either
- [ ] Meeting with Chris. ⚠ The week-of-Sep-14 slot Chris proposed was **never scheduled**; chased Sep 20 with a fixed date about two weeks out, roughly Oct 2-6 (Entry #35). Ask for an intro to Cam
- [ ] Tester reward term closed in the LOI. Substance agreed 2026-09-21 (owner accepted Chris's "free access to the base app not paid extra content"; clause added at `docs/LOI_DRAFT.md:66`); what is unticked is Chris resolving the comment thread, the letter issuing with the clause intact, and the **duration** being stated at all
- [ ] Legal contact and marketing/social contact named (asked Aug 25; marketing "easier mid Sept")
- [ ] New kickoff date set by Modiphius and the schedule (header, §5 build cadence, §8 pipeline) re-anchored to it
- [ ] Confirm Modiphius's NDA stance (per Apr 29 followup ask #4; still open)
- [ ] **Alpha DLC unlock mechanism decided and built** (see §3; billing stays parked)
- [ ] Announcement draft + signup form get Modiphius's endorsement / bias-check pass
- [ ] 7 legal placeholders stay as-is until the LOI settles the terms (`docs/legal/POST_LOI_LEGAL_CHECKLIST.md`)
- [x] Telemetry tooling decision: Talo (consent-gated, `TaloAnalyticsAdapter.gd:92-93`)
- [ ] Discord channel structure agreed (funnel spans three communities, so where the alpha channels live is open)
- [x] Bug intake: in-app "Report a Bug" dialog built (§4). Pinned Discord template still optional.
- [ ] Pricing-perception survey questions finalized (separate `docs/PRICING_RESEARCH_PLAN.md`), rewritten for the $9.99 + per-book model
- [ ] Onboarding doc: drafted but stale for Android (see banner in `docs/testing/ALPHA_TESTER_ONBOARDING.md`)
- [ ] A0 sanity-check build verified before broader distribution

---

*Document drafted Apr 29 2026 post Modiphius meeting. Status lines, §3 and §11 updated 2026-09-13 against the build at `3b26b873d` and journal Entries #15-#33.*
