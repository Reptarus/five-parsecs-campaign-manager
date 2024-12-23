# AdvancedTrainingManager.gd
class_name AdvancedTrainingManager
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/data/resources/GameState/GameState.gd")

signal training_completed(character: Resource)
signal training_failed(character: Resource, reason: String)
signal training_cost_updated(new_cost: int)

var game_state: FiveParsecsGameState
var training_cost: int = 100

# Training course costs and requirements based on core rules
const ADVANCED_TRAINING_COURSES := {
	"PILOT_TRAINING": {
		"cost": 20,
		"skill": GameEnums.CharacterStats.REACTIONS,
		"prerequisites": [],
		"bonus": 1
	},
	"COMBAT_SPECIALIST": {
		"cost": 15,
		"skill": GameEnums.CharacterStats.COMBAT_SKILL,
		"prerequisites": [],
		"bonus": 1
	},
	"TECH_EXPERT": {
		"cost": 15,
		"skill": GameEnums.CharacterStats.SAVVY,
		"prerequisites": [],
		"bonus": 1
	},
	"SURVIVAL_EXPERT": {
		"cost": 15,
		"skill": GameEnums.CharacterStats.TOUGHNESS,
		"prerequisites": [],
		"bonus": 1
	},
	"LEADERSHIP": {
		"cost": 25,
		"skill": GameEnums.CharacterStats.SAVVY,
		"prerequisites": ["COMBAT_SPECIALIST"],
		"bonus": 2
	}
}

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

func apply_for_training(character: Resource, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	
	# Check prerequisites
	for prerequisite in course_data.prerequisites:
		if not character.has_completed_training(prerequisite):
			return false
	
	# Application fee is 1 credit per core rules
	var application_fee := 1
	if not game_state.remove_credits(application_fee):
		push_warning("Not enough credits for application fee")
		return false
	
	# Roll 1d6, need 4+ to be accepted per core rules
	var roll := randi() % 6 + 1
	return roll >= 4

func enroll_in_course(character: Resource, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	if not game_state.remove_credits(course_data.cost):
		push_warning("Not enough credits for course: %s" % course)
		return false
	
	apply_training_effect(course, character)
	training_completed.emit(character, course)
	return true

func get_available_courses(character: Resource) -> Array[String]:
	var available_courses: Array[String] = []
	for course in ADVANCED_TRAINING_COURSES.keys():
		if can_take_course(character, course):
				available_courses.append(course)
	return available_courses

func can_take_course(character: Resource, course: String) -> bool:
	if not character or not ADVANCED_TRAINING_COURSES.has(course):
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	
	# Check prerequisites
	for prerequisite in course_data.prerequisites:
		if not character.has_completed_training(prerequisite):
			return false
	
	return true

func attempt_training(character: Resource, course: String) -> void:
	if apply_for_training(character, course):
		if enroll_in_course(character, course):
			print("Training successful: %s completed %s" % [character.name, course])
		else:
			training_failed.emit(character, course)
			print("Training failed: %s could not enroll in %s" % [character.name, course])
	else:
		training_failed.emit(character, course)
		print("Application failed: %s was not accepted for %s" % [character.name, course])

func apply_training_effect(course: String, character: Resource) -> void:
	var course_data = ADVANCED_TRAINING_COURSES[course]
	character.improve_stat(course_data.skill, course_data.bonus)
	character.add_completed_training(course)
