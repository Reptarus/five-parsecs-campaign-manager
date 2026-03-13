# Campaign Turn Phases (9-Phase Loop)

## Phase Order

```
STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT
```

Each phase has a dedicated panel wired into `CampaignPhaseManager` → `CampaignTurnController` with completion signals and data handoff.

## FiveParsecsCampaignPhase Enum (14 values)

```gdscript
enum FiveParsecsCampaignPhase {
    NONE, SETUP, STORY, TRAVEL, PRE_MISSION, MISSION,
    BATTLE_SETUP, BATTLE_RESOLUTION, POST_MISSION,
    UPKEEP, ADVANCEMENT, TRADING, CHARACTER, RETIREMENT
}
```

**IMPORTANT**: CampaignDashboard uses this enum (aliased as `FPC`). The old `CampaignPhase` (10 values) is **deprecated**.

## CampaignPhaseManager Signals

```
phase_changed(old_phase, new_phase)
sub_phase_changed(old_sub_phase, new_sub_phase)
phase_completed
phase_started(phase)
phase_action_completed(action: String)
phase_event_triggered(event: Dictionary)
phase_error(error_message: String, is_critical: bool)
campaign_turn_started(turn_number: int)
campaign_turn_completed(turn_number: int)
```

## Phase Flow

### Turn Start
```
CampaignPhaseManager.start_new_turn()
  → turn_number += 1
  → campaign_turn_started.emit(turn_number)
  → start_phase(STORY)
```

### Phase Transition
```
Phase Panel emits phase_completed with data
  → CampaignPhaseManager.complete_current_phase()
    → Advance to next phase OR complete turn
    → phase_changed.emit(old, new)
    → Dashboard._on_phase_changed() updates UI
```

### Turn Completion
```
Last phase (RETIREMENT) completes
  → CampaignPhaseManager.complete_current_turn()
    → campaign_turn_completed.emit(turn_number)
    → Auto-save if enabled
```

## Phase Panel Contract

Each phase panel must:
1. Emit `phase_completed` signal when done
2. Accept `setup()` or `initialize()` call with phase data
3. Refresh data on entry (not rely on `_ready()`)
4. Use `TurnPhaseChecklist` to track required/optional actions

## Data Handoff Between Phases

| From Phase | To Phase | Data Key | Contents |
|-----------|----------|----------|----------|
| STORY | TRAVEL | story_events | Array of triggered events |
| TRAVEL | UPKEEP | travel_result | {destination, encounters} |
| MISSION | POST_MISSION | battle_results | Via GameState.set_battle_results() |
| POST_MISSION | ADVANCEMENT | post_battle_data | {loot, injuries, experience} |
| TRADING | CHARACTER | trade_results | {purchased, sold, credits_remaining} |

Inter-phase data uses `GameStateManager.set_temp_data(key, value)`.

## Key Methods

```
# CampaignPhaseManager
start_new_turn() → void
complete_current_phase() → void
start_phase(phase) → bool
complete_phase_action(action: String) → void
calculate_upkeep() → Dictionary    # {crew, equipment, ship, total}
validate_current_campaign() → bool
get_campaign_results() → Dictionary
```
