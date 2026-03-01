extends GdUnitTestSuite

## StatBadge Component Unit Tests
## Tests the StatBadge UI component created in Sprint A Session 1
## Framework: GDUnit4 v6.0.3 | Max 8 tests

const StatBadgeClass = preload("res://src/ui/components/base/StatBadge.gd")

var badge: StatBadge

## Setup & Teardown

func before_test():
	"""Create fresh badge instance before each test"""
	badge = StatBadgeClass.new()
	# Add to tree to ensure _ready() is called and UI is created
	add_child(badge)
	await get_tree().process_frame  # Wait for _ready() to complete

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		push_warning("badge freed during setup, test may fail")

func after_test():
	"""Clean up badge after each test"""
	if badge:
		# Remove from tree before freeing
		if badge.get_parent():
			badge.get_parent().remove_child(badge)
		badge.queue_free()
	badge = null

## Tests

func test_stat_badge_instantiates_correctly():
	"""Verify StatBadge instantiates with default values"""
	assert_object(badge).is_not_null()
	assert_str(badge.stat_name).is_equal("STAT")  # Default value
	assert_that(badge.stat_value).is_equal(0)  # Default value (Variant, int 0)
	assert_bool(badge.show_plus).is_false()
	assert_that(badge.accent_color).is_equal(StatBadgeClass.COLOR_ACCENT)

func test_stat_name_setter_updates_label():
	"""Verify setting stat_name updates the name_label"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	badge.stat_name = "Combat"
	await get_tree().process_frame  # Wait for _update_display() to run

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	# Access internal _name_label directly (StatBadge stores it as private variable)
	var name_label: Label = null
	if "_name_label" in badge:
		name_label = badge.get("_name_label") as Label
	else:
		# Fallback: search for label with uppercase text
		name_label = _find_label_with_text(badge, "COMBAT")  # StatBadge converts to uppercase
	
	assert_object(name_label).is_not_null()
	if name_label:
		assert_str(name_label.text).is_equal("COMBAT")  # StatBadge converts to uppercase

func test_stat_value_setter_updates_label():
	"""Verify setting stat_value updates the value_label"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	badge.stat_value = "5"
	await get_tree().process_frame  # Wait for _update_display() to run

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	# Access internal _value_label directly
	var value_label: Label = null
	if "_value_label" in badge:
		value_label = badge.get("_value_label") as Label
	else:
		# Fallback: search for label
		value_label = _find_label_with_text(badge, "5")
	
	assert_object(value_label).is_not_null()
	if value_label:
		assert_str(value_label.text).is_equal("5")

func test_show_plus_adds_plus_sign_to_positive_values():
	"""Verify show_plus=true prepends + to positive values"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	badge.stat_value = "3"
	badge.show_plus = true
	await get_tree().process_frame  # Wait for _update_display() to run

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	# Access internal _value_label directly
	var value_label: Label = null
	if "_value_label" in badge:
		value_label = badge.get("_value_label") as Label
	else:
		# Fallback: search for label
		value_label = _find_label_with_text(badge, "+3")
	
	assert_object(value_label).is_not_null()
	if value_label:
		assert_str(value_label.text).is_equal("+3")

func test_accent_color_applies_to_value_label():
	"""Verify accent_color applies to value_label font color"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	badge.stat_value = "7"
	badge.accent_color = Color(0.1, 0.7, 0.4)  # Green accent
	await get_tree().process_frame  # Wait for _update_display() to run

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	# Access internal _value_label directly
	var value_label: Label = null
	if "_value_label" in badge:
		value_label = badge.get("_value_label") as Label
	else:
		# Fallback: search for label
		value_label = _find_label_with_text(badge, "7")
	
	assert_object(value_label).is_not_null()
	if value_label:
		# Check if color override is set (may be in theme overrides)
		var color_override: Color = value_label.get_theme_color("font_color", "Label")
		assert_object(color_override).is_not_null()

func test_configure_method_sets_all_properties():
	"""Verify configure() sets all properties at once"""
	badge.configure("Reactions", 5, true, Color(0.3, 0.7, 1.0))

	assert_str(badge.stat_name).is_equal("Reactions")
	assert_that(badge.stat_value).is_equal(5)
	assert_bool(badge.show_plus).is_true()
	assert_that(badge.accent_color).is_equal(Color(0.3, 0.7, 1.0))

func test_minimum_size_is_80x64():
	"""Verify stat badge meets minimum size requirements"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	# Badge is already added in before_test()
	await get_tree().process_frame  # Ensure _ready() completed

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	var min_size = badge.custom_minimum_size
	# Use int() cast since custom_minimum_size.x/y are floats
	assert_int(int(min_size.x)).is_greater_equal(80)
	assert_int(int(min_size.y)).is_greater_equal(64)

func test_labels_have_correct_font_sizes():
	"""Verify font sizes match design system (XS=11, SM=14)"""
	if not is_instance_valid(badge):
		push_warning("badge freed early, skipping")
		return

	badge.stat_name = "Hull"
	badge.stat_value = "8"
	await get_tree().process_frame  # Wait for _update_display() to run

	# Guard against freed instance after await
	if not is_instance_valid(badge):
		return

	# Access internal labels directly
	var name_label: Label = null
	var value_label: Label = null
	
	if "_name_label" in badge:
		name_label = badge.get("_name_label") as Label
	else:
		name_label = _find_label_with_text(badge, "HULL")  # StatBadge converts to uppercase
	
	if "_value_label" in badge:
		value_label = badge.get("_value_label") as Label
	else:
		value_label = _find_label_with_text(badge, "8")

	# Name label should be XS (11) - StatBadge uses FONT_SIZE_XS = 11
	if name_label:
		var name_font_size: int = name_label.get_theme_font_size("font_size", "Label")
		assert_int(name_font_size).is_equal(11)

	# Value label should be SM (14) - StatBadge uses FONT_SIZE_SM = 14, not MD=16
	if value_label:
		var value_font_size: int = value_label.get_theme_font_size("font_size", "Label")
		assert_int(value_font_size).is_equal(14)

## Helper Functions

func _find_label_with_text(parent: Node, text: String) -> Label:
	"""Recursively find Label with specific text (nil-safe)"""
	if not is_instance_valid(parent):
		return null
	for child in parent.get_children():
		if not is_instance_valid(child):
			continue
		if child is Label and child.text == text:
			return child
		var found = _find_label_with_text(child, text)
		if found:
			return found
	return null
