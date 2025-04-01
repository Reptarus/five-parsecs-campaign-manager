@tool
extends "res://addons/gut/test.gd"

## Campaign Test Base Class
## This is a simple base class for campaign tests without dependencies

# Import GameEnums directly
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Campaign test configuration
const CAMPAIGN_TEST_CONFIG = {
	"stabilize_time": 0.2,
	"save_timeout": 2.0,
	"load_timeout": 2.0,
	"phase_timeout": 1.0
}

# Test campaign values
var _test_campaign_name = "Test Campaign"
var _test_difficulty_level = GameEnums.DifficultyLevel.NORMAL
var _test_credits = 1000
var _test_supplies = 5
var _game_state = null

# Helper methods
func stabilize_engine(time: float = 0.0):
	await get_tree().process_frame
	await get_tree().process_frame
	
	if time > 0:
		await get_tree().create_timer(time).timeout

# Safety utility to verify signal sequences without risking array out of bounds
func verify_signal_sequence(received_signals: Array, expected_signals: Array, strict_order: bool = true) -> bool:
	# Log signals for debugging
	print("Verifying signals. Received: ", received_signals, " Expected: ", expected_signals)
	
	# First check: do we have enough signals?
	var has_enough_signals = received_signals.size() >= expected_signals.size()
	assert_true(has_enough_signals,
		"Expected at least %d signals, but got %d: %s" % [
			expected_signals.size(),
			received_signals.size(),
			received_signals
		])
	
	if not has_enough_signals:
		return false
	
	# Second check: are all expected signals present?
	var all_present = true
	var missing_signals = []
	
	for expected in expected_signals:
		if not received_signals.has(expected):
			all_present = false
			missing_signals.append(expected)
	
	assert_true(all_present,
		"All expected signals should be present. Missing: %s" % missing_signals)
	
	# Third check: if strict order is required, verify order
	if strict_order and all_present:
		var correct_order = true
		var previous_index = -1
		
		for expected in expected_signals:
			var current_index = received_signals.find(expected)
			
			if current_index < previous_index:
				correct_order = false
				break
				
			previous_index = current_index
		
		assert_true(correct_order,
			"Signals should be received in the expected order: %s vs %s" % [
				expected_signals,
				received_signals
			])
		
		return correct_order
	
	return all_present
	
func track_test_node(node):
	if node != null and node is Node:
		if not has_node(node.get_path()):
			add_child(node)
	
func track_test_resource(_resource):
	# Nothing to do for resources in this simplified version
	pass
	
func track_node_count(label):
	print("[%s] Node count: %d" % [label, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])

# The missing function that's causing the error
func create_test_game_state() -> Node:
	# Try to load the GameState script
	var game_state_script = load("res://src/core/state/GameState.gd")
	if not game_state_script:
		push_error("Could not load GameState script")
		return null
		
	# Create a new instance
	var state_instance = game_state_script.new()
	if not state_instance:
		push_error("Failed to create GameState instance")
		return null
		
	# Return the created state
	return state_instance
	
# Add helper for loading test campaign
func load_test_campaign(state: Node) -> void:
	if not state:
		push_error("Cannot load campaign: game state is null")
		return
		
	var campaign_resource = Resource.new()
	
	# Create a script for the campaign
	var compatibility = GutCompatibility.new()
	var script = compatibility.create_script()
	
	script.source_code = """
extends Resource

var campaign_id = "test_campaign_" + str(randi())
var campaign_name = "Test Campaign"
var difficulty = 1
var credits = 1000
var supplies = 5
var turn = 1
var phase = 0

signal campaign_state_changed(property)

func initialize_from_data(data = {}):
	if data.has("campaign_id"):
		campaign_id = data.campaign_id
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("credits"):
		credits = data.credits
	if data.has("supplies"):
		supplies = data.supplies
	return true
"""
	script.reload()
	
	# Apply the script to the resource
	campaign_resource.set_script(script)
	
	# Set the campaign on the state
	if state.has_method("set_current_campaign"):
		state.set_current_campaign(campaign_resource)
	elif "current_campaign" in state:
		state.current_campaign = campaign_resource
	
# Simple test function to verify the script works
func test_script_loads():
	assert_true(true, "Script loaded successfully")

# Assert valid game state function
func assert_valid_game_state(state: Node) -> void:
	assert_not_null(state, "Game state should not be null")
	
	# Check for current campaign
	var has_campaign = false
	if state.has_method("get_current_campaign"):
		has_campaign = state.get_current_campaign() != null
	elif "current_campaign" in state:
		has_campaign = state.current_campaign != null
	
	assert_true(has_campaign, "Game state should have a current campaign")