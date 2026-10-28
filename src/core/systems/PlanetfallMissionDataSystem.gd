class_name PlanetfallMissionDataSystem
extends RefCounted

## Manages Mission Data accumulation and the 4 sequential Breakthroughs.
## Mission Data is noted as it arrives and checked at each Campaign Milestone (see
## note()/receive() for the p.68 / p.169 conflict): roll 1D6, if roll <= total MD, a
## breakthrough occurs (subtract roll from total). The 4th breakthrough triggers a D100
## roll on the Final Breakthrough table. After that, MD no longer has value.
## Source: Planetfall pp.169-172

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")

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
	var roll: int = _d6("Planetfall Mission Data")
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
			"count": effects["ancient_sites"],
			"md_per_site": int(effects.get("md_per_site_explored", 0))
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
		# pp.161-163 name the Breakthrough an End Game bonus needs, so WHICH one was
		# rolled is campaign state, not only that a fourth happened.
		if "final_breakthrough" in campaign:
			campaign.final_breakthrough = str(entry.get("id", ""))
		var effects: Dictionary = entry.get("immediate_effect", {})

		if effects.has("story_points") and campaign.has_method("add_story_points"):
			campaign.add_story_points(int(effects["story_points"]))

		# "add 2 XP to three characters of your choice" / "Select three characters on your
		# roster and raise their Reaction scores by +1": the player picks, so queue them.
		if effects.has("character_xp") and campaign.has_method("queue_character_award"):
			campaign.queue_character_award("xp", int(effects["character_xp"]),
					int(effects.get("character_xp_count", 1)), str(entry.get("name", "")))
		if effects.has("character_reaction_bonus") \
				and campaign.has_method("queue_character_award"):
			campaign.queue_character_award("reactions", int(effects["character_reaction_bonus"]),
					int(effects.get("character_reaction_count", 1)), str(entry.get("name", "")))

		if effects.has("research_points"):
			if campaign.has_method("earn_research_points"):
				campaign.earn_research_points(int(effects["research_points"]))
			else:
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

		# "sleepers_lose_save" (Defense Network) is read off campaign.final_breakthrough.
		# It was a set_meta() flag, which no save carries and nothing read.

		if effects.has("reduce_all_hazard_levels"):
			result["actions_needed"] = result.get("actions_needed", [])
			result["actions_needed"].append({
				"action": "reduce_all_hazard_levels",
				"amount": effects["reduce_all_hazard_levels"]
			})

	return result


## ============================================================================
## RECEIVE — the one way Mission Data enters a campaign
## ============================================================================

## WHEN the check is made is a book conflict, resolved for the procedural pages. p.169
## says "Each time you received Mission Data, process it". The turn sequence says
## otherwise: p.68 Step 12, "If you obtained any Mission Data, note it on your roster. It
## is resolved when you reach a Campaign Milestone (see page 156)", and every p.156-158
## Milestone reads "Add N points of Mission Data and check for Mission Data progress".
## Two procedural pages agree, so (the 75-credit precedent) Mission Data from a mission, a
## Building, an Artifact or a Site is NOTED, and the check is made at a Milestone.
##
## note(): add Mission Data without the check (p.68). Returns the lines.
func note(campaign: Resource, amount: int, source: String = "") -> Array:
	if campaign == null or amount <= 0:
		return []
	var made: int = int(campaign.mission_data_breakthroughs) \
			if "mission_data_breakthroughs" in campaign else 0
	if made >= 4:
		return ["Mission Data no longer has any value (all four Breakthroughs made) (p.169)"]
	if campaign.has_method("add_mission_data_points"):
		campaign.add_mission_data_points(amount)
	var total: int = int(campaign.mission_data) if "mission_data" in campaign else amount
	return ["+%d Mission Data%s, %d noted; it is checked at the next Campaign Milestone (p.68)."
			% [amount, " (%s)" % source if source != "" else "", total]]


## receive(): a Milestone's "Add N points of Mission Data and check" (p.156). Adds `amount`,
## makes the p.169 check, and carries a Breakthrough through to the map and the Final
## table. Returns the lines to show.
func receive(campaign: Resource, amount: int, source: String = "") -> Array:
	if campaign == null or amount <= 0:
		return []
	var outcome: Dictionary = add_and_check(campaign, amount)
	# No roll means nothing was added: after the Fourth "Mission Data no longer has any
	# value" (p.169).
	if not outcome.has("roll"):
		return ["Mission Data no longer has any value (all four Breakthroughs made) (p.169)"]
	var lines: Array = ["+%d Mission Data%s" % [amount, " (%s)" % source if source != "" else ""]]
	if not bool(outcome.get("breakthrough", false)):
		lines.append("No Mission Data Breakthrough: 1D6 %d against %d (p.169)." % [
				int(outcome.roll), int(outcome.get("md_total", 0))])
		return lines
	var bt: Dictionary = outcome.get("result", {})
	lines.append("Mission Data Breakthrough %d: 1D6 %d, %d Mission Data left. %s (p.169)" % [
			int(outcome.get("breakthrough_index", 0)), int(outcome.roll),
			int(outcome.get("md_remaining", 0)), str(bt.get("name", ""))])
	var actions: Array = []
	for needed in bt.get("actions_needed", []):
		if not needed is Dictionary:
			continue
		if needed.get("action", "") == "roll_final_breakthrough":
			var roll: int = _d100("Planetfall Final Breakthrough")
			var last: Dictionary = roll_final_breakthrough(campaign, roll)
			lines.append("Final Breakthrough, D100 %d: %s (p.169)" % [roll, str(last.get("name", ""))])
			actions.append_array(last.get("actions_needed", []))
		else:
			actions.append(needed)
	lines.append_array(MapScript.apply_breakthrough_actions(campaign, actions))
	if campaign.has_method("queue_character_award") and "pending_character_awards" in campaign \
			and not campaign.pending_character_awards.is_empty():
		lines.append("Choose the characters for the Breakthrough's award.")
	return lines


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


## Through DiceManager so the QA seam can arm the p.169 check ("Planetfall Mission Data").
static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


func is_loaded() -> bool:
	return _loaded
