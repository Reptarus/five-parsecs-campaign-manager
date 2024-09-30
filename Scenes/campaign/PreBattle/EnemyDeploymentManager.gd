class_name EnemyDeploymentManager
extends Node

enum DeploymentType {
	LINE,
	HALF_FLANK,
	IMPROVED_POSITIONS,
	FORWARD_POSITIONS,
	BOLSTERED_LINE,
	INFILTRATION,
	REINFORCED,
	BOLSTERED_FLANK,
	CONCEALED
}

enum EnemyType {
	AGGRESSIVE,
	CAUTIOUS,
	DEFENSIVE,
	TACTICAL,
	RAMPAGE,
	BEAST
}

const GRID_SIZE: int = 24
const MIN_ENEMIES: int = 1
const MAX_ENEMIES: int = 10

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_deployment(enemy_type: String, battle_map: Dictionary) -> Array:
	assert(enemy_type in EnemyType.keys(), "Invalid enemy type")
	assert("enemy_edge" in battle_map and "width" in battle_map and "height" in battle_map, "Invalid battle map data")

	var deployment: Array = []
	var roll: int = randi_range(1, 100)
	
	var deployment_type: DeploymentType = _get_deployment_type(EnemyType[enemy_type], roll)
	deployment = _generate_deployment_by_type(deployment_type, battle_map)
	
	return deployment

func _get_deployment_type(enemy_type: EnemyType, roll: int) -> DeploymentType:
	match enemy_type:
		EnemyType.AGGRESSIVE:
			if roll <= 20: return DeploymentType.LINE
			elif roll <= 35: return DeploymentType.HALF_FLANK
			elif roll <= 50: return DeploymentType.FORWARD_POSITIONS
			elif roll <= 60: return DeploymentType.BOLSTERED_LINE
			elif roll <= 80: return DeploymentType.INFILTRATION
			elif roll <= 90: return DeploymentType.BOLSTERED_FLANK
			else: return DeploymentType.CONCEALED
		EnemyType.CAUTIOUS:
			if roll <= 30: return DeploymentType.LINE
			elif roll <= 40: return DeploymentType.HALF_FLANK
			elif roll <= 50: return DeploymentType.IMPROVED_POSITIONS
			elif roll <= 70: return DeploymentType.BOLSTERED_LINE
			elif roll <= 90: return DeploymentType.REINFORCED
			else: return DeploymentType.CONCEALED
		EnemyType.DEFENSIVE:
			if roll <= 25: return DeploymentType.LINE
			elif roll <= 40: return DeploymentType.IMPROVED_POSITIONS
			elif roll <= 45: return DeploymentType.FORWARD_POSITIONS
			elif roll <= 60: return DeploymentType.BOLSTERED_LINE
			elif roll <= 70: return DeploymentType.INFILTRATION
			elif roll <= 85: return DeploymentType.REINFORCED
			elif roll <= 90: return DeploymentType.BOLSTERED_FLANK
			else: return DeploymentType.CONCEALED
		EnemyType.TACTICAL:
			if roll <= 20: return DeploymentType.LINE
			elif roll <= 30: return DeploymentType.HALF_FLANK
			elif roll <= 40: return DeploymentType.IMPROVED_POSITIONS
			elif roll <= 50: return DeploymentType.FORWARD_POSITIONS
			elif roll <= 60: return DeploymentType.BOLSTERED_LINE
			elif roll <= 70: return DeploymentType.INFILTRATION
			elif roll <= 80: return DeploymentType.REINFORCED
			elif roll <= 90: return DeploymentType.BOLSTERED_FLANK
			else: return DeploymentType.CONCEALED
		EnemyType.RAMPAGE:
			if roll <= 20: return DeploymentType.LINE
			elif roll <= 25: return DeploymentType.HALF_FLANK
			elif roll <= 45: return DeploymentType.FORWARD_POSITIONS
			elif roll <= 65: return DeploymentType.BOLSTERED_LINE
			elif roll <= 75: return DeploymentType.INFILTRATION
			elif roll <= 80: return DeploymentType.REINFORCED
			elif roll <= 90: return DeploymentType.BOLSTERED_FLANK
			else: return DeploymentType.CONCEALED
		EnemyType.BEAST:
			if roll <= 15: return DeploymentType.HALF_FLANK
			elif roll <= 20: return DeploymentType.IMPROVED_POSITIONS
			elif roll <= 35: return DeploymentType.FORWARD_POSITIONS
			elif roll <= 45: return DeploymentType.BOLSTERED_LINE
			elif roll <= 65: return DeploymentType.INFILTRATION
			elif roll <= 70: return DeploymentType.REINFORCED
			elif roll <= 80: return DeploymentType.BOLSTERED_FLANK
			else: return DeploymentType.CONCEALED
	
	return DeploymentType.LINE  # Default deployment type

