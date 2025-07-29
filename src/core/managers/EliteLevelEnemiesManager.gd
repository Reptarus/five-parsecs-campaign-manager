@tool
extends Node

const ELITE_COMBAT_SKILL_BONUS: int = 2
const ELITE_TOUGHNESS_BONUS: int = 2
const ELITE_REACTIONS_BONUS: int = 1

# GlobalEnums available as autoload singleton
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

## Upgrades a regular enemy to an elite version
## Parameters:
	## - enemy: The enemy to upgrade
func upgrade_enemy_to_elite(enemy: Enemy) -> void:
	# Increase core stats
	enemy.stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += ELITE_COMBAT_SKILL_BONUS
	enemy.stats[GlobalEnums.CharacterStats.TOUGHNESS] += ELITE_TOUGHNESS_BONUS
	enemy.stats[GlobalEnums.CharacterStats.REACTIONS] += ELITE_REACTIONS_BONUS

	# Upgrade weapons
	for weapon in enemy.weapons:
		upgrade_weapon_rarity(weapon)

	# Add elite characteristic
	if not GlobalEnums.EnemyCharacteristic.ELITE in enemy.characteristics:
		enemy.characteristics.append(GlobalEnums.EnemyCharacteristic.ELITE)

## Upgrades a weapon's rarity to the next tier
## Parameters:
	## - weapon: The weapon to upgrade
func upgrade_weapon_rarity(weapon: Resource) -> void:
	if weapon.has_method("get_rarity") and weapon.has_method("set_rarity"):
		match weapon.get_rarity():
			GlobalEnums.ItemRarity.COMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.UNCOMMON)
			GlobalEnums.ItemRarity.UNCOMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.RARE)
			GlobalEnums.ItemRarity.RARE:
				weapon.set_rarity(GlobalEnums.ItemRarity.EPIC)
			GlobalEnums.ItemRarity.EPIC:
				weapon.set_rarity(GlobalEnums.ItemRarity.LEGENDARY)
func upgrade_enemy_to_boss(enemy: Enemy) -> void:
	# First make them elite
	upgrade_enemy_to_elite(enemy)

	# Then add boss bonuses
	enemy.stats[GlobalEnums.CharacterStats.SAVVY] += 1
	enemy.stats[GlobalEnums.CharacterStats.TECH] += 1

	# Add boss characteristic
	enemy.characteristics.append(GlobalEnums.EnemyCharacteristic.BOSS)
func get_valid_item_types() -> Array:
	return [GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.MISC]

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

	# Use the autoloaded DataManager singleton directly if available
	@warning_ignore("untyped_declaration")
	var tree = Engine.get_main_loop() as SceneTree
	var elite_data = null
	if tree and tree.root:
		@warning_ignore("unsafe_method_access", "unsafe_cast")
		var data_manager = tree.root.get_node_or_null("DataManagerAutoload")
		if data_manager:
			elite_data = data_manager.get_elite_enemy_types() # Assuming this method exists
	if elite_data and elite_data.has("squad_composition"):
		composition_rules = elite_data["squad_composition"]
	else:
		push_error("Elite enemy squad composition data not found in DataManager.")
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

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
