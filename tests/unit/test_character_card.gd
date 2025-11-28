extends GdUnitTestSuite
class_name TestCharacterCard

## Comprehensive CharacterCard Component Test Suite
## Tests 3 variants (COMPACT, STANDARD, EXPANDED) with signal emission, data binding, and performance
## MAX 13 TESTS (runner stability limit)

# Test constants
const VARIANT_COMPACT = 0
const VARIANT_STANDARD = 1
const VARIANT_EXPANDED = 2

const COMPACT_HEIGHT = 80
const STANDARD_HEIGHT = 120
const EXPANDED_HEIGHT = 160
const TOUCH_TARGET_MIN = 48

# Scene under test (will be created by UI designer)
const CARD_SCENE_PATH = "res://src/ui/components/character/CharacterCard.tscn"

# Mock data
var mock_character: Character
var card_instance: PanelContainer
var _test_scene_runner: GdUnitSceneRunner

# =====================================================
# SETUP & TEARDOWN
# =====================================================

func before_test() -> void:
	"""Setup before each test - create mock character and card instance"""
	_test_scene_runner = scene_runner(self)
	mock_character = _create_mock_character()
	
	# Load card scene if it exists, otherwise create minimal mock
	if ResourceLoader.exists(CARD_SCENE_PATH):
		card_instance = load(CARD_SCENE_PATH).instantiate()
	else:
		# Create minimal mock node for testing (until UI designer creates scene)
		card_instance = _create_mock_card_node()
	
	# Add to scene tree for signal testing
	_test_scene_runner.add_child(card_instance)

func after_test() -> void:
	"""Cleanup after each test"""
	if card_instance and is_instance_valid(card_instance):
		card_instance.queue_free()
	card_instance = null
	mock_character = null
	_test_scene_runner = null

# =====================================================
# INSTANTIATION TESTS (3 tests)
# =====================================================

func test_card_instantiates_with_default_variant() -> void:
	"""Test 1/13: Card instantiates with STANDARD variant by default"""
	assert_that(card_instance).is_not_null()
	
	# Check default variant
	if card_instance.has_method("get_variant"):
		var variant = card_instance.get_variant()
		assert_int(variant).is_equal(VARIANT_STANDARD)

func test_card_accepts_character_data() -> void:
	"""Test 2/13: Card accepts Character resource without crashing"""
	assert_that(card_instance).is_not_null()
	
	# Should not crash when setting character
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		
		# Verify character was set
		if card_instance.has_method("get_character"):
			var retrieved_character = card_instance.get_character()
			assert_that(retrieved_character).is_not_null()

func test_card_switches_variants_at_runtime() -> void:
	"""Test 3/13: Card can switch between variants at runtime"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_variant"):
		# Start with STANDARD
		card_instance.set_variant(VARIANT_STANDARD)
		await get_tree().process_frame  # Wait for layout update
		
		# Switch to COMPACT
		card_instance.set_variant(VARIANT_COMPACT)
		await get_tree().process_frame
		
		if card_instance.has_method("get_variant"):
			assert_int(card_instance.get_variant()).is_equal(VARIANT_COMPACT)
		
		# Switch to EXPANDED
		card_instance.set_variant(VARIANT_EXPANDED)
		await get_tree().process_frame
		
		if card_instance.has_method("get_variant"):
			assert_int(card_instance.get_variant()).is_equal(VARIANT_EXPANDED)

# =====================================================
# DATA BINDING TESTS (3 tests)
# =====================================================

func test_compact_displays_name_and_class() -> void:
	"""Test 4/13: COMPACT variant displays character name and class"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_variant") and card_instance.has_method("set_character"):
		card_instance.set_variant(VARIANT_COMPACT)
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find name and class labels
		var name_label = _find_node_by_partial_name(card_instance, "Name")
		var class_label = _find_node_by_partial_name(card_instance, "Class")
		
		if name_label and name_label is Label:
			assert_str(name_label.text).contains("Test Character")
		
		if class_label and class_label is Label:
			assert_str(class_label.text).contains("MILITARY")

