class_name EnemyDeploymentManager
extends Node

const GRID_SIZE: int = 24
const MIN_ENEMIES: int = 1
const MAX_ENEMIES: int = 10

var game_state: GameStateManager

func _init(_game_state: GameStateManager) -> void:
	game_state = _game_state

func generate_deployment(enemy_type: GlobalEnums.AIType, battle_map: Dictionary) -> Array:
	assert(enemy_type in GlobalEnums.AIType.values(), "Invalid enemy type")
	assert("enemy_edge" in battle_map and "width" in battle_map and "height" in battle_map, "Invalid battle map data")

	var deployment: Array = []
	var roll: int = randi_range(1, 100)
	
	var deployment_type: GlobalEnums.DeploymentType = _get_deployment_type(enemy_type, roll)
	deployment = _generate_deployment_by_type(deployment_type, battle_map)
	
	return deployment

func _get_deployment_type(enemy_type: GlobalEnums.AIType, roll: int) -> GlobalEnums.DeploymentType:
	match enemy_type:
		GlobalEnums.AIType.AGGRESSIVE:
			if roll <= 20: return GlobalEnums.DeploymentType.LINE
			elif roll <= 35: return GlobalEnums.DeploymentType.HALF_FLANK
			elif roll <= 50: return GlobalEnums.DeploymentType.FORWARD_POSITIONS
			elif roll <= 60: return GlobalEnums.DeploymentType.BOLSTERED_LINE
			elif roll <= 80: return GlobalEnums.DeploymentType.INFILTRATION
			elif roll <= 90: return GlobalEnums.DeploymentType.BOLSTERED_FLANK
			else: return GlobalEnums.DeploymentType.CONCEALED
		GlobalEnums.AIType.CAUTIOUS:
			if roll <= 30: return GlobalEnums.DeploymentType.LINE
			elif roll <= 40: return GlobalEnums.DeploymentType.HALF_FLANK
			elif roll <= 50: return GlobalEnums.DeploymentType.IMPROVED_POSITIONS
			elif roll <= 70: return GlobalEnums.DeploymentType.BOLSTERED_LINE
			elif roll <= 90: return GlobalEnums.DeploymentType.REINFORCED
			else: return GlobalEnums.DeploymentType.CONCEALED
		_:
			return GlobalEnums.DeploymentType.LINE

func _generate_deployment_by_type(deployment_type: GlobalEnums.DeploymentType, battle_map: Dictionary) -> Array:
	match deployment_type:
		GlobalEnums.DeploymentType.LINE:
			return _generate_line_deployment(battle_map)
		GlobalEnums.DeploymentType.HALF_FLANK:
			return _generate_half_flank_deployment(battle_map)
		GlobalEnums.DeploymentType.IMPROVED_POSITIONS:
			return _generate_improved_positions_deployment(battle_map)
		GlobalEnums.DeploymentType.FORWARD_POSITIONS:
			return _generate_forward_positions_deployment(battle_map)
		GlobalEnums.DeploymentType.BOLSTERED_LINE:
			return _generate_bolstered_line_deployment(battle_map)
		GlobalEnums.DeploymentType.INFILTRATION:
			return _generate_infiltration_deployment(battle_map)
		GlobalEnums.DeploymentType.REINFORCED:
			return _generate_reinforced_deployment(battle_map)
		GlobalEnums.DeploymentType.BOLSTERED_FLANK:
			return _generate_bolstered_flank_deployment(battle_map)
		GlobalEnums.DeploymentType.CONCEALED:
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
	
	for i in range(int(base_deployment.size() / 2.0)):
		infiltration_deployment.append(base_deployment[i])
	
	return infiltration_deployment

func _generate_reinforced_deployment(battle_map: Dictionary) -> Array:
	var base_deployment: Array = _generate_line_deployment(battle_map)
	var reinforced_deployment: Array = []
	
	for i in range(ceili((base_deployment.size() + 1) / 2.0)):
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

func deploy_enemies(enemies: Array, battle_map: Dictionary) -> void:
	var deployment_positions = generate_deployment(game_state.current_mission.enemy_type, battle_map)
	for i in range(min(enemies.size(), deployment_positions.size())):
		var enemy = enemies[i]
		var spawn_point = deployment_positions[i]
		enemy.position = spawn_point
		# Add the enemy to the battle scene
		game_state.current_battle_scene.add_child(enemy)