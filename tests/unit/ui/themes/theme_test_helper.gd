@tool
extends Node
# Use explicit preloads instead of global class names
const ThemeTestHelperScript = preload("res://tests/unit/ui/themes/theme_test_helper.gd")

## A utility class that provides helper methods for testing theme-related functionality.
## This helps standardize theme testing across different UI components.

const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")
const GutTest = preload("res://addons/gut/test.gd")

## Verifies that the basic theme properties match the expected values
## 
## @param theme: The theme to verify
## @param expected_properties: Dictionary with expected property values
## @param gut: GUT test instance for assertions
## @return: Whether all properties matched expectations
static func verify_theme_properties(theme: Theme, expected_properties: Dictionary, gut: GutTest) -> bool:
	var all_matched := true
	
	for property_path in expected_properties:
		var parts: PackedStringArray = property_path.split("/")
		var property_type: String = parts[0]
		var property_name: String = parts[1]
		var expected_value = expected_properties[property_path]
		
		match property_type:
			"color":
				var actual_value := theme.get_color(property_name, "")
				gut.assert_almost_eq(actual_value, expected_value, Vector3(0.01, 0.01, 0.01),
					"Theme color property '%s' should match expected value" % property_path)
				
				if actual_value.is_equal_approx(expected_value) == false:
					all_matched = false
			
			"constant":
				var actual_value := theme.get_constant(property_name, "")
				gut.assert_eq(actual_value, expected_value,
					"Theme constant property '%s' should match expected value" % property_path)
				
				if actual_value != expected_value:
					all_matched = false
			
			"font_size":
				var actual_value := theme.get_font_size(property_name, "")
				gut.assert_eq(actual_value, expected_value,
					"Theme font size property '%s' should match expected value" % property_path)
				
				if actual_value != expected_value:
					all_matched = false
	
	return all_matched

## Tests theme switching on a control node
##
## @param control: The Control node to test
## @param theme_manager: Theme manager instance
## @param theme_key: Key for the theme to switch to
## @param gut: GUT test instance for assertions
## @return: Whether the theme switch was successful
static func test_theme_switching(control: Control, theme_manager: ThemeManager, theme_key: String, gut: GutTest) -> bool:
	# Store the original theme for comparison
	var original_theme := control.theme
	
	# Switch the theme
	theme_manager.set_active_theme(theme_key)
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame # Wait two frames to ensure theme changes propagate
	
	# Get the new theme
	var new_theme := control.theme
	
	# Check if theme changed
	gut.assert_ne(original_theme, new_theme, "Theme should change after switching")
	
	# Verify theme is the expected one
	var expected_theme: Theme = theme_manager.get_theme(theme_key)
	gut.assert_eq(new_theme, expected_theme, "Control should have the selected theme")
	
	return original_theme != new_theme && new_theme == expected_theme

## Tests high contrast mode on a control node
##
## @param control: The Control node to test
## @param theme_manager: Theme manager instance
## @param gut: GUT test instance for assertions
## @return: Whether high contrast mode affects the control appropriately
static func test_high_contrast_mode(control: Control, theme_manager: ThemeManager, gut: GutTest) -> bool:
	# Store original settings
	var original_high_contrast: bool = theme_manager.high_contrast_enabled
	var original_theme := control.theme
	
	# Enable high contrast mode
	theme_manager.set_high_contrast(true)
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Check if theme changed
	var high_contrast_theme := control.theme
	gut.assert_ne(original_theme, high_contrast_theme, "Theme should change when high contrast is enabled")
	
	# Disable high contrast mode
	theme_manager.set_high_contrast(false)
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Check if theme reverted
	var reverted_theme := control.theme
	gut.assert_ne(high_contrast_theme, reverted_theme, "Theme should change when high contrast is disabled")
	
	# Restore original setting
	theme_manager.set_high_contrast(original_high_contrast)
	
	return true

## Tests text scaling on a control node
##
## @param control: The Control node to test
## @param theme_manager: Theme manager instance
## @param label_nodes: Array of Label nodes to check for scaling
## @param gut: GUT test instance for assertions
## @return: Whether text scaling works correctly
static func test_text_scaling(control: Control, theme_manager: ThemeManager,
							 label_nodes: Array[Label], gut: GutTest) -> bool:
	# Store original settings
	var original_scale: float = theme_manager.text_scale
	
	# Store original font sizes
	var original_sizes: Array[int] = []
	for label in label_nodes:
		original_sizes.append(label.get_theme_font_size("font_size"))
	
	# Test increased scale
	theme_manager.set_text_scale(1.5) # 50% larger
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Check if font sizes increased
	var all_increased: bool = true
	for i in range(label_nodes.size()):
		var new_size: int = label_nodes[i].get_theme_font_size("font_size")
		var original_size: int = original_sizes[i]
		gut.assert_gt(new_size, original_size, "Font size should increase with larger scale")
		
		if new_size <= original_size:
			all_increased = false
	
	# Test decreased scale
	theme_manager.set_text_scale(0.8) # 20% smaller
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Check if font sizes decreased
	var all_decreased: bool = true
	for i in range(label_nodes.size()):
		var new_size: int = label_nodes[i].get_theme_font_size("font_size")
		var original_size: int = original_sizes[i]
		gut.assert_lt(new_size, original_size, "Font size should decrease with smaller scale")
		
		if new_size >= original_size:
			all_decreased = false
	
	# Restore original setting
	theme_manager.set_text_scale(original_scale)
	
	return all_increased && all_decreased

## Tests animation settings on a control node
##
## @param control: The Control node to test
## @param theme_manager: Theme manager instance
## @param animated_nodes: Array of nodes that should respond to animation settings
## @param gut: GUT test instance for assertions
## @return: Whether animation settings work correctly
static func test_animation_settings(control: Control, theme_manager: ThemeManager,
								  animated_nodes: Array[Node], gut: GutTest) -> bool:
	# Store original settings
	var original_enabled: bool = theme_manager.animations_enabled
	
	# Disable animations
	theme_manager.set_animations_enabled(false)
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Check if animations are disabled
	var all_disabled: bool = true
	for node in animated_nodes:
		if node.has_method("is_animating") && node.is_animating():
			all_disabled = false
			gut.assert_false(node.is_animating(), "Node should not be animating when animations are disabled")
	
	# Enable animations
	theme_manager.set_animations_enabled(true)
	await gut.get_tree().process_frame
	await gut.get_tree().process_frame
	
	# Restore original setting
	theme_manager.set_animations_enabled(original_enabled)
	
	return all_disabled

## Returns a dictionary with some expected properties for the base theme
## This provides a baseline for theme property testing
static func get_base_theme_expected_properties() -> Dictionary:
	return {
		"color/primary": Color(0.2, 0.4, 0.7),
		"color/secondary": Color(0.7, 0.3, 0.2),
		"color/background": Color(0.95, 0.95, 0.95),
		"color/text": Color(0.1, 0.1, 0.1),
		"constant/margin": 10,
		"constant/padding": 5,
		"font_size/normal": 16,
		"font_size/large": 24
	}

## Returns a dictionary with some expected properties for the dark theme
static func get_dark_theme_expected_properties() -> Dictionary:
	return {
		"color/background": Color(0.15, 0.15, 0.15),
		"color/text": Color(0.9, 0.9, 0.9)
	}

## Returns a dictionary with some expected properties for the high contrast theme
static func get_high_contrast_expected_properties() -> Dictionary:
	return {
		"color/background": Color(0.0, 0.0, 0.0),
		"color/text": Color(1.0, 1.0, 1.0)
	}
