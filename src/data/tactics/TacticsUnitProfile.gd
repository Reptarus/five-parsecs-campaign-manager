class_name TacticsUnitProfile
extends Resource

## TacticsUnitProfile - Five Parsecs: Tactics unit definition
## Replaces AoF quality/defense with Tactics' 7-stat system:
## Speed, Reactions, Combat Skill, Toughness, KP, Savvy, Training.
## Drops caster/base_size/active_abilities. Adds org_slot for platoon structure.
## Source: Five Parsecs: Tactics rulebook pp.14-20, species army lists

enum UnitType {
	INFANTRY,       # Standard foot troops (4-5 soldiers + sergeant)
	RECON,          # Recon squad
	STORM,          # Storm/assault squad
	CHARACTER,      # Individual character (Sergeant, Major, Epic)
	VEHICLE,        # Vehicle unit (uses TacticsVehicleProfile for stats)
	SPECIALIST,     # Specialist attachment (Tech, Sharpshooter, Medic, etc.)
	WEAPON_TEAM,    # Crewed weapon team (3 soldiers + weapon)
}

enum OrgSlot {
	LEADER,         # Company/Platoon leader character
	TROOP,          # Core troops (2-5 per platoon)
	SUPPORT,        # Support units (0-4, fewer than troops)
	SPECIALIST_SLOT, # Specialist attachments (0-2, one of each type)
	COMPANY_SUPPORT, # Company-level support (0-4, max = platoon count)
}

enum ProfileTier {
	CIVILIAN,       # Untrained (tier 1)
	MILITARY,       # Standard soldier (tier 2)
	SERGEANT,       # Squad leader / Minor Character (tier 3)
	MAJOR,          # Experienced officer (tier 4)
	EPIC,           # Elite hero (tier 5)
}

# Identity
@export var unit_name: String = ""
@export var unit_id: String = ""
@export var unit_type: UnitType = UnitType.INFANTRY
@export var org_slot: OrgSlot = OrgSlot.TROOP
@export var profile_tier: ProfileTier = ProfileTier.MILITARY
@export var points_cost: int = 0

# Tactics Stats (7-stat system, same base as 5PFH + Training)
@export_group("Stats")
@export var speed: int = 4              # Movement in inches
@export var reactions: int = 2          # Initiative/alertness (dice count)
@export var combat_skill: int = 1       # Weapons training bonus (+0 to +2)
@export var toughness: int = 3          # Damage resistance
@export var kill_points: int = 1        # Damage capacity (KP, vehicles have 2-8)
@export var savvy: int = 0              # Wits/tech aptitude
@export var training: int = 1           # Military competence (morale, tests)

# Saving Throw (0 = no save, 5 = 5+, 6 = 6+)
@export var saving_throw: int = 0

# Composition
@export_group("Composition")
@export var base_models: int = 5        # Default squad size (soldiers + sergeant)
@export var min_models: int = 4         # Minimum for unit
@export var max_models: int = 6         # Maximum for unit

# Equipment
var weapons: Array = []                 # Array of TacticsWeaponProfile
var special_rules: Array = []           # Array of TacticsSpecialRule
var upgrade_groups: Array = []          # Array of TacticsUpgradeGroup

# Vehicle reference (for UnitType.VEHICLE)
var vehicle_profile: TacticsVehicleProfile = null


## Check if unit has a specific special rule
func has_rule(rule_name: String) -> bool:
	for rule in special_rules:
		if rule is TacticsSpecialRule and rule.matches(rule_name):
			return true
	return false


## Get rule value for parametric rules
func get_rule_value(rule_name: String) -> int:
	for rule in special_rules:
		if rule is TacticsSpecialRule and rule.matches(rule_name):
			return rule.rule_value
	return 0


## Check if this is a vehicle unit
func is_vehicle() -> bool:
	return unit_type == UnitType.VEHICLE


## Check if this is a character (individual model)
func is_character() -> bool:
	return unit_type == UnitType.CHARACTER


## Check if this is a leader slot
func is_leader() -> bool:
	return org_slot == OrgSlot.LEADER


## Get the primary weapon
func get_primary_weapon() -> TacticsWeaponProfile:
	if weapons.size() > 0:
		return weapons[0] as TacticsWeaponProfile
	return null


## Get description for UI display
func get_description() -> String:
	var parts: Array[String] = []
	parts.append("%s (%s)" % [unit_name, UnitType.keys()[unit_type].capitalize()])
	parts.append("Spd%d Rct%d CS+%d T%d KP%d Sav+%d Trn+%d" % [
		speed, reactions, combat_skill, toughness, kill_points, savvy, training
	])
	if saving_throw > 0:
		parts.append("%d+ Save" % saving_throw)
	parts.append("%d models" % base_models)
	for rule in special_rules:
		if rule is TacticsSpecialRule:
			parts.append(rule.get_display_name())
	return ", ".join(parts)


