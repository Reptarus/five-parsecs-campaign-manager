class_name FPCM_WeaponTableSystem
extends Resource

## Weapon Table System implementing Five Parsecs Core Rules
##
## Complete weapon reference with stats for quick lookup during tabletop play.
## Includes all standard weapons, damage modifiers, and special traits.
##
## Reference: Core Rules Weapon Tables (various pages)

# Weapon data class
class WeaponData extends Resource:
	@export var weapon_id: String = ""
	@export var name: String = ""
	@export var range_inches: int = 0  # 0 = melee
	@export var shots: int = 1
	@export var damage_bonus: int = 0
	@export var traits: Array[String] = []
	@export var category: String = ""  # pistol, rifle, heavy, melee, special
	@export var description: String = ""

	func get_range_text() -> String:
		if range_inches == 0:
			return "Melee"
		return "%d\"" % range_inches

	func get_traits_text() -> String:
		if traits.is_empty():
			return "-"
		return ", ".join(traits)

# Weapon registry
var weapon_registry: Dictionary = {}  # weapon_id -> WeaponData

# Enemy weapon distribution tables (loaded from JSON)
var _enemy_weapon_distributions: Dictionary = {}
var _enemy_weapon_aliases: Dictionary = {}
var _enemy_tables_loaded: bool = false

func _init() -> void:
	_load_weapons_from_json()
	if weapon_registry.is_empty():
		push_warning("WeaponTableSystem: JSON load failed, using hardcoded fallback")
		_initialize_weapon_registry()

## Load weapon data from equipment_database.json (canonical source)
func _load_weapons_from_json() -> void:
	var file := FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		file.close()
		return
	file.close()
	var weapons_array: Array = json.data.get("weapons", [])
	for entry in weapons_array:
		var weapon := WeaponData.new()
		weapon.weapon_id = entry.get("id", "")
		weapon.name = entry.get("name", "")
		weapon.range_inches = int(entry.get("range", 0))
		weapon.shots = int(entry.get("shots", 0))
		weapon.damage_bonus = int(entry.get("damage", 0))
		var traits_arr: Array = entry.get("traits", [])
		for t in traits_arr:
			weapon.traits.append(str(t))
		weapon.description = entry.get("description", "")
		# Derive category from type + traits
		weapon.category = _derive_category(entry.get("type", ""), weapon.traits)
		if not weapon.weapon_id.is_empty():
			weapon_registry[weapon.weapon_id] = weapon

## Derive weapon category from JSON type and traits
static func _derive_category(type_str: String, traits: Array[String]) -> String:
	if type_str == "Melee":
		return "melee"
	if type_str == "Grenade":
		return "grenade"
	if "Pistol" in traits:
		return "pistol"
	if "Heavy" in traits:
		return "heavy"
	if type_str == "Special":
		return "special"
	# Default ranged weapons to rifle
	return "rifle"

## Get weapon by ID
func get_weapon(weapon_id: String) -> WeaponData:
	return weapon_registry.get(weapon_id.to_lower().replace(" ", "_"), null)

## Get all weapons in category
func get_weapons_by_category(category: String) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon in weapon_registry.values():
		if weapon.category == category:
			result.append(weapon)
	return result

## Get all weapon categories
func get_categories() -> Array[String]:
	return ["pistol", "rifle", "heavy", "melee", "special", "grenade"]

## Search weapons by name
func search_weapons(query: String) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	var query_lower := query.to_lower()
	for weapon in weapon_registry.values():
		if weapon.name.to_lower().contains(query_lower):
			result.append(weapon)
	return result

## Get all weapons
func get_all_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon in weapon_registry.values():
		result.append(weapon)
	return result

## Roll random weapon from enemy type table
func roll_enemy_weapon(enemy_type: String) -> WeaponData:
	var table := _get_enemy_weapon_table(enemy_type)
	if table.is_empty():
		return get_weapon("handgun")

	var roll := randi_range(1, 100)
	var cumulative := 0

	for entry in table:
		cumulative += entry.weight
		if roll <= cumulative:
			return get_weapon(entry.weapon_id)

	return get_weapon(table[-1].weapon_id)

