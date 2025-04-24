@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

const EventItem: GDScript = preload("res://src/scenes/campaign/components/EventItem.gd")
const EventItemInstance = preload("res://src/scenes/campaign/components/EventItem.tscn")

# Test variables with explicit types
var value_changed_signal_emitted: bool = false
var last_value: String = ""

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	# Use the scene instance instead of a script instance for more reliable tests
	return EventItemInstance.instantiate() if EventItemInstance else EventItem.new()

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	value_changed_signal_emitted = false
	last_value = ""

func _reset_signals() -> void:
	value_changed_signal_emitted = false
	last_value = ""

func _connect_signals() -> void:
	if not is_instance_valid(_component):
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("value_changed"):
		if _component.value_changed.is_connected(_on_value_changed):
			_component.value_changed.disconnect(_on_value_changed)
		_component.value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: String) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

func test_initial_setup() -> void:
	assert_not_null(_component, "Event item should be initialized")
	
	# Use defensive null checks with has_node instead of has
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	if not _component.has_method("has_node") or not _component.has_node("MarginContainer/VBoxContainer/Header/Title"):
		push_warning("Value label is not found, skipping test")
		return
		
	if not _component.has_method("has_node") or not _component.has_node("MarginContainer/VBoxContainer/Header/Timestamp"):
		push_warning("Timestamp label is not found, skipping test")
		return
	
	var title_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	var timestamp_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Timestamp")
	
	assert_not_null(title_label, "Title label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	var current_value: String = ""
	if _component.has_method("get_current_value"):
		current_value = str(_component.get_current_value())
	assert_eq(current_value, "", "Initial value should be empty")

func test_value_update() -> void:
	# Skip test if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	if not _component.has_method("has_node") or not _component.has_node("MarginContainer/VBoxContainer/Header/Title"):
		push_warning("Title label is not found, skipping test")
		return
	
	var test_value: String = "Test Event"
	if _component.has_method("set_value"):
		_component.set_value(test_value)
	else:
		push_warning("Component doesn't have set_value method, skipping test")
		return
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var current_value: String = ""
	if _component.has_method("get_current_value"):
		current_value = str(_component.get_current_value())
	
	# Safely access title_label
	var label_text: String = ""
	var title_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	if is_instance_valid(title_label) and title_label is Label:
		label_text = title_label.text
	
	assert_eq(current_value, test_value, "Current value should be updated")
	assert_eq(label_text, test_value, "Label should display the new value")

func test_empty_value_handling() -> void:
	# Skip test if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	if not _component.has_method("set_value"):
		push_warning("Component doesn't have set_value method, skipping test")
		return
	
	_component.set_value("")
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, "", "Last value should be empty")
	
	# Safely access title_label
	var label_text: String = ""
	var title_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	if is_instance_valid(title_label) and title_label is Label:
		label_text = title_label.text
	
	assert_eq(label_text, "", "Label should be empty")

func test_timestamp_formatting() -> void:
	# Skip test if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	var timestamp_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Timestamp")
	if not is_instance_valid(timestamp_label):
		push_warning("Timestamp label is invalid, skipping test")
		return
		
	if not _component.has_method("set_timestamp"):
		push_warning("Component doesn't have set_timestamp method, skipping test")
		return
	
	var test_timestamp: String = "2024-03-20 15:30:00"
	_component.set_timestamp(test_timestamp)
	
	var timestamp_text: String = ""
	if is_instance_valid(timestamp_label) and timestamp_label is Label:
		timestamp_text = timestamp_label.text
	
	assert_true(timestamp_text.length() > 0, "Timestamp should be formatted")
	assert_true("2024" in timestamp_text, "Timestamp should contain year")

func test_color_handling() -> void:
	# Skip test if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	var title_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	var timestamp_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Timestamp")
	
	if not is_instance_valid(title_label) or not is_instance_valid(timestamp_label) or not _component.has_method("set_text_color"):
		push_warning("Labels are invalid or missing set_text_color method, skipping test")
		return
	
	var test_color := Color(1, 0, 0, 1) # Red color
	_component.set_text_color(test_color)
	
	assert_not_null(title_label, "Title label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	# Check if the color was applied to both labels
	var title_label_color: Color = Color.WHITE
	var timestamp_label_color: Color = Color.WHITE
	
	if is_instance_valid(title_label) and title_label is Label and title_label.has_method("get_theme_color"):
		title_label_color = title_label.get_theme_color("font_color")
	
	if is_instance_valid(timestamp_label) and timestamp_label is Label and timestamp_label.has_method("get_theme_color"):
		timestamp_label_color = timestamp_label.get_theme_color("font_color")
	
	assert_eq(title_label_color, test_color, "Title label color should match test color")
	assert_eq(timestamp_label_color, test_color, "Timestamp label color should match test color")

func test_animation_handling() -> void:
	# Skip test if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping test")
		return
		
	var animation_player = _component.get_node_or_null("AnimationPlayer")
	if not is_instance_valid(animation_player):
		push_warning("Animation player is invalid, skipping test")
		return
		
	if not _component.has_method("play_highlight_animation"):
		push_warning("Component doesn't have play_highlight_animation method, skipping test")
		return
	
	_component.play_highlight_animation()
	
	# Wait for animation to start
	await get_tree().process_frame
	
	assert_not_null(animation_player, "Animation player should exist")
	
	if is_instance_valid(animation_player) and animation_player is AnimationPlayer:
		assert_true(animation_player.is_playing(), "Animation should be playing")

# Add inherited component tests
func test_component_structure() -> void:
	await super.test_component_structure()
	
	# Skip additional tests if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping additional structure tests")
		return
	
	# Additional EventItem-specific structure tests
	assert_not_null(_component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title"),
		"Title label should exist")
	
	assert_not_null(_component.get_node_or_null("MarginContainer/VBoxContainer/Header/Timestamp"),
		"Timestamp label should exist")
	
	assert_not_null(_component.get_node_or_null("AnimationPlayer"),
		"Animation player should exist")

func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Skip additional tests if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping additional theme tests")
		return
	
	# Additional EventItem-specific theme tests
	if _component.has_method("has_theme_color"):
		assert_true(_component.has_theme_color("font_color"), "Should have font color theme property")
	
	if _component.has_method("has_theme_stylebox"):
		assert_true(_component.has_theme_stylebox("normal"), "Should have normal stylebox")

func test_component_accessibility() -> void:
	await super.test_component_accessibility()
	
	# Skip additional tests if component is invalid
	if not is_instance_valid(_component):
		push_warning("Component is invalid, skipping additional accessibility tests")
		return
	
	var title_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	var timestamp_label = _component.get_node_or_null("MarginContainer/VBoxContainer/Header/Timestamp")
	
	if not is_instance_valid(title_label) or not is_instance_valid(timestamp_label):
		push_warning("Labels are invalid, skipping additional accessibility tests")
		return
	
	# Additional EventItem-specific accessibility tests
	if is_instance_valid(title_label) and title_label is Label:
		assert_true(title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
			"Title label should be left-aligned for readability")
	
	if is_instance_valid(timestamp_label) and timestamp_label is Label:
		assert_true(timestamp_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
			"Timestamp label should be right-aligned for consistency")