## Get stat line as a dictionary (for UI stat grids)
func get_stat_line() -> Dictionary:
	return {
		"speed": speed,
		"reactions": reactions,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"kill_points": kill_points,
		"savvy": savvy,
		"training": training,
		"saving_throw": saving_throw,
	}


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary, weapon_lookup: Dictionary = {},
		vehicle_lookup: Dictionary = {}) -> TacticsUnitProfile:
	var _Self = load("res://src/data/tactics/TacticsUnitProfile.gd")
	var profile = _Self.new()
	profile.unit_name = data.get("name", data.get("unit_name", ""))
	profile.unit_id = data.get("id", data.get("unit_id", ""))
	profile.points_cost = data.get("cost", data.get("points_cost", 0))

	# Stats
	profile.speed = data.get("speed", 4)
	profile.reactions = data.get("reactions", 2)
	profile.combat_skill = data.get("combat_skill", 1)
	profile.toughness = data.get("toughness", 3)
	profile.kill_points = data.get("kp", data.get("kill_points", 1))
	profile.savvy = data.get("savvy", 0)
	profile.training = data.get("training", 1)
	profile.saving_throw = data.get("saving_throw", data.get("save", 0))

	# Composition
	profile.base_models = data.get("models", data.get("base_models", 5))
	profile.min_models = data.get("min_models", maxi(profile.base_models - 1, 1))
	profile.max_models = data.get("max_models", profile.base_models + 1)

	# Type & Org
	var type_str: String = data.get("type", data.get("unit_type", "infantry"))
	profile.unit_type = _type_from_string(type_str)

	var org_str: String = data.get("org_slot", "troop")
	profile.org_slot = _org_from_string(org_str)

	var tier_str: String = data.get("tier", data.get("profile_tier", "military"))
	profile.profile_tier = _tier_from_string(tier_str)

	# Weapons — array of IDs or inline dicts
	var raw_weapons: Array = data.get("weapons", [])
	for raw in raw_weapons:
		if raw is String and weapon_lookup.has(raw):
			profile.weapons.append(weapon_lookup[raw])
		elif raw is Dictionary:
			profile.weapons.append(TacticsWeaponProfile.from_dict(raw))

	# Special rules
	var raw_rules: Array = data.get("special_rules", [])
	for raw in raw_rules:
		if raw is String:
			profile.special_rules.append(TacticsSpecialRule.from_string(raw))
		elif raw is Dictionary:
			profile.special_rules.append(TacticsSpecialRule.from_dict(raw))

	# Upgrade groups
	var raw_upgrades: Array = data.get("upgrade_groups", [])
	for raw in raw_upgrades:
		if raw is Dictionary:
			profile.upgrade_groups.append(TacticsUpgradeGroup.from_dict(raw, weapon_lookup))

	# Vehicle reference
	var veh_id: String = data.get("vehicle_id", "")
	if not veh_id.is_empty() and vehicle_lookup.has(veh_id):
		profile.vehicle_profile = vehicle_lookup[veh_id]
	elif data.has("vehicle"):
		profile.vehicle_profile = TacticsVehicleProfile.from_dict(data["vehicle"])

	# Auto-generate ID
	if profile.unit_id.is_empty() and not profile.unit_name.is_empty():
		profile.unit_id = profile.unit_name.to_lower().replace(" ", "_")

	return profile


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"id": unit_id,
		"name": unit_name,
		"type": UnitType.keys()[unit_type].to_lower(),
		"org_slot": OrgSlot.keys()[org_slot].to_lower(),
		"tier": ProfileTier.keys()[profile_tier].to_lower(),
		"cost": points_cost,
		"speed": speed,
		"reactions": reactions,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"kp": kill_points,
		"savvy": savvy,
		"training": training,
		"models": base_models,
	}
	if saving_throw > 0:
		data["saving_throw"] = saving_throw

	# Weapons
	var weapon_list: Array = []
	for w in weapons:
		if w is TacticsWeaponProfile:
			weapon_list.append(w.to_dict())
	if not weapon_list.is_empty():
		data["weapons"] = weapon_list

	# Special rules
	var rule_list: Array = []
	for rule in special_rules:
		if rule is TacticsSpecialRule:
			rule_list.append(rule.to_dict())
	if not rule_list.is_empty():
		data["special_rules"] = rule_list

	# Upgrade groups
	var upgrade_list: Array = []
	for group in upgrade_groups:
		if group is TacticsUpgradeGroup:
			upgrade_list.append(group.to_dict())
	if not upgrade_list.is_empty():
		data["upgrade_groups"] = upgrade_list

	# Vehicle
	if vehicle_profile:
		data["vehicle"] = vehicle_profile.to_dict()

	return data


static func _type_from_string(type_str: String) -> UnitType:
	match type_str.to_lower():
		"infantry": return UnitType.INFANTRY
		"recon": return UnitType.RECON
		"storm": return UnitType.STORM
		"character": return UnitType.CHARACTER
		"vehicle": return UnitType.VEHICLE
		"specialist": return UnitType.SPECIALIST
		"weapon_team": return UnitType.WEAPON_TEAM
		_: return UnitType.INFANTRY


static func _org_from_string(org_str: String) -> OrgSlot:
	match org_str.to_lower():
		"leader": return OrgSlot.LEADER
		"troop": return OrgSlot.TROOP
		"support": return OrgSlot.SUPPORT
		"specialist", "specialist_slot": return OrgSlot.SPECIALIST_SLOT
		"company_support": return OrgSlot.COMPANY_SUPPORT
		_: return OrgSlot.TROOP


static func _tier_from_string(tier_str: String) -> ProfileTier:
	match tier_str.to_lower():
		"civilian": return ProfileTier.CIVILIAN
		"military": return ProfileTier.MILITARY
		"sergeant", "minor": return ProfileTier.SERGEANT
		"major": return ProfileTier.MAJOR
		"epic": return ProfileTier.EPIC
		_: return ProfileTier.MILITARY
