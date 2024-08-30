# AdvancedTrainingManager.gd
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

const ADVANCED_TRAINING_COURSES = {
	"Pilot Training": {
		"cost": 20,
		"effect": func(character): character.pilot_skill += 1
	},
	"Mechanic Training": {
		"cost": 15,
		"effect": func(character): character.mechanic_skill += 1
	},
	"Medical School": {
		"cost": 20,
		"effect": func(character): character.medical_skill += 1
	},
	"Merchant School": {
		"cost": 10,
		"effect": func(character): character.merchant_skill += 1
	},
	"Security Training": {
		"cost": 10,
		"effect": func(character): character.security_skill += 1
	},
	"Broker Training": {
		"cost": 15,
		"effect": func(character): character.broker_skill += 1
	},
	"Bot Technician": {
		"cost": 10,
		"effect": func(character): character.bot_tech_skill += 1
	}
}

func apply_for_training(character: Character, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		return false
	
	var application_fee = 1
	if game_state.current_crew.credits < application_fee:
		return false
	
	game_state.current_crew.credits -= application_fee
	
	var roll = randi() % 6 + randi() % 6 + 2  # 2d6
	if roll >= 4:
		return true
	return false

func enroll_in_course(character: Character, course: String) -> bool:
	if not ADVANCED_TRAINING_COURSES.has(course):
		return false
	
	var course_data = ADVANCED_TRAINING_COURSES[course]
	if game_state.current_crew.credits < course_data.cost:
		return false
	
	game_state.current_crew.credits -= course_data.cost
	course_data.effect.call(character)
	return true

func get_available_courses(character: Character) -> Array:
	var available_courses = []
	for course in ADVANCED_TRAINING_COURSES.keys():
		if not character.has_training(course):
			available_courses.append(course)
	return available_courses
