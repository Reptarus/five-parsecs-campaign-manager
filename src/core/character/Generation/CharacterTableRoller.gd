extends RefCounted

const FIRST_NAMES: Array[String] = [
	"Alex", "Blake", "Casey", "Drew", "Ellis",
	"Finn", "Gray", "Harper", "Indigo", "Jules",
	"Kai", "Lee", "Morgan", "Nova", "Orion",
	"Parker", "Quinn", "Remy", "Sage", "Tate",
	"Uri", "Val", "Winter", "Xen", "Yuri", "Zephyr",
	"Ash", "Bryn", "Cael", "Dex", "Ember",
	"Flint", "Haven", "Jace", "Kira", "Lyric",
	"Mars", "Nyx", "Pike", "Rowan", "Sable"
]

const LAST_NAMES: Array[String] = [
	"Adler", "Blackwood", "Chen", "Drake", "Evans",
	"Flynn", "Graves", "Hayes", "Ivanov", "Jones",
	"Kim", "Liang", "Mercer", "Nash", "Ortiz",
	"Park", "Quill", "Reyes", "Smith", "Thorne",
	"Udall", "Vega", "Ward", "Xu", "Yang", "Zhang",
	"Ashford", "Cortez", "Frost", "Harker", "Ito",
	"Kovac", "Mendez", "Okafor", "Russo", "Stark"
]

const TITLES: Array[String] = [
	"Captain", "Commander", "Doctor", "Lieutenant",
	"Major", "Officer", "Pilot", "Ranger", "Scout",
	"Sergeant", "Specialist", "Trooper", "Veteran"
]

static func generate_random_name() -> String:
	var first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name = LAST_NAMES[randi() % LAST_NAMES.size()]

	# Avoid "Blake Blake" — re-roll last name if it matches first
	if first_name == last_name:
		last_name = LAST_NAMES[(randi() + 1) % LAST_NAMES.size()]

	# 20% chance to add a title
	if randf() < 0.2:
		var title = TITLES[randi() % TITLES.size()]
		return title + " " + first_name + " " + last_name

	return first_name + " " + last_name