@tool
extends RefCounted

const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterScript: GDScript = preload("res://src/core/character/Base/Character.gd")
const FiveParcsecsCampaignScript: GDScript = preload("res://src/core/campaign/Campaign.gd")

# Default game state configuration
const DEFAULT_GAME_STATE: Dictionary = {
	"difficulty_level": GameEnumsScript.DifficultyLevel.NORMAL,
	"enable_permadeath": true,
	"use_story_track": true,
	"auto_save_enabled": true,
	"last_save_time": 0
}

const DEFAULT_CHARACTER: Dictionary = {
	"name": "Test Character",
	"background": GameEnumsScript.Background.MILITARY,
	"motivation": GameEnumsScript.Motivation.REVENGE,
	"level": 1,
	"experience": 0,
	"health": 10,
	"max_health": 10
}

const DEFAULT_CAMPAIGN: Dictionary = {
	"name": "Test Campaign",
	"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
	"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
	"crew_size": GameEnumsScript.CrewSize.FOUR,
	"use_story_track": true,
	"current_phase": GameEnumsScript.FiveParsecsCampaignPhase.SETUP,
	"turn": 1,
	"credits": 1000
}

# Setup methods
static func setup_test_game_state(config: Dictionary = {}) -> Dictionary:
	var state = DEFAULT_GAME_STATE.duplicate()
	state.merge(config)
	
	# Add campaign if not skipped
	if not config.has("skip_campaign"):
		state["campaign"] = setup_test_campaign(config.get("campaign", {}))
	
	return state

static func setup_test_campaign(config: Dictionary = {}) -> Dictionary:
	var campaign = DEFAULT_CAMPAIGN.duplicate()
	campaign.merge(config)
	
	# Add crew if not skipped
	if not config.has("skip_crew"):
		campaign["crew"] = []
		for i: int in range(campaign.crew_size):
			campaign.crew.append(setup_test_character({
				"name": "Crew Member %d" % (i + 1)
			}))
	
	return campaign

static func setup_test_character(config: Dictionary = {}) -> Dictionary:
	var character = DEFAULT_CHARACTER.duplicate()
	character.merge(config)
	return character

# Resource creation methods
static func create_test_character(config: Dictionary = {}) -> Resource:
	var data = setup_test_character(config)
	var character = CharacterScript.new()
	if not character:
		return null
	
	for key: String in data:
		var setter = "set_" + key
		if character.has_method(setter):
			character.call(setter, data[key])
		else:
			character.set(key, data[key])
	
	return character

static func create_test_campaign(config: Dictionary = {}) -> Resource:
	var data = setup_test_campaign(config)
	var campaign = FiveParcsecsCampaignScript.new()
	if not campaign:
		return null
	
	for key: String in data:
		var setter = "set_" + key
		if campaign.has_method(setter):
			campaign.call(setter, data[key])
		else:
			campaign.set(key, data[key])
	
	return campaign

# Combat state setup
static func setup_test_combat_state(config: Dictionary = {}) -> Dictionary:
	return {
		"turn": config.get("turn", 1),
		"phase": config.get("phase", GameEnumsScript.BattlePhase.SETUP),
		"active_character": config.get("active_character", null),
		"characters": config.get("characters", []),
		"terrain": config.get("terrain", []),
		"objectives": config.get("objectives", [])
	}

# Mission setup
static func setup_test_mission(config: Dictionary = {}) -> Dictionary:
	return {
		"type": config.get("type", GameEnumsScript.MissionType.PATROL),
		"difficulty": config.get("difficulty", GameEnumsScript.DifficultyLevel.NORMAL),
		"objectives": config.get("objectives", []),
		"rewards": config.get("rewards", []),
		"enemies": config.get("enemies", []),
		"terrain": config.get("terrain", [])
	}

# Resource generation
static func generate_test_resources(amount: int = 1000) -> Dictionary:
	return {
		"credits": amount,
		"items": [],
		"equipment": []
	}

# Verification methods
static func verify_campaign_state(campaign: Resource, expected: Dictionary) -> bool:
	if not campaign:
		return false
	
	for key in expected:
		var getter = "get_" + key
		if campaign.has_method(getter):
			if campaign.call(getter) != expected[key]:
				return false
		elif campaign.get(key) != expected[key]:
			return false
	
	return true

static func verify_character_state(character: Resource, expected: Dictionary) -> bool:
	if not character:
		return false
	
	for key in expected:
		var getter = "get_" + key
		if character.has_method(getter):
			if character.call(getter) != expected[key]:
				return false
		elif character.get(key) != expected[key]:
			return false
	
	return true
