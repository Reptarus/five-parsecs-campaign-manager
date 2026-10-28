class_name PlanetfallBuildingSystem
extends RefCounted

## Manages Planetfall colony building construction.
## One building under construction at a time. BP can be spread over turns.
## Max 3 RM → BP conversion per turn. One of each building per colony.
## Source: Planetfall pp.97-104

var _buildings: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var path := "res://data/planetfall/buildings.json"
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallBuildingSystem: JSON not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is Dictionary:
		_buildings = json.data.get("buildings", [])
	_loaded = not _buildings.is_empty()


## ============================================================================
## QUERIES
## ============================================================================

func get_all_buildings() -> Array:
	return _buildings.duplicate(true)


func get_building(building_id: String) -> Dictionary:
	for b in _buildings:
		if b is Dictionary and b.get("id", "") == building_id:
			return b.duplicate(true)
	return {}


func is_constructed(campaign: Resource, building_id: String) -> bool:
	var bd: Dictionary = _get_buildings_data(campaign)
	var constructed: Array = bd.get("constructed", [])
	return constructed.has(building_id)


func get_constructed_buildings(campaign: Resource) -> Array:
	var bd: Dictionary = _get_buildings_data(campaign)
	return bd.get("constructed", []).duplicate()


func get_in_progress(campaign: Resource) -> Dictionary:
	## Returns {building_id: bp_remaining} or empty.
	var bd: Dictionary = _get_buildings_data(campaign)
	return bd.get("in_progress", {}).duplicate()


func get_available_buildings(
		campaign: Resource,
		research_system: RefCounted = null) -> Array:
	## Returns buildings not yet constructed, whose prerequisites are met.
	var constructed: Array = get_constructed_buildings(campaign)
	var result: Array = []
	for b in _buildings:
		if b is not Dictionary:
			continue
		var bid: String = b.get("id", "")
		if constructed.has(bid):
			continue
		if _check_prerequisite(campaign, b, research_system):
			result.append(b.duplicate(true))
	return result


func get_current_bp(campaign: Resource) -> int:
	var bd: Dictionary = _get_buildings_data(campaign)
	return bd.get("current_bp", 0)


func can_build(campaign: Resource, building_id: String) -> bool:
	if is_constructed(campaign, building_id):
		return false
	var building: Dictionary = get_building(building_id)
	return not building.is_empty()


## ============================================================================
## CONSTRUCTION
## ============================================================================

func invest_bp(
		campaign: Resource,
		building_id: String,
		bp_amount: int) -> Dictionary:
	## Invest BP toward a building. Returns {success, remaining, completed}.
	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return {"success": false, "error": "Unknown building"}
	if is_constructed(campaign, building_id):
		return {"success": false, "error": "Already constructed"}

	var bd: Dictionary = _get_buildings_data(campaign)
	var current_bp: int = bd.get("current_bp", 0)
	if current_bp < bp_amount:
		return {"success": false, "error": "Not enough BP"}
	# p.97: "You can only put BP towards a single Building per campaign turn."
	var other: String = building_invested_this_turn(campaign)
	if other != "" and other != building_id:
		return {"success": false, "error": "BP already went to %s this turn (p.97)." % str(
				get_building(other).get("name", other))}

	var bp_cost: int = building.get("bp_cost", 0)
	var in_progress: Dictionary = bd.get("in_progress", {})
	var already_invested: int = 0
	if in_progress.has(building_id):
		already_invested = bp_cost - in_progress[building_id]

	var invest: int = mini(bp_amount, bp_cost - already_invested)
	var remaining: int = bp_cost - already_invested - invest

	# Deduct BP
	bd["current_bp"] = current_bp - invest
	bd["invested_turn"] = _turn(campaign)
	bd["invested_building"] = building_id

	# Update in-progress
	if not bd.has("in_progress"):
		bd["in_progress"] = {}
	if remaining > 0:
		bd["in_progress"][building_id] = remaining
	else:
		bd["in_progress"].erase(building_id)

	# Check completion
	var completed: bool = remaining <= 0
	if completed:
		_complete_building(campaign, building_id, bd)

	_set_buildings_data(campaign, bd)
	return {
		"success": true,
		"invested": invest,
		"remaining": max(0, remaining),
		"completed": completed
	}


## p.98: "convert 1 unit of Raw Materials into 1 BP, with up to 3 units converted per
## round". The cap was per CALL, so pressing Convert again moved three more.
const MAX_CONVERT_PER_TURN := 3


