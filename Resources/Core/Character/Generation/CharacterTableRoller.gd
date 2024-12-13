class_name CharacterTableRoller
extends RefCounted

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

# Background Table Results
class BackgroundResult:
	var background: GameEnums.CharacterBackground
	var description: String
	var stat_bonus: Dictionary
	var resources: Array
	var starting_rolls: Array
	var special_rules: Array
	
	func _init(bg: GameEnums.CharacterBackground, desc: String = "", stats: Dictionary = {}, res: Array = [], rolls: Array = [], rules: Array = []):
		background = bg
		description = desc
		stat_bonus = stats
		resources = res
		starting_rolls = rolls
		special_rules = rules

# Class Table Results
class ClassResult:
	var character_class: GameEnums.CharacterClass
	var description: String
	var stat_bonus: Dictionary
	var resources: Array
	var starting_rolls: Array
	var special_rules: Array
	
	func _init(cls: GameEnums.CharacterClass, desc: String = "", stats: Dictionary = {}, res: Array = [], rolls: Array = [], rules: Array = []):
		character_class = cls
		description = desc
		stat_bonus = stats
		resources = res
		starting_rolls = rolls
		special_rules = rules

# Motivation Table Results
class MotivationResult:
	var motivation: GameEnums.CharacterMotivation
	var description: String
	var stat_bonus: Dictionary
	var resources: Array
	var starting_rolls: Array
	var special_rules: Array
	
	func _init(mot: GameEnums.CharacterMotivation, desc: String = "", stats: Dictionary = {}, res: Array = [], rolls: Array = [], rules: Array = []):
		motivation = mot
		description = desc
		stat_bonus = stats
		resources = res
		starting_rolls = rolls
		special_rules = rules

# Get background data by index
static func get_background_data(index: int) -> BackgroundResult:
	var bg = GameEnums.CharacterBackground.values()[index]
	
	match bg:
		GameEnums.CharacterBackground.PEACEFUL_HIGH_TECH_COLONY:
			return BackgroundResult.new(
				bg,
				"A prosperous colony with advanced technology and comfortable living conditions.",
				{"SAVVY": 1},
				["credits_1d6"],
				[],
				["Access to advanced medical facilities", "Well-connected in tech circles"]
			)
		GameEnums.CharacterBackground.GIANT_OVERCROWDED_DYSTOPIAN_CITY:
			return BackgroundResult.new(
				bg,
				"A massive urban sprawl where millions live in cramped conditions.",
				{"SPEED": 1},
				[],
				[],
				["Street-smart", "Knows the undercity layout"]
			)
		# Add more background cases here...
		_:
			return BackgroundResult.new(bg)

# Get class data by index
static func get_class_data(index: int) -> ClassResult:
	var cls = GameEnums.CharacterClass.values()[index]
	
	match cls:
		GameEnums.CharacterClass.WORKING_CLASS:
			return ClassResult.new(
				cls,
				"Hard-working individuals who know the value of honest labor.",
				{"SAVVY": 1, "LUCK": 1},
				[],
				[],
				["Skilled at repairs", "Good with tools"]
			)
		GameEnums.CharacterClass.TECHNICIAN:
			return ClassResult.new(
				cls,
				"Technical experts who can fix almost anything.",
				{"SAVVY": 1},
				[],
				["gear"],
				["Tech specialist", "Can jury-rig equipment"]
			)
		# Add more class cases here...
		_:
			return ClassResult.new(cls)

# Get motivation data by index
static func get_motivation_data(index: int) -> MotivationResult:
	var mot = GameEnums.CharacterMotivation.values()[index]
	
	match mot:
		GameEnums.CharacterMotivation.WEALTH:
			return MotivationResult.new(
				mot,
				"Driven by the pursuit of riches and material success.",
				{},
				["credits_1d6"],
				[],
				["Good at haggling", "Knows valuable items"]
			)
		GameEnums.CharacterMotivation.FAME:
			return MotivationResult.new(
				mot,
				"Seeks recognition and renown across the galaxy.",
				{},
				["story_point"],
				[],
				["Charismatic", "Well-known in some circles"]
			)
		# Add more motivation cases here...
		_:
			return MotivationResult.new(mot)

