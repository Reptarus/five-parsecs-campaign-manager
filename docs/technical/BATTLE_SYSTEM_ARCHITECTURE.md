# Battle System Architecture

**Last Updated**: 2026-02-28
**Engine**: Godot 4.6-stable
**Status**: Fully wired, end-to-end battle flow working

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

## Deleted Files (Phase 16-17 Cleanup)

These were removed during the Feb 2026 battle rework:
- `BattleCompanionUI.gd` — absorbed into TacticalBattleUI
- `BattleResolutionUI.gd` — orphaned, removed Feb 28
- `BattleDashboardUI.gd`, `BattleScreen.gd`, `BattleHUDCoordinator.gd`
- `BattlefieldGridUI.gd`, `PreBattleEquipmentUI.gd`, `TestPreBattle.gd`
- `PostBattleResultsUI.gd`
- `FPCM_BattleEventBus.gd` — dead code, removed Feb 28
