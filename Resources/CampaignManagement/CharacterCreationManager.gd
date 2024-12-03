extends Resource

enum Class {
	WARRIOR,
	SCOUT,
	TECH,
	LEADER,
	SPECIALIST,
	SUPPORT
}

enum WeaponType {
	HAND_GUN,
	SHELL_GUN,
	HUNTING_RIFLE,
	PLASMA_RIFLE,
	ENERGY_BLADE,
	COMBAT_BLADE
}

enum ArmorType {
	LIGHT,
	MEDIUM,
	HEAVY,
	STEALTH,
	POWERED
}

var current_character: Node  # Will be cast to Character at runtime

func _add_starting_equipment(weapon_type: WeaponType, armor_type: ArmorType) -> void:
	match current_character.character_class:
		Class.WARRIOR:
			_add_starting_equipment(WeaponType.SHELL_GUN, ArmorType.MEDIUM)
		Class.SCOUT:
			_add_starting_equipment(WeaponType.HUNTING_RIFLE, ArmorType.LIGHT)
		Class.TECH:
			_add_starting_equipment(WeaponType.HAND_GUN, ArmorType.LIGHT)
		Class.LEADER:
			_add_starting_equipment(WeaponType.HAND_GUN, ArmorType.LIGHT)
		Class.SPECIALIST:
			_add_starting_equipment(WeaponType.HAND_GUN, ArmorType.STEALTH)
		Class.SUPPORT:
			_add_starting_equipment(WeaponType.PLASMA_RIFLE, ArmorType.LIGHT)
