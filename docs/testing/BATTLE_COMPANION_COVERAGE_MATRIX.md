# Battle-Phase Companion — Coverage Matrix (SSOT)

**Sprint:** Battle-Phase Companion Comprehensiveness · **Started:** 2026-07-05
**Plan:** `C:\Users\admin\.claude\plans\commit-and-start-investigating-delightful-bentley.md`
**Scope (user-confirmed):** exhaustive matrix · 5PFH + Battle Simulator · fix + regression each bug.

This is the living single source of truth for the sprint. Every dimension VALUE below must reach
`PASS` or `FIXED`. Two coverage axes:

- **U (unit-test cell):** a gdUnit4 assertion locks the behavior/value.
- **R (runtime cell):** an MCP/tablet walk observed the surface render/fire correctly.
- **P (page-cite verified):** the value matches the Core Rules/Compendium PDF at the cited page.

Status legend: `PENDING` · `PASS` · `FAIL` (bug filed below) · `FIXED` (bug closed + regression) · `N/A`.

---

## Harness recipes

### H1 — Battle Simulator (desktop MCP, isolated companion)
`MainMenu → "Battle Simulator" (node BattleSimulator, ungated, no campaign) → BattleSimulatorSetupPanel
(Crew Size 3-6, Enemy Category/Type, Mission, Difficulty) → launch → TacticalBattleUI @ TIER_SELECT
(TierSelectionPanel) → SETUP → DEPLOYMENT → COMBAT (rounds) → RESOLUTION`.
- Combat mode is forced **play_on_table** (interactive companion) — Battle Simulator has no PreBattleUI.
- Disable `TransitionOverlay` (`visible=false`) before `take_screenshot` (existing gotcha).
- Reuse `reference_galaxy_log_mcp_verification_runbook` + `docs/sop/visual-runtime-verification.md`.

### H2 — 5PFH campaign PreBattleUI (integrated path, tablet + desktop)
`World Phase (Mission Prep) → Ready for Battle → PreBattleUI` picks BOTH:
- **Combat Mode** (`selected_representation_mode`): `play_on_table` / `no_minis` / `auto_resolve`
  (`PreBattleUI.gd:895-901`).
- **Tracking Level** (`selected_tier`): 0 LOG_ONLY / 1 ASSISTED / 2 FULL_ORACLE (`:822`; tier moved here
  from the old TacticalBattleUI overlay, `:31`). Auto-resolve greys out the tier radios (`:930`).
Then `Confirm Deployment → TacticalBattleUI` (tier pre-set, TIER_SELECT skipped) → … → PostBattle.

---

## Pre-found findings (from the planning review — verify, then fix in Phase 6)

