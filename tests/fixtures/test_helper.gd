@tool
class_name TestHelper
extends RefCounted

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Resource Creation
static func create_test_mission(mission_type: int = GameEnums.MissionType.NONE) -> Resource:
	var mission = load("res://src/core/story/StoryQuestData.gd").new()
	mission.configure(mission_type, {})
	return mission

static func create_test_character(armor_class: int = GameEnums.ArmorClass.NONE) -> Resource:
	var character = load("res://src/core/character/Character.gd").new()
	character.initialize(armor_class)
	return character

static func create_test_item(weapon_type: int = GameEnums.WeaponType.NONE) -> Resource:
	var item = load("res://src/core/items/Item.gd").new()
	item.initialize(weapon_type)
	return item

# State Setup
static func setup_test_game_state() -> Dictionary:
	return {
		"campaign_turn": 1,
		"story_points": 0,
		"credits": 1000,
		"resources": {
			GameEnums.ResourceType.FUEL: 10,
			GameEnums.ResourceType.MEDICAL_SUPPLIES: 5,
			GameEnums.ResourceType.WEAPONS: 20
		},
		"crew": [],
		"missions": [],
		"items": []
	}

static func setup_test_campaign_state() -> Dictionary:
	return {
		"campaign_name": "Test Campaign",
		"current_phase": GameEnums.CampaignPhase.SETUP,
		"phase_history": [],
		"active_missions": [],
		"completed_missions": [],
		"mission_history": []
	}

# Data Generation
static func generate_test_mission_data(count: int = 1) -> Array[Dictionary]:
	var missions: Array[Dictionary] = []
	for i in range(count):
		missions.append({
			"mission_id": "TEST_MISSION_%d" % i,
			"mission_type": GameEnums.MissionType.PATROL,
			"name": "Test Mission %d" % i,
			"description": "Test mission description %d" % i,
			"objectives": ["Objective 1", "Objective 2"],
			"rewards": {
				"credits": 100,
				"reputation": 1,
				"items": []
			}
		})
	return missions

static func generate_test_character_data(count: int = 1) -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	for i in range(count):
		characters.append({
			"character_id": "TEST_CHAR_%d" % i,
			"name": "Test Character %d" % i,
			"armor_class": GameEnums.ArmorClass.LIGHT,
			"level": 1,
			"experience": 0,
			"skills": [],
			"equipment": []
		})
	return characters

# Validation Helpers
static func validate_mission_data(mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	if not mission.has("mission_id"):
		errors.append("Missing mission_id")
	if not mission.has("mission_type"):
		errors.append("Missing mission_type")
	if not mission.has("name"):
		errors.append("Missing name")
	if not mission.has("description"):
		errors.append("Missing description")
	if not mission.has("objectives") or not mission.objectives is Array:
		errors.append("Invalid or missing objectives")
	if not mission.has("rewards") or not mission.rewards is Dictionary:
		errors.append("Invalid or missing rewards")
		
	return errors

static func validate_character_data(character: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	if not character.has("character_id"):
		errors.append("Missing character_id")
	if not character.has("name"):
		errors.append("Missing name")
	if not character.has("armor_class"):
		errors.append("Missing armor_class")
	if not character.has("level") or character.level < 1:
		errors.append("Invalid or missing level")
	if not character.has("skills") or not character.skills is Array:
		errors.append("Invalid or missing skills")
	if not character.has("equipment") or not character.equipment is Array:
		errors.append("Invalid or missing equipment")
		
	return errors

# Performance Helpers
static func measure_execution_time(callable: Callable) -> float:
	var start_time := Time.get_ticks_msec()
	callable.call()
	return (Time.get_ticks_msec() - start_time) / 1000.0

static func measure_memory_usage(callable: Callable) -> int:
	var start_memory := OS.get_static_memory_usage()
	callable.call()
	return OS.get_static_memory_usage() - start_memory

# Signal Helpers
static func wait_for_signal(object: Object, signal_name: String, timeout: float = 5.0) -> bool:
	var start_time := Time.get_ticks_msec()
	var signal_received := false
	
	object.connect(signal_name, func(): signal_received = true)
	
	while not signal_received and (Time.get_ticks_msec() - start_time) < (timeout * 1000):
		await Engine.get_main_loop().process_frame
	
	return signal_received

# File Helpers
static func create_test_save_data() -> Dictionary:
	return {
		"version": "1.0.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": setup_test_game_state(),
		"campaign_state": setup_test_campaign_state(),
		"characters": generate_test_character_data(2),
		"missions": generate_test_mission_data(2)
	}

static func cleanup_test_files(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("test_"):
				dir.remove(file_name)
			file_name = dir.get_next()