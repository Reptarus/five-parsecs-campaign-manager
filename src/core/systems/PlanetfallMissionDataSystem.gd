class_name PlanetfallMissionDataSystem
extends RefCounted

## Manages Mission Data accumulation and the 4 sequential Breakthroughs.
## Each time MD is gained: roll 1D6, if roll <= total MD, breakthrough occurs
## (subtract roll from total). The 4th breakthrough triggers a D100 roll on
## the Final Breakthrough table. After that, MD no longer has value.
## Source: Planetfall pp.169-172

var _breakthroughs: Array = []
var _final_table: Array = []
var _check_mechanic: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var data: Dictionary = _load_json(
		"res://data/planetfall/mission_data_breakthroughs.json")
	_breakthroughs = data.get("breakthroughs", [])
	_check_mechanic = data.get("check_mechanic", {})

	var final_data: Dictionary = data.get("final_breakthrough_table", {})
	_final_table = final_data.get("entries", [])

	_loaded = not _breakthroughs.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallMissionDataSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallMissionDataSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## ADD AND CHECK
## ============================================================================

func add_and_check(campaign: Resource, amount: int) -> Dictionary:
	## Add Mission Data, then check for breakthrough.
	## Returns {breakthrough: bool, breakthrough_index: int, result: Dictionary}.
	if not campaign:
		return {"breakthrough": false}

	# Check if MD still has value
	var current_breakthroughs: int = campaign.mission_data_breakthroughs if "mission_data_breakthroughs" in campaign else 0
	if current_breakthroughs >= 4:
		return {"breakthrough": false, "note": "Mission Data no longer has value."}

	# Add MD
	if campaign.has_method("add_mission_data_points"):
		campaign.add_mission_data_points(amount)
	elif "mission_data" in campaign:
		campaign.mission_data += amount

	var total: int = campaign.mission_data if "mission_data" in campaign else 0

	# Check: roll 1D6, if roll <= total MD, breakthrough occurs
	var roll: int = randi_range(1, 6)
	if roll <= total:
		# Breakthrough! Subtract roll from total
		if "mission_data" in campaign:
			campaign.mission_data -= roll
		if "mission_data_breakthroughs" in campaign:
			campaign.mission_data_breakthroughs += 1

		var new_index: int = campaign.mission_data_breakthroughs
		var bt_result: Dictionary = process_breakthrough(campaign, new_index)

		return {
			"breakthrough": true,
			"breakthrough_index": new_index,
			"roll": roll,
			"md_remaining": campaign.mission_data,
			"result": bt_result
		}

	return {
		"breakthrough": false,
		"roll": roll,
		"md_total": total,
		"note": "D6 roll %d > MD total %d — no breakthrough." % [roll, total]
	}


## ============================================================================
## BREAKTHROUGH PROCESSING
## ============================================================================

func process_breakthrough(campaign: Resource, breakthrough_index: int) -> Dictionary:
	## Apply the effects of a breakthrough (1-4).
	## Returns the breakthrough data + any actions needed.
	if breakthrough_index < 1 or breakthrough_index > 4:
		return {}

	# Find breakthrough entry
	var bt_entry: Dictionary = {}
	for bt in _breakthroughs:
		if bt is Dictionary and bt.get("index", 0) == breakthrough_index:
			bt_entry = bt.duplicate(true)
			break

	if bt_entry.is_empty():
		return {}

	var result: Dictionary = {
		"name": bt_entry.get("name", ""),
		"description": bt_entry.get("description", ""),
		"effects": bt_entry.get("effect", {}),
		"actions_needed": []
	}

	var effects: Dictionary = bt_entry.get("effect", {})

	# Apply immediate effects
	if effects.has("ancient_sites"):
		result["actions_needed"].append({
			"action": "place_ancient_sites",
			"count": effects["ancient_sites"]
		})

	if effects.has("explore_sectors"):
		result["actions_needed"].append({
			"action": "explore_random_sectors",
			"count": effects["explore_sectors"],
			"resource_bonus": effects.get("resource_bonus", 0)
		})

	if effects.has("investigation_sectors"):
		result["actions_needed"].append({
			"action": "mark_investigation_sectors",
			"count": effects["investigation_sectors"]
		})

	if effects.get("roll_final_table", false):
		result["actions_needed"].append({
			"action": "roll_final_breakthrough"
		})

	return result


func roll_final_breakthrough(campaign: Resource, roll: int) -> Dictionary:
	## D100 roll on the 4th (final) breakthrough table.
	## Returns the result entry with immediate effects and endgame bonus.
	var entry: Dictionary = _lookup_d100(_final_table, roll)
	if entry.is_empty():
		return {}

	var result: Dictionary = entry.duplicate(true)

	# Apply immediate effects to campaign
	if campaign:
		var effects: Dictionary = entry.get("immediate_effect", {})

		if effects.has("story_points") and campaign.has_method("add_story_points"):
			campaign.add_story_points(effects["story_points"])

		if effects.has("research_points"):
			var rd: Dictionary = campaign.research_data if "research_data" in campaign else {}
			rd["current_rp"] = rd.get("current_rp", 0) + effects["research_points"]

		if effects.has("build_points"):
			var bd: Dictionary = campaign.buildings_data if "buildings_data" in campaign else {}
			bd["current_bp"] = bd.get("current_bp", 0) + effects["build_points"]

		if effects.has("build_points_per_turn") and "build_points_per_turn" in campaign:
			campaign.build_points_per_turn += effects["build_points_per_turn"]

		if effects.has("augmentation_points") and "augmentation_points" in campaign:
			campaign.augmentation_points += effects["augmentation_points"]

		if effects.has("grunts") and campaign.has_method("gain_grunts"):
			campaign.gain_grunts(effects["grunts"])

		if effects.has("ancient_sites"):
			result["actions_needed"] = [{"action": "place_ancient_sites", "count": effects["ancient_sites"]}]

		if effects.has("sleepers_lose_save"):
			# Store flag on campaign for battle phase to read
			if "progression" in campaign or true:
				campaign.set_meta("sleepers_lose_save", true)

		if effects.has("reduce_all_hazard_levels"):
			result["actions_needed"] = result.get("actions_needed", [])
			result["actions_needed"].append({
				"action": "reduce_all_hazard_levels",
				"amount": effects["reduce_all_hazard_levels"]
			})

	return result


## ============================================================================
## PROGRESS QUERY
## ============================================================================

func get_progress(campaign: Resource) -> Dictionary:
	if not campaign:
		return {}
	return {
		"mission_data": campaign.mission_data if "mission_data" in campaign else 0,
		"breakthroughs": campaign.mission_data_breakthroughs if "mission_data_breakthroughs" in campaign else 0,
		"md_valuable": (campaign.mission_data_breakthroughs if "mission_data_breakthroughs" in campaign else 0) < 4
	}


## ============================================================================
## PRIVATE
## ============================================================================

func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
