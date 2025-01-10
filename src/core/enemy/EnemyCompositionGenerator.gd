@tool
class_name EnemyCompositionGenerator
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

func generate_enemy_force(mission: Mission) -> Dictionary:
	var base_size := _calculate_base_force_size(mission)
	var adjusted_size := _adjust_force_size_for_difficulty(base_size, mission.difficulty)
	
	var base_types := _get_enemy_types(mission.mission_type)
	var available_types := _get_enemy_types_for_difficulty(base_types, mission.difficulty)
	
	var composition := []
	for i in range(adjusted_size):
		var unit = _create_enemy_unit(available_types.pick_random())
		composition.append(unit)
	
	var special_units := _generate_special_units(mission)
	
	return {
		"count": adjusted_size + special_units.size(),
		"composition": composition,
		"special_units": special_units
	}

func _calculate_base_force_size(mission: Mission) -> int:
	var base_size := 3
	
	# Adjust for mission type
	match mission.mission_type:
		GameEnums.MissionType.RAID, GameEnums.MissionType.DEFENSE:
			base_size += 2
		GameEnums.MissionType.BLACK_ZONE:
			base_size += 3
	
	return base_size

func _adjust_force_size_for_difficulty(base_size: int, difficulty: int) -> int:
	match difficulty:
		GameEnums.DifficultyLevel.EASY:
			return base_size - 1
		GameEnums.DifficultyLevel.NORMAL:
			return base_size
		GameEnums.DifficultyLevel.HARD:
			return base_size + 1
		GameEnums.DifficultyLevel.VETERAN:
			return base_size + 2
		GameEnums.DifficultyLevel.ELITE:
			return base_size + 3
	return base_size

func _get_enemy_types(mission_type: int) -> Array[String]:
	var types: Array[String] = ["Grunt", "Minion"]
	
	# Add types based on mission type
	match mission_type:
		GameEnums.MissionType.GREEN_ZONE:
			types.append_array(["Gangers", "Punks", "Raiders"])
		GameEnums.MissionType.RED_ZONE:
			types.append_array(["Elite Guards", "Corporate Security", "Hired Guns"])
		GameEnums.MissionType.BLACK_ZONE:
			types.append_array(["Elite Commandos", "War Bots", "Alien Warriors"])
		GameEnums.MissionType.PATRON:
			types.append_array(["Professional Guards", "Security Bots", "Elite Guards"])
	
	return types

func _get_enemy_types_for_difficulty(base_types: Array[String], difficulty: int) -> Array[String]:
	var types = base_types.duplicate()
	
	# Add types based on difficulty
	match difficulty:
		GameEnums.DifficultyLevel.HARD, GameEnums.DifficultyLevel.VETERAN:
			types.append_array(["Tech Gangers", "Gene Renegades", "Pirates"])
		GameEnums.DifficultyLevel.ELITE:
			types.append_array(["Elite Mercenaries", "Corporate Security", "Black Ops"])
	
	return types

func _determine_elite_units(mission: Mission) -> int:
	var elite_count := 0
	
	# Base on difficulty
	match mission.difficulty:
		GameEnums.DifficultyLevel.HARD, GameEnums.DifficultyLevel.VETERAN:
			elite_count = 1
		GameEnums.DifficultyLevel.ELITE:
			elite_count = 2
	
	# Adjust for mission type
	if mission.mission_type == GameEnums.MissionType.BLACK_ZONE:
		elite_count += 1
	
	return elite_count

func _generate_special_units(mission: Mission) -> Array:
	var special_units := []
	
	# Only add special units for higher difficulties
	if mission.difficulty < GameEnums.DifficultyLevel.HARD:
		return special_units
	
	var special_unit_count := _determine_elite_units(mission)
	for i in range(special_unit_count):
		var unit = _create_enemy_unit("Elite " + _get_enemy_types(mission.mission_type).pick_random())
		special_units.append(unit)
	
	return special_units

func _create_enemy_unit(enemy_type: String) -> Dictionary:
	# Base stats from core rules
	var unit := {
		"type": enemy_type,
		"combat_skill": 0,
		"toughness": 3,
		"movement": 4,
		"weapons": ["Basic Rifle"],
		"special_rules": []
	}
	
	# Adjust stats based on type
	match enemy_type:
		"Tech Gangers", "Gene Renegades", "Pirates":
			unit.combat_skill = 1
			unit.toughness = 4
		"Elite Mercenaries", "Corporate Security", "Black Ops":
			unit.combat_skill = 2
			unit.toughness = 4
			unit.weapons = ["Advanced Rifle"]
		"War Bots", "Security Bots":
			unit.toughness = 5
			unit.special_rules.append("Armored")
		"Alien Warriors":
			unit.combat_skill = 2
			unit.movement = 6
			unit.special_rules.append("Aggressive")
	
	return unit