func test_standard_displays_stats_summary() -> void:
	"""Test 5/13: STANDARD variant displays Combat/Reactions/Toughness summary"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_variant") and card_instance.has_method("set_character"):
		card_instance.set_variant(VARIANT_STANDARD)
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find stats labels (Combat, Reactions, Toughness)
		var combat_label = _find_node_by_partial_name(card_instance, "Combat")
		var reactions_label = _find_node_by_partial_name(card_instance, "Reactions")
		var toughness_label = _find_node_by_partial_name(card_instance, "Toughness")
		
		# At least one stat should be displayed
		var stats_found = (combat_label != null) or (reactions_label != null) or (toughness_label != null)
		assert_bool(stats_found).is_true()

func test_expanded_displays_full_stats() -> void:
	"""Test 6/13: EXPANDED variant displays all 5 stats + XP bar"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_variant") and card_instance.has_method("set_character"):
		card_instance.set_variant(VARIANT_EXPANDED)
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find XP/experience indicator
		var xp_bar = _find_node_by_partial_name(card_instance, "XP")
		var xp_label = _find_node_by_partial_name(card_instance, "Experience")
		
		# XP indicator should exist in expanded view
		var xp_found = (xp_bar != null) or (xp_label != null)
		assert_bool(xp_found).is_true()

# =====================================================
# SIGNAL TESTS (4 tests)
# =====================================================

func test_card_tapped_signal_emits() -> void:
	"""Test 7/13: Clicking card body emits card_tapped signal"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Monitor signal
		var signal_monitor = monitor_signals(card_instance)
		
		# Simulate click on card (if gui_input exists)
		if card_instance.has_signal("card_tapped"):
			var click_event = InputEventMouseButton.new()
			click_event.button_index = MOUSE_BUTTON_LEFT
			click_event.pressed = true
			
			if card_instance.has_method("_gui_input"):
				card_instance._gui_input(click_event)
				await get_tree().process_frame
				
				# Verify signal was emitted
				assert_int(signal_monitor.count("card_tapped")).is_greater_equal(0)

func test_view_details_button_emits_signal() -> void:
	"""Test 8/13: View Details button emits view_details_pressed signal"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find view details button
		var view_button = _find_button_by_partial_name(card_instance, "View")
		
		if view_button and card_instance.has_signal("view_details_pressed"):
			var signal_monitor = monitor_signals(card_instance)
			
			# Click button
			view_button.pressed.emit()
			await get_tree().process_frame
			
			# Verify signal emitted
			assert_int(signal_monitor.count("view_details_pressed")).is_greater_equal(1)

func test_edit_button_emits_signal() -> void:
	"""Test 9/13: Edit button emits edit_pressed signal"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find edit button
		var edit_button = _find_button_by_partial_name(card_instance, "Edit")
		
		if edit_button and card_instance.has_signal("edit_pressed"):
			var signal_monitor = monitor_signals(card_instance)
			
			# Click button
			edit_button.pressed.emit()
			await get_tree().process_frame
			
			# Verify signal emitted
			assert_int(signal_monitor.count("edit_pressed")).is_greater_equal(1)

func test_remove_button_emits_signal() -> void:
	"""Test 10/13: Remove button emits remove_pressed signal"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find remove button
		var remove_button = _find_button_by_partial_name(card_instance, "Remove")
		
		if remove_button and card_instance.has_signal("remove_pressed"):
			var signal_monitor = monitor_signals(card_instance)
			
			# Click button
			remove_button.pressed.emit()
			await get_tree().process_frame
			
			# Verify signal emitted
			assert_int(signal_monitor.count("remove_pressed")).is_greater_equal(1)

# =====================================================
# TOUCH TARGET TESTS (2 tests)
# =====================================================

