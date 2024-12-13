# AdvancedTrainingManager.gd
class_name AdvancedTrainingManager
extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")
const GameState = preload("res://Resources/Core/GameState/GameState.gd")

signal training_completed(character: Character, course: int)  # GlobalEnums.AdvancedTrainingCourse
signal training_failed(character: Character, course: int)  # GlobalEnums.AdvancedTrainingCourse

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

var ADVANCED_TRAINING_COURSES := {
	GameEnums.AdvancedTrainingCourse.PILOT_TRAINING: {
		"cost": 20,
		"skill": GameEnums.SkillType.TECHNICAL,
		"prerequisites": []
	},
	GameEnums.AdvancedTrainingCourse.COMBAT_SPECIALIST: {
		"cost": 15,
		"skill": GameEnums.SkillType.COMBAT,
		"prerequisites": []
	},
	GameEnums.AdvancedTrainingCourse.TECH_EXPERT: {
		"cost": 15,
		"skill": GameEnums.SkillType.TECHNICAL,
		"prerequisites": []
	},
	GameEnums.AdvancedTrainingCourse.SURVIVAL_EXPERT: {
		"cost": 15,
		"skill": GameEnums.SkillType.SURVIVAL,
		"prerequisites": []
	},
	GameEnums.AdvancedTrainingCourse.LEADERSHIP: {
		"cost": 25,
		"skill": GameEnums.SkillType.LEADERSHIP,
		"prerequisites": []
	}
}

func apply_for_training(character: Character, course: int) -> bool:  # GlobalEnums.AdvancedTrainingCourse
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	
	# Check prerequisites
	for prerequisite in course_data.prerequisites:
		if not character.has_skill(prerequisite):
			return false
	
	var application_fee := 1
	if not game_state.remove_credits(application_fee):
		push_warning("Not enough credits for application fee")
		return false
	
	var roll := randi() % 6 + 1  # 1d6
	return roll >= 4

func enroll_in_course(character: Character, course: int) -> bool:  # GlobalEnums.AdvancedTrainingCourse
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	if not game_state.remove_credits(course_data.cost):
		push_warning("Not enough credits for course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	apply_training_effect(course, character)
	training_completed.emit(character, course)
	return true

func get_available_courses(character: Character) -> Array[int]:  # Array[GlobalEnums.AdvancedTrainingCourse]
	var available_courses: Array[int] = []
	for course in ADVANCED_TRAINING_COURSES.keys():
		if can_take_course(character, course):
			available_courses.append(course)
	return available_courses

func can_take_course(character: Character, course: int) -> bool:  # GlobalEnums.AdvancedTrainingCourse
	if not character or not ADVANCED_TRAINING_COURSES.has(course):
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	
	# Check if character meets prerequisites
	for prerequisite in course_data.prerequisites:
		if not character.has_skill(prerequisite):
			return false
	
	return true

func attempt_training(character: Character, course: int) -> void:  # GlobalEnums.AdvancedTrainingCourse
	if apply_for_training(character, course):
		if enroll_in_course(character, course):
			print("Training successful: %s completed %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])
		else:
			training_failed.emit(character, course)
			print("Training failed: %s could not enroll in %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])
	else:
		training_failed.emit(character, course)
		print("Application failed: %s was not accepted for %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])

func apply_training_effect(course: int, character: Character) -> void:  # GlobalEnums.AdvancedTrainingCourse
	var course_data = ADVANCED_TRAINING_COURSES[course]
	character.improve_skill(course_data.skill, 2)
