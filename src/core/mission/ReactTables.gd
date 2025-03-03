@tool
extends Node
class_name ReactTables

## React Tables Implementation for Five Parsecs From Home
## Implements React tables for enemy generation (rulebook p.124-129)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

signal enemies_generated(enemies: Array)
signal enemy_faction_determined(faction: String)

# Data files
const REACT_TABLES_PATH = "res://data/react_tables.json"
const ENEMY_TYPES_PATH = "res://data/enemy_types.json"
const ELITE_ENEMY_TYPES_PATH = "res://data/elite_enemy_types.json"

# Loaded data
var _react_tables: Dictionary = {}
var _enemy_types: Dictionary = {}
var _elite_enemy_types: Array = []
var _data_manager: GameDataManager

# React Tables
enum ReactTable {
    CORE, # Core rulebook table (p.125)
    UNDERWORLD, # Underworld expansion table
    CORPORATE, # Corporate expansion table
    MILITARY # Military expansion table
}

# Enemy distribution types (based on rulebook)
enum EnemyDistribution {
    BALANCED, # Mix of different types
    HEAVY, # Mostly heavy troops
    ELITE, # More elite troops
    LIGHT # Mostly light troops
}

# Campaign difficulty modifiers
var _campaign_difficulty_mod: int = 0
var _mission_danger_mod: int = 0

func _init() -> void:
    _data_manager = GameDataManager.new()
    _load_data()

func _ready() -> void:
    pass

## Load all required data from JSON files
func _load_data() -> void:
    # Load React tables
    var react_tables_data = _data_manager.load_json_file(REACT_TABLES_PATH)
    if react_tables_data:
        _react_tables = react_tables_data
    else:
        push_error("Failed to load React tables data")
    
    # Load enemy types
    var enemy_types_data = _data_manager.load_json_file(ENEMY_TYPES_PATH)
    if enemy_types_data:
        _enemy_types = enemy_types_data
    else:
        push_error("Failed to load enemy types data")
    
    # Load elite enemy types
    var elite_data = _data_manager.load_json_file(ELITE_ENEMY_TYPES_PATH)
    if elite_data and elite_data.has("elite_enemy_types"):
        _elite_enemy_types = elite_data["elite_enemy_types"]
    else:
        push_error("Failed to load elite enemy types data")

## Generate enemies based on the React Table system (rulebook p.124-129)
func generate_enemies(
    danger_level: int,
    mission_type: int,
    location_type: String
) -> Array:
    var enemies = []
    var distribution = _calculate_enemy_distribution(danger_level, mission_type)
    var faction = _determine_enemy_faction(location_type, mission_type)
    
    for enemy_type in distribution:
        for i in range(distribution[enemy_type]):
            var enemy = _create_enemy(enemy_type, faction)
            if enemy:
                enemies.append(enemy)
    
    emit_signal("enemies_generated", enemies)
    return enemies

## Generate enemy for specified mission from the rulebook tables
func generate_mission_enemies(
    mission_type: int,
    danger_level: int,
    enemy_faction: String = ""
) -> Array:
    # Get appropriate distribution based on mission type
    var distribution = EnemyDistribution.BALANCED
    
    # Match mission types to appropriate enemy distributions
    match mission_type:
        GameEnums.MissionType.BLACK_ZONE:
            distribution = EnemyDistribution.ELITE
        GameEnums.MissionType.RAID:
            distribution = EnemyDistribution.HEAVY
        GameEnums.MissionType.PATROL:
            distribution = EnemyDistribution.LIGHT
    
    # Generate enemies with appropriate distribution
    return generate_enemies(
        danger_level,
        mission_type,
        enemy_faction
    )

## Determine the number of enemies based on danger level (rulebook p.124)
func _determine_enemy_count(danger_level: int) -> int:
    var base_count = danger_level + 2
    
    # Apply campaign difficulty modifier
    base_count += _campaign_difficulty_mod
    
    # Apply mission specific danger modifier
    base_count += _mission_danger_mod
    
    # Randomize slightly (+/- 1)
    base_count += (randi() % 3) - 1
    
    # Ensure minimum of 3 enemies
    return max(3, base_count)

## Calculate enemy distribution based on the distribution type (rulebook p.125)
func _calculate_enemy_distribution(danger_level: int, mission_type: int) -> Dictionary:
    var distribution = {}
    var table_key = "danger_level_" + str(danger_level)
    
    if not _react_tables.has(table_key):
        push_error("Invalid danger level: " + str(danger_level))
        return distribution
    
    var base_distribution = _react_tables[table_key].duplicate()
    
    # Adjust distribution based on mission type
    match mission_type:
        GameEnums.MissionType.BLACK_ZONE:
            # Increase difficult enemies for black zone missions
            if base_distribution.has("elite"):
                base_distribution["elite"] += 1
            else:
                base_distribution["elite"] = 1
        
        GameEnums.MissionType.RED_ZONE:
            # Add more enemies for red zone missions
            if base_distribution.has("regular"):
                base_distribution["regular"] += 2
            else:
                base_distribution["regular"] = 2
        
        GameEnums.MissionType.SABOTAGE:
            # Add special defenders for sabotage missions
            if base_distribution.has("specialist"):
                base_distribution["specialist"] += 1
            else:
                base_distribution["specialist"] = 1
    
    return base_distribution

