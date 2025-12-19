extends GdUnitTestSuite

## Unit tests for ThemeManager
## Validates theme switching, persistence, and color accessors

var theme_manager: Node

func before_test() -> void:
	"""Setup before each test"""
	# ThemeManager extends Node, so we need to instantiate it properly
	var ThemeManagerClass = load("res://src/ui/themes/ThemeManager.gd")
	theme_manager = auto_free(ThemeManagerClass.new())
	# Add to scene tree so _ready() can execute
	add_child(theme_manager)
	# Call _ready manually since await might not work in tests
	if theme_manager.has_method("_ready"):
		theme_manager._ready()

func after_test() -> void:
	"""Cleanup after each test"""
	# Node will be auto-freed by auto_free(), just remove from tree
	if theme_manager and is_instance_valid(theme_manager):
		remove_child(theme_manager)
	theme_manager = null

func test_theme_manager_can_apply_dark_theme() -> void:
	"""Test that ThemeManager can apply DARK theme correctly"""
	# Note: ThemeManager loads saved settings on init, so we explicitly apply DARK
	theme_manager.apply_theme(ThemeManager.ThemeVariant.DARK)
	assert_that(theme_manager.get_current_theme()).is_equal(ThemeManager.ThemeVariant.DARK)

func test_apply_theme_changes_current_theme() -> void:
	"""Test that apply_theme changes the current theme"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.LIGHT)
	assert_that(theme_manager.get_current_theme()).is_equal(ThemeManager.ThemeVariant.LIGHT)

func test_get_color_returns_correct_color_for_dark_theme() -> void:
	"""Test that get_color returns correct colors from dark theme"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.DARK)
	
	var base_color = theme_manager.get_color("base")
	assert_that(base_color).is_equal(Color("#0a0d14"))
	
	var accent_color = theme_manager.get_color("accent")
	assert_that(accent_color).is_equal(Color("#3b82f6"))

func test_get_color_returns_correct_color_for_light_theme() -> void:
	"""Test that get_color returns correct colors from light theme"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.LIGHT)
	
	var base_color = theme_manager.get_color("base")
	assert_that(base_color).is_equal(Color("#f5f5f5"))
	
	var text_primary = theme_manager.get_color("text_primary")
	assert_that(text_primary).is_equal(Color("#1f2937"))

func test_get_font_size_returns_correct_sizes() -> void:
	"""Test that get_font_size returns expected sizes"""
	assert_that(theme_manager.get_font_size("xs")).is_equal(11)
	assert_that(theme_manager.get_font_size("sm")).is_equal(14)
	assert_that(theme_manager.get_font_size("md")).is_equal(16)
	assert_that(theme_manager.get_font_size("lg")).is_equal(18)
	assert_that(theme_manager.get_font_size("xl")).is_equal(24)

func test_get_font_size_scales_with_scale_factor() -> void:
	"""Test that font sizes scale correctly with scale factor"""
	theme_manager.set_scale_factor(1.5)
	
	assert_that(theme_manager.get_font_size("md")).is_equal(24)  # 16 * 1.5
	assert_that(theme_manager.get_font_size("lg")).is_equal(27)  # 18 * 1.5

func test_high_contrast_theme_has_pure_black_background() -> void:
	"""Test that high contrast theme uses pure black"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.HIGH_CONTRAST)
	
	var base_color = theme_manager.get_color("base")
	assert_that(base_color).is_equal(Color("#000000"))

func test_colorblind_deuteranopia_theme_uses_blue_for_success() -> void:
	"""Test that deuteranopia theme uses blue instead of green for success"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA)

	var success_color = theme_manager.get_color("success")
	assert_that(success_color).is_equal(Color("#0077BB"))  # Tol blue (colorblind-safe)

func test_colorblind_protanopia_theme_uses_cyan_for_success() -> void:
	"""Test that protanopia theme uses cyan instead of green for success"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.COLORBLIND_PROTANOPIA)

	var success_color = theme_manager.get_color("success")
	assert_that(success_color).is_equal(Color("#33BBEE"))  # Cyan (Tol bright cyan)

func test_register_control_adds_to_registered_list() -> void:
	"""Test that register_control adds control to internal list"""
	var label = Label.new()
	theme_manager.register_control(label)
	
	# Control should be in registered list (we can't access private var, but test side effects)
	# Apply a theme and check if control gets updated
	theme_manager.apply_theme(ThemeManager.ThemeVariant.LIGHT)
	
	# Verify the label has light theme colors applied
	assert_that(label.get_theme_color("font_color")).is_equal(Color("#1f2937"))
	
	label.queue_free()

func test_save_and_load_settings() -> void:
	"""Test that theme settings can be saved and loaded"""
	theme_manager.apply_theme(ThemeManager.ThemeVariant.HIGH_CONTRAST)
	theme_manager.set_scale_factor(1.25)
	
	var settings = theme_manager.save_settings()
	
	assert_that(settings["theme_variant"]).is_equal(ThemeManager.ThemeVariant.HIGH_CONTRAST)
	assert_that(settings["scale_factor"]).is_equal(1.25)
	
	# Create new instance and load settings
	var ThemeManagerClass = load("res://src/ui/themes/ThemeManager.gd")
	var new_manager = auto_free(ThemeManagerClass.new())
	add_child(new_manager)
	# Call _ready manually since await might not work in tests
	if new_manager.has_method("_ready"):
		new_manager._ready()
	new_manager.load_settings(settings)
	
	assert_that(new_manager.get_current_theme()).is_equal(ThemeManager.ThemeVariant.HIGH_CONTRAST)
	assert_that(new_manager.get_current_scale()).is_equal(1.25)
	
	remove_child(new_manager)

func test_theme_changed_signal_emits_on_apply() -> void:
	"""Test that theme_changed signal emits when theme is applied"""
	var _signal_monitor = monitor_signals(theme_manager)
	
	theme_manager.apply_theme(ThemeManager.ThemeVariant.LIGHT)
	
	# Verify signal was emitted (get_signal_parameters is not available in GdUnit4)
	assert_signal(theme_manager).is_emitted("theme_changed")

func test_scale_changed_signal_emits_on_scale_change() -> void:
	"""Test that scale_changed signal emits when scale factor changes"""
	var _signal_monitor = monitor_signals(theme_manager)
	
	theme_manager.set_scale_factor(1.5)
	
	# Verify signal was emitted (get_signal_parameters is not available in GdUnit4)
	assert_signal(theme_manager).is_emitted("scale_changed")
