# Battle System Architecture

**Last Updated**: 2026-03-03
**Engine**: Godot 4.6-stable
**Status**: Fully wired, end-to-end battle flow working (standard + Bug Hunt)

## Overview

The battle system is a **tabletop companion assistant** (NOT a tactical simulator). All output is TEXT INSTRUCTIONS for the player to execute on the physical tabletop. Three-tier tracking: LOG_ONLY / ASSISTED / FULL_ORACLE.

## Battle Flow

```
CampaignPhaseManager (MISSION/BATTLE_SETUP/BATTLE_RESOLUTION phases)
  → CampaignTurnController._show_phase_ui()
  → BattleTransitionUI (mission briefing, crew/equipment display)
    → signal: battle_ready_to_launch
  → PreBattleUI (crew selection, deployment preview)
    → signal: deployment_confirmed
  → TacticalBattleUI (main battle companion, 1,694 lines)
    → TierSelectionPanel overlay → PreBattleChecklist modal
    → 26 battle components in three-zone tabbed layout
    → signal: tactical_battle_completed
  → PostBattleSequence (14-step post-battle processing)
    → signal: post_battle_completed
  → CampaignPhaseManager advances to ADVANCEMENT
```

**Key**: CampaignTurnController hosts all 4 battle UIs as **embedded panels** (show/hide via signals). SceneRouter has routes registered but the main flow uses the embedded pattern.

## File Inventory

### Screen Scripts (4 files, 2,378 lines)

| File | Lines | Purpose |
| --- | --- | --- |
| `src/ui/screens/battle/TacticalBattleUI.gd` | 1,694 | Main battle companion hub |
| `src/ui/screens/battle/PreBattleUI.gd` | 267 | Crew selection + deployment |
| `src/ui/screens/battle/BattleTransitionUI.gd` | 248 | Mission briefing |
| `src/ui/screens/battle/BattlefieldMain.gd` | 169 | Battlefield visualization |

### Component Scripts (27 files, 7,218 lines)

| Component | Tier | Signals Connected |
| --- | --- | --- |
| BattleJournal | LOG_ONLY | Yes - central log |
| DiceDashboard | LOG_ONLY | Yes - dice_rolled |
| CombatCalculator | LOG_ONLY | Yes - calculation_completed |
| CharacterStatusCard | LOG_ONLY | Yes - action_used, damage_taken |
| BattleRoundHUD | LOG_ONLY | Yes - next_phase_requested |
| CombatSituationPanel | LOG_ONLY | Yes - modifiers_changed |
| DualInputRoll | LOG_ONLY | Yes - roll_completed |
| CheatSheetPanel | ALWAYS | No (display-only reference) |
| WeaponTableDisplay | ALWAYS | Yes - weapon_selected |
| MoralePanicTracker | ASSISTED | Yes - morale_check_triggered, enemy_fled |
| EventResolutionPanel | ASSISTED | Yes - event_resolved |
| VictoryProgressPanel | ASSISTED | Yes - victory_condition_met, defeat_condition_triggered |
| ActivationTrackerPanel | ASSISTED | Yes - unit_activation_requested |
| ObjectiveDisplay | ASSISTED | Yes - objective_rolled, objective_acknowledged |
| ReactionDicePanel | ASSISTED | Yes - dice_spent, all_dice_reset |
| DeploymentConditionsPanel | ASSISTED | Yes - condition_acknowledged, reroll_requested |
| InitiativeCalculator | ASSISTED | Yes - initiative_calculated |
| TierSelectionPanel | OVERLAY | Yes - tier_selected |
| PreBattleChecklist | OVERLAY | Yes - checklist_completed |
| EnemyIntentPanel | FULL_ORACLE | Yes - intent_revealed, oracle_instruction_ready |
| EnemyGenerationWizard | FULL_ORACLE | Yes - enemies_generated |

### Core Battle Logic (37 files, 14,422 lines)

Key files:
- `FPCM_BattleManager.gd` (589 lines) — battle FSM, phase transitions
- `FPCM_BattleState.gd` — serializable battle data
- `BattleResolver.gd` (530 lines) — thin orchestrator, delegates to BattleCalculations
- `BattleCalculations.gd` — actual combat math
- `BattleRoundTracker.gd` — round/phase progression
- `BattleTierController.gd` — tier visibility management
- `BattleEventsSystem.gd` — round 2/4 event triggers

## Three-Tier System

| Tier | Components | Description |
| --- | --- | --- |
| LOG_ONLY (0) | 8 | Basic logging, dice, calculator, character cards |
| ASSISTED (1) | 8 + LOG_ONLY | Morale, activation tracking, objectives, deployment |
| FULL_ORACLE (2) | 2 + ASSISTED | Enemy AI intent, enemy generation wizard |
| ALWAYS | 3 | Cheat sheet, weapon table, combat situation |
| OVERLAY | 2 | Tier selection, pre-battle checklist |

## TacticalBattleUI Architecture

Three-zone tabbed layout:

