@tool
extends ComponentTestBase

const Logbook := preload("res://src/ui/components/logbook/logbook.gd")

# Type-safe instance variables
var _last_crew_selection: String
var _last_entry_selection: String
var _last_notes_text: String

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return Logbook.new()

func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_crew_selection = ""
	_last_entry_selection = ""
	_last_notes_text = ""

func _connect_signals() -> void:
	_component.crew_selected.connect(_on_crew_selected)
	_component.entry_selected.connect(_on_entry_selected)
	_component.notes_updated.connect(_on_notes_updated)

func _on_crew_selected(crew_id: String) -> void:
	_last_crew_selection = crew_id

func _on_entry_selected(entry_id: String) -> void:
	_last_entry_selection = entry_id

func _on_notes_updated(notes: String) -> void:
	_last_notes_text = notes

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.crew_select)
	assert_not_null(_component.entry_list)
	assert_not_null(_component.entry_content)
	assert_not_null(_component.notes_edit)
	assert_eq(_component.PORTRAIT_LIST_HEIGHT_RATIO, 0.4)

func test_portrait_layout() -> void:
	_component._apply_portrait_layout()
	
	assert_true(_component.main_container.get("vertical"))
	
	var viewport_height := _component.get_viewport_rect().size.y
	assert_eq(_component.sidebar.custom_minimum_size.y, viewport_height * _component.PORTRAIT_LIST_HEIGHT_RATIO)

func test_landscape_layout() -> void:
	_component._apply_landscape_layout()
	
	assert_false(_component.main_container.get("vertical"))
	assert_eq(_component.sidebar.custom_minimum_size, Vector2(300, 0))

func test_touch_size_adjustments() -> void:
	# Test portrait mode adjustments
	_component._adjust_touch_sizes(true)
	assert_eq(_component.crew_select.custom_minimum_size.y, _component.TOUCH_BUTTON_HEIGHT)
	assert_eq(_component.entry_list.fixed_item_height, _component.TOUCH_BUTTON_HEIGHT)
	
	# Test landscape mode adjustments
	_component._adjust_touch_sizes(false)
	assert_eq(_component.crew_select.custom_minimum_size.y, _component.TOUCH_BUTTON_HEIGHT * 0.75)
	assert_eq(_component.entry_list.fixed_item_height, _component.TOUCH_BUTTON_HEIGHT * 0.75)

func test_button_setup() -> void:
	_component._setup_buttons()
	
	var buttons := get_tree().get_nodes_in_group("touch_buttons")
	for button in buttons:
		assert_eq(button.custom_minimum_size.x, 150)

func test_crew_selector_setup() -> void:
	_component._setup_crew_selector()
	assert_true(_component.crew_select.is_in_group("touch_controls"))

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for logbook
	assert_component_theme_color("text_color")
	assert_component_theme_color("background_color")
	assert_component_theme_font("normal_font")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for logbook
	assert_true(_component.crew_select.size.y <= _component.size.y * 0.4,
		"Crew select should not exceed 40% of logbook height")
	assert_true(_component.entry_list.size.y <= _component.size.y * 0.6,
		"Entry list should not exceed 60% of logbook height")

func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform logbook specific operations
	for i in range(5):
		_component._apply_portrait_layout()
		_component._apply_landscape_layout()
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 15,
		"draw_calls": 10,
		"theme_lookups": 25
	})

func test_logbook_interaction() -> void:
	# Test crew selection
	var crew_id := "crew_1"
	_component.crew_select.selected_id = crew_id
	_component.crew_select.item_selected.emit(0)
	assert_eq(_last_crew_selection, crew_id)
	
	# Test entry selection
	var entry_id := "entry_1"
	_component.entry_list.selected_id = entry_id
	_component.entry_list.item_selected.emit(0)
	assert_eq(_last_entry_selection, entry_id)
	
	# Test notes update
	var notes := "Test notes"
	_component.notes_edit.text = notes
	_component.notes_edit.text_changed.emit()
	assert_eq(_last_notes_text, notes)

func test_responsive_behavior() -> void:
	# Test portrait mode
	get_viewport().size = Vector2i(360, 640)
	await get_tree().process_frame
	assert_true(_component.main_container.get("vertical"))
	
	# Test landscape mode
	get_viewport().size = Vector2i(640, 360)
	await get_tree().process_frame
	assert_false(_component.main_container.get("vertical"))

func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for logbook
	assert_true(_component.crew_select.focus_mode != Control.FOCUS_NONE,
		"Crew select should be focusable")
	assert_true(_component.entry_list.focus_mode != Control.FOCUS_NONE,
		"Entry list should be focusable")
	assert_true(_component.notes_edit.focus_mode != Control.FOCUS_NONE,
		"Notes edit should be focusable")