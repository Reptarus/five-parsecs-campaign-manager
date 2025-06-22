@tool
class_name GameWeapon
extends Resource

# Weapon properties
@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_category: String = ""
@export var weapon_description: String = ""
@export var weapon_damage: Dictionary = {}
@export var weapon_range: Dictionary = {}
@export var weapon_traits: Array[String] = []
@export var weapon_special_rules: Array[Dictionary] = []
@export var weapon_cost: Dictionary = {}
@export var weapon_tags: Array[String] = []
@export var weapon_ammo: Dictionary = {}

func initialize(name: String, damage: Dictionary, range: Dictionary) -> void:
	weapon_name = name
	weapon_damage = damage
	weapon_range = range
	weapon_id = name.to_lower().replace(" ", "_")
func load_from_data(data: Dictionary) -> bool:
	if not data.has("name"):
		push_error("Weapon data must have a name")
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
		weapon_cost = {
			"credits": data.get("cost", 0),
			"rarity": data.get("rarity", "Common")
		}
	
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
		
	var range_str: String = ""
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

func get_ammo() -> Dictionary:
	return weapon_ammo

func set_ammo_current(amount: int) -> void:
	weapon_ammo["current"] = clampi(amount, 0, weapon_ammo.get("capacity", 0))
func use_ammo(amount: int = 1) -> bool:
	var current = weapon_ammo.get("current", 0)
	if current < amount:
		return false
	
	weapon_ammo["current"] = current - amount
	return true

func reload_ammo() -> void:
	weapon_ammo["current"] = weapon_ammo.get("capacity", 0)
func is_ranged() -> bool:
	return weapon_range.get("short", 0) > 0 or weapon_range.get("medium", 0) > 0 or weapon_range.get("long", 0) > 0

func is_melee() -> bool:
	return not is_ranged()

func get_max_range() -> int:
	return maxi(maxi(weapon_range.get("short", 0), weapon_range.get("medium", 0)), weapon_range.get("long", 0))

func calculate_damage_roll() -> int:
	var dice = weapon_damage.get("dice", 1)
	var die_type = weapon_damage.get("die_type", 6)
	var bonus = weapon_damage.get("bonus", 0)
	
	var total: int = 0
	for i in range(dice):
		total += randi() % die_type + 1
	
	return total + bonus

func to_dict() -> Dictionary:
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

func from_dict(data: Dictionary) -> void:
	load_from_data(data)
func duplicate_weapon() -> GameWeapon:
	var new_weapon = GameWeapon.new()
	new_weapon.from_dict(to_dict())
	return new_weapon

static func create_from_profile(profile: Dictionary) -> GameWeapon:
	var weapon := GameWeapon.new()
	weapon.load_from_data(profile)
	return weapon

func _to_string() -> String:
	return "GameWeapon<%s>" % weapon_name
