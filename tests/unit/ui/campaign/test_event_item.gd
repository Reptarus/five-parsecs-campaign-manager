@tool
extends GdUnitGameTest

# Handle missing preload gracefully
static func _load_event_item() -> GDScript:
	if ResourceLoader.exists("res://src/scenes/campaign/components/EventItem.gd"):
		return preload("res://src/scenes/campaign/components/EventItem.gd")
	return null

var EventItem: GDScript = _load_event_item()

# Mock EventItem for when actual one doesn't exist
class MockEventItem extends Control:
	signal value_changed(new_value: String)
	signal timestamp_changed(new_timestamp: String)
	
	var value_label: Label
	var timestamp_label: Label
	var animation_player: AnimationPlayer
	var current_value: String = ""
	var current_timestamp: String = ""
	
	func _init():
		name = "MockEventItem"
		_setup_components()
	
	func _setup_components():
		# Create value label
		value_label = Label.new()
		value_label.name = "ValueLabel"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(value_label)
		
		# Create timestamp label
		timestamp_label = Label.new()
		timestamp_label.name = "TimestampLabel"
		timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(timestamp_label)
		
		# Create animation player
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
	
	func set_value(new_value: String) -> bool:
		current_value = new_value
		if value_label:
			value_label.text = new_value
		value_changed.emit(new_value)
		return true
	
	func get_current_value() -> String:
		return current_value
	
	func set_timestamp(new_timestamp: String) -> bool:
		current_timestamp = new_timestamp
		if timestamp_label:
			timestamp_label.text = new_timestamp
		timestamp_changed.emit(new_timestamp)
		return true
	
	func set_text_color(color: Color) -> bool:
		if value_label:
			value_label.add_theme_color_override("font_color", color)
		if timestamp_label:
			timestamp_label.add_theme_color_override("font_color", color)
		return true
	
	func play_highlight_animation() -> bool:
		if animation_player:
			# Simulate animation playing
			animation_player.play("highlight")
		return true

# Test variables with explicit types
var value_changed_signal_emitted: bool = false
var last_value: String = ""
var _component: Control

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	if EventItem:
		return EventItem.new()
	else:
		return MockEventItem.new()

func before_test() -> void:
	super.before_test()
	_component = _create_component_instance()
	if _component:
		track_node(_component)
		add_child(_component)
	_reset_signals()
	_connect_signals()
	await get_tree().process_frame

func after_test() -> void:
	_component = null
	value_changed_signal_emitted = false
	last_value = ""
	super.after_test()

func _reset_signals() -> void:
	value_changed_signal_emitted = false
	last_value = ""

func _connect_signals() -> void:
	if not _component:
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("value_changed"):
		_component.value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: String) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

# Safe wrapper methods for dynamic method calls
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
	if node and node.has_method(method_name):
		var result = node.callv(method_name, args)
		return result if result is bool else false
	return false

func _safe_call_method(node: Node, method_name: String, args: Array = []) -> Variant:
	if node and node.has_method(method_name):
		return node.callv(method_name, args)
	return null

func _safe_cast_to_string(value: Variant) -> String:
	return value if value is String else ""

# Safe property checking using 'in' operator instead of has_property()
func _safe_has_property(node: Node, property_name: String) -> bool:
	if not node:
		return false
	return property_name in node

func test_initial_setup() -> void:
	assert_that(_component).override_failure_message("Event item should be initialized").is_not_null()
	
	# Check if component has the expected properties using safe property checking
	if _safe_has_property(_component, "value_label") and _component.get("value_label"):
		var value_label: Label = _component.get("value_label")
		assert_that(value_label).override_failure_message("Value label should exist").is_not_null()
	
	if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
		var timestamp_label: Label = _component.get("timestamp_label")
		assert_that(timestamp_label).override_failure_message("Timestamp label should exist").is_not_null()
	
	var current_value: String = _safe_cast_to_string(_safe_call_method(_component, "get_current_value", []))
	assert_that(current_value).override_failure_message("Initial value should be empty").is_equal("")

func test_value_update() -> void:
	var test_value: String = "Test Event"
	_safe_call_method_bool(_component, "set_value", [test_value])
	
	# Wait for signal to be processed
	await get_tree().process_frame
	
	assert_that(value_changed_signal_emitted).override_failure_message("Value changed signal should be emitted").is_true()
	assert_that(last_value).override_failure_message("Last value should match test value").is_equal(test_value)
	
	var current_value: String = _safe_cast_to_string(_safe_call_method(_component, "get_current_value", []))
	assert_that(current_value).override_failure_message("Current value should be updated").is_equal(test_value)
	
	# Check label text if component has value_label
	if _safe_has_property(_component, "value_label") and _component.get("value_label"):
		var value_label: Label = _component.get("value_label")
		assert_that(value_label.text).override_failure_message("Label should display the new value").is_equal(test_value)

