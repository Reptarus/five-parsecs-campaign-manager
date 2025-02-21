@tool
extends GameTest

const PhaseIndicator = preload("res://src/scenes/campaign/components/PhaseIndicator.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

var indicator: Node
var phase_manager: Node

func before_each() -> void:
	await super.before_each()
	indicator = PhaseIndicator.new()
	phase_manager = CampaignPhaseManager.new()
	add_child_autofree(indicator)
	add_child_autofree(phase_manager)
	track_test_node(indicator)
	track_test_node(phase_manager)
	_initialize_indicator()

func after_each() -> void:
	indicator = null
	phase_manager = null
	await super.after_each()

func _initialize_indicator() -> void:
	if not indicator or not phase_manager:
		return
	indicator.initialize(phase_manager)

## Safe Property Access Methods
func _get_indicator_property(property: String, default_value = null) -> Variant:
	if not indicator:
		push_error("Trying to access property '%s' on null indicator" % property)
		return default_value
	if not property in indicator:
		push_error("Indicator missing required property: %s" % property)
		return default_value
	return indicator.get(property)

func _get_manager_property(property: String, default_value = null) -> Variant:
	if not phase_manager:
		push_error("Trying to access property '%s' on null phase manager" % property)
		return default_value
	if not property in phase_manager:
		push_error("Phase manager missing required property: %s" % property)
		return default_value
	return phase_manager.get(property)

func _get_label_text() -> String:
	var label = _get_indicator_property("phase_label")
	if not label:
		return ""
	return label.text

func _get_description_text() -> String:
	var description = _get_indicator_property("phase_description")
	if not description:
		return ""
	return description.text

func test_initial_setup() -> void:
	assert_not_null(indicator, "Indicator should exist")
	assert_not_null(_get_indicator_property("phase_label"), "Phase label should exist")
	assert_not_null(_get_indicator_property("phase_description"), "Phase description should exist")
	assert_not_null(_get_indicator_property("phase_icon"), "Phase icon should exist")
	assert_eq(_get_indicator_property("current_phase"), GameEnums.FiveParcsecsCampaignPhase.SETUP, "Initial phase should be SETUP")

func test_phase_text_update() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.UPKEEP
	indicator.set_phase(test_phase)
	
	assert_eq(_get_indicator_property("current_phase"), test_phase, "Current phase should match test phase")
	assert_eq(_get_label_text(), "Upkeep Phase", "Phase label should be updated")
	assert_true(_get_description_text().length() > 0, "Phase description should not be empty")

func test_phase_icon_update() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP
	indicator.set_phase(test_phase)
	
	var icon = _get_indicator_property("phase_icon")
	assert_not_null(icon, "Phase icon should exist")
	assert_not_null(icon.texture, "Phase icon should have a texture")

func test_phase_description_formatting() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.STORY
	indicator.set_phase(test_phase)
	
	var description = _get_description_text()
	assert_true(description.length() > 0, "Description should not be empty")
	assert_true(description.begins_with(description[0].to_upper()), "Description should start with uppercase")
	assert_true(description.ends_with("."), "Description should end with period")

func test_phase_manager_integration() -> void:
	phase_manager.advance_phase() # Should move to next phase
	
	var current_phase = _get_manager_property("current_phase")
	assert_eq(_get_indicator_property("current_phase"), current_phase, "Indicator phase should match manager phase")
	assert_eq(_get_label_text(), GameEnums.FiveParcsecsCampaignPhase.keys()[current_phase] + " Phase", "Phase label should match current phase")

func test_phase_cycling() -> void:
	var initial_phase = _get_indicator_property("current_phase")
	
	# Test cycling through all phases
	for i in range(GameEnums.FiveParcsecsCampaignPhase.size()):
		var expected_phase = (initial_phase + i) % GameEnums.FiveParcsecsCampaignPhase.size()
		assert_eq(_get_indicator_property("current_phase"), expected_phase, "Current phase should match expected phase")
		phase_manager.advance_phase()

func test_phase_descriptions() -> void:
	# Test descriptions for all phases
	for phase in GameEnums.FiveParcsecsCampaignPhase.values():
		indicator.set_phase(phase)
		var description = _get_description_text()
		assert_true(description.length() > 0, "Description should not be empty")
		assert_true(description is String, "Description should be a string")
		assert_true(description.strip_edges().length() > 0, "Description should not be only whitespace")

func test_invalid_phase_handling() -> void:
	var invalid_phase = -1
	indicator.set_phase(invalid_phase)
	
	# Should default to SETUP phase
	assert_eq(_get_indicator_property("current_phase"), GameEnums.FiveParcsecsCampaignPhase.SETUP, "Invalid phase should default to SETUP")
	assert_eq(_get_label_text(), "Setup Phase", "Phase label should show Setup Phase")