@tool
extends Node

const ELITE_COMBAT_SKILL_BONUS: int = 2
const ELITE_TOUGHNESS_BONUS: int = 2
const ELITE_REACTIONS_BONUS: int = 1

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

## Upgrades a regular enemy to an elite version
## Parameters:
	## - enemy: The enemy to upgrade
func upgrade_enemy_to_elite(enemy: Enemy) -> void:
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
func upgrade_enemy_to_boss(enemy: Enemy) -> void:
	# First make them elite
	upgrade_enemy_to_elite(enemy)

	# Then add boss bonuses
	enemy.stats[GlobalEnums.CharacterStats.SAVVY] += 1
	enemy.stats[GlobalEnums.CharacterStats.TECH] += 1

	# Add boss characteristic
	enemy.characteristics.append(GlobalEnums.EnemyCharacteristic.BOSS)
func get_valid_item_types() -> Array:
	return [GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.MISC]

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null