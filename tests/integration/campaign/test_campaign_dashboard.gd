@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const CampaignDashboard: GDScript = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")

# Remove duplicated enums since they're already in parent class
# const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
# const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Type-safe instance variables
var _dashboard: Control
var _mock_game_state: Node

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	_mock_game_state = GameState.new()
	add_child(_mock_game_state)
	track_test_node(_mock_game_state)
	
	_dashboard = Control.new()
	_dashboard.set_script(CampaignDashboard)
	add_child(_dashboard)
	track_test_node(_dashboard)
	
	await get_tree().process_frame

func after_each() -> void:
	_dashboard = null
	_mock_game_state = null
	await super.after_each()

# Basic tests
func test_dashboard_initialization() -> void:
	assert_not_null(_dashboard, "Dashboard should be initialized")

# Test campaign data display
func test_campaign_data_display() -> void:
	# Test code would go here
	pass