# Campaign Phase Consistency Analysis

**Analysis Date**: 2025-12-29
**Document Purpose**: Compare official Five Parsecs rules against implementation in scenes and code

---

## Overview

This document compares the **official campaign turn structure** from `docs/gameplay/rules/core_rules.md` (lines 5484-5514) against the actual implementation in phase handlers and UI screens.

---

## Official Campaign Turn Structure (Core Rules)

### STEP 1: TRAVEL (p.69)
| # | Substep | Description |
|---|---------|-------------|
| 1 | Flee Invasion | If applicable, decide to flee invasion |
| 2 | Decide Whether to Travel | Stay or travel to new world |
| 3 | Starship Travel Event | If traveling, resolve travel event |
| 4 | New World Arrival Steps | If applicable, handle arrival |

### STEP 2: WORLD (p.76)
| # | Substep | Description |
|---|---------|-------------|
| 1 | Upkeep and Ship Repairs | Pay crew and repair costs |
| 2 | Assign and Resolve Crew Tasks | Assign crew to tasks |
| 3 | Determine Job Offers | Check for patron/job offers |
| 4 | Assign Equipment | Equip crew for battle |
| 5 | Resolve Any Rumors | Handle rumor missions |
| 6 | Choose Your Battle | Select mission for battle |

### STEP 3: TABLETOP BATTLE (p.87)
| Phase | Description |
|-------|-------------|
| Setup | Determine mission, enemies, terrain |
| Deployment | Position forces on battlefield |
| Initiative | Determine turn order |
| Combat Rounds | Execute turn-by-turn combat |
| Battle End | Resolve victory/defeat conditions |

### STEP 4: POST-BATTLE SEQUENCE (p.119)
| # | Substep | Description |
|---|---------|-------------|
| 1 | Resolve Rival Status | Check if rival removed |
| 2 | Resolve Patron Status | Check patron relationship |
| 3 | Quest Progress | Update quest/story track |
| 4 | Get Paid | Collect mission payment |
| 5 | Battlefield Finds | Search battlefield for loot |
| 6 | Check for Invasion | Check if world is invaded |
| 7 | Gather Loot | Roll on loot tables |
| 8 | Determine Injuries | Roll injury table for casualties |
| 9 | Experience and Leveling | Award XP and check advancement |
| 10 | Purchase Items | Buy equipment from shops |
| 11 | Campaign Event | Roll on campaign event table |
| 12 | Character Event | Roll on character event table |
| 13 | Galactic War Progress | Update war status |
| 14 | Clock Resets and Story Track | Reset timers, advance story |

---

## Implementation Status

### GlobalEnums.gd - Substep Definitions

| Phase | Enum Name | Substeps Defined | Match Rules? |
|-------|-----------|------------------|--------------|
| Travel | `TravelSubPhase` | NONE, FLEE_INVASION, DECIDE_TRAVEL, TRAVEL_EVENT, WORLD_ARRIVAL | **YES** (4 substeps) |
| World | `WorldSubPhase` | NONE, UPKEEP, CREW_TASKS, JOB_OFFERS, EQUIPMENT, RUMORS, BATTLE_CHOICE | **YES** (6 substeps) |
| Battle | `BattlePhase` | NONE, SETUP, DEPLOYMENT, INITIATIVE, ACTIVATION, CLEANUP | **YES** (battle-specific) |
| Post-Battle | `PostBattleSubPhase` | 14 substeps matching rules exactly | **YES** (14 substeps) |

---

## Phase Handler Implementation

### TravelPhase.gd
**Status**: CONSISTENT with rules

| Rule Step | Implementation | Status |
|-----------|----------------|--------|
| 1. Flee Invasion | `_handle_flee_invasion()` | OK |
| 2. Decide Travel | `_handle_decide_travel()` | OK |
| 3. Travel Event | `_handle_travel_event()` | OK |
| 4. World Arrival | `_handle_world_arrival()` | OK |

**Signals**: `travel_phase_started`, `travel_phase_completed`, `travel_substep_changed`

### WorldPhase.gd
**Status**: CONSISTENT with rules

| Rule Step | Implementation | Status |
|-----------|----------------|--------|
| 1. Upkeep | `_handle_upkeep()` | OK |
| 2. Crew Tasks | `_handle_crew_tasks()` | OK |
| 3. Job Offers | `_handle_job_offers()` | OK |
| 4. Equipment | `_handle_equipment()` | OK |
| 5. Rumors | `_handle_rumors()` | OK |
| 6. Battle Choice | `_handle_battle_choice()` | OK |

