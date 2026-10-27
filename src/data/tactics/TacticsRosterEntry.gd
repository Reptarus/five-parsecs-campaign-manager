class_name TacticsRosterEntry
extends Resource

## TacticsRosterEntry - One configured unit in a player's Tactics roster
## Simplified from AoF ArmyListEntry: drops combined units logic.
## Adds org_slot tracking for platoon composition validation.
## Source: Five Parsecs: Tactics **pp.132-138** — the Army Builder chapter.
## ⚠ CITE CORRECTED 2026-09-04 from "pp.81-88" (that is Scenario Types).

# Base unit from the species book
var base_profile: TacticsUnitProfile = null

# Selected upgrades (from the profile's upgrade_groups)
var selected_upgrades: Array = []  # Array of TacticsUpgradeOption

# Chosen model count (between min_models and max_models)
@export var model_count: int = 0

# Display name override (e.g., "1st Infantry Squad" vs just "Infantry Squad")
@export var display_name: String = ""

# Entry ID (unique within roster)
@export var entry_id: String = ""

# Platoon assignment (which platoon this unit belongs to, 0-indexed). -1 is a
# company-level unit (p.135: the company's own Leaders and Supports).
@export var platoon_index: int = 0

# p.135 Armored Platoon: the role a vehicle fills there, "leader" or "troop". Empty
# means the profile's own slot, which is every case outside an armored platoon.
@export var role: String = ""

# p.138 Mechanized Infantry: "Any squad may be selected as mechanized infantry. Select
# a transport vehicle capable of carrying the squad." The transport is bought with the
# squad, so its cost is part of this entry. p.135 requires one for every Support in an
# armored platoon.
@export var transport_vehicle_id: String = ""
var transport_profile: TacticsVehicleProfile = null


## Get total points cost (base + upgrades)
func get_total_cost() -> int:
	if not base_profile:
		return 0

	var total: int = base_profile.points_cost

	for upgrade in selected_upgrades:
		if upgrade is TacticsUpgradeOption:
			total += upgrade.points_cost

	if transport_profile:
		total += transport_profile.points_cost

	return total


## Get the configured profile with all upgrades applied (returns new copy)
func get_configured_profile() -> TacticsUnitProfile:
	if not base_profile:
		return null

	var configured := _clone_profile(base_profile)

	if model_count > 0:
		configured.base_models = clampi(model_count, configured.min_models, configured.max_models)

	# Apply stat overrides from upgrades
	for upgrade in selected_upgrades:
		if upgrade is TacticsUpgradeOption:
			_apply_upgrade(configured, upgrade)

	if not display_name.is_empty():
		configured.unit_name = display_name

	return configured


## Validate this entry — returns empty array if valid
func validate() -> Array[String]:
	var errors: Array[String] = []

	if not base_profile:
		errors.append("No base profile set")
		return errors

	if model_count > 0:
		if model_count < base_profile.min_models:
			errors.append("Model count %d below minimum %d" % [model_count, base_profile.min_models])
		if model_count > base_profile.max_models:
			errors.append("Model count %d exceeds maximum %d" % [model_count, base_profile.max_models])

	# Check for conflicting upgrades
	var selected_names: Array[String] = []
	for upgrade in selected_upgrades:
		if not upgrade is TacticsUpgradeOption:
			continue
		for existing_name in selected_names:
			if upgrade.conflicts_with(existing_name):
				errors.append("'%s' conflicts with '%s'" % [upgrade.upgrade_name, existing_name])
		selected_names.append(upgrade.upgrade_name)

	# Each option group's own selection rule.
	for g in base_profile.upgrade_groups:
		if not (g is TacticsUpgradeGroup):
			continue
		var picked := 0
		for upgrade in selected_upgrades:
			if g.options.has(upgrade):
				picked += 1
		var cap: int = picked
		match g.selection_mode:
			TacticsUpgradeGroup.SelectionMode.PICK_ONE:
				cap = 1
			TacticsUpgradeGroup.SelectionMode.PICK_UP_TO_N:
				cap = g.max_selections
		if picked > cap:
			errors.append("'%s': at most %d (have %d)" % [g.get_header_text(), cap, picked])

	# p.138 Mechanized Infantry.
	if not transport_vehicle_id.is_empty():
		if not is_squad():
			errors.append("Only a squad may ride in a transport (p.138)")
		elif transport_profile == null:
			errors.append("Unknown transport '%s'" % transport_vehicle_id)
		elif transport_profile.transport_capacity < carried_models():
			errors.append("%s carries %d figures; the squad has %d (p.138)" % [
				transport_profile.vehicle_name, transport_profile.transport_capacity,
				carried_models()])

	return errors