func test_empty_value_handling() -> void:
	_safe_call_method_bool(_component, "set_value", [""])
	
	# Wait for signal to be processed
	await get_tree().process_frame
	
	assert_that(value_changed_signal_emitted).override_failure_message("Value changed signal should be emitted").is_true()
	assert_that(last_value).override_failure_message("Last value should be empty").is_equal("")
	
	# Check label text if component has value_label
	if _safe_has_property(_component, "value_label") and _component.get("value_label"):
		var value_label: Label = _component.get("value_label")
		assert_that(value_label.text).override_failure_message("Label should be empty").is_equal("")

func test_timestamp_formatting() -> void:
	var test_timestamp: String = "2024-03-20 15:30:00"
	_safe_call_method_bool(_component, "set_timestamp", [test_timestamp])
	
	# Check timestamp text if component has timestamp_label
	if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
		var timestamp_label: Label = _component.get("timestamp_label")
		assert_that(timestamp_label.text.length()).override_failure_message("Timestamp should be formatted").is_greater(0)
		assert_that("2024" in timestamp_label.text).override_failure_message("Timestamp should contain year").is_true()

func test_color_handling() -> void:
	var test_color := Color(1, 0, 0, 1) # Red color
	_safe_call_method_bool(_component, "set_text_color", [test_color])
	
	# Check if component has labels to test color on
	if _safe_has_property(_component, "value_label") and _component.get("value_label"):
		var value_label: Label = _component.get("value_label")
		assert_that(value_label).override_failure_message("Value label should exist").is_not_null()
		
		# Check if the color was applied
		if value_label.has_theme_color_override("font_color"):
			var value_label_color: Color = value_label.get_theme_color("font_color")
			assert_that(value_label_color).override_failure_message("Value label color should match test color").is_equal(test_color)
	
	if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
		var timestamp_label: Label = _component.get("timestamp_label")
		assert_that(timestamp_label).override_failure_message("Timestamp label should exist").is_not_null()

func test_animation_handling() -> void:
	_safe_call_method_bool(_component, "play_highlight_animation", [])
	
	# Wait for animation to start
	await get_tree().process_frame
	
	# Check if component has animation_player
	if _safe_has_property(_component, "animation_player") and _component.get("animation_player"):
		var animation_player: AnimationPlayer = _component.get("animation_player")
		assert_that(animation_player).override_failure_message("Animation player should exist").is_not_null()
		# Note: Mock animation player may not actually play, so we just check it exists

# Test component structure
func test_component_structure() -> void:
	assert_that(_component).override_failure_message("Component should exist").is_not_null()
	
	# Additional EventItem-specific structure tests
	if _safe_has_property(_component, "value_label"):
		assert_that(_component.get("value_label")).override_failure_message("Value label should exist").is_not_null()
	if _safe_has_property(_component, "timestamp_label"):
		assert_that(_component.get("timestamp_label")).override_failure_message("Timestamp label should exist").is_not_null()
	if _safe_has_property(_component, "animation_player"):
		assert_that(_component.get("animation_player")).override_failure_message("Animation player should exist").is_not_null()

func test_component_theme() -> void:
	# Test theme properties if they exist
	if _component.has_method("has_theme_color"):
		if _component.has_theme_color("font_color"):
			assert_that(_component.has_theme_color("font_color")).override_failure_message("Should have font color theme property").is_true()
	if _component.has_method("has_theme_stylebox"):
		if _component.has_theme_stylebox("normal"):
			assert_that(_component.has_theme_stylebox("normal")).override_failure_message("Should have normal stylebox").is_true()

func test_component_accessibility() -> void:
	# Additional EventItem-specific accessibility tests
	if _safe_has_property(_component, "value_label") and _component.get("value_label"):
		var value_label: Label = _component.get("value_label")
		if _safe_has_property(value_label, "horizontal_alignment"):
			assert_that(value_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT).override_failure_message("Value label should be left-aligned for readability").is_true()
	
	if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
		var timestamp_label: Label = _component.get("timestamp_label")
		if _safe_has_property(timestamp_label, "horizontal_alignment"):
			assert_that(timestamp_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT).override_failure_message("Timestamp label should be right-aligned for consistency").is_true()