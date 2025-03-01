@tool
extends "res://tests/fixtures/base/game_test.gd"

const CampaignSetupScreen = preload("res://src/ui/screens/campaign/CampaignSetupScreen.gd")

var _instance: CampaignSetupScreen
var setup_completed_signal_emitted := false
var setup_cancelled_signal_emitted := false
var last_setup_data: Dictionary

# Signal watching helper functions
func watch_signals(emitter: Object) -> void:
	super.watch_signals(emitter)

func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	verify_signal_emitted(object, signal_name, text)

func before_each() -> void:
	_instance = CampaignSetupScreen.new()
	add_child_autofree(_instance)
	track_test_node(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	await get_tree().process_frame

func _reset_signals() -> void:
	setup_completed_signal_emitted = false
	setup_cancelled_signal_emitted = false
	last_setup_data = {}

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("setup_completed"):
		_instance.connect("setup_completed", _on_setup_completed)
	if _instance.has_signal("setup_cancelled"):
		_instance.connect("setup_cancelled", _on_setup_cancelled)

func _on_setup_completed(setup_data: Dictionary) -> void:
	setup_completed_signal_emitted = true
	last_setup_data = setup_data

func _on_setup_cancelled() -> void:
	setup_cancelled_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(_instance)
	
	# Wait for UI elements to be ready
	await _instance.ready
	
	# Now check UI elements
	assert_not_null(_instance.get_node("CrewPanel"), "CrewPanel should exist")
	assert_not_null(_instance.get_node("EquipmentPanel"), "EquipmentPanel should exist")
	assert_not_null(_instance.get_node("ObjectivePanel"), "ObjectivePanel should exist")
	assert_not_null(_instance.get_node("ConfirmButton"), "ConfirmButton should exist")
	assert_not_null(_instance.get_node("BackButton"), "BackButton should exist")

func test_crew_setup() -> void:
	var test_crew = {
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": [
			{"name": "Member 1", "class": GameEnums.CharacterClass.MEDIC},
			{"name": "Member 2", "class": GameEnums.CharacterClass.ENGINEER}
		]
	}
	
	_instance.set_crew_data(test_crew)
	
	assert_eq(_instance.get_crew_data(), test_crew)
	assert_true(_instance.is_crew_valid())

func test_equipment_setup() -> void:
	var test_equipment = {
		"weapons": ["Rifle", "Pistol"],
		"armor": ["Light Armor"],
		"items": ["Medkit", "Toolkit"]
	}
	
	_instance.set_equipment_data(test_equipment)
	
	assert_eq(_instance.get_equipment_data(), test_equipment)
	assert_true(_instance.is_equipment_valid())

func test_objective_setup() -> void:
	var test_objective = {
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000,
		"time_limit": 50
	}
	
	_instance.set_objective_data(test_objective)
	
	assert_eq(_instance.get_objective_data(), test_objective)
	assert_true(_instance.is_objective_valid())

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
	
	_instance.set_crew_data(test_data.crew)
	_instance.set_equipment_data(test_data.equipment)
	_instance.set_objective_data(test_data.objective)
	
	# Wait for UI to update
	await get_tree().process_frame
	
	_instance.complete_setup()
	
	# Check signal emission
	assert_signal_emitted(_instance, "setup_completed", "Setup completed signal should be emitted")
	
	# Verify setup data
	var confirm_button = _instance.get_node("ConfirmButton")
	assert_not_null(confirm_button, "ConfirmButton should exist")
	assert_false(confirm_button.disabled, "ConfirmButton should be enabled")

func test_setup_cancellation() -> void:
	_instance.cancel_setup()
	assert_signal_emitted(_instance, "setup_cancelled", "Setup cancelled signal should be emitted")

func test_validation() -> void:
	# Test with empty data
	assert_false(_instance.is_setup_valid())
	
	# Test with partial data
	_instance.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	await get_tree().process_frame
	assert_false(_instance.is_setup_valid())
	
	# Test with complete data
	_instance.set_equipment_data({
		"weapons": ["Rifle"],
		"armor": ["Light Armor"],
		"items": []
	})
	_instance.set_objective_data({
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000
	})
	await get_tree().process_frame
	assert_true(_instance.is_setup_valid())

func test_confirm_button_state() -> void:
	var confirm_button = _instance.get_node("ConfirmButton")
	assert_not_null(confirm_button, "ConfirmButton should exist")
	
	# Test with invalid setup
	assert_true(confirm_button.disabled, "Button should be disabled initially")
	
	# Test with valid setup
	_instance.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	_instance.set_equipment_data({
		"weapons": ["Rifle"],
		"armor": ["Light Armor"],
		"items": []
	})
	_instance.set_objective_data({
		"type": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
		"target": 10000
	})
	
	# Wait for UI to update
	await get_tree().process_frame
	assert_false(confirm_button.disabled, "Button should be enabled with valid setup")

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
	
	_instance.load_setup_data(test_data)
	await get_tree().process_frame
	
	var saved_data = _instance.save_setup_data()
	assert_eq(saved_data.crew, test_data.crew, "Crew data should match")
	assert_eq(saved_data.equipment, test_data.equipment, "Equipment data should match")
	assert_eq(saved_data.objective, test_data.objective, "Objective data should match")

func test_reset() -> void:
	# Set some data
	_instance.set_crew_data({
		"leader": {"name": "Leader", "class": GameEnums.CharacterClass.SOLDIER},
		"members": []
	})
	
	# Wait for UI to update
	await get_tree().process_frame
	
	# Reset screen
	_instance.reset()
	await get_tree().process_frame
	
	# Verify everything is cleared
	assert_false(_instance.is_crew_valid(), "Crew should be invalid after reset")
	assert_false(_instance.is_equipment_valid(), "Equipment should be invalid after reset")
	assert_false(_instance.is_objective_valid(), "Objective should be invalid after reset")
	
	var confirm_button = _instance.get_node("ConfirmButton")
	assert_not_null(confirm_button, "ConfirmButton should exist")
	assert_true(confirm_button.disabled, "ConfirmButton should be disabled after reset")