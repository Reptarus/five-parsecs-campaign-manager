# AdvancedTrainingManager.gd
class_name AdvancedTrainingManager
extends Node

signal training_completed(character: Character, course: GlobalEnums.AdvancedTrainingCourse)
signal training_failed(character: Character, course: GlobalEnums.AdvancedTrainingCourse)

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

const ADVANCED_TRAINING_COURSES := {
	GlobalEnums.AdvancedTrainingCourse.PILOT_TRAINING: {
		"cost": 1000,
		"skill": GlobalEnums.SkillType.TECHNICAL,
	},
	GlobalEnums.AdvancedTrainingCourse.HACKING_MASTERY: {
		"cost": 1200,
		"skill": GlobalEnums.SkillType.TECHNICAL,
	},
	GlobalEnums.AdvancedTrainingCourse.ADVANCED_COMBAT_TACTICS: {
		"cost": 1500,
		"skill": GlobalEnums.SkillType.COMBAT,
	},
	GlobalEnums.AdvancedTrainingCourse.XENOBIOLOGY: {
		"cost": 1300,
		"skill": GlobalEnums.SkillType.SURVIVAL,
	},
	GlobalEnums.AdvancedTrainingCourse.NEGOTIATION_EXPERTISE: {
		"cost": 1100,
		"skill": GlobalEnums.SkillType.SOCIAL,
	}
}

func apply_for_training(_character: Character, course: GlobalEnums.AdvancedTrainingCourse) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	var application_fee := 1
	if not game_state.remove_credits(application_fee):
		push_warning("Not enough credits for application fee")
		return false
	
	var roll := GameManager.roll_dice(2, 6)  # 2d6
	return roll >= 4

func enroll_in_course(character: Character, course: GlobalEnums.AdvancedTrainingCourse) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	var course_data: Dictionary = ADVANCED_TRAINING_COURSES[course]
	if not game_state.remove_credits(course_data.cost):
		push_warning("Not enough credits for course: %s" % GlobalEnums.AdvancedTrainingCourse.keys()[course])
		return false
	
	course_data.effect.call(character)
	training_completed.emit(character, course)
	return true

func get_available_courses(character: Character) -> Array[GlobalEnums.AdvancedTrainingCourse]:
	var available_courses: Array[GlobalEnums.AdvancedTrainingCourse] = []
	for course in ADVANCED_TRAINING_COURSES.keys():
		if not character.has_training(course):
			available_courses.append(course)
	return available_courses

func attempt_training(character: Character, course: GlobalEnums.AdvancedTrainingCourse) -> void:
	if apply_for_training(character, course):
		if enroll_in_course(character, course):
			print("Training successful: %s completed %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])
		else:
			training_failed.emit(character, course)
			print("Training failed: %s could not enroll in %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])
	else:
		training_failed.emit(character, course)
		print("Application failed: %s was not accepted for %s" % [character.name, GlobalEnums.AdvancedTrainingCourse.keys()[course]])

func apply_training_effect(course: GlobalEnums.AdvancedTrainingCourse, character: Character) -> void:
	var skill = ADVANCED_TRAINING_COURSES[course]["skill"]
	character.improve_skill(skill, 2)