**Signals**: `world_phase_started`, `world_phase_completed`, `world_substep_changed`

### BattlePhase.gd
**Status**: CONSISTENT with rules

| Battle Phase | Implementation | Status |
|--------------|----------------|--------|
| Setup | `_process_battle_setup()` | OK |
| Deployment | `_process_deployment()` | OK |
| Initiative | `_process_initiative()` | OK |
| Combat Rounds | `_process_combat_rounds()` | OK |
| Cleanup | `_complete_battle_phase()` | OK |

**Signals**: `battle_phase_started`, `battle_phase_completed`, `battle_substep_changed`, `battle_results_ready`

### PostBattlePhase.gd
**Status**: CONSISTENT with rules (14 substeps)

All 14 substeps match core rules exactly. Full implementation with proper signal flow.

---

## UI Screen Implementation

### PostBattleSequence.gd (UI)
**Status**: CONSISTENT - All 14 steps match rules

```
post_battle_steps Array:
1. Resolve Rival Status
2. Resolve Patron Status
3. Quest Progress
4. Get Paid
5. Battlefield Finds
6. Check for Invasion
7. Gather Loot
8. Determine Injuries
9. Experience and Leveling
10. Purchase Items
11. Campaign Event
12. Character Event
13. Galactic War Progress
14. Clock Resets and Story Track
```

### WorldPhaseController.gd (UI)
**Status**: INCONSISTENCY DETECTED

```gdscript
enum WorldPhaseStep {
    UPKEEP = 0,           # World Phase - OK
    CREW_TASKS = 1,       # World Phase - OK
    JOB_OFFERS = 2,       # World Phase - OK
    ASSIGN_EQUIPMENT = 3, # World Phase - OK
    RESOLVE_RUMORS = 4,   # World Phase - OK
    MISSION_PREP = 5,     # Not in rules (variant of BATTLE_CHOICE?) - REVIEW
    PURCHASE_ITEMS = 6,   # POST-BATTLE Step 10 - WRONG PHASE
    CAMPAIGN_EVENT = 7,   # POST-BATTLE Step 11 - WRONG PHASE
    CHARACTER_EVENT = 8   # POST-BATTLE Step 12 - WRONG PHASE
}
```

**Issue**: Steps 6-8 (PURCHASE_ITEMS, CAMPAIGN_EVENT, CHARACTER_EVENT) belong in POST-BATTLE phase per core rules, not World phase.

---

## CampaignTurnController.gd (Orchestrator)
**Status**: CONSISTENT - Proper phase flow

The orchestrator correctly manages:
- Phase transitions: Travel WORLD BATTLE POST_BATTLE
- Turn rollover: `_on_campaign_turn_completed()` auto-starts next turn
- Battle flow: BattleTransition PreBattle TacticalBattle PostBattle

**Phase Flow Implementation**:
```
start_new_campaign_turn()
    CampaignPhaseManager.start_new_campaign_turn()
        Travel Phase (UI: travel_phase_ui)
            world Phase (UI: world_phase_controller)
                Battle Phase (UI: battle_transition_ui)
                    PreBattle (UI: pre_battle_ui)
                        TacticalBattle (UI: tactical_battle_ui)
                            Post-Battle (UI: post_battle_ui)
                                _on_campaign_turn_completed()
                                    start_new_campaign_turn() [NEXT TURN]
```

---

## Summary of Findings

### CONSISTENT
| Component | Status | Notes |
|-----------|--------|-------|
| GlobalEnums.gd | PASS | All substep enums match rules |
| TravelPhase.gd | PASS | 4/4 substeps implemented |
| WorldPhase.gd | PASS | 6/6 substeps implemented |
| BattlePhase.gd | PASS | 5 battle phases implemented |
| PostBattlePhase.gd | PASS | 14/14 substeps implemented |
| PostBattleSequence.gd | PASS | 14 UI steps match rules |
| CampaignTurnController.gd | PASS | Proper phase orchestration |
| CampaignPhaseManager.gd | PASS | Proper phase transitions |

### PREVIOUSLY INCONSISTENT (NOW FIXED - 2025-12-29)
| Component | Issue | Resolution |
|-----------|-------|------------|
| WorldPhaseController.gd | Steps 6-8 were in World Phase | **FIXED** - Removed PURCHASE_ITEMS, CAMPAIGN_EVENT, CHARACTER_EVENT from WorldPhaseController |
| PostBattleSequence.gd | Purchase step was minimal | **FIXED** - Now uses PurchaseItemsComponent |
| WorldPhaseController.gd | MISSION_PREP not in core rules | **DOCUMENTED** - Variant of BATTLE_CHOICE for mission selection UI |

