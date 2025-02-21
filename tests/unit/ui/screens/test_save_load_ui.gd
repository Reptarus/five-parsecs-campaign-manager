@tool
extends GameTest

const SaveLoadUIScript: GDScript = preload("res://src/ui/screens/SaveLoadUI.gd")

# Type-safe component references
var save_load_ui: Node
var mock_game_state: Node
var save_selected_signal_emitted := false
var load_selected_signal_emitted := false
var cancelled_signal_emitted := false
var last_save_name: String = ""
var last_save_data: Dictionary = {}

# Type-safe test lifecycle
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state with type safety
	mock_game_state = Node.new()
	mock_game_state.set_script(GameStateScript)
	if not mock_game_state.get_script() == GameStateScript:
		push_error("Failed to set GameState script")
		return
	add_child_autofree(mock_game_state)
	track_test_node(mock_game_state)
	
	# Initialize UI with type safety
	save_load_ui = Node.new()
	save_load_ui.set_script(SaveLoadUIScript)
	if not save_load_ui.get_script() == SaveLoadUIScript:
		push_error("Failed to set SaveLoadUI script")
		return
	add_child_autofree(save_load_ui)
	track_test_node(save_load_ui)
	
	await save_load_ui.ready
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	save_load_ui = null
	mock_game_state = null
	await super.after_each()

# Type-safe signal handling
func _reset_signals() -> void:
	save_selected_signal_emitted = false
	load_selected_signal_emitted = false
	cancelled_signal_emitted = false
	last_save_name = ""
	last_save_data = {}

func _connect_signals() -> void:
	if not save_load_ui:
		return
		
	if save_load_ui.has_signal("save_selected"):
		save_load_ui.connect("save_selected", _on_save_selected)
	if save_load_ui.has_signal("load_selected"):
		save_load_ui.connect("load_selected", _on_load_selected)
	if save_load_ui.has_signal("cancelled"):
		save_load_ui.connect("cancelled", _on_cancelled)

func _disconnect_signals() -> void:
	if not save_load_ui:
		return
		
	if save_load_ui.has_signal("save_selected") and save_load_ui.is_connected("save_selected", _on_save_selected):
		save_load_ui.disconnect("save_selected", _on_save_selected)
	if save_load_ui.has_signal("load_selected") and save_load_ui.is_connected("load_selected", _on_load_selected):
		save_load_ui.disconnect("load_selected", _on_load_selected)
	if save_load_ui.has_signal("cancelled") and save_load_ui.is_connected("cancelled", _on_cancelled):
		save_load_ui.disconnect("cancelled", _on_cancelled)

func _on_save_selected(save_name: String) -> void:
	save_selected_signal_emitted = true
	last_save_name = save_name

func _on_load_selected(save_data: Dictionary) -> void:
	load_selected_signal_emitted = true
	last_save_data = save_data

func _on_cancelled() -> void:
	cancelled_signal_emitted = true

# Type-safe property access
func _get_ui_property(property: String, default_value: Variant = null) -> Variant:
	if not save_load_ui:
		push_error("Trying to access property '%s' on null save load UI" % property)
		return default_value
	if not property in save_load_ui:
		push_error("SaveLoadUI missing required property: %s" % property)
		return default_value
	return save_load_ui.get(property)

func _set_ui_property(property: String, value: Variant) -> void:
	if not save_load_ui:
		push_error("Trying to set property '%s' on null save load UI" % property)
		return
	if not property in save_load_ui:
		push_error("SaveLoadUI missing required property: %s" % property)
		return
	save_load_ui.set(property, value)

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(save_load_ui, "SaveLoadUI should be initialized")
	assert_false(_get_ui_property("is_saving", false), "Should not be in saving state initially")
	assert_false(_get_ui_property("is_loading", false), "Should not be in loading state initially")

# Save Tests
func test_save_game() -> void:
	watch_signals(save_load_ui)
	
	# Setup mock save data with type safety
	_set_property_safe(mock_game_state, "campaign", {
		"name": "Test Campaign",
		"credits": 1000
	})
	
	var save_name_input: Node = _get_ui_property("save_name_input")
	if save_name_input:
		_set_property_safe(save_name_input, "text", "test_save")
	
	_call_node_method(save_load_ui, "_on_save_pressed")
	
	verify_signal_emitted(save_load_ui, "save_completed")
	assert_true(_call_node_method_bool(save_load_ui, "save_exists", ["test_save"]),
		"Save file should exist after saving")

# Load Tests
func test_load_game() -> void:
	watch_signals(save_load_ui)
	
	# Create a mock save first with type safety
	_set_property_safe(mock_game_state, "campaign", {
		"name": "Test Campaign",
		"credits": 1000
	})
	
	var save_name_input: Node = _get_ui_property("save_name_input")
	if save_name_input:
		_set_property_safe(save_name_input, "text", "test_save")
	_call_node_method(save_load_ui, "_on_save_pressed")
	
	# Clear game state
	_set_property_safe(mock_game_state, "campaign", null)
	
	# Test loading with type safety
	_call_node_method(save_load_ui, "select_save", ["test_save"])
	_call_node_method(save_load_ui, "_on_load_pressed")
	
	verify_signal_emitted(save_load_ui, "load_completed")
	var campaign: Dictionary = _get_property_safe(mock_game_state, "campaign", {})
	assert_not_null(campaign, "Campaign should be loaded into game state")
	assert_eq(campaign.get("name"), "Test Campaign", "Should load correct campaign data")

