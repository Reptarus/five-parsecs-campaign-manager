# Equipment & World Systems Reference

## EquipmentManager (Autoload)
- **Path**: `src/core/equipment/EquipmentManager.gd`
- **extends**: Node

### Signals
```
equipment_acquired(equipment_data: Dictionary)
equipment_assigned(character_id: String, equipment_id: String)
equipment_removed(character_id: String, equipment_id: String)
equipment_sold(equipment_id: String, credits: int)
equipment_list_updated()
```

### Equipment Categories
```gdscript
enum EquipmentCategory { WEAPON, ARMOR, GEAR, CONSUMABLE, SPECIAL, CREDITS }
```

### Key Methods
```
setup(state, char_manager, battle_results_manager) -> void
get_sell_value(item) -> int    # condition-aware resale pricing
```

### CRITICAL: Equipment Data Key
Ship stash is stored under `campaign.equipment_data["equipment"]`.
- **CORRECT**: `campaign.equipment_data["equipment"]`
- **WRONG**: `campaign.equipment_data["pool"]` — this was a systemic bug fixed in Phase 22

---

## PlanetDataManager (Autoload)
- **Path**: `src/core/world/PlanetDataManager.gd`
- **extends**: Node

### Signals
```
planet_discovered(planet_data: PlanetData)
planet_visited(planet_id: String, visit_count: int)
planet_data_updated(planet_id: String, update_type: String)
world_event_occurred(planet_id: String, event: Dictionary)
exploration_progress_updated(planet_id: String, progress: float)
```

### PlanetData Inner Class
Properties: `id`, `name`, `type`, `type_name`, `danger_level`, `traits`, `locations`, `special_features`, `discovered_on_turn`, `last_visited_turn`, `visit_count`, `missions_completed`, `resources_extracted`, `exploration_progress`, `active_modifiers`, `temporary_effects`, `world_events`, `contact_ids`, `market_conditions`, `trade_opportunities`, `price_modifiers`

Serialization: `serialize() -> Dictionary`, `deserialize(data: Dictionary) -> void`

### Key Methods
```
get_or_generate_planet(planet_id: String = "", campaign_turn: int = 0) -> PlanetData
set_current_planet(planet_id: String) -> void
get_current_planet() -> PlanetData
complete_mission(planet_id: String, mission_data: Dictionary) -> void
add_world_event(planet_id: String, event: Dictionary) -> void
generate_world_event(planet_id: String) -> Dictionary
apply_temporary_effect(planet_id: String, effect: Dictionary, duration_turns: int) -> void
process_turn_effects(current_turn: int) -> void
get_planet_modifier(planet_id: String, effect_type: String) -> float
get_planet_contacts(planet_id: String) -> Array[String]
add_contact_to_planet(planet_id: String, contact_id: String) -> void
get_exploration_opportunities(planet_id: String) -> Array[Dictionary]
get_planet_stats(planet_id: String) -> Dictionary
serialize_all() -> Dictionary
deserialize_all(data: Dictionary) -> void
get_visited_planets() -> Array[String]
has_visited_planet(planet_id: String) -> bool
get_planet_patrons(planet_id: String) -> Array[String]
get_planet_rivals(planet_id: String) -> Array[String]
```

---

## WorldEconomyManager (Autoload)
- **Path**: `src/core/world/WorldEconomyManager.gd`
- **extends**: Node

### Signals
```
economy_updated
transaction_completed(amount: int, type: String)
```

### Key Methods
```
get_credits() -> int
add_credits(amount: int) -> void
remove_credits(amount: int) -> bool              # returns false if insufficient
get_transaction_history() -> Array
clear_history() -> void
calculate_price_adjustment(location_type: String) -> float
```

### Location Price Multipliers
```
trade_hub:            0.9  (10% discount)
black_market:         1.2  (20% premium)
frontier_outpost:     1.1  (10% premium)
civilian_settlement:  1.0  (standard)
military_base:        1.15 (15% premium)
```

Starting balance: 1000 credits

---

## PlanetCache (Autoload)
- **Path**: `src/core/world/PlanetCache.gd`
- Caches planet data to avoid regeneration
- Works alongside PlanetDataManager

---

## DataManager (Autoload)
- **Path**: `src/core/data/DataManager.gd`
- **extends**: Node

### Signals
```
data_loaded()
data_load_failed(error: String)
initialization_complete()
```

### Key Methods
```
initialize_data_system() -> bool
load_json_file(file_path: String, context: String = "JSON data") -> Dictionary
```

### Data Holders
```gdscript
var character_data: FiveParsecsCharacterData
var combat_data: FiveParsecsCombatDataResource
var campaign_data: FiveParsecsCampaignDataResource
var is_data_loaded: bool
```

---

## GameDataManager (Autoload)
- **Path**: `src/core/managers/GameDataManager.gd`
- **extends**: Node

### Data Stores
```gdscript
var injury_tables: Dictionary
var enemy_types: Dictionary
var world_traits: Dictionary
var planet_types: Dictionary
var location_types: Dictionary
var gear_database: Dictionary
var equipment_database: Dictionary
var loot_tables: Dictionary
var mission_templates: Array
var character_creation_data: Dictionary
var weapons_database: Dictionary
var armor_database: Dictionary
var status_effects: Dictionary
```

### Loading Methods
```
load_all_data() -> bool
load_injury_tables() -> bool
load_enemy_types() -> bool
load_world_traits() -> bool
load_gear_database() -> bool
load_equipment_database() -> bool
load_loot_tables() -> bool
load_mission_templates() -> bool
load_character_creation_data() -> bool
load_weapons_database() -> bool
load_armor_database() -> bool
load_status_effects() -> bool
```

### Accessor Methods
```
get_injury_result(table_name: String, roll: int) -> Dictionary
get_enemy_type(enemy_id: String) -> Dictionary
get_world_trait(trait_id: String) -> Dictionary
get_gear_item(item_id: String) -> Dictionary
get_equipment_item(item_id: String) -> Dictionary
get_loot_table(table_name: String) -> Array
get_random_loot_item(table_name: String) -> Dictionary
get_mission_template(template_id: String) -> Dictionary
get_weapon_by_id(weapon_id: String) -> Dictionary
get_armor_by_id(armor_id: String) -> Dictionary
get_status_effect_by_id(effect_id: String) -> Dictionary
is_data_loaded(data_type: String) -> bool
```

### Static Methods
```
GameDataManager.get_instance() -> Node
GameDataManager.ensure_data_loaded() -> bool
GameDataManager.is_data_type_loaded(data_type: String) -> bool
```
