class_name PlanetfallPostMissionSystem
extends RefCounted

## Processes Post-Mission Finds and Alien Artifact distribution after missions.
## Source: Planetfall pp.134-136. Campaign Factors live in PlanetfallMap.

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")

var _finds: Array = []
var _artifacts: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	var finds_data: Dictionary = _load_json(
		"res://data/planetfall/post_mission_finds.json")
	_finds = finds_data.get("entries", [])

	var artifacts_data: Dictionary = _load_json(
		"res://data/planetfall/artifacts.json")
	_artifacts = artifacts_data.get("entries", [])

	_loaded = not _finds.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallPostMissionSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallPostMissionSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## POST-MISSION FINDS (D100)
## ============================================================================

func roll_find(roll: int) -> Dictionary:
	## D100 lookup on Post-Mission Finds table.
	return _lookup_d100(_finds, roll)


func roll_find_with_bonuses(roll: int, has_scientist: bool, has_scout: bool) -> Dictionary:
	## Roll a find and include any scientist/scout bonuses.
	var find: Dictionary = roll_find(roll)
	if find.is_empty():
		return find

	var result: Dictionary = find.duplicate(true)
	var bonuses: Array = []

	if has_scientist and find.has("scientist_bonus"):
		bonuses.append({"source": "scientist", "bonus": find["scientist_bonus"]})
	if has_scout and find.has("scout_bonus"):
		bonuses.append({"source": "scout", "bonus": find["scout_bonus"]})

	result["applied_bonuses"] = bonuses
	return result


func apply_find_to_campaign(campaign: Resource, find: Dictionary) -> Array:
	## Apply the reward from a Post-Mission Find to campaign state. Returns the lines only
	## the application can know (an Ancient Sign's roll).
	var lines: Array = []
	if not campaign:
		return lines
	var reward: Dictionary = find.get("reward", {})

	# One Find is one source. p.90: in a Crisis "every RP/BP/RM source gives 1 point
	# less", so a Find's reward and its scientist/scout bonus are totalled per currency
	# and reduced ONCE. These were written straight into the dictionaries before
	# 2026-10-27, so a Crisis never reduced a Find; raw materials were reduced twice.
	var rp: int = int(reward.get("research_points", 0))
	var bp: int = int(reward.get("build_points", 0))
	var rm: int = int(reward.get("raw_materials", 0))
	for bonus_entry in find.get("applied_bonuses", []):
		var bonus: Dictionary = bonus_entry.get("bonus", {})
		rp += int(bonus.get("research_points", 0))
		rm += int(bonus.get("raw_materials", 0))
	var adjust := func(amount: int) -> int:
		return campaign.crisis_adjusted_gain(amount) \
				if amount > 0 and campaign.has_method("crisis_adjusted_gain") else amount

	if rp > 0 and "research_data" in campaign:
		# Through the core so p.63's wasted points come off it.
		if campaign.has_method("earn_research_points"):
			campaign.earn_research_points(adjust.call(rp))
		else:
			var rd: Dictionary = campaign.research_data
			rd["current_rp"] = int(rd.get("current_rp", 0)) + adjust.call(rp)

	if bp > 0 and "buildings_data" in campaign:
		var bd: Dictionary = campaign.buildings_data
		bd["current_bp"] = int(bd.get("current_bp", 0)) + adjust.call(bp)

	# add_raw_materials applies the Crisis point itself, once per call.
	if rm > 0 and campaign.has_method("add_raw_materials"):
		campaign.add_raw_materials(rm)

	if reward.has("story_points") and campaign.has_method("add_story_points"):
		campaign.add_story_points(reward["story_points"])

	if reward.has("colony_morale") and campaign.has_method("adjust_morale"):
		campaign.adjust_morale(reward["colony_morale"])

	# p.61: each Sign obtained is tested for an Ancient Site at once. These were appended
	# as {} with no roll until 2026-10-28, so a Find never located a Site.
	if reward.has("ancient_signs"):
		lines.append_array(MapScript.obtain_ancient_signs(campaign, int(reward["ancient_signs"])))
	return lines


## ============================================================================
## ALIEN ARTIFACTS (D100)
## ============================================================================

func roll_artifact(roll: int, found_artifact_ids: Array) -> Dictionary:
	## D100 lookup on Artifacts table. If artifact already found, take next
	## available entry (wrap around). Returns artifact entry.
	var initial: Dictionary = _lookup_d100(_artifacts, roll)
	if initial.is_empty():
		return {}

	# Check if already found — if so, find next available
	if initial.get("id", "") in found_artifact_ids:
		return _find_next_available_artifact(initial, found_artifact_ids)

	return initial


func apply_artifact_to_campaign(campaign: Resource, artifact: Dictionary) -> bool:
	## Add artifact to campaign. Returns false if already found.
	if not campaign or not campaign.has_method("add_artifact"):
		return false
	return campaign.add_artifact(artifact)


func get_artifact_by_id(artifact_id: String) -> Dictionary:
	## Look up a specific artifact by ID.
	for artifact in _artifacts:
		if artifact is Dictionary and artifact.get("id", "") == artifact_id:
			return artifact.duplicate(true)
	return {}


func get_all_artifacts() -> Array:
	return _artifacts.duplicate(true)


## ============================================================================
## DICE HELPERS
## ============================================================================

## Through DiceManager so the QA seam can force a Find; these were raw randi_range()
## until 2026-10-27. RefCounted, so the autoload is reached through the main loop (a
## bare get_node_or_null("/root/...") here ERRORS and aborts the roll).
func roll_d100(context: String = "Planetfall Post-Mission Find") -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


func roll_d6(context: String = "Planetfall D6") -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


## ============================================================================
## PRIVATE
## ============================================================================

func _find_next_available_artifact(initial: Dictionary, found_ids: Array) -> Dictionary:
	## Find the next available artifact after the initial one, wrapping around.
	var start_index: int = -1
	for i in range(_artifacts.size()):
		if _artifacts[i] is Dictionary and _artifacts[i].get("id", "") == initial.get("id", ""):
			start_index = i
			break

	if start_index < 0:
		return {}

	# Search forward from start, wrapping
	for offset in range(1, _artifacts.size()):
		var idx: int = (start_index + offset) % _artifacts.size()
		var candidate: Variant = _artifacts[idx]
		if candidate is Dictionary and candidate.get("id", "") not in found_ids:
			return candidate.duplicate()

	# All artifacts found
	return {}


func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
