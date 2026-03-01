# Data Architecture

**Last Updated**: July 2025
**Status**: Implemented and Production-Ready

## Overview

The Five Parsecs Campaign Manager employs a robust, hybrid data architecture that combines the performance and type-safety of Godot's built-in enums with the flexibility and richness of JSON-based data files. This system is managed by the `DataManager` autoload script, which serves as the single source of truth for all game data.

## Data Manager

The `DataManager` (`src/core/data/DataManager.gd`) is a globally accessible autoload script responsible for:

-   **Loading Data:** It loads all game data from JSON files at startup.
-   **Caching:** It caches all data in memory for high-performance access.
-   **Validation:** It validates the integrity of the data and checks for consistency.
-   **Hot-Reloading:** It supports hot-reloading of data in development builds for rapid iteration.
-   **API:** It provides a simple, consistent API for accessing all game data.

## Data Files

All game data is stored in JSON files located in the `data` directory. The `DataManager` loads data from the following files:

-   `data/RulesReference/` - A collection of JSON files that act as an in-game reference for the Five Parsecs rulebook.
-   `data/Tutorials/` - Contains the data for the in-game tutorials.
-   `data/armor.json`
-   `data/battle_rules.json`
-   `data/battlefield/` - A directory containing data for battlefield generation, including features, objectives, and rules.
-   `data/battlefield_tables/` - Tables for generating cover, hazards, and strategic points.
-   `data/campaign_tables/` - A comprehensive set of tables for campaign events, mission generation, and crew tasks.
-   `data/character_backgrounds.json`
-   `data/character_creation_data.json`
-   `data/character_creation_tables/` - Tables for character creation, including background events, connections, and equipment.
-   `data/character_skills.json`
-   `data/character_species.json`
-   `data/elite_enemy_types.json`
-   `data/enemies/` - Data for different enemy types, including corporate security, pirates, and wildlife.
-   `data/equipment_database.json`
-   `data/event_tables.json`
-   `data/expanded_connections.json`
-   `data/expanded_missions.json`
-   `data/expanded_quest_progressions.json`
-   `data/gear_database.json`
-   `data/injury_table.json`
-   `data/location_types.json`
-   `data/loot_tables.json`
-   `data/mission_templates.json`
-   `data/missions/` - Data for patron and opportunity missions.
-   `data/patron_types.json`
-   `data/planet_types.json`
-   `data/psionic_powers.json`
-   `data/resources.json`
-   `data/ship_components.json`
-   `data/skill_proression.json`
-   `data/status_effects.json`
-   `data/weapons.json`
-   `data/world_traits.json`

## Data Access

All game data should be accessed through the `DataManager` API. This ensures that data is always accessed in a safe and consistent manner. The API provides methods for retrieving data related to characters, equipment, missions, and more.

## Data Handling Patterns & Safety

### Critical Data Handling Insights
Through comprehensive end-to-end testing, we've identified critical patterns for safe data handling, particularly around numerical data that drives campaign gameplay:

#### **Testing vs Production Data Differences**
One of the most important architectural discoveries is the difference in data handling between testing and production environments:

**Production Environment:**
```gdscript
# Real Character objects with proper typing
var character = Character.new()
character.combat = 5
character.toughness = 6
character.savvy = 7
```

**Testing Environment (Fallback Pattern):**
```gdscript
# Dictionary fallbacks for safe testing
var character = {
    "combat": 5,
    "toughness": 6, 
    "savvy": 7
}
# Safe access pattern
var combat = character.combat if typeof(character) == TYPE_OBJECT else character.combat
```

### **Number Safety Architecture**
Given the complexity of Five Parsecs campaigns with numerous numerical calculations (character stats, credits, equipment values, ship components), we've implemented comprehensive number safety patterns:

#### **Safe Numerical Access**
```gdscript
# Safe property access with type validation
func safe_get_stat(character: Variant, stat_name: String, default: int = 0) -> int:
    if character == null:
        return default
    if typeof(character) == TYPE_OBJECT and stat_name in character:
        var value = character.get(stat_name)
        return value if value is int else default
    elif character is Dictionary:
        return character.get(stat_name, default)
    return default
```

#### **Credit and Equipment Value Safety**
```gdscript
# Safe credit calculations with validation
func calculate_total_credits(equipment_list: Array, starting_credits: int = 0) -> int:
    var total = starting_credits
    for item in equipment_list:
        if item is Dictionary and item.has("credits"):
            var credits = item.credits
            if credits is int and credits > 0:
                total += credits
    return max(0, total)  # Ensure non-negative
```

### **Data Validation Architecture**

#### **Campaign Data Validation**
All campaign data undergoes comprehensive validation before use:

```gdscript
func validate_campaign_data(campaign_data: Dictionary) -> ValidationResult:
    var result = ValidationResult.new()
    
    # Validate essential keys exist
    var required_keys = ["config", "crew", "captain", "ship", "equipment"]
    for key in required_keys:
        if not campaign_data.has(key):
            result.add_error("Missing required key: " + key)
    
    # Validate crew data integrity
    if campaign_data.has("crew") and campaign_data.crew is Array:
        for i in range(campaign_data.crew.size()):
            var character = campaign_data.crew[i]
            if not _validate_character_data(character):
                result.add_error("Invalid character data at index " + str(i))
    
    return result
```

## Example Usage

```gdscript
# Get character origin data
var origin_data = DataManager.get_origin_data("HUMAN")

# Get weapon data with safety validation
var weapon_data = DataManager.get_weapon_data("LASER_PISTOL")
if weapon_data and weapon_data.has("damage"):
    var damage = weapon_data.damage if weapon_data.damage is int else 0

# Get all character backgrounds
var all_backgrounds = DataManager.get_all_backgrounds()

# Safe campaign data access
var campaign = load_campaign_safely("campaign_save.dat")
if campaign and _validate_campaign_data(campaign).is_valid():
    var crew_count = campaign.crew.size() if campaign.crew is Array else 0
```

## Production Data Integrity

### **Character Data Integrity**
Character data represents one of the most critical aspects of campaign management:

- **Stat Validation**: All character stats validated within Five Parsecs ranges (typically 1-6)
- **Health Calculation**: Health always calculated as Toughness + bonus (2 for crew, 3 for captains)
- **Equipment Assignment**: All equipment properly linked to character owners
- **Credit Tracking**: All monetary values validated and bounded

### **Campaign Turn Data Safety**
Given the complexity of campaign turns with multiple numerical calculations:

- **Resource Tracking**: Credits, fuel, supplies all validated on each access
- **Progress Tracking**: Mission completion, character advancement safely calculated
- **State Persistence**: All numerical data properly serialized and validated on load

### **Error Recovery Patterns**
The data architecture includes comprehensive error recovery:

```gdscript
# Graceful degradation for missing data
func get_character_stat_safe(character: Variant, stat: String) -> int:
    # Try production path first
    if character is Character and stat in character:
        return character.get(stat)
    
    # Fall back to dictionary access
    elif character is Dictionary and character.has(stat):
        var value = character[stat]
        return value if value is int else 0
    
    # Final fallback to reasonable default
    return _get_stat_default(stat)
```

This robust data architecture ensures that the Five Parsecs Campaign Manager can handle the complex numerical requirements of campaign gameplay while maintaining data integrity across all scenarios, from testing to production deployment.
