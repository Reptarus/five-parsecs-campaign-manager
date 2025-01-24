extends "res://addons/gut/test.gd"

const PhaseIndicator = preload("res://src/scenes/campaign/components/PhaseIndicator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

var indicator: PhaseIndicator
var phase_manager: Node

func before_each() -> void:
	indicator = PhaseIndicator.new()
	phase_manager = CampaignPhaseManager.new()
	add_child(indicator)
	add_child(phase_manager)
	indicator.initialize(phase_manager)

func after_each() -> void:
	indicator.queue_free()
	phase_manager.queue_free()

func test_initial_setup() -> void:
	assert_not_null(indicator)
	assert_not_null(indicator.phase_label)
	assert_not_null(indicator.phase_description)
	assert_not_null(indicator.phase_icon)
	assert_eq(indicator.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)

func test_phase_text_update() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.UPKEEP
	indicator.set_phase(test_phase)
	
	assert_eq(indicator.current_phase, test_phase)
	assert_eq(indicator.phase_label.text, "Upkeep Phase")
	assert_true(indicator.phase_description.text.length() > 0)

func test_phase_icon_update() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP
	indicator.set_phase(test_phase)
	
	assert_not_null(indicator.phase_icon.texture)
	# Add more specific icon checks when implemented

func test_phase_description_formatting() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.STORY
	indicator.set_phase(test_phase)
	
	var description = indicator.phase_description.text
	assert_true(description.length() > 0)
	assert_true(description.begins_with(description[0].to_upper()))
	assert_true(description.ends_with("."))

func test_phase_manager_integration() -> void:
	phase_manager.advance_phase() # Should move to next phase
	
	assert_eq(indicator.current_phase, phase_manager.current_phase)
	assert_eq(indicator.phase_label.text, GameEnums.FiveParcsecsCampaignPhase.keys()[phase_manager.current_phase] + " Phase")

func test_phase_cycling() -> void:
	var initial_phase = indicator.current_phase
	
	# Test cycling through all phases
	for i in range(GameEnums.FiveParcsecsCampaignPhase.size()):
		var expected_phase = (initial_phase + i) % GameEnums.FiveParcsecsCampaignPhase.size()
		assert_eq(indicator.current_phase, expected_phase)
		phase_manager.advance_phase()

func test_phase_descriptions() -> void:
	# Test descriptions for all phases
	for phase in GameEnums.FiveParcsecsCampaignPhase.values():
		indicator.set_phase(phase)
		var description = indicator.phase_description.text
		assert_true(description.length() > 0)
		assert_true(description is String)
		assert_true(description.strip_edges().length() > 0)

func test_invalid_phase_handling() -> void:
	var invalid_phase = -1
	indicator.set_phase(invalid_phase)
	
	# Should default to SETUP phase
	assert_eq(indicator.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)
	assert_eq(indicator.phase_label.text, "Setup Phase")