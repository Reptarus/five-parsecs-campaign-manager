extends Node
class_name BattleSetupWizard

## Battle Setup Wizard - One-click battle generation
## Integrates with existing BattlefieldGenerator and EnemyGenerator

signal battle_generated(battle_data: Dictionary)

## Generate complete battle setup
func generate_battle_from_mission(mission: Variant) -> Dictionary:
	"""Auto-generate battle parameters from mission"""
	var battle_data = {
		"enemy_type": roll_enemy_type(),
		"enemy_count": calculate_enemy_count(6),  # TODO: Get actual crew size
		"deployment": determine_deployment(),
		"terrain": suggest_terrain(),
		"objectives": []
	}
	
	battle_generated.emit(battle_data)
	return battle_data

func roll_enemy_type() -> String:
	"""Roll for enemy type from tables"""
	# TODO: Integrate with actual enemy tables
	var enemy_types = ["Vent Crawlers", "Raiders", "Converted", "Precursor Artifacts"]
	return enemy_types[randi() % enemy_types.size()]

func calculate_enemy_count(crew_size: int) -> int:
	"""Calculate enemy count based on crew size"""
	# Standard: crew size × 2
	return crew_size * 2

func determine_deployment() -> Dictionary:
	"""Determine deployment zones"""
	var zones = ["North Edge", "South Edge", "East Edge", "West Edge", "Scattered"]
	return {
		"crew_zone": zones[randi() % zones.size()],
		"enemy_zone": zones[randi() % zones.size()],
		"distance": 18  # inches
	}

func suggest_terrain() -> Array:
	"""Suggest terrain placement"""
	# TODO: Integrate with TerrainFactory
	var terrain_pieces = []
	var piece_count = randi_range(6, 8)
	
	for i in piece_count:
		terrain_pieces.append({
			"type": "cover",
			"position": Vector2(randf_range(0, 48), randf_range(0, 48))
		})
	
	return terrain_pieces

func quick_start_battle(mission: Variant) -> void:
	"""Generate and immediately start battle"""
	var battle_data = generate_battle_from_mission(mission)
	# TODO: Hook into BattlefieldManager to actually start battle
	print("Quick-starting battle: ", battle_data)
