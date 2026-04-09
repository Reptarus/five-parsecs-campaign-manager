class_name PlanetfallCalamitySystem
extends RefCounted

## Manages Calamity generation, ongoing effects, and resolution tracking.
## Same Calamity cannot occur twice (take next entry, wrap around).
## Source: Planetfall pp.165-169

var _calamities: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var data: Dictionary = _load_json("res://data/planetfall/calamities.json")
	_calamities = data.get("entries", [])
	_loaded = not _calamities.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallCalamitySystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallCalamitySystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## CALAMITY GENERATION
## ============================================================================

func trigger_calamity(campaign: Resource, roll: int) -> Dictionary:
	## D100 lookup on Calamity table. If already occurred, take next (wrap).
	## Appends the calamity to campaign.active_calamities.
	## Returns the calamity entry or empty if all 8 have occurred.
	var initial: Dictionary = _lookup_d100(_calamities, roll)
	if initial.is_empty():
		return {}

	# Get list of already-occurred calamity IDs
	var occurred_ids: Array = _get_occurred_calamity_ids(campaign)

	# If this one already occurred, find the next available
	var calamity: Dictionary = initial
	if calamity.get("id", "") in occurred_ids:
		calamity = _find_next_available(initial, occurred_ids)
		if calamity.is_empty():
			return {}  # All 8 have occurred

	# Create active calamity record
	var active_record: Dictionary = {
		"id": calamity.get("id", ""),
		"name": calamity.get("name", ""),
		"description": calamity.get("description", ""),
		"setup": calamity.get("setup", ""),
		"ongoing_effect": calamity.get("ongoing_effect", ""),
		"resolution": calamity.get("resolution", ""),
		"reward": calamity.get("reward", ""),
		"enemy_profile": calamity.get("enemy_profile", {}),
		"resolved": false,
		"progress": {},
		"triggered_turn": campaign.campaign_turn if campaign and "campaign_turn" in campaign else 0
	}

	if campaign and "active_calamities" in campaign:
		campaign.active_calamities.append(active_record)

	return active_record


## ============================================================================
## ACTIVE CALAMITY MANAGEMENT
## ============================================================================

func get_active_calamities(campaign: Resource) -> Array:
	## Returns unresolved calamities.
	if not campaign or not "active_calamities" in campaign:
		return []
	var active: Array = []
	for cal in campaign.active_calamities:
		if cal is Dictionary and not cal.get("resolved", false):
			active.append(cal)
	return active


func get_calamity_count(campaign: Resource) -> int:
	return get_active_calamities(campaign).size()


func process_turn_effects(campaign: Resource) -> Dictionary:
	## Called at start of each turn — apply ongoing effects for all active calamities.
	## Returns summary of effects applied.
	var effects: Dictionary = {"events": []}

	for cal in get_active_calamities(campaign):
		var cal_id: String = cal.get("id", "")
		match cal_id:
			"enemy_super_weapon":
				# Progress 1D6 per turn, launch at 15
				var progress: int = cal.get("progress", {}).get("weapon_progress", 0)
				var roll: int = randi_range(1, 6)
				progress += roll
				if not cal.has("progress") or cal["progress"] is not Dictionary:
					cal["progress"] = {}
				cal["progress"]["weapon_progress"] = progress
				effects["events"].append({
					"calamity": cal_id,
					"description": "Super weapon progress: +%d (total: %d/15)" % [roll, progress]
				})
				if progress >= 15:
					effects["events"].append({
						"calamity": cal_id,
						"description": "WEAPON LAUNCHED! Roll 3D6 for colony damage.",
						"weapon_launched": true
					})
					cal["progress"]["weapon_progress"] = 0

			"virus":
				# Select 3 characters for virus spread
				effects["events"].append({
					"calamity": cal_id,
					"description": "Virus spread check: select 3 characters for testing.",
					"action_needed": "virus_spread"
				})

			"swarm_infestation":
				# Roll spread for adjacent sectors
				effects["events"].append({
					"calamity": cal_id,
					"description": "Swarm spreading: check adjacent sectors.",
					"action_needed": "swarm_spread"
				})

	return effects


func record_resolution_progress(campaign: Resource, calamity_index: int,
		progress: Dictionary) -> Dictionary:
	## Record progress toward resolving a specific calamity.
	## Returns {resolved: bool, reward: String}.
	if not campaign or not "active_calamities" in campaign:
		return {"resolved": false}
	if calamity_index < 0 or calamity_index >= campaign.active_calamities.size():
		return {"resolved": false}

	var cal: Variant = campaign.active_calamities[calamity_index]
	if cal is not Dictionary:
		return {"resolved": false}

	# Merge progress
	if not cal.has("progress") or cal["progress"] is not Dictionary:
		cal["progress"] = {}
	for key in progress:
		cal["progress"][key] = progress[key]

	# Check resolution conditions
	var resolved: bool = check_resolved(campaign, calamity_index)
	if resolved:
		cal["resolved"] = true
		return {"resolved": true, "reward": cal.get("reward", "")}

	return {"resolved": false}


func check_resolved(campaign: Resource, calamity_index: int) -> bool:
	## Check if a specific calamity's resolution conditions are met.
	if not campaign or not "active_calamities" in campaign:
		return false
	if calamity_index < 0 or calamity_index >= campaign.active_calamities.size():
		return false

	var cal: Variant = campaign.active_calamities[calamity_index]
	if cal is not Dictionary:
		return false
	if cal.get("resolved", false):
		return true

	var cal_id: String = cal.get("id", "")
	var progress: Dictionary = cal.get("progress", {})

	match cal_id:
		"slyn_assault":
			return progress.get("slyn_killed", 0) >= 30
		"robot_rampage":
			return progress.get("chips_collected", 0) >= 5
		"mega_predators":
			return progress.get("enhanced_killed", 0) >= 5
		"wildlife_aggression":
			return progress.get("controller_killed", false)
		"virus":
			return progress.get("cure_discovered", false)
		"swarm_infestation":
			return progress.get("all_sectors_cleared", false)
		"environmental_risk":
			return progress.get("all_sectors_cleared", false)
		"enemy_super_weapon":
			return progress.get("weapon_destroyed", false)

	return false


## ============================================================================
## PRIVATE
## ============================================================================

func _get_occurred_calamity_ids(campaign: Resource) -> Array:
	var ids: Array = []
	if campaign and "active_calamities" in campaign:
		for cal in campaign.active_calamities:
			if cal is Dictionary:
				ids.append(cal.get("id", ""))
	return ids


func _find_next_available(initial: Dictionary, occurred_ids: Array) -> Dictionary:
	var start_index: int = -1
	for i in range(_calamities.size()):
		if _calamities[i] is Dictionary and _calamities[i].get("id", "") == initial.get("id", ""):
			start_index = i
			break
	if start_index < 0:
		return {}
	for offset in range(1, _calamities.size()):
		var idx: int = (start_index + offset) % _calamities.size()
		var candidate: Variant = _calamities[idx]
		if candidate is Dictionary and candidate.get("id", "") not in occurred_ids:
			return candidate.duplicate()
	return {}


func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
