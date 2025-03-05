@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe constants with explicit typing
const UIManagerScript: GDScript = preload("res://src/ui/screens/UIManager.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")
const ThemeManagerScript: GDScript = preload("res://src/ui/themes/ThemeManager.gd")

# Type-safe instance variables
var _ui_manager: UIManagerScript
var _mock_game_state: GameState
var _theme_manager: ThemeManagerScript

# Type-safe signal tracking
var _screen_changed_emitted: bool = false
var _dialog_opened_emitted: bool = false
var _dialog_closed_emitted: bool = false
var _theme_applied_emitted: bool = false
var _last_signal_data: Dictionary = {
	"screen_name": "" as String,
	"dialog_name": "" as String,
	"dialog_data": {} as Dictionary
}

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state with type safety
	_mock_game_state = create_test_game_state()
	if not _mock_game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_mock_game_state)
	
	# Initialize UI manager with type safety
	_ui_manager = Node.new()
	if not _ui_manager:
		push_error("Failed to create UI manager")
		return
	_ui_manager.set_script(UIManagerScript)
	add_child_autofree(_ui_manager)
	
	# Initialize theme manager with type safety
	_theme_manager = ThemeManagerScript.new()
	if not _theme_manager:
		push_error("Failed to create theme manager")
		return
	add_child_autofree(_theme_manager)
	
	# Reset signal tracking
	_reset_signal_states()
	_connect_signals()

func after_each() -> void:
	_cleanup_signals()
	await super.after_each()
	_ui_manager = null
	_mock_game_state = null
	_theme_manager = null

# Type-safe signal management
func _reset_signal_states() -> void:
	_screen_changed_emitted = false
	_dialog_opened_emitted = false
	_dialog_closed_emitted = false
	_theme_applied_emitted = false
	_last_signal_data = {
		"screen_name": "",
		"dialog_name": "",
		"dialog_data": {}
	}

func _connect_signals() -> void:
	if _ui_manager != null:
		if _ui_manager.has_signal("screen_changed"):
			_ui_manager.screen_changed.connect(self._on_screen_changed)
			
		if _ui_manager.has_signal("dialog_opened"):
			_ui_manager.dialog_opened.connect(self._on_dialog_opened)
			
		if _ui_manager.has_signal("dialog_closed"):
			_ui_manager.dialog_closed.connect(self._on_dialog_closed)
			
		if _ui_manager.has_signal("theme_applied"):
			_ui_manager.theme_applied.connect(self._on_theme_applied)

func _cleanup_signals() -> void:
	if _signal_watcher:
		_signal_watcher.clear()

# Type-safe signal handlers
func _on_screen_changed(screen_name: String) -> void:
	_screen_changed_emitted = true
	_last_signal_data["screen_name"] = screen_name

func _on_dialog_opened(dialog_name: String, dialog_data: Dictionary = {}) -> void:
	_dialog_opened_emitted = true
	_last_signal_data["dialog_name"] = dialog_name
	_last_signal_data["dialog_data"] = dialog_data

func _on_dialog_closed(dialog_name: String) -> void:
	_dialog_closed_emitted = true
	_last_signal_data["dialog_name"] = dialog_name

func _on_theme_applied(theme_name: String) -> void:
	_theme_applied_emitted = true
	_last_signal_data["theme_name"] = theme_name

# Type-safe test helper methods
func _verify_ui_manager_state(screen_name: String, expected_screen: String, message: String) -> void:
	assert_eq(screen_name, expected_screen, message)
	assert_true(_screen_changed_emitted, "Screen changed signal should be emitted: %s" % message)

func _verify_dialog_state(dialog_name: String, expected_dialog: String, message: String) -> void:
	assert_eq(dialog_name, expected_dialog, message)
	assert_true(_dialog_opened_emitted, "Dialog opened signal should be emitted: %s" % message)

# Type-safe test cases
func test_initial_state() -> void:
	assert_not_null(_ui_manager, "UI Manager should be initialized")
	assert_not_null(_mock_game_state, "Game State should be initialized")
	assert_false(_screen_changed_emitted, "No screen change should be emitted initially")
	assert_false(_dialog_opened_emitted, "No dialog open should be emitted initially")
	assert_false(_dialog_closed_emitted, "No dialog close should be emitted initially")

func test_show_screen() -> void:
	const TEST_SCREEN: String = "main_menu"
	_ui_manager.show_screen(TEST_SCREEN)
	
	assert_true(_screen_changed_emitted, "Screen changed signal should be emitted")
	assert_eq(_last_signal_data["screen_name"], TEST_SCREEN,
		"Screen name should match the requested screen")

func test_hide_screen() -> void:
	const TEST_SCREEN: String = "main_menu"
	_ui_manager.show_screen(TEST_SCREEN)
	_reset_signal_states()
	
	_ui_manager.hide_screen(TEST_SCREEN)
	assert_true(_screen_changed_emitted, "Screen changed signal should be emitted")
	assert_eq(_last_signal_data["screen_name"], "",
		"Screen name should be empty after hiding")

