@tool
extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const CharacterManager = preload("res://src/core/character/Management/CharacterManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")

signal equipment_acquired(equipment_data: Dictionary)
signal equipment_assigned(character_id: String, equipment_id: String)
signal equipment_removed(character_id: String, equipment_id: String)
signal equipment_sold(equipment_id: String, credits: int)
signal equipment_list_updated()

var character_manager
var game_state: FiveParsecsGameState
var battle_results_manager: BattleResultsManager

# Equipment categories
enum EquipmentCategory {
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	SPECIAL,
	CREDITS
}

# Equipment storage
var _equipment_storage: Array = []
var _character_equipment: Dictionary = {}

func _init() -> void:
	pass

func _ready() -> void:
	pass

func setup(state: FiveParsecsGameState, char_manager, battle_results_manager: BattleResultsManager) -> void:
	game_state = state
	character_manager = char_manager
	battle_results_manager = battle_results_manager
	
	# Connect to character signals
	if character_manager:
		if character_manager.is_connected("character_added", _on_character_added):
			character_manager.disconnect("character_added", _on_character_added)
		character_manager.connect("character_added", _on_character_added)
		
		if character_manager.is_connected("character_removed", _on_character_removed):
			character_manager.disconnect("character_removed", _on_character_removed)
		character_manager.connect("character_removed", _on_character_removed)

## Equipment Management Functions

## Add new equipment to storage
func add_equipment(equipment_data: Dictionary) -> bool:
	if equipment_data.is_empty() or not equipment_data.has("id"):
		push_error("Invalid equipment data")
		return false
	
	# Check for duplicate IDs
	for item in _equipment_storage:
		if item.get("id") == equipment_data.get("id"):
			push_error("Equipment with ID already exists: " + equipment_data.get("id"))
			return false
	
	_equipment_storage.append(equipment_data)
	equipment_acquired.emit(equipment_data)
	equipment_list_updated.emit()
	
	return true

## Get equipment by ID
func get_equipment(equipment_id: String) -> Dictionary:
	for item in _equipment_storage:
		if item.get("id") == equipment_id:
			return item
	
	return {}

## Remove equipment from storage
func remove_equipment(equipment_id: String) -> bool:
	for i in range(_equipment_storage.size() - 1, -1, -1):
		if _equipment_storage[i].get("id") == equipment_id:
			_equipment_storage.remove_at(i)
			
			# Remove from any characters who might have it
			for character_id in _character_equipment:
				var equipment_list = _character_equipment[character_id]
				for j in range(equipment_list.size() - 1, -1, -1):
					if equipment_list[j] == equipment_id:
						equipment_list.remove_at(j)
						equipment_removed.emit(character_id, equipment_id)
			
			equipment_list_updated.emit()
			return true
	
	return false

## Assign equipment to a character
func assign_equipment_to_character(character_id: String, equipment_id: String) -> bool:
	if not character_manager.has_character(character_id):
		push_error("Character does not exist: " + character_id)
		return false
	
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		push_error("Equipment does not exist: " + equipment_id)
		return false
	
	# Initialize equipment list for character if needed
	if not character_id in _character_equipment:
		_character_equipment[character_id] = []
	
	# Check equipment type and compatibility
	var character = character_manager.get_character(character_id)
	if not _can_character_use_equipment(character, equipment_data):
		push_warning("Character cannot use this equipment")
		return false
	
	# Check equipment slots
	if equipment_data.get("category") == EquipmentCategory.ARMOR:
		# Remove existing armor first
		for eq_id in _character_equipment[character_id]:
			var eq = get_equipment(eq_id)
			if eq.get("category") == EquipmentCategory.ARMOR:
				_character_equipment[character_id].erase(eq_id)
				equipment_removed.emit(character_id, eq_id)
				break
	
	# Add equipment to character
	_character_equipment[character_id].append(equipment_id)
	
	# Update the actual character object with equipment
	_update_character_with_equipment(character_id)
	
	equipment_assigned.emit(character_id, equipment_id)
	equipment_list_updated.emit()
	return true

## Remove equipment from a character
func remove_equipment_from_character(character_id: String, equipment_id: String) -> bool:
	if not character_id in _character_equipment:
		return false
	
	var equipment_list = _character_equipment[character_id]
	if equipment_id in equipment_list:
		equipment_list.erase(equipment_id)
		
		# Update the character object
		_update_character_with_equipment(character_id)
		
		equipment_removed.emit(character_id, equipment_id)
		equipment_list_updated.emit()
		return true
	
	return false

## Get all equipment assigned to a character
func get_character_equipment(character_id: String) -> Array:
	if not character_id in _character_equipment:
		return []
	
	return _character_equipment[character_id].duplicate()

## Get all equipment in storage
func get_all_equipment() -> Array:
	return _equipment_storage.duplicate()

## Get equipment of a specific category
func get_equipment_by_category(category: int) -> Array:
	var filtered_equipment = []
	
	for item in _equipment_storage:
		if item.get("category") == category:
			filtered_equipment.append(item)
	
	return filtered_equipment

## Sell equipment and generate credits
func sell_equipment(equipment_id: String) -> int:
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		return 0
	
	# Calculate sell value
	var base_value = equipment_data.get("value", 0)
	var condition = equipment_data.get("condition", 100)
	
	# Value is a percentage of base value based on condition
	var sell_value = int(base_value * (condition / 100.0) * 0.5) # 50% of value
	
	# Remove equipment
	if remove_equipment(equipment_id):
		if game_state:
			game_state.add_credits(sell_value)
		
		equipment_sold.emit(equipment_id, sell_value)
		return sell_value
	
	return 0

