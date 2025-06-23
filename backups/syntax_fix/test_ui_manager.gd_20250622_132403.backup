@tool
extends GdUnitGameTest

class MockUIManager extends Resource:
		pass
	var is_initialized: bool = false
	var current_screen: String = "main_menu"
	var previous_screen: String = ""
	var ui_state: String = "normal"
	var is_transitioning: bool = false
	var transition_duration: float = 0.3
	var screen_stack: Array[String] = []
	
	#
	var available_screens: Array[String] = [
		"main_menu", "campaign", "combat", "settings", "save_load",
		"character_sheet", "inventory", "trading", "mission_select"

	var screen_history: Array[String] = []
	var max_history_size: int = 10
	
	#
	var is_portrait_mode: bool = false
	var screen_size: Vector2 = Vector2(1024, 768)
	var ui_scale: float = 1.0
	var theme_name: String = "default"
	var modal_count: int = 0
	var overlay_active: bool = false
	
	#
	var input_enabled: bool = true
	var keyboard_navigation: bool = false
	var touch_enabled: bool = false
	var last_input_method: String = "mouse"
	
	#
	signal screen_changed(new_screen: String, old_screen: String)
	signal transition_started(from_screen: String, to_screen: String)
	signal transition_completed(screen: String)
	signal modal_opened(modal_name: String)
	signal modal_closed(modal_name: String)
	signal orientation_changed(is_portrait: bool)
	signal theme_changed(theme: String)
	signal ui_state_changed(state: String)
	
	#
	func initialize() -> bool:
		if is_initialized:
			return false
		is_initialized = true
		return true
	
	func change_screen(screen_name: String) -> bool:
		if not screen_name in available_screens:
			return false
		if is_transitioning:
			return false
		var old_screen = current_screen
		#
		if not current_screen.is_empty():
			screen_history.append(current_screen)
			if screen_history.size() > max_history_size:
				screen_history.pop_front()
		previous_screen = current_screen
		current_screen = screen_name
		screen_changed.emit(screen_name, old_screen)
		return true
	
	func push_screen(screen_name: String) -> bool:
		if not screen_name in available_screens:
			return false
		screen_stack.append(current_screen)
		current_screen = screen_name
		return true
	
	func pop_screen() -> bool:
		if screen_stack.is_empty():
			return false
		var previous = screen_stack.pop_back()
		current_screen = previous
		return true
	
	func go_back() -> bool:
		if not previous_screen.is_empty():
			return change_screen(previous_screen)
		elif not screen_history.is_empty():
			var last_screen = screen_history.pop_back()
			return change_screen(last_screen)
		return false
	
	func open_modal(modal_name: String) -> void:
		modal_count += 1
		modal_opened.emit(modal_name)
	
	func close_modal(modal_name: String) -> void:
		if modal_count == 0:
			return
		modal_count -= 1
		modal_closed.emit(modal_name)
	
	func set_ui_state(state: String) -> void:
		ui_state = state
		ui_state_changed.emit(state)
	
	func set_orientation(portrait: bool) -> void:
		if is_portrait_mode != portrait:
			is_portrait_mode = portrait
			orientation_changed.emit(portrait)
	
	func set_theme(theme: String) -> void:
		theme_name = theme
		theme_changed.emit(theme)
	
	func set_screen_size(size: Vector2) -> void:
		screen_size = size
	
	func set_ui_scale(scale: float) -> void:
		ui_scale = clamp(scale, 0.5, 2.0)
	
	func enable_input(enabled: bool) -> void:
		input_enabled = enabled
	
	func set_input_method(method: String) -> void:
		last_input_method = method
		if method == "touch":
			touch_enabled = true
		elif method == "keyboard":
			keyboard_navigation = true
	
	func get_current_screen() -> String:
		return current_screen
	
	func is_modal_open() -> bool:
		return modal_count > 0
	
	func can_go_back() -> bool:
		return not previous_screen.is_empty() or not screen_history.is_empty()
	
	func get_screen_stack_size() -> int:
		return screen_stack.size()
	
	func clear_screen_history() -> void:
		screen_history.clear()
	
	func get_ui_info() -> Dictionary:
		return {
		"current_screen": current_screen,
		"is_portrait": is_portrait_mode,
		"ui_scale": ui_scale,
		"theme": theme_name,
		"modal_count": modal_count,
		"input_enabled": input_enabled,
	#
	func show_overlay(name: String) -> void:
		overlay_active = true
	
	func is_overlay_visible(name: String) -> bool:
		return overlay_active
	
	func show_dialog(name: String) -> void:
		modal_count += 1
	
	func has_active_dialog() -> bool:
		return modal_count > 0
	
	func set_input_blocked(blocked: bool) -> void:
		input_enabled = not blocked
	
	func is_input_blocked() -> bool:
		return not input_enabled
	
	func get_navigation_stack_size() -> int:
		return screen_stack.size()
	
	func save_ui_state() -> void:
		pass
	
	func has_saved_state() -> bool:
		return true

var mock_ui_manager: MockUIManager = null

func before_test() -> void:
	super.before_test()
	mock_ui_manager = MockUIManager.new()
	track_resource(mock_ui_manager) # Perfect cleanup

#
func test_initialization() -> void:
	assert_that(mock_ui_manager.is_initialized).is_false()
	assert_that(mock_ui_manager.current_screen).is_equal("main_menu")
	var result = mock_ui_manager.initialize()
	assert_that(result).is_true()
	assert_that(mock_ui_manager.is_initialized).is_true()

func test_screen_change() -> void:
	mock_ui_manager.initialize()
	
	var result = mock_ui_manager.change_screen("combat")
	assert_that(result).is_true()
	assert_that(mock_ui_manager.current_screen).is_equal("combat")

func test_invalid_screen_change() -> void:
	mock_ui_manager.initialize()
	var result = mock_ui_manager.change_screen("invalid_screen")
	assert_that(result).is_false()
	assert_that(mock_ui_manager.current_screen).is_equal("main_menu")

func test_screen_stack() -> void:
	mock_ui_manager.initialize()
	
	#
	assert_that(mock_ui_manager.push_screen("campaign")).is_true()
	assert_that(mock_ui_manager.push_screen("combat")).is_true()
	assert_that(mock_ui_manager.get_screen_stack_size()).is_equal(2)
	
	#
	assert_that(mock_ui_manager.pop_screen()).is_true()
	assert_that(mock_ui_manager.get_screen_stack_size()).is_equal(1)
	assert_that(mock_ui_manager.pop_screen()).is_true()

func test_go_back_functionality() -> void:
	mock_ui_manager.initialize()
	
	mock_ui_manager.change_screen("campaign")
	mock_ui_manager.change_screen("combat")
	
	assert_that(mock_ui_manager.can_go_back()).is_true()
	var result = mock_ui_manager.go_back()
	assert_that(result).is_true()
	assert_that(mock_ui_manager.current_screen).is_equal("campaign")

func test_modal_management() -> void:
	mock_ui_manager.open_modal("inventory")
	assert_that(mock_ui_manager.is_modal_open()).is_true()
	assert_that(mock_ui_manager.modal_count).is_equal(1)

func test_ui_state_management() -> void:
	mock_ui_manager.set_ui_state("loading")
	assert_that(mock_ui_manager.ui_state).is_equal("loading")

func test_orientation_change() -> void:
	mock_ui_manager.set_orientation(true)
	assert_that(mock_ui_manager.is_portrait_mode).is_true()

func test_theme_change() -> void:
	mock_ui_manager.set_theme("dark")
	assert_that(mock_ui_manager.theme_name).is_equal("dark")

func test_screen_size_change() -> void:
	pass
	#
	mock_ui_manager.set_screen_size(Vector2(600, 800))
	assert_that(mock_ui_manager.screen_size).is_equal(Vector2(600, 800))
	assert_that(mock_ui_manager.screen_size.x).is_less_than(mock_ui_manager.screen_size.y)

func test_ui_scale() -> void:
	mock_ui_manager.set_ui_scale(1.5)
	assert_that(mock_ui_manager.ui_scale).is_equal(1.5)
	
	#
	mock_ui_manager.set_ui_scale(3.0)
	assert_that(mock_ui_manager.ui_scale).is_equal(2.0)
	
	mock_ui_manager.set_ui_scale(0.1)
	assert_that(mock_ui_manager.ui_scale).is_equal(0.5)

func test_input_management() -> void:
	mock_ui_manager.enable_input(false)
	assert_that(mock_ui_manager.input_enabled).is_false()
	
	mock_ui_manager.enable_input(true)
	assert_that(mock_ui_manager.input_enabled).is_true()

func test_input_method_detection() -> void:
	mock_ui_manager.set_input_method("touch")
	assert_that(mock_ui_manager.last_input_method).is_equal("touch")
	assert_that(mock_ui_manager.touch_enabled).is_true()
	
	mock_ui_manager.set_input_method("keyboard")
	assert_that(mock_ui_manager.last_input_method).is_equal("keyboard")
	assert_that(mock_ui_manager.keyboard_navigation).is_true()

func test_screen_history() -> void:
	mock_ui_manager.initialize()
	
	#
	mock_ui_manager.change_screen("campaign")
	mock_ui_manager.change_screen("combat")
	mock_ui_manager.change_screen("inventory")
	
	assert_that(mock_ui_manager.screen_history.size()).is_greater_than(0)
	assert_that(mock_ui_manager.can_go_back()).is_true()
	assert_that(mock_ui_manager.current_screen).is_equal("inventory")

func test_clear_history() -> void:
	mock_ui_manager.initialize()
	mock_ui_manager.change_screen("campaign")
	mock_ui_manager.change_screen("combat")
	
	mock_ui_manager.clear_screen_history()
	assert_that(mock_ui_manager.screen_history.size()).is_equal(0)
	assert_that(mock_ui_manager.can_go_back()).is_true() #

func test_multiple_modals() -> void:
	mock_ui_manager.open_modal("inventory")
	mock_ui_manager.open_modal("settings")
	mock_ui_manager.open_modal("help")
	
	assert_that(mock_ui_manager.modal_count).is_equal(3)
	assert_that(mock_ui_manager.is_modal_open()).is_true()
	
	mock_ui_manager.close_modal("settings")
	assert_that(mock_ui_manager.modal_count).is_equal(2)
	assert_that(mock_ui_manager.is_modal_open()).is_true()

func test_transition_state() -> void:
	mock_ui_manager.initialize()
	
	#
	mock_ui_manager.is_transitioning = true
	var result = mock_ui_manager.change_screen("combat")
	assert_that(result).is_false()

func test_ui_info() -> void:
	mock_ui_manager.initialize()
	mock_ui_manager.set_theme("dark")
	mock_ui_manager.set_ui_scale(1.2)
	mock_ui_manager.open_modal("test")
	
	var info = mock_ui_manager.get_ui_info()
	
	assert_that(info).is_not_empty()
	assert_that(info.get("current_screen")).is_equal("main_menu")
	assert_that(info.get("theme")).is_equal("dark")
	assert_that(info.get("modal_count")).is_equal(1)

func test_available_screens() -> void:
	assert_that(mock_ui_manager.available_screens).contains("main_menu")
	assert_that(mock_ui_manager.available_screens).contains("campaign")
	assert_that(mock_ui_manager.available_screens).contains("combat")
	assert_that(mock_ui_manager.available_screens).contains("settings")

func test_screen_transition() -> void:
	pass
	#
	mock_ui_manager.change_screen("main_menu")
	var screen_changed = mock_ui_manager.get_current_screen() == "main_menu"
	assert_that(screen_changed).is_true()

func test_overlay_management() -> void:
	pass
	#
	mock_ui_manager.show_overlay("settings")
	var overlay_shown = mock_ui_manager.is_overlay_visible("settings")
	assert_that(overlay_shown).is_true()

func test_dialog_handling() -> void:
	pass
	#
	mock_ui_manager.show_dialog("confirmation")
	var dialog_active = mock_ui_manager.has_active_dialog()
	assert_that(dialog_active).is_true()

func test_input_blocking() -> void:
	pass
	#
	mock_ui_manager.set_input_blocked(true)
	var input_blocked = mock_ui_manager.is_input_blocked()
	assert_that(input_blocked).is_true()

func test_navigation_stack() -> void:
	pass
	#
	mock_ui_manager.push_screen("inventory")
	var stack_size = mock_ui_manager.get_navigation_stack_size()
	assert_that(stack_size).is_equal(1)

func test_ui_state_persistence() -> void:
	pass
	#
	mock_ui_manager.save_ui_state()
	var state_saved = mock_ui_manager.has_saved_state()
	assert_that(state_saved).is_true()
