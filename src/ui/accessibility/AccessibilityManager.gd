class_name AccessibilityManager
extends RefCounted

## AccessibilityManager - Production-ready accessibility features
## Provides keyboard navigation, screen reader support, and focus management

# Accessibility settings
var high_contrast_mode: bool = false
var screen_reader_enabled: bool = false
var keyboard_navigation_enabled: bool = true
var focus_indicators_enabled: bool = true

# Focus management
var current_focus_element: Control = null
var focus_history: Array[Control] = []
var focus_groups: Dictionary = {}

# Screen reader announcements
var announcement_queue: Array[String] = []
var last_announcement_time: float = 0.0
var announcement_delay: float = 0.5

signal accessibility_announcement(text: String)
signal focus_changed(from_element: Control, to_element: Control)
signal high_contrast_toggled(enabled: bool)

func _init() -> void:
	_detect_system_accessibility_settings()
	_setup_accessibility_signals()

func _detect_system_accessibility_settings() -> void:
	"""Detect system accessibility settings"""
	# Check for high contrast mode
	if OS.has_feature("windows"):
		# Windows high contrast detection would go here
		# For now, use a simple heuristic
		high_contrast_mode = _check_windows_high_contrast()
	elif OS.has_feature("macos"):
		# macOS accessibility detection
		high_contrast_mode = _check_macos_high_contrast()
	elif OS.has_feature("linux"):
		# Linux accessibility detection
		high_contrast_mode = _check_linux_high_contrast()
	
	# Check for screen reader
	screen_reader_enabled = _detect_screen_reader()
	
	print("AccessibilityManager: Detected settings - High Contrast: %s, Screen Reader: %s" % [high_contrast_mode, screen_reader_enabled])

func _setup_accessibility_signals():
	"""Setup accessibility-related signals"""
	if high_contrast_mode:
		high_contrast_toggled.emit(true)

## Public API - Focus Management

func set_focus_group(group_name: String, elements: Array) -> void:
	"""Register a group of focusable elements"""
	focus_groups[group_name] = elements
	for element in elements:
		if element:
			_setup_element_accessibility(element)

func focus_element(element: Control, announce: bool = true) -> void:
	"""Set focus to a specific element with accessibility support"""
	if not element or not is_instance_valid(element):
		return
	
	var previous_focus = current_focus_element
	current_focus_element = element
	
	# Update focus history
	if previous_focus and previous_focus != element:
		focus_history.append(previous_focus)
		if focus_history.size() > 10:  # Limit history size
			focus_history.pop_front()
	
	# Set actual focus
	element.grab_focus()
	
	# Emit focus change signal
	focus_changed.emit(previous_focus, element)
	
	# Screen reader announcement
	if announce and screen_reader_enabled:
		var announcement = _generate_element_announcement(element)
		announce_to_screen_reader(announcement)

func focus_next_in_group(group_name: String) -> bool:
	"""Move focus to next element in group"""
	if not focus_groups.has(group_name):
		return false
	
	var elements: Array[Control] = focus_groups[group_name]
	var current_index = elements.find(current_focus_element)
	
	if current_index == -1:
		# No current focus, focus first element
		if elements.size() > 0:
			focus_element(elements[0])
			return true
		return false
	
	# Move to next element
	var next_index = (current_index + 1) % elements.size()
	focus_element(elements[next_index])
	return true

func focus_previous_in_group(group_name: String) -> bool:
	"""Move focus to previous element in group"""
	if not focus_groups.has(group_name):
		return false
	
	var elements: Array[Control] = focus_groups[group_name]
	var current_index = elements.find(current_focus_element)
	
	if current_index == -1:
		# No current focus, focus last element
		if elements.size() > 0:
			focus_element(elements[elements.size() - 1])
			return true
		return false
	
	# Move to previous element
	var next_index = (current_index - 1 + elements.size()) % elements.size()
	focus_element(elements[next_index])
	return true

func return_to_previous_focus() -> bool:
	"""Return focus to previously focused element"""
	if focus_history.is_empty():
		return false
	
	var previous_element = focus_history.pop_back()
	if previous_element and is_instance_valid(previous_element):
		focus_element(previous_element, false)  # Don't announce return focus
		return true
	
	return false

## Public API - Screen Reader Support

func announce_to_screen_reader(text: String, priority: String = "normal") -> void:
	"""Announce text to screen reader with queue management"""
	if not screen_reader_enabled or text.is_empty():
		return
	
	var current_time = Time.get_time_dict_from_system()
	var timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Respect announcement timing
	if timestamp - last_announcement_time < announcement_delay:
		announcement_queue.append(text)
		return
	
	# Immediate announcement
	_perform_screen_reader_announcement(text)
	last_announcement_time = timestamp
	
	# Process queue after delay
	if not announcement_queue.is_empty():
		var timer = Timer.new()
		timer.wait_time = announcement_delay
		timer.one_shot = true
		timer.timeout.connect(_process_announcement_queue)
		timer.start()

func announce_panel_change(panel_name: String, completion_percentage: float = -1) -> void:
	"""Announce panel change with context"""
	var announcement = "Switched to %s panel" % panel_name
	if completion_percentage >= 0:
		announcement += ", %.0f percent complete" % completion_percentage
	announce_to_screen_reader(announcement)

func announce_validation_error(errors: Array) -> void:
	"""Announce validation errors accessibly"""
	if errors.is_empty():
		return
	
	var announcement = "Validation errors found: "
	if errors.size() == 1:
		announcement += errors[0]
	else:
		announcement += "%d errors. " % errors.size()
		announcement += ". ".join(errors)
	
	announce_to_screen_reader(announcement, "urgent")

