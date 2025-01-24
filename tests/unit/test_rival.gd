extends "res://addons/gut/test.gd"

const Rival = preload("res://src/core/rivals/Rival.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var rival: Rival

func before_each() -> void:
	rival = Rival.new()
	rival.rival_name = "Test Rival"
	rival.rival_type = "Mercenary"
	rival.threat_level = GameEnums.DifficultyLevel.NORMAL
	rival.reputation = 0
	rival.active = true

func after_each() -> void:
	rival = null

func test_initialization() -> void:
	assert_eq(rival.rival_name, "Test Rival", "Should set rival name")
	assert_eq(rival.rival_type, "Mercenary", "Should set rival type")
	assert_eq(rival.threat_level, GameEnums.DifficultyLevel.NORMAL, "Should set threat level")
	assert_eq(rival.reputation, 0, "Should start with zero reputation")
	assert_true(rival.active, "Should start active")
	assert_eq(rival.last_encounter_turn, -1, "Should start with no encounters")
	assert_eq(rival.special_traits.size(), 0, "Should start with no special traits")
	assert_has(rival.resources, "credits", "Should initialize resources with credits")
	assert_has(rival.resources, "influence", "Should initialize resources with influence")
	assert_has(rival.resources, "territory", "Should initialize resources with territory")

func test_threat_modifiers() -> void:
	rival.threat_level = GameEnums.DifficultyLevel.EASY
	assert_eq(rival.get_threat_modifier(), 0.8, "Easy threat should have 0.8 modifier")
	
	rival.threat_level = GameEnums.DifficultyLevel.NORMAL
	assert_eq(rival.get_threat_modifier(), 1.0, "Normal threat should have 1.0 modifier")
	
	rival.threat_level = GameEnums.DifficultyLevel.HARD
	assert_eq(rival.get_threat_modifier(), 1.2, "Hard threat should have 1.2 modifier")
	
	rival.threat_level = GameEnums.DifficultyLevel.HARDCORE
	assert_eq(rival.get_threat_modifier(), 1.4, "Hardcore threat should have 1.4 modifier")
	
	rival.threat_level = GameEnums.DifficultyLevel.ELITE
	assert_eq(rival.get_threat_modifier(), 1.6, "Elite threat should have 1.6 modifier")

func test_encounter_management() -> void:
	var encounter = {
		"type": "Combat",
		"outcome": "Victory",
		"location": "Test Location"
	}
	
	rival.last_encounter_turn = 5
	rival.add_encounter(encounter)
	
	var history = rival.get_encounter_history()
	assert_eq(history.size(), 1, "Should have one encounter in history")
	assert_eq(history[0].type, "Combat", "Should store encounter type")
	assert_eq(history[0].outcome, "Victory", "Should store encounter outcome")
	assert_eq(history[0].location, "Test Location", "Should store encounter location")
	assert_eq(history[0].turn, 5, "Should store encounter turn")

func test_resource_management() -> void:
	assert_eq(rival.resources.credits, 1000, "Should start with 1000 credits")
	assert_eq(rival.resources.influence, 0, "Should start with 0 influence")
	assert_eq(rival.resources.territory, 0, "Should start with 0 territory")
	
	rival.resources.credits += 500
	assert_eq(rival.resources.credits, 1500, "Should be able to modify credits")
	
	rival.resources.influence += 2
	assert_eq(rival.resources.influence, 2, "Should be able to modify influence")
	
	rival.resources.territory += 1
	assert_eq(rival.resources.territory, 1, "Should be able to modify territory")

func test_serialization() -> void:
	rival.rival_name = "Test Rival"
	rival.rival_type = "Mercenary"
	rival.threat_level = GameEnums.DifficultyLevel.HARD
	rival.reputation = 10
	rival.active = true
	rival.last_encounter_turn = 5
	rival.special_traits = ["Ruthless", "Cunning"]
	rival.resources.credits = 2000
	
	var encounter = {
		"type": "Combat",
		"outcome": "Victory",
		"location": "Test Location",
		"turn": 5
	}
	rival.add_encounter(encounter)
	
	var data = rival.serialize()
	var new_rival = Rival.new()
	new_rival.deserialize(data)
	
	assert_eq(new_rival.rival_name, rival.rival_name, "Should preserve rival name")
	assert_eq(new_rival.rival_type, rival.rival_type, "Should preserve rival type")
	assert_eq(new_rival.threat_level, rival.threat_level, "Should preserve threat level")
	assert_eq(new_rival.reputation, rival.reputation, "Should preserve reputation")
	assert_eq(new_rival.active, rival.active, "Should preserve active status")
	assert_eq(new_rival.last_encounter_turn, rival.last_encounter_turn, "Should preserve last encounter turn")
	assert_eq(new_rival.special_traits, rival.special_traits, "Should preserve special traits")
	assert_eq(new_rival.resources.credits, rival.resources.credits, "Should preserve resources")
	assert_eq(new_rival.get_encounter_history().size(), 1, "Should preserve encounter history")

func test_default_values() -> void:
	var default_rival = Rival.new()
	assert_eq(default_rival.rival_name, "", "Should have empty default name")
	assert_eq(default_rival.rival_type, "", "Should have empty default type")
	assert_eq(default_rival.threat_level, GameEnums.DifficultyLevel.NORMAL, "Should have normal default threat")
	assert_eq(default_rival.reputation, 0, "Should have zero default reputation")
	assert_true(default_rival.active, "Should be active by default")
	assert_eq(default_rival.last_encounter_turn, -1, "Should have -1 as default last encounter turn")

func test_invalid_deserialization() -> void:
	var invalid_data = {}
	var new_rival = Rival.new()
	new_rival.deserialize(invalid_data)
	
	assert_eq(new_rival.rival_name, "", "Should use default name for invalid data")
	assert_eq(new_rival.rival_type, "", "Should use default type for invalid data")
	assert_eq(new_rival.threat_level, GameEnums.DifficultyLevel.NORMAL, "Should use default threat for invalid data")
	assert_eq(new_rival.reputation, 0, "Should use default reputation for invalid data")
	assert_true(new_rival.active, "Should use default active status for invalid data")
	assert_eq(new_rival.last_encounter_turn, -1, "Should use default last encounter turn for invalid data")
	assert_eq(new_rival.special_traits.size(), 0, "Should use empty special traits for invalid data")
	assert_has(new_rival.resources, "credits", "Should initialize resources even with invalid data")
	assert_eq(new_rival.get_encounter_history().size(), 0, "Should use empty encounter history for invalid data")