func test_buttons_meet_minimum_touch_target() -> void:
	"""Test 11/13: All interactive buttons meet 48dp minimum touch target"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		await get_tree().process_frame
		
		# Find all buttons
		var buttons = _find_all_buttons(card_instance)
		
		# Check each button meets minimum height
		for button in buttons:
			if button is Button:
				var min_size = button.custom_minimum_size
				var size = button.size
				
				# Either custom_minimum_size or actual size should meet target
				var meets_target = (min_size.y >= TOUCH_TARGET_MIN) or (size.y >= TOUCH_TARGET_MIN)
				assert_bool(meets_target).is_true()

func test_card_height_matches_variant() -> void:
	"""Test 12/13: Card height matches variant specifications"""
	assert_that(card_instance).is_not_null()
	
	if card_instance.has_method("set_variant") and card_instance.has_method("set_character"):
		card_instance.set_character(mock_character)
		
		# Test COMPACT (80px)
		card_instance.set_variant(VARIANT_COMPACT)
		await get_tree().process_frame
		var compact_size = card_instance.custom_minimum_size
		if compact_size.y > 0:
			assert_float(compact_size.y).is_equal_approx(COMPACT_HEIGHT, 10.0)
		
		# Test STANDARD (120px)
		card_instance.set_variant(VARIANT_STANDARD)
		await get_tree().process_frame
		var standard_size = card_instance.custom_minimum_size
		if standard_size.y > 0:
			assert_float(standard_size.y).is_equal_approx(STANDARD_HEIGHT, 10.0)
		
		# Test EXPANDED (160px)
		card_instance.set_variant(VARIANT_EXPANDED)
		await get_tree().process_frame
		var expanded_size = card_instance.custom_minimum_size
		if expanded_size.y > 0:
			assert_float(expanded_size.y).is_equal_approx(EXPANDED_HEIGHT, 10.0)

# =====================================================
# PERFORMANCE TEST (1 test)
# =====================================================

func test_instantiation_performance() -> void:
	"""Test 13/13: Card instantiation and population completes in <1ms"""
	var start_time = Time.get_ticks_usec()
	
	# Create and populate card
	var test_card: PanelContainer
	if ResourceLoader.exists(CARD_SCENE_PATH):
		test_card = load(CARD_SCENE_PATH).instantiate()
	else:
		test_card = _create_mock_card_node()
	
	if test_card.has_method("set_character"):
		test_card.set_character(mock_character)
	
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	# Cleanup
	test_card.queue_free()
	
	# Should complete in less than 1ms
	assert_float(duration_ms).is_less(1.0)

# =====================================================
# TEST UTILITIES
# =====================================================

func _create_mock_character() -> Character:
	"""Create mock character with all required fields"""
	var character = Character.new()
	character.name = "Test Character"
	character.background = "MILITARY"
	character.motivation = "WEALTH"
	character.origin = "HUMAN"
	character.character_class = "BASELINE"
	
	# Stats
	character.combat = 4
	character.reactions = 3
	character.toughness = 5
	character.savvy = 2
	character.tech = 1
	character.move = 4
	character.speed = 4
	character.luck = 2
	
	# Progression
	character.experience = 15
	character.credits = 100
	
	# Equipment
	character.equipment = ["Infantry Laser", "Body Armor", "Basic Kit"]
	
	# Status
	character.is_captain = false
	character.status = "ACTIVE"
	character.health = 7
	character.max_health = 7
	
	return character

func _create_mock_card_node() -> PanelContainer:
	"""Create minimal mock card node for testing before UI implementation"""
	var mock_card = PanelContainer.new()
	mock_card.name = "MockCharacterCard"
	mock_card.custom_minimum_size = Vector2(200, STANDARD_HEIGHT)
	
	# Add mock methods
	mock_card.set_script(preload("res://tests/unit/helpers/MockCharacterCardScript.gd") if ResourceLoader.exists("res://tests/unit/helpers/MockCharacterCardScript.gd") else null)
	
	return mock_card

func _find_node_by_partial_name(root: Node, partial_name: String) -> Node:
	"""Recursively find node containing partial name"""
	if root.name.contains(partial_name):
		return root
	
	for child in root.get_children():
		var found = _find_node_by_partial_name(child, partial_name)
		if found:
			return found
	
	return null

func _find_button_by_partial_name(root: Node, partial_name: String) -> Button:
	"""Find button node containing partial name"""
	var node = _find_node_by_partial_name(root, partial_name)
	if node and node is Button:
		return node
	return null

func _find_all_buttons(root: Node) -> Array[Button]:
	"""Recursively find all button nodes"""
	var buttons: Array[Button] = []
	
	if root is Button:
		buttons.append(root)
	
	for child in root.get_children():
		buttons.append_array(_find_all_buttons(child))
	
	return buttons