---

## Completed Actions (2025-12-29)

### DONE: Fixed WorldPhaseController Step Placement
The following steps were removed from WorldPhaseController.gd and now exist only in PostBattleSequence:
- `PURCHASE_ITEMS` → Post-Battle Step 10 (uses PurchaseItemsComponent)
- `CAMPAIGN_EVENT` → Post-Battle Step 11 (inline implementation)
- `CHARACTER_EVENT` → Post-Battle Step 12 (inline implementation)

**Changes Made**:
- WorldPhaseController.gd: Reduced from 9 steps to 6 steps
- WorldPhaseController.tscn: Removed 3 container nodes
- PostBattleSequence.gd: Enhanced `_add_purchase_content()` to use PurchaseItemsComponent

### DOCUMENTED: MISSION_PREP Variant
The `MISSION_PREP` step in WorldPhaseController is a game-specific variant of "Choose Your Battle" (Step 6 in rules). It provides a dedicated mission selection UI before proceeding to battle.

---

## Battle Phase Detail

### World Phase Battle Choice

Per core rules, World Phase Step 6 "Choose Your Battle" determines:
- Mission selection (patron job, opportunity mission, quest mission)
- Enemy type based on mission
- Deployment conditions

### Implementation Flow (WorldPhase.gd)
```gdscript
# Step 6: Battle Choice
func _handle_battle_choice():
    # Player selects mission
    # Sets up battle parameters
    # Emits battle_selected signal
    world_phase_completed.emit()
    # CampaignPhaseManager transitions to BATTLE phase
```

### Battle Phase Implementation (BattlePhase.gd)
```gdscript
# Called when Battle phase starts
func start_battle_phase(mission_data: Dictionary):
    # SETUP: Generate enemies, terrain, conditions
    _process_battle_setup()

    # DEPLOYMENT: Position units
    _process_deployment()

    # INITIATIVE: Determine turn order
    _process_initiative()

    # COMBAT: Execute rounds
    _process_combat_rounds()

    # CLEANUP: Finalize results
    _complete_battle_phase()
    # Emits battle_results_ready with combat_results
```

### Post-Battle Transition
```gdscript
# CampaignTurnController.gd
func _on_battle_completed(results: Dictionary):
    game_state.set_battle_results(results)
    campaign_phase_manager.start_phase(POST_BATTLE)
```

---

## Turn Rollover

### Implementation (CampaignTurnController.gd:304-311)
```gdscript
func _on_campaign_turn_completed(turn_number: int):
    print("Campaign turn %d completed" % turn_number)
    campaign_turn_completed.emit(turn_number)

    # Auto-start next turn after 2 second delay
    await get_tree().create_timer(2.0).timeout
    start_new_campaign_turn()
```

### Post-Battle Completion Handler (CampaignTurnController.gd:397-408)
```gdscript
func _on_post_battle_completed(results: Dictionary):
    # Store and clear battle results
    game_state.set_battle_results(results)
    game_state.clear_battle_results()

    # Trigger next campaign turn
    campaign_phase_manager.start_new_campaign_turn()
```

**Status**: Turn rollover is properly implemented with automatic progression.

---

## Conclusion

The core campaign turn flow (Travel → World → Battle → Post-Battle) is **fully implemented** with consistent substep handling across all phase handlers.

**Status**: ALL ISSUES RESOLVED (2025-12-29)

All previously identified inconsistencies have been fixed:
- WorldPhaseController.gd step placement - FIXED (removed Post-Battle steps)
- MISSION_PREP variant - DOCUMENTED (game-specific UI for battle choice)

The campaign phase system now correctly matches the official Five Parsecs core rules structure.

---

## Additional Data Handoff Fixes (2025-12-29)

Related fixes made to ensure proper data flow between campaign wizard panels and phase handlers:

| Component | Fix Applied |
|-----------|-------------|
| EquipmentPanel.gd | Added `_on_coordinator_set()` signal connection for cross-panel crew data |
| CaptainPanel.gd | Added `"name"` key alongside `"character_name"` for consumer compatibility |
| ShipPanel.gd | Added `cargo_capacity` field calculation for FinalPanel display |
| CampaignPhaseManager.gd | Fixed turn counter double-advancement bug |
| GameState.gd | Added `set_turn_number()` method for sync from CampaignPhaseManager |
