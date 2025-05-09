@tool
extends "res://tests/fixtures/base/game_test.gd"

const CampaignManagerScript = preload("res://src/core/managers/CampaignManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const StoryQuestDataScript = preload("res://src/core/story/StoryQuestData.gd")

var _campaign_manager = null # Use explicit null to prevent type inference issues
var _test_campaign_data = null # Use explicit null to prevent type inference issues
var _received_signals = [] # Track received signals for validation

# Lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Reset signal tracking
	_received_signals.clear()
	
	# Create campaign manager with proper null checks
	_campaign_manager = CampaignManagerScript.new()
	if not is_instance_valid(_campaign_manager):
		push_error("Failed to create campaign manager")
		pending("Campaign manager could not be created")
		return
		
	add_child(_campaign_manager)
	track_test_node(_campaign_manager)
	
	# Connect signals from campaign manager
	if _campaign_manager.has_signal("campaign_initialized"):
		_campaign_manager.campaign_initialized.connect(_on_campaign_initialized)
	if _campaign_manager.has_signal("campaign_saved"):
		_campaign_manager.campaign_saved.connect(_on_campaign_saved)
	
	# Create test campaign data with explicit types
	_test_campaign_data = {
		"campaign_name": "Test Campaign",
		"campaign_id": "test_123"
	}
	
	await get_tree().process_frame
	
	# Use type-safe signal watching
	if _signal_watcher:
		_signal_watcher.watch_signals(_campaign_manager)

# Signal handlers
func _on_campaign_initialized(data) -> void:
	_received_signals.append("campaign_initialized")

func _on_campaign_saved(data) -> void:
	_received_signals.append("campaign_saved")

func after_each() -> void:
	# Disconnect signals
	if is_instance_valid(_campaign_manager):
		if _campaign_manager.has_signal("campaign_initialized"):
			if _campaign_manager.is_connected("campaign_initialized", _on_campaign_initialized):
				_campaign_manager.campaign_initialized.disconnect(_on_campaign_initialized)
				
		if _campaign_manager.has_signal("campaign_saved"):
			if _campaign_manager.is_connected("campaign_saved", _on_campaign_saved):
				_campaign_manager.campaign_saved.disconnect(_on_campaign_saved)
		
		_campaign_manager.queue_free()
	
	_campaign_manager = null
	_test_campaign_data = null
	_received_signals.clear()
	
	await super.after_each()

# Helper for validating signal sequence
func verify_signal_sequence(received_signals: Array, expected_signals: Array, strict_order: bool = true) -> bool:
	# Check that we received enough signals
	if received_signals.size() < expected_signals.size():
		assert_false(true, "Not enough signals received. Expected %d but got %d" %
			[expected_signals.size(), received_signals.size()])
		return false
	
	# For strict order, check each position
	if strict_order:
		for i in range(expected_signals.size()):
			if i >= received_signals.size():
				assert_false(true, "Missing signal at position %d: %s" % [i, expected_signals[i]])
				return false
				
			if received_signals[i] != expected_signals[i]:
				assert_false(true, "Signal mismatch at position %d. Expected '%s' but got '%s'" %
					[i, expected_signals[i], received_signals[i]])
				return false
	# For non-strict order, just check that all expected signals exist
	else:
		for expected in expected_signals:
			if not expected in received_signals:
				assert_false(true, "Expected signal '%s' was not emitted" % expected)
				return false
	
	return true

# Tests for state loading
func test_safe_state_loading() -> void:
	if not is_instance_valid(_campaign_manager):
		push_warning("Skipping test_safe_state_loading: _campaign_manager is null or invalid")
		pending("Test skipped - _campaign_manager is null or invalid")
		return
		
	if not _campaign_manager.has_method("load_state"):
		push_warning("Skipping test_safe_state_loading: load_state method not found")
		pending("Test skipped - load_state method not found")
		return
		
	# Test loading with null state
	var result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "load_state", [null], false)
	
	assert_false(result, "Should return false when loading null state")
	
	# Test loading with invalid state data
	var invalid_data = {"invalid": "data"}
	result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "load_state", [invalid_data], false)
	
	assert_false(result, "Should return false when loading invalid state")
	
	# Test loading with valid state
	var valid_data = _test_campaign_data
	result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "load_state", [valid_data], false)
	
	assert_true(result, "Should return true when loading valid state")