## An infantry, recon or storm squad (p.134 Troops; p.138 mechanized infantry).
func is_squad() -> bool:
	if not base_profile:
		return false
	return base_profile.unit_type in [TacticsUnitProfile.UnitType.INFANTRY,
		TacticsUnitProfile.UnitType.RECON, TacticsUnitProfile.UnitType.STORM]


## How many figures a transport must carry for this entry.
func carried_models() -> int:
	if model_count > 0:
		return model_count
	return base_profile.base_models if base_profile else 0


## One of this unit's listed options, by name (what the builder stores) or id.
func find_option(key: String) -> TacticsUpgradeOption:
	if not base_profile:
		return null
	for g in base_profile.upgrade_groups:
		if not (g is TacticsUpgradeGroup):
			continue
		for o in g.options:
			if o is TacticsUpgradeOption and (o.upgrade_name == key or o.upgrade_id == key):
				return o
	return null


## Build an entry from the builder's Dictionary form, resolving the unit, its options
## and its transport against one species book. The roster panel and the creation
## coordinator both price and validate through this, so the cost a player sees is the
## cost the validator checks.
static func from_entry_dict(data: Dictionary, book) -> TacticsRosterEntry:
	var _Self = load("res://src/data/tactics/TacticsRosterEntry.gd")
	var entry = _Self.new()
	entry.entry_id = str(data.get("entry_id", ""))
	entry.platoon_index = int(data.get("platoon_index", 0))
	entry.model_count = int(data.get("model_count", 0))
	entry.display_name = str(data.get("display_name", ""))
	entry.role = str(data.get("role", ""))
	entry.transport_vehicle_id = str(data.get("transport_vehicle_id", ""))
	if book == null:
		return entry
	var unit_id: String = str(data.get("unit_id", ""))
	if not unit_id.is_empty():
		entry.base_profile = book.get_unit_profile(unit_id)
	for want in data.get("selected_upgrades", []):
		var opt: TacticsUpgradeOption = entry.find_option(str(want))
		if opt:
			entry.selected_upgrades.append(opt)
	if not entry.transport_vehicle_id.is_empty():
		entry.transport_profile = book.get_vehicle(entry.transport_vehicle_id)
	return entry


## Get display name for UI
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if base_profile:
		return base_profile.unit_name
	return "Empty Entry"


## Get upgrade summary text
func get_upgrade_summary() -> String:
	if selected_upgrades.is_empty():
		return "No upgrades"
	var names: Array[String] = []
	for upgrade in selected_upgrades:
		if upgrade is TacticsUpgradeOption:
			names.append(upgrade.upgrade_name)
	return ", ".join(names)


## Get the org slot from the base profile
func get_org_slot() -> int:
	if base_profile:
		return base_profile.org_slot
	return TacticsUnitProfile.OrgSlot.TROOP


## Serialize to dictionary (for save/load)
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"entry_id": entry_id,
		"platoon_index": platoon_index,
	}
	if not role.is_empty():
		data["role"] = role
	if not transport_vehicle_id.is_empty():
		data["transport_vehicle_id"] = transport_vehicle_id
	if not display_name.is_empty():
		data["display_name"] = display_name
	if model_count > 0:
		data["model_count"] = model_count
	if base_profile:
		data["unit_id"] = base_profile.unit_id
	# Option NAMES, the form the builder and the campaign-unit record both store.
	var upgrade_names: Array = []
	for upgrade in selected_upgrades:
		if upgrade is TacticsUpgradeOption:
			upgrade_names.append(upgrade.upgrade_name)
	if not upgrade_names.is_empty():
		data["selected_upgrades"] = upgrade_names
	return data


