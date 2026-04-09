class_name PlanetfallPostMissionSystem
extends RefCounted

## Processes Post-Mission Finds, Alien Artifact distribution, and campaign
## factor resolution after completing missions.
## Source: Planetfall pp.134-136

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


func apply_find_to_campaign(campaign: Resource, find: Dictionary) -> void:
	## Apply the reward from a Post-Mission Find to campaign state.
	if not campaign:
		return
	var reward: Dictionary = find.get("reward", {})

	if reward.has("research_points"):
		var rd: Dictionary = campaign.research_data if "research_data" in campaign else {}
		rd["current_rp"] = rd.get("current_rp", 0) + reward["research_points"]
		if "research_data" in campaign:
			campaign.research_data = rd

	if reward.has("build_points"):
		var bd: Dictionary = campaign.buildings_data if "buildings_data" in campaign else {}
		bd["current_bp"] = bd.get("current_bp", 0) + reward["build_points"]
		if "buildings_data" in campaign:
			campaign.buildings_data = bd

	if reward.has("raw_materials") and campaign.has_method("add_raw_materials"):
		campaign.add_raw_materials(reward["raw_materials"])

	if reward.has("story_points") and campaign.has_method("add_story_points"):
		campaign.add_story_points(reward["story_points"])

	if reward.has("colony_morale") and campaign.has_method("adjust_morale"):
		campaign.adjust_morale(reward["colony_morale"])

	if reward.has("ancient_signs") and "ancient_signs" in campaign:
		for _i in range(reward["ancient_signs"]):
			campaign.ancient_signs.append({})

	# Apply bonuses
	for bonus_entry in find.get("applied_bonuses", []):
		var bonus: Dictionary = bonus_entry.get("bonus", {})
		if bonus.has("research_points"):
			var rd2: Dictionary = campaign.research_data if "research_data" in campaign else {}
			rd2["current_rp"] = rd2.get("current_rp", 0) + bonus["research_points"]
		if bonus.has("raw_materials") and campaign.has_method("add_raw_materials"):
			campaign.add_raw_materials(bonus["raw_materials"])


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
## CAMPAIGN FACTORS
## ============================================================================

func process_campaign_factors(campaign: Resource, mission_id: String,
		battle_result: Dictionary) -> Dictionary:
	## Apply post-mission campaign state changes based on mission type and result.
	## Returns a summary of all changes made.
	var changes: Dictionary = {"applied": []}

	if not campaign:
		return changes

	var won: bool = battle_result.get("won", false)

	match mission_id:
		"exploration":
			# Roll D6 per objective: 1=Hazard+1, 2=nothing, 3-6=Resource-1
			var objectives_completed: int = battle_result.get("objectives_completed", 0)
			var sector_id: String = battle_result.get("sector_id", "")
			changes["exploration_results"] = []
			for _i in range(objectives_completed):
				var obj_roll: int = roll_d6()
				changes["exploration_results"].append({"roll": obj_roll})

		"scouting":
			# Sector becomes Explored. Resource = 2D6 pick lowest. Hazard = 2D6 pick lowest.
			if won:
				var r1: int = roll_d6()
				var r2: int = roll_d6()
				var resource_level: int = mini(r1, r2)
				var h1: int = roll_d6()
				var h2: int = roll_d6()
				var hazard_level: int = mini(h1, h2)
				changes["sector_explored"] = true
				changes["resource_level"] = resource_level
				changes["hazard_level"] = hazard_level
				changes["applied"].append("Sector explored: Resource %d, Hazard %d" % [resource_level, hazard_level])

		"science":
			# Resource -1 if any samples collected
			var samples: int = battle_result.get("samples_collected", 0)
			if samples > 0:
				changes["resource_reduction"] = 1
				changes["applied"].append("Sector Resource value reduced by 1.")

		"hunt":
			# If sector has Hazard, D6 on 5-6 reduce by 1
			var hazard_roll: int = roll_d6()
			if hazard_roll >= 5:
				changes["hazard_reduction"] = 1
				changes["applied"].append("Sector Hazard reduced by 1.")

		"skirmish":
			# Both objectives = enemy no longer occupies sector
			var both_done: bool = battle_result.get("both_objectives", false)
			if both_done:
				changes["enemy_sector_cleared"] = true
				changes["applied"].append("Enemy no longer occupies this sector.")

		"rescue":
			# -1 Morale per colonist not saved. Squad casualties don't affect Morale.
			var colonists_lost: int = battle_result.get("colonists_lost", 0)
			if colonists_lost > 0 and campaign.has_method("adjust_morale"):
				campaign.adjust_morale(-colonists_lost)
				changes["morale_loss"] = colonists_lost
				changes["applied"].append("Lost %d Colony Morale (colonists not saved)." % colonists_lost)

		"scout_down":
			# Non-roster scout saved = +1 Morale. Sector may become Explored.
			var scout_saved: bool = battle_result.get("scout_saved", false)
			var is_roster_scout: bool = battle_result.get("is_roster_scout", false)
			if scout_saved and not is_roster_scout:
				if campaign.has_method("adjust_morale"):
					campaign.adjust_morale(1)
				changes["morale_gain"] = 1
				changes["applied"].append("+1 Colony Morale (scout rescued).")

		"pitched_battle":
			# Win = +1 XP per survivor. Loss = D100 Campaign Consequences.
			if won:
				changes["survivor_xp"] = 1
				changes["applied"].append("+1 XP to each survivor.")

		"assault":
			# Win = enemy eliminated from campaign, roll Resource/Hazard for sector
			if won:
				changes["enemy_eliminated"] = true
				changes["applied"].append("Enemy eliminated from campaign. All sectors relinquished.")

	return changes


func process_enemy_info_gain(campaign: Resource, enemy_index: int,
		gained: int) -> Dictionary:
	## Increment enemy info counter. Check boss_located and strongpoint_located.
	## Returns status dict.
	if not campaign or not campaign.has_method("increment_enemy_info"):
		return {}

	campaign.increment_enemy_info(enemy_index, gained)
	var total: int = campaign.get_enemy_info_count(enemy_index)

	var status: Dictionary = {
		"enemy_index": enemy_index,
		"total_info": total,
		"boss_located": false,
		"strongpoint_located": false
	}

	# Check thresholds on the tactical enemy
	if "tactical_enemies" in campaign and enemy_index < campaign.tactical_enemies.size():
		var enemy: Variant = campaign.tactical_enemies[enemy_index]
		if enemy is Dictionary:
			# Boss located after Strike mission with sufficient info
			if total >= 3 and not enemy.get("boss_located", false):
				enemy["boss_located"] = true
				status["boss_located"] = true

	return status


## ============================================================================
## DICE HELPERS
## ============================================================================

func roll_d100() -> int:
	return randi_range(1, 100)


func roll_d6() -> int:
	return randi_range(1, 6)


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
