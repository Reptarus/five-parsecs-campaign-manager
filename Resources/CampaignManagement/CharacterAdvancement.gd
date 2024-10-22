class_name CharacterAdvancement
extends Node

signal upgrade_available(upgrades: Array)

var character: Character

func _init(_character: Character) -> void:
	character = _character

func get_xp_for_next_level(current_level: int) -> int:
	return current_level * 100  # 100 XP per level

func get_available_upgrades() -> Array:
	var upgrades := []
	if character.reactions < 6:
		upgrades.append({"type": GlobalEnums.SkillType.COMBAT, "stat": "Reactions", "cost": 7})
	if character.combat_skill < 5:
		upgrades.append({"type": GlobalEnums.SkillType.COMBAT, "stat": "Combat Skill", "cost": 7})
	if character.speed < 8:
		upgrades.append({"type": GlobalEnums.SkillType.SURVIVAL, "stat": "Speed", "cost": 5})
	if character.savvy < 5:
		upgrades.append({"type": GlobalEnums.SkillType.TECHNICAL, "stat": "Savvy", "cost": 5})
	if character.toughness < 6:
		upgrades.append({"type": GlobalEnums.SkillType.SURVIVAL, "stat": "Toughness", "cost": 6})
	if character.luck < (3 if character.species == GlobalEnums.Species.HUMAN else 1):
		upgrades.append({"type": GlobalEnums.SkillType.SOCIAL, "stat": "Luck", "cost": 10})
	return upgrades

func apply_upgrade(upgrade: Dictionary) -> void:
	if character.xp < upgrade.cost:
		push_error("Not enough XP to apply upgrade")
		return

	character.xp -= upgrade.cost
	var stat_name = upgrade.stat.to_lower().replace(" ", "_")
	var new_value = character.get(stat_name) + 1
	character.stat_distribution.update_stat(stat_name, new_value)
	print("%s upgraded %s to %d" % [character.name, upgrade.stat, new_value])

func apply_experience(xp_gained: int) -> void:
	character.add_xp(xp_gained)
	check_for_upgrades()

func check_for_upgrades() -> void:
	var upgrades := get_available_upgrades()
	for upgrade in upgrades:
		if character.xp >= upgrade.cost:
			upgrade_available.emit(upgrades)
			break
