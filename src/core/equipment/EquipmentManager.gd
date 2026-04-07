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

# Equipment database loaded from JSON (Core Rules pp.49-58)
var _equipment_db: Dictionary = {}
var _db_weapons: Array = []
var _db_armor: Array = []
var _db_gear: Array = []
var _onboard_items: Array = []  # On-board items from Core Rules pp.57-58

func _init() -> void:
	pass

func _ready() -> void:
	_load_equipment_database()

func _load_equipment_database() -> void:
	var path := "res://data/equipment_database.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("EquipmentManager: Cannot open equipment_database.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("EquipmentManager: Failed to parse equipment_database.json")
		return
	if json.data is Dictionary:
		_equipment_db = json.data
		_db_weapons = _equipment_db.get("weapons", [])
		_db_armor = _equipment_db.get("armor", [])
		_db_gear = _equipment_db.get("gear", [])

	# Load on-board items (Core Rules pp.57-58 — ship items not carried into battle)
	_load_onboard_items()

func _load_onboard_items() -> void:
	var path := "res://data/onboard_items.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("EquipmentManager: Failed to parse onboard_items.json")
		return
	file.close()
	if json.data is Dictionary:
		_onboard_items = json.data.get("onboard_items", [])

## Get all on-board items (Core Rules pp.57-58)
func get_onboard_items() -> Array:
	return _onboard_items

## Get on-board item by ID
func get_onboard_item(item_id: String) -> Dictionary:
	for item in _onboard_items:
		if item is Dictionary and item.get("id", "") == item_id:
			return item
	return {}

## Check if an on-board item is single-use
func is_onboard_item_single_use(item_id: String) -> bool:
	var item := get_onboard_item(item_id)
	return item.get("single_use", false)

## Return basic weapons (always available, 1 credit each — Core Rules p.126)
func get_basic_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in _db_weapons:
		if w is Dictionary and w.get("basic", false):
			result.append({"name": w.get("name", ""), "type": "weapon", "value": int(w.get("cost", 1)), "_basic": true})
	if result.is_empty():
		push_warning("EquipmentManager: No basic weapons found in equipment_database.json")
	return result

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

	# Write-through to campaign equipment_data for save/load persistence
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.get("current_campaign") and "equipment_data" in gs.current_campaign:
		var stash: Array = gs.current_campaign.equipment_data.get("equipment", [])
		stash.append(equipment_data)
		gs.current_campaign.equipment_data["equipment"] = stash

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

## Reset the manager to an empty state. Used by GameState.restore_equipment_from_campaign
## when rehydrating runtime state from a newly-loaded campaign Resource so leftover
## items from a previous session don't bleed into the new one.
func clear_all_equipment() -> void:
	_equipment_storage.clear()
	_character_equipment.clear()
	equipment_list_updated.emit()

## Bulk-set a character's owned equipment IDs, bypassing the normal compatibility
## and slot checks in assign_equipment_to_character(). Used by the restore pipeline
## after reconstructing ownership from persisted data — the items already existed
## in a prior session and went through those checks then. Do NOT use for runtime
## assignment; use assign_equipment_to_character() for that.
func set_character_equipment_ids(character_id: String, equipment_ids: Array) -> void:
	_character_equipment[character_id] = equipment_ids.duplicate()
	equipment_list_updated.emit()

## Get equipment of a specific category
func get_equipment_by_category(category: int) -> Array:
	var filtered_equipment = []
	
	for item in _equipment_storage:
		if item.get("category") == category:
			filtered_equipment.append(item)
	
	return filtered_equipment

## Sell equipment — Core Rules p.76: each item sold = 1 credit of Upkeep
func sell_equipment(equipment_id: String) -> int:
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		return 0

	var sell_value := 1  # Core Rules p.76: flat 1 credit per item

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
		# Standard Weapon (from JSON)
		return _generate_random_db_weapon()
	elif roll <= 55:
		# Armor (from JSON)
		return _generate_random_db_armor()
	elif roll <= 65:
		# Consumable (from JSON)
		return _generate_consumable_item()
	elif roll <= 75:
		# Gear (from JSON)
		return _generate_random_db_gear()
	elif roll <= 85:
		# Utility Item
		return _generate_utility_item()
	elif roll <= 95:
		# Rare Equipment
		return _generate_rare_equipment()
	else:
		# Unique Item (very rare, powerful)
		return _generate_unique_item()

## Generate weapon from JSON database
func _generate_weapon_by_rulebook() -> Dictionary:
	return _generate_random_db_weapon()

## Generate armor from JSON database
func _generate_armor_by_rulebook() -> Dictionary:
	return _generate_random_db_armor()

## Helper: random weapon from equipment database at listed cost
func _generate_random_db_weapon() -> Dictionary:
	if _db_weapons.is_empty():
		return create_weapon_item("Basic Weapon", GameEnums.WeaponType.BASIC, 1, 1)
	var chosen: Dictionary = _db_weapons[randi() % _db_weapons.size()].duplicate()
	chosen["category"] = EquipmentCategory.WEAPON
	chosen["value"] = chosen.get("cost", 3)
	return chosen

## Helper: random armor from equipment database at listed cost
func _generate_random_db_armor() -> Dictionary:
	if _db_armor.is_empty():
		return create_armor_item("Basic Armor", GameEnums.ArmorType.LIGHT, 1)
	var chosen: Dictionary = _db_armor[randi() % _db_armor.size()].duplicate()
	chosen["category"] = EquipmentCategory.ARMOR
	chosen["value"] = chosen.get("cost", 3)
	return chosen

