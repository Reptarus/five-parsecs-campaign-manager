extends "res://tests/fixtures/base_test.gd"

# Game-specific test functionality
class_name GameTest

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const Campaign = preload("res://src/core/campaign/Campaign.gd")

# Game state setup
func setup_game_state() -> FiveParsecsGameState:
	var state = FiveParsecsGameState.new()
	track_test_node(state)
	
	# Initialize state properties
	state.credits = 1000
	state.difficulty_level = GameEnums.DifficultyLevel.NORMAL
	state.enable_permadeath = true
	state.use_story_track = true
	state.auto_save_enabled = true
	
	return state

# Character setup
func setup_test_character(name: String = "Test Character") -> Character:
	var character = Character.new()
	track_test_resource(character)
	
	# Set basic info
	character.character_name = name
	character.character_class = GameEnums.CharacterClass.SOLDIER
	character.origin = GameEnums.Origin.HUMAN
	character.background = GameEnums.Background.MILITARY
	character.motivation = GameEnums.Motivation.GLORY
	
	# Set base stats
	character.level = 1
	character.experience = 0
	character.health = 10
	character.max_health = 10
	
	return character

# Campaign setup
func setup_test_campaign() -> Campaign:
	var campaign = Campaign.new()
	track_test_resource(campaign)
	
	campaign.campaign_name = "Test Campaign"
	campaign.starting_credits = 1000
	campaign.starting_reputation = 0
	
	return campaign

# Game-specific assertions
func assert_valid_game_state(state: FiveParsecsGameState) -> void:
	assert_node_valid(state)
	assert_has_method(state, "save")
	assert_has_method(state, "load")

func assert_valid_character(character: Character) -> void:
	assert_resource_valid(character)
	assert_true(character.character_name.length() > 0, "Character should have a name")
	assert_true(character.character_class in GameEnums.CharacterClass.values(), "Character should have valid class")
	assert_true(character.origin in GameEnums.Origin.values(), "Character should have valid origin")

func assert_valid_campaign(campaign: Campaign) -> void:
	assert_resource_valid(campaign)
	assert_true(campaign.campaign_name.length() > 0, "Campaign should have a name")
	assert_true(campaign.starting_credits >= 0, "Campaign should have valid starting credits")

# Game-specific utilities
func simulate_combat_round() -> void:
	await wait_frames(2) # Give time for combat calculations

func simulate_campaign_turn() -> void:
	await wait_frames(2) # Give time for turn processing