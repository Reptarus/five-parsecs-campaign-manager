extends Resource

# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

signal enemy_deployment_generated(positions: Array)
signal deployment_validated(success: bool)

func get_deployment_type(ai_behavior: int) -> GlobalEnums.DeploymentType:
	var roll := randi() % 100 + 1

	match ai_behavior:
		0: # AGGRESSIVE
			if roll <= 30: return GlobalEnums.DeploymentType.STANDARD
			elif roll <= 50: return GlobalEnums.DeploymentType.AMBUSH
			elif roll <= 60: return GlobalEnums.DeploymentType.CONCENTRATED
			elif roll <= 80: return GlobalEnums.DeploymentType.OFFENSIVE
			elif roll <= 90: return GlobalEnums.DeploymentType.SPECIALIZED
			else: return GlobalEnums.DeploymentType.SCATTERED
		1: # CAUTIOUS
			if roll <= 30: return GlobalEnums.DeploymentType.STANDARD
			elif roll <= 50: return GlobalEnums.DeploymentType.DEFENSIVE
			elif roll <= 70: return GlobalEnums.DeploymentType.CONCENTRATED
			elif roll <= 90: return GlobalEnums.DeploymentType.SPECIALIZED
			else: return GlobalEnums.DeploymentType.SCATTERED
		_:
			return GlobalEnums.DeploymentType.STANDARD

func generate_deployment_positions(battle_map: Node, deployment_type: GlobalEnums.DeploymentType) -> Array:
	match deployment_type:
		GlobalEnums.DeploymentType.STANDARD:
			return _generate_standard_deployment(battle_map)
		GlobalEnums.DeploymentType.SCATTERED:
			return _generate_line_deployment(battle_map)
		GlobalEnums.DeploymentType.AMBUSH:
			return _generate_flank_deployment(battle_map)
		GlobalEnums.DeploymentType.SCATTERED:
			return _generate_scattered_deployment(battle_map)
		GlobalEnums.DeploymentType.DEFENSIVE:
			return _generate_defensive_deployment(battle_map)
		GlobalEnums.DeploymentType.SPECIALIZED:
			return _generate_infiltration_deployment(battle_map)
		GlobalEnums.DeploymentType.CONCENTRATED:
			return _generate_reinforced_deployment(battle_map)
		GlobalEnums.DeploymentType.CONCENTRATED:
			return _generate_bolstered_line_deployment(battle_map)
		GlobalEnums.DeploymentType.RANDOM:
			return _generate_concealed_deployment(battle_map)
		_:
			push_error("Invalid deployment _type: %d" % deployment_type)
			return []

# Implementation of deployment generation functions...
func _generate_standard_deployment(battle_map: Node) -> Array:
	"""Standard deployment with enemies positioned in a line facing the player"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	var enemy_zone_start = Vector2(map_size.x * 0.7, map_size.y * 0.2)
	var enemy_zone_end = Vector2(map_size.x * 0.9, map_size.y * 0.8)
	
	# Deploy enemies in a standard line formation
	var num_positions = 6  # Standard deployment positions
	for i in range(num_positions):
		var y_offset = (enemy_zone_end.y - enemy_zone_start.y) * (i / float(num_positions - 1))
		var position = Vector2(enemy_zone_start.x, enemy_zone_start.y + y_offset)
		positions.append(position)
	
	return positions

func _generate_line_deployment(battle_map: Node) -> Array:
	"""Line deployment with enemies spread across the battlefield width"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	var deployment_line_y = map_size.y * 0.8  # Back line of the battlefield
	
	var num_positions = 5
	for i in range(num_positions):
		var x_offset = (map_size.x * 0.8) * (i / float(num_positions - 1)) + (map_size.x * 0.1)
		var position = Vector2(x_offset, deployment_line_y)
		positions.append(position)
	
	return positions

func _generate_flank_deployment(battle_map: Node) -> Array:
	"""Flank deployment with enemies positioned on the sides for ambush"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Left flank positions
	for i in range(3):
		var y_pos = map_size.y * (0.3 + i * 0.2)
		positions.append(Vector2(map_size.x * 0.1, y_pos))
	
	# Right flank positions
	for i in range(3):
		var y_pos = map_size.y * (0.3 + i * 0.2)
		positions.append(Vector2(map_size.x * 0.9, y_pos))
	
	return positions

func _generate_scattered_deployment(battle_map: Node) -> Array:
	"""Scattered deployment with enemies randomly distributed"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Generate random positions avoiding player start zone
	var num_positions = 8
	for i in range(num_positions):
		var attempts = 0
		var position: Vector2
		
		# Try to find a valid position (not too close to player start)
		while attempts < 10:
			position = Vector2(
				randf_range(map_size.x * 0.3, map_size.x * 0.9),
				randf_range(map_size.y * 0.1, map_size.y * 0.9)
			)
			
			# Check if position is far enough from player start (assumed at 0.1, 0.5)
			var player_start = Vector2(map_size.x * 0.1, map_size.y * 0.5)
			if position.distance_to(player_start) > map_size.x * 0.3:
				break
			attempts += 1
		
		positions.append(position)
	
	return positions

