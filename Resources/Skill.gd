class_name Skill
extends Resource

enum SkillType { COMBAT, GENERAL }

@export var name: String
@export var type: SkillType
@export var level: int = 0

func _init():
	pass

func initialize(_name: String, _type: SkillType) -> Skill:
	name = _name
	type = _type
	return self

func increase_level() -> void:
	level += 1

func to_dict() -> Dictionary:
	return {
		"name": name,
		"type": SkillType.keys()[type],
		"level": level
	}

static func from_dict(data: Dictionary) -> Skill:
	var skill = Skill.new()
	skill.initialize(data["name"], SkillType[data["type"]])
	skill.level = data["level"]
	return skill