## Generate loot from battles according to Five Parsecs rulebook tables
func generate_battle_loot(difficulty: int, success: bool = true) -> Array:
	var loot_items = []
	
	# Only generate loot if the battle was a success and crew held the field
	if not success:
		return loot_items
	
	# In Five Parsecs, you get to roll once on the Loot Table after winning a battle
	# Additional rolls might be granted for special conditions
	
	# Roll on the main loot table
	loot_items.append(_roll_on_loot_table())
	
	# Get current battle data from the battle results manager, if available
	var current_battle = {}
	if battle_results_manager != null:
		current_battle = battle_results_manager.get_current_battle() if battle_results_manager.has_method("get_current_battle") else {}
	
	# Check for Black Zone mission bonus roll (rulebook rule)
	if current_battle and current_battle.get("mission_type") == GameEnums.MissionType.BLACK_ZONE:
		loot_items.append(_roll_on_loot_table())
	
	# Check for high-danger mission bonus roll
	if difficulty >= 4:
		loot_items.append(_roll_on_loot_table())
	
	return loot_items

## Roll on the Five Parsecs loot table and return an item
func _roll_on_loot_table() -> Dictionary:
	# Roll D100 to determine the loot type as per rulebook
	var roll = randi() % 100 + 1
	
	if roll <= 10:
		# Credits (small amount)
		return {
			"id": "credits_" + str(randi() % 10000),
			"name": "Small Credit Pouch",
			"category": EquipmentCategory.CREDITS,
			"credits": 50 + (randi() % 6) * 10, # 50-100 credits
			"value": 0
		}
	elif roll <= 20:
		# Credits (medium amount)
		return {
			"id": "credits_" + str(randi() % 10000),
			"name": "Credit Stick",
			"category": EquipmentCategory.CREDITS,
			"credits": 100 + (randi() % 11) * 10, # 100-200 credits
			"value": 0
		}
	elif roll <= 25:
		# Credits (large amount, rare)
		return {
			"id": "credits_" + str(randi() % 10000),
			"name": "Valuable Credit Chip",
			"category": EquipmentCategory.CREDITS,
			"credits": 200 + (randi() % 11) * 20, # 200-400 credits
			"value": 0
		}
	elif roll <= 40:
		# Standard Weapon
		return _generate_weapon_by_rulebook()
	elif roll <= 55:
		# Armor
		return _generate_armor_by_rulebook()
	elif roll <= 65:
		# Medical Supplies
		return create_gear_item("Medical Kit", "medkit", {"healing": 1 + (randi() % 3)})
	elif roll <= 75:
		# Targeting System
		return create_gear_item("Targeting System", "targeting", {"accuracy": 1 + (randi() % 2)})
	elif roll <= 85:
		# Utility Item
		return _generate_utility_item()
	elif roll <= 95:
		# Rare Equipment
		return _generate_rare_equipment()
	else:
		# Unique Item (very rare, powerful)
		return _generate_unique_item()

## Generate a weapon based on the rulebook's weapon tables
func _generate_weapon_by_rulebook() -> Dictionary:
	# Roll for weapon type according to rulebook probability
	var weapon_type_roll = randi() % 100 + 1
	var weapon_type = GameEnums.WeaponType.BASIC
	
	if weapon_type_roll <= 40:
		weapon_type = GameEnums.WeaponType.PISTOL
	elif weapon_type_roll <= 75:
		weapon_type = GameEnums.WeaponType.RIFLE
	elif weapon_type_roll <= 90:
		weapon_type = GameEnums.WeaponType.ADVANCED
	else:
		weapon_type = GameEnums.WeaponType.HEAVY
	
	# Roll for weapon quality
	var quality_roll = randi() % 100 + 1
	var damage_bonus = 0
	var range_bonus = 0
	var weapon_condition = 100
	var name_prefix = "Standard"
	
	if quality_roll <= 10:
		# Poor quality
		weapon_condition = 60 + (randi() % 21) # 60-80%
		name_prefix = "Worn"
	elif quality_roll <= 25:
		# Below average
		weapon_condition = 80 + (randi() % 11) # 80-90%
		name_prefix = "Used"
	elif quality_roll <= 75:
		# Average quality
		weapon_condition = 90 + (randi() % 11) # 90-100%
		name_prefix = "Standard"
	elif quality_roll <= 90:
		# Good quality
		damage_bonus = 1
		name_prefix = "Enhanced"
	else:
		# Excellent quality
		damage_bonus = 1
		range_bonus = 1
		name_prefix = "Superior"
	
	# Base stats based on weapon type
	var base_damage = 0
	var base_range = 0
	var weapon_name = ""
	
	match weapon_type:
		GameEnums.WeaponType.PISTOL:
			base_damage = 1
			base_range = 1
			weapon_name = name_prefix + " Pistol"
		GameEnums.WeaponType.RIFLE:
			base_damage = 2
			base_range = 2
			weapon_name = name_prefix + " Rifle"
		GameEnums.WeaponType.ADVANCED:
			base_damage = 3
			base_range = 2
			weapon_name = name_prefix + " Advanced Weapon"
		GameEnums.WeaponType.HEAVY:
			base_damage = 4
			base_range = 1
			weapon_name = name_prefix + " Heavy Weapon"
		_:
			base_damage = 1
			base_range = 1
			weapon_name = name_prefix + " Basic Weapon"
	
	# Create the weapon with appropriate stats
	var weapon = create_weapon_item(
		weapon_name,
		weapon_type,
		base_damage + damage_bonus,
		base_range + range_bonus
	)
	
	# Set the condition
	weapon["condition"] = weapon_condition
	
	return weapon

