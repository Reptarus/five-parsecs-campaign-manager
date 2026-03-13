# Bug Hunt Turn Flow Reference

## 3-Stage Turn (vs 9-Phase Standard)

```
SPECIAL_ASSIGNMENTS (Stage 0) → MISSION (Stage 1) → POST_BATTLE (Stage 2)
```

## BugHuntPhaseManager
- **Path**: `src/core/campaign/BugHuntPhaseManager.gd`
- **class_name**: BugHuntPhaseManager

### Phase Enum
```gdscript
enum Phase { NONE = -1, SPECIAL_ASSIGNMENTS = 0, MISSION = 1, POST_BATTLE = 2 }
```

### Signals
```
phase_changed(old_phase: int, new_phase: int)
phase_completed(phase: int)
campaign_turn_started(turn_number: int)
campaign_turn_completed(turn_number: int)
navigation_updated(can_back: bool, can_forward: bool)
```

### Key Methods
```
setup(campaign_resource: Resource) -> void
start_new_turn() -> void
get_phase_name(phase: int = -99) -> String
complete_current_phase(result_data: Dictionary = {}) -> void
is_phase_complete(phase: int) -> bool
can_advance() -> bool
go_to_phase(phase: int) -> void
```

### Phase Result Processing
```
_apply_phase_results(phase, data) -> void
_apply_battle_results(result: Dictionary) -> void
_apply_post_battle_results(result: Dictionary) -> void
```

## Architecture

```
MainMenu → BugHuntCreationUI (4-step wizard) → BugHuntDashboard → BugHuntTurnController
  Stage 0: SPECIAL_ASSIGNMENTS → SpecialAssignmentsPanel
  Stage 1: MISSION → BugHuntMissionPanel → TacticalBattleUI (bug_hunt mode)
  Stage 2: POST_BATTLE → BugHuntPostBattlePanel
```

## BugHuntCreationUI (4-Step Wizard)

### Steps
1. **BugHuntConfigPanel** — Campaign name, regiment, difficulty
2. **BugHuntSquadPanel** — 3-4 main characters (create/select)
3. **BugHuntEquipmentPanel** — Assign equipment
4. **BugHuntReviewPanel** — Validate & launch

### Signal Wiring
- Coordinator emits `navigation_updated`, `step_changed`
- Panels emit `*_updated` signals → lambda adapters → coordinator methods
- Navigation buttons → coordinator.next_step(), previous_step(), finalize()

## BugHuntDashboard

### Differences from CampaignDashboard
- No ship/patron/rival sections
- Shows `main_characters` (3-4) instead of full crew
- Shows `grunts` pool (expendable soldiers)
- Displays `movie_magic_used` (10 abilities with checkboxes)
- Uses `reputation: int` (expendable resource)
- Simpler single-phase display
- TweenFX animations: press, breathe, punch_in, fade_in

### Colors (hardcoded Deep Space theme)
```
COLOR_BASE: #1A1A2E, COLOR_ELEVATED: #252542, COLOR_TEXT: #E0E0E0
COLOR_TEXT_SEC: #808080, COLOR_BORDER: #3A3A5C
COLOR_SUCCESS: #10B981, COLOR_WARNING: #D97706, COLOR_ACCENT: #2D5A7B
```

## SceneRouter Keys
```
bug_hunt_creation
bug_hunt_dashboard
bug_hunt_turn_controller
```

## Data Files
15 JSON files in `data/bug_hunt/` — Bug Hunt-specific tables.
