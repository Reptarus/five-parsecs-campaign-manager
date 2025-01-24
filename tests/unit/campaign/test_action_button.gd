extends "res://addons/gut/test.gd"

const ActionButton = preload("res://src/scenes/campaign/components/ActionButton.gd")

var button: ActionButton
var pressed_signal_emitted := false
var hovered_signal_emitted := false
var unhovered_signal_emitted := false

func before_each() -> void:
	button = ActionButton.new()
	add_child(button)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	button.queue_free()

func _reset_signals() -> void:
	pressed_signal_emitted = false
	hovered_signal_emitted = false
	unhovered_signal_emitted = false

func _connect_signals() -> void:
	button.action_pressed.connect(_on_action_pressed)
	button.action_hovered.connect(_on_action_hovered)
	button.action_unhovered.connect(_on_action_unhovered)

func _on_action_pressed() -> void:
	pressed_signal_emitted = true

func _on_action_hovered() -> void:
	hovered_signal_emitted = true

func _on_action_unhovered() -> void:
	unhovered_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(button)
	assert_not_null(button.icon_rect)
	assert_not_null(button.label)
	assert_eq(button.action_name, "")
	assert_null(button.action_icon)
	assert_true(button.is_enabled)

func test_setup() -> void:
	var test_name = "Test Action"
	var test_color = Color(1, 0, 0) # Red
	
	button.setup(test_name, null, true, test_color)
	
	assert_eq(button.action_name, test_name)
	assert_null(button.action_icon)
	assert_true(button.is_enabled)
	assert_eq(button.action_color, test_color)

func test_button_press() -> void:
	button.setup("Test Action", null, true)
	button._on_button_pressed()
	
	assert_true(pressed_signal_emitted)

func test_disabled_state() -> void:
	button.setup("Test Action", null, false)
	
	assert_false(button.is_enabled)
	assert_true(button.button.disabled)

func test_hover_state() -> void:
	button.setup("Test Action", null, true)
	button._on_button_mouse_entered()
	
	assert_true(hovered_signal_emitted)
	button._on_button_mouse_exited()
	assert_true(unhovered_signal_emitted)

func test_long_text_handling() -> void:
	var long_name = "Very Long Action Name That Should Be Handled Properly"
	
	button.setup(long_name, null, true)
	
	assert_eq(button.action_name, long_name)
	assert_eq(button.label.text, long_name.capitalize())

func test_color_handling() -> void:
	var test_colors = [
		Color(1, 0, 0), # Red
		Color(0, 1, 0), # Green
		Color(0, 0, 1), # Blue
		Color(1, 1, 1), # White
		Color(0, 0, 0) # Black
	]
	
	for color in test_colors:
		button.setup("Test", null, true, color)
		assert_eq(button.action_color, color)

func test_empty_values() -> void:
	button.setup("", null, true)
	
	assert_eq(button.action_name, "")
	assert_null(button.action_icon)
	assert_true(button.is_enabled)

func test_cooldown() -> void:
	button.setup("Test Action", null, true)
	button.start_cooldown(1.0)
	
	assert_false(button.is_enabled)
	assert_eq(button.cooldown_progress, 0.0)
	
	# Test progress update
	button.set_progress(0.5)
	assert_eq(button.cooldown_progress, 0.5)
	
	# Test reset
	button.reset_cooldown()
	assert_true(button.is_enabled)
	assert_eq(button.cooldown_progress, 1.0)

func test_icon_handling() -> void:
	var test_icon = PlaceholderTexture2D.new()
	button.setup("Test Action", test_icon, true)
	
	assert_eq(button.action_icon, test_icon)
	assert_true(button.icon_rect.visible)