| # | Finding | Location | Status |
|---|---------|----------|--------|
| F1 | **NOT A BUG (verified — my characterization was wrong).** ACCESS/ELIMINATE/SECURE are **player-driven by design**: their win states (1D6+Savvy access roll, killing a specific marked figure, holding the exact centre 2 rounds) can't be seen on the physical table, so `check_completion()` correctly returns false and they complete via the player's manual toggle in `VictoryProgressPanel` (`BattleObjectiveTracker.is_complete()` → `_manual_met`; row is `interactive:true, input_kind:bool`). Same companion pattern as the FIGHT_OFF counter. Already tested in `test_battle_objective_tracker.gd` (`test_uncovered_types_have_no_auto_completion`, `_uncovered_row_exposes_manual_toggle`). No fix — auto-completing them would BREAK the companion model. | `BattleObjectiveTracker.gd:174-186` | RESOLVED — not a bug |
| F2 | **NOT A BUG (verified).** Re-reading p.112: the Feral clause follows "Many opponent types will add a bonus or penalty" → it means **per-opponent-type** penalties (Alert −1), NOT the category-level Hired Muscle −1. Code skips only `enemy_type` for Feral = correct reading. Lock current behavior with a test. | `SeizeInitiativeSystem.gd:219` | RESOLVED — not a bug |
| F3 | **VALID ITEMS, cite wrong.** Compendium p.26 "Multi-wave scanner: +1 Seize the Initiative, cumulative with a party-carried Motion Tracker." Both `motion_tracker`/`scanner_bot` (+1) are real. Fix only the page-cite (Compendium p.26, not Core p.112). | `SeizeInitiativeSystem.gd:132,139` | RESOLVED — cite fix P5 |
| F4/F7 | **FIXED.** Committed PDF is canonical (user-confirmed). Re-verified each rule's printed page by footer: Seize = **p.112** (was p.117), Reaction Roll = **p.113** (was p.96), Deployment Conditions = **p.88** (was p.90/p.94/p.115), Notable Sights = **p.89** (was p.94). Morale **pp.114-118 was already correct** (I was off-by-one earlier). 14 cites fixed across 8 files, surgically (p.117 stays for the Battle Events table on p.117; p.94 stays for enemy encounters; p.90 stays for objectives). | `SeizeInitiativeSystem`, `InitiativeCalculator`, `BattleCalculations`, `BattleResolver`, `DeploymentConditionsSystem`, `NoMinisResolver`, `PreBattleChecklist`, `CampaignTurnController` | **FIXED** |
| F5 | **CONFIRMED BUG (Patrol unwinnable).** `check_completion()` requires `markers_checked >= 4`, but rulebook p.90 + `mission_objectives.json` + BattleFlowGuide all say **3** patrol points. Only 3 markers are ever placed → Patrol can never complete. | `MissionObjectiveSystem.gd:100`, `BattleObjectiveTracker.gd:29` | FIXED (P1 inline) |
| F6 | **CONFIRMED BUG (Move Through too hard).** `check_completion()` requires `crew_exited >= 3`, but rulebook p.90 + JSON + BattleFlowGuide all say **at least 2** crew. | `MissionObjectiveSystem.gd:98`, `BattleObjectiveTracker.gd:28` | FIXED (P1 inline) |
| F9 | **CONFIRMED BUG (device-only — Phase 4 tablet walk).** The Crew/Enemy Tracker drawer (`SlideOverDrawer` → `ScrollContainer`) does not vertical-touch-scroll on the tablet. Once several enemies are marked down, their FULL-height struck-through "ledger" cards inflate the list past the viewport and the last LIVE enemy's Mark-Down button falls off the bottom with no reachable control. Desktop mouse-wheel hides it — only the on-device touch walk surfaced it (blocked marking the 5th enemy). **Fix:** a DOWN figure now collapses to a compact one-line row (`_build_downed_unit_row`, control-free) so a full roster + casualties fits the viewport. **RE-VERIFIED ON-DEVICE (Test19, Jul 6):** marked down all 4 War Bots one-by-one — each collapsed to a compact `DOWN 0/4` row stacking in the top ~180px; the last LIVE enemy's Mark-Down stayed high in the viewport (no scroll). | `TacticalBattleUI.gd:_populate_unit_drawer` / `_build_downed_unit_row`; `SlideOverDrawer.gd:253` | **FIXED + on-device verified** (regression `test_tactical_downed_unit_row.gd`) |
| F10 | **CONFIRMED BUG (core-feature — Phase 4 tablet walk).** A PLAYED (non-auto-resolved) LOG_ONLY campaign battle had **no reachable control to end the battle or declare the mission objective.** Root cause: the pre-selected-tier fast path forces COMBAT for every tier (`initialize_battle` `:3446-3452`) yet the LOG_ONLY combat loop has no victory check (VictoryProgressPanel is ASSISTED+), no `end_battle()` caller anywhere in the codebase, and no results-form trigger. Only exits were top-bar **Auto Resolve** (simulates a battle played by hand) or **Return** (abandon). This is why the objective couldn't be marked on-device and why the earlier desktop check had to inject a tracker. **Fix (choice B):** keep the full LOG_ONLY companion + add an always-reachable emerald **Record Result** button (landscape toolbar + portrait ≡ menu) → opens `BattleResultsInputForm` (now objective-aware) → submit → `tactical_battle_completed` → PostBattle. LOG_ONLY no longer short-circuits to a bare form (`_on_checklist_dismissed`). **ON-DEVICE RE-TEST (Test18→20, Jul 6) surfaced TWO follow-up bugs the unit tests + `--headless` both passed — both now FIXED + on-device verified:** (F10-b) the Record Result drawer rendered EMPTY — the form wrapped its whole body in its own `SIZE_EXPAND_FILL` `ScrollContainer`, which reports ~0 min height, so the hug-to-content `SlideOverDrawer` collapsed to its 200px `MIN_PANEL_H` floor and clipped everything (objective + Submit invisible). Fix: drop the internal ScrollContainer — the drawer owns scrolling (`SlideOverDrawer.gd:122-125`); the form now reports natural height (~1480px, fits the 1840px landscape viewport). (F10-c) for a real **Deliver** battle the MISSION OBJECTIVE section was ABSENT — campaign mission dicts store the objective under `mission_data["objective"]` (String), but `_init_objective_tracker` reads only `mission_objective`/`objective_details` (so the tracker is null → empty prefill) and the form fell back to `objective_name` (also absent). Fix: form objective fallback now reads the `"objective"` key (same key the objective panel uses), id normalized to upper-case. (F10-d) with the MISSION OBJECTIVE section now present AND a full 6-crew roster, the form overran the viewport by ~1 button-row and the **Submit button fell off the bottom** — and the drawer's `ScrollContainer` does NOT vertical-touch-scroll on the tablet (same limitation the F9 fix works around), so a played objective battle was un-submittable. Fix: tighten the form's vertical spacing (main VBox `SPACING_SM`, panel margin `SPACING_LG`) so it FITS the viewport and Submit stays on-screen without scrolling. **(F10-e)** on-device (Test16, Eliminate battle) the submit worked and reached PostBattle, but the Record Result drawer **lingered on-screen over the PostBattle sequence** — `_on_log_only_results_submitted` emitted `tactical_battle_completed` without closing its own drawer. Fix: `.close()` the results drawer at the top of the submit handler (reuses the same `SlideOverDrawer.close()` the exclusive `_open_drawer` already calls) before the PostBattle hand-off. **Full end-to-end re-verified on-device (Test16, Jul 6, "Eliminate Mission [LOG ONLY]", Turn 4):** Record Result → full objective-aware form (MISSION OBJECTIVE "Eliminate" + "Objective achieved" checkbox, OUTCOME/ENEMIES/6-crew CASUALTIES+INJURIES, Submit all on one screen) → check objective → Submit → **PostBattle Sequence Step 14 of 14** (all 13 prior steps ✓; log shows "Payment received: 3 credits", "Loot found: Flak Gun", 6× "gained 3 XP", campaign event) — battle correctly resolved via the declared objective. | `TacticalBattleUI.gd:3446` / `_rebuild_drawer_toolbar` / `_ensure_results_form_drawer` / `_on_checklist_dismissed` / `_on_log_only_results_submitted` (drawer close); `BattleResultsInputForm.gd` (`_build_ui` no internal scroll + tightened spacing; `setup()` objective fallback) | **FIXED + on-device verified** (regressions `test_battle_results_input_form.gd` — 8 cases incl. `test_form_reports_real_height_not_collapsed` + `test_objective_from_mission_data_when_prefill_empty`) |

