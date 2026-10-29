class_name PlanetfallMissionSetup
extends RefCounted

## The Planetfall mission briefings (mission_types.json) and the Slyn and Sleeper
## profiles PlanetfallBattleGuide builds a battle's opposition from.
## Source: Planetfall pp.114-133, 152-155
##
## ⚠ 2026-10-28: twelve functions with no caller were deleted. Mission availability is
## PlanetfallMap.mission_availability(), the mission screen's own rule; the objective
## tables and the Sleeper's weapon die are rolled by PlanetfallBattleGuide through
## DiceManager. The deleted copies rolled raw randi_range.

var _missions: Array = []
var _slyn_profile: Dictionary = {}
var _sleeper_profile: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var mission_data: Dictionary = _load_json(
		"res://data/planetfall/mission_types.json")
	_missions = mission_data.get("missions", [])

	_slyn_profile = _load_json("res://data/planetfall/slyn_profile.json")
	_sleeper_profile = _load_json("res://data/planetfall/sleeper_profile.json")

	_loaded = not _missions.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallMissionSetup: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallMissionSetup: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## MISSION BRIEFING
## ============================================================================

func get_mission_briefing(mission_id: String) -> Dictionary:
	## Returns the full mission entry for the given ID, including all briefing
	## data (table_size, player_forces, opposition, objectives, rewards, etc.).
	for mission in _missions:
		if mission is Dictionary and mission.get("id", "") == mission_id:
			return mission.duplicate(true)
	return {}


## ============================================================================
## SLYN AGGRESSION CHECK
## ============================================================================

func check_slyn_aggression(mission_id: String, roll_2d6: int) -> bool:
	## Check if the Slyn attack during this mission type.
	## Returns true if Slyn are attacking.
	var briefing: Dictionary = get_mission_briefing(mission_id)
	var opposition: Dictionary = briefing.get("opposition", {})
	var aggression: Variant = opposition.get("slyn_aggression", null)
	if aggression is Dictionary:
		var range_min: int = aggression.get("slyn_range_min", 0)
		var range_max: int = aggression.get("slyn_range_max", 0)
		return roll_2d6 >= range_min and roll_2d6 <= range_max
	return false


## ============================================================================
## PROFILES
## ============================================================================

func get_slyn_profile() -> Dictionary:
	return _slyn_profile.duplicate(true)


func get_slyn_combat_profile() -> Dictionary:
	return _slyn_profile.get("profile", {}).duplicate(true)


func get_slyn_encounter_size(roll_d6: int) -> int:
	var sizes: Dictionary = _slyn_profile.get("encounter_sizes", {})
	var entries: Array = sizes.get("entries", [])
	for entry in entries:
		if entry is Dictionary:
			if roll_d6 >= entry.get("min", 0) and roll_d6 <= entry.get("max", 0):
				return entry.get("count", 6)
	return 6


func get_sleeper_profile() -> Dictionary:
	return _sleeper_profile.duplicate(true)


func is_loaded() -> bool:
	return _loaded
