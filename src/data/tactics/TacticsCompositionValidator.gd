class_name TacticsCompositionValidator
extends RefCounted

## TacticsCompositionValidator - Validates Tactics army roster composition
## Complete rewrite of AoF rules: platoon org (2-5 troops, 0-4 supports,
## 0-2 specialists per platoon), company org (2-4 platoons, leaders = platoon count).
## Source: Five Parsecs: Tactics rulebook pp.81-88

# Platoon constraints (per-platoon)
const MIN_TROOPS_PER_PLATOON := 2
const MAX_TROOPS_PER_PLATOON := 5
const MAX_SUPPORTS_PER_PLATOON := 4  # Must be fewer than troops
const MAX_SPECIALISTS_PER_PLATOON := 2  # One of each type
const PLATOON_LEADER_COUNT := 1  # Each platoon has 1 leader

# Company constraints
const MIN_PLATOONS := 2
const MAX_PLATOONS := 4
const MAX_COMPANY_LEADERS := 4  # Max = platoon count
const MAX_COMPANY_SUPPORTS := 4  # Max = platoon count

# Points tiers
const POINTS_SMALL := 500
const POINTS_STANDARD := 750
const POINTS_LARGE := 1000

# Mixed army rule
const MAX_SPECIES_PICKUP := 2  # Pick-up games: max 2 species


## Validate a complete roster. Returns empty array if valid.
static func validate(roster: TacticsRoster) -> Array[String]:
	var errors: Array[String] = []

	if not roster.species_book:
		errors.append("No species book selected")
		return errors

	# Points check
	var total: int = roster.get_total_points()
	if total > roster.points_limit:
		errors.append("Over points limit: %d / %d" % [total, roster.points_limit])

	# Must have at least one entry
	if roster.entries.is_empty():
		errors.append("Roster is empty")
		return errors

	# Validate per org type
	match roster.org_type:
		TacticsRoster.OrgType.PLATOON:
			errors.append_array(_validate_platoon(roster, 0))
		TacticsRoster.OrgType.COMPANY:
			errors.append_array(_validate_company(roster))

	# Validate individual entries
	for i in range(roster.entries.size()):
		var entry: TacticsRosterEntry = roster.entries[i] as TacticsRosterEntry
		if entry:
			var entry_errors: Array[String] = entry.validate()
			for err in entry_errors:
				errors.append("Entry %d (%s): %s" % [i + 1, entry.get_display_name(), err])

	return errors


## Validate a single platoon within the roster
static func _validate_platoon(roster: TacticsRoster, platoon_idx: int) -> Array[String]:
	var errors: Array[String] = []

	var troop_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.TROOP, platoon_idx)
	var support_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.SUPPORT, platoon_idx)
	var specialist_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT, platoon_idx)
	var leader_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.LEADER, platoon_idx)

	var label: String = "Platoon %d" % (platoon_idx + 1)

	# Troops: 2-5
	if troop_count < MIN_TROOPS_PER_PLATOON:
		errors.append("%s: Need at least %d troop units (have %d)" % [
			label, MIN_TROOPS_PER_PLATOON, troop_count])
	if troop_count > MAX_TROOPS_PER_PLATOON:
		errors.append("%s: Max %d troop units (have %d)" % [
			label, MAX_TROOPS_PER_PLATOON, troop_count])

	# Supports: 0-4, must be fewer than troops
	if support_count > MAX_SUPPORTS_PER_PLATOON:
		errors.append("%s: Max %d support units (have %d)" % [
			label, MAX_SUPPORTS_PER_PLATOON, support_count])
	if support_count >= troop_count and troop_count > 0:
		errors.append("%s: Support count (%d) must be fewer than troop count (%d)" % [
			label, support_count, troop_count])

	# Specialists: 0-2, one of each type
	if specialist_count > MAX_SPECIALISTS_PER_PLATOON:
		errors.append("%s: Max %d specialist units (have %d)" % [
			label, MAX_SPECIALISTS_PER_PLATOON, specialist_count])

	# Check for duplicate specialist types within platoon
	var specialist_types: Array[String] = []
	for entry in roster.get_entries_for_platoon(platoon_idx):
		if entry is TacticsRosterEntry:
			if entry.get_org_slot() == TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT:
				if entry.base_profile:
					var name: String = entry.base_profile.unit_id
					if name in specialist_types:
						errors.append("%s: Duplicate specialist type '%s'" % [
							label, entry.base_profile.unit_name])
					else:
						specialist_types.append(name)

	# Leader: exactly 1 per platoon
	if leader_count == 0:
		errors.append("%s: Needs a platoon leader" % label)
	if leader_count > PLATOON_LEADER_COUNT:
		errors.append("%s: Max %d leader (have %d)" % [
			label, PLATOON_LEADER_COUNT, leader_count])

	return errors


## Validate company organization
static func _validate_company(roster: TacticsRoster) -> Array[String]:
	var errors: Array[String] = []

	# Company must have 2-4 platoons
	if roster.platoon_count < MIN_PLATOONS:
		errors.append("Company needs at least %d platoons (have %d)" % [
			MIN_PLATOONS, roster.platoon_count])
	if roster.platoon_count > MAX_PLATOONS:
		errors.append("Company max %d platoons (have %d)" % [
			MAX_PLATOONS, roster.platoon_count])

	# Validate each platoon
	for i in range(roster.platoon_count):
		errors.append_array(_validate_platoon(roster, i))

	# Company-level leaders: max = platoon count
	var company_leaders: int = 0
	for entry in roster.entries:
		if entry is TacticsRosterEntry:
			if entry.get_org_slot() == TacticsUnitProfile.OrgSlot.LEADER:
				if entry.platoon_index < 0:  # Company-level (not assigned to platoon)
					company_leaders += 1
	if company_leaders > roster.platoon_count:
		errors.append("Too many company leaders: %d (max %d = platoon count)" % [
			company_leaders, roster.platoon_count])

	# Company-level supports: max = platoon count
	var company_supports: int = 0
	for entry in roster.entries:
		if entry is TacticsRosterEntry:
			if entry.get_org_slot() == TacticsUnitProfile.OrgSlot.COMPANY_SUPPORT:
				company_supports += 1
	if company_supports > roster.platoon_count:
		errors.append("Too many company supports: %d (max %d = platoon count)" % [
			company_supports, roster.platoon_count])

	return errors


## Get a human-readable summary of composition limits for a given org type
static func get_limits_summary(org_type: int, points: int) -> String:
	var lines: Array[String] = []
	lines.append("Points: %d" % points)
	if org_type == TacticsRoster.OrgType.PLATOON:
		lines.append("1 Platoon Leader")
		lines.append("%d-%d Troop units" % [MIN_TROOPS_PER_PLATOON, MAX_TROOPS_PER_PLATOON])
		lines.append("0-%d Support units (fewer than troops)" % MAX_SUPPORTS_PER_PLATOON)
		lines.append("0-%d Specialists (one of each type)" % MAX_SPECIALISTS_PER_PLATOON)
	else:
		lines.append("%d-%d Platoons" % [MIN_PLATOONS, MAX_PLATOONS])
		lines.append("Per platoon: same as above")
		lines.append("Company leaders: max = platoon count")
		lines.append("Company supports: max = platoon count")
	return "\n".join(lines)
