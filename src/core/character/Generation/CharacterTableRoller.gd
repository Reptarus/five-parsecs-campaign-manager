class_name CharacterTableRoller
extends RefCounted

const FIRST_NAMES = [
	"Alex", "Blake", "Casey", "Drew", "Ellis",
	"Finn", "Gray", "Harper", "Indigo", "Jules",
	"Kai", "Lee", "Morgan", "Nova", "Orion",
	"Parker", "Quinn", "Remy", "Sage", "Tate",
	"Uri", "Val", "Winter", "Xen", "Yuri", "Zephyr"
]

const LAST_NAMES = [
	"Adler", "Blake", "Chen", "Drake", "Evans",
	"Flynn", "Gray", "Hayes", "Ivanov", "Jones",
	"Kim", "Lee", "Morgan", "Nash", "Ortiz",
	"Park", "Quinn", "Reyes", "Smith", "Thorne",
	"Udall", "Vega", "Ward", "Xu", "Yang", "Zhang"
]

const TITLES = [
	"Captain", "Commander", "Doctor", "Lieutenant",
	"Major", "Officer", "Pilot", "Ranger", "Scout",
	"Sergeant", "Specialist", "Trooper", "Veteran"
]

static func generate_random_name() -> String:
	var first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name = LAST_NAMES[randi() % LAST_NAMES.size()]
	
	# 20% chance to add a title
	if randf() < 0.2:
		var title = TITLES[randi() % TITLES.size()]
		return title + " " + first_name + " " + last_name
	
	return first_name + " " + last_name