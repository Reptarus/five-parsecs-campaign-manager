## Campaign State Test Suite
## Tests the functionality of the game state management specifically for campaigns,
## including initialization, loading, and settings management.
@tool
extends CampaignTest

# Type-safe script references
const Campaign := preload("res://src/core/campaign/Campaign.gd")

# Type-safe instance variables
var _campaign_state: Node = null

## Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	_campaign_state = create_test_game_state()
	if not _campaign_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_campaign_state)
	await stabilize_engine()

func after_each() -> void:
	_campaign_state = null
	await super.after_each()

## Initial State Tests
func test_initial_state() -> void:
	assert_not_null(_campaign_state, "Game state should be initialized")
	
	var has_campaign: bool = TypeSafeMixin._call_node_method_bool(_campaign_state, "has_active_campaign", [])
	var credits: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	var reputation: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	
	assert_false(has_campaign, "Should start with no active campaign")
	assert_eq(credits, 0, "Should start with 0 credits")
	assert_eq(reputation, 0, "Should start with 0 reputation")

## Campaign Management Tests
func test_campaign_loading() -> void:
	watch_signals(_campaign_state)
	
	var campaign: Resource = TypeSafeMixin._safe_cast_to_resource(Campaign.new(), "")
	if not campaign:
		push_error("Failed to create campaign")
		return
	track_test_resource(campaign)
	
	TypeSafeMixin._call_node_method_bool(campaign, "set_campaign_name", ["Test Campaign"])
	TypeSafeMixin._call_node_method_bool(campaign, "set_difficulty", [GameEnums.DifficultyLevel.NORMAL])
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "set_active_campaign", [campaign])
	
	var has_campaign: bool = TypeSafeMixin._call_node_method_bool(_campaign_state, "has_active_campaign", [])
	var active_campaign: Resource = TypeSafeMixin._safe_cast_to_resource(TypeSafeMixin._call_node_method(_campaign_state, "get_active_campaign", []), "")
	var campaign_name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(active_campaign, "get_campaign_name", []))
	
	assert_true(has_campaign, "Campaign should be loaded")
	assert_eq(campaign_name, "Test Campaign", "Campaign name should match")
	verify_signal_emitted(_campaign_state, "campaign_changed")

## Game Settings Tests
func test_game_settings() -> void:
	watch_signals(_campaign_state)
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "set_difficulty_level", [GameEnums.DifficultyLevel.HARD])
	var difficulty: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_difficulty_level", [])
	assert_eq(difficulty, GameEnums.DifficultyLevel.HARD, "Difficulty should be HARD")
	verify_signal_emitted(_campaign_state, "difficulty_changed")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "set_permadeath_enabled", [false])
	var permadeath: bool = TypeSafeMixin._call_node_method_bool(_campaign_state, "is_permadeath_enabled", [])
	assert_false(permadeath, "Permadeath should be disabled")
	verify_signal_emitted(_campaign_state, "settings_changed")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "set_story_track_enabled", [false])
	var story_track: bool = TypeSafeMixin._call_node_method_bool(_campaign_state, "is_story_track_enabled", [])
	assert_false(story_track, "Story track should be disabled")
	verify_signal_emitted(_campaign_state, "settings_changed")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "set_auto_save_enabled", [false])
	var auto_save: bool = TypeSafeMixin._call_node_method_bool(_campaign_state, "is_auto_save_enabled", [])
	assert_false(auto_save, "Auto save should be disabled")
	verify_signal_emitted(_campaign_state, "settings_changed")