## Deep clone a TacticsUnitProfile
func _clone_profile(source: TacticsUnitProfile) -> TacticsUnitProfile:
	var clone := TacticsUnitProfile.new()

	# Identity
	clone.unit_name = source.unit_name
	clone.unit_id = source.unit_id
	clone.unit_type = source.unit_type
	clone.org_slot = source.org_slot
	clone.profile_tier = source.profile_tier
	clone.points_cost = source.points_cost

	# Stats
	clone.speed = source.speed
	clone.reactions = source.reactions
	clone.combat_skill = source.combat_skill
	clone.toughness = source.toughness
	clone.kill_points = source.kill_points
	clone.savvy = source.savvy
	clone.training = source.training
	clone.saving_throw = source.saving_throw

	# Composition
	clone.base_models = source.base_models
	clone.min_models = source.min_models
	clone.max_models = source.max_models

	# Equipment (shallow copy — upgrades replace individual items)
	clone.weapons = source.weapons.duplicate()
	clone.special_rules = source.special_rules.duplicate()
	clone.upgrade_groups = source.upgrade_groups.duplicate()

	# Vehicle
	clone.vehicle_profile = source.vehicle_profile

	return clone


## Apply a single upgrade to a profile
func _apply_upgrade(profile: TacticsUnitProfile, upgrade: TacticsUpgradeOption) -> void:
	match upgrade.upgrade_type:
		TacticsUpgradeOption.UpgradeType.WEAPON_SWAP:
			if upgrade.grants_weapon:
				# Find and replace matching weapon
				if not upgrade.replaces_weapon_id.is_empty():
					for i in range(profile.weapons.size()):
						var w: TacticsWeaponProfile = profile.weapons[i] as TacticsWeaponProfile
						if w and w.weapon_id == upgrade.replaces_weapon_id:
							profile.weapons[i] = upgrade.grants_weapon
							break
				else:
					profile.weapons.append(upgrade.grants_weapon)

		TacticsUpgradeOption.UpgradeType.WEAPON_ADD:
			if upgrade.grants_weapon:
				profile.weapons.append(upgrade.grants_weapon)

		TacticsUpgradeOption.UpgradeType.ABILITY_GRANT:
			for rule in upgrade.grants_rules:
				if rule is TacticsSpecialRule:
					profile.special_rules.append(rule)

		TacticsUpgradeOption.UpgradeType.STAT_CHANGE:
			_apply_stat_overrides(profile, upgrade.stat_overrides)

		TacticsUpgradeOption.UpgradeType.MODEL_COUNT:
			if "model_count" in upgrade.stat_overrides:
				profile.base_models = upgrade.stat_overrides["model_count"]

	# Apply generic stat overrides
	if upgrade.upgrade_type != TacticsUpgradeOption.UpgradeType.STAT_CHANGE:
		_apply_stat_overrides(profile, upgrade.stat_overrides)

	profile.points_cost += upgrade.points_cost


func _apply_stat_overrides(profile: TacticsUnitProfile, overrides: Dictionary) -> void:
	for stat_name in overrides:
		if stat_name == "model_count":
			continue
		match stat_name:
			"speed": profile.speed = overrides[stat_name]
			"reactions": profile.reactions = overrides[stat_name]
			"combat_skill": profile.combat_skill = overrides[stat_name]
			"toughness": profile.toughness = overrides[stat_name]
			"kill_points": profile.kill_points = overrides[stat_name]
			"savvy": profile.savvy = overrides[stat_name]
			"training": profile.training = overrides[stat_name]
			"saving_throw": profile.saving_throw = overrides[stat_name]
