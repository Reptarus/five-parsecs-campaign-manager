extends RefCounted

## Character name generator — loads names from data/character_names.json.
## Hardcoded fallback arrays retained for resilience (e.g. Android res:// issues).

static var _names_data: Dictionary = {}
static var _loaded: bool = false

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

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/character_names.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_names_data = json.data
	file.close()

static func _get_first_names() -> Array:
	_ensure_loaded()
	if _names_data.has("first_names") and _names_data["first_names"] is Array and _names_data["first_names"].size() > 0:
		return _names_data["first_names"]
	return FIRST_NAMES

static func _get_last_names() -> Array:
	_ensure_loaded()
	if _names_data.has("last_names") and _names_data["last_names"] is Array and _names_data["last_names"].size() > 0:
		return _names_data["last_names"]
	return LAST_NAMES

static func _get_titles() -> Array:
	_ensure_loaded()
	if _names_data.has("titles") and _names_data["titles"] is Array and _names_data["titles"].size() > 0:
		return _names_data["titles"]
	return TITLES

static func generate_random_name() -> String:
	var firsts := _get_first_names()
	var lasts := _get_last_names()
	var first_name: String = firsts[randi() % firsts.size()]
	var last_name: String = lasts[randi() % lasts.size()]

	# Avoid "Blake Blake" — re-roll last name if it matches first
	if first_name == last_name:
		last_name = lasts[(randi() + 1) % lasts.size()]

	# 20% chance to add a title
	if randf() < 0.2:
		var titles := _get_titles()
		var title: String = titles[randi() % titles.size()]
		return title + " " + first_name + " " + last_name

	return first_name + " " + last_name
