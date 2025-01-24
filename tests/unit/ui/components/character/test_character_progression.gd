extends "res://tests/fixtures/base_test.gd"

const CharacterProgression = preload("res://src/ui/components/character/CharacterBox.tscn")

var character_progression = null
var mock_character_data = {}

func before_each():
	await super.before_each()
	character_progression = CharacterProgression.instantiate()
	add_child_autofree(character_progression)
	await character_progression.ready
	mock_character_data = {
		"level": 1,
		"experience": 0,
		"next_level_exp": 100
	}

func after_each():
	await super.after_each()
	character_progression = null

func test_initial_setup():
	assert_not_null(character_progression, "Character progression node should exist")
	assert_true(character_progression.is_inside_tree(), "Node should be in scene tree")

func test_update_progression_display():
	character_progression.update_display(mock_character_data)
	assert_eq(character_progression.get_level(), 1, "Initial level should be 1")
	assert_eq(character_progression.get_experience(), 0, "Initial experience should be 0")

func test_experience_gain():
	character_progression.update_display(mock_character_data)
	var gained_exp = 50
	mock_character_data.experience = gained_exp
	character_progression.update_display(mock_character_data)
	assert_eq(character_progression.get_experience(), gained_exp, "Experience should update correctly")

func test_level_up():
	mock_character_data.experience = 100
	mock_character_data.level = 2
	character_progression.update_display(mock_character_data)
	assert_eq(character_progression.get_level(), 2, "Level should increase after reaching threshold")