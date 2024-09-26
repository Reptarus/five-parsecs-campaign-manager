class_name CharacterAdvancement
extends Node

var character: Character

func _init(_character: Character):
	character = _character

func get_xp_for_next_level(current_level: int) -> int:
	# Implement XP requirements for leveling up
	return current_level * 100  # Example: 100 XP per level

func get_available_upgrades(character: Character) -> Array:
	var upgrades = []
	if character.reactions < 6:
		upgrades.append({"stat": "Reactions", "cost": 7})
	if character.combat_skill < 5:
		upgrades.append({"stat": "Combat Skill", "cost": 7})
	if character.speed < 8:
		upgrades.append({"stat": "Speed", "cost": 5})
	if character.savvy < 5:
		upgrades.append({"stat": "Savvy", "cost": 5})
	if character.toughness < 6:
		upgrades.append({"stat": "Toughness", "cost": 6})
	if character.luck < (3 if character.species == "Human" else 1):
		upgrades.append({"stat": "Luck", "cost": 10})
	return upgrades

func apply_upgrade(upgrade: Dictionary) -> void:
	character.xp -= upgrade.cost
	match upgrade.stat:
		"Reactions":
			character.reactions += 1
		"Combat Skill":
			character.combat_skill += 1
		"Speed":
			character.speed += 1
		"Savvy":
			character.savvy += 1
		"Toughness":
			character.toughness += 1
		"Luck":
			character.luck += 1
	print(character.name + " upgraded " + upgrade.stat + " to " + str(character.get(upgrade.stat.to_lower())))

func apply_experience(xp_gained: int) -> void:
	character.add_xp(xp_gained)
	check_for_upgrades()

func check_for_upgrades() -> void:
	var upgrades = get_available_upgrades(character)
	for upgrade in upgrades:
		if character.xp >= upgrade.cost:
			character.emit_signal("request_upgrade_choice", upgrades)
			break
