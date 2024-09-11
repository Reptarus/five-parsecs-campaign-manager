class_name CharacterAdvancement
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func apply_experience(character, xp_gained: int) -> void:
	character.add_xp(xp_gained)
	check_for_upgrades(character)

func check_for_upgrades(character) -> void:
	var upgrades = get_available_upgrades(character)
	for upgrade in upgrades:
		if character.xp >= upgrade.cost:
			apply_upgrade(character, upgrade)

func get_available_upgrades(character) -> Array:
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
	if character.luck < (3 if character.race == "Human" else 1):
		upgrades.append({"stat": "Luck", "cost": 10})
	return upgrades

func apply_upgrade(character, upgrade: Dictionary) -> void:
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
