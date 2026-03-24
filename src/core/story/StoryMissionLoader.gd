class_name FPCM_StoryMissionLoader
extends RefCounted

## Story Mission Loader - Loads and validates story track mission JSON files
## Converts JSON to game-compatible mission data structures
## Implements caching for performance

const STORY_MISSIONS_PATH := "res://data/story_track_missions/"
const MISSION_FILE_PREFIX := "mission_"
const MISSION_FILE_SUFFIX := ".json"

## Cache for loaded missions
var _mission_cache: Dictionary = {}
var _validation_errors: Array[String] = []

## Mission file mapping (event_id -> filename)
const EVENT_TO_FILE_MAP := {
	"discovery_signal": "mission_01_discovery",
	"first_contact": "mission_02_contact",
	"conspiracy_revealed": "mission_03_conspiracy",
	"personal_connection": "mission_04_personal",
	"hunt_begins": "mission_05_hunt",
	"final_confrontation": "mission_06_confrontation"
}

## Load a story mission by its event ID
func load_story_mission(event_id: String) -> Dictionary:
	# Check cache first
	if _mission_cache.has(event_id):
		return _mission_cache[event_id]

	# Get file path
	var file_name: String = EVENT_TO_FILE_MAP.get(event_id, "")
	if file_name.is_empty():
		push_error("StoryMissionLoader: Unknown event_id: %s" % event_id)
		return {}

	var file_path := STORY_MISSIONS_PATH + file_name + MISSION_FILE_SUFFIX

	# Load and parse JSON
	var mission_data := _load_json_file(file_path)
	if mission_data.is_empty():
		push_error("StoryMissionLoader: Failed to load mission file: %s" % file_path)
		return {}

	# Validate mission data
	if not _validate_mission_data(mission_data):
		push_error("StoryMissionLoader: Mission validation failed for %s" % event_id)
		for error in _validation_errors:
			push_error("  - %s" % error)
		return {}

	# Cache the validated mission
	_mission_cache[event_id] = mission_data

	return mission_data

## Load mission by number (1-6)
func load_story_mission_by_number(mission_number: int) -> Dictionary:
	var event_ids := EVENT_TO_FILE_MAP.keys()
	if mission_number < 1 or mission_number > event_ids.size():
		push_error("StoryMissionLoader: Invalid mission number: %d" % mission_number)
		return {}

	var event_id: String = event_ids[mission_number - 1]
	return load_story_mission(event_id)

## Load all story missions
func load_all_story_missions() -> Array[Dictionary]:
	var missions: Array[Dictionary] = []

	for event_id in EVENT_TO_FILE_MAP.keys():
		var mission := load_story_mission(event_id)
		if not mission.is_empty():
			missions.append(mission)

	return missions

## Get the next story mission based on current progress
func get_next_story_mission(current_event_id: String) -> Dictionary:
	var event_ids := EVENT_TO_FILE_MAP.keys()
	var current_index := event_ids.find(current_event_id)

	if current_index == -1:
		# No current mission - start from beginning
		return load_story_mission(event_ids[0])

	var next_index := current_index + 1
	if next_index >= event_ids.size():
		# Story track complete
		return {}

	return load_story_mission(event_ids[next_index])

## Get mission by event ID without loading (check existence)
func has_mission(event_id: String) -> bool:
	return EVENT_TO_FILE_MAP.has(event_id)

## Get total mission count
func get_total_mission_count() -> int:
	return EVENT_TO_FILE_MAP.size()

## Get list of all event IDs in order
func get_event_id_sequence() -> Array[String]:
	var sequence: Array[String] = []
	for event_id in EVENT_TO_FILE_MAP.keys():
		sequence.append(event_id)
	return sequence

## Convert mission data to game Mission resource
func convert_to_mission_resource(mission_data: Dictionary) -> Resource:
	# Try to load the Mission script
	var MissionScript = load("res://src/core/campaign/Mission.gd")
	if not MissionScript:
		push_error("StoryMissionLoader: Could not load Mission.gd")
		return null

	var mission = MissionScript.new()

	# Populate mission from JSON data
	mission.mission_id = mission_data.get("mission_id", "")
	mission.mission_name = mission_data.get("title", "")
	mission.description = mission_data.get("narrative", {}).get("briefing", "")
	mission.mission_type = Mission.MissionType.STORY_MISSION

	# Set story track specific fields
	if mission.has_method("set_story_track_data"):
		mission.set_story_track_data({
			"story_event_id": mission_data.get("story_event_id", ""),
			"mission_number": mission_data.get("mission_number", 0),
			"narrative": mission_data.get("narrative", {}),
			"difficulty_rating": mission_data.get("difficulty_rating", 1)
		})

	return mission