## Determine enemy faction based on React tables (rulebook p.125)
func _determine_enemy_faction(location_type: String, mission_type: int) -> String:
    var possible_factions = ["raiders", "military", "criminals", "aliens"]
    var faction = possible_factions[randi() % possible_factions.size()]
    
    # Adjust faction probability based on mission type
    match mission_type:
        GameEnums.MissionType.PATROL:
            # Patrol missions more likely to encounter raiders
            if randf() < 0.6:
                faction = "raiders"
        
        GameEnums.MissionType.RAID:
            # Raid missions more likely to encounter military
            if randf() < 0.7:
                faction = "military"
        
        GameEnums.MissionType.SABOTAGE:
            # Sabotage missions more likely to encounter military
            if randf() < 0.8:
                faction = "military"
    
    emit_signal("enemy_faction_determined", faction)
    return faction

## Generate an individual enemy based on type and faction (rulebook p.126-127)
func _generate_enemy(faction: String, enemy_type: String) -> Dictionary:
    if not _enemy_types.has(enemy_type) or not _enemy_types[enemy_type].has(faction):
        push_error("Invalid enemy type or faction: " + enemy_type + ", " + faction)
        return {}
    
    var enemy_template = _enemy_types[enemy_type][faction].duplicate()
    _adjust_enemy_stats(enemy_template)
    
    return enemy_template

## Adjust enemy stats based on danger level
func _adjust_enemy_stats(enemy: Dictionary) -> void:
    # Add some randomness to enemy stats
    if enemy.has("health"):
        enemy["health"] = int(enemy["health"] * randf_range(0.9, 1.1))
    
    if enemy.has("morale"):
        enemy["morale"] = int(enemy["morale"] * randf_range(0.9, 1.1))

## Add special abilities to enemies based on danger level (rulebook p.127-128)
func _add_special_abilities(enemies: Array, danger_level: int) -> void:
    # Only add special abilities at danger level 3+
    if danger_level < 3:
        return
    
    # Number of special abilities equals danger level - 2
    var num_abilities = danger_level - 2
    
    # Limit to one ability per every 3 enemies
    num_abilities = min(num_abilities, floor(enemies.size() / 3.0) + 1)
    
    # Distribute abilities
    for i in range(num_abilities):
        if enemies.is_empty():
            break
            
        # Select random enemy (prefer elites and leaders)
        var elite_indices = []
        var other_indices = []
        
        for j in range(enemies.size()):
            if enemies[j].get("type", "") == "elite" or enemies[j].get("type", "") == "leader":
                elite_indices.append(j)
            else:
                other_indices.append(j)
        
        var target_index = -1
        if not elite_indices.is_empty():
            target_index = elite_indices[randi() % elite_indices.size()]
        elif not other_indices.is_empty():
            target_index = other_indices[randi() % other_indices.size()]
        else:
            break
        
        # Select a special ability
        var ability = _select_special_ability(enemies[target_index])
        
        # Add ability to enemy
        var current_abilities = enemies[target_index].get("special_abilities", [])
        if not ability in current_abilities:
            current_abilities.append(ability)
            enemies[target_index]["special_abilities"] = current_abilities

## Select a special ability appropriate for the enemy (rulebook p.128)
func _select_special_ability(enemy: Dictionary) -> String:
    var abilities = [
        "Quick", # +1 Activation dice
        "Accurate", # +1 to Combat
        "Resilient", # +1 to Toughness
        "Aggressive", # +1 to Damage
        "Cautious", # +2 to Defense
        "Camouflaged", # +2 to Defense when in cover
        "Leader", # +1 to Combat for all allies within 6"
        "Armored", # Ignore first hit in combat
        "Gunslinger", # Can fire twice
        "Veteran" # Re-roll one failed dice per activation
    ]
    
    # Special case for leaders
    if enemy.get("type", "") == "leader":
        # Leader ability is always available for leaders
        if randf() < 0.5:
            return "Leader"
    
    # Remove abilities the enemy already has
    var current_abilities = enemy.get("special_abilities", [])
    for ability in current_abilities:
        if ability in abilities:
            abilities.erase(ability)
    
    # Return a random ability
    if abilities.is_empty():
        return "Veteran" # Fallback
    
    return abilities[randi() % abilities.size()]

## Upgrade a weapon to a better version
func _upgrade_weapon(weapon: String) -> String:
    var upgrades = {
        "Pistol": "Heavy Pistol",
        "Heavy Pistol": "Energy Pistol",
        "Rifle": "Combat Rifle",
        "Combat Rifle": "Energy Rifle",
        "Shotgun": "Heavy Shotgun",
        "Heavy Shotgun": "Plasma Cannon",
        "SMG": "Heavy SMG",
        "Heavy SMG": "Dual SMGs",
        "Sword": "Power Sword",
        "Knife": "Sword"
    }
    
    return upgrades.get(weapon, weapon)

## Upgrade armor to a better version
func _upgrade_armor(armor: String) -> String:
    var upgrades = {
        "Light Armor": "Combat Armor",
        "Combat Armor": "Powered Armor",
        "Shield": "Energy Shield"
    }
    
    return upgrades.get(armor, armor)

## Set campaign difficulty modifier
func set_campaign_difficulty(modifier: int) -> void:
    _campaign_difficulty_mod = modifier

## Set mission-specific danger modifier
func set_mission_danger_modifier(modifier: int) -> void:
    _mission_danger_mod = modifier

## Create an enemy based on type and faction
func _create_enemy(enemy_type: String, faction: String) -> Dictionary:
    if not _enemy_types.has(enemy_type) or not _enemy_types[enemy_type].has(faction):
        push_error("Invalid enemy type or faction: " + enemy_type + ", " + faction)
        return {}
    
    var enemy_template = _enemy_types[enemy_type][faction].duplicate()
    _adjust_enemy_stats(enemy_template)
    
    return enemy_template