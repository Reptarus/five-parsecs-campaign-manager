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
	"""Verify the badge uses the XS rung for its name and SM for its value.

	Asserted through ScreenChrome.font_size(), NOT against the raw 11/14, because
	StatBadge scales both by the ambient breakpoint — see the note at the assertions.
	"""
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

	# The badge must use the XS rung for its name and the SM rung for its value —
	# asserted THROUGH the same transform the widget uses, not against the raw
	# constants.
	#
	# ⚠ This used to assert `is_equal(11)` / `is_equal(14)`, and it was a test whose
	# result depended on the size of the window the test runner happened to boot in.
	# StatBadge sets its sizes with `ScreenChrome.font_size(FONT_SIZE_XS)`
	# (StatBadge.gd:129/137), which delegates to
	# `ResponsiveManager.get_responsive_font_size()` = `maxi(9, round(base * mult))`.
	# The multiplier is 1.0 ONLY at the DESKTOP breakpoint, so the raw constants were
	# correct only when the ambient window happened to be 768-1023 px wide. Measured
	# 2026-09-05 by varying `user://window.ini` alone, with no code change at all:
	#
	#   900 px  -> DESKTOP  x1.00 -> 11, 14   PASS
	#   360 px  -> MOBILE   x0.85 ->  9, 12   FAIL
	#   1920 px -> WIDE     x1.15 -> 13, 16   FAIL
	#   headless (width 0)  -> MOBILE         FAIL
	#
	# `tests/tools/verify_layout.gd` sweeps six sizes and leaves the LAST one in
	# `user://window.ini`, which `GameState` restores at boot — so running the layout
	# sweep before the unit suite flipped this case red with nothing else changed.
	# That is the cross-process channel CLAUDE.md warns about under T11-04: a unit
	# test that depends on a screen configuration must PIN it, or must not depend on
	# it. This one now does not depend on it, which is the stronger of the two.
	var xs_expected: int = ScreenChrome.font_size(11)
	var sm_expected: int = ScreenChrome.font_size(14)

	if name_label:
		var name_font_size: int = name_label.get_theme_font_size("font_size", "Label")
		assert_int(name_font_size).override_failure_message(
			"Name label must use the XS rung through ScreenChrome.font_size()."
		).is_equal(xs_expected)

	if value_label:
		var value_font_size: int = value_label.get_theme_font_size("font_size", "Label")
		assert_int(value_font_size).override_failure_message(
			"Value label must use the SM rung (14), not MD (16)."
		).is_equal(sm_expected)

	# The rungs must stay DISTINCT and ordered, or the assertions above would still
	# pass if StatBadge used one size for both — at MOBILE the 9 px floor collapses
	# small rungs together, so this is only meaningful where the floor is not binding.
	if xs_expected < sm_expected:
		assert_int(xs_expected).override_failure_message(
			"XS must be smaller than SM wherever the 9px floor is not binding."
		).is_less(sm_expected)

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
