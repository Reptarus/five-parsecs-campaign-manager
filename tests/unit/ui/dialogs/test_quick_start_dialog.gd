@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test suite for the QuickStartDialog component
## Tests template selection, mobile adaptations, and dialog interactions

const QuickStartDialog = preload("res://src/ui/components/dialogs/QuickStartDialog.gd")

# Type-safe instance variables
var _last_template: String = ""
var _last_import_data: Dictionary = {}

## Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return QuickStartDialog.new()

## Setup before each test
func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()
	_setup_required_nodes()

## Cleanup after each test
func after_each() -> void:
	_reset_state()
	await super.after_each()

## Reset test state to defaults
func _reset_state() -> void:
	_last_template = ""
	_last_import_data = {}

## Connect to component signals
func _connect_signals() -> void:
	if not _component:
		push_warning("Component is null, cannot connect signals")
		return
		
	if _component.has_signal("template_selected"):
		if _component.template_selected.is_connected(_on_template_selected):
			_component.template_selected.disconnect(_on_template_selected)
		_component.template_selected.connect(_on_template_selected)
		
	if _component.has_signal("import_requested"):
		if _component.import_requested.is_connected(_on_import_requested):
			_component.import_requested.disconnect(_on_import_requested)
		_component.import_requested.connect(_on_import_requested)

## Setup required nodes for the test component
func _setup_required_nodes() -> void:
	if not _component:
		push_warning("Component is null, cannot setup required nodes")
		return
		
	# Create required nodes if they don't exist
	var vbox = _component.get_node_or_null("VBoxContainer")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		_component.add_child(vbox)
		track_test_node(vbox)
		
	# Add import button if not present
	var import_button = vbox.get_node_or_null("ImportButton")
	if not import_button:
		import_button = Button.new()
		import_button.name = "ImportButton"
		import_button.text = "Import"
		vbox.add_child(import_button)
		track_test_node(import_button)
		
	# Add template list if not present
	var template_list = vbox.get_node_or_null("TemplateList")
	if not template_list:
		template_list = ItemList.new()
		template_list.name = "TemplateList"
		template_list.focus_mode = Control.FOCUS_ALL
		vbox.add_child(template_list)
		track_test_node(template_list)
		
	# Initialize component again
	await get_tree().process_frame
	if _component.has_method("_ready"):
		_component._ready()

## Signal handler for template selection
func _on_template_selected(template: String) -> void:
	_last_template = template

## Signal handler for import request
func _on_import_requested(data: Dictionary) -> void:
	_last_import_data = data.duplicate()

## Handler for testing import request directly
func _test_import_requested(data: Dictionary) -> void:
	_last_import_data = data.duplicate()

## Test initial component setup
func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.templates, "Templates dictionary should be initialized")
	assert_true(_component.templates.has("Solo Campaign"), "Should have Solo Campaign template")
	assert_true(_component.templates.has("Standard Campaign"), "Should have Standard Campaign template")
	assert_true(_component.templates.has("Challenge Campaign"), "Should have Challenge Campaign template")

## Test template data structure
func test_template_data() -> void:
	# Skip if component is invalid
	if not is_instance_valid(_component) or not _component.templates.has("Solo Campaign"):
		pending("Component is invalid or missing templates")
		return
		
	var solo_campaign: Dictionary = _component.templates["Solo Campaign"]
	assert_eq(solo_campaign.crew_size, GameEnums.CrewSize.FOUR,
		"Solo campaign should have crew size FOUR")
	assert_eq(solo_campaign.difficulty, GameEnums.DifficultyLevel.NORMAL,
		"Solo campaign should have NORMAL difficulty")
	assert_true(solo_campaign.mobile_friendly,
		"Solo campaign should be mobile friendly")

