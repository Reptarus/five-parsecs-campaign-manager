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

## Phase 1 progress (data axis)

Done + green: `test_seize_initiative_system` (13, D7 incl. verified-F2/F3), `test_battle_objective_completion`
(14, D4 completion + F5/F6 locked + F1 characterized), `test_morale_panic_tracker` (7, D8),
`test_battle_flow_guide` (extended: all 11 conditions in round-end coverage, D4/D5/D6). Existing
`test_battle_tier_controller_features` (13, D2) + `test_no_minis_resolver` (D3) reviewed as adequate.
Regression: `test_battle_objective_tracker` patrol test updated to the F5 value; full batch 85 cases → 0 fail.
