class_name EliteLevelEnemiesManager
extends Resource

const ELITE_DAMAGE_BONUS: int = 1
const ELITE_TOUGHNESS_BONUS: int = 1
const ELITE_COMBAT_SKILL_BONUS: int = 1
const ELITE_PANIC_REDUCTION: int = 1

enum EliteAbility {
	REGENERATION,
	TELEPORT,
	ENERGY_SHIELD,
	BERSERKER,
	CAMOUFLAGE
}

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_elite_enemy(enemy_type: String) -> Dictionary:
	var base_enemy: Dictionary = EnemyTypes.get_enemy_type(enemy_type)
	assert(base_enemy, "Invalid enemy type: " + enemy_type)
	
	var elite_enemy: Dictionary = base_enemy.duplicate(true)
	
	elite_enemy.numbers += 1
	elite_enemy.combat_skill = mini(elite_enemy.combat_skill + ELITE_COMBAT_SKILL_BONUS, 3)
	elite_enemy.toughness = mini(elite_enemy.toughness + ELITE_TOUGHNESS_BONUS, 6)
	
	if "panic" in elite_enemy:
		elite_enemy.panic = _reduce_panic(elite_enemy.panic)
	
	elite_enemy.special_rules.append("Elite: This enemy is tougher and more skilled than normal.")
	
	return _apply_elite_modifications(elite_enemy)

func _reduce_panic(panic: String) -> String:
	var panic_values := panic.split("-")
	if panic_values.size() == 2:
		var lower := int(panic_values[0])
		var upper := int(panic_values[1])
		upper = maxi(lower, upper - ELITE_PANIC_REDUCTION)
		return "%d-%d" % [lower, upper]
	elif panic_values.size() == 1:
		return str(maxi(0, int(panic_values[0]) - ELITE_PANIC_REDUCTION))
	else:
		return panic  # Return original if format is unexpected

func _apply_elite_modifications(enemy: Dictionary) -> Dictionary:
	var roll := randf()
	
	if roll <= 0.2:
		enemy = apply_elite_weaponry(enemy)
	elif roll <= 0.4:
		enemy = _apply_elite_armor(enemy)
	elif roll <= 0.6:
		enemy = _apply_elite_skills(enemy)
	elif roll <= 0.8:
		enemy = _apply_elite_ability(enemy)
	else:
		enemy = _apply_elite_leadership(enemy)
	
	return enemy

func apply_elite_weaponry(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	var weapons: Array = (new_enemy.get("weapons", "") as String).split(" ")
	var new_weapons: Array[String] = []
	
	for weapon in weapons:
		match weapon:
			"1A": new_weapons.append("2B")
			"1B": new_weapons.append("2C")
			"2A": new_weapons.append("3B")
			"2B", "2C": new_weapons.append("3C")
			"3A", "3B", "3C": new_weapons.append(weapon)
	
	new_enemy["weapons"] = " ".join(new_weapons)
	new_enemy["special_rules"].append("Elite Weaponry: This enemy is equipped with more powerful weapons.")
	return new_enemy

func _apply_elite_armor(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	if "Saving Throw" in new_enemy:
		var current_save := int(new_enemy["Saving Throw"].split("+")[0])
		new_enemy["Saving Throw"] = "%d+" % maxi(current_save - 1, 4)
	else:
		new_enemy["Saving Throw"] = "5+"
	
	new_enemy.special_rules.append("Elite Armor: This enemy has improved armor or defenses.")
	return new_enemy

func _apply_elite_skills(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	new_enemy.combat_skill = mini(new_enemy.combat_skill + ELITE_COMBAT_SKILL_BONUS, 3)
	new_enemy.speed += 1
	new_enemy.special_rules.append("Elite Skills: This enemy is exceptionally skilled and quick.")
	return new_enemy

func _apply_elite_ability(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	var ability: EliteAbility = EliteAbility.values()[randi() % EliteAbility.size()]
	
	match ability:
		EliteAbility.REGENERATION:
			new_enemy.special_rules.append("Regeneration: At the end of each round, remove 1 Stun marker.")
		EliteAbility.TELEPORT:
			new_enemy.special_rules.append("Teleport: Once per battle, can move to any point on the battlefield as a free action.")
		EliteAbility.ENERGY_SHIELD:
			new_enemy.special_rules.append("Energy Shield: The first hit each round is automatically negated.")
		EliteAbility.BERSERKER:
			new_enemy.special_rules.append("Berserker: Gains +1 to all rolls when wounded.")
		EliteAbility.CAMOUFLAGE:
			new_enemy.special_rules.append("Camouflage: -1 to all enemy hit rolls against this enemy when in cover.")
	
	return new_enemy

func _apply_elite_leadership(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	new_enemy.special_rules.append("Elite Leadership: All friendly units within 6\" gain +1 to hit rolls.")
	return new_enemy

func get_elite_enemy_reward(_enemy: Dictionary) -> Dictionary:
	# TODO: Implement elite enemy reward generation
	return {
		"credits": randi() % 6 + 5,
		"item": null  # TODO: Generate random item reward
	}
