# WeaponSystem.gd
class_name WeaponSystem
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

func get_weapon_for_enemy(enemy_type: GlobalEnums.EnemyCategory, weapon_group: int) -> Weapon:
	var weapon_pool := _get_weapon_pool(weapon_group)
	return weapon_pool[randi() % weapon_pool.size()]

func _get_weapon_pool(group: int) -> Array[Weapon]:
	var pool: Array[Weapon] = []
	match group:
		0: # Basic weapons
			pool.append(create_weapon("Hand Gun", GlobalEnums.WeaponType.HAND_GUN, 12, 1, 1))
			pool.append(create_weapon("Combat Blade", GlobalEnums.WeaponType.BLADE, 1, 1, 2))
		1: # Advanced weapons
			pool.append(create_weapon("Plasma Rifle", GlobalEnums.WeaponType.PLASMA_RIFLE, 24, 2, 3))
			pool.append(create_weapon("Energy Blade", GlobalEnums.WeaponType.ENERGY_BLADE, 1, 1, 4))
		2: # Elite weapons
			pool.append(create_weapon("Heavy Cannon", GlobalEnums.WeaponType.HEAVY, 18, 3, 5))
			pool.append(create_weapon("Power Claw", GlobalEnums.WeaponType.POWER_CLAW, 1, 2, 6))
	return pool

func create_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> Weapon:
	return Weapon.new(name, type, range, shots, damage)