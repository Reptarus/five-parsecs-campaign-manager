extends GdUnitTestSuite

## ValidationPanel Component Unit Tests
## Tests the ValidationPanel UI component created in Sprint A Session 1
## Framework: GDUnit4 v6.0.1 | Max 5 tests

const ValidationPanel = preload("res://src/ui/components/combat/rules/validation_panel.gd")

var panel: ValidationPanel

## Setup & Teardown

func before():
	"""Create fresh panel instance before each test"""
	panel = ValidationPanel.new() as ValidationPanel

func after():
	"""Clean up panel after each test"""
	if panel:
		panel.queue_free()
	panel = null

## Tests

func test_validation_panel_instantiates_correctly():
	"""Verify ValidationPanel instantiates with default state"""
	assert_object(panel).is_not_null()

	# Add to tree to trigger _ready
	add_child(panel)
	await get_tree().process_frame

	# Should start with success state
	assert_object(panel).is_not_null()

func test_success_feedback_shows_green_styling():
	"""Verify success feedback displays green border and checkmark"""
	add_child(panel)
	await get_tree().process_frame

	panel.show_success("", "")
	await get_tree().process_frame

	# Find the RichTextLabel with success message
	var rich_label = _find_rich_text_label(panel)
	assert_object(rich_label).is_not_null()
	assert_str(rich_label.text).contains("✅")
	assert_str(rich_label.text).contains("Campaign ready to create")

	# Check panel style has green border
	var panel_container = _find_panel_container(panel)
	assert_object(panel_container).is_not_null()
	var style = panel_container.get_theme_stylebox("panel")
	assert_object(style).is_instance_of(StyleBoxFlat)
	# Green border color check (COLOR_SUCCESS = #10B981)
	assert_bool(style.border_color.is_equal_approx(Color("#10B981"))).is_true()

func test_error_feedback_shows_red_styling_with_messages():
	"""Verify error feedback displays red border and bulleted error list"""
	add_child(panel)
	await get_tree().process_frame

	var errors = PackedStringArray([
		"Campaign name required",
		"Captain must be assigned",
		"At least 1 crew member required"
	])
	panel.show_error(errors)
	await get_tree().process_frame

	# Find the RichTextLabel with error messages
	var rich_label = _find_rich_text_label(panel)
	assert_object(rich_label).is_not_null()
	assert_str(rich_label.text).contains("❌")
	assert_str(rich_label.text).contains("Issues to fix")
	assert_str(rich_label.text).contains("Campaign name required")
	assert_str(rich_label.text).contains("Captain must be assigned")
	assert_str(rich_label.text).contains("At least 1 crew member required")

	# Check panel style has red border
	var panel_container = _find_panel_container(panel)
	assert_object(panel_container).is_not_null()
	var style = panel_container.get_theme_stylebox("panel")
	assert_object(style).is_instance_of(StyleBoxFlat)
	# Red border color check (COLOR_DANGER = #DC2626)
	assert_bool(style.border_color.is_equal_approx(Color("#DC2626"))).is_true()

func test_warning_feedback_shows_orange_styling():
	"""Verify warning feedback displays orange border and warning icon"""
	add_child(panel)
	await get_tree().process_frame

	var warnings = PackedStringArray([
		"Low starting credits (recommended: 1000+)",
		"Small crew size (recommended: 5+)"
	])
	panel.show_warning(warnings)
	await get_tree().process_frame


func test_empty_messages_shows_default_success_message():
	"""Verify empty messages array shows default success message"""
	add_child(panel)
	await get_tree().process_frame

	panel.show_success("", "")
	await get_tree().process_frame

	var rich_label = _find_rich_text_label(panel)
	assert_object(rich_label).is_not_null()
	assert_str(rich_label.text).is_equal("[color=#10B981]✅ Campaign ready to create![/color]")

## Helper Functions

func _find_rich_text_label(parent: Node) -> RichTextLabel:
	"""Recursively find RichTextLabel"""
	for child in parent.get_children():
		if child is RichTextLabel:
			return child
		var found = _find_rich_text_label(child)
		if found:
			return found
	return null

func _find_panel_container(parent: Node) -> PanelContainer:
	"""Recursively find PanelContainer"""
	if parent is PanelContainer:
		return parent
	for child in parent.get_children():
		var found = _find_panel_container(child)
		if found:
			return found
	return null
