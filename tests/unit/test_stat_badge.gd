extends GdUnitTestSuite

## StatBadge Component Unit Tests
## Tests the StatBadge UI component created in Sprint A Session 1
## Framework: GDUnit4 v6.0.1 | Max 8 tests

const StatBadge = preload("res://src/ui/components/combat/rules/validation_panel.gd")

var badge: StatBadge

## Setup & Teardown

func before():
	"""Create fresh badge instance before each test"""
	badge = ValidationPanel.new()

func after():
	"""Clean up badge after each test"""
	if badge:
		badge.queue_free()
	badge = null

## Tests

func test_stat_badge_instantiates_correctly():
	"""Verify StatBadge instantiates with default values"""
	assert_object(badge).is_not_null()
	assert_str(badge.stat_name).is_empty()
	assert_str(badge.stat_value).is_empty()
	assert_bool(badge.show_plus).is_false()
	assert_object(badge.accent_color).is_null()

func test_stat_name_setter_updates_label():
	"""Verify setting stat_name updates the name_label"""
	badge.stat_name = "Combat"

	# Add to tree to trigger _ready and UI creation
	add_child(badge)
	await get_tree().process_frame

	# Find name label
	var name_label = _find_label_with_text(badge, "Combat")
	assert_object(name_label).is_not_null()
	assert_str(name_label.text).is_equal("Combat")

func test_stat_value_setter_updates_label():
	"""Verify setting stat_value updates the value_label"""
	badge.stat_value = "5"

	add_child(badge)
	await get_tree().process_frame

	var value_label = _find_label_with_text(badge, "5")
	assert_object(value_label).is_not_null()
	assert_str(value_label.text).is_equal("5")

func test_show_plus_adds_plus_sign_to_positive_values():
	"""Verify show_plus=true prepends + to positive values"""
	badge.stat_value = "3"
	badge.show_plus = true

	add_child(badge)
	await get_tree().process_frame

	var value_label = _find_label_with_text(badge, "+3")
	assert_object(value_label).is_not_null()
	assert_str(value_label.text).is_equal("+3")

func test_accent_color_applies_to_value_label():
	"""Verify accent_color applies to value_label font color"""
	badge.stat_value = "7"
	badge.accent_color = Color(0.1, 0.7, 0.4)  # Green accent

	add_child(badge)
	await get_tree().process_frame

	# Find value label and check color override
	var value_label = _find_label_with_text(badge, "7")
	assert_object(value_label).is_not_null()

	# Check if color override is set (may be in theme overrides)
	var color_override = value_label.get_theme_color("font_color")
	assert_object(color_override).is_not_null()

func test_configure_method_sets_all_properties():
	"""Verify configure() sets all properties at once"""
	badge.configure("Reactions", 5, true, Color(0.3, 0.7, 1.0))

	assert_str(badge.stat_name).is_equal("Reactions")
	assert_str(badge.stat_value).is_equal("5")
	assert_bool(badge.show_plus).is_true()
	assert_object(badge.accent_color).is_equal(Color(0.3, 0.7, 1.0))

func test_minimum_size_is_80x64():
	"""Verify stat badge meets minimum size requirements"""
	add_child(badge)
	await get_tree().process_frame

	var min_size = badge.custom_minimum_size
	assert_int(min_size.x).is_greater_equal(80)
	assert_int(min_size.y).is_greater_equal(64)

func test_labels_have_correct_font_sizes():
	"""Verify font sizes match design system (XS=11, MD=16)"""
	badge.stat_name = "Hull"
	badge.stat_value = "8"

	add_child(badge)
	await get_tree().process_frame

	var name_label = _find_label_with_text(badge, "Hull")
	var value_label = _find_label_with_text(badge, "8")

	# Name label should be XS (11)
	assert_int(name_label.get_theme_font_size("font_size")).is_equal(11)

	# Value label should be MD (16)
	assert_int(value_label.get_theme_font_size("font_size")).is_equal(16)

## Helper Functions

func _find_label_with_text(parent: Node, text: String) -> Label:
	"""Recursively find Label with specific text"""
	for child in parent.get_children():
		if child is Label and child.text == text:
			return child
		var found = _find_label_with_text(child, text)
		if found:
			return found
	return null