```
┌─────────────┬──────────────┬──────────────┐
│ LEFT TABS   │ CENTER TABS  │ RIGHT TABS   │
│             │              │              │
│ 0: Crew     │ 0: Battle Log│ 0: Tools     │
│ 1: Units*   │ 1: Tracking* │ 1: Reference │
│ 2: Enemies**│ 2: Events*   │              │
└─────────────┴──────────────┴──────────────┘
│               BOTTOM BAR                   │
│ Turn indicator │ Phase buttons │ End turn   │
└────────────────────────────────────────────┘
* = ASSISTED+   ** = FULL_ORACLE only
```

### Signal Hub Pattern

All component signals route through TacticalBattleUI → BattleJournal for logging. Key connections:

- Component signals → lambda → `battle_journal.log_action()` / `log_event()`
- BattleRoundTracker → `_on_round_phase_changed()`, `_on_round_started()`, etc.
- CharacterStatusCards → per-card `action_used` / `damage_taken`
- Overlays: InitiativeCalculator shown at REACTION_ROLL phase, EventResolutionPanel at rounds 2/4

## Campaign Integration

`CampaignTurnController.gd` is the bridge between CampaignPhaseManager and battle UIs:

```
@onready var battle_transition_ui: Control = %BattleTransitionUI
@onready var pre_battle_ui: Control = %PreBattleUI
@onready var tactical_battle_ui: Control = %TacticalBattleUI
@onready var post_battle_ui: Control = %PostBattleUI
```

All 4 are instanced in `CampaignTurnController.tscn` as children of `MainContainer/PhaseContainer`.

## Key Autoloads Used by Battle

DiceManager, GameState, GameStateManager, CampaignPhaseManager, GlobalEnums

## Bug Hunt Mode (Mar 3, 2026)

TacticalBattleUI supports a second battle mode (`battle_mode = "bug_hunt"`) for the Bug Hunt gamemode. This mode is **purely additive** — standard 5PFH battle flow is unchanged.

### Bug Hunt Battle Flow

```
BugHuntMissionPanel._launch_mission()
  → BugHuntBattleSetup.generate_battle_context()
  → GameStateManager.set_temp_data("bug_hunt_battle_context", context)
  → SceneRouter.navigate_to("tactical_battle")
  → TacticalBattleUI._check_bug_hunt_launch()  [auto-detect in _ready()]
    → Validates campaign type (must have "main_characters")
    → setup_bug_hunt_battle(context, crew)
      → Hides morale tracker
      → Adds ContactMarkerPanel to Tracking tab
      → Adds Movie Magic panel to Tools tab
      → Hides AutoResolve button
    → _add_bug_hunt_complete_button()  [green button in BottomBar]
    → Rewires ReturnButton to "Abort Mission"
  → Player uses tabletop companion
  → _on_bug_hunt_battle_done(result)
    → Stores result in temp_data, clears context
    → SceneRouter.navigate_to("bug_hunt_turn_controller")
  → BugHuntTurnController._resume_after_battle()
    → Skips to POST_BATTLE phase
    → PostBattlePanel.set_battle_results() with real data
```

### Cross-Mode Safety

- **Campaign type validation**: `_check_bug_hunt_launch()` verifies `"main_characters" in campaign`; aborts with warning if wrong campaign type
- **Double-call guard**: `_bug_hunt_returning` flag prevents `_on_bug_hunt_battle_done()` from firing twice
- **Signal guards**: `is_connected()` check on return_button; ContactMarkerPanel + MovieMagicPanel freed before recreation
- **Temp data isolation**: Bug Hunt uses `"bug_hunt_*"` prefixed keys; standard uses `"world_phase_results"`, etc.

### Bug Hunt Components (added to TacticalBattleUI)

| Component | Tab | Purpose |
| --- | --- | --- |
| ContactMarkerPanel | Tracking | 4x4 sector grid, contact reveal/movement/spawning |
| MovieMagicPanel | Tools | 10 one-shot cinematic abilities from campaign data |
| CompleteBugHuntBtn | BottomBar | Green button to end battle and return to turn controller |

### Bug Hunt Files (read-only reference)

- `src/core/battle/BugHuntBattleSetup.gd` — generates battle context (contacts, locations, spawns)
- `src/core/systems/BugHuntEnemyGenerator.gd` — contact table, reveal, priority spawning
- `src/ui/components/battle/ContactMarkerPanel.gd` — scanner blip tracker UI
- `data/bug_hunt/bug_hunt_movie_magic.json` — 10 Movie Magic abilities

## Deleted Files (Phase 16-17 Cleanup)

These were removed during the Feb 2026 battle rework:
- `BattleCompanionUI.gd` — absorbed into TacticalBattleUI
- `BattleResolutionUI.gd` — orphaned, removed Feb 28
- `BattleDashboardUI.gd`, `BattleScreen.gd`, `BattleHUDCoordinator.gd`
- `BattlefieldGridUI.gd`, `PreBattleEquipmentUI.gd`, `TestPreBattle.gd`
- `PostBattleResultsUI.gd`
- `FPCM_BattleEventBus.gd` — dead code, removed Feb 28
