@tool
extends GdUnitGameTest

#
class MockCharacterSheet extends Resource:
	var character_data: Dictionary = {}
	var is_initialized: bool = false
	
	func initialize(data: Dictionary) -> void:
		character_data = data.duplicate()
		is_initialized = true
		stats_updated.emit(character_data.get("stats", {}))

	func update_experience(new_exp: int) -> void:
		character_data["experience"] = new_exp
		experience_updated.emit(new_exp)
	
	func get_character_data() -> Dictionary:
		return character_data.duplicate()

	#
	signal stats_updated(stats: Dictionary)
	signal experience_updated(experience: int)

#
var character_sheet: MockCharacterSheet = null
var mock_character_data: Dictionary = {}

func before_test() -> void:
	super.before_test()
	character_sheet = MockCharacterSheet.new()
	track_resource(character_sheet)
	mock_character_data = _create_mock_character_data()

func after_test() -> void:
	character_sheet = null
	super.after_test()

func _create_mock_character_data() -> Dictionary:
	return {
		"name": "Test Character",
		"level": 1,
		"experience": 0,
		"stats": {"strength": 10, "agility": 10}

#
func test_progression_stat_updates() -> void:
	pass
	#
	character_sheet.initialize(mock_character_data)

	var stats = character_sheet.get_character_data().get("stats", {})
	assert_that(stats["strength"]).is_equal(10)
	assert_that(stats["agility"]).is_equal(10)

func test_experience_display() -> void:
	pass
	#
	character_sheet.initialize(mock_character_data)
	character_sheet.update_experience(100)

	var experience = character_sheet.get_character_data().get("experience", 0)
	assert_that(experience).is_equal(100)
