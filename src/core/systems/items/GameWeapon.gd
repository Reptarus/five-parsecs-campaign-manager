@tool
extends Resource
class_name GameWeapon

# Import necessary classes
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_category: String = ""
@export var weapon_description: String = ""
@export var weapon_damage: Dictionary = {"dice": 1, "die_type": 6, "bonus": 0}
@export var weapon_range: Dictionary = {"short": 0, "medium": 0, "long": 0}
@export var weapon_traits: Array[String] = []
@export var weapon_special_rules: Array[Dictionary] = []
@export var weapon_cost: Dictionary = {"credits": 0, "rarity": "Common"}
@export var weapon_tags: Array[String] = []
@export var weapon_ammo: Dictionary = {"type": "", "capacity": 0, "current": 0}
@export var is_two_handed: bool = false
@export var durability: int = 100

var _data_manager: Object = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Use the shared GameDataManager instance
	_data_manager = GameDataManager.get_instance()
	GameDataManager.ensure_data_loaded()

func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.get_instance()
		GameDataManager.ensure_data_loaded()
		
	var weapon_data = _data_manager.get_weapon(id)
	if weapon_data.is_empty():
		push_error("Failed to find weapon with ID: " + id)
		return false
		
	return initialize_from_data(weapon_data)

func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	weapon_id = data.get("id", "")
	weapon_name = data.get("name", "")
	weapon_category = data.get("category", "")
	weapon_description = data.get("description", "")
	
	# Handle damage data
	if data.has("damage") and data.damage is Dictionary:
		weapon_damage = data.damage
	else:
		weapon_damage = {
			"dice": data.get("damage_dice", 1),
			"die_type": data.get("damage_die_type", 6),
			"bonus": data.get("damage_bonus", 0)
		}
	
	# Handle range data
	if data.has("range") and data.range is Dictionary:
		weapon_range = data.range
	else:
		weapon_range = {
			"short": data.get("range_short", 0),
			"medium": data.get("range_medium", 0),
			"long": data.get("range_long", 0)
		}
	
	# Handle traits
	if data.has("traits") and data.traits is Array:
		weapon_traits = data.traits
	else:
		weapon_traits = []
	
	# Handle special rules
	if data.has("special_rules") and data.special_rules is Array:
		weapon_special_rules = data.special_rules
	else:
		weapon_special_rules = []
		
		# If there's a single special rule, convert it to our format
		if data.has("special_rule"):
			weapon_special_rules.append({
				"name": data.get("special_rule", ""),
				"description": data.get("special_rule_description", ""),
				"effect": data.get("special_rule_effect", {})
			})
	
	# Handle cost data
	if data.has("cost") and data.cost is Dictionary:
		weapon_cost = data.cost
	else:
		weapon_cost = {"credits": data.get("cost", 0), "rarity": data.get("rarity", "Common")}
	
	weapon_tags = data.get("tags", [])
	
	# Handle ammo data
	if data.has("ammo") and data.ammo is Dictionary:
		weapon_ammo = data.ammo
	else:
		weapon_ammo = {
			"type": data.get("ammo_type", ""),
			"capacity": data.get("ammo_capacity", 0),
			"current": data.get("ammo_current", 0)
		}
	
	return true

func get_id() -> String:
	return weapon_id

func get_weapon_name() -> String:
	return weapon_name

func get_category() -> String:
	return weapon_category

func get_description() -> String:
	return weapon_description

func get_damage() -> Dictionary:
	return weapon_damage

func get_damage_string() -> String:
	var dice = weapon_damage.get("dice", 1)
	var die_type = weapon_damage.get("die_type", 6)
	var bonus = weapon_damage.get("bonus", 0)
	
	var damage_str = str(dice) + "d" + str(die_type)
	if bonus > 0:
		damage_str += "+" + str(bonus)
	elif bonus < 0:
		damage_str += str(bonus)
		
	return damage_str

func get_range() -> Dictionary:
	return weapon_range

