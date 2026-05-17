# Alpha-1 Regression Checklist

**Owner**: QA (Elijah Rhyne)
**Cycle**: Closed Alpha (Phase B), May 25 → Jul 6, 2026
**Created**: 2026-05-01
**Cadence**: Run before EVERY weekly build (A1 through A6) + every hotfix build before shipping to cohort.
**Estimated duration**: ~60 min full sweep + ~15 min focused if last build's full sweep passed clean.

**Purpose**: Mandatory per-build smoke + regression sweep that catches breakage in already-tested surfaces before a build reaches the cohort. Distinct from feature-specific test scenarios (S1-S15) which run more deliberately.

**Companion**: `ALPHA_1_ENTRY_EXIT_CRITERIA.md` PB-G2 references this doc; result feeds per-build TEST_EXECUTION_REPORT.

---

## Run instructions

1. **Set up clean state**: Wipe `user://` (or use a clean Windows VM) before starting
2. **Build artifact**: use the candidate build for the next ship (e.g., A2 candidate, before A2 distribution)
3. **Run the headless compile check FIRST** — if that fails, fix and rerun before continuing
4. **Run the manual smoke**: ~60 min, follow exact order (each section depends on the previous state)
5. **Capture results** in next per-build TEST_EXECUTION_REPORT (per `TEST_EXECUTION_REPORT_TEMPLATE.md` Regression Sweep section)
6. **Any FAIL = build does not ship until fixed**

---

## Section 0 — Headless compile (always first)

> **Setup**: replace `<GODOT_CONSOLE>` below with the path to your Godot 4.6 console binary, and `<PROJECT_ROOT>` with the absolute path to the project. The reference dev machine values are `C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe` and `c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager` — adjust for your environment.

```bash
"<GODOT_CONSOLE>" --headless --quit --path "<PROJECT_ROOT>" 2>&1
```

| Check | Pass criterion | Result |
|---|---|---|
| 0.1 — `--headless --quit` runs to completion | exit code 0; no compile errors | PASS / FAIL |
| 0.2 — No new push_error / push_warning since previous build | Diff vs previous-build log | PASS / FAIL |
| 0.3 — No new "Class hides an autoload singleton" warnings | grep stderr | PASS / FAIL |

**If any FAIL**: stop here, fix, rerun. Do not proceed.

---

## Section 1 — Build artifact + first launch (~5 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 1.1 | Build artifact size <200 MB | `ls -la build/FiveParsecsAlpha-A*.exe` | PASS / FAIL |
| 1.2 | .exe + .pck pair in same directory | file presence | PASS / FAIL |
| 1.3 | Cold launch <10 seconds on test machine | stopwatch | PASS / FAIL |
| 1.4 | First-launch flow: SmartScreen handled, EULA shows | manual | PASS / FAIL |
| 1.5 | EULA → Privacy → Analytics opt-in (default OFF) → MainMenu | manual chain | PASS / FAIL |
| 1.6 | `user://legal_consent.cfg` (sectioned ConfigFile) contains `[eula] accepted=true version="1.0"` and `[analytics] consent=false` | file inspection (open in text editor) | PASS / FAIL |
| 1.7 | Second launch goes directly to MainMenu (no consent re-prompt) | restart app | PASS / FAIL |

---