## Helper: random gear from equipment database at listed cost
func _generate_random_db_gear() -> Dictionary:
	if _db_gear.is_empty():
		return create_gear_item("Basic Gear", "misc", {})
	var chosen: Dictionary = _db_gear[randi() % _db_gear.size()].duplicate()
	chosen["category"] = EquipmentCategory.GEAR
	if chosen.get("single_use", false):
		chosen["category"] = EquipmentCategory.CONSUMABLE
	chosen["value"] = chosen.get("cost", 3)
	return chosen

## Generate consumable item from JSON database (Core Rules p.54)
func _generate_consumable_item() -> Dictionary:
	var consumables: Array = _db_gear.filter(
		func(g): return g is Dictionary and g.get("type", "") == "Consumable")
	if consumables.is_empty():
		return create_gear_item("Stim-pack", "consumable", {})
	var chosen: Dictionary = consumables[randi() % consumables.size()]
	var item: Dictionary = chosen.duplicate()
	item["category"] = EquipmentCategory.CONSUMABLE
	item["condition"] = 100
	item["value"] = item.get("cost", 3)
	return item

## Generate utility item from equipment_database.json (Core Rules pp.56-57)
func _generate_utility_item() -> Dictionary:
	var utilities: Array = _db_gear.filter(
		func(g): return g is Dictionary and g.get("type", "") == "Utility Device")
	if utilities.is_empty():
		return create_gear_item("Communicator", "utility", {})
	var chosen: Dictionary = utilities[randi() % utilities.size()]
	var item: Dictionary = chosen.duplicate()
	item["category"] = EquipmentCategory.GEAR
	item["value"] = item.get("cost", 3)
	return item

## Generate rare equipment — picks Rare rarity from any category in JSON
func _generate_rare_equipment() -> Dictionary:
	var rare_items: Array = []
	for item in _db_weapons:
		if item is Dictionary and item.get("rarity", "") == "Rare":
			rare_items.append(item)
	for item in _db_armor:
		if item is Dictionary and item.get("rarity", "") == "Rare":
			rare_items.append(item)
	for item in _db_gear:
		if item is Dictionary and item.get("rarity", "") == "Rare":
			rare_items.append(item)
	if rare_items.is_empty():
		return _generate_random_db_weapon()
	var chosen: Dictionary = rare_items[randi() % rare_items.size()]
	var item: Dictionary = chosen.duplicate()
	item["value"] = item.get("cost", 3)
	return item

## Generate unique powerful items — picks rarest available from JSON
func _generate_unique_item() -> Dictionary:
	# Unique items are the rarest in the database
	return _generate_rare_equipment()

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
		"value": 3  # Default purchase cost (Core Rules p.125: 3 credits for a table roll)
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

## Generate a random item from equipment database (used for loot generation)
func _generate_random_item(_difficulty: int) -> Dictionary:
	var item_type := randi() % 3
	match item_type:
		0:
			if not _db_weapons.is_empty():
				var w: Dictionary = _db_weapons[randi() % _db_weapons.size()].duplicate()
				w["category"] = EquipmentCategory.WEAPON
				w["value"] = w.get("cost", 3)  # Use listed cost from JSON
				return w
		1:
			if not _db_armor.is_empty():
				var a: Dictionary = _db_armor[randi() % _db_armor.size()].duplicate()
				a["category"] = EquipmentCategory.ARMOR
				a["value"] = a.get("cost", 3)
				return a
		_:
			if not _db_gear.is_empty():
				var g: Dictionary = _db_gear[randi() % _db_gear.size()].duplicate()
				g["category"] = EquipmentCategory.GEAR
				g["value"] = g.get("cost", 3)
				return g
	return create_gear_item("Basic Gear", "misc", {})

## Signal handlers

func _on_character_added(character) -> void:
	var char_id = character.get("id", "")
	if not char_id.is_empty() and not char_id in _character_equipment:
		_character_equipment[char_id] = []

func _on_character_removed(character_id: String) -> void:
	if character_id in _character_equipment:
		_character_equipment.erase(character_id)

## Generate available items for market/trade UI.
## Core Rules p.125: Purchase items by paying 3 credits for a roll on Military
## Weapon, Gear, or Gadget table. You can also buy Hand Guns, Blades, Colony
## Rifles, or Shotguns for 1 credit each.
## TODO: Replace with proper Trade Table (Core Rules p.79) implementation.
## For now returns random items from equipment database at their listed cost.
func generate_market_items(_location_type: int, item_count: int = 5) -> Array:
	var market_items: Array = []
	for i in range(item_count):
		var item: Dictionary = _generate_random_item(0)
		if not item.is_empty():
			# Use cost from JSON data — no fabricated markup or pricing formula
			item["value"] = item.get("cost", 3)
			market_items.append(item)
	return market_items

## Use a consumable item, decrementing its remaining uses.
## Returns a result dictionary with {success, remaining, depleted}.
## If depleted, the caller should remove the item from the owner.
func use_consumable(item_data: Dictionary) -> Dictionary:
	var uses: int = item_data.get("remaining_uses", -1)
	if uses < 0:
		# Not a consumable — check legacy "uses" key
		uses = item_data.get("uses", -1)
		if uses >= 0:
			item_data["remaining_uses"] = uses
		else:
			return {"success": false, "remaining": -1, "depleted": false, "reason": "not_consumable"}
	if uses <= 0:
		return {"success": false, "remaining": 0, "depleted": true, "reason": "already_depleted"}
	item_data["remaining_uses"] = uses - 1
	var depleted: bool = item_data["remaining_uses"] <= 0
	return {"success": true, "remaining": item_data["remaining_uses"], "depleted": depleted, "reason": ""}