## Generate armor based on the rulebook's armor tables
func _generate_armor_by_rulebook() -> Dictionary:
	# Roll for armor type
	var armor_type_roll = randi() % 100 + 1
	var armor_type = GameEnums.ArmorType.LIGHT
	
	if armor_type_roll <= 60:
		armor_type = GameEnums.ArmorType.LIGHT
	elif armor_type_roll <= 90:
		armor_type = GameEnums.ArmorType.MEDIUM
	else:
		armor_type = GameEnums.ArmorType.HEAVY
	
	# Roll for armor quality
	var quality_roll = randi() % 100 + 1
	var protection_bonus = 0
	var armor_condition = 100
	var name_prefix = "Standard"
	
	if quality_roll <= 10:
		# Poor quality
		armor_condition = 60 + (randi() % 21) # 60-80%
		name_prefix = "Patched"
	elif quality_roll <= 25:
		# Below average
		armor_condition = 80 + (randi() % 11) # 80-90%
		name_prefix = "Used"
	elif quality_roll <= 75:
		# Average quality
		armor_condition = 90 + (randi() % 11) # 90-100%
		name_prefix = "Standard"
	elif quality_roll <= 90:
		# Good quality
		protection_bonus = 1
		name_prefix = "Reinforced"
	else:
		# Excellent quality
		protection_bonus = 2
		name_prefix = "Superior"
	
	# Base protection based on armor type
	var base_protection = 0
	var armor_name = ""
	
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			base_protection = 1
			armor_name = name_prefix + " Light Armor"
		GameEnums.ArmorType.MEDIUM:
			base_protection = 2
			armor_name = name_prefix + " Medium Armor"
		GameEnums.ArmorType.HEAVY:
			base_protection = 3
			armor_name = name_prefix + " Heavy Armor"
		_:
			base_protection = 1
			armor_name = name_prefix + " Armor"
	
	# Create the armor with appropriate stats
	var armor = create_armor_item(
		armor_name,
		armor_type,
		base_protection + protection_bonus
	)
	
	# Set the condition
	armor["condition"] = armor_condition
	
	return armor

## Generate utility items based on the rulebook's gear tables
func _generate_utility_item() -> Dictionary:
	var utility_types = [
		"scanner",
		"toolkit",
		"communicator",
		"field rations",
		"climbing gear"
	]
	
	var selected_type = utility_types[randi() % utility_types.size()]
	var effect = {}
	
	match selected_type:
		"scanner":
			effect = {"detection": 1 + (randi() % 2)}
		"toolkit":
			effect = {"repair": 1 + (randi() % 2)}
		"communicator":
			effect = {"communication": 1 + (randi() % 2)}
		"field rations":
			effect = {"survival": 1 + (randi() % 2)}
		"climbing gear":
			effect = {"mobility": 1 + (randi() % 2)}
	
	return create_gear_item("Utility " + selected_type.capitalize(), selected_type, effect)

## Generate rare equipment based on the rulebook's rare find tables
func _generate_rare_equipment() -> Dictionary:
	var rare_types = [
		"shield generator",
		"stealth field",
		"combat stims",
		"bionic enhancement",
		"rare weapon mod"
	]
	
	var selected_type = rare_types[randi() % rare_types.size()]
	var effect = {}
	
	match selected_type:
		"shield generator":
			effect = {"defense": 2 + (randi() % 2)}
		"stealth field":
			effect = {"stealth": 2 + (randi() % 2)}
		"combat stims":
			effect = {"reaction": 2 + (randi() % 2)}
		"bionic enhancement":
			effect = {"attribute": 1, "attribute_type": ["strength", "speed", "reaction"][randi() % 3]}
		"rare weapon mod":
			effect = {"damage": 1, "accuracy": 1}
	
	return create_gear_item("Rare " + selected_type.capitalize(), selected_type, effect)

## Generate unique powerful items (very rare)
func _generate_unique_item() -> Dictionary:
	var unique_items = [
		{
			"name": "Experimental Weapon Prototype",
			"type": "weapon",
			"stats": {
				"weapon_type": GameEnums.WeaponType.SPECIAL,
				"damage": 5,
				"range": 3
			}
		},
		{
			"name": "Advanced Power Armor",
			"type": "armor",
			"stats": {
				"armor_type": GameEnums.ArmorType.POWERED,
				"protection": 4
			}
		},
		{
			"name": "Alien Artifact",
			"type": "gear",
			"gear_type": "artifact",
			"effect": {"special": 3, "description": "Unknown alien technology with powerful effects"}
		},
		{
			"name": "Neural Interface",
			"type": "gear",
			"gear_type": "augment",
			"effect": {"skills": 2, "reaction": 2}
		}
	]
	
	var selected_item = unique_items[randi() % unique_items.size()]
	
	match selected_item.type:
		"weapon":
			return create_weapon_item(
				selected_item.name,
				selected_item.stats.weapon_type,
				selected_item.stats.damage,
				selected_item.stats.range
			)
		"armor":
			return create_armor_item(
				selected_item.name,
				selected_item.stats.armor_type,
				selected_item.stats.protection
			)
		"gear":
			return create_gear_item(
				selected_item.name,
				selected_item.gear_type,
				selected_item.effect
			)
		_:
			return create_gear_item(
				"Mysterious Item",
				"unknown",
				{"unknown": 3}
			)

