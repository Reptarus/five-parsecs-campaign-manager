@tool
extends Node
class_name EliteLevelEnemiesManager

const ELITE_COMBAT_SKILL_BONUS: int = 2
const ELITE_TOUGHNESS_BONUS: int = 2
const ELITE_REACTIONS_BONUS: int = 1
const EnemyNode = preload("res://src/core/enemy/base/EnemyNode.gd")
const EnemyData = preload("res://src/core/enemy/EnemyData.gd")

## Upgrades a regular enemy to an elite version
## Parameters:
## - enemy: The enemy to upgrade
func upgrade_enemy_to_elite(enemy: EnemyNode) -> void:
	# Increase core stats
	enemy.stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += ELITE_COMBAT_SKILL_BONUS
	enemy.stats[GlobalEnums.CharacterStats.TOUGHNESS] += ELITE_TOUGHNESS_BONUS
	enemy.stats[GlobalEnums.CharacterStats.REACTIONS] += ELITE_REACTIONS_BONUS
	
	# Upgrade weapons
	for weapon in enemy.weapons:
		upgrade_weapon_rarity(weapon)
	
	# Add elite characteristic
	if not GlobalEnums.EnemyCharacteristic.ELITE in enemy.characteristics:
		enemy.characteristics.append(GlobalEnums.EnemyCharacteristic.ELITE)

## Upgrades a weapon's rarity to the next tier
## Parameters:
## - weapon: The weapon to upgrade
func upgrade_weapon_rarity(weapon: Resource) -> void:
	if weapon.has_method("get_rarity") and weapon.has_method("set_rarity"):
		match weapon.get_rarity():
			GlobalEnums.ItemRarity.COMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.UNCOMMON)
			GlobalEnums.ItemRarity.UNCOMMON:
				weapon.set_rarity(GlobalEnums.ItemRarity.RARE)
			GlobalEnums.ItemRarity.RARE:
				weapon.set_rarity(GlobalEnums.ItemRarity.EPIC)
			GlobalEnums.ItemRarity.EPIC:
				weapon.set_rarity(GlobalEnums.ItemRarity.LEGENDARY)

func upgrade_enemy_to_boss(enemy: EnemyNode) -> void:
	# First make them elite
	upgrade_enemy_to_elite(enemy)
	
	# Then add boss bonuses
	enemy.stats[GlobalEnums.CharacterStats.SAVVY] += 1
	enemy.stats[GlobalEnums.CharacterStats.TECH] += 1
	
	# Add boss characteristic
	enemy.characteristics.append(GlobalEnums.EnemyCharacteristic.BOSS)

func get_valid_item_types() -> Array:
	return [
		GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.MISC,
	]
