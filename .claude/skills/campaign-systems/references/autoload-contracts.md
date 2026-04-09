# Campaign Autoload Contracts

## CRITICAL: TransitionManager Scene Init Timing (Session 45)

`TransitionManager.fade_to_scene()` instantiates scenes **before** adding to tree. `_ready()` fires before `/root/` autoloads are accessible. Any scene loaded via `SceneRouter.navigate_to()` that uses `get_node_or_null("/root/...")` in `_ready()` **MUST** defer initialization:

```gdscript
func _ready() -> void:
    call_deferred("_initialize")

func _initialize() -> void:
    var gsm = get_node_or_null("/root/GameStateManager")  # Now safe
```

Known affected: `BugHuntTurnController.gd`. Check any new scene that accesses autoloads in `_ready()`.

---

## CampaignPhaseManager (Autoload)

**Path**: `src/core/campaign/CampaignPhaseManager.gd`

### Signals
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

### PostBattlePhase Handler (Session 47 rewiring)
```
# CampaignPhaseManager owns the PostBattlePhase orchestrator as a child node.
# Preload: src/core/campaign/phases/PostBattlePhase.gd (14-step decomposed)
# NOT src/core/campaign/PostBattlePhase.gd (old 5-step stub — DEPRECATED)
#
# Init: PostBattlePhaseClass.new() → set_campaign(campaign) → add_child()
# Signal: post_battle_phase_completed (NOT phase_completed)
# Entry: start_post_battle_phase(battle_data) with GameState.get_battle_results()
# Campaign ref updated in _connect_to_campaign() for save/load
```

### Public API
```
setup(state: FiveParsecsGameState) → void
# Turn rollover routes story points through StoryPointSystem:
# - reset_turn_limits() resets per-turn spending flags
# - check_turn_earning(turn_number) awards +1 SP every 3rd turn
# - Insanity mode check applied (story points disabled)
# - Persists back to campaign.story_point_turn_state + campaign.story_points
get_current_phase() → FiveParcsecsCampaignPhase
get_turn_number() → int
set_campaign(campaign: Resource) → void
start_new_turn() → void                 # calls _process_turn_rollover() internally
start_new_campaign_turn() → void        # alias
# Turn rollover sequence (called by start_new_turn):
#   1. _restore_crew_luck()                    — Core Rules p.91
#   2. _process_sick_bay_recovery()            — Core Rules p.99
#   3. _process_character_event_effects()      — Core Rules pp.128-130 (Session 51)
#   4. _process_patron_expiration()            — Core Rules p.81-88
#   5. Story Points reset + auto-award         — Core Rules pp.66-67
#   6. Planet effects expiry
#   7. Victory condition check                 — Core Rules p.64
complete_current_turn() → void
complete_current_phase() → void
start_phase(new_phase) → bool
start_sub_phase(new_sub_phase) → bool
complete_phase_action(action: String) → void
reset_phase_tracking() → void
validate_current_campaign() → bool
setup_battle() → bool
get_campaign_results() → Dictionary
calculate_upkeep() → Dictionary          # {crew, equipment, ship, total}
advance_campaign() → bool
```

---

## GameState (Autoload)

**Path**: `src/core/state/GameState.gd`

### Signals
```
state_changed
campaign_loaded(campaign)
campaign_saved
save_started
save_completed(success: bool, message: String)
load_started
load_completed(success: bool, message: String)
```

### Campaign Management
```
new_campaign(campaign_data: Dictionary) → Campaign
set_current_campaign(campaign) → void
get_current_campaign() → Resource
start_new_campaign(config) → bool
save_campaign(campaign, path: String = "") → Dictionary
load_campaign(path: String) → Dictionary
import_campaign(external_path: String) → Dictionary
get_available_campaigns() → Array
auto_save() → void
```

### State Accessors
```
get_turn_number() → int
set_turn_number(value: int) → bool
get_story_points() → int
set_story_points(value: int) → bool
get_reputation() → int
set_reputation(value: int) → bool
get_current_phase() → int
set_current_phase(value: int) → bool
get_resource(resource: int) → int
set_resource(resource: int, value: int) → bool
get_difficulty_level() → int
is_permadeath_enabled() → bool
is_auto_save_enabled() → bool
```