## Section 2 — MainMenu + navigation (~5 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 2.1 | MainMenu renders without visual regression vs previous build | screenshot diff | PASS / FAIL |
| 2.2 | "New Campaign" button → CampaignCreationUI loads | nav | PASS / FAIL |
| 2.3 | "Continue Campaign" button enabled only when save exists | conditional check | PASS / FAIL |
| 2.4 | "Battle Simulator" button → BattleSimulatorUI loads | nav | PASS / FAIL |
| 2.5 | "Library" / Compendium button → CompendiumScreen loads | nav | PASS / FAIL |
| 2.6 | "Settings" button → Expansions section visible inside SettingsScreen ([SettingsScreen.gd:400-435](../../src/ui/screens/settings/SettingsScreen.gd#L400)); "Browse Expansions" button → StoreScreen loads | nav | PASS / FAIL |
| 2.7 | "Settings" → SettingsScreen loads | nav | PASS / FAIL |
| 2.8 | Tutorial selection accessible | nav | PASS / FAIL |
| 2.9 | "Get Physical Edition" CTA visible in main menu footer (**available from build A2 onward — Phase 2.T6**; skip section on A0/A1) | scan UI | PASS / FAIL / N/A |

---

## Section 3 — Campaign creation 7-phase wizard (~10 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 3.1 | Phase 1 Config: difficulty + crew size + DLC toggles all interactable | manual | PASS / FAIL |
| 3.2 | Phase 2 Captain: character creator launches; species dropdown works; stats randomize | manual | PASS / FAIL |
| 3.3 | Phase 3 Crew: roster meets `campaign_crew_size` setting (4/5/6) | count check | PASS / FAIL |
| 3.4 | Phase 4 Equipment: starting equipment generated; matches Core Rules p.28 | equipment count + type | PASS / FAIL |
| 3.5 | Phase 5 Ship: ship assigned with hull/debt per Core Rules | property check | PASS / FAIL |
| 3.6 | Phase 6 World: starting world generated with traits | world panel renders | PASS / FAIL |
| 3.7 | Phase 7 Final Review: all data displayed; "Begin Campaign" button works | manual | PASS / FAIL |
| 3.8 | Created campaign saves to `user://saves/<name>.json` | file presence | PASS / FAIL |
| 3.9 | CampaignDashboard loads after creation completes | nav | PASS / FAIL |

---

## Section 4 — Compendium DLC toggle integrity (~10 min) [MOST CRITICAL]

This is the highest-risk surface for alpha-1. Test exhaustively per build.

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 4.1 | Settings → DLC management opens | nav | PASS / FAIL |
| 4.2 | All 33 ContentFlags listed (TT=7, FH=17, FG=9) | count | PASS / FAIL |
| 4.3 | "Enable Pack" toggle for Trailblazer's Toolkit enables all 7 TT flags | toggle + verify | PASS / FAIL |
| 4.4 | Krag + Skulker species appear in character creator after TT enabled | new char + species dropdown | PASS / FAIL |
| 4.5 | Toggle "Enable Pack" Freelancer's Handbook (17 flags) | toggle + verify | PASS / FAIL |
| 4.6 | Compendium difficulty toggles appear in config panel after FH enabled | manual | PASS / FAIL |
| 4.7 | Toggle "Enable Pack" Fixer's Guidebook (9 flags) | toggle + verify | PASS / FAIL |
| 4.8 | Stealth/Street/Salvage missions appear in world phase job pipeline after FG enabled | new turn → World Phase | PASS / FAIL |
| 4.9 | Mid-campaign disable Fixer's Guidebook does NOT crash | toggle while in campaign | PASS / FAIL |
| 4.10 | Save → reload → toggle state preserved | save+restart+verify | PASS / FAIL |
| 4.11 | All-OFF state: no DLC content visible anywhere | toggle all off + check | PASS / FAIL |

---

## Section 5 — Standard 5PFH 9-phase turn (~15 min)

Full single-turn cycle through all 9 phases.

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 5.1 | Phase 1 Story: story panel loads, advances, completes | manual | PASS / FAIL |
| 5.2 | Phase 2 Travel: travel options shown; rolling works; outcomes apply | manual | PASS / FAIL |
| 5.3 | Phase 3 Upkeep: cost calculation matches Core Rules p.76 (1 cr/crew + ship maintenance); pay/skip works | math check | PASS / FAIL |
| 5.4 | Phase 4 Mission: job offers display; selection routes to PreBattle correctly | manual | PASS / FAIL |
| 5.5 | Phase 5 Post-Mission: 14-step PostBattle pipeline completes | manual chain | PASS / FAIL |
| 5.6 | Phase 6 Advancement: XP applied; advancement options shown; selection commits | manual | PASS / FAIL |
| 5.7 | Phase 7 Trading: trade phase renders; buy/sell works; credits update | manual | PASS / FAIL |
| 5.8 | Phase 8 Character: character events fire if applicable; status_effects update | manual | PASS / FAIL |
| 5.9 | Phase 9 Retirement: retirement options shown; turn rollover triggers | manual | PASS / FAIL |
| 5.10 | Turn counter increments correctly after full cycle | check progress_data.turn_number | PASS / FAIL |

---

## Section 6 — Save / Load roundtrip (~5 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 6.1 | Save campaign mid-turn (after Phase 4 Mission, before battle) | file write | PASS / FAIL |
| 6.2 | Quit app | manual | PASS / FAIL |
| 6.3 | Reload save from MainMenu → "Continue" or save/load dialog | nav | PASS / FAIL |
| 6.4 | Pre-save credits == post-reload credits | dual-sync check | PASS / FAIL |
| 6.5 | Pre-save crew count == post-reload crew count | count | PASS / FAIL |
| 6.6 | Each crew member's stats preserved | per-character check | PASS / FAIL |
| 6.7 | Equipment per crew + ship stash preserved (BUG-035 regression) | inventory check | PASS / FAIL |
| 6.8 | Turn number preserved | property | PASS / FAIL |
| 6.9 | Campaign phase resumes correctly (not at Phase 1 again) | nav state | PASS / FAIL |
| 6.10 | DLC toggle state preserved across reload | settings panel | PASS / FAIL |

---

## Section 7 — Battle assistant (~5 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 7.1 | Mission selection → PreBattle UI loads with mission briefing | nav | PASS / FAIL |
| 7.2 | Crew selection shows only active (non-injured/dead/retired/departed) crew | filter check | PASS / FAIL |
| 7.3 | Tier selection overlay appears (LOG_ONLY / ASSISTED / FULL_ORACLE) | manual | PASS / FAIL |
| 7.4 | Selected tier activates correct panel visibility | manual | PASS / FAIL |
| 7.5 | Initiative roll works without crash | manual | PASS / FAIL |
| 7.6 | Battle resolves; result panel shows; transition to PostBattle works | manual chain | PASS / FAIL |

---

## Section 8 — Battle Simulator standalone (~3 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 8.1 | MainMenu → "Battle Simulator" → BattleSimulatorSetupPanel loads | nav | PASS / FAIL |
| 8.2 | Crew size + enemy + mission + difficulty all configurable | manual | PASS / FAIL |
| 8.3 | "Generate Battle" launches TacticalBattleUI | nav | PASS / FAIL |
| 8.4 | Battle resolves to results screen | manual | PASS / FAIL |
| 8.5 | "Play Again" works; "Main Menu" returns | manual | PASS / FAIL |

---

## Section 9 — Telemetry consent gate (~5 min)

> **Available from build A0 onward** — depends on Phase 0.6 C-track (Talo plugin install + CampaignAnalytics autoload + TaloAnalyticsAdapter). Skip section on builds before C-track lands.

CRITICAL — verify per build that the consent gate is enforcing correctly.

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 9.1 | Settings → Privacy → Analytics: shows current state | UI | PASS / FAIL |
| 9.2 | Set analytics OFF; trigger 5+ events (phase changes, feature usage) | manual + Talo dashboard | PASS / FAIL |
| 9.3 | Talo dashboard shows ZERO new events for current session_id during OFF window | dashboard | PASS / FAIL |
| 9.4 | Set analytics ON; trigger 5+ more events | manual + Talo dashboard | PASS / FAIL |
| 9.5 | Talo dashboard receives matching events within 60 seconds | dashboard | PASS / FAIL |
| 9.6 | Each event has anonymous session UUID (no name, email, IP, custom strings) | payload audit | PASS / FAIL |

---

## Section 10 — Surveys + Conversion mechanisms (~5 min)

> **Available from build A2 onward** — depends on Phase 2.T1 (PricingPerceptionSurvey), T5-T9 (5 conversion mechanisms). Skip individual rows where the underlying feature has not yet shipped; mark `N/A` rather than `FAIL` in that case.

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 10.1 | Pricing-perception modal appears at session-end (first time on this build version) | manual | PASS / FAIL |
| 10.2 | 4 VW questions appear in randomized order | manual + multiple sessions | PASS / FAIL |
| 10.3 | Submit succeeds; toast confirms; once-per-build persistence works | manual + relaunch | PASS / FAIL |
| 10.4 | Discount code dialog appears on first-launch + Settings → "Get the Book" | manual | PASS / FAIL |
| 10.5 | "Get Physical Edition" CTA visible in 3 placements (footer/Help/post-victory) | UI scan | PASS / FAIL |
| 10.6 | Bundled-PDF tooltip appears on hover/focus on Compendium screen + DLCPackCard | manual | PASS / FAIL |
| 10.7 | Pre-order incentive mockup visible in StoreScreen (greyed-out, non-interactive) | UI scan | PASS / FAIL |
| 10.8 | NewsletterOptInForm renders in Settings; email + name + consent checkbox all present | manual | PASS / FAIL |

---

## Section 11 — Crash auto-capture (~2 min)

> **Available from build A2 onward** — depends on Phase 2.T4 (CrashLogger autoload + `user://crash_logs/` directory). Skip section on A0/A1 builds; mark `N/A`.

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 11.1 | Trigger deliberate `assert(false)` in dev/debug build | manual | PASS / FAIL |
| 11.2 | Crash log file appears in `user://crash_logs/<timestamp>.txt` | file check | PASS / FAIL |
| 11.3 | Restart app | manual | PASS / FAIL |
| 11.4 | Crash dialog shown on next launch with file path + "Open Folder" button | manual | PASS / FAIL |
| 11.5 | "Open Folder" opens correct directory on Windows | manual | PASS / FAIL |

---

## Section 12 — GDPR data export + delete (~3 min)

| # | Check | Pass criterion | Result |
|---|---|---|---|
| 12.1 | Settings → Privacy → "Export my data" produces JSON manifest in `user://` | file | PASS / FAIL |
| 12.2 | JSON manifest lists all `user://` files with sizes | content audit | PASS / FAIL |
| 12.3 | Settings → Privacy → "Delete all data" with confirm prompt | UI | PASS / FAIL |
| 12.4 | Delete clears `user://` files | filesystem | PASS / FAIL |
| 12.5 | Next launch returns to first-launch consent flow | nav | PASS / FAIL |

---

## Result aggregation

After all sections run:

| Section | Pass | Fail | Skipped |
|---|---|---|---|
| 0 — Headless compile | / | / | / |
| 1 — First launch | / | / | / |
| 2 — MainMenu | / | / | / |
| 3 — Campaign creation | / | / | / |
| 4 — DLC toggle (CRITICAL) | / | / | / |
| 5 — Turn cycle | / | / | / |
| 6 — Save/Load | / | / | / |
| 7 — Battle assistant | / | / | / |
| 8 — Battle Simulator | / | / | / |
| 9 — Telemetry consent | / | / | / |
| 10 — Surveys + conversion | / | / | / |
| 11 — Crash capture | / | / | / |
| 12 — GDPR | / | / | / |
| **TOTAL** | / | / | / |

**Build ships if**: TOTAL fail count == 0 AND no Section 0/4/9 failures (compile, DLC toggle, telemetry consent are non-negotiable).

**Build does NOT ship if**: any failure in Section 0, 4, or 9 → fix and rerun. Other failures triaged into hotfix budget.

---

## Trend tracking

After each build, append the result row to a build-trend table maintained in the per-build `TEST_EXECUTION_REPORT-A<N>.md` Regression Sweep section. End-of-cycle, the synthesis report aggregates the trend.

---

*Checklist v1, 2026-05-01. Owned by QA. Update if new mandatory regressions emerge during alpha.*
