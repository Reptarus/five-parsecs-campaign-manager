# EliteEnemyForce.gd
class_name EliteEnemyForce extends Resource

## Elite Enemy Force Management
## This script defines the composition and generation logic for elite enemy forces,
## adhering to the rules specified in the Five Parsecs From Home Compendium.
##
## This is a COMPENDIUM-ONLY feature and should be gated behind a DLC check.
##
## Setup and Integration:
## 1. Ensure 'data/elite_enemy_types.json' is correctly structured and loaded
##    by the GameDataManager.
## 2. In your mission generation or encounter system (e.g., EnemyGenerator.gd),
##    when an elite encounter is determined, instantiate this class.
## 3. Call the 'generate_composition' method with the desired base size.
## 4. Use the returned array of enemy types to spawn the elite enemies.
## 5. Implement a check for a 'compendium_dlc_unlocked' flag before allowing
##    access to this feature.

const GameDataManager = preload("res://src/core/data/GameDataManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Generates an elite enemy force composition based on a base size.
## This method applies the squad composition rules from the Compendium.
##
## Parameters:
## - base_size: The desired base number of enemies for the encounter.
##
## Returns:
## An Array of Dictionaries, where each Dictionary represents an enemy
## with its type (e.g., "basic", "specialist", "lieutenant", "captain").
##
## DLC Gating: This function should only be called if the Compendium DLC
## is active.
func generate_composition(base_size: int) -> Array[Dictionary]:
    # Ensure minimum size is 4 for elite encounters as per rules
    var size = max(base_size, 4)
    var composition_rules: Array = []

    # Assuming GameDataManager is an autoload or accessible globally
    var game_data_manager = get_node("/root/GameDataManager") # Adjust path if not autoload
    if game_data_manager:
        var elite_data = game_data_manager.get_elite_enemy_types() # Assuming this method exists
        if elite_data and elite_data.has("squad_composition"):
            composition_rules = elite_data["squad_composition"]
        else:
            push_error("Elite enemy squad composition data not found in GameDataManager.")
            return []
    else:
        push_error("GameDataManager not found. Cannot generate elite enemy composition.")
        return []

    var selected_composition: Dictionary = {}
    for rule in composition_rules:
        if rule.get("size") == size or (typeof(rule.get("size")) == TYPE_STRING and rule.get("size") == "7+" and size >= 7):
            selected_composition = rule
            break

    if selected_composition.is_empty():
        push_warning(str("No specific elite composition rule found for size: ", size, ". Using default."))
        # Fallback to a default or basic elite composition if no rule matches
        selected_composition = {"basic": size, "specialists": 0, "lieutenants": 0, "captain": 0}

    var enemy_list: Array[Dictionary] = []

    # Add basic enemies
    for i in range(selected_composition.get("basic", 0)):
        enemy_list.append({"type": "basic"})

    # Add specialists
    for i in range(selected_composition.get("specialists", 0)):
        enemy_list.append({"type": "specialist"})

    # Add lieutenants
    for i in range(selected_composition.get("lieutenants", 0)):
        enemy_list.append({"type": "lieutenant"})

    # Add captain
    if selected_composition.get("captain", 0) > 0:
        enemy_list.append({"type": "captain"})

    # Handle "3+" for basic enemies in "7+" size if applicable
    if typeof(selected_composition.get("basic")) == TYPE_STRING and selected_composition.get("basic") == "3+" and size > 6:
        var additional_basics = size - 6 # For sizes 7, 8, etc.
        for i in range(additional_basics):
            enemy_list.append({"type": "basic"})

    return enemy_list

## Builds the actual enemy Character instances from the generated composition.
## This would typically involve calling the EnemyGenerator or a similar system.
##
## Parameters:
## - composition: An Array of Dictionaries, as returned by generate_composition.
## - faction: The faction of the enemies.
## - difficulty: The overall mission difficulty.
##
## Returns:
## An Array of Character instances representing the elite enemy force.
func build_enemy_force(composition: Array[Dictionary], faction: String, difficulty: int) -> Array[Character]:
    var elite_enemies: Array[Character] = []
    # Placeholder for actual enemy generation logic
    # This would involve iterating through the composition, calling EnemyGenerator
    # or a similar factory to create Character instances, and then applying
    # elite-specific modifications (e.g., from EliteLevelEnemiesManager).
    for enemy_data in composition:
        print(str("Building elite enemy of type: ", enemy_data.type))
        # Example: var enemy_character = EnemyGenerator.create_enemy(enemy_data.type, faction, difficulty)
        # elite_enemies.append(enemy_character)
    return elite_enemies

# --- DLC Gating Example (Conceptual) ---
# This is a conceptual example of how you might gate this feature.
# The actual implementation would depend on your game's DLC management system.
static func is_compendium_dlc_active() -> bool:
    # Replace with actual DLC check logic
    # e.g., return ProjectSettings.get_setting("game/dlc/compendium_unlocked", false)
    # or check a persistent save data flag
    return true # For development/testing, assume true

# --- Documentation for DLC Gating ---
# To gate this feature as paid DLC:
# 1. In your game's main entry point or a central game state manager,
#    implement a system to check if the "Compendium" DLC is owned/unlocked.
# 2. Store this status in a persistent way (e.g., ProjectSettings, save file).
# 3. Before any code attempts to use EliteEnemyForce (e.g., in mission generation
#    or encounter setup), call 'EliteEnemyForce.is_compendium_dlc_active()'.
# 4. If 'false', either prevent the elite encounter from happening, or
#    substitute it with a standard enemy encounter, and inform the player
#    that this feature requires the Compendium DLC.
#
# Example usage in an encounter generation script:
# if EliteEnemyForce.is_compendium_dlc_active():
#     var elite_composition = EliteEnemyForce.new().generate_composition(base_enemy_count)
#     var enemies_to_spawn = EliteEnemyForce.new().build_enemy_force(elite_composition, current_faction, current_difficulty)
# else:
#     # Fallback to standard enemy generation
#     var enemies_to_spawn = EnemyGenerator.generate_standard_enemies(...)
#     print("Elite enemy encounters require the Compendium DLC.")
