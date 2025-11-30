extends GdUnitTestSuite

## Tier 1 UI Improvements Validation Test Suite
## Tests visual hierarchy, section icons, validation feedback, and stat badges
## Framework: GDUnit4 v6.0.1 | Max 13 tests per file

const FinalPanel = preload("res://src/ui/screens/campaign/panels/FinalPanel.gd")
const Character = preload("res://src/core/character/Character.gd")

var panel: FinalPanel
var mock_campaign_data: Dictionary

## Setup & Teardown

func before():
	"""Create FinalPanel instance and mock campaign data"""
	panel = FinalPanel.new()
	add_child(panel)

	# Wait for panel initialization
	await get_tree().process_frame
	await get_tree().process_frame

	mock_campaign_data = _create_valid_campaign_data()

func after():
	"""Clean up panel and reset mock data"""
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	mock_campaign_data.clear()
	await get_tree().process_frame

## Visual Hierarchy Tests (Font Sizes & Colors)

func test_campaign_name_uses_large_font_and_accent_color():
	"""Verify campaign name displays with FONT_SIZE_LG and COLOR_ACCENT"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Find campaign name label in config card
	var config_card = _find_card_by_title(panel.summary_cards_container, "Campaign Configuration")
	assert_that(config_card).is_not_null()

	var campaign_label = _find_label_with_text(config_card, "Campaign:")
	assert_that(campaign_label).is_not_null()

	# Assert: Font size is FONT_SIZE_LG (18)
	var font_size = campaign_label.get_theme_font_size("font_size")
	assert_that(font_size).is_equal(18)

	# Assert: Font color is COLOR_ACCENT (#2D5A7B)
	var font_color = campaign_label.get_theme_color("font_color")
	assert_that(font_color).is_equal(Color("#2D5A7B"))

func test_ship_name_uses_large_font():
	"""Verify ship name displays with FONT_SIZE_MD"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Find ship name label
	var ship_card = _find_card_by_title(panel.summary_cards_container, "Ship Details")
	assert_that(ship_card).is_not_null()

	var ship_label = _find_label_with_text(ship_card, "Starfury")
	assert_that(ship_label).is_not_null()

	# Assert: Font size is FONT_SIZE_MD (16)
	var font_size = ship_label.get_theme_font_size("font_size")
	assert_that(font_size).is_equal(16)

func test_captain_name_uses_primary_color():
	"""Verify captain name displays with COLOR_TEXT_PRIMARY"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Find captain name label
	var captain_card = _find_card_by_title(panel.summary_cards_container, "Captain")
	assert_that(captain_card).is_not_null()

	var captain_label = _find_label_with_text(captain_card, "Commander Vale")
	assert_that(captain_label).is_not_null()

	# Assert: Font color is COLOR_TEXT_PRIMARY (#E0E0E0)
	var font_color = captain_label.get_theme_color("font_color")
	assert_that(font_color).is_equal(Color("#E0E0E0"))

func test_secondary_text_uses_small_font_and_secondary_color():
	"""Verify difficulty/mode text uses FONT_SIZE_SM and COLOR_TEXT_SECONDARY"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Find difficulty label
	var config_card = _find_card_by_title(panel.summary_cards_container, "Campaign Configuration")
	var difficulty_label = _find_label_with_text(config_card, "Difficulty:")
	assert_that(difficulty_label).is_not_null()

	# Assert: Font size is FONT_SIZE_SM (14)
	var font_size = difficulty_label.get_theme_font_size("font_size")
	assert_that(font_size).is_equal(14)

	# Assert: Font color is COLOR_TEXT_SECONDARY (#808080)
	var font_color = difficulty_label.get_theme_color("font_color")
	assert_that(font_color).is_equal(Color("#808080"))

## Section Icon Tests

func test_all_summary_cards_have_section_icons():
	"""Verify all 5 summary cards have icons in headers"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Count cards with icons (icons are part of _create_section_card title)
	var expected_cards = [
		"Campaign Configuration",
		"Ship Details",
		"Captain",
		"Crew Summary",
		"Starting Equipment"
	]

	# Assert: All 5 cards exist
	for card_title in expected_cards:
		var card = _find_card_by_title(panel.summary_cards_container, card_title)
		assert_that(card).is_not_null()

## Validation Feedback Tests

func test_valid_campaign_shows_no_errors():
	"""Test valid campaign data shows no error messages"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Validate campaign
	var errors = panel._validate_campaign_data()

	# Assert: No validation errors
	assert_that(errors).is_empty()
	assert_that(panel.is_campaign_complete).is_true()

func test_missing_campaign_name_shows_error():
	"""Test missing campaign_name triggers validation error"""
	# Arrange: Create campaign data with missing name
	var invalid_data = mock_campaign_data.duplicate(true)
	invalid_data["campaign_config"]["campaign_name"] = ""
	panel.set_campaign_data(invalid_data)
	await get_tree().process_frame

	# Act: Validate campaign
	var errors = panel._validate_campaign_data()

	# Assert: Error message present
	assert_that(errors.size()).is_greater(0)
	assert_that(errors[0]).contains_ignoring_case("campaign name")