### Battle/Mission
```
set_battle_results(results: Dictionary) → void
get_battle_results() → Dictionary
clear_battle_results() → void
set_battlefield_data(data: Dictionary) → void
get_battlefield_data() → Dictionary
get_current_mission() → Dictionary
get_active_crew() → Array
get_current_enemies() → Array
has_crew() → bool
get_crew_size() → int
```

---

## GameStateManager (Autoload)

**Path**: `src/core/managers/GameStateManager.gd`

### Signals
```
game_state_changed(new_state: int)
campaign_phase_changed(new_phase: int)
difficulty_changed(new_difficulty: int)
credits_changed(new_amount: int)
supplies_changed(new_amount: int)
reputation_changed(new_amount: int)
story_progress_changed(new_amount: int)
```

### Resources
```
set_credits(amount: int) → void
add_credits(amount: int) → void
remove_credits(amount: int) → bool
modify_credits(amount: int) → void
set_supplies(amount: int) → void
set_reputation(amount: int) → void
add_reputation(amount: int) → void
add_story_points(amount: int) → void
```

### Campaign Delegation
```
get_crew_members() → Array
get_crew_size() → int
get_ship() → Dictionary
get_ship_debt() → int
get_current_world() → Dictionary
get_patrons() → Array
get_rivals() → Array
get_victory_conditions() → Dictionary
```

### Temp Data (Inter-Screen Communication)
```
set_temp_data(key: String, value) → void
get_temp_data(key: String, default = null) → Variant
has_temp_data(key: String) → bool
clear_temp_data(key: String) → void
```

### Navigation
```
navigate_to_screen(screen_name: String) → void
navigate_to_scene_path(scene_path: String) → void
```

---

## CampaignJournal (Autoload)

**Path**: `src/core/campaign/CampaignJournal.gd`

### Signals
```
entry_created(entry: Dictionary)
entry_updated(entry_id: String)
entry_deleted(entry_id: String)
timeline_updated()
```

### Entry Management
```
create_entry(data: Dictionary) → String
update_entry(entry_id: String, data: Dictionary) → bool
delete_entry(entry_id: String) → bool
get_entry(entry_id: String) → Dictionary
get_all_entries() → Array[Dictionary]
```

### Auto-Generation
```
auto_create_battle_entry(battle_result: Dictionary) → void
auto_create_milestone_entry(milestone_type: String, data: Dictionary) → void
auto_create_character_event(character_id: String, event_type: String, details: Dictionary) → void
```

### Timeline & Filtering
```
get_timeline_data() → Dictionary
get_milestones() → Array[Dictionary]
filter_entries(filter: Dictionary) → Array[Dictionary]
get_character_history(character_id: String) → Dictionary
get_character_statistics(character_id: String) → Dictionary
get_top_performers(stat: String, limit: int) → Array
get_crew_stats_summary() → Dictionary
```

### Export
```
export_to_markdown(file_path: String) → bool
export_to_json(file_path: String) → bool
```

### Save/Load
```
initialize_for_campaign(campaign_id: String) → void
load_from_save(save_data: Dictionary) → void
save_to_dict() → Dictionary
```

---

## TurnPhaseChecklist (Autoload)

**Path**: `src/qol/TurnPhaseChecklist.gd`

### Signals
```
action_completed(action_id: String)
phase_validation_changed(can_advance: bool)
```

### Phase Checklists (const)
```
upkeep:      required=[pay_crew_upkeep, pay_ship_maintenance, resolve_injuries]
world_steps: required=[patron_job_check, enemy_encounter_check]
battle:      required=[deploy_crew, fight_battle, resolve_casualties]
post_battle: required=[collect_loot, resolve_injuries, gain_experience]
```

### Key Methods
```
get_phase_checklist(phase: String) → Dictionary    # {required, optional}
load_checklist_for_phase(phase: String) → void
mark_action_complete(action_id: String, completed: bool = true) → void
can_advance_phase() → bool
get_incomplete_required_actions() → Array[String]
get_completion_status() → Dictionary
get_action_description(action_id: String) → String
load_from_save(save_data: Dictionary) → void
save_to_dict() → Dictionary
```