## Create a weapon with the specified parameters (used by import/generation systems)
func create_weapon_item(name: String, weapon_type: int, damage: int, range_val: int) -> Dictionary:
	return {
		"id": "weapon_" + str(randi() % 100000),
		"name": name,
		"category": EquipmentCategory.WEAPON,
		"type": weapon_type,
		"damage": damage,
		"range": range_val,
		"condition": 100,
		"traits": [],
		"value": 100 + (damage * 50) + (range_val * 30)
	}

## Create armor with the specified parameters (used by import/generation systems)
func create_armor_item(name: String, armor_type: int, protection: int) -> Dictionary:
	var mobility_penalty = 0
	
	# Set mobility penalty based on armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			mobility_penalty = 0
		GameEnums.ArmorType.MEDIUM:
			mobility_penalty = 1
		GameEnums.ArmorType.HEAVY:
			mobility_penalty = 2
		GameEnums.ArmorType.POWERED:
			mobility_penalty = 1 # Powered armor has enhanced mobility systems
		_:
			mobility_penalty = 0
			
	return {
		"id": "armor_" + str(randi() % 100000),
		"name": name,
		"category": EquipmentCategory.ARMOR,
		"armor_type": armor_type,
		"protection": protection,
		"mobility_penalty": mobility_penalty,
		"condition": 100,
		"traits": [],
		"value": 100 + (protection * 75)
	}

## Create gear with the specified parameters (used by import/generation systems)
func create_gear_item(name: String, gear_type: String, effect: Dictionary) -> Dictionary:
	return {
		"id": "gear_" + str(randi() % 100000),
		"name": name,
		"category": EquipmentCategory.GEAR,
		"type": gear_type,
		"effect": effect,
		"condition": 100,
		"traits": [],
		"value": 50 + (effect.size() * 25)
	}

## Repair equipment
func repair_equipment(equipment_id: String, repair_amount: int = 100) -> bool:
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		return false
	
	var current_condition = equipment_data.get("condition", 100)
	var new_condition = min(100, current_condition + repair_amount)
	
	equipment_data["condition"] = new_condition
	
	for i in range(_equipment_storage.size()):
		if _equipment_storage[i].get("id") == equipment_id:
			_equipment_storage[i] = equipment_data
			equipment_list_updated.emit()
			return true
	
	return false

## Private Helper Methods

## Check if a character can use a piece of equipment
func _can_character_use_equipment(character, equipment_data: Dictionary) -> bool:
	var category = equipment_data.get("category", EquipmentCategory.GEAR)
	
	# For weapons, check class restrictions
	if category == EquipmentCategory.WEAPON:
		var weapon_type = equipment_data.get("weapon_type", GameEnums.WeaponType.NONE)
		var char_class = character.get("character_class", FiveParsecsGameEnums.CharacterClass.NONE)
		
		# Some special weapons might be restricted
		if weapon_type == GameEnums.WeaponType.HEAVY:
			return char_class in [
				FiveParsecsGameEnums.CharacterClass.SOLDIER,
				FiveParsecsGameEnums.CharacterClass.BRUTE,
				FiveParsecsGameEnums.CharacterClass.SECURITY
			]
	
	# For armor, check armor type compatibility
	if category == EquipmentCategory.ARMOR:
		var armor_type = equipment_data.get("armor_type", GameEnums.ArmorType.NONE)
		var char_toughness = character.get("toughness", 1)
		
		# Heavy armor requires higher toughness
		if armor_type == GameEnums.ArmorType.HEAVY and char_toughness < 3:
			return false
	
	# By default, equipment is usable
	return true

## Update character object with assigned equipment
func _update_character_with_equipment(character_id: String) -> void:
	if not character_manager.has_character(character_id):
		return
	
	var character = character_manager.get_character(character_id)
	var equipment_list = _character_equipment.get(character_id, [])
	
	# Collect weapons
	var weapons = []
	var armor = null
	var gear = []
	
	for equipment_id in equipment_list:
		var equipment = get_equipment(equipment_id)
		if equipment.is_empty():
			continue
			
		match equipment.get("category"):
			EquipmentCategory.WEAPON:
				weapons.append(equipment)
			EquipmentCategory.ARMOR:
				armor = equipment
			EquipmentCategory.GEAR:
				gear.append(equipment)
	
	# Update the character with equipment
	if character.has_method("set_weapons"):
		character.set_weapons(weapons)
	else:
		character["weapons"] = weapons
		
	if character.has_method("set_armor"):
		character.set_armor(armor)
	else:
		character["armor"] = armor
		
	if character.has_method("set_gear"):
		character.set_gear(gear)
	else:
		character["gear"] = gear
	
	# Update character in manager
	character_manager.update_character(character_id, character)