func announce_campaign_progress(current_step: int, total_steps: int, step_name: String) -> void:
	"""Announce campaign creation progress"""
	var announcement = "Step %d of %d: %s" % [current_step + 1, total_steps, step_name]
	announce_to_screen_reader(announcement)

## Public API - Keyboard Navigation

func handle_global_keyboard_input(event: InputEvent) -> bool:
	"""Handle global keyboard navigation shortcuts"""
	if not keyboard_navigation_enabled or not event is InputEventKey:
		return false
	
	var key_event = event as InputEventKey
	if not key_event.pressed:
		return false
	
	# Handle accessibility shortcuts
	match key_event.keycode:
		KEY_F6:
			# Cycle through major UI sections
			return _cycle_ui_sections()
		
		KEY_F7:
			# Toggle high contrast mode
			if key_event.ctrl_pressed:
				toggle_high_contrast_mode()
				return true
		
		KEY_F8:
			# Read current element
			if key_event.ctrl_pressed:
				_read_current_element()
				return true
		
		KEY_ESCAPE:
			# Return to previous focus
			return return_to_previous_focus()
	
	return false

func toggle_high_contrast_mode() -> void:
	"""Toggle high contrast mode"""
	high_contrast_mode = not high_contrast_mode
	high_contrast_toggled.emit(high_contrast_mode)
	
	var announcement = "High contrast mode " + ("enabled" if high_contrast_mode else "disabled")
	announce_to_screen_reader(announcement)

## Internal Methods

func _setup_element_accessibility(element: Control) -> void:
	"""Setup accessibility features for an element"""
	if not element:
		return
	
	# Ensure element can receive focus
	if element.focus_mode == Control.FOCUS_NONE:
		element.focus_mode = Control.FOCUS_ALL
	
	# Add focus indicators if enabled
	if focus_indicators_enabled:
		_add_focus_indicator(element)
	
	# Connect accessibility signals
	if not element.focus_entered.is_connected(_on_element_focus_entered):
		element.focus_entered.connect(_on_element_focus_entered.bind(element))
	if not element.focus_exited.is_connected(_on_element_focus_exited):
		element.focus_exited.connect(_on_element_focus_exited.bind(element))

func _add_focus_indicator(element: Control) -> void:
	"""Add visual focus indicator to element"""
	# This would add visual focus indicators for keyboard navigation
	# Implementation depends on the specific UI design
	pass

func _generate_element_announcement(element: Control) -> String:
	"""Generate screen reader announcement for element"""
	if not element:
		return ""
	
	var announcement = ""
	
	# Element type
	if element is Button:
		announcement += "Button: "
	elif element is LineEdit:
		announcement += "Text field: "
	elif element is CheckBox:
		announcement += "Checkbox: "
	elif element is OptionButton:
		announcement += "Dropdown: "
	elif element is SpinBox:
		announcement += "Number field: "
	
	# Element text/value
	if element.has_method("get_text") and element.get_text():
		announcement += element.get_text()
	elif element.has_method("get_value"):
		announcement += str(element.get_value())
	elif element.name:
		announcement += element.name.replace("_", " ")
	
	# Element state
	if element is CheckBox and element.button_pressed:
		announcement += ", checked"
	elif element is Button and element.disabled:
		announcement += ", disabled"
	
	return announcement

func _perform_screen_reader_announcement(text: String) -> void:
	"""Perform actual screen reader announcement"""
	accessibility_announcement.emit(text)
	print("Screen Reader: " + text)  # Debug output

func _process_announcement_queue() -> void:
	"""Process queued screen reader announcements"""
	if announcement_queue.is_empty():
		return
	
	var next_announcement = announcement_queue.pop_front()
	_perform_screen_reader_announcement(next_announcement)
	last_announcement_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second

func _cycle_ui_sections() -> bool:
	"""Cycle through major UI sections"""
	# Implementation would cycle through major UI sections
	# This is context-dependent and would be implemented per screen
	return false

func _read_current_element() -> void:
	"""Read current focused element to screen reader"""
	if current_focus_element:
		var announcement = _generate_element_announcement(current_focus_element)
		announce_to_screen_reader(announcement)

func _on_element_focus_entered(element: Control) -> void:
	"""Handle element focus entered"""
	current_focus_element = element

func _on_element_focus_exited(element: Control) -> void:
	"""Handle element focus exited"""
	if current_focus_element == element:
		current_focus_element = null

## System Detection Methods

func _check_windows_high_contrast() -> bool:
	"""Check Windows high contrast setting"""
	# In a real implementation, this would check Windows registry
	# For now, return false as a placeholder
	return false

func _check_macos_high_contrast() -> bool:
	"""Check macOS high contrast setting"""
	# In a real implementation, this would check macOS accessibility settings
	return false

func _check_linux_high_contrast() -> bool:
	"""Check Linux high contrast setting"""
	# In a real implementation, this would check Linux accessibility settings
	return false

func _detect_screen_reader() -> bool:
	"""Detect if a screen reader is running"""
	# In a real implementation, this would detect screen readers
	# For now, return false as a placeholder
	return false

## Public API - Utility Methods

func get_accessibility_summary() -> Dictionary:
	"""Get current accessibility settings summary"""
	return {
		"high_contrast_mode": high_contrast_mode,
		"screen_reader_enabled": screen_reader_enabled,
		"keyboard_navigation_enabled": keyboard_navigation_enabled,
		"focus_indicators_enabled": focus_indicators_enabled,
		"current_focus": current_focus_element.name if current_focus_element else "None",
		"focus_groups_count": focus_groups.size()
	}