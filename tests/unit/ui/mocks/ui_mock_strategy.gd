@tool
extends RefCounted
class_name UIMockStrategy

# ========================================
# UNIVERSAL UI MOCK STRATEGY - SIMPLIFIED
# ========================================
# Simplified version focused on essential functionality

# ========================================
# MOCK TIMER
#
class MockTimer extends RefCounted:
    signal timeout
	
    var mock_wait_time: float = 0.0
    var _completed: bool = false
	
	func mock_start(time_sec: float = -1) -> void:
		if time_sec > 0:
    mock_wait_time = time_sec
		#
		call_deferred("_complete_timer")
	
	func mock_stop() -> void:
    _completed = true
	
	func _complete_timer() -> void:
		if not _completed:
    _completed = true
			timeout.emit()

# ========================================
# MOCK ACTION BUTTON
#
class MockActionButton extends Control:
    signal action_pressed
    signal action_hovered
    signal action_unhovered
    signal button_pressed
    signal clicked
	
    var action_name: String = ""
    var is_enabled: bool = true
    var cooldown_progress: float = 1.0
    var action_color: Color = Color.WHITE
    var text: String = ""
    var disabled: bool = false
	
	func setup(action_name_param: String, p_icon: Texture = null, enabled: bool = true, color: Color = Color.WHITE) -> void:
		self.action_name = action_name_param
		self.is_enabled = enabled
		self.action_color = color
	
	func start_cooldown(duration: float) -> void:
    cooldown_progress = 0.0
    is_enabled = false
	
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
    var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if is_enabled and not disabled:
					action_pressed.emit()

# ========================================
# FACTORY FUNCTIONS
#
static func create_mock_action_button() -> MockActionButton:
	return MockActionButton.new()

static func create_mock_timer(duration: float = 1.0) -> MockTimer:
    var timer: MockTimer = MockTimer.new()
	timer.mock_wait_time = duration
	return timer