## Generate a random item (used for loot generation)
func _generate_random_item(difficulty: int) -> Dictionary:
	var item_type = randi() % 3 # 0: Weapon, 1: Armor, 2: Gear
	var item = {}
	
	match item_type:
		0: # Weapon
			var weapon_types = [
				GameEnums.WeaponType.BASIC,
				GameEnums.WeaponType.PISTOL,
				GameEnums.WeaponType.RIFLE
			]
			
			# Add advanced weapons at higher difficulties
			if difficulty >= 3:
				weapon_types.append(GameEnums.WeaponType.ADVANCED)
			
			# Add heavy weapons at high difficulties
			if difficulty >= 5:
				weapon_types.append(GameEnums.WeaponType.HEAVY)
			
			var weapon_type = weapon_types[randi() % weapon_types.size()]
			var damage = 1 + (randi() % (1 + difficulty / 2))
			var range_val = 1 + (randi() % 3)
			
			var prefixes = ["Standard", "Reliable", "Tactical", "Enhanced", "Advanced"]
			var weapon_bases = ["Blaster", "Rifle", "Pistol", "Carbine", "Cannon"]
			var name = prefixes[randi() % prefixes.size()] + " " + weapon_bases[randi() % weapon_bases.size()]
			
			item = create_weapon_item(name, weapon_type, damage, range_val)
			
		1: # Armor
			var armor_types = [
				GameEnums.ArmorType.LIGHT,
				GameEnums.ArmorType.MEDIUM
			]
			
			# Add heavy armor at higher difficulties
			if difficulty >= 4:
				armor_types.append(GameEnums.ArmorType.HEAVY)
			
			var armor_type = armor_types[randi() % armor_types.size()]
			var protection = 1 + (randi() % (1 + difficulty / 2))
			
			var prefixes = ["Standard", "Reinforced", "Tactical", "Combat", "Advanced"]
			var armor_bases = ["Vest", "Suit", "Armor", "Plating", "Shield"]
			var name = prefixes[randi() % prefixes.size()] + " " + armor_bases[randi() % armor_bases.size()]
			
			item = create_armor_item(name, armor_type, protection)
			
		2: # Gear
			var gear_types = ["medkit", "scanner", "toolkit", "booster", "shield"]
			var gear_type = gear_types[randi() % gear_types.size()]
			
			var effect = {}
			match gear_type:
				"medkit":
					effect = {"healing": 1 + (randi() % difficulty)}
				"scanner":
					effect = {"detection": 1 + (randi() % difficulty)}
				"toolkit":
					effect = {"repair": 1 + (randi() % difficulty)}
				"booster":
					effect = {"speed": 1 + (randi() % difficulty)}
				"shield":
					effect = {"defense": 1 + (randi() % difficulty)}
			
			var prefixes = ["Basic", "Reliable", "Advanced", "Premium", "Prototype"]
			var name = prefixes[randi() % prefixes.size()] + " " + gear_type.capitalize()
			
			item = create_gear_item(name, gear_type, effect)
	
	# Randomly add condition variation (80-100%)
	item["condition"] = 80 + (randi() % 21)
	
	return item

func _calculate_weapon_value(weapon_type: int, damage: int, range_val: int) -> int:
	var base_value = 100
	
	# Adjust for weapon type
	match weapon_type:
		GameEnums.WeaponType.BASIC:
			base_value = 100
		GameEnums.WeaponType.PISTOL:
			base_value = 150
		GameEnums.WeaponType.RIFLE:
			base_value = 200
		GameEnums.WeaponType.ADVANCED:
			base_value = 300
		GameEnums.WeaponType.HEAVY:
			base_value = 400
		GameEnums.WeaponType.SPECIAL:
			base_value = 500
	
	# Adjust for damage and range
	base_value += damage * 50
	base_value += range_val * 30
	
	return base_value

func _calculate_armor_value(armor_type: int, protection: int) -> int:
	var base_value = 100
	
	# Adjust for armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			base_value = 100
		GameEnums.ArmorType.MEDIUM:
			base_value = 200
		GameEnums.ArmorType.HEAVY:
			base_value = 300
		GameEnums.ArmorType.POWERED:
			base_value = 500
		GameEnums.ArmorType.HAZARD:
			base_value = 250
		GameEnums.ArmorType.STEALTH:
			base_value = 350
	
	# Adjust for protection
	base_value += protection * 75
	
	return base_value

func _calculate_gear_value(effect: Dictionary) -> int:
	var base_value = 50
	
	# Sum all effect values
	for key in effect:
		base_value += effect[key] * 40
	
	return base_value

## Signal handlers

func _on_character_added(character) -> void:
	var char_id = character.get("id", "")
	if not char_id.is_empty() and not char_id in _character_equipment:
		_character_equipment[char_id] = []

func _on_character_removed(character_id: String) -> void:
	if character_id in _character_equipment:
		_character_equipment.erase(character_id)

## Equipment Upgrading System (Five Parsecs rulebook p.56-74)

## Upgrade a weapon with improved stats
func upgrade_weapon(weapon_id: String, upgrade_type: String) -> bool:
	var weapon = get_equipment(weapon_id)
	if weapon.is_empty() or weapon.get("category") != EquipmentCategory.WEAPON:
		return false
	
	# Calculate upgrade cost based on weapon type and current stats
	var upgrade_cost = _calculate_weapon_upgrade_cost(weapon, upgrade_type)
	
	# Check if player has enough credits
	if game_state and game_state.get_credits() < upgrade_cost:
		return false
	
	# Apply the upgrade
	var success = false
	match upgrade_type:
		"damage":
			weapon["damage"] = weapon.get("damage", 1) + 1
			success = true
		"range":
			weapon["range"] = weapon.get("range", 1) + 1
			success = true
		"accuracy":
			weapon["accuracy"] = weapon.get("accuracy", 0) + 1
			success = true
		"special":
			# Add a special trait to the weapon
			var available_traits = ["Reliable", "Rapid", "Penetrating", "Shred"]
			var current_traits = weapon.get("traits", [])
			
			# Filter out traits the weapon already has
			var valid_traits = []
			for trait_id in available_traits:
				if not trait_id in current_traits:
					valid_traits.append(trait_id)
			
			if valid_traits.is_empty():
				return false
				
			# Select a random valid trait
			var selected_trait = valid_traits[randi() % valid_traits.size()]
			current_traits.append(selected_trait)
			weapon["traits"] = current_traits
			success = true
		"condition":
			# Repair the weapon to 100% condition
			weapon["condition"] = 100
			success = true
	
	if success and game_state:
		# Deduct credits
		game_state.remove_credits(upgrade_cost)
		
		# Update equipment in storage (replace with modified version)
		for i in range(_equipment_storage.size()):
			if _equipment_storage[i].get("id") == weapon_id:
				_equipment_storage[i] = weapon
				break
		
		# Emit signals
		equipment_list_updated.emit()
		return true
	
	return false