# Save List Tests
func test_save_list_updates() -> void:
	# Create multiple saves with type safety
	var save_names := ["save1", "save2", "save3"]
	var save_name_input: Node = _get_ui_property("save_name_input")
	
	for save_name in save_names:
		if save_name_input:
			_set_property_safe(save_name_input, "text", save_name)
		_call_node_method(save_load_ui, "_on_save_pressed")
	
	_call_node_method(save_load_ui, "_refresh_save_list")
	
	for save_name in save_names:
		assert_true(_call_node_method_bool(save_load_ui, "save_list_has_item", [save_name]),
			"Save list should show all saves")

# Validation Tests
func test_save_name_validation() -> void:
	var save_name_input: Node = _get_ui_property("save_name_input")
	
	# Test empty name
	if save_name_input:
		_set_property_safe(save_name_input, "text", "")
	assert_false(_call_node_method_bool(save_load_ui, "_validate_save_name"),
		"Should reject empty save names")
	
	# Test invalid characters
	if save_name_input:
		_set_property_safe(save_name_input, "text", "test/save")
	assert_false(_call_node_method_bool(save_load_ui, "_validate_save_name"),
		"Should reject names with invalid characters")
	
	# Test valid name
	if save_name_input:
		_set_property_safe(save_name_input, "text", "valid_save_name")
	assert_true(_call_node_method_bool(save_load_ui, "_validate_save_name"),
		"Should accept valid save names")

# Delete Tests
func test_delete_save() -> void:
	# Create a save first with type safety
	var save_name_input: Node = _get_ui_property("save_name_input")
	if save_name_input:
		_set_property_safe(save_name_input, "text", "test_delete")
	_call_node_method(save_load_ui, "_on_save_pressed")
	
	watch_signals(save_load_ui)
	_call_node_method(save_load_ui, "select_save", ["test_delete"])
	_call_node_method(save_load_ui, "_on_delete_pressed")
	
	verify_signal_emitted(save_load_ui, "save_deleted")
	assert_false(_call_node_method_bool(save_load_ui, "save_exists", ["test_delete"]),
		"Save should be deleted")

# Error Cases Tests
func test_error_cases() -> void:
	# Test loading non-existent save with type safety
	watch_signals(save_load_ui)
	_call_node_method(save_load_ui, "select_save", ["non_existent_save"])
	_call_node_method(save_load_ui, "_on_load_pressed")
	
	verify_signal_not_emitted(save_load_ui, "load_completed",
		"Should not emit load_completed for non-existent save")
	
	# Test overwriting existing save with type safety
	var save_name_input: Node = _get_ui_property("save_name_input")
	if save_name_input:
		_set_property_safe(save_name_input, "text", "existing_save")
	_call_node_method(save_load_ui, "_on_save_pressed")
	_call_node_method(save_load_ui, "_on_save_pressed") # Try to save again
	
	verify_signal_emitted(save_load_ui, "save_overwritten",
		"Should emit overwrite signal for existing save")

# Navigation Tests
func test_navigation() -> void:
	watch_signals(get_tree())
	
	_call_node_method(save_load_ui, "_on_back_pressed")
	verify_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_operations() -> void:
	var start_time: int = Time.get_ticks_msec()
	
	# Test rapid save list refreshes with type safety
	for i in range(10):
		_call_node_method(save_load_ui, "_refresh_save_list")
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_true(duration < 1000,
		"Should handle rapid save list refreshes efficiently")

# Cleanup Tests
func test_cleanup() -> void:
	# Create some test saves with type safety
	var save_name_input: Node = _get_ui_property("save_name_input")
	if save_name_input:
		_set_property_safe(save_name_input, "text", "cleanup_test")
	_call_node_method(save_load_ui, "_on_save_pressed")
	
	_call_node_method(save_load_ui, "cleanup")
	
	if save_name_input:
		assert_eq(_get_property_safe(save_name_input, "text"), "",
			"Should clear save name input")
	assert_false(_get_ui_property("is_saving", false),
		"Should reset saving state")
	assert_false(_get_ui_property("is_loading", false),
		"Should reset loading state")

func test_initial_setup() -> void:
	assert_not_null(save_load_ui)
	assert_not_null(_get_ui_property("save_list"))
	assert_not_null(_get_ui_property("save_name_input"))
	assert_not_null(_get_ui_property("save_button"))
	assert_not_null(_get_ui_property("load_button"))
	assert_not_null(_get_ui_property("cancel_button"))

