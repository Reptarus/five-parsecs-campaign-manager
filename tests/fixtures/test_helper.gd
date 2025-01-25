@tool
extends RefCounted

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const FiveParcsecsCampaign := preload("res://src/core/campaign/Campaign.gd")

# Default test data
const DEFAULT_GAME_STATE := {
	"difficulty_level": GameEnums.DifficultyLevel.NORMAL,
	"enable_permadeath": true,
	"use_story_track": true,
	"auto_save_enabled": true,
	"last_save_time": 0
}

const DEFAULT_CHARACTER := {
	"name": "Test Character",
	"background": GameEnums.Background.MILITARY,
	"motivation": GameEnums.Motivation.REVENGE,
	"level": 1,
	"experience": 0,
	"health": 10,
	"max_health": 10
}

const DEFAULT_CAMPAIGN := {
	"name": "Test Campaign",
	"difficulty": GameEnums.DifficultyLevel.NORMAL,
	"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
	"crew_size": GameEnums.CrewSize.FOUR,
	"use_story_track": true,
	"current_phase": GameEnums.FiveParcsecsCampaignPhase.SETUP,
	"turn": 1,
	"credits": 1000
}

# Game state setup
static func setup_test_game_state(config: Dictionary = {}) -> Dictionary:
	var state = DEFAULT_GAME_STATE.duplicate(true)
	state.merge(config)
	
	# Add campaign if not explicitly disabled
	if not config.has("skip_campaign"):
		state["campaign"] = setup_test_campaign(config.get("campaign", {}))
	
	return state

# Campaign setup
static func setup_test_campaign(config: Dictionary = {}) -> Dictionary:
	var campaign = DEFAULT_CAMPAIGN.duplicate(true)
	campaign.merge(config)
	
	# Add default crew if not disabled
	if not config.has("skip_crew"):
		campaign["crew"] = []
		for i in range(campaign.crew_size):
			campaign.crew.append(setup_test_character({
				"name": "Crew Member %d" % (i + 1)
			}))
	
	return campaign

# Character setup
static func setup_test_character(config: Dictionary = {}) -> Dictionary:
	var character = DEFAULT_CHARACTER.duplicate(true)
	character.merge(config)
	return character

# Create actual character instance
static func create_test_character(config: Dictionary = {}) -> Resource:
	var data = setup_test_character(config)
	var character = Character.new()
	
	for key in data:
		if character.has_method("set_" + key):
			character.call("set_" + key, data[key])
		else:
			character[key] = data[key]
	
	return character

# Create actual campaign instance
static func create_test_campaign(config: Dictionary = {}) -> Resource:
	var data = setup_test_campaign(config)
	var campaign = FiveParcsecsCampaign.new()
	
	for key in data:
		if campaign.has_method("set_" + key):
			campaign.call("set_" + key, data[key])
		else:
			campaign[key] = data[key]
	
	return campaign

# Combat setup helpers
static func setup_test_combat_state(config: Dictionary = {}) -> Dictionary:
	return {
		"turn": config.get("turn", 1),
		"phase": config.get("phase", GameEnums.BattlePhase.SETUP),
		"active_character": config.get("active_character", null),
		"characters": config.get("characters", []),
		"terrain": config.get("terrain", []),
		"objectives": config.get("objectives", [])
	}

# Mission setup helpers
static func setup_test_mission(config: Dictionary = {}) -> Dictionary:
	return {
		"type": config.get("type", GameEnums.MissionType.PATROL),
		"difficulty": config.get("difficulty", GameEnums.DifficultyLevel.NORMAL),
		"objectives": config.get("objectives", []),
		"rewards": config.get("rewards", []),
		"enemies": config.get("enemies", []),
		"terrain": config.get("terrain", [])
	}

# Resource generation helpers
static func generate_test_resources(amount: int = 1000) -> Dictionary:
	return {
		"credits": amount,
		"items": [],
		"equipment": []
	}

# State verification helpers
static func verify_campaign_state(campaign: Resource, expected: Dictionary) -> bool:
	for key in expected:
		if campaign.has_method("get_" + key):
			if campaign.call("get_" + key) != expected[key]:
				return false
		elif campaign[key] != expected[key]:
			return false
	return true

static func verify_character_state(character: Resource, expected: Dictionary) -> bool:
	for key in expected:
		if character.has_method("get_" + key):
			if character.call("get_" + key) != expected[key]:
				return false
		elif character[key] != expected[key]:
			return false
	return true
