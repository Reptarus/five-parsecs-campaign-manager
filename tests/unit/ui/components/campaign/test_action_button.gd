@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

const ActionButton: PackedScene = preload("res://src/scenes/campaign/components/ActionButton.tscn")

# Test variables with explicit types
var clicked_signal_emitted: bool = false
var last_click_data: Dictionary = {}

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return ActionButton.instantiate()

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	clicked_signal_emitted = false
	last_click_data.clear()

func _reset_signals() -> void:
	clicked_signal_emitted = false
	last_click_data.clear()

func _connect_signals() -> void:
	if not _component:
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("clicked"):
		_component.clicked.connect(_on_button_clicked)

func _on_button_clicked(data: Dictionary = {}) -> void:
	clicked_signal_emitted = true
	last_click_data = data

func test_initial_state() -> void:
	assert_not_null(_component, "Button should be initialized")
	assert_false(_component.disabled, "Button should be enabled by default")
	assert_false(_component.visible, "Button should be hidden by default")

func test_button_click() -> void:
	_component.visible = true
	_component.disabled = false
	
	_component.emit_signal("pressed")
	assert_true(clicked_signal_emitted, "Click signal should be emitted")

func test_disabled_state() -> void:
	_component.disabled = true
	_component.emit_signal("pressed")
	assert_false(clicked_signal_emitted, "Click signal should not be emitted when disabled")

func test_button_text() -> void:
	var test_text := "Test Button"
	_call_node_method_bool(_component, "set_text", [test_text])
	
	var button_text: String = _call_node_method_string(_component, "get_text", [], "")
	assert_eq(button_text, test_text, "Button text should match")

func test_button_icon() -> void:
	var test_icon := PlaceholderTexture2D.new()
	test_icon.size = Vector2(32, 32)
	_call_node_method_bool(_component, "set_icon", [test_icon])
	
	var button_icon: Texture2D = _call_node_method_object(_component, "get_icon", [], null) as Texture2D
	assert_eq(button_icon, test_icon, "Button icon should match")

func test_button_style() -> void:
	var test_style := "primary"
	_call_node_method_bool(_component, "set_style", [test_style])
	
	var button_style: String = _call_node_method_string(_component, "get_style", [], "")
	assert_eq(button_style, test_style, "Button style should match")

func test_button_size() -> void:
	var test_size := "large"
	_call_node_method_bool(_component, "set_size", [test_size])
	
	var button_size: String = _call_node_method_string(_component, "get_size", [], "")
	assert_eq(button_size, test_size, "Button size should match")

func test_button_tooltip() -> void:
	var test_tooltip := "Test Tooltip"
	_call_node_method_bool(_component, "set_tooltip", [test_tooltip])
	
	var button_tooltip: String = _call_node_method_string(_component, "get_tooltip", [], "")
	assert_eq(button_tooltip, test_tooltip, "Button tooltip should match")

# Add inherited component tests
func test_component_structure() -> void:
	await super.test_component_structure()
	
	# Additional ActionButton-specific structure tests
	assert_true(_component.has_method("set_text"), "Should have set_text method")
	assert_true(_component.has_method("get_text"), "Should have get_text method")
	assert_true(_component.has_method("set_icon"), "Should have set_icon method")
	assert_true(_component.has_method("get_icon"), "Should have get_icon method")

func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional ActionButton-specific theme tests
	assert_true(_component.has_theme_stylebox("normal"), "Should have normal stylebox")
	assert_true(_component.has_theme_stylebox("hover"), "Should have hover stylebox")
	assert_true(_component.has_theme_stylebox("pressed"), "Should have pressed stylebox")
	assert_true(_component.has_theme_stylebox("disabled"), "Should have disabled stylebox")

func test_component_accessibility() -> void:
	await super.test_component_accessibility()
	
	# Additional ActionButton-specific accessibility tests
	assert_true(_component.focus_mode != Control.FOCUS_NONE,
		"Button should be focusable for keyboard navigation")
	assert_true(_component.size.x >= MIN_TOUCH_TARGET_SIZE and _component.size.y >= MIN_TOUCH_TARGET_SIZE,
		"Button should meet minimum touch target size requirements")