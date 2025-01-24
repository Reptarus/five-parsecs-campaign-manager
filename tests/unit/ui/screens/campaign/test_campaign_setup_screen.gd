extends "res://addons/gut/test.gd"

const CampaignSetupScreen = preload("res://src/ui/screens/campaign/CampaignSetupScreen.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var setup_screen: CampaignSetupScreen
var setup_completed_signal_emitted := false
var setup_cancelled_signal_emitted := false
var last_setup_data: Dictionary

func before_each() -> void:
	setup_screen = CampaignSetupScreen.new()
	add_child(setup_screen)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	setup_screen.queue_free()

func _reset_signals() -> void:
	setup_completed_signal_emitted = false
	setup_cancelled_signal_emitted = false
	last_setup_data = {}

func _connect_signals() -> void:
	setup_screen.setup_completed.connect(_on_setup_completed)
	setup_screen.setup_cancelled.connect(_on_setup_cancelled)

func _on_setup_completed(setup_data: Dictionary) -> void:
	setup_completed_signal_emitted = true
	last_setup_data = setup_data

func _on_setup_cancelled() -> void:
	setup_cancelled_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(setup_screen)
	assert_not_null(setup_screen.crew_panel)
	assert_not_null(setup_screen.equipment_panel)
	assert_not_null(setup_screen.objective_panel)
	assert_not_null(setup_screen.confirm_button)
	assert_not_null(setup_screen.back_button)

func test_crew_setup() -> void:
	var test_crew = {
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": [
			{"name": "Member 1", "class": GameEnums.CharacterClass.MEDIC},
			{"name": "Member 2", "class": GameEnums.CharacterClass.ENGINEER}
		]
	}
	
	setup_screen.set_crew_data(test_crew)
	
	assert_eq(setup_screen.get_crew_data(), test_crew)
	assert_true(setup_screen.is_crew_valid())

func test_equipment_setup() -> void:
	var test_equipment = {
		"weapons": ["Rifle", "Pistol"],
		"armor": ["Light Armor"],
		"items": ["Medkit", "Toolkit"]
	}
	
	setup_screen.set_equipment_data(test_equipment)
	
	assert_eq(setup_screen.get_equipment_data(), test_equipment)
	assert_true(setup_screen.is_equipment_valid())

func test_objective_setup() -> void:
	var test_objective = {
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000,
		"time_limit": 50
	}
	
	setup_screen.set_objective_data(test_objective)
	
	assert_eq(setup_screen.get_objective_data(), test_objective)
	assert_true(setup_screen.is_objective_valid())

func test_setup_completion() -> void:
	# Set valid data
	var test_data = {
		"crew": {
			"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
			"members": []
		},
		"equipment": {
			"weapons": ["Rifle"],
			"armor": ["Light Armor"],
			"items": []
		},
		"objective": {
			"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
			"target": 10000
		}
	}
	
	setup_screen.set_crew_data(test_data.crew)
	setup_screen.set_equipment_data(test_data.equipment)
	setup_screen.set_objective_data(test_data.objective)
	
	setup_screen.complete_setup()
	
	assert_true(setup_completed_signal_emitted)
	assert_eq(last_setup_data.crew, test_data.crew)
	assert_eq(last_setup_data.equipment, test_data.equipment)
	assert_eq(last_setup_data.objective, test_data.objective)

func test_setup_cancellation() -> void:
	setup_screen.cancel_setup()
	
	assert_true(setup_cancelled_signal_emitted)

func test_validation() -> void:
	# Test with empty data
	assert_false(setup_screen.is_setup_valid())
	
	# Test with partial data
	setup_screen.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	assert_false(setup_screen.is_setup_valid())
	
	# Test with complete data
	setup_screen.set_equipment_data({
		"weapons": ["Rifle"],
		"armor": ["Light Armor"],
		"items": []
	})
	setup_screen.set_objective_data({
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000
	})
	assert_true(setup_screen.is_setup_valid())

func test_confirm_button_state() -> void:
	# Test with invalid setup
	assert_true(setup_screen.confirm_button.disabled)
	
	# Test with valid setup
	setup_screen.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	setup_screen.set_equipment_data({
		"weapons": ["Rifle"],
		"armor": ["Light Armor"],
		"items": []
	})
	setup_screen.set_objective_data({
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000
	})
	
	assert_false(setup_screen.confirm_button.disabled)

func test_data_persistence() -> void:
	var test_data = {
		"crew": {
			"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
			"members": []
		},
		"equipment": {
			"weapons": ["Rifle"],
			"armor": ["Light Armor"],
			"items": []
		},
		"objective": {
			"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
			"target": 10000
		}
	}
	
	setup_screen.load_setup_data(test_data)
	var saved_data = setup_screen.save_setup_data()
	
	assert_eq(saved_data.crew, test_data.crew)
	assert_eq(saved_data.equipment, test_data.equipment)
	assert_eq(saved_data.objective, test_data.objective)

func test_reset() -> void:
	# Set some data
	setup_screen.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	
	# Reset screen
	setup_screen.reset()
	
	# Verify everything is cleared
	assert_false(setup_screen.is_crew_valid())
	assert_false(setup_screen.is_equipment_valid())
	assert_false(setup_screen.is_objective_valid())