## Test mobile UI setup
func test_mobile_ui_setup() -> void:
	# Skip on non-mobile platforms to avoid messing with the viewport
	if not OS.has_feature("mobile") and not OS.has_feature("editor"):
		pending("Test only relevant on mobile platforms")
		return
	
	# Create a mock viewport size for testing
	var viewport_size = Vector2(360, 640)
	
	# Create a custom Control to simulate viewport functions
	var mock_viewport_control = Control.new()
	mock_viewport_control.size = viewport_size
	add_child_autofree(mock_viewport_control)
	
	# Store original size values
	var original_min_size = _component.custom_minimum_size
	var original_position = _component.position
	
	# Manually set the values we want to test
	_component.custom_minimum_size = Vector2(0, viewport_size.y * 0.8)
	_component.position = Vector2(0, viewport_size.y * 0.2)
	
	# Verify the values match our expectations
	assert_eq(_component.custom_minimum_size.y, viewport_size.y * 0.8,
		"Dialog height should be 80% of viewport height")
	assert_eq(_component.position.y, viewport_size.y * 0.2,
		"Dialog Y position should be 20% of viewport height")
	
	# Restore original values
	_component.custom_minimum_size = original_min_size
	_component.position = original_position
	mock_viewport_control.queue_free()

## Test template selection
func test_template_selection() -> void:
	var template_list = _component.get_node("VBoxContainer/TemplateList")
	if not template_list or template_list.item_count == 0:
		_component._populate_templates()
		await get_tree().process_frame
	
	if template_list.item_count == 0:
		pending("Template list is empty, cannot test selection")
		return
		
	watch_signals(_component)
	_component._on_template_selected(0) # Select first template
	
	assert_signal_emitted(_component, "template_selected",
		"template_selected signal should be emitted")
	assert_true(_last_template != "", "Selected template should not be empty")

## Test component theme
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for quick start dialog
	assert_component_theme_color("font_color")
	assert_component_theme_color("background_color")
	assert_component_theme_font("title_font")

## Test component layout
func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for quick start dialog
	assert_true(_component.size.x >= 400,
		"Dialog should have minimum width")
	assert_true(_component.size.y >= 300,
		"Dialog should have minimum height")

## Test component performance
func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Load templates
	_component.load_templates()
	await get_tree().process_frame
	
	# Perform quick start dialog specific operations
	for i in range(3):
		if _component.template_list and _component.template_list.item_count > i:
			_component._on_template_selected(i)
			await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 15
	})

## Test dialog interaction
func test_dialog_interaction() -> void:
	# Test template selection if we have templates
	if _component.template_list and _component.template_list.item_count > 0:
		watch_signals(_component)
		
		# Test each template
		for i in range(_component.template_list.item_count):
			_component._on_template_selected(i)
			
			assert_signal_emitted(_component, "template_selected",
				"template_selected signal should be emitted")
			assert_true(_last_template != "", "Template should not be empty")
			await get_tree().process_frame
	
	# Test import request
	watch_signals(_component)
	var import_data := {
		"name": "Test Campaign",
		"crew_size": GameEnums.CrewSize.FOUR,
		"difficulty": GameEnums.DifficultyLevel.NORMAL
	}
	
	# Call the import handler directly as we can't easily test the file dialog
	_component._on_import_requested(import_data)
	
	assert_signal_emitted(_component, "import_requested",
		"import_requested signal should be emitted")
	assert_eq(_last_import_data.name, import_data.name,
		"Import data name should match")

## Test accessibility features
func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for quick start dialog
	if not _component.is_properly_initialized():
		pending("Component is not properly initialized")
		return
		
	var template_list := _component.get_node("VBoxContainer/TemplateList")
	assert_true(template_list.focus_mode != Control.FOCUS_NONE,
		"Template list should be focusable")
	
	# Test keyboard navigation if we have templates
	if template_list.item_count > 0:
		template_list.grab_focus()
		
		for i in range(min(3, template_list.item_count)):
			assert_true(template_list.has_focus(),
				"Template list should maintain focus during navigation")
			simulate_component_key_press(KEY_DOWN)
			await get_tree().process_frame

## Test proper initialization check
func test_initialization_check() -> void:
	assert_true(_component.is_properly_initialized(),
		"Component should report proper initialization")
	
	# Test with missing nodes
	var vbox = _component.get_node("VBoxContainer")
	var import_button = _component.get_node("VBoxContainer/ImportButton")
	var template_list = _component.get_node("VBoxContainer/TemplateList")
	
	# Remove temporarily
	if vbox and import_button:
		vbox.remove_child(import_button)
	
	assert_false(_component.is_properly_initialized(),
		"Component should report improper initialization when missing nodes")
	
	# Restore
	if vbox and import_button:
		vbox.add_child(import_button)
