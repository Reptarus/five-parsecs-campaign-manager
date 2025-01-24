extends "res://addons/gut/test.gd"

const EventItem = preload("res://src/scenes/campaign/components/EventItem.gd")

var item: EventItem
var selected_signal_emitted := false
var last_event_id: String

func before_each() -> void:
	item = EventItem.new()
	add_child(item)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	item.queue_free()

func _reset_signals() -> void:
	selected_signal_emitted = false
	last_event_id = ""

func _connect_signals() -> void:
	item.event_selected.connect(_on_event_selected)

func _on_event_selected(event_id: String) -> void:
	selected_signal_emitted = true
	last_event_id = event_id

func test_initial_setup() -> void:
	assert_not_null(item)
	assert_not_null(item.title_label)
	assert_not_null(item.description_label)
	assert_not_null(item.timestamp_label)
	assert_not_null(item.category_indicator)
	assert_eq(item.event_id, "")

func test_event_data_setup() -> void:
	var test_id = "test_event_1"
	var test_title = "Test Event"
	var test_description = "Test Description"
	var test_timestamp = Time.get_unix_time_from_system()
	var test_color = Color(1, 0, 0) # Red
	
	item.setup(test_id, test_title, test_description, test_timestamp, test_color)
	
	assert_eq(item.event_id, test_id)
	assert_eq(item.title_label.text, test_title)
	assert_eq(item.description_label.text, test_description)
	assert_true(item.timestamp_label.text.length() > 0)
	assert_eq(item.event_color, test_color)

func test_event_selection() -> void:
	var test_id = "test_event_2"
	item.setup(test_id, "Test Event", "Description", Time.get_unix_time_from_system(), Color.WHITE)
	
	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	item._on_gui_input(mouse_event)
	
	assert_true(selected_signal_emitted)
	assert_eq(last_event_id, test_id)

func test_long_text_handling() -> void:
	var test_id = "test_event_3"
	var long_title = "Very Long Event Title That Should Be Handled Properly"
	var long_description = "This is a very long description that should be properly wrapped and displayed in the event item's description label without breaking the layout"
	
	item.setup(test_id, long_title, long_description, Time.get_unix_time_from_system(), Color.WHITE)
	
	assert_eq(item.title_label.text, long_title)
	assert_eq(item.description_label.text, long_description)
	assert_true(item.description_label.autowrap_mode > 0)

func test_empty_values() -> void:
	item.setup("", "", "", Time.get_unix_time_from_system(), Color.WHITE)
	
	assert_eq(item.event_id, "")
	assert_eq(item.title_label.text, "")
	assert_eq(item.description_label.text, "")
	assert_true(item.timestamp_label.text.length() > 0)

func test_timestamp_formatting() -> void:
	var test_timestamp = Time.get_unix_time_from_system()
	item.setup("test_event_4", "Test Event", "Description", test_timestamp, Color.WHITE)
	
	var timestamp_text = item.timestamp_label.text
	assert_true(timestamp_text.length() > 0)
	assert_true(":" in timestamp_text) # Should be in HH:MM format

func test_color_handling() -> void:
	var test_colors = [
		Color(1, 0, 0), # Red
		Color(0, 1, 0), # Green
		Color(0, 0, 1), # Blue
		Color(1, 1, 1), # White
		Color(0, 0, 0) # Black
	]
	
	for color in test_colors:
		item.setup("test_event", "Test Event", "Description", Time.get_unix_time_from_system(), color)
		assert_eq(item.event_color, color)
		assert_eq(item.category_indicator.color, color)

func test_animations() -> void:
	item.setup("test_event_5", "Test Event", "Description", Time.get_unix_time_from_system(), Color.WHITE)
	
	# Test highlight animation
	item.highlight(0.1) # Use shorter duration for testing
	assert_eq(item.modulate.a, 0.5) # Should start fading
	
	# Test fade in animation
	item.fade_in(0.1) # Use shorter duration for testing
	assert_eq(item.modulate.a, 0.0) # Should start invisible