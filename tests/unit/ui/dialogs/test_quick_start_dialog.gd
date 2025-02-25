@tool
extends ComponentTestBase

const QuickStartDialog := preload("res://src/ui/components/dialogs/QuickStartDialog.gd")

# Type-safe instance variables
var _last_template: String
var _last_import_data: Dictionary

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return QuickStartDialog.new()

func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_template = ""
	_last_import_data = {}

func _connect_signals() -> void:
	_component.template_selected.connect(_on_template_selected)
	_component.import_requested.connect(_on_import_requested)

func _on_template_selected(template: String) -> void:
	_last_template = template

func _on_import_requested(data: Dictionary) -> void:
	_last_import_data = data.duplicate()

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.templates)
	assert_true(_component.templates.has("Solo Campaign"))
	assert_true(_component.templates.has("Standard Campaign"))
	assert_true(_component.templates.has("Challenge Campaign"))

func test_template_data() -> void:
	var solo_campaign: Dictionary = _component.templates["Solo Campaign"]
	assert_eq(solo_campaign.crew_size, GameEnums.CrewSize.FOUR)
	assert_eq(solo_campaign.difficulty, GameEnums.DifficultyLevel.NORMAL)
	assert_true(solo_campaign.mobile_friendly)

func test_mobile_ui_setup() -> void:
	if OS.has_feature("mobile"):
		_component._setup_mobile_ui()
		var viewport_size := _component.get_viewport().get_visible_rect().size
		assert_eq(_component.custom_minimum_size.y, viewport_size.y * 0.8)
		assert_eq(_component.position.y, viewport_size.y * 0.2)

func test_template_selection() -> void:
	var template_list := _component.get_node("VBoxContainer/TemplateList")
	assert_not_null(template_list)
	_component._on_template_selected(0) # Select first template
	assert_signal_emitted(_component, "template_selected")

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for quick start dialog
	assert_component_theme_color("font_color")
	assert_component_theme_color("background_color")
	assert_component_theme_font("title_font")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for quick start dialog
	assert_true(_component.size.x >= 400,
		"Dialog should have minimum width")
	assert_true(_component.size.y >= 300,
		"Dialog should have minimum height")

func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform quick start dialog specific operations
	for i in range(5):
		_component._on_template_selected(i % 3)
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 15
	})

func test_dialog_interaction() -> void:
	# Test template selection
	for i in range(3):
		_component._on_template_selected(i)
		assert_signal_emitted(_component, "template_selected")
		assert_true(_last_template != "", "Template should not be empty")
		await get_tree().process_frame
	
	# Test import request
	var import_data := {
		"name": "Test Campaign",
		"crew_size": GameEnums.CrewSize.FOUR,
		"difficulty": GameEnums.DifficultyLevel.NORMAL
	}
	_component._on_import_requested(import_data)
	assert_signal_emitted(_component, "import_requested")
	assert_eq(_last_import_data.name, import_data.name)

func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for quick start dialog
	var template_list := _component.get_node("VBoxContainer/TemplateList")
	assert_true(template_list.focus_mode != Control.FOCUS_NONE,
		"Template list should be focusable")
	
	# Test keyboard navigation
	template_list.grab_focus()
	for i in range(3):
		assert_true(template_list.has_focus(),
			"Template list should maintain focus during navigation")
		simulate_component_key_press(KEY_DOWN)
		await get_tree().process_frame