func _generate_defensive_deployment(battle_map: Node) -> Array:
	"""Defensive deployment with enemies in cover positions"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Create defensive positions around cover points
	var cover_positions = _find_cover_positions(battle_map)
	
	if cover_positions.is_empty():
		# Fallback to defensive line if no cover found
		var defensive_line_x = map_size.x * 0.8
		for i in range(4):
			var y_pos = map_size.y * (0.2 + i * 0.2)
			positions.append(Vector2(defensive_line_x, y_pos))
	else:
		# Use cover positions, limit to reasonable number
		var max_positions = min(6, cover_positions.size())
		for i in range(max_positions):
			positions.append(cover_positions[i])
	
	return positions

func _generate_infiltration_deployment(battle_map: Node) -> Array:
	"""Infiltration deployment with enemies positioned for stealth approach"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Infiltrators start closer to player positions but concealed
	var concealment_positions = _find_concealment_positions(battle_map)
	
	if concealment_positions.is_empty():
		# Fallback to edge positions for infiltration
		positions.append(Vector2(map_size.x * 0.1, map_size.y * 0.1))  # Top left
		positions.append(Vector2(map_size.x * 0.1, map_size.y * 0.9))  # Bottom left
		positions.append(Vector2(map_size.x * 0.5, map_size.y * 0.05)) # Top center
		positions.append(Vector2(map_size.x * 0.5, map_size.y * 0.95)) # Bottom center
	else:
		# Use concealment positions
		var max_positions = min(4, concealment_positions.size())
		for i in range(max_positions):
			positions.append(concealment_positions[i])
	
	return positions

func _generate_reinforced_deployment(battle_map: Node) -> Array:
	"""Reinforced deployment with concentrated enemy force"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Create a tight formation in one area
	var formation_center = Vector2(map_size.x * 0.8, map_size.y * 0.5)
	var formation_radius = min(map_size.x, map_size.y) * 0.15
	
	# Generate positions in a concentrated formation
	var num_positions = 7
	for i in range(num_positions):
		var angle = (i / float(num_positions)) * 2.0 * PI
		var offset = Vector2(cos(angle), sin(angle)) * formation_radius
		positions.append(formation_center + offset)
	
	return positions

func _generate_bolstered_line_deployment(battle_map: Node) -> Array:
	"""Bolstered line deployment with reinforced center"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Main line formation
	var line_y = map_size.y * 0.75
	for i in range(5):
		var x_pos = map_size.x * (0.2 + i * 0.15)
		positions.append(Vector2(x_pos, line_y))
	
	# Reinforced center positions
	var center_x = map_size.x * 0.5
	positions.append(Vector2(center_x, line_y - map_size.y * 0.1))  # Forward center
	positions.append(Vector2(center_x, line_y + map_size.y * 0.1))  # Rear center
	
	return positions

func _generate_concealed_deployment(battle_map: Node) -> Array:
	"""Concealed deployment with enemies hidden until revealed"""
	var positions = []
	var map_size = _get_battle_map_size(battle_map)
	
	# Find hiding spots throughout the battlefield
	var concealment_positions = _find_concealment_positions(battle_map)
	
	if concealment_positions.is_empty():
		# Fallback to edge positions
		positions.append(Vector2(map_size.x * 0.05, map_size.y * 0.3))
		positions.append(Vector2(map_size.x * 0.05, map_size.y * 0.7))
		positions.append(Vector2(map_size.x * 0.95, map_size.y * 0.3))
		positions.append(Vector2(map_size.x * 0.95, map_size.y * 0.7))
		positions.append(Vector2(map_size.x * 0.5, map_size.y * 0.05))
	else:
		# Use available concealment positions
		var max_positions = min(6, concealment_positions.size())
		for i in range(max_positions):
			positions.append(concealment_positions[i])
	
	return positions

func _get_battle_map_size(battle_map: Node) -> Vector2:
	"""Get the size of the battle map for positioning calculations"""
	if battle_map and battle_map.has_method("get_map_size"):
		return battle_map.get_map_size()
	elif battle_map and "map_size" in battle_map:
		return battle_map.map_size
	else:
		# Default battlefield size (in grid units or pixels)
		return Vector2(1000, 800)

func _find_cover_positions(battle_map: Node) -> Array:
	"""Find available cover positions on the battlefield"""
	var cover_positions = []
	
	if battle_map and battle_map.has_method("get_cover_positions"):
		cover_positions = battle_map.get_cover_positions()
	elif battle_map and battle_map.has_method("find_terrain_features"):
		var features = battle_map.find_terrain_features("cover")
		for feature in features:
			if feature.has("position"):
				cover_positions.append(feature.position)
	else:
		# Generate some default cover positions
		var map_size = _get_battle_map_size(battle_map)
		cover_positions.append(Vector2(map_size.x * 0.6, map_size.y * 0.3))
		cover_positions.append(Vector2(map_size.x * 0.7, map_size.y * 0.6))
		cover_positions.append(Vector2(map_size.x * 0.8, map_size.y * 0.4))
	
	return cover_positions

func _find_concealment_positions(battle_map: Node) -> Array:
	"""Find positions suitable for concealment and infiltration"""
	var concealment_positions = []
	
	if battle_map and battle_map.has_method("get_concealment_positions"):
		concealment_positions = battle_map.get_concealment_positions()
	elif battle_map and battle_map.has_method("find_terrain_features"):
		var features = battle_map.find_terrain_features("concealment")
		for feature in features:
			if feature.has("position"):
				concealment_positions.append(feature.position)
	else:
		# Generate some default concealment positions
		var map_size = _get_battle_map_size(battle_map)
		concealment_positions.append(Vector2(map_size.x * 0.3, map_size.y * 0.2))
		concealment_positions.append(Vector2(map_size.x * 0.4, map_size.y * 0.8))
		concealment_positions.append(Vector2(map_size.x * 0.6, map_size.y * 0.1))
		concealment_positions.append(Vector2(map_size.x * 0.7, map_size.y * 0.9))
	
	return concealment_positions