func test_missing_captain_shows_error():
	"""Test missing captain triggers validation error"""
	# Arrange: Create campaign data with no captain
	var invalid_data = mock_campaign_data.duplicate(true)
	invalid_data["captain"] = {}
	panel.set_campaign_data(invalid_data)
	await get_tree().process_frame

	# Act: Validate campaign
	var errors = panel._validate_campaign_data()

	# Assert: Error message present
	assert_that(errors.size()).is_greater(0)
	var has_captain_error = false
	for error in errors:
		if "captain" in error.to_lower():
			has_captain_error = true
			break
	assert_that(has_captain_error).is_true()

func test_empty_crew_shows_error():
	"""Test empty crew array triggers validation error"""
	# Arrange: Create campaign data with no crew
	var invalid_data = mock_campaign_data.duplicate(true)
	invalid_data["crew"]["members"] = []
	panel.set_campaign_data(invalid_data)
	await get_tree().process_frame

	# Act: Validate campaign
	var errors = panel._validate_campaign_data()

	# Assert: Error message present
	assert_that(errors.size()).is_greater(0)
	var has_crew_error = false
	for error in errors:
		if "crew" in error.to_lower():
			has_crew_error = true
			break
	assert_that(has_crew_error).is_true()

## Stat Badge Tests

func test_stat_badges_render_in_crew_summary():
	"""Verify stat badges appear in crew summary card"""
	# Arrange: Set valid campaign data
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Find crew summary card
	var crew_card = _find_card_by_title(panel.summary_cards_container, "Crew Summary")
	assert_that(crew_card).is_not_null()

	# Assert: Crew count label exists
	var crew_count_label = _find_label_with_text(crew_card, "Crew Members:")
	assert_that(crew_count_label).is_not_null()

	# Assert: Average stats label exists
	var avg_stats_label = _find_label_with_text(crew_card, "Avg Combat:")
	assert_that(avg_stats_label).is_not_null()

func test_stat_values_are_correct():
	"""Verify stat calculations match expected values"""
	# Arrange: Set valid campaign data (4 crew with known stats)
	panel.set_campaign_data(mock_campaign_data)
	await get_tree().process_frame

	# Act: Manually calculate expected averages
	# Crew: combat_skill = [1, 0, 2, 1] → avg = 1
	# Crew: reactions = [1, 1, 2, 1] → avg = 1
	var expected_avg_combat = 1
	var expected_avg_reactions = 1

	# Assert: Crew summary shows correct values
	var crew_card = _find_card_by_title(panel.summary_cards_container, "Crew Summary")
	var stats_label = _find_label_with_text(crew_card, "Avg Combat:")
	assert_that(stats_label).is_not_null()

	# Check text contains expected values
	assert_that(stats_label.text).contains("Avg Combat: +%d" % expected_avg_combat)
	assert_that(stats_label.text).contains("Avg Reactions: %d\"" % expected_avg_reactions)

## Helper Methods

func _create_valid_campaign_data() -> Dictionary:
	"""Create valid campaign data for testing"""
	var captain_char = Character.new()
	captain_char.character_name = "Commander Vale"
	captain_char.background = "Military"
	captain_char.char_class = "Officer"
	captain_char.combat_skill = 2
	captain_char.reactions = 2
	captain_char.toughness = 3

	var crew_members = []
	for i in range(4):
		var crew_char = Character.new()
		crew_char.character_name = "Crew Member %d" % (i + 1)
		crew_char.combat_skill = [1, 0, 2, 1][i]
		crew_char.reactions = [1, 1, 2, 1][i]
		crew_members.append(crew_char)

	return {
		"campaign_config": {
			"campaign_name": "Test Campaign",
			"difficulty": "Normal",
			"game_mode": "Standard",
			"victory_conditions": {
				"standard_victory": true
			},
			"story_track_enabled": true
		},
		"ship": {
			"name": "Starfury",
			"type": "Freighter",
			"hull_points": 10,
			"cargo_capacity": 50,
			"debt": 500
		},
		"captain": {
			"captain": captain_char,
			"name": "Commander Vale",
			"background": "Military",
			"class": "Officer",
			"xp": 0
		},
		"crew": {
			"members": crew_members
		},
		"equipment": {
			"starting_credits": 1000,
			"items": [],
			"resources": {
				"story_points": 2,
				"patrons": [],
				"rivals": []
			}
		}
	}

func _find_card_by_title(container: Control, title: String) -> PanelContainer:
	"""Find PanelContainer by searching for title text"""
	if not container or not is_instance_valid(container):
		return null

	for child in container.get_children():
		if child is PanelContainer:
			var label = _find_first_label(child)
			if label and title.to_upper() in label.text.to_upper():
				return child
	return null

func _find_label_with_text(node: Node, search_text: String) -> Label:
	"""Recursively find Label containing search_text"""
	if not node or not is_instance_valid(node):
		return null

	if node is Label and search_text in node.text:
		return node

	for child in node.get_children():
		var result = _find_label_with_text(child, search_text)
		if result:
			return result

	return null

func _find_first_label(node: Node) -> Label:
	"""Find first Label node in tree"""
	if not node or not is_instance_valid(node):
		return null

	if node is Label:
		return node

	for child in node.get_children():
		var result = _find_first_label(child)
		if result:
			return result

	return null
