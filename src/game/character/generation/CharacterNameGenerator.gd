# CharacterNameGenerator.gd
class_name FPCM_CharacterNameGenerator
extends RefCounted

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

const FIRST_NAMES: Array[String] = [
	# Original names
	"John", "Jane", "Alex", "Sarah", "Michael", "Emily", "Ivan", "Chris",
	"Bill", "Jason", "Maria", "David", "Anna", "Robert", "Lisa",
	"Marcus", "Elena", "Kai", "Zara", "Omar", "Nina", "Felix", "Maya",
	"Dante", "Luna", "Atlas", "Nova", "Cora", "Rex", "Vera",

	# Sci-fi references (subtle variants)
	"Malcolm", "River", "Kaidan", "Tali", "Gordon", "Ellen", "Isaac",
	"Amos", "James", "Naomi", "Alex", "Camina", "Kara", "William",
	"Jean", "Honor", "Miles", "Cordelia", "Ender", "Valentine",
	"Duncan", "Leto", "Paul", "Chani", "Zoe", "Wash", "Kaylee",
	"Gaius", "Laura", "Kara", "Shepard", "Garrus", "Liara", "Tali",
	"Cortana", "Miranda", "Jacob", "Thane", "Legion", "Mordin",

	# Military/Tough sounding names
	"Stone", "Steel", "Brick", "Slate", "Flint", "Jet", "Drake",
	"Storm", "Blaze", "Hawk", "Wolf", "Viper", "Phoenix", "Raven",

	# Cyberpunk-inspired
	"Spike", "Ghost", "Zero", "Cipher", "Vector", "Cache", "Pixel",
	"Binary", "Core", "Data", "Net", "Chrome", "Neon", "Glitch"
]

const LAST_NAMES: Array[String] = [
	# Original names
	"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
	"Davis", "Anderson", "Wilson", "Taylor", "Moore", "Martin", "Lee",
	"Chen", "Patel", "Kim", "Singh", "Cohen", "Murphy", "O'Brien",
	"Kowalski", "Petrov", "Santos", "Silva", "Kumar", "Zhang", "Sato",

	# Sci-fi references
	"Shepard", "Ryder", "Vakarian", "Reynolds", "Holden", "Burton",
	"Nagata", "Kamal", "Drummer", "Thrace", "Adama", "Roslin",
	"Freeman", "Vance", "Ripley", "Hicks", "Rico", "Hawthorne",
	"Vorkosigan", "Wiggin", "Naismith", "Atreides", "Harkonnen",
	"Malcolm", "Serra", "Washburne", "Frye", "Baltar", "Roslin",

	# Military/Corporate sounding
	"Sterling", "Drake", "Stone", "Steele", "Black", "Frost", "Storm",
	"Wolf", "Sharp", "Edge", "Cross", "Shield", "Striker", "Viper",

	# Cyberpunk-inspired
	"Chrome", "Wire", "Steel", "Flux", "Void", "Shadow", "Neon",
	"Circuit", "Binary", "Core", "Vector", "Matrix", "Grid", "Net",

	# Megacorp names
	"Weyland", "Tyrell", "Rosen", "Tessier", "Ashpool", "Maelcum",
	"Wintermute", "Armitage", "Yakamoto", "Arasaka", "Militech"
]

const ALIEN_FIRST_NAMES: Array[String] = [
	# Warhammer 40k Primarch names (public domain-inspired)
	"Horus", "Lion", "Fulgrim", "Perturabo", "Jaghatai", "Leman",
	"Rogal", "Konrad", "Sanguinius", "Ferrus", "Angron", "Roboute",
	"Guilliman", "Sanguinius", "Vulkan", "Magnus", "Mortarion",
	"Perturabo", "Fulgrim", "Lorgar", "Corax", "Ferrus", "Dorn"
]

const ALIEN_LAST_NAMES: Array[String] = [
	# Original sci-fi surnames
	"Starforge", "Voidwalker", "Nebula", "Cosmic", "Stellar",
	"Astral", "Quantum", "Plasma", "Fusion", "Reactor",
	"Hyperdrive", "Warpcore", "Photon", "Neutron", "Quark",

	# Tech/Cyberpunk
	"Nexus", "Matrix", "Vector", "Cipher", "Binary", "Quantum",
	"Cortex", "Neural", "Cyber", "Digital", "Chrome", "Silicon"
]

static func get_random_name() -> String:
	var first_name := FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name := LAST_NAMES[randi() % LAST_NAMES.size()]
	return str(first_name) + " " + str(last_name)
static func get_random_name_for_origin(origin: GlobalEnums.Origin) -> String:
	var first_name: String
	var last_name: String

	match origin:
		GlobalEnums.Origin.HUMAN:
			first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
			last_name = LAST_NAMES[randi() % LAST_NAMES.size()]
		GlobalEnums.Origin.ENGINEER:
			first_name = "Eng-" + ALIEN_FIRST_NAMES[randi() % ALIEN_FIRST_NAMES.size()]
			last_name = ALIEN_LAST_NAMES[randi() % ALIEN_LAST_NAMES.size()]
		GlobalEnums.Origin.FERAL:
			first_name = ALIEN_FIRST_NAMES[randi() % ALIEN_FIRST_NAMES.size()]
			last_name = "Feral"
		GlobalEnums.Origin.KERIN:
			first_name = "K'" + ALIEN_FIRST_NAMES[randi() % ALIEN_FIRST_NAMES.size()]
			last_name = "Erin"
		GlobalEnums.Origin.PRECURSOR:
			first_name = "Ancient-" + str(randi() % 1000).pad_zeros(3)
			last_name = ALIEN_LAST_NAMES[randi() % ALIEN_LAST_NAMES.size()]
		GlobalEnums.Origin.SOULLESS:
			first_name = "Unit-" + str(randi() % 1000).pad_zeros(3)
			last_name = ""
		GlobalEnums.Origin.SWIFT:
			first_name = ALIEN_FIRST_NAMES[randi() % ALIEN_FIRST_NAMES.size()]
			last_name = "Swift"
		GlobalEnums.Origin.BOT:
			first_name = "Bot-" + str(randi() % 1000).pad_zeros(3)
			last_name = ALIEN_LAST_NAMES[randi() % ALIEN_LAST_NAMES.size()]
		_:
			first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
			last_name = LAST_NAMES[randi() % LAST_NAMES.size()]

	return (str(first_name) + " " + str(last_name)).strip_edges()

static func generate_character_name() -> String:
	# Get a random name from the appropriate tables
	var first_names = [
		"Alex", "Morgan", "Jordan", "Taylor", "Casey", "Riley", "Sam", "Jamie",
		"Quinn", "Avery", "Blake", "Charlie", "Drew", "Emerson", "Finley", "Gray",
		"Harper", "Indigo", "Jules", "Kai", "Logan", "Max", "Nova", "Orion",
		"Phoenix", "Quinn", "Remy", "Sage", "Tate", "Unity", "Val", "Winter",
		"Xen", "Yuri", "Zen"
	]

	var last_names = [
		"Smith", "Jones", "Williams", "Brown", "Taylor", "Davies", "Wilson",
		"Evans", "Thomas", "Roberts", "Johnson", "Walker", "Wright", "Robinson",
		"Thompson", "White", "Hughes", "Edwards", "Green", "Hall", "Wood",
		"Harris", "Lewis", "Martin", "Jackson", "Clarke", "Clark", "Scott",
		"Turner", "Hill", "Moore", "Cooper", "Ward", "Morris", "King"
	]

	return "%s %s" % [
		first_names[randi() % first_names.size()],
		last_names[randi() % last_names.size()]
	]

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null