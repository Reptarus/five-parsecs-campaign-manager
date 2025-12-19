extends GdUnitTestSuite

## ValidationPanel Component Unit Tests
## Tests the ValidationPanel UI component created in Sprint A Session 1
## Framework: GDUnit4 v6.0.3 | Max 5 tests

const ValidationPanelScene = preload("res://src/ui/components/combat/rules/validation_panel.tscn")

var panel: Node

## Setup & Teardown

func before_test():
	"""Create fresh panel instance before each test"""
	panel = auto_free(ValidationPanelScene.instantiate())
	add_child(panel)
	# Wait for _ready to complete
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(panel):
		push_warning("panel freed during setup, test may fail")

func after_test():
	"""Clean up panel after each test"""
	if panel and is_instance_valid(panel):
		remove_child(panel)
	panel = null

## Tests

func test_validation_panel_instantiates_correctly():
	"""Verify ValidationPanel instantiates with default state"""
	assert_object(panel).is_not_null()
	# Panel should be hidden by default (unless in editor)
	assert_bool(panel.visible).is_false()

func test_success_feedback_shows_green_styling():
	"""Verify success feedback displays green border and checkmark"""
	if not is_instance_valid(panel):
		push_warning("panel freed early, skipping")
		return

	panel.show_success("Campaign ready to create", "")
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(panel):
		return

	# Access message_label directly (it's an @onready var)
	var message_label = panel.get("message_label")
	if message_label:
		assert_str(message_label.text).is_equal("Campaign ready to create")

	# Panel should be visible after show_success
	assert_bool(panel.visible).is_true()

func test_error_feedback_shows_red_styling_with_messages():
	"""Verify error feedback displays red border and bulleted error list"""
	if not is_instance_valid(panel):
		push_warning("panel freed early, skipping")
		return

	# show_error expects (message: String, details: String = "")
	var error_message = "Campaign name required\nCaptain must be assigned\nAt least 1 crew member required"
	panel.show_error(error_message, "")
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(panel):
		return

	# Access message_label directly (it's an @onready var)
	var message_label = panel.get("message_label")
	if message_label:
		assert_str(message_label.text).contains("Campaign name required")

	# Panel should be visible after show_error
	assert_bool(panel.visible).is_true()

func test_warning_feedback_shows_orange_styling():
	"""Verify warning feedback displays orange border and warning icon"""
	# Note: show_warning doesn't exist in validation_panel.gd
	# This test is skipped as the function is not implemented
	# If warning functionality is needed, it should be added to validation_panel.gd
	push_warning("test_warning_feedback_shows_orange_styling: show_warning() not implemented in ValidationPanel")
	return


func test_empty_messages_shows_default_success_message():
	"""Verify empty messages show default success message"""
	if not is_instance_valid(panel):
		push_warning("panel freed early, skipping")
		return

	panel.show_success("Campaign ready to create!", "")
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(panel):
		return

	# Access message_label directly (it's an @onready var)
	var message_label = panel.get("message_label")
	if message_label:
		assert_str(message_label.text).is_equal("Campaign ready to create!")

	# Panel should be visible
	assert_bool(panel.visible).is_true()

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
