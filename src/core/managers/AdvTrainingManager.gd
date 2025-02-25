# AdvancedTrainingManager.gd
@tool
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

signal training_completed(character: Character, skill: String)
signal training_failed(character: Character, reason: String)
signal training_cost_updated(new_cost: int)

var game_state: FiveParsecsGameState
var training_cost: int = 100

# Training types and their costs
const TRAINING_COSTS = {
	GameEnums.Training.PILOT: 100,
	GameEnums.Training.MECHANIC: 150,
	GameEnums.Training.MEDICAL: 200,
	GameEnums.Training.MERCHANT: 100,
	GameEnums.Training.SECURITY: 150,
	GameEnums.Training.BROKER: 200,
	GameEnums.Training.BOT_TECH: 250,
	GameEnums.Training.SPECIALIST: 300,
	GameEnums.Training.ELITE: 500
}

# Training requirements and stat bonuses
const TRAINING_REQUIREMENTS = {
	GameEnums.Training.PILOT: {
		"stats": {
			GameEnums.CharacterStats.REACTIONS: 3,
			GameEnums.CharacterStats.NAVIGATION: 2
		},
		"cost": 100
	},
	GameEnums.Training.MECHANIC: {
		"stats": {
			GameEnums.CharacterStats.TECH: 3,
			GameEnums.CharacterStats.SAVVY: 2
		},
		"cost": 150
	},
	GameEnums.Training.MEDICAL: {
		"stats": {
			GameEnums.CharacterStats.TECH: 3,
			GameEnums.CharacterStats.SAVVY: 2
		},
		"cost": 200
	},
	GameEnums.Training.MERCHANT: {
		"stats": {
			GameEnums.CharacterStats.SOCIAL: 3,
			GameEnums.CharacterStats.SAVVY: 2
		},
		"cost": 100
	},
	GameEnums.Training.SECURITY: {
		"stats": {
			GameEnums.CharacterStats.COMBAT_SKILL: 3,
			GameEnums.CharacterStats.REACTIONS: 2
		},
		"cost": 150
	},
	GameEnums.Training.BROKER: {
		"stats": {
			GameEnums.CharacterStats.SOCIAL: 3,
			GameEnums.CharacterStats.SAVVY: 2
		},
		"cost": 200
	},
	GameEnums.Training.BOT_TECH: {
		"stats": {
			GameEnums.CharacterStats.TECH: 4,
			GameEnums.CharacterStats.SAVVY: 2
		},
		"cost": 250
	},
	GameEnums.Training.SPECIALIST: {
		"stats": {
			GameEnums.CharacterStats.COMBAT_SKILL: 4,
			GameEnums.CharacterStats.REACTIONS: 3
		},
		"cost": 300
	},
	GameEnums.Training.ELITE: {
		"stats": {
			GameEnums.CharacterStats.COMBAT_SKILL: 5,
			GameEnums.CharacterStats.REACTIONS: 4,
			GameEnums.CharacterStats.TOUGHNESS: 3
		},
		"cost": 500
	}
}

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

## Applies for training in a specific course
## Parameters:
## - character: The character applying for training
## - course: The training course name
## Returns: Whether the application was successful
func apply_for_training(character: Character, course: String) -> bool:
	if not TRAINING_COSTS.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var course_data: Dictionary = TRAINING_REQUIREMENTS[course]
	
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

## Enrolls a character in a training course
## Parameters:
## - character: The character to enroll
## - course: The training course name
## Returns: Whether enrollment was successful
func enroll_in_course(character: Character, course: String) -> bool:
	if not TRAINING_COSTS.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var course_data: Dictionary = TRAINING_REQUIREMENTS[course]
	if not game_state.remove_credits(course_data.cost):
		push_warning("Not enough credits for course: %s" % course)
		return false
	
	apply_training_effect(course, character)
	training_completed.emit(character, course)
	return true

## Gets available courses for a character
## Parameters:
## - character: The character to check courses for
## Returns: Array of available course names
func get_available_courses(character: Character) -> Array[String]:
	var available_courses: Array[String] = []
	for course in TRAINING_COSTS.keys():
		if can_take_course(character, course):
				available_courses.append(course)
	return available_courses

## Checks if a character can take a specific course
## Parameters:
## - character: The character to check
## - course: The course name to check
## Returns: Whether the character can take the course
func can_take_course(character: Character, course: String) -> bool:
	if not character or not TRAINING_COSTS.has(course):
		return false
	
	var course_data: Dictionary = TRAINING_REQUIREMENTS[course]
	
	# Check prerequisites
	for prerequisite in course_data.prerequisites:
		if not character.has_completed_training(prerequisite):
			return false
	
	return true

## Attempts to enroll a character in training
## Parameters:
## - character: The character to train
## - course: The course to attempt
func attempt_training(character: Character, course: String) -> void:
	if apply_for_training(character, course):
		if enroll_in_course(character, course):
			print("Training successful: %s completed %s" % [character.name, course])
		else:
			training_failed.emit(character, course)
			print("Training failed: %s could not enroll in %s" % [character.name, course])
	else:
		training_failed.emit(character, course)
		print("Application failed: %s was not accepted for %s" % [character.name, course])

## Applies the training effect to a character
## Parameters:
## - course: The course name
## - character: The character to apply training to
func apply_training_effect(course: String, character: Character) -> void:
	var course_data: Dictionary = TRAINING_REQUIREMENTS[course]
	character.improve_stat(course_data.skill, course_data.bonus)
	character.add_completed_training(course)
