# SceneRouter Reference

## SceneRouter.gd
- **Path**: `src/ui/screens/SceneRouter.gd`
- **Autoloaded as**: `SceneRouter`

## Signals
```
scene_changed(new_scene: String, previous_scene: String)
navigation_error(scene_name: String, error: String)
```

## Properties
```
use_transitions: bool = true
transition_duration: float = 0.2
current_scene: String
navigation_history: Array[String]
max_history_size: int = 20
preload_enabled: bool = true
max_cache_size: int = 10
```

## Scene Routes (70+ keys)

### Campaign
`campaign_creation`, `campaign_dashboard`, `campaign_turn`, `campaign_turn_controller`, `victory_progress`

### Character
`character_creator`, `character_details`, `character_progression`, `advancement_manager`, `crew_management`

### Equipment/Ships
`equipment_manager`, `equipment_generation`, `ship_manager`, `ship_inventory`

### World/Travel
`world_phase`, `mission_selection`, `patron_rival_manager`, `world_phase_summary`, `travel_phase`

### Battle
`pre_battle`, `battlefield_main`, `tactical_battle`, `post_battle`, `post_battle_sequence`

### Bug Hunt
`bug_hunt_creation`, `bug_hunt_dashboard`, `bug_hunt_turn_controller`

### Battle Simulator
`battle_simulator`

### Store/Expansions
`store`

### Events
`campaign_events`

### Utility
`game_over`, `logbook`, `settings`

### Help
`help`

### Tutorial
`tutorial_selection`, `new_campaign_tutorial`

### Main
`main_menu`, `main_game`, `help`

## Navigation Methods

```gdscript
# Primary navigation
navigate_to(scene_name: String, context: Dictionary = {}, add_to_history: bool = true, with_transition: bool = true) -> void
navigate_back() -> void

# With transitions
navigate_to_with_transition(scene_name, context, add_to_history) -> void
navigate_back_with_transition() -> void

# Shortcuts
start_new_campaign() -> void
return_to_main_menu() -> void
enter_main_game() -> void
open_character_management() -> void
open_equipment_management() -> void
open_ship_management() -> void
start_battle_sequence() -> void
start_post_battle_sequence() -> void

# Campaign phase navigation
navigate_to_campaign_phase(phase: String) -> void
# phases: travel, world, pre_battle, battle, post_battle
```

## Query Methods
```gdscript
get_current_scene() -> String
get_navigation_history() -> Array[String]
has_scene(scene_name: String) -> bool
get_scene_path(scene_name: String) -> String
get_available_scenes() -> Array[String]
get_scenes_by_category(category: String) -> Array[String]
# categories: campaign, character, equipment, world, battle, events, phases, utility, tutorial
```

## Context System
```gdscript
# Pass data between scenes
navigate_to("pre_battle", {"mission": mission_data, "crew": selected_crew})

# Retrieve in target scene
get_scene_context(scene_name: String) -> Dictionary
clear_scene_context(scene_name: String) -> void
```

## Caching
```gdscript
preload_scene(scene_name: String) -> void
preload_campaign_scenes() -> void
clear_scene_cache() -> void
get_cache_info() -> Dictionary
```

## Transition Settings
```gdscript
set_transitions_enabled(enabled: bool) -> void
set_transition_duration(duration: float) -> void
```
