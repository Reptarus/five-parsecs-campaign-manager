extends "res://addons/gut/test.gd"

const Logbook = preload("res://src/ui/components/logbook/logbook.gd")

var logbook: Logbook

func before_each() -> void:
	logbook = Logbook.new()
	add_child(logbook)

func after_each() -> void:
	logbook.queue_free()

func test_initial_setup() -> void:
	assert_not_null(logbook)
	assert_not_null(logbook.crew_select)
	assert_not_null(logbook.entry_list)
	assert_not_null(logbook.entry_content)
	assert_not_null(logbook.notes_edit)
	assert_eq(logbook.PORTRAIT_LIST_HEIGHT_RATIO, 0.4)

func test_portrait_layout() -> void:
	logbook._apply_portrait_layout()
	
	assert_true(logbook.main_container.get("vertical"))
	
	var viewport_height = logbook.get_viewport_rect().size.y
	assert_eq(logbook.sidebar.custom_minimum_size.y, viewport_height * logbook.PORTRAIT_LIST_HEIGHT_RATIO)

func test_landscape_layout() -> void:
	logbook._apply_landscape_layout()
	
	assert_false(logbook.main_container.get("vertical"))
	assert_eq(logbook.sidebar.custom_minimum_size, Vector2(300, 0))

func test_touch_size_adjustments() -> void:
	# Test portrait mode adjustments
	logbook._adjust_touch_sizes(true)
	assert_eq(logbook.crew_select.custom_minimum_size.y, logbook.TOUCH_BUTTON_HEIGHT)
	assert_eq(logbook.entry_list.fixed_item_height, logbook.TOUCH_BUTTON_HEIGHT)
	
	# Test landscape mode adjustments
	logbook._adjust_touch_sizes(false)
	assert_eq(logbook.crew_select.custom_minimum_size.y, logbook.TOUCH_BUTTON_HEIGHT * 0.75)
	assert_eq(logbook.entry_list.fixed_item_height, logbook.TOUCH_BUTTON_HEIGHT * 0.75)

func test_button_setup() -> void:
	logbook._setup_buttons()
	
	var buttons = get_tree().get_nodes_in_group("touch_buttons")
	for button in buttons:
		assert_eq(button.custom_minimum_size.x, 150)

func test_crew_selector_setup() -> void:
	logbook._setup_crew_selector()
	assert_true(logbook.crew_select.is_in_group("touch_controls"))