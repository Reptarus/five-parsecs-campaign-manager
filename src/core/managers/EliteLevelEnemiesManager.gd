class_name EliteLevelEnemiesManager
extends Resource

# Core rules elite bonuses
const ELITE_COMBAT_SKILL_BONUS: int = 1
const ELITE_TOUGHNESS_BONUS: int = 1
const ELITE_REACTIONS_BONUS: int = 1
const ELITE_PANIC_REDUCTION: int = 1
const ELITE_CREDIT_BONUS: int = 2

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Enemy = preload("res://src/core/enemy/Enemy.gd")

signal elite_enemy_spawned(enemy: Enemy)
signal elite_enemy_defeated(enemy: Resource)
signal elite_enemy_escaped(enemy: Resource)
signal elite_enemy_level_increased(enemy: Resource, new_level: int)

var game_state: FiveParsecsGameState
var elite_enemies: Array[Resource] = []
var active_elite_enemies: Array[Resource] = []
var defeated_elite_enemies: Array[Resource] = []

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

func generate_elite_enemy(base_enemy: EnemyData) -> EnemyData:
	var elite_enemy = base_enemy.duplicate()
	
	# Apply core rules elite bonuses
	elite_enemy.stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += ELITE_COMBAT_SKILL_BONUS
	elite_enemy.stats[GlobalEnums.CharacterStats.TOUGHNESS] += ELITE_TOUGHNESS_BONUS
	elite_enemy.stats[GlobalEnums.CharacterStats.REACTIONS] += ELITE_REACTIONS_BONUS
	
	# Reduce panic value
	if elite_enemy.panic > ELITE_PANIC_REDUCTION:
		elite_enemy.panic -= ELITE_PANIC_REDUCTION
	
	# Apply elite modifications
	_apply_elite_modifications(elite_enemy)
	
	return elite_enemy

func _apply_elite_modifications(enemy: EnemyData) -> void:
	var modifications = [
		"_apply_elite_weaponry",
		"_apply_elite_armor",
		"_apply_elite_skills",
		"_apply_elite_ability",
		"_apply_elite_leadership"
	]
	
	# Apply 1-2 random modifications per core rules
	var num_mods = randi() % 2 + 1
	modifications.shuffle()
	
	for i in range(num_mods):
		call(modifications[i], enemy)

func _apply_elite_weaponry(enemy: EnemyData) -> void:
	# Upgrade weapons to next tier per core rules
	for weapon in enemy.equipped_weapons:
		match weapon.get_rarity():
			GlobalEnums.ItemRarity.COMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.UNCOMMON)
			GlobalEnums.ItemRarity.UNCOMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.RARE)
			GlobalEnums.ItemRarity.RARE:
				weapon.set_rarity(GlobalEnums.ItemRarity.EPIC)
	
	enemy.special_rules.append("Elite Weaponry: This enemy is equipped with more powerful weapons.")

func _apply_elite_armor(enemy: EnemyData) -> void:
	# Improve armor save per core rules
	if enemy.has_armor_save():
		enemy.improve_armor_save()
	else:
		enemy.add_armor_save(6) # Base 6+ save
	
	enemy.special_rules.append("Elite Armor: This enemy has improved armor or defenses.")

func _apply_elite_skills(enemy: EnemyData) -> void:
	# Additional stat bonuses per core rules
	enemy.stats[GlobalEnums.CharacterStats.SPEED] += 1
	enemy.stats[GlobalEnums.CharacterStats.SAVVY] += 1
	
	enemy.special_rules.append("Elite Skills: This enemy is exceptionally skilled and quick.")

func _apply_elite_ability(enemy: EnemyData) -> void:
	# Add a special ability per core rules
	var abilities = [
		"Fearless: Ignores first failed morale check each battle.",
		"Tactical: Can perform one free reposition move when activated.",
		"Deadly: +1 damage with all attacks.",
		"Resilient: Can ignore one wound per battle.",
		"Quick: Can perform two actions per activation.",
		"Leader: Nearby allies gain +1 to hit."
	]
	
	var ability = abilities[randi() % abilities.size()]
	enemy.special_rules.append(ability)

func _apply_elite_leadership(enemy: EnemyData) -> void:
	enemy.special_rules.append("Elite Leadership: All friendly units within 6\" gain +1 to hit rolls.")

func get_elite_reward(enemy: EnemyData) -> Dictionary:
	var reward = {
		"credits": enemy.get_base_reward() + ELITE_CREDIT_BONUS,
		"items": []
	}
	
	# Elite enemies always drop at least one item per core rules
	var item = _generate_elite_item()
	if item:
		reward.items.append(item)
	
	# 33% chance for second item
	if randf() < 0.33:
		item = _generate_elite_item()
		if item:
			reward.items.append(item)
	
	return reward

func _generate_elite_item() -> Equipment:
	var item_types = [
		GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.GEAR,
		GlobalEnums.ItemType.CONSUMABLE
	]
	
	var type = item_types[randi() % item_types.size()]
	var rarity = _determine_elite_item_rarity()
	
	return game_state.item_generator.generate_item(type, rarity)

func _determine_elite_item_rarity() -> GlobalEnums.ItemRarity:
	var roll = randf()
	
	if roll < 0.5:
		return GlobalEnums.ItemRarity.UNCOMMON
	elif roll < 0.8:
		return GlobalEnums.ItemRarity.RARE
	else:
		return GlobalEnums.ItemRarity.EPIC