func test_show_dialog() -> void:
	const TEST_DIALOG: String = "confirmation"
	var test_data: Dictionary = {
		"message": "Test message"
	}
	
	_ui_manager.show_dialog(TEST_DIALOG, test_data)
	assert_true(_dialog_opened_emitted, "Dialog opened signal should be emitted")
	assert_eq(_last_signal_data["dialog_name"], TEST_DIALOG,
		"Dialog name should match the requested dialog")
	assert_eq(_last_signal_data["dialog_data"], test_data,
		"Dialog data should match the provided data")

func test_hide_dialog() -> void:
	const TEST_DIALOG: String = "confirmation"
	_ui_manager.show_dialog(TEST_DIALOG)
	_reset_signal_states()
	
	_ui_manager.hide_dialog(TEST_DIALOG)
	assert_true(_dialog_closed_emitted, "Dialog closed signal should be emitted")
	assert_eq(_last_signal_data["dialog_name"], TEST_DIALOG,
		"Dialog name should match the closed dialog")

func test_screen_stack_management() -> void:
	const SCREEN_1: String = "main_menu"
	const SCREEN_2: String = "options"
	
	_ui_manager.show_screen(SCREEN_1)
	_verify_ui_manager_state(_last_signal_data["screen_name"], SCREEN_1,
		"First screen should be shown")
	
	_ui_manager.show_screen(SCREEN_2)
	_verify_ui_manager_state(_last_signal_data["screen_name"], SCREEN_2,
		"Second screen should be shown")
	
	_ui_manager.hide_screen(SCREEN_2)
	_verify_ui_manager_state(_last_signal_data["screen_name"], SCREEN_1,
		"First screen should be restored")

func test_modal_management() -> void:
	const MAIN_SCREEN: String = "main_menu"
	const MODAL_SCREEN: String = "options"
	
	_ui_manager.show_screen(MAIN_SCREEN)
	_reset_signal_states()
	
	_ui_manager.show_modal(MODAL_SCREEN)
	_verify_ui_manager_state(_last_signal_data["screen_name"], MODAL_SCREEN,
		"Modal should be shown")
	
	_ui_manager.hide_modal()
	_verify_ui_manager_state(_last_signal_data["screen_name"], MAIN_SCREEN,
		"Should return to main screen after modal")

func test_screen_transitions() -> void:
	const TEST_SCREEN: String = "main_menu"
	const TRANSITION_TIME: float = 0.1
	
	_ui_manager.show_screen_with_transition(TEST_SCREEN, TRANSITION_TIME)
	await stabilize_engine(TRANSITION_TIME)
	
	_verify_ui_manager_state(_last_signal_data["screen_name"], TEST_SCREEN,
		"Should complete transition to new screen")

func test_cleanup() -> void:
	const TEST_SCREEN: String = "main_menu"
	_ui_manager.show_screen(TEST_SCREEN)
	_reset_signal_states()
	
	_ui_manager.cleanup()
	_verify_ui_manager_state(_last_signal_data["screen_name"], "",
		"Should clear current screen")
	assert_false(_ui_manager.has_modal, "Should clear modals")
	assert_eq(_ui_manager.screen_stack.size(), 0, "Should clear screen stack")

# Additional tests for theme support
func test_theme_manager_integration() -> void:
	# Test connecting the theme manager
	_ui_manager.connect_theme_manager(_theme_manager)
	assert_not_null(_ui_manager.theme_manager, "Theme manager should be connected to UI manager")

func test_theme_application() -> void:
	# Test applying a theme
	_ui_manager.apply_theme("dark")
	
	# Verify signal emission and theme change
	assert_true(_theme_applied_emitted, "theme_applied signal should be emitted")
	assert_eq(_last_signal_data["theme_name"], "dark", "Correct theme name should be in signal data")
	assert_eq(_theme_manager.current_theme_name, "dark", "Theme should be changed on the theme manager")

func test_ui_scale_setting() -> void:
	# Test setting UI scale
	var test_scale = 1.2
	_ui_manager.set_ui_scale(test_scale)
	
	# Verify scale change
	assert_eq(_theme_manager.ui_scale, test_scale, "UI scale should be updated on the theme manager")

func test_accessibility_settings() -> void:
	# Test high contrast setting
	_ui_manager.set_high_contrast(true)
	assert_true(_theme_manager.high_contrast_enabled, "High contrast should be enabled")
	
	# Test animations setting
	_ui_manager.toggle_animations(false)
	assert_false(_theme_manager.animations_enabled, "Animations should be disabled")
	
	# Test text size setting
	_ui_manager.set_text_size("large")
	assert_eq(_theme_manager.get_text_scale(), 1.4, "Text scale should be set to large")

func test_theme_persistence() -> void:
	# Set theme and verify it's saved
	_ui_manager.apply_theme("dark")
	assert_eq(_ui_manager.get_current_theme(), "dark", "Current theme should be correctly reported")
	
	# Test persisting settings
	_ui_manager.save_ui_settings()
	
	# Create a new UI manager to simulate app restart
	var new_ui_manager = UIManagerScript.new()
	add_child(new_ui_manager)
	new_ui_manager.connect_theme_manager(_theme_manager)
	
	# Load settings and verify theme is restored
	new_ui_manager.load_ui_settings()
	assert_eq(new_ui_manager.get_current_theme(), "dark", "Theme should be restored from saved settings")
	
	# Clean up
	new_ui_manager.queue_free()
	_theme_manager.queue_free()