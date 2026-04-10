class_name TacticsUpgradeOption
extends Resource

## TacticsUpgradeOption - Equipment/ability upgrade for Tactics army building
## Simplified from AoF: no mount upgrades, no caster. Adds vehicle weapon swaps.
## Source: Five Parsecs: Tactics species army lists

enum UpgradeType {
	WEAPON_SWAP,    # Replace an existing weapon
	WEAPON_ADD,     # Add an additional weapon
	ABILITY_GRANT,  # Grant special rules
	VEHICLE_WEAPON, # Vehicle weapon swap/add
	MODEL_COUNT,    # Change squad size
	STAT_CHANGE,    # Direct stat modification
}

# Upgrade Identity
@export var upgrade_name: String = ""
@export var upgrade_id: String = ""
@export var upgrade_type: UpgradeType = UpgradeType.WEAPON_SWAP
@export var points_cost: int = 0
@export var description: String = ""

# What it replaces (for WEAPON_SWAP)
var replaces_weapon_id: String = ""

# What it grants
var grants_weapon: TacticsWeaponProfile = null
var grants_rules: Array = []  # Array of TacticsSpecialRule
var grants_vehicle_weapon: TacticsWeaponProfile = null

# Stat overrides (e.g., {"toughness": 4, "model_count": 6})
var stat_overrides: Dictionary = {}

# Restrictions
@export var max_selections: int = 1
var mutually_exclusive_with: Array = []  # Array of String


## Get display name with cost for UI
func get_display_name() -> String:
	if points_cost > 0:
		return "%s (+%dpts)" % [upgrade_name, points_cost]
	elif points_cost < 0:
		return "%s (%dpts)" % [upgrade_name, points_cost]
	return "%s (free)" % upgrade_name


## Check if this upgrade conflicts with another
func conflicts_with(other_name: String) -> bool:
	return other_name in mutually_exclusive_with


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary, weapon_lookup: Dictionary = {}) -> TacticsUpgradeOption:
	var _Self = load("res://src/data/tactics/TacticsUpgradeOption.gd")
	var upgrade = _Self.new()
	upgrade.upgrade_name = data.get("name", data.get("upgrade_name", ""))
	upgrade.upgrade_id = data.get("id", data.get("upgrade_id", ""))
	upgrade.points_cost = data.get("cost", data.get("points_cost", 0))
	upgrade.description = data.get("description", "")
	upgrade.max_selections = data.get("max_selections", 1)

	# Type
	var type_str: String = data.get("type", "weapon_swap")
	upgrade.upgrade_type = _type_from_string(type_str)

	# Replaces
	upgrade.replaces_weapon_id = data.get("replaces", data.get("replaces_weapon_id", ""))

	# Grants weapon — can be an ID (lookup) or inline dict
	var grants_data: Variant = data.get("grants_weapon")
	if grants_data is String and weapon_lookup.has(grants_data):
		upgrade.grants_weapon = weapon_lookup[grants_data]
	elif grants_data is Dictionary:
		upgrade.grants_weapon = TacticsWeaponProfile.from_dict(grants_data)

	# Vehicle weapon
	var veh_data: Variant = data.get("grants_vehicle_weapon")
	if veh_data is String and weapon_lookup.has(veh_data):
		upgrade.grants_vehicle_weapon = weapon_lookup[veh_data]
	elif veh_data is Dictionary:
		upgrade.grants_vehicle_weapon = TacticsWeaponProfile.from_dict(veh_data)

	# Grants rules
	var raw_rules: Array = data.get("grants_rules", [])
	for raw in raw_rules:
		if raw is String:
			upgrade.grants_rules.append(TacticsSpecialRule.from_string(raw))
		elif raw is Dictionary:
			upgrade.grants_rules.append(TacticsSpecialRule.from_dict(raw))

	# Stat overrides
	upgrade.stat_overrides = data.get("stat_overrides", {}).duplicate()

	# Mutual exclusion
	var excl: Array = data.get("mutually_exclusive_with", [])
	for e in excl:
		if e is String:
			upgrade.mutually_exclusive_with.append(e)

	# Auto-generate ID
	if upgrade.upgrade_id.is_empty() and not upgrade.upgrade_name.is_empty():
		upgrade.upgrade_id = upgrade.upgrade_name.to_lower().replace(" ", "_")

	return upgrade


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"id": upgrade_id,
		"name": upgrade_name,
		"type": UpgradeType.keys()[upgrade_type].to_lower(),
		"cost": points_cost,
	}
	if not description.is_empty():
		data["description"] = description
	if not replaces_weapon_id.is_empty():
		data["replaces"] = replaces_weapon_id
	if grants_weapon:
		data["grants_weapon"] = grants_weapon.to_dict()
	if grants_vehicle_weapon:
		data["grants_vehicle_weapon"] = grants_vehicle_weapon.to_dict()
	if not grants_rules.is_empty():
		var rule_list: Array = []
		for rule in grants_rules:
			if rule is TacticsSpecialRule:
				rule_list.append(rule.to_dict())
		data["grants_rules"] = rule_list
	if not stat_overrides.is_empty():
		data["stat_overrides"] = stat_overrides.duplicate()
	if max_selections != 1:
		data["max_selections"] = max_selections
	if not mutually_exclusive_with.is_empty():
		data["mutually_exclusive_with"] = mutually_exclusive_with.duplicate()
	return data


static func _type_from_string(type_str: String) -> UpgradeType:
	match type_str.to_lower():
		"weapon_swap": return UpgradeType.WEAPON_SWAP
		"weapon_add": return UpgradeType.WEAPON_ADD
		"ability_grant", "ability": return UpgradeType.ABILITY_GRANT
		"vehicle_weapon": return UpgradeType.VEHICLE_WEAPON
		"model_count": return UpgradeType.MODEL_COUNT
		"stat_change": return UpgradeType.STAT_CHANGE
		_: return UpgradeType.WEAPON_SWAP