---

## D1 — Battle round phases (Core Rules p.112)

| Phase | Companion surface | U | R | P |
|-------|-------------------|---|---|---|
| 1. Reaction Roll | ReactionDicePanel / ReactionRollAssignment (≤Reaction→Quick, >→Slow, Feral single-1) | PENDING | PENDING | PENDING |
| 2. Quick Actions | BattleRoundHUD phase breadcrumb; ActivationTracker | PENDING | PENDING | PENDING |
| 3. Enemy Actions | EnemyIntentPanel (oracle); closest-to-player-edge order | PENDING | PENDING | PENDING |
| 4. Slow Actions | BattleRoundHUD; ActivationTracker | PENDING | PENDING | PENDING |
| 5. End Phase | MoralePanicTracker + round-end condition prompts + give-up roll | PENDING | PENDING | PENDING |

## D2 — Tracking tiers (BattleTierController; cumulative)

| Tier | Components (cumulative) | Feature flags | U | R |
|------|-------------------------|---------------|---|---|
| LOG_ONLY | Journal, DiceDashboard, RoundHUD, StatusCard, CombatCalculator (+CheatSheet/WeaponTable/BrawlResolver) | casualty_tracking, dice_rolling | PENDING | PENDING |
| ASSISTED | +Morale/Panic, ReactionDice, ActivationTracker, DeploymentConditions, Initiative, EventResolution, ObjectiveDisplay, PreBattleChecklist, VictoryProgress | +auto_event_prompts, morale_prompts, escalation, deployment_suggestions, phase_reminders | PENDING | PENDING |
| FULL_ORACLE | +EnemyIntent, EnemyGenerationWizard | +ai_oracle | PENDING | PENDING |