## Private: Load JSON file
func _load_json_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("StoryMissionLoader: Could not open file: %s" % file_path)
		return {}

	var content := file.get_as_text()
	file.close()

	if content.is_empty():
		push_error("StoryMissionLoader: Empty file: %s" % file_path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(content)

	if parse_result != OK:
		push_error("StoryMissionLoader: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return {}

	var data = json.get_data()

	# Post-process: Convert numeric fields from float to int where appropriate
	if data is Dictionary:
		if data.has("mission_number") and data["mission_number"] is float:
			data["mission_number"] = int(data["mission_number"])
		if data.has("difficulty_rating") and data["difficulty_rating"] is float:
			data["difficulty_rating"] = int(data["difficulty_rating"])
		if data.has("recommended_crew_size") and data["recommended_crew_size"] is float:
			data["recommended_crew_size"] = int(data["recommended_crew_size"])
		if data.has("estimated_duration_rounds") and data["estimated_duration_rounds"] is float:
			data["estimated_duration_rounds"] = int(data["estimated_duration_rounds"])

		# Convert battlefield size
		if data.has("battlefield") and data["battlefield"] is Dictionary:
			var bf = data["battlefield"]
			if bf.has("size") and bf["size"] is Dictionary:
				var size = bf["size"]
				if size.has("x") and size["x"] is float:
					size["x"] = int(size["x"])
				if size.has("y") and size["y"] is float:
					size["y"] = int(size["y"])

		# Convert enemy fixed_count
		if data.has("enemies") and data["enemies"] is Dictionary:
			var enemies = data["enemies"]
			if enemies.has("fixed_count") and enemies["fixed_count"] is float:
				enemies["fixed_count"] = int(enemies["fixed_count"])

	return data

## Private: Validate mission data structure
func _validate_mission_data(data: Dictionary) -> bool:
	_validation_errors.clear()

	# Required top-level fields
	var required_fields := ["mission_id", "story_event_id", "title", "mission_number", "battlefield", "enemies", "objectives"]

	for field in required_fields:
		if not data.has(field):
			_validation_errors.append("Missing required field: %s" % field)

	# Validate battlefield structure
	if data.has("battlefield"):
		var bf: Dictionary = data["battlefield"]
		if not bf.has("size") or not bf.has("deployment_zones"):
			_validation_errors.append("Battlefield missing size or deployment_zones")
		if bf.has("size"):
			var size: Dictionary = bf["size"]
			if not size.has("x") or not size.has("y"):
				_validation_errors.append("Battlefield size missing x or y")

	# Validate enemies structure
	if data.has("enemies"):
		var enemies: Dictionary = data["enemies"]
		if not enemies.has("composition") or not enemies.has("fixed_count"):
			_validation_errors.append("Enemies missing composition or fixed_count")

	# Validate objectives structure
	if data.has("objectives"):
		var objectives: Dictionary = data["objectives"]
		if not objectives.has("primary"):
			_validation_errors.append("Objectives missing primary objective")

	# Validate mission number is 1-6
	if data.has("mission_number"):
		var num: int = data["mission_number"]
		if num < 1 or num > 6:
			_validation_errors.append("Mission number must be 1-6, got: %d" % num)

	# Validate difficulty rating is 1-5
	if data.has("difficulty_rating"):
		var diff: int = data["difficulty_rating"]
		if diff < 1 or diff > 5:
			_validation_errors.append("Difficulty rating must be 1-5, got: %d" % diff)

	return _validation_errors.is_empty()

## Get battlefield data from mission
func get_battlefield_data(mission_data: Dictionary) -> Dictionary:
	return mission_data.get("battlefield", {})

## Get enemy composition from mission
func get_enemy_composition(mission_data: Dictionary) -> Dictionary:
	return mission_data.get("enemies", {})

## Get objectives from mission
func get_objectives(mission_data: Dictionary) -> Dictionary:
	return mission_data.get("objectives", {})

## Get narrative text from mission
func get_narrative(mission_data: Dictionary) -> Dictionary:
	return mission_data.get("narrative", {})

## Get rewards from mission
func get_rewards(mission_data: Dictionary) -> Dictionary:
	return mission_data.get("rewards", {})

## Get tutorial hints from mission
func get_tutorial_hints(mission_data: Dictionary) -> Array:
	return mission_data.get("tutorial_hints", [])

## Check if mission is the final story mission
func is_final_mission(mission_data: Dictionary) -> bool:
	return mission_data.get("story_track_completion", {}).get("triggers_completion", false)

## Clear the mission cache (useful for testing/development)
func clear_cache() -> void:
	_mission_cache.clear()

## Get cache status for debugging
func get_cache_status() -> Dictionary:
	return {
		"cached_missions": _mission_cache.keys(),
		"cache_size": _mission_cache.size(),
		"total_missions": EVENT_TO_FILE_MAP.size()
	}
