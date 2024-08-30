class_name Skill
extends Resource

enum SkillType { COMBAT, GENERAL }

@export var name: String
@export var type: SkillType
@export var level: int = 0

func increase_level() -> void:
	level += 1

func to_dict() -> Dictionary:
	return {
		"name": name,
		"type": SkillType.keys()[type],
		"level": level
	}

static func from_dict(data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.name = data["name"]
	skill.type = SkillType[data["type"]]
	skill.level = data["level"]
	return skill
