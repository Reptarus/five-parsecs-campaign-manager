class_name CharacterResourceManager
extends RefCounted

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

# Resource types
enum ResourceType {
	CREDITS,
	STORY_POINT,
	PATRON,
	RIVAL,
	QUEST_RUMOR,
	XP
}

# Starting roll types
enum StartingRollType {
	LOW_TECH_WEAPON,
	MILITARY_WEAPON,
	HIGH_TECH_WEAPON,
	GEAR,
	GADGET
}

class ResourceResult:
	var type: ResourceType
	var amount: int
	var roll_str: String = ""
	
	func _init(t: ResourceType, a: int = 1):
		type = t
		amount = a

class StartingRollResult:
	var type: StartingRollType
	var amount: int
	
	func _init(t: StartingRollType, a: int = 1):
		type = t
		amount = a

static func parse_resource(resource_str: String) -> ResourceResult:
	match resource_str:
		"credits_1d6":
			var roll = (randi() % 6) + 1
			var result = ResourceResult.new(ResourceType.CREDITS, roll)
			result.roll_str = "1d6 = %d" % roll
			return result
		"credits_2d6":
			var roll1 = (randi() % 6) + 1
			var roll2 = (randi() % 6) + 1
			var result = ResourceResult.new(ResourceType.CREDITS, roll1 + roll2)
			result.roll_str = "2d6 = %d + %d = %d" % [roll1, roll2, roll1 + roll2]
			return result
		"story_point":
			return ResourceResult.new(ResourceType.STORY_POINT)
		"patron":
			return ResourceResult.new(ResourceType.PATRON)
		"rival":
			return ResourceResult.new(ResourceType.RIVAL)
		"quest_rumor":
			return ResourceResult.new(ResourceType.QUEST_RUMOR)
		"quest_rumors_2":
			return ResourceResult.new(ResourceType.QUEST_RUMOR, 2)
		"xp_2":
			return ResourceResult.new(ResourceType.XP, 2)
		_:
			push_error("Unknown resource type: " + resource_str)
			return null

static func parse_starting_roll(roll_str: String) -> StartingRollResult:
	match roll_str:
		"low_tech_weapon":
			return StartingRollResult.new(StartingRollType.LOW_TECH_WEAPON)
		"military_weapon":
			return StartingRollResult.new(StartingRollType.MILITARY_WEAPON)
		"high_tech_weapon":
			return StartingRollResult.new(StartingRollType.HIGH_TECH_WEAPON)
		"gear":
			return StartingRollResult.new(StartingRollType.GEAR)
		"gadget":
			return StartingRollResult.new(StartingRollType.GADGET)
		_:
			push_error("Unknown starting roll type: " + roll_str)
			return null

static func apply_resources_to_character(character: Character, resources: Array[String]) -> void:
	for resource_str in resources:
		var result = parse_resource(resource_str)
		if result:
			match result.type:
				ResourceType.CREDITS:
					character.add_credits(result.amount, result.roll_str)
				ResourceType.STORY_POINT:
					character.add_story_points(result.amount)
				ResourceType.PATRON:
					character.add_patron()
				ResourceType.RIVAL:
					character.add_rival()
				ResourceType.QUEST_RUMOR:
					character.add_quest_rumors(result.amount)
				ResourceType.XP:
					character.add_experience(result.amount * 10)

static func apply_starting_rolls_to_character(character: Character, rolls: Array[String]) -> void:
	for roll_str in rolls:
		var result = parse_starting_roll(roll_str)
		if result:
			match result.type:
				StartingRollType.LOW_TECH_WEAPON:
					character.roll_and_add_weapon("low_tech")
				StartingRollType.MILITARY_WEAPON:
					character.roll_and_add_weapon("military")
				StartingRollType.HIGH_TECH_WEAPON:
					character.roll_and_add_weapon("high_tech")
				StartingRollType.GEAR:
					character.roll_and_add_gear()
				StartingRollType.GADGET:
					character.roll_and_add_gadget() 