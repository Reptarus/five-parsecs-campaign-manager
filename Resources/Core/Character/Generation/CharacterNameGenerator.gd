# CharacterNameGenerator.gd
class_name CharacterNameGenerator
extends RefCounted

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

const FIRST_NAMES: Array[String] = [
	"John", "Jane", "Alex", "Sarah", "Michael", "Emily", "Zorg", "Xyla", "Krath",
	"Ivan", "Chris", "Bill", "Jason", "K'Erin", "Swift", "Precursor", "Soulless",
	"Converted", "Krorg", "Unity", "Skulker", "Krag"
]

const LAST_NAMES: Array[String] = [
	"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "X'tor",
	"Sorensen", "Modiphius", "Weasel", "Nordic", "Fringe", "Core", "Parsec", "Starport",
	"Galactic", "War", "Swarm", "Hunt", "Bug"
]

const EXTRA_FIRST_NAMES: Array[String] = [
	"Zax", "Vex", "Quark", "Nyx", "Lyra", "Kael", "Jett", "Io", "Hux", "Grix",
	"Faye", "Elix", "Dax", "Cygnus", "Brix", "Astra"
]

const EXTRA_LAST_NAMES: Array[String] = [
	"Voidborn", "Starforge", "Nebula", "Moonwalker", "Lightspeed", "Kuiper", "Jetstream",
	"Ionos", "Hyperion", "Gravity", "Fusion", "Equinox", "Darkmatter", "Comet", "Blazar"
]

static func get_random_name() -> String:
	var first_name := FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name := LAST_NAMES[randi() % LAST_NAMES.size()]
	return first_name + " " + last_name

static func get_random_name_for_origin(origin: GlobalEnums.Origin) -> String:
	var first_name: String
	var last_name: String
	
	match origin:
		GlobalEnums.Origin.MILITARY:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Origin.CORPORATE:
			first_name = "CORP-" + str(randi() % 1000).pad_zeros(3)
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Origin.CRIMINAL:
			first_name = "CR-" + EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Origin.COLONIST:
			first_name = "COL-" + str(randi() % 1000).pad_zeros(3)
			last_name = ""
		GlobalEnums.Origin.NOMAD:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Wanderer"
		GlobalEnums.Origin.ACADEMIC:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Scholar"
		GlobalEnums.Origin.MUTANT:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Evolved"
		GlobalEnums.Origin.HYBRID:
			first_name = "HYB-" + str(randi() % 1000).pad_zeros(3)
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		_:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
	
	return (first_name + " " + last_name).strip_edges()