func _ensure_enemy_tables_loaded() -> void:
	if _enemy_tables_loaded:
		return
	_enemy_tables_loaded = true
	var file := FileAccess.open("res://data/enemy_weapon_tables.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		file.close()
		return
	file.close()
	_enemy_weapon_distributions = json.data.get("distributions", {})
	_enemy_weapon_aliases = json.data.get("aliases", {})

func _get_enemy_weapon_table(enemy_type: String) -> Array:
	_ensure_enemy_tables_loaded()
	var key: String = enemy_type.to_lower()
	# Check aliases first (e.g., "thug" -> "criminal")
	if _enemy_weapon_aliases.has(key):
		key = _enemy_weapon_aliases[key]
	var table: Array = _enemy_weapon_distributions.get(key, [])
	if table.is_empty():
		table = _enemy_weapon_distributions.get("default", [])
	return table

func _initialize_weapon_registry() -> void:
	weapon_registry.clear()

	# PISTOLS
	_add_weapon("handgun", "Handgun", 8, 1, 0, [], "pistol",
		"Standard sidearm. Reliable and common.")
	_add_weapon("auto_pistol", "Auto Pistol", 8, 2, 0, [], "pistol",
		"Rapid-fire pistol with increased shot capacity.")
	_add_weapon("machine_pistol", "Machine Pistol", 8, 3, 0, [], "pistol",
		"Compact automatic weapon with high rate of fire.")
	_add_weapon("hand_laser", "Hand Laser", 10, 1, 0, ["Critical"], "pistol",
		"Energy weapon with increased critical chance.")
	_add_weapon("blast_pistol", "Blast Pistol", 6, 1, 1, ["Piercing"], "pistol",
		"High-powered pistol with armor penetration.")
	_add_weapon("hand_flamer", "Hand Flamer", 6, 2, 0, ["Area", "Burn"], "pistol",
		"Short-range incendiary weapon.")

	# RIFLES
	_add_weapon("colony_rifle", "Colony Rifle", 18, 1, 0, [], "rifle",
		"Standard frontier rifle. Reliable and accurate.")
	_add_weapon("military_rifle", "Military Rifle", 24, 1, 0, [], "rifle",
		"Military-grade rifle with excellent range.")
	_add_weapon("auto_rifle", "Auto Rifle", 18, 2, 0, [], "rifle",
		"Automatic rifle with burst fire capability.")
	_add_weapon("infantry_laser", "Infantry Laser", 24, 1, 0, ["Critical"], "rifle",
		"Standard military energy rifle.")
	_add_weapon("needle_rifle", "Needle Rifle", 18, 2, 0, ["Piercing", "Silent"], "rifle",
		"Silent weapon firing armor-piercing flechettes.")
	_add_weapon("hunting_rifle", "Hunting Rifle", 30, 1, 1, ["Heavy"], "rifle",
		"Long-range rifle favored by hunters.")
	_add_weapon("shotgun", "Shotgun", 12, 2, 1, ["Focused"], "rifle",
		"Devastating at close range.")
	_add_weapon("rattle_gun", "Rattle Gun", 18, 3, 0, [], "rifle",
		"High-capacity automatic weapon.")
	_add_weapon("plasma_rifle", "Plasma Rifle", 18, 1, 2, ["Overheat"], "rifle",
		"Powerful plasma weapon with risk of overheat.")

	# HEAVY WEAPONS
	_add_weapon("machine_gun", "Machine Gun", 30, 3, 0, ["Heavy", "Stabilize"], "heavy",
		"Squad support weapon requiring setup.")
	_add_weapon("flak_gun", "Flak Gun", 24, 2, 1, ["Heavy", "Area"], "heavy",
		"Anti-personnel explosive weapon.")
	_add_weapon("plasma_cannon", "Plasma Cannon", 24, 1, 3, ["Heavy", "Overheat"], "heavy",
		"Devastating energy weapon.")
	_add_weapon("rattle_cannon", "Rattle Cannon", 24, 4, 0, ["Heavy", "Stabilize"], "heavy",
		"High-volume suppression weapon.")
	_add_weapon("fury_rifle", "Fury Rifle", 36, 1, 2, ["Heavy"], "heavy",
		"Long-range heavy rifle.")
	_add_weapon("hyper_blaster", "Hyper Blaster", 18, 4, 1, ["Heavy", "Overheat"], "heavy",
		"Rapid-fire energy weapon.")

	# MELEE WEAPONS
	_add_weapon("blade", "Blade", 0, 1, 0, ["Melee"], "melee",
		"Basic combat knife or sword.")
	_add_weapon("brutal_melee", "Brutal Melee Weapon", 0, 1, 1, ["Melee", "Clumsy"], "melee",
		"Heavy melee weapon with increased damage.")
	_add_weapon("power_claw", "Power Claw", 0, 1, 2, ["Melee", "Piercing"], "melee",
		"Powered melee weapon with armor penetration.")
	_add_weapon("ripper_sword", "Ripper Sword", 0, 2, 1, ["Melee"], "melee",
		"Chain-edged sword with rapid strikes.")
	_add_weapon("suppression_maul", "Suppression Maul", 0, 1, 2, ["Melee", "Stun"], "melee",
		"Non-lethal weapon that can stun targets.")
	_add_weapon("glare_sword", "Glare Sword", 0, 1, 1, ["Melee", "Elegant", "Critical"], "melee",
		"Elegant energy blade favored by elites.")

	# NATURAL WEAPONS
	_add_weapon("claws", "Claws", 0, 2, 0, ["Melee", "Natural"], "melee",
		"Natural creature weapon.")
	_add_weapon("fangs", "Fangs", 0, 1, 1, ["Melee", "Natural"], "melee",
		"Natural biting attack.")

	# SPECIAL WEAPONS
	_add_weapon("cling_fire_pistol", "Cling Fire Pistol", 8, 1, 0, ["Burn", "Area"], "special",
		"Fires adhesive incendiary gel.")
	_add_weapon("beam_light", "Beam Light", 12, 1, 0, ["Blind"], "special",
		"Blinds and disorients targets.")
	_add_weapon("shell_gun", "Shell Gun", 12, 1, 0, ["Stun", "Area"], "special",
		"Fires concussive shells.")
	_add_weapon("sonic_blaster", "Sonic Blaster", 8, 2, 0, ["Stun", "Area"], "special",
		"Area denial weapon using sonic waves.")

	# GRENADES
	_add_weapon("frag_grenade", "Frag Grenade", 6, 0, 1, ["Grenade", "Area"], "grenade",
		"Standard fragmentation grenade.")
	_add_weapon("stun_grenade", "Stun Grenade", 6, 0, 0, ["Grenade", "Stun", "Area"], "grenade",
		"Non-lethal concussion grenade.")
	_add_weapon("smoke_grenade", "Smoke Grenade", 6, 0, 0, ["Grenade", "Smoke"], "grenade",
		"Creates concealing smoke cloud.")

func _add_weapon(id: String, name: String, range_in: int, shots: int, damage: int,
		traits: Array, category: String, description: String) -> void:
	var weapon := WeaponData.new()
	weapon.weapon_id = id
	weapon.name = name
	weapon.range_inches = range_in
	weapon.shots = shots
	weapon.damage_bonus = damage
	weapon.traits.assign(traits)
	weapon.category = category
	weapon.description = description
	weapon_registry[id] = weapon
