extends Node
class_name BattleSetupWizard

## Battle Setup Wizard - One-click battle generation
## Integrates with existing EnemyGenerator and GameState

signal battle_generated(battle_data: Dictionary)

var _enemy_generator: EnemyGenerator

func _ready() -> void:
	_enemy_generator = EnemyGenerator.new()

## Generate complete battle setup
func generate_battle_from_mission(mission: Variant) -> Dictionary:
	var crew_size := _get_crew_size()
	var battle_data := {
		"enemy_type": roll_enemy_type(),
		"enemy_count": calculate_enemy_count(crew_size),
		"deployment": determine_deployment(),
		"terrain": suggest_terrain(),
		"objectives": []
	}

	battle_generated.emit(battle_data)
	return battle_data

func roll_enemy_type() -> String:
	# Use EnemyGenerator's loaded categories (from JSON or fallback)
	if _enemy_generator and not _enemy_generator.enemy_categories.is_empty():
		var categories: Array = _enemy_generator.enemy_categories.keys()
		var category: String = categories[randi() % categories.size()]
		var types: Array = _enemy_generator.enemy_categories[category]
		if not types.is_empty():
			return types[randi() % types.size()]

	# Fallback if EnemyGenerator not available
	var fallback := ["Criminal Elements", "Hired Guns", "K'Erin Warriors", "Converted", "Raiders"]
	return fallback[randi() % fallback.size()]

func calculate_enemy_count(crew_size: int) -> int:
	## Calculate enemy count using Core Rules dice formula (p.63).
	## Delegates to EnemyGenerator for consistency.
	if _enemy_generator:
		# Normal difficulty (2), not a quest mission
		return _enemy_generator.calculate_enemy_count(2, crew_size)
	# Fallback: simple 1D6 approximation
	return randi_range(1, 6)

func determine_deployment() -> Dictionary:
	# Five Parsecs deployment uses table edges with 24" standard separation
	var crew_zones := ["North Edge", "South Edge", "East Edge", "West Edge"]
	var crew_zone: String = crew_zones[randi() % crew_zones.size()]

	# Enemy deploys on opposite edge by default
	var enemy_zone_map := {"North Edge": "South Edge", "South Edge": "North Edge", "East Edge": "West Edge", "West Edge": "East Edge"}
	var enemy_zone: String = enemy_zone_map.get(crew_zone, "North Edge")

	return {
		"crew_zone": crew_zone,
		"enemy_zone": enemy_zone,
		"distance": 24 # standard inches separation
	}

func suggest_terrain() -> Array:
	# Five Parsecs recommends 6-8 terrain features for a 2'x2' / 3'x3' table
	var terrain_types := [
		{"type": "building", "cover": "hard"},
		{"type": "ruins", "cover": "hard"},
		{"type": "crates", "cover": "soft"},
		{"type": "vegetation", "cover": "soft"},
		{"type": "wall_section", "cover": "hard"},
		{"type": "vehicle_wreck", "cover": "hard"},
		{"type": "rocky_outcrop", "cover": "hard"},
		{"type": "barricade", "cover": "soft"},
	]

	var terrain_pieces: Array = []
	var piece_count := randi_range(6, 8)

	for i in piece_count:
		var template: Dictionary = terrain_types[randi() % terrain_types.size()]
		terrain_pieces.append({
			"type": template.type,
			"cover": template.cover,
			"position": Vector2(randf_range(6, 42), randf_range(6, 42)) # Keep away from edges
		})

	return terrain_pieces

func quick_start_battle(mission: Variant) -> void:
	var battle_data := generate_battle_from_mission(mission)
	# Signal consumers (BattlePhase / BattleSetupPhasePanel) to start with this data
	battle_generated.emit(battle_data)

func _get_crew_size() -> int:
	var tree = Engine.get_main_loop()
	var root = tree.root if tree else null
	if root:
		# Prefer campaign crew size setting (Core Rules p.63)
		var gsm = root.get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("get_campaign_crew_size"):
			var size: int = gsm.get_campaign_crew_size()
			if size >= 4:
				return size
	return 6  # Default campaign crew size