## Upgrade armor with improved stats
func upgrade_armor(armor_id: String, upgrade_type: String) -> bool:
	var armor = get_equipment(armor_id)
	if armor.is_empty() or armor.get("category") != EquipmentCategory.ARMOR:
		return false
	
	# Calculate upgrade cost
	var upgrade_cost = _calculate_armor_upgrade_cost(armor, upgrade_type)
	
	# Check if player has enough credits
	if game_state and game_state.get_credits() < upgrade_cost:
		return false
	
	# Apply the upgrade
	var success = false
	match upgrade_type:
		"protection":
			armor["protection"] = armor.get("protection", 1) + 1
			success = true
		"mobility":
			# Reduce movement penalty
			var mobility = armor.get("mobility_penalty", 0)
			if mobility > 0:
				armor["mobility_penalty"] = mobility - 1
				success = true
		"special":
			# Add a special trait to the armor
			var available_traits = ["Environmental", "Sealed", "Reinforced", "Stealth"]
			var current_traits = armor.get("traits", [])
			
			# Filter out traits the armor already has
			var valid_traits = []
			for trait_id in available_traits:
				if not trait_id in current_traits:
					valid_traits.append(trait_id)
			
			if valid_traits.is_empty():
				return false
				
			# Select a random valid trait
			var selected_trait = valid_traits[randi() % valid_traits.size()]
			current_traits.append(selected_trait)
			armor["traits"] = current_traits
			success = true
		"condition":
			# Repair the armor to 100% condition
			armor["condition"] = 100
			success = true
	
	if success and game_state:
		# Deduct credits
		game_state.remove_credits(upgrade_cost)
		
		# Update equipment in storage (replace with modified version)
		for i in range(_equipment_storage.size()):
			if _equipment_storage[i].get("id") == armor_id:
				_equipment_storage[i] = armor
				break
		
		# Emit signals
		equipment_list_updated.emit()
		return true
	
	return false

## Calculate the cost to upgrade a weapon based on rulebook tables (p.58-60)
func _calculate_weapon_upgrade_cost(weapon: Dictionary, upgrade_type: String) -> int:
	var base_cost = 0
	var weapon_type = weapon.get("type", GameEnums.WeaponType.BASIC)
	
	# Base cost depends on weapon type
	match weapon_type:
		GameEnums.WeaponType.PISTOL:
			base_cost = 50
		GameEnums.WeaponType.RIFLE:
			base_cost = 75
		GameEnums.WeaponType.ADVANCED:
			base_cost = 100
		GameEnums.WeaponType.HEAVY:
			base_cost = 150
		_:
			base_cost = 50
	
	# Additional cost based on current stats and upgrade type
	match upgrade_type:
		"damage":
			var current_damage = weapon.get("damage", 1)
			# Each point of damage costs more as it increases
			base_cost += current_damage * 25
		"range":
			var current_range = weapon.get("range", 1)
			# Each point of range costs more as it increases
			base_cost += current_range * 20
		"accuracy":
			var current_accuracy = weapon.get("accuracy", 0)
			# Each point of accuracy is very valuable
			base_cost += current_accuracy * 30
		"special":
			# Special traits are expensive
			base_cost += 100
		"condition":
			# Repair cost is lower for maintenance
			var condition = weapon.get("condition", 100)
			base_cost = int(50.0 * (1.0 - condition / 100.0))
			base_cost = max(10, base_cost) # Minimum 10 credits
	
	return base_cost

## Calculate the cost to upgrade armor based on rulebook tables (p.61-63)
func _calculate_armor_upgrade_cost(armor: Dictionary, upgrade_type: String) -> int:
	var base_cost = 0
	var armor_type = armor.get("armor_type", GameEnums.ArmorType.LIGHT)
	
	# Base cost depends on armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			base_cost = 50
		GameEnums.ArmorType.MEDIUM:
			base_cost = 100
		GameEnums.ArmorType.HEAVY:
			base_cost = 200
		_:
			base_cost = 50
	
	# Additional cost based on current stats and upgrade type
	match upgrade_type:
		"protection":
			var current_protection = armor.get("protection", 1)
			# Each point of protection costs more as it increases
			base_cost += current_protection * 40
		"mobility":
			var current_penalty = armor.get("mobility_penalty", 0)
			# Reducing mobility penalty is very valuable
			base_cost += (3 - current_penalty) * 50
		"special":
			# Special traits are expensive
			base_cost += 150
		"condition":
			# Repair cost is based on damage
			var condition = armor.get("condition", 100)
			base_cost = int(75.0 * (1.0 - condition / 100.0))
			base_cost = max(15, base_cost) # Minimum 15 credits
	
	return base_cost