func convert_rm_to_bp(
		campaign: Resource, rm_amount: int) -> int:
	## Convert Raw Materials to Build Points (max 3 per turn).
	## Returns actual BP gained.
	var actual: int = mini(rm_amount, convertible_this_turn(campaign))
	if actual <= 0 or not campaign or not campaign.has_method("spend_raw_materials"):
		return 0
	if not campaign.spend_raw_materials(actual):
		return 0
	var bd: Dictionary = _get_buildings_data(campaign)
	bd["current_bp"] = bd.get("current_bp", 0) + actual
	var turn: int = _turn(campaign)
	var before: int = int(bd.get("converted_count", 0)) \
			if int(bd.get("converted_turn", -1)) == turn else 0
	bd["converted_turn"] = turn
	bd["converted_count"] = before + actual
	_set_buildings_data(campaign, bd)
	return actual


## How many Raw Materials may still become BP this turn: the p.98 cap less what was
## converted, and never more than the colony holds.
func convertible_this_turn(campaign: Resource) -> int:
	var bd: Dictionary = _get_buildings_data(campaign)
	var used: int = int(bd.get("converted_count", 0)) \
			if int(bd.get("converted_turn", -1)) == _turn(campaign) else 0
	var held: int = int(campaign.raw_materials) \
			if campaign and "raw_materials" in campaign else 0
	return clampi(mini(MAX_CONVERT_PER_TURN - used, held), 0, MAX_CONVERT_PER_TURN)


## The Building that received BP this turn, or "" (p.97: one per campaign turn).
func building_invested_this_turn(campaign: Resource) -> String:
	var bd: Dictionary = _get_buildings_data(campaign)
	if int(bd.get("invested_turn", -1)) != _turn(campaign):
		return ""
	return str(bd.get("invested_building", ""))


## The Building reclaimed this turn, or "" (p.98: "reclaim a single building").
func building_reclaimed_this_turn(campaign: Resource) -> String:
	var bd: Dictionary = _get_buildings_data(campaign)
	if int(bd.get("reclaimed_turn", -1)) != _turn(campaign):
		return ""
	return str(bd.get("reclaimed_building", ""))


## Standing benefits a reclaimed Building takes with it. One-time grants (Morale,
## Story Points, Augmentation Points, the Integrity raise, a Milestone) were spent when
## it was built and stay; Roster slots are summed over the constructed list, so they
## leave on their own.
const STANDING_EFFECTS := {
	"colony_defenses": "colony_defenses",
	"mitigate_colony_damage": "colony_damage_mitigation",
	"repair_capacity": "repair_capacity",
	"build_points_per_turn": "build_points_per_turn",
	"research_points_per_turn": "research_points_per_turn"}


func reclaim_building(
		campaign: Resource, building_id: String) -> Dictionary:
	## Destroy a building, receive half BP cost (rounded down) as Raw Materials.
	if not is_constructed(campaign, building_id):
		return {"success": false, "error": "Not constructed"}
	var already: String = building_reclaimed_this_turn(campaign)
	if already != "":
		return {"success": false, "error": "%s was already reclaimed this turn (p.98)." % str(
				get_building(already).get("name", already))}
	var building: Dictionary = get_building(building_id)
	var rm_gained: int = building.get("bp_cost", 0) / 2

	var bd: Dictionary = _get_buildings_data(campaign)
	var constructed: Array = bd.get("constructed", [])
	constructed.erase(building_id)
	bd["constructed"] = constructed
	bd["reclaimed_turn"] = _turn(campaign)
	bd["reclaimed_building"] = building_id
	_set_buildings_data(campaign, bd)

	# "The building is destroyed": a destroyed Heavy Construction Site kept paying +1 BP
	# every turn, and a destroyed shield kept its Defenses.
	var effect: Dictionary = building.get("effect", {})
	for key in STANDING_EFFECTS:
		var field: String = STANDING_EFFECTS[key]
		if effect.has(key) and field in campaign:
			campaign.set(field, maxi(int(campaign.get(field)) - int(effect[key]), 0))

	if campaign.has_method("add_raw_materials"):
		campaign.add_raw_materials(rm_gained)

	return {"success": true, "raw_materials_gained": rm_gained}


## Why a Building cannot be started yet, in the book's terms; "" when it can.
func locked_reason(campaign: Resource, building: Dictionary,
		research_system: RefCounted) -> String:
	var needs: Array[String] = []
	var app: Dictionary = research_system.application_for_building(
			str(building.get("id", ""))) \
			if research_system and research_system.has_method("application_for_building") \
			else {}
	if not app.is_empty() and not research_system.is_application_unlocked(
			campaign, str(app.get("id", ""))):
		needs.append("the %s Application (%s research, p.93)" % [
				str(app.get("name", "")), str(app.get("theory_name", ""))])
	var prereq: String = str(building.get("prerequisite", "")) \
			if building.get("prerequisite") != null else ""
	if prereq.ends_with("_built") and not is_constructed(campaign, prereq.trim_suffix("_built")):
		needs.append("the %s built" % str(
				get_building(prereq.trim_suffix("_built")).get("name", prereq)))
	if needs.is_empty() and not _check_prerequisite(campaign, building, research_system):
		needs.append(prereq.replace("_", " ").capitalize())
	return "" if needs.is_empty() else "Needs %s." % " and ".join(needs)


