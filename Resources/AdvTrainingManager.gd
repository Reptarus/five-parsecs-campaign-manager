# AdvancedTrainingManager.gd
class_name AdvancedTrainingManager
extends Node

signal training_completed(character: Character, course: String)
signal training_failed(character: Character, course: String)

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

const ADVANCED_TRAINING_COURSES = {
	"Pilot Training": {
		"cost": 20,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.TECHNICAL, 1)
	},
	"Combat Training": {
		"cost": 25,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.COMBAT, 1)
	},
	"Medical School": {
		"cost": 20,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.TECHNICAL, 1)
	},
	"Negotiation Course": {
		"cost": 15,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.SOCIAL, 1)
	},
	"Survival Training": {
		"cost": 18,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.SURVIVAL, 1)
	},
	"Hacking Masterclass": {
		"cost": 22,
		"effect": func(character: Character): character.increase_skill(GlobalEnums.SkillType.TECHNICAL, 1)
	}
}

func apply_for_training(character: Character, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var application_fee = 1
	if not game_state.remove_credits(application_fee):
		push_warning("Not enough credits for application fee")
		return false
	
	var roll = GameManager.roll_dice(2, 6)  # 2d6
	if roll >= 4:
		return true
	return false

func enroll_in_course(character: Character, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		push_error("Invalid course: %s" % course)
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	if not game_state.remove_credits(course_data.cost):
		push_warning("Not enough credits for course: %s" % course)
		return false
	
	course_data.effect.call(character)
	training_completed.emit(character, course)
	return true

func get_available_courses(character: Character) -> Array[String]:
	var available_courses: Array[String] = []
	for course in ADVANCED_TRAINING_COURSES.keys():
		if not character.has_training(course):
			available_courses.append(course)
	return available_courses

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