## Trading System Implementation (Five Parsecs rulebook p.64-68)

## Generate tradeable items for a market based on location type
func generate_market_items(location_type: int, item_count: int = 5) -> Array:
	var market_items = []
	
	# Determine market quality based on location
	var market_quality = _determine_market_quality(location_type)
	
	# Generate random items based on market quality
	for i in range(item_count):
		var item_type = _determine_market_item_type(market_quality)
		var item = {}
		
		match item_type:
			"weapon":
				item = _generate_market_weapon(market_quality)
			"armor":
				item = _generate_market_armor(market_quality)
			"gear":
				item = _generate_market_gear(market_quality)
			"medical":
				item = create_gear_item("Medical Kit", "medkit", {"healing": 1 + (randi() % market_quality)})
			"ammo":
				item = create_gear_item("Ammunition", "ammo", {"quantity": 2 + (randi() % 3)})
		
		# Apply market markup
		item["value"] = _apply_market_markup(item.get("value", 50), market_quality, location_type)
		market_items.append(item)
	
	return market_items

## Determine market quality based on location type (1-5 scale)
func _determine_market_quality(location_type: int) -> int:
	match location_type:
		GameEnums.WorldTrait.TRADE_CENTER:
			return 4 + (randi() % 2) # 4-5 quality
		GameEnums.WorldTrait.TECH_CENTER:
			return 3 + (randi() % 3) # 3-5 quality
		GameEnums.WorldTrait.INDUSTRIAL_HUB:
			return 3 + (randi() % 2) # 3-4 quality
		GameEnums.WorldTrait.PIRATE_HAVEN:
			return 2 + (randi() % 3) # 2-4 quality, wide variety
		GameEnums.WorldTrait.FRONTIER_WORLD:
			return 1 + (randi() % 3) # 1-3 quality, limited options
		_:
			return 2 + (randi() % 2) # 2-3 quality for other locations

## Determine what type of item a market will offer
func _determine_market_item_type(market_quality: int) -> String:
	var roll = randi() % 100 + 1
	
	if roll <= 35:
		return "weapon"
	elif roll <= 60:
		return "armor"
	elif roll <= 80:
		return "gear"
	elif roll <= 90:
		return "medical"
	else:
		return "ammo"

## Generate a weapon for the market based on quality
func _generate_market_weapon(market_quality: int) -> Dictionary:
	# Higher quality markets have better weapons
	var weapon_type = GameEnums.WeaponType.BASIC
	
	# Determine weapon type based on market quality
	var type_roll = randi() % 100 + 1
	if market_quality >= 5:
		# Top quality markets have advanced weapons
		if type_roll <= 30:
			weapon_type = GameEnums.WeaponType.ADVANCED
		elif type_roll <= 70:
			weapon_type = GameEnums.WeaponType.RIFLE
		else:
			weapon_type = GameEnums.WeaponType.PISTOL
	elif market_quality >= 3:
		# Good markets have rifles and pistols mostly
		if type_roll <= 10:
			weapon_type = GameEnums.WeaponType.ADVANCED
		elif type_roll <= 50:
			weapon_type = GameEnums.WeaponType.RIFLE
		else:
			weapon_type = GameEnums.WeaponType.PISTOL
	else:
		# Basic markets have basic weapons
		if type_roll <= 30:
			weapon_type = GameEnums.WeaponType.RIFLE
		else:
			weapon_type = GameEnums.WeaponType.PISTOL
	
	# Base stats based on weapon type
	var base_damage = 0
	var base_range = 0
	var weapon_name = ""
	var base_value = 0
	
	match weapon_type:
		GameEnums.WeaponType.PISTOL:
			base_damage = 1
			base_range = 1
			weapon_name = "Market Pistol"
			base_value = 75
		GameEnums.WeaponType.RIFLE:
			base_damage = 2
			base_range = 2
			weapon_name = "Market Rifle"
			base_value = 150
		GameEnums.WeaponType.ADVANCED:
			base_damage = 3
			base_range = 2
			weapon_name = "Advanced Market Weapon"
			base_value = 300
		GameEnums.WeaponType.HEAVY:
			base_damage = 4
			base_range = 1
			weapon_name = "Heavy Market Weapon"
			base_value = 400
		_:
			base_damage = 1
			base_range = 1
			weapon_name = "Basic Market Weapon"
			base_value = 50
	
	# Create the weapon with appropriate stats
	var weapon = create_weapon_item(
		weapon_name,
		weapon_type,
		base_damage,
		base_range
	)
	
	# Set the condition (market weapons are generally in good condition)
	weapon["condition"] = 80 + (randi() % 21) # 80-100%
	
	# Set the value
	weapon["value"] = base_value
	
	# Special features based on market quality
	if market_quality >= 4 and randf() < 0.3:
		# 30% chance for a special trait in high quality markets
		var available_traits = ["Reliable", "Rapid", "Penetrating", "Shred"]
		var selected_trait = available_traits[randi() % available_traits.size()]
		
		var current_traits = weapon.get("traits", [])
		current_traits.append(selected_trait)
		weapon["traits"] = current_traits
		
		# Increase value for special trait
		weapon["value"] += 100
	
	return weapon

