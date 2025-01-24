extends "res://addons/gut/test.gd"

const Patron = preload("res://src/core/rivals/Patron.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsLocation = preload("res://src/core/world/Location.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

var patron: Patron
var test_location: FiveParsecsLocation

func before_each() -> void:
	test_location = FiveParsecsLocation.new()
	test_location.location_name = "Test Location"
	
	patron = Patron.new("Test Patron", test_location, GameEnums.FactionType.NEUTRAL)

func after_each() -> void:
	patron = null
	test_location = null

func test_initialization() -> void:
	assert_eq(patron.patron_name, "Test Patron", "Should set patron name")
	assert_eq(patron.location.location_name, "Test Location", "Should set location")
	assert_eq(patron.faction_type, GameEnums.FactionType.NEUTRAL, "Should set faction type")
	assert_eq(patron.relationship, 0, "Should start with neutral relationship")
	assert_gt(patron.economic_influence, 0.0, "Should have positive economic influence")
	assert_gt(patron.characteristics.size(), 0, "Should have characteristics")

func test_characteristics() -> void:
	var has_valid_characteristic := false
	for characteristic in patron.characteristics:
		if characteristic in [
			"Connected: +1 to finding new patrons in this location",
			"Wealthy: +2 credits to mission rewards",
			"Influential: +1 reputation from completed missions",
			"Demanding: -1 relationship for failed missions",
			"Generous: +1 relationship for completed missions"
		]:
			has_valid_characteristic = true
			break
	assert_true(has_valid_characteristic, "Should have valid characteristic")

func test_mission_management() -> void:
	var mission = Mission.new()
	patron.add_mission(mission)
	assert_true(mission in patron.get_available_missions(), "Should add mission to available missions")
	
	patron.remove_mission(mission)
	assert_false(mission in patron.get_available_missions(), "Should remove mission from available missions")

func test_relationship_changes() -> void:
	patron.change_relationship(10)
	assert_eq(patron.relationship, 10, "Should increase relationship")
	
	patron.change_relationship(-20)
	assert_eq(patron.relationship, -10, "Should decrease relationship")
	
	patron.change_relationship(-100)
	assert_eq(patron.relationship, -100, "Should clamp relationship at minimum")
	
	patron.change_relationship(200)
	assert_eq(patron.relationship, 100, "Should clamp relationship at maximum")

func test_patron_status() -> void:
	patron.change_relationship(-50)
	assert_eq(patron.get_status(), "Distrustful", "Should be distrustful at low relationship")
	
	patron.change_relationship(75)
	assert_eq(patron.get_status(), "Friend", "Should be friend at medium-high relationship")
	
	patron.change_relationship(25)
	assert_eq(patron.get_status(), "Trusted Ally", "Should be trusted ally at high relationship")

func test_mission_reward_modifier() -> void:
	var base_modifier = patron.get_mission_reward_modifier()
	assert_gt(base_modifier, 0.0, "Should have positive reward modifier")
	
	# Test economic influence affects rewards
	var wealthy_patron = Patron.new("Wealthy Patron", test_location, GameEnums.FactionType.NEUTRAL)
	wealthy_patron.economic_influence = 2.0
	assert_gt(wealthy_patron.get_mission_reward_modifier(), base_modifier, "Higher economic influence should give better rewards")

func test_serialization() -> void:
	var mission = Mission.new()
	patron.add_mission(mission)
	
	var data = patron.serialize()
	var new_patron = Patron.deserialize(data)
	
	assert_eq(new_patron.patron_name, patron.patron_name, "Should preserve patron name")
	assert_eq(new_patron.relationship, patron.relationship, "Should preserve relationship")
	assert_eq(new_patron.characteristics, patron.characteristics, "Should preserve characteristics")
	assert_eq(new_patron.economic_influence, patron.economic_influence, "Should preserve economic influence")

func test_dismissal() -> void:
	assert_false(patron._is_dismissed, "Should start not dismissed")
	
	patron.dismiss()
	assert_true(patron._is_dismissed, "Should be dismissed after calling dismiss")
	assert_eq(patron.get_status(), "Dismissed", "Should show dismissed status")
	assert_false(patron.can_offer_mission(), "Should not be able to offer missions when dismissed")

func test_mission_completion() -> void:
	var mission = Mission.new()
	patron.add_mission(mission)
	
	patron.complete_mission(mission)
	assert_gt(patron.relationship, 0, "Should improve relationship on mission completion")
	
	if patron.has_characteristic("Generous"):
		assert_gt(patron.relationship, 2, "Should give bonus relationship if patron is generous")