# Roll on Background Table (1-100)
static func roll_background() -> BackgroundResult:
	var roll := randi() % 100 + 1
	var bg: GameEnums.CharacterBackground
	var desc := ""
	var stats := {}
	var res := []
	var rolls := []
	var rules := []
	
	match roll:
		1-4: 
			bg = GameEnums.CharacterBackground.PEACEFUL_HIGH_TECH_COLONY
			desc = "A prosperous colony with advanced technology and comfortable living conditions."
			stats = {"SAVVY": 1}
			res = ["credits_1d6"]
			rules = ["Access to advanced medical facilities", "Well-connected in tech circles"]
		5-9:
			bg = GameEnums.CharacterBackground.GIANT_OVERCROWDED_DYSTOPIAN_CITY
			desc = "A massive urban sprawl where millions live in cramped conditions."
			stats = {"SPEED": 1}
			rules = ["Street-smart", "Knows the undercity layout"]
		# Add more roll cases here...
		_:  # 98-100
			bg = GameEnums.CharacterBackground.ALIEN_CULTURE
			desc = "Raised among non-human species with unique customs and technology."
			rolls = ["high_tech_weapon"]
			rules = ["Understands alien cultures", "Speaks multiple languages"]
	
	return BackgroundResult.new(bg, desc, stats, res, rolls, rules)

# Roll on Motivation Table (1-100)
static func roll_motivation() -> MotivationResult:
	var roll := randi() % 100 + 1
	var mot: GameEnums.CharacterMotivation
	var desc := ""
	var stats := {}
	var res := []
	var rolls := []
	var rules := []
	
	match roll:
		1-8:
			mot = GameEnums.CharacterMotivation.WEALTH
			desc = "Driven by the pursuit of riches and material success."
			res = ["credits_1d6"]
			rules = ["Good at haggling", "Knows valuable items"]
		9-14:
			mot = GameEnums.CharacterMotivation.FAME
			desc = "Seeks recognition and renown across the galaxy."
			res = ["story_point"]
			rules = ["Charismatic", "Well-known in some circles"]
		# Add more roll cases here...
		_:  # 96-100
			mot = GameEnums.CharacterMotivation.FREEDOM
			desc = "Values personal liberty and independence above all else."
			stats = {"XP": 2}
			rules = ["Independent spirit", "Resists authority"]
	
	return MotivationResult.new(mot, desc, stats, res, rolls, rules)

# Roll on Class Table (1-100)
static func roll_class() -> ClassResult:
	var roll := randi() % 100 + 1
	var cls: GameEnums.CharacterClass
	var desc := ""
	var stats := {}
	var res := []
	var rolls := []
	var rules := []
	
	match roll:
		1-5:
			cls = GameEnums.CharacterClass.WORKING_CLASS
			desc = "Hard-working individuals who know the value of honest labor."
			stats = {"SAVVY": 1, "LUCK": 1}
			rules = ["Skilled at repairs", "Good with tools"]
		6-9:
			cls = GameEnums.CharacterClass.TECHNICIAN
			desc = "Technical experts who can fix almost anything."
			stats = {"SAVVY": 1}
			rolls = ["gear"]
			rules = ["Tech specialist", "Can jury-rig equipment"]
		# Add more roll cases here...
		_:  # 97-100
			cls = GameEnums.CharacterClass.SCAVENGER
			desc = "Survives by finding and selling valuable salvage."
			res = ["quest_rumor"]
			rolls = ["high_tech_weapon"]
			rules = ["Knows valuable salvage", "Good at finding hidden items"]
	
	return ClassResult.new(cls, desc, stats, res, rolls, rules)

# Generate a random character name
static func generate_random_name() -> String:
	var first_names := [
		"Alex", "Morgan", "Jordan", "Casey", "Taylor", "Sam", "Riley", "Quinn",
		"Avery", "Blake", "Charlie", "Drew", "Ellis", "Finn", "Gray", "Harper"
	]
	var last_names := [
		"Smith", "Jones", "Williams", "Brown", "Taylor", "Davies", "Wilson",
		"Evans", "Thomas", "Roberts", "Johnson", "Walker", "Wright", "Clarke"
	]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()] 