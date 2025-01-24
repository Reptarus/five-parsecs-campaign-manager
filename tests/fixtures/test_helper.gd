@tool
class_name TestHelper
extends RefCounted

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Resource Creation
static func create_test_mission(mission_type: int = GameEnums.MissionType.PATROL) -> Resource:
	var mission = load("res://src/core/story/StoryQuestData.gd").new()
	mission.configure(mission_type, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1,
		"victory_type": GameEnums.MissionVictoryType.ELIMINATION
	})
	return mission

static func create_test_character(armor_class: int = GameEnums.ArmorClass.LIGHT) -> Resource:
	var character = load("res://src/core/character/Base/Character.gd").new()
	character.character_name = "Test Character"
	character.character_class = GameEnums.CharacterClass.SOLDIER
	character.origin = GameEnums.Origin.CORE_WORLDS
	character.background = GameEnums.Background.MILITARY
	character.motivation = GameEnums.Motivation.REVENGE
	character.training = GameEnums.Training.PILOT
	character.status = GameEnums.CharacterStatus.HEALTHY
	character.is_human = true
	return character

static func create_test_item(weapon_type: int = GameEnums.WeaponType.NONE) -> Resource:
	var item = load("res://src/core/items/Item.gd").new()
	item.initialize(weapon_type)
	return item

# State Setup
static func setup_test_game_state() -> Dictionary:
	return {
		"campaign": setup_test_campaign_state(),
		"campaign_turn": 1,
		"credits": 1000,
		"reputation": 0,
		"last_save_time": Time.get_unix_time_from_system(),
		"difficulty_level": GameEnums.DifficultyLevel.NORMAL,
		"enable_permadeath": true,
		"use_story_track": true,
		"auto_save_enabled": true
	}

static func setup_test_campaign_state() -> Dictionary:
	var test_characters = generate_test_character_data(3) # Create 3 crew members
	var captain_data = generate_test_character_data(1)[0] # Create a captain
	captain_data.character_name = "Test Captain"
	captain_data.character_class = GameEnums.CharacterClass.SOLDIER
	captain_data.training = GameEnums.Training.PILOT
	
	return {
		"campaign_name": "Test Campaign",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"current_phase": GameEnums.CampaignPhase.SETUP,
		"campaign_turn": 1,
		"crew_members": test_characters,
		"captain": captain_data,
		"resources": {
			GameEnums.ResourceType.CREDITS: 1000,
			GameEnums.ResourceType.SUPPLIES: 5,
			GameEnums.ResourceType.FUEL: 10,
			GameEnums.ResourceType.MEDICAL_SUPPLIES: 5,
			GameEnums.ResourceType.TECH_PARTS: 0,
			GameEnums.ResourceType.STORY_POINT: 0
		},
		"story_points": 0,
		"completed_missions": [],
		"available_missions": [],
		"faction_standings": {},
		"game_state": GameEnums.GameState.CAMPAIGN
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
			"difficulty": GameEnums.DifficultyLevel.NORMAL,
			"victory_type": GameEnums.MissionVictoryType.ELIMINATION,
			"objectives": [
				{
					"type": GameEnums.MissionObjective.PATROL,
					"description": "Patrol the area",
					"required": true,
					"completed": false
				}
			],
			"rewards": {
				"credits": 100,
				"reputation": 1,
				"items": []
			},
			"required_resources": {
				GameEnums.ResourceType.SUPPLIES: 5,
				GameEnums.ResourceType.FUEL: 2
			}
		})
	return missions

static func generate_test_character_data(count: int = 1) -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	for i in range(count):
		characters.append({
			"character_name": "Test Character %d" % i,
			"character_class": GameEnums.CharacterClass.SOLDIER,
			"origin": GameEnums.Origin.CORE_WORLDS,
			"background": GameEnums.Background.MILITARY,
			"motivation": GameEnums.Motivation.REVENGE,
			"level": 1,
			"experience": 0,
			"health": 10,
			"max_health": 10,
			"reaction": 2,
			"combat": 2,
			"toughness": 2,
			"savvy": 2,
			"luck": 1,
			"weapons": [],
			"armor": [],
			"items": [],
			"skills": [],
			"abilities": [],
			"traits": [],
			"training": GameEnums.Training.PILOT,
			"status": GameEnums.CharacterStatus.HEALTHY,
			"is_active": true,
			"is_wounded": false,
			"is_dead": false,
			"status_effects": [],
			"is_bot": false,
			"is_soulless": false,
			"is_human": true
		})
	return characters

# Validation Helpers
static func validate_mission_data(mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	var required_fields = [
		"mission_id",
		"mission_type",
		"name",
		"description",
		"difficulty",
		"victory_type",
		"objectives",
		"rewards",
		"required_resources"
	]
	
	for field in required_fields:
		if not mission.has(field):
			errors.append("Missing required field: " + field)
	
	if mission.has("objectives"):
		if not mission.objectives is Array:
			errors.append("Objectives must be an array")
		else:
			for objective in mission.objectives:
				if not objective is Dictionary:
					errors.append("Each objective must be a dictionary")
				elif not objective.has_all(["type", "description", "required", "completed"]):
					errors.append("Objective missing required fields")
	
	return errors

static func validate_character_data(character: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	# Required fields for all characters
	var required_fields = [
		"character_name",
		"character_class",
		"origin",
		"background",
		"motivation",
		"level",
		"experience",
		"health",
		"max_health",
		"reaction",
		"combat",
		"toughness",
		"savvy",
		"luck",
		"is_active",
		"is_wounded",
		"is_dead",
		"is_human",
		"is_bot",
		"is_soulless",
		"training"
	]
	
	for field in required_fields:
		if not character.has(field):
			errors.append("Missing required field: " + field)
	
	# Validate arrays
	var array_fields = ["weapons", "armor", "items", "skills", "abilities", "traits", "status_effects"]
	for field in array_fields:
		if not character.has(field) or not character[field] is Array:
			errors.append("Invalid or missing array field: " + field)
	
	# Validate numeric ranges
	if character.has("level") and (character.level < 1 or character.level > 10):
		errors.append("Level must be between 1 and 10")
	
	if character.has("experience") and character.experience < 0:
		errors.append("Experience cannot be negative")
	
	if character.has("health") and character.health < 0:
		errors.append("Health cannot be negative")
	
	if character.has("max_health") and character.max_health < 1:
		errors.append("Max health must be positive")
	
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
