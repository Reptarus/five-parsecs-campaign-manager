# Bug Hunt Data Model Reference

## BugHuntCampaignCore (Resource)
- **class_name**: BugHuntCampaignCore
- **extends**: Resource
- **SEPARATE from FiveParsecsCampaignCore**

## Data Model Comparison

| Aspect | Bug Hunt | Standard 5PFH |
|--------|----------|---------------|
| Core class | `BugHuntCampaignCore` | `FiveParsecsCampaignCore` |
| Characters | `main_characters: Array` (flat) | `crew_data["members"]` (nested Dict) |
| Expendables | `grunts: Array` | None |
| Ship | None | Full ship system |
| Patrons/Rivals | None | Full patron/rival system |
| Resources | `reputation: int` (expendable) | Patron relationships |
| Turn structure | 3-stage | 9-phase |
| Abilities | `movie_magic_used: Dictionary` (10 one-time) | None equivalent |
| Squad org | `combat_teams: Array` | None |
| Injury system | `sick_bay: Dictionary` | Per-character injuries |

## Key Properties

### Meta
```gdscript
schema_version: int
campaign_name: String
campaign_id: String
campaign_type: String = "bug_hunt"
```

### Config
```gdscript
regiment_name: String
uniform_color: String
difficulty: String
```

### Squad
```gdscript
main_characters: Array      # 3-4 Character dicts (flat list)
grunts: Array               # Simplified stat blocks (expendable)
combat_teams: Array         # Squad organization
```

### Resources
```gdscript
reputation: int             # Expendable resource (not relationship-based)
operational_progress_modifier: int
extra_contact_markers: int
extra_support_rolls: int
```

### Abilities
```gdscript
movie_magic_used: Dictionary  # ability_id → bool (10 one-time abilities)
support_teams_available: Array
```

### State
```gdscript
sick_bay: Dictionary          # character_id → turns_remaining
completed_assignments: Dictionary
military_life_modifiers: Dictionary
current_mission: Dictionary
game_phase: String            # "creation" | "active" | "completed"
campaign_turn: int
```

### Progress
```gdscript
total_objectives_completed: int
total_missions_played: int
missions_in_current_operation: int
```

## Key Methods
```
# Config
set_config(data: Dictionary) -> void
initialize_squad(characters: Array, grunt_data: Array) -> void

# Characters
add_main_character(char_dict: Dictionary) -> void
remove_main_character(character_id: String) -> void
get_main_character_by_id(character_id: String) -> Variant
get_active_main_characters() -> Array

# Movie Magic (10 one-time abilities)
use_movie_magic(ability_id: String) -> bool
is_movie_magic_available(ability_id: String) -> bool
get_available_movie_magic() -> Array[String]

# Sick Bay
add_to_sick_bay(character_id: String, turns: int) -> void
tick_sick_bay() -> Array[String]   # Returns recovered character IDs

# Reputation
spend_reputation(amount: int) -> bool
add_reputation(amount: int) -> void

# Lifecycle
start_campaign() -> void
advance_turn() -> void
validate() -> bool
get_validation_errors() -> Array[String]

# Serialization
to_dictionary() -> Dictionary
from_dictionary(data: Dictionary) -> void
save_to_file(path: String) -> Error
load_from_file(path: String) -> BugHuntCampaignCore  # static
create_new_campaign(name, difficulty) -> BugHuntCampaignCore  # static
```

## Campaign Type Detection

`GameState._detect_campaign_type(data)` peeks JSON:
```gdscript
if "main_characters" in data:
    return "bug_hunt"      # Route to BugHuntCampaignCore
return "standard"          # Route to FiveParsecsCampaignCore
```

Always validate: `"main_characters" in campaign` before Bug Hunt code runs.