func _generate_deployment_by_type(deployment_type: DeploymentType, battle_map: Dictionary) -> Array:
	match deployment_type:
		DeploymentType.LINE:
			return _generate_line_deployment(battle_map)
		DeploymentType.HALF_FLANK:
			return _generate_half_flank_deployment(battle_map)
		DeploymentType.IMPROVED_POSITIONS:
			return _generate_improved_positions_deployment(battle_map)
		DeploymentType.FORWARD_POSITIONS:
			return _generate_forward_positions_deployment(battle_map)
		DeploymentType.BOLSTERED_LINE:
			return _generate_bolstered_line_deployment(battle_map)
		DeploymentType.INFILTRATION:
			return _generate_infiltration_deployment(battle_map)
		DeploymentType.REINFORCED:
			return _generate_reinforced_deployment(battle_map)
		DeploymentType.BOLSTERED_FLANK:
			return _generate_bolstered_flank_deployment(battle_map)
		DeploymentType.CONCEALED:
			return _generate_concealed_deployment(battle_map)
	
	return []  # Default empty deployment

func _generate_line_deployment(battle_map: Dictionary) -> Array:
	var deployment: Array = []
	var enemy_edge: int = battle_map.enemy_edge
	var num_enemies: int = battle_map.get("num_enemies", randi_range(MIN_ENEMIES, MAX_ENEMIES))
	var spacing: float = battle_map.width / (num_enemies + 1)
	
	for i in range(num_enemies):
		deployment.append(Vector2(enemy_edge, (i + 1) * spacing))
	
	return deployment

func _find_nearest_cover(position: Vector2, battle_map: Dictionary) -> Vector2:
	var cover_positions: Array = battle_map.get("cover_positions", [])
	var nearest_cover: Vector2 = position
	var min_distance: float = INF
	
	for cover in cover_positions:
		var distance: float = position.distance_to(cover)
		if distance < min_distance:
			min_distance = distance
			nearest_cover = cover
	
	return nearest_cover

func _generate_half_flank_deployment(battle_map: Dictionary) -> Array:
	var deployment: Array = []
	var num_enemies: int = battle_map.get("num_enemies", randi_range(MIN_ENEMIES, MAX_ENEMIES))
	var flank_edge: int = randi_range(0, 1) * battle_map.width  # Randomly choose left or right edge
	var spacing: float = battle_map.height / (num_enemies + 1)
	
	for i in range(num_enemies):
		deployment.append(Vector2(flank_edge, (i + 1) * spacing))
	
	return deployment

func _generate_improved_positions_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var improved_deployment: Array = []
	
	for position in base_deployment:
		improved_deployment.append(_find_nearest_cover(position, battle_map))
	
	return improved_deployment

func _generate_forward_positions_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var forward_deployment: Array = []
	
	for position in base_deployment:
		var forward_position: Vector2 = position
		forward_position.x += GRID_SIZE * 2  # Move 2 grid spaces forward
		forward_deployment.append(_find_nearest_cover(forward_position, battle_map))
	
	return forward_deployment

func _generate_bolstered_line_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var num_additional: int = 1 if game_state.player_crew.size() > base_deployment.size() else 2
	
	for _i in range(num_additional):
		var new_position: Vector2 = Vector2(battle_map.enemy_edge, randf_range(0, battle_map.height))
		base_deployment.append(new_position)
	
	return base_deployment

func _generate_infiltration_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var infiltration_deployment: Array = []
	
	for i in range(base_deployment.size() / 2):
		infiltration_deployment.append(base_deployment[i])
	
	return infiltration_deployment

func _generate_reinforced_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var reinforced_deployment: Array = []
	
	for i in range(base_deployment.size() / 2):
		reinforced_deployment.append(base_deployment[i])
	
	# Add two additional basic enemies
	for _i in range(2):
		var new_position: Vector2 = Vector2(battle_map.enemy_edge, randf_range(0, battle_map.height))
		reinforced_deployment.append(new_position)
	
	return reinforced_deployment

func _generate_bolstered_flank_deployment(battle_map: Dictionary) -> Array:
	var flank_deployment: Array = _generate_half_flank_deployment(battle_map)
	
	# Add one additional specialist enemy
	var new_position: Vector2 = Vector2(flank_deployment[0].x, randf_range(0, battle_map.height))
	flank_deployment.append(new_position)
	
	return flank_deployment

func _generate_concealed_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var concealed_deployment: Array = []
	var cover_positions: Array = battle_map.get("cover_positions", [])
	
	for position in base_deployment:
		if cover_positions.size() > 0:
			var random_cover: Vector2 = cover_positions[randi() % cover_positions.size()]
			concealed_deployment.append(random_cover)
		else:
			concealed_deployment.append(position)
	
	return concealed_deployment