# Tests for campaign initialization
func test_campaign_initialization() -> void:
	if not is_instance_valid(_campaign_manager):
		push_warning("Skipping test_campaign_initialization: _campaign_manager is null or invalid")
		pending("Test skipped - _campaign_manager is null or invalid")
		return
		
	if not (_campaign_manager.has_method("initialize_campaign") and
			_campaign_manager.has_signal("campaign_initialized")):
		push_warning("Skipping test_campaign_initialization: required methods or signals not found")
		pending("Test skipped - required methods or signals not found")
		return
		
	# Reset signal tracking
	_received_signals.clear()
	
	# Initialize with null data
	var result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "initialize_campaign", [null], false)
	
	assert_false(result, "Should return false when initializing with null data")
	assert_false("campaign_initialized" in _received_signals, "Signal should not be emitted with null data")
	
	# Initialize with valid data
	result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "initialize_campaign", [_test_campaign_data], false)
	
	assert_true(result, "Should return true when initializing with valid data")
	assert_true("campaign_initialized" in _received_signals, "Signal should be emitted with valid data")
	
	if not "current_campaign" in _campaign_manager:
		push_warning("Skipping current_campaign check: property not found")
		pending("Test skipped - current_campaign property not found")
		return
		
	var campaign_name = TypeSafeMixin._get_property_safe(_campaign_manager.current_campaign, "campaign_name", "")
	assert_eq(campaign_name, "Test Campaign", "Campaign data should be correctly initialized")

# Tests for campaign saving
func test_campaign_saving() -> void:
	if not is_instance_valid(_campaign_manager):
		push_warning("Skipping test_campaign_saving: _campaign_manager is null or invalid")
		pending("Test skipped - _campaign_manager is null or invalid")
		return
		
	if not (_campaign_manager.has_method("initialize_campaign") and
			_campaign_manager.has_method("save_campaign") and
			_campaign_manager.has_signal("campaign_saved")):
		push_warning("Skipping test_campaign_saving: required methods or signals not found")
		pending("Test skipped - required methods or signals not found")
		return
		
	# Reset signal tracking
	_received_signals.clear()
	
	# Initialize campaign
	TypeSafeMixin._call_node_method_bool(_campaign_manager, "initialize_campaign", [_test_campaign_data], false)
	
	# Try to save campaign
	var result = TypeSafeMixin._call_node_method_bool(_campaign_manager, "save_campaign", [], false)
	
	assert_true(result, "Should return true when saving campaign")
	assert_true("campaign_saved" in _received_signals, "Signal should be emitted when saving")
	
	# Verify save data parameters only if the signal was actually emitted
	if _signal_watcher.was_signal_emitted(_campaign_manager, "campaign_saved"):
		var save_params = _signal_watcher.get_signal_parameters(_campaign_manager, "campaign_saved")
		if save_params and save_params.size() > 0 and save_params[0] != null:
			var campaign_name = TypeSafeMixin._get_property_safe(save_params[0], "campaign_name", "")
			assert_eq(campaign_name, "Test Campaign", "Save data should contain correct campaign name")

# Tests for error handling
func test_error_handling() -> void:
	if not is_instance_valid(_campaign_manager):
		push_warning("Skipping test_error_handling: _campaign_manager is null or invalid")
		pending("Test skipped - _campaign_manager is null or invalid")
		return
		
	if not (_campaign_manager.has_method("get_last_error") and
			_campaign_manager.has_method("clear_errors")):
		push_warning("Skipping test_error_handling: required methods not found")
		pending("Test skipped - required methods or signals not found")
		return
		
	# Force an error
	if _campaign_manager.has_method("load_state"):
		TypeSafeMixin._call_node_method(_campaign_manager, "load_state", [null])
	
	# Check error state using type-safe access
	var error = TypeSafeMixin._call_node_method(_campaign_manager, "get_last_error")
	assert_not_null(error, "Error should be recorded after failed operation")
	
	# Clear errors
	TypeSafeMixin._call_node_method(_campaign_manager, "clear_errors")
	error = TypeSafeMixin._call_node_method(_campaign_manager, "get_last_error")
	assert_null(error, "Error should be cleared after clear_errors call")

# Tests for resource cleanup
func test_campaign_cleanup() -> void:
	if not is_instance_valid(_campaign_manager):
		push_warning("Skipping test_campaign_cleanup: _campaign_manager is null or invalid")
		pending("Test skipped - _campaign_manager is null or invalid")
		return
		
	if not (_campaign_manager.has_method("initialize_campaign") and
			_campaign_manager.has_method("cleanup")):
		push_warning("Skipping test_campaign_cleanup: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	# Initialize campaign
	TypeSafeMixin._call_node_method_bool(_campaign_manager, "initialize_campaign", [_test_campaign_data], false)
	
	# Clean up
	TypeSafeMixin._call_node_method(_campaign_manager, "cleanup")
	
	if not "current_campaign" in _campaign_manager:
		push_warning("Skipping current_campaign check: property not found")
		pending("Test skipped - current_campaign property not found")
		return
		
	assert_null(_campaign_manager.current_campaign, "Current campaign should be null after cleanup")