func test_save_mode() -> void:
	_call_node_method(save_load_ui, "set_mode", [GameEnums.EditMode.CREATE])
	
	var save_name_input: Node = _get_ui_property("save_name_input")
	var save_button: Node = _get_ui_property("save_button")
	var load_button: Node = _get_ui_property("load_button")
	
	if save_name_input:
		assert_true(_get_property_safe(save_name_input, "visible"))
	if save_button:
		assert_true(_get_property_safe(save_button, "visible"))
	if load_button:
		assert_false(_get_property_safe(load_button, "visible"))

func test_load_mode() -> void:
	_call_node_method(save_load_ui, "set_mode", [GameEnums.EditMode.VIEW])
	
	var save_name_input: Node = _get_ui_property("save_name_input")
	var save_button: Node = _get_ui_property("save_button")
	var load_button: Node = _get_ui_property("load_button")
	
	if save_name_input:
		assert_false(_get_property_safe(save_name_input, "visible"))
	if save_button:
		assert_false(_get_property_safe(save_button, "visible"))
	if load_button:
		assert_true(_get_property_safe(load_button, "visible"))

func test_save_selection() -> void:
	_call_node_method(save_load_ui, "set_mode", [GameEnums.EditMode.CREATE])
	
	var save_name_input: Node = _get_ui_property("save_name_input")
	var save_button: Node = _get_ui_property("save_button")
	
	if save_name_input:
		_set_property_safe(save_name_input, "text", "Test Save")
	if save_button:
		_call_node_method(save_button, "emit_signal", ["pressed"])
	
	assert_true(save_selected_signal_emitted)
	assert_eq(last_save_name, "Test Save")

func test_load_selection() -> void:
	_call_node_method(save_load_ui, "set_mode", [GameEnums.EditMode.VIEW])
	
	var test_save_data := {
		"name": "Test Save",
		"date": "2024-01-01",
		"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
	}
	
	_call_node_method(save_load_ui, "add_save_data", [test_save_data])
	_call_node_method(save_load_ui, "select_save", [0])
	
	var load_button: Node = _get_ui_property("load_button")
	if load_button:
		_call_node_method(load_button, "emit_signal", ["pressed"])
	
	assert_true(load_selected_signal_emitted)
	assert_eq(last_save_data, test_save_data)

func test_save_list_population() -> void:
	var test_saves := [
		{
			"name": "Save 1",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Save 2",
			"date": "2024-01-02",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.CUSTOM
		}
	]
	
	_call_node_method(save_load_ui, "populate_save_list", [test_saves])
	
	var save_list: Node = _get_ui_property("save_list")
	if save_list:
		assert_eq(_get_property_safe(save_list, "item_count"), 2)
	
	var save_data_1: Dictionary = _call_node_method_dict(save_load_ui, "get_save_data", [0])
	var save_data_2: Dictionary = _call_node_method_dict(save_load_ui, "get_save_data", [1])
	assert_eq(save_data_1.get("name"), "Save 1")
	assert_eq(save_data_2.get("name"), "Save 2")

func test_save_deletion() -> void:
	var test_save := {
		"name": "Test Save",
		"date": "2024-01-01",
		"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
	}
	
	_call_node_method(save_load_ui, "add_save_data", [test_save])
	
	var save_list: Node = _get_ui_property("save_list")
	if save_list:
		assert_eq(_get_property_safe(save_list, "item_count"), 1)
	
	_call_node_method(save_load_ui, "delete_save", [0])
	
	if save_list:
		assert_eq(_get_property_safe(save_list, "item_count"), 0)

func test_cancellation() -> void:
	var cancel_button: Node = _get_ui_property("cancel_button")
	if cancel_button:
		_call_node_method(cancel_button, "emit_signal", ["pressed"])
	
	assert_true(cancelled_signal_emitted)

func test_save_sorting() -> void:
	var test_saves := [
		{
			"name": "Save 2",
			"date": "2024-01-02",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Save 1",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		}
	]
	
	_call_node_method(save_load_ui, "populate_save_list", [test_saves])
	_call_node_method(save_load_ui, "sort_saves_by_date")
	
	var save_data_0: Dictionary = _call_node_method_dict(save_load_ui, "get_save_data", [0])
	var save_data_1: Dictionary = _call_node_method_dict(save_load_ui, "get_save_data", [1])
	assert_eq(save_data_0.get("date"), "2024-01-02")
	assert_eq(save_data_1.get("date"), "2024-01-01")

func test_save_filtering() -> void:
	var test_saves := [
		{
			"name": "Standard Save",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Custom Save",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.CUSTOM
		}
	]
	
	_call_node_method(save_load_ui, "populate_save_list", [test_saves])
	_call_node_method(save_load_ui, "filter_saves_by_type", [GameEnums.FiveParcsecsCampaignType.STANDARD])
	
	var save_list: Node = _get_ui_property("save_list")
	if save_list:
		assert_eq(_get_property_safe(save_list, "item_count"), 1)
	
	var save_data: Dictionary = _call_node_method_dict(save_load_ui, "get_save_data", [0])
	assert_eq(save_data.get("name"), "Standard Save")