static func _turn(campaign: Resource) -> int:
	return int(campaign.campaign_turn) if campaign and "campaign_turn" in campaign else 0


## ============================================================================
## PRIVATE
## ============================================================================

func _complete_building(
		campaign: Resource,
		building_id: String,
		bd: Dictionary) -> void:
	if not bd.has("constructed"):
		bd["constructed"] = []
	bd["constructed"].append(building_id)

	# Apply building effects
	var building: Dictionary = get_building(building_id)
	var effect: Dictionary = building.get("effect", {})
	_apply_building_effect(campaign, effect)


func _apply_building_effect(
		campaign: Resource, effect: Dictionary) -> void:
	if effect.is_empty() or not campaign:
		return
	# p.87: an Integrity BONUS raises the maximum with the current score.
	if effect.has("colony_integrity") and campaign.has_method("raise_integrity"):
		campaign.raise_integrity(effect.get("colony_integrity", 0))
	if effect.has("colony_morale") and campaign.has_method("adjust_morale"):
		campaign.adjust_morale(effect.get("colony_morale", 0))
	if effect.has("colony_defenses") and "colony_defenses" in campaign:
		campaign.colony_defenses += effect.get("colony_defenses", 0)
	# Colony Shield Network (p.87 mitigation). Read by take_colony_damage(); this key
	# had no reader until 2026-10-27, so the building did nothing.
	if effect.has("mitigate_colony_damage") and "colony_damage_mitigation" in campaign:
		campaign.colony_damage_mitigation += int(effect.get("mitigate_colony_damage", 0))
	if effect.has("repair_capacity") and "repair_capacity" in campaign:
		campaign.repair_capacity += effect.get("repair_capacity", 0)
	if effect.has("build_points_per_turn") and "build_points_per_turn" in campaign:
		campaign.build_points_per_turn += effect.get("build_points_per_turn", 0)
	if effect.has("research_points_per_turn") and "research_points_per_turn" in campaign:
		campaign.research_points_per_turn += effect.get("research_points_per_turn", 0)
	if effect.has("story_points") and campaign.has_method("add_story_points"):
		campaign.add_story_points(effect.get("story_points", 0))
	if effect.has("augmentation_points") and "augmentation_points" in campaign:
		campaign.augmentation_points += effect.get("augmentation_points", 0)
	# A "milestone" effect is NOT granted here: PlanetfallMilestoneSystem grants it once,
	# with its effects, when Step 15 completes (p.156). Counting it here as well made one
	# building worth two Milestones, the first with no effects at all.
	# "roster_slots" (p.100) is not applied here either: PlanetfallRosterRules
	# .roster_capacity() sums it over the constructed buildings, so a save that built the
	# facility while this branch was a bare `pass` gets its slots without a migration.


func _check_prerequisite(
		campaign: Resource,
		building: Dictionary,
		research_system: RefCounted) -> bool:
	var prereq: Variant = building.get("prerequisite")
	if prereq == null or (prereq is String and prereq.is_empty()):
		return true

	var prereq_str: String = str(prereq)

	# p.93: "(Building) allows a new building to be constructed", and p.98 lists the
	# "prerequisite research applications that must have been completed". The table's
	# column prints the Theory the Application sits under, and a completed Theory alone
	# used to open EVERY Building in its field, Milestone Buildings included, skipping the
	# random Application draw. A Building that an Application unlocks needs that
	# Application; p.100's High-tech plant also needs the Advanced Manufacturing Plant.
	if research_system and research_system.has_method("application_for_building"):
		var app: Dictionary = research_system.application_for_building(
				str(building.get("id", "")))
		if not app.is_empty():
			if not research_system.is_application_unlocked(campaign, str(app.get("id", ""))):
				return false
			if not prereq_str.ends_with("_built"):
				return true

	# Special case: "advanced_manufacturing_plant_built" means the building
	if prereq_str.ends_with("_built"):
		var building_id: String = prereq_str.replace("_built", "")
		return is_constructed(campaign, building_id)

	# Check if it's a completed research theory
	if research_system and research_system.has_method("is_theory_researched"):
		return research_system.is_theory_researched(campaign, prereq_str)

	# Fallback: check unlocked applications
	var rd: Dictionary = _get_research_data(campaign)
	var completed: Array = rd.get("completed_theories", [])
	return completed.has(prereq_str)


func _get_buildings_data(campaign: Resource) -> Dictionary:
	if not campaign or not "buildings_data" in campaign:
		return {}
	return campaign.buildings_data


func _set_buildings_data(
		campaign: Resource, data: Dictionary) -> void:
	if campaign and "buildings_data" in campaign:
		campaign.buildings_data = data


func _get_research_data(campaign: Resource) -> Dictionary:
	if not campaign or not "research_data" in campaign:
		return {}
	return campaign.research_data


func is_loaded() -> bool:
	return _loaded