func get_range_string() -> String:
	var short_range = weapon_range.get("short", 0)
	var medium_range = weapon_range.get("medium", 0)
	var long_range = weapon_range.get("long", 0)
	
	if short_range == 0 and medium_range == 0 and long_range == 0:
		return "Melee"
		
	var range_str = ""
	if short_range > 0:
		range_str += "S:" + str(short_range)
	if medium_range > 0:
		if range_str.length() > 0:
			range_str += ", "
		range_str += "M:" + str(medium_range)
	if long_range > 0:
		if range_str.length() > 0:
			range_str += ", "
		range_str += "L:" + str(long_range)
		
	return range_str

func get_traits() -> Array[String]:
	return weapon_traits

func has_trait(trait_name: String) -> bool:
	return weapon_traits.has(trait_name)

func get_special_rules() -> Array[Dictionary]:
	return weapon_special_rules

func get_cost() -> int:
	return weapon_cost.get("credits", 0)

func get_rarity() -> String:
	return weapon_cost.get("rarity", "Common")

func get_tags() -> Array[String]:
	return weapon_tags

func has_tag(tag: String) -> bool:
	return weapon_tags.has(tag)

func get_ammo() -> Dictionary:
	return weapon_ammo

func get_ammo_type() -> String:
	return weapon_ammo.get("type", "")

func get_ammo_capacity() -> int:
	return weapon_ammo.get("capacity", 0)

func get_current_ammo() -> int:
	return weapon_ammo.get("current", 0)

func set_current_ammo(amount: int) -> void:
	var capacity = get_ammo_capacity()
	weapon_ammo.current = clampi(amount, 0, capacity)

func reload(amount: int = -1) -> int:
	var capacity = get_ammo_capacity()
	var current = get_current_ammo()
	
	if amount < 0:
		# Full reload
		var reloaded = capacity - current
		weapon_ammo.current = capacity
		return reloaded
	else:
		# Partial reload
		var new_ammo = clampi(current + amount, 0, capacity)
		var reloaded = new_ammo - current
		weapon_ammo.current = new_ammo
		return reloaded

func fire(shots: int = 1) -> bool:
	var current = get_current_ammo()
	
	# Check if we have enough ammo
	if current < shots:
		return false
		
	# If this is a melee weapon or doesn't use ammo
	if get_ammo_capacity() <= 0:
		return true
		
	# Use ammo
	weapon_ammo.current = current - shots
	return true

func is_melee() -> bool:
	return weapon_range.get("short", 0) == 0 and weapon_range.get("medium", 0) == 0 and weapon_range.get("long", 0) == 0

func is_ranged() -> bool:
	return not is_melee()

func get_weapon_profile() -> Dictionary:
	return {
		"id": weapon_id,
		"name": weapon_name,
		"category": weapon_category,
		"description": weapon_description,
		"damage": weapon_damage,
		"range": weapon_range,
		"traits": weapon_traits,
		"special_rules": weapon_special_rules,
		"cost": weapon_cost,
		"tags": weapon_tags,
		"ammo": weapon_ammo
	}

static func create_from_profile(profile: Dictionary) -> GameWeapon:
	var weapon = GameWeapon.new()
	weapon.initialize_from_data(profile)
	return weapon

func serialize() -> Dictionary:
	return get_weapon_profile()

func deserialize(data: Dictionary) -> void:
	initialize_from_data(data)

func get_combat_value() -> int:
	var value := 0
	
	# Base value from damage
	var dice = weapon_damage.get("dice", 1)
	var die_type = weapon_damage.get("die_type", 6)
	var bonus = weapon_damage.get("bonus", 0)
	
	value += dice * (die_type / 2 + 0.5) + bonus
	
	# Add value for range
	if is_ranged():
		var long_range = weapon_range.get("long", 0)
		value += long_range / 5
	
	# Add value for traits
	value += weapon_traits.size() * 2
	
	# Add value for special rules
	value += weapon_special_rules.size() * 3
	
	# Add value for ammo capacity
	var capacity = get_ammo_capacity()
	if capacity > 0:
		value += sqrt(capacity)
	
	return value
