@tool
extends Node

const ELITE_COMBAT_SKILL_BONUS: int = 2
const ELITE_TOUGHNESS_BONUS: int = 2
const ELITE_REACTIONS_BONUS: int = 1

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")
const Weapon = preload("res://src/core/systems/items/Weapon.gd")

## Upgrades a regular enemy to an elite version
## Parameters:
## - enemy: The enemy to upgrade
func upgrade_enemy_to_elite(enemy: Enemy) -> void:
	# Increase core stats
	enemy.stats[GameEnums.CharacterStats.COMBAT_SKILL] += ELITE_COMBAT_SKILL_BONUS
	enemy.stats[GameEnums.CharacterStats.TOUGHNESS] += ELITE_TOUGHNESS_BONUS
	enemy.stats[GameEnums.CharacterStats.REACTIONS] += ELITE_REACTIONS_BONUS
	
	# Upgrade weapons
	for weapon in enemy.weapons:
		upgrade_weapon_rarity(weapon)
	
	# Add elite characteristic
	if not GameEnums.EnemyCharacteristic.ELITE in enemy.characteristics:
		enemy.characteristics.append(GameEnums.EnemyCharacteristic.ELITE)

## Upgrades a weapon's rarity to the next tier
## Parameters:
## - weapon: The weapon to upgrade
func upgrade_weapon_rarity(weapon: Weapon) -> void:
	match weapon.get_rarity():
		GameEnums.ItemRarity.COMMON:
			weapon.set_rarity(GameEnums.ItemRarity.UNCOMMON)
		GameEnums.ItemRarity.UNCOMMON:
			weapon.set_rarity(GameEnums.ItemRarity.RARE)
		GameEnums.ItemRarity.RARE:
			weapon.set_rarity(GameEnums.ItemRarity.EPIC)
		GameEnums.ItemRarity.EPIC:
			weapon.set_rarity(GameEnums.ItemRarity.LEGENDARY)

func upgrade_enemy_to_boss(enemy: Enemy) -> void:
	# First make them elite
	upgrade_enemy_to_elite(enemy)
	
	# Then add boss bonuses
	enemy.stats[GameEnums.CharacterStats.SAVVY] += 1
	enemy.stats[GameEnums.CharacterStats.TECH] += 1
	
	# Add boss characteristic
	enemy.characteristics.append(GameEnums.EnemyCharacteristic.BOSS)

func get_valid_item_types() -> Array:
	return [
		GameEnums.ItemType.WEAPON,
		GameEnums.ItemType.ARMOR,
		GameEnums.ItemType.MISC,
	]