## Generate armor for the market based on quality
func _generate_market_armor(market_quality: int) -> Dictionary:
	# Higher quality markets have better armor
	var armor_type = GameEnums.ArmorType.LIGHT
	
	# Determine armor type based on market quality
	var type_roll = randi() % 100 + 1
	if market_quality >= 5:
		# Top quality markets have heavy armor
		if type_roll <= 30:
			armor_type = GameEnums.ArmorType.HEAVY
		elif type_roll <= 70:
			armor_type = GameEnums.ArmorType.MEDIUM
		else:
			armor_type = GameEnums.ArmorType.LIGHT
	elif market_quality >= 3:
		# Good markets have medium armor
		if type_roll <= 10:
			armor_type = GameEnums.ArmorType.HEAVY
		elif type_roll <= 50:
			armor_type = GameEnums.ArmorType.MEDIUM
		else:
			armor_type = GameEnums.ArmorType.LIGHT
	else:
		# Basic markets mainly have light armor
		if type_roll <= 20:
			armor_type = GameEnums.ArmorType.MEDIUM
		else:
			armor_type = GameEnums.ArmorType.LIGHT
	
	# Base stats based on armor type
	var base_protection = 0
	var mobility_penalty = 0
	var armor_name = ""
	var base_value = 0
	var protection_bonus = 0
	
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			base_protection = 1
			mobility_penalty = 0
			armor_name = "Light Market Armor"
			base_value = 100
		GameEnums.ArmorType.MEDIUM:
			base_protection = 2
			mobility_penalty = 1
			armor_name = "Medium Market Armor"
			base_value = 200
		GameEnums.ArmorType.HEAVY:
			base_protection = 3
			mobility_penalty = 2
			armor_name = "Heavy Market Armor"
			base_value = 350
		_:
			base_protection = 1
			mobility_penalty = 0
			armor_name = "Basic Market Armor"
			base_value = 75
	
	# Create armor with the appropriate stats
	var armor = create_armor_item(
		armor_name,
		armor_type,
		base_protection + protection_bonus
	)
	
	# Set the condition (market armor is generally in good condition)
	armor["condition"] = 80 + (randi() % 21) # 80-100%
	
	# Set the value
	armor["value"] = base_value
	
	# Special features based on market quality
	if market_quality >= 4 and randf() < 0.3:
		# 30% chance for a special trait in high quality markets
		var available_traits = ["Environmental", "Sealed", "Reinforced", "Stealth"]
		var selected_trait = available_traits[randi() % available_traits.size()]
		
		var current_traits = armor.get("traits", [])
		current_traits.append(selected_trait)
		armor["traits"] = current_traits
		
		# Increase value for special trait
		armor["value"] += 150
	
	return armor

## Generate gear items for the market
func _generate_market_gear(market_quality: int) -> Dictionary:
	var gear_types = [
		{
			"name": "Medkit",
			"type": "medkit",
			"properties": {"healing": 1},
			"base_value": 50
		},
		{
			"name": "Targeting System",
			"type": "targeting",
			"properties": {"accuracy": 1},
			"base_value": 75
		},
		{
			"name": "Combat Stimulant",
			"type": "stimulant",
			"properties": {"combat_bonus": 1, "uses": 2},
			"base_value": 60
		},
		{
			"name": "Shield Generator",
			"type": "shield",
			"properties": {"defense": 1, "charges": 3},
			"base_value": 100
		},
		{
			"name": "Grappling Hook",
			"type": "mobility",
			"properties": {"climb": 1},
			"base_value": 40
		}
	]
	
	# Add more high-quality items if the market is good
	if market_quality >= 4:
		gear_types.append({
			"name": "Advanced Scanner",
			"type": "scanner",
			"properties": {"detection": 2, "range": 2},
			"base_value": 120
		})
		
		gear_types.append({
			"name": "Energy Shield",
			"type": "shield",
			"properties": {"defense": 2, "charges": 5},
			"base_value": 200
		})
	
	# Select a random gear type
	var selected_gear = gear_types[randi() % gear_types.size()]
	
	# Create the gear with appropriate properties
	var gear = create_gear_item(
		selected_gear.name,
		selected_gear.type,
		selected_gear.properties
	)
	
	# Set the value
	gear["value"] = selected_gear.base_value
	
	# Improve gear based on market quality
	if market_quality >= 3 and randf() < 0.5:
		# 50% chance to enhance the item in good markets
		for key in gear.get("properties", {}).keys():
			if key in ["healing", "accuracy", "combat_bonus", "defense"]:
				gear["properties"][key] += 1
				gear["value"] += 50
	
	return gear

## Apply market-specific markup to item values
func _apply_market_markup(base_value: int, market_quality: int, location_type: int) -> int:
	var markup = 1.0
	
	# Location-based markup
	match location_type:
		GameEnums.WorldTrait.TRADE_CENTER:
			markup = 0.9 # Trade centers have lower prices
		GameEnums.WorldTrait.FRONTIER_WORLD:
			markup = 1.3 # Frontier worlds have higher prices
		GameEnums.WorldTrait.PIRATE_HAVEN:
			markup = 1.2 # Pirate havens have slightly higher prices
		_:
			markup = 1.0
	
	# Quality-based adjustment (higher quality can mean better deals)
	if market_quality >= 4:
		markup -= 0.1
	elif market_quality <= 2:
		markup += 0.1
	
	# Random market fluctuation
	markup += (randf() * 0.2) - 0.1 # +/- 10%
	
	# Calculate final price
	var final_value = int(base_value * markup)
	
	# Ensure minimum value
	return max(10, final_value)