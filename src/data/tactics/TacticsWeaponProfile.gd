class_name TacticsWeaponProfile
extends Resource

## TacticsWeaponProfile - Five Parsecs: Tactics weapon definition
## Converts AoF WeaponProfile: attacks→shots, armor_piercing→damage,
## adds 6 weapon categories and 25 Tactics-specific traits.
## Source: Five Parsecs: Tactics rulebook pp.36-42

enum WeaponCategory {
	MELEE,          # Blades, claws, powered weapons
	GRENADE,        # Thrown ordnance (Area, limited)
	SIDEARM,        # Pistols (short range, Pistol trait)
	RIFLE,          # Standard ranged (Military Rifle, Infantry Laser, etc.)
	TEAM_WEAPON,    # Crew-served squad weapons (LMG, Plasma Rifle, etc.)
	CREWED_WEAPON,  # Emplacement/vehicle weapons (Laser Cannon, 100mm, etc.)
}

# Basic Properties
@export var weapon_name: String = ""
@export var weapon_id: String = ""
@export var category: WeaponCategory = WeaponCategory.RIFLE
@export var points_cost: int = 0

# Combat Stats (Tactics-specific)
@export_group("Combat Stats")
@export var range_inches: int = 0           # 0 = melee only
@export var shots: int = 1                  # Number of shots (0 for melee/grenades)
@export var damage: int = 0                 # Damage bonus (added to D6 roll vs Toughness)
@export var damage_multiplier: int = 1      # x2, x3, x4 for heavy weapons (e.g., 5(x3))

# Special Rules / Weapon Traits
@export_group("Traits")
var traits: Array = []  # Array of TacticsSpecialRule


## Check if weapon has a specific trait
func has_trait(trait_name: String) -> bool:
	for t in traits:
		if t is TacticsSpecialRule and t.matches(trait_name):
			return true
	return false


## Get trait value for parametric traits like Minimum Range(12)
func get_trait_value(trait_name: String) -> int:
	for t in traits:
		if t is TacticsSpecialRule and t.matches(trait_name):
			return t.rule_value
	return 0


## Check if weapon is melee
func is_melee() -> bool:
	return category == WeaponCategory.MELEE or has_trait("Melee")


## Check if weapon is ranged
func is_ranged() -> bool:
	return range_inches > 0 and not is_melee()


## Check if weapon requires a team to operate
func is_team_weapon() -> bool:
	return category == WeaponCategory.TEAM_WEAPON or has_trait("Team")


## Check if weapon is crewed (emplacement/vehicle mount)
func is_crewed() -> bool:
	return category == WeaponCategory.CREWED_WEAPON or has_trait("Crewed")


## Check if weapon can fire after moving
func can_fire_after_move() -> bool:
	return not has_trait("Heavy") and not has_trait("Crewed")


## Get formatted damage string for UI (e.g., "5(x3)" or "1")
func get_damage_display() -> String:
	if damage_multiplier > 1:
		return "%d(x%d)" % [damage, damage_multiplier]
	return str(damage)


## Get display name for UI
func get_display_name() -> String:
	var parts: Array[String] = [weapon_name]
	if range_inches > 0:
		parts.append('%d"' % range_inches)
	if shots > 0:
		parts.append("%d shot%s" % [shots, "s" if shots > 1 else ""])
	parts.append("Dmg %s" % get_damage_display())
	return " — ".join(parts)


## Get trait names as a comma-separated string
func get_traits_display() -> String:
	var names: Array[String] = []
	for t in traits:
		if t is TacticsSpecialRule:
			names.append(t.get_display_name())
	return ", ".join(names)


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary) -> TacticsWeaponProfile:
	var _Self = load("res://src/data/tactics/TacticsWeaponProfile.gd")
	var weapon = _Self.new()
	weapon.weapon_name = data.get("name", data.get("weapon_name", ""))
	weapon.weapon_id = data.get("id", data.get("weapon_id", ""))
	weapon.points_cost = data.get("cost", data.get("points_cost", 0))
	weapon.range_inches = data.get("range", data.get("range_inches", 0))
	weapon.shots = data.get("shots", 1)
	weapon.damage = data.get("damage", 0)
	weapon.damage_multiplier = data.get("damage_multiplier", 1)

	# Category
	var cat_str: String = data.get("category", "rifle")
	weapon.category = _category_from_string(cat_str)

	# Traits — array of strings or dicts
	var raw_traits: Array = data.get("traits", [])
	for raw in raw_traits:
		if raw is String:
			weapon.traits.append(TacticsSpecialRule.from_string(raw))
		elif raw is Dictionary:
			weapon.traits.append(TacticsSpecialRule.from_dict(raw))

	# Auto-generate weapon_id from name if empty
	if weapon.weapon_id.is_empty() and not weapon.weapon_name.is_empty():
		weapon.weapon_id = weapon.weapon_name.to_lower().replace(" ", "_")

	return weapon


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"id": weapon_id,
		"name": weapon_name,
		"category": WeaponCategory.keys()[category].to_lower(),
		"cost": points_cost,
		"range": range_inches,
		"shots": shots,
		"damage": damage,
	}
	if damage_multiplier > 1:
		data["damage_multiplier"] = damage_multiplier

	var trait_list: Array = []
	for t in traits:
		if t is TacticsSpecialRule:
			if t.rule_value > 0:
				trait_list.append(t.get_display_name())
			else:
				trait_list.append(t.rule_name)
	if not trait_list.is_empty():
		data["traits"] = trait_list

	return data


static func _category_from_string(cat_str: String) -> WeaponCategory:
	match cat_str.to_lower():
		"melee": return WeaponCategory.MELEE
		"grenade": return WeaponCategory.GRENADE
		"sidearm": return WeaponCategory.SIDEARM
		"rifle": return WeaponCategory.RIFLE
		"team_weapon", "team": return WeaponCategory.TEAM_WEAPON
		"crewed_weapon", "crewed": return WeaponCategory.CREWED_WEAPON
		_: return WeaponCategory.RIFLE