## D3 — Combat modes (PreBattleUI)

| Mode | Path | U | R |
|------|------|---|---|
| play_on_table | interactive companion (H1 Battle Sim; H2 tier walks) | N/A | PENDING |
| no_minis | NoMinisCombatPanel → NoMinisResolver (Freelancer's Handbook DLC) | PENDING | PENDING |
| auto_resolve | BattleResolver → NarrativeScreen; result → PostBattle | PENDING | PENDING |

## D4 — Objectives (Core Rules p.89-90) — 11 total

| Objective | Auto-eval? (F1) | BattleFlowGuide win-text | ObjectiveDisplay + VictoryProgress | U | R | P |
|-----------|------------------|--------------------------|-------------------------------------|---|---|---|
| Fight Off | yes | ✓ | | PENDING | PENDING | PENDING |
| Move Through | yes (crew_exited≥3) | ✓ | | PENDING | PENDING | PENDING |
| Deliver | yes | ✓ | | PENDING | PENDING | PENDING |
| Acquire | yes | ✓ | | PENDING | PENDING | PENDING |
| Patrol | yes (markers≥4) | ✓ | | PENDING | PENDING | PENDING |
| Search | yes | ✓ | | PENDING | PENDING | PENDING |
| Defend | yes (survive 6) | ✓ | | PENDING | PENDING | PENDING |
| Protect | yes | ✓ | | PENDING | PENDING | PENDING |
| **Access** | **NO (F1)** | ✓ | ? | PENDING | PENDING | PENDING |
| **Eliminate** | **NO (F1)** | ✓ | ? | PENDING | PENDING | PENDING |
| **Secure** | **NO (F1)** | ✓ | ? | PENDING | PENDING | PENDING |

> Note: counter targets (Move Through 3, Patrol 4) mirror `MissionObjectiveSystem.check_completion()`;
> verify the rulebook values in Phase 5 (Patrol = 3 features per p.90? code uses 4 — VERIFY).

## D5 — Deployment conditions (Core Rules p.88) — 11 total

| Condition | Effect | Round-end prompt? | U | R | P |
|-----------|--------|-------------------|---|---|---|
| No Condition | — | no | PENDING | PENDING | PENDING |
| Small Encounter | 1 crew sits out, −1/−2 enemy | no | PENDING | PENDING | PENDING |
| Poor Visibility | 1D6+8", reroll/round | yes | PENDING | PENDING | PENDING |
| Brief Engagement | 2D6 ≤ round → inconclusive | yes | PENDING | PENDING | PENDING |
| Toxic Environment | Stun→1D6+Savvy 4+ or casualty | per-Stun | PENDING | PENDING | PENDING |
| Surprise Encounter | enemy skips round 1 | no | PENDING | PENDING | PENDING |
| Delayed | 2 crew off-table, 1D6 ≤ round | yes | PENDING | PENDING | PENDING |
| Slippery Ground | −1 Speed ground | no | PENDING | PENDING | PENDING |
| Bitter Struggle | Enemy Morale +1 | no (passive) | PENDING | PENDING | PENDING |
| Caught Off Guard | squad acts Slow round 1 | no | PENDING | PENDING | PENDING |
| Gloomy | visibility 9" | no | PENDING | PENDING | PENDING |

## D6 — Enemy AI types (Core Rules pp.94-103) — 7 total

| AI | Description | Setup spacing (p.110) | Give-up roll | EnemyIntent oracle | U | R | P |
|----|-------------|------------------------|--------------|--------------------|---|---|---|
| A Aggressive | move to closest, attack | one cluster 1" | 1D6 | | PENDING | PENDING | PENDING |
| C Cautious | stay in cover, fire closest visible | 2 groups 6" | 2D6 | | PENDING | PENDING | PENDING |
| D Defensive | hold, fire if approached | 3 teams 8" | 2D6 | | PENDING | PENDING | PENDING |
| G Guardian | stay near assigned unit | attached to guarded figure | — | | PENDING | PENDING | PENDING |
| R Rampage | rush nearest, melee | one cluster 1" | fight to end | | PENDING | PENDING | PENDING |
| T Tactical | advance to cover, fire best | 3 teams 8" | 2D6 | | PENDING | PENDING | PENDING |
| B Beast | move to nearest, attack on contact | pairs per third 2" | fight to end | | PENDING | PENDING | PENDING |

## D7 — Seize Initiative modifiers (Core Rules p.112)

| Modifier | Value | Feral-ignores? | U | P |
|----------|-------|----------------|---|---|
| Base | 2D6 + highest Savvy ≥ 10 | — | PENDING | PENDING |
| Outnumbered | +1 | no | PENDING | PENDING |
| vs Hired Muscle | −1 | **yes (F2)** | PENDING | PENDING |
| Hardcore | −2 | no (difficulty, not opponent) | PENDING | PENDING |
| Insanity | −3 | no | PENDING | PENDING |
| Enemy Careless | +1 | n/a | PENDING | PENDING |
| Enemy Alert | −1 | yes | PENDING | PENDING |
| Motion Tracker | +1 | **VERIFY (F3)** | PENDING | PENDING |
| Scanner Bot | +1 | **VERIFY (F3)** | PENDING | PENDING |

## D8 — End-Phase morale / bail (Core Rules p.113)

| Case | Rule | U | P |
|------|------|---|---|
| Dice = casualties this round | roll 1D6 per figure removed in combat | PENDING | PENDING |
| Bail count | each die within Panic (Bail) range = 1 Bail | PENDING | PENDING |
| Bail order | closest to enemy edge first | PENDING | N/A |
| Fearless | Panic 0 → never Bail | PENDING | PENDING |
| Stubborn | ignore first casualty of the battle | PENDING | PENDING |
| Bitter Struggle | Enemy Morale +1 | PENDING | PENDING |
| Give-up roll | 2D6 (C/D/T), 1D6 (A), fight-to-end (R/B) | PENDING | PENDING |
| Player morale | players never test (abandon by leaving edge) | PENDING | PENDING |

## D9 — Mission-type panels (Compendium)

| Mission | Panel | U | R |
|---------|-------|---|---|
| Standard | (none) | N/A | PENDING |
| Stealth | StealthMissionPanel | PENDING | PENDING |
| Street Fight | StreetFightPanel | PENDING | PENDING |
| Salvage | SalvageMissionPanel | PENDING | PENDING |

## D10 — Notable Sights (Core Rules p.88) — D100, 9 outcomes

| Roll | Outcome | U | P |
|------|---------|---|---|
| 1-20 (Opp) | Nothing special | PENDING | PENDING |
| Documentation | +1 Quest Rumor | PENDING | PENDING |
| Priority target | +1 Toughness, slay → 1D3 cr | PENDING | PENDING |
| Loot cache | 1 Loot Table roll | PENDING | PENDING |
| Shiny bits | +1 cr | PENDING | PENDING |
| Really shiny bits | +2 cr | PENDING | PENDING |
| Person of interest | +1 story point | PENDING | PENDING |
| Peculiar item | +2 XP | PENDING | PENDING |
| Curious item | 1D6: 1-4 sell 1cr / 5-6 Loot | PENDING | PENDING |

---

## Page-cite reconciliation (Phase 5) — printed page = PDF-index + 1

| Rule | Was cited | Canonical PDF (footer-verified) | Status |
|------|-----------|----------------------------------|--------|
| Seizing the Initiative | p.117 | **p.112** (pdf-idx 111) | FIXED → p.112 |
| The Reaction Roll | p.96 | **p.113** (pdf-idx 112) | FIXED → p.113 |
| End Phase / Running Away / Morale | pp.114-118 | **p.114** (spans to p.118 ref) | CORRECT — kept |
| Deployment conditions table | p.90 / p.94 / p.115 | **p.88** (pdf-idx 87) | FIXED → p.88 |
| Notable Sights | p.94 | **p.89** (pdf-idx 88) | FIXED → p.89 |
| Objectives ("Types of Objective") | p.90 | **p.90** (pdf-idx 89) ✓ | CORRECT — kept |
| Enemy encounter tables | p.94 | **p.94-95** (pdf-idx 93-94) ✓ | CORRECT — kept |
| Battle Events (ROLL EFFECT) table | p.117 | **p.117** (pdf-idx 116) ✓ | CORRECT — kept (NOT seize) |
| Deployment procedure (edges/enemy-first/18") | p.110 | **p.110** ✓ | CORRECT — kept |

---

## Bugs found (filed during runtime/unit phases)

| ID | Severity | Summary | Status |
|----|----------|---------|--------|
| F5 | **HIGH** — Patrol objective UNWINNABLE | `check_completion()` required 4 patrol markers; only 3 are ever placed (Core Rules p.90 = 3). | **FIXED** + regression (`test_battle_objective_completion` + updated `test_battle_objective_tracker`) |
| F6 | MEDIUM — Move Through too hard | Required 3 crew exited; rulebook p.90 = "at least 2". | **FIXED** + regression |
| F8 | **HIGH** — FULL_ORACLE Enemy Actions soft-lock / oracle vanishes | `enemy_intent_panel` is the one phase component freed during the SETUP→COMBAT rebuild; `_show_enemy_actions_ui()` passed it unguarded to the TYPED `_surface_phase_component(component: Control)` → freed-ref fails the call-boundary type check → method ABORTS before building "Enemy Actions Done" (soft-lock); null case silently drops the oracle. Found by the Phase-2 runtime walk (invisible to unit tests + `--headless`). | **FIXED** (`TacticalBattleUI.gd:2755` guard+recreate) + runtime-verified (Enemy Actions reached, oracle valid, done button built) |
| F1 | ~~MEDIUM~~ **NOT A BUG** | ACCESS/ELIMINATE/SECURE are player-driven by design (manual VictoryProgressPanel toggle, like FIGHT_OFF) — the app can't see their physical-table win states. `check_completion()` returning false is correct; completion via `is_complete()`→`_manual_met`. Already tested. Auto-completing would break the companion model. | RESOLVED — not a bug |
| F4 | LOW — battle page-cites reference a different pagination | seize/reaction/morale cites off by non-uniform offsets vs committed PDF. | Reconcile in Phase 5 |

## Phase 2 progress (UX axis — desktop MCP `run_script` harness)

**Harness correction:** MCP `simulate_input` (coordinate clicks / keys) does NOT drive this project's
Control menus — synthetic events don't reach the GUI `pressed` pipeline (menu nav works fine when the
button's `pressed` signal is fired directly). The working harness is `run_script`: navigate by firing
`button.emit_signal("pressed")` / calling `SceneRouter`, set state + invoke methods on the live tree,
`take_screenshot` to verify. Neutralize `/root/TransitionManager/TransitionOverlay` (`visible=false`)
before capture. NOTE: MCP runs in `--debug` → any script error HALTS at the debugger (restart to recover).

**Tier gating (D2) VERIFIED at runtime** (Battle Simulator → TacticalBattleUI):
- LOG_ONLY: enabled = exactly `[BattleJournal, DiceDashboard, BattleRoundHUD, CharacterStatusCard,
  CombatCalculator]`; Morale/Oracle/Activation components **absent** from the tree. PASS.
- FULL_ORACLE: all 14 cumulative components enabled AND instantiated (Morale, Reaction, Activation,
  DeploymentConditions, Initiative, EventResolution, Objective, VictoryProgress, EnemyIntent,
  EnemyGeneration). PASS. (ASSISTED = the middle subset, covered by cumulative logic + unit tests.)
- Companion renders correctly at SETUP: Battle Card (objective + battlefield + build hint), Pre-Battle
  Setup Checklist (terrain/deploy/conditions/sights), enemy roster w/ Oracle intel, tier-gated
  Tracking + Oracle drawers. Screenshot on record.

| F7 | LOW — page-cite | Pre-Battle Checklist "Roll d100 … deployment conditions (Core Rules p.90)" — table is on **p.88** (p.90 is objectives). | PENDING — Phase 5 (with F4) |

## Phase 4 progress (integrated 5PFH played battle — the "how were you doing battles?" gap)

Loaded a 5PFH campaign (Modiphius Demo) → `WorldPhaseController._debug_skip_to_battle()` → campaign
`PreBattleUI` (`selected_representation_mode = "play_on_table"`) → `_on_confirm_pressed()` launched a
**played** `TacticalBattleUI` in campaign context (COMBAT stage). Forced a victory and called
`_resolve_battle()`.

**Played-vs-auto-resolve result contract — VERIFIED identical:**
- Code: `auto_result_dict` (`.gd:4280`) is commented "same contract as `_resolve_battle`" and has the
  same **24 keys** as the played `result_dict` (`.gd:4086`). Only differences: `auto_resolved` flag +
  `defeated_enemies` detail.
- Runtime: the played battle emitted `tactical_battle_completed` with all 24 keys —
  `victory:true, won:true, **success:true**, auto_resolved:false, crew_alive:6, enemies_remaining:0,
  mission_source:"opportunity"`. The `success` key (once a latent bug — "won battles cascaded as
  failures", `.gd:4071`) is present and correct.
- The result flowed through `CampaignTurnController._on_battle_completed` → **`PostBattleSequence`
  launched** (present in tree), no SCRIPT ERRORs.

Caveat: the post-battle UI rendered blank on this path because `_debug_skip_to_battle` bypassed the
World Phase mission-data setup its display needs — an artifact of the test shortcut, not the played
path (the full interactive PostBattleSequence render was confirmed earlier on the tablet). The Phase-4
GOAL (played result contract == auto contract, reaches PostBattle) is met.

### Phase 4 — ON-DEVICE played walk (tablet, Test17 APK, 2026-07-05→06)

Drove a REAL played LOG_ONLY campaign battle ("Deliver Mission [LOG ONLY]", Turn 4) end-to-end via ADB
touch, no injected state:
- Enemy Tracker **Mark Down → Confirm Casualty** exercised 4× on-device; persistent sidebar tracked to
  **ENEMIES 1/5 active** with struck-through ledger. Objective **● Deliver (marked on map)** displayed.
  Tap-a-sector rules popover (SectorRulesPopover) confirmed working.
- **Surfaced F9 + F10** (both code-confirmed, see findings table). These are exactly the class of defect
  the on-device walk exists to catch — unit tests, `--headless`, AND desktop MCP (mouse-wheel scroll /
  API-injected trackers) all pass through them because they're device-only / played-flow-only.
- **F9 fixed:** downed figures collapse to compact rows so the full roster fits the drawer viewport.
- **F10 fixed (choice B):** the full LOG_ONLY companion is preserved AND a reachable emerald **Record
  Result** button now opens the objective-aware `BattleResultsInputForm`; submit → PostBattle. A played
  battle at ANY tier can now be recorded (previously only Auto Resolve / Return existed).
- Result-form objective semantics now book-faithful (p.90): mission **success = declared objective
  outcome**, not the Won/Lost proxy (regression: `test_battle_results_input_form.gd`, 8 cases).
- **Re-test DONE on-device (Jul 6).** The walk itself surfaced FOUR more device-/played-flow-only bugs the
  unit tests + `--headless` + desktop MCP all passed — see the F10 row (F10-b drawer collapse, F10-c missing
  objective section, F10-d Submit off-screen because the form outgrew the non-touch-scrollable drawer, F10-e
  results drawer lingered over PostBattle). All fixed, re-built (Test16), and re-verified on the tablet.
- **Final end-to-end walk (Test16, "Eliminate Mission [LOG ONLY]", Turn 4):** F9 compact downed rows confirmed
  earlier (all 4 enemies); F10 Record Result (reachable in Deploy/Combat once the pre-battle checklist modal is
  dismissed) → opens the FULL objective-aware form on ONE screen (MISSION OBJECTIVE "Eliminate" + "Objective
  achieved" checkbox, OUTCOME, ENEMIES 5/5, 6-crew CASUALTIES + INJURIES, Submit) → check objective → Submit →
  drawer closes (F10-e) and **PostBattle Sequence Step 14 of 14** renders (all 13 prior steps ✓; log: payment
  3cr, loot Flak Gun, 6× +3 XP, campaign event). The played battle resolved on the DECLARED objective (p.90).
  Three regressions added across the sprint (`test_form_reports_real_height_not_collapsed`,
  `test_objective_from_mission_data_when_prefill_empty`, `test_tactical_downed_unit_row` ×3).
- **Process notes:** (1) each on-device fix needed a full APK rebuild + reinstall (Android has no hot-reload);
  (2) a full app force-stop (not just in-app Load) is required to reset `CampaignPhaseManager`'s per-turn step
  state — an in-app reload left World Phase step 2 (Crew Tasks) unable to advance (stale completion flags);
  (3) the Record Result button lives in the persistent action bar but a *modal* Pre-Battle Setup Checklist
  (full-screen input scrim) sits in front of it during Setup→Deploy — "always reachable" holds in actual play
  (Combat rounds / post-deploy), the one-shot modal is dismissed via its Begin Battle button first.

## Phase 1 progress (data axis)

Done + green: `test_seize_initiative_system` (13, D7 incl. verified-F2/F3), `test_battle_objective_completion`
(14, D4 completion + F5/F6 locked + F1 characterized), `test_morale_panic_tracker` (7, D8),
`test_battle_flow_guide` (extended: all 11 conditions in round-end coverage, D4/D5/D6). Existing
`test_battle_tier_controller_features` (13, D2) + `test_no_minis_resolver` (D3) reviewed as adequate.
Regression: `test_battle_objective_tracker` patrol test updated to the F5 value; full batch 85 cases → 0 fail.
