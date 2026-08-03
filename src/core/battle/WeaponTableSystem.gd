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
		# Deliberately loud, and deliberately empty. There is no hardcoded
		# fallback any more — see the note at the bottom of this file. Showing
		# the player a fabricated weapon profile is worse than showing none.
		push_error(
			"WeaponTableSystem: could not load res://data/equipment_database.json. "
			+ "Weapon reference and enemy weapon rolls will be EMPTY. This is a "
			+ "packaging/data bug, not a condition to paper over."
		)

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

## The hardcoded weapon table that used to live here was DELETED 2026-08-02.
##
## It was a wholesale fabricated parallel table, wrong in roughly thirty
## profiles against Core Rules p.50 — Plasma Rifle 18"/1 shot/2 damage/Overheat
## where the book prints 20"/2/1/Focused+Piercing; Flak Gun 24"/Heavy+Area
## where the book prints 8"/Focused+Critical; Hand Flamer 6"/0 damage/Burn
## where the book prints 12"/1/Focused+Area. It also carried invented traits
## (Burn, Overheat, Stabilize, Silent, Natural, Blind, Smoke) and invented
## weapons (Auto Pistol, Machine Gun, Plasma Cannon, Rattle Cannon, Sonic
## Blaster). Its Suppression Maul entry — Brawl, 2 damage, Melee+Stun — matched
## the COMPENDIUM Game Options alternative table rather than the Core Rules
## (Brawl, 1 damage, Melee+Impact), which is exactly the sourcing trap
## documented in docs/RULES_WIRING_AUDIT_2026-08.md.
##
## data/equipment_database.json is the single source of truth and is verified
## byte-correct against p.50 for all 32 book weapons. A silent fallback to a
## fabricated table is worse than a hard failure: WeaponTableDisplay shows this
## data to the player as a rules reference, and EnemyGenerationWizard arms
## enemies from it, so wrong data here is wrong data at the table.
##
## Do not reintroduce a hardcoded fallback. If the JSON cannot be read, that is
## a packaging bug and must be loud.
