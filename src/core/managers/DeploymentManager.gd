class_name DeploymentManager
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const TerrainTypes = preload("res://src/core/battle/TerrainTypes.gd")

signal deployment_zones_generated(zones: Array)
signal terrain_generated(terrain: Array)

var current_deployment_type: GameEnums.DeploymentType = GameEnums.DeploymentType.STANDARD
var terrain_layout: Array = []
var grid_size: Vector2i = Vector2i(24, 24)

static func get_zone_size(deployment_type: GameEnums.DeploymentType) -> Vector2:
	match deployment_type:
		GameEnums.DeploymentType.STANDARD:
			return Vector2(6, 4)
		GameEnums.DeploymentType.LINE:
			return Vector2(8, 2)
		GameEnums.DeploymentType.AMBUSH:
			return Vector2(4, 6)
		GameEnums.DeploymentType.SCATTERED:
			return Vector2(3, 3)
		GameEnums.DeploymentType.DEFENSIVE:
			return Vector2(5, 5)
		GameEnums.DeploymentType.CONCEALED:
			return Vector2(4, 4)
		_:
			return Vector2(6, 4)

func generate_deployment_zones(deployment_type: GameEnums.DeploymentType) -> Array:
	current_deployment_type = deployment_type
	var deployment_zones = []
	var zone_size = get_zone_size(deployment_type)
	
	match deployment_type:
		GameEnums.DeploymentType.STANDARD:
			deployment_zones = _generate_standard_zones(zone_size)
		GameEnums.DeploymentType.LINE:
			deployment_zones = _generate_line_zones(zone_size)
		GameEnums.DeploymentType.AMBUSH:
			deployment_zones = _generate_flank_zones(zone_size)
		GameEnums.DeploymentType.SCATTERED:
			deployment_zones = _generate_scattered_zones(zone_size)
		GameEnums.DeploymentType.DEFENSIVE:
			deployment_zones = _generate_defensive_zones(zone_size)
		GameEnums.DeploymentType.CONCEALED:
			deployment_zones = _generate_concealed_zones(zone_size)
	
	deployment_zones_generated.emit(deployment_zones)
	return deployment_zones

func generate_terrain_layout(terrain_features: Array) -> void:
	terrain_layout.clear()
	
	match current_deployment_type:
		GameEnums.DeploymentType.STANDARD:
			_generate_standard_terrain(terrain_features)
		GameEnums.DeploymentType.LINE:
			_generate_line_terrain(terrain_features)
		GameEnums.DeploymentType.SCATTERED:
			_generate_scattered_terrain(terrain_features)
		_:
			_generate_standard_terrain(terrain_features)
	
	terrain_generated.emit(terrain_layout)

# Private helper methods for zone generation
func _generate_standard_zones(size: Vector2) -> Array:
	return [
		{
			"type": "player",
			"rect": Rect2(Vector2.ZERO, size)
		},
		{
			"type": "enemy",
			"rect": Rect2(Vector2(grid_size.x - size.x, grid_size.y - size.y), size)
		}
	]

func _generate_line_zones(size: Vector2) -> Array:
	return [
		{
			"type": "player",
			"rect": Rect2(Vector2(0, 10), size)
		},
		{
			"type": "enemy",
			"rect": Rect2(Vector2(grid_size.x - size.x, 10), size)
		}
	]

func _generate_flank_zones(size: Vector2) -> Array:
	return [
		{
			"type": "player",
			"rect": Rect2(Vector2(0, 0), size)
		},
		{
			"type": "enemy",
			"rect": Rect2(Vector2(grid_size.x - size.x, grid_size.y - size.y), size)
		}
	]

func _generate_scattered_zones(size: Vector2) -> Array:
	var zones = []
	var crew_positions = [
		Vector2(0, 0),
		Vector2(0, grid_size.y - size.y),
		Vector2(grid_size.x/2 - size.x/2, grid_size.y/2 - size.y/2)
	]
	var enemy_positions = [
		Vector2(grid_size.x - size.x, 0),
		Vector2(grid_size.x - size.x, grid_size.y - size.y),
		Vector2(grid_size.x/2 - size.x/2, grid_size.y/2 - size.y/2)
	]
	
	zones.append({
		"type": "player",
		"rect": Rect2(crew_positions[randi() % crew_positions.size()], size)
	})
	zones.append({
		"type": "enemy",
		"rect": Rect2(enemy_positions[randi() % enemy_positions.size()], size)
	})
	return zones

func _generate_defensive_zones(size: Vector2) -> Array:
	return [
		{
			"type": "player",
			"rect": Rect2(Vector2(grid_size.x/3, grid_size.y/3), size * 1.5)
		},
		{
			"type": "enemy",
			"rect": Rect2(Vector2.ZERO, Vector2(grid_size))
		}
	]

func _generate_concealed_zones(size: Vector2) -> Array:
	var zones = []
	var possible_positions = []
	
	# Generate possible positions near cover/terrain
	for x in range(0, grid_size.x - int(size.x), 4):
		for y in range(0, grid_size.y - int(size.y), 4):
			if _has_nearby_cover(Vector2(x, y)):
				possible_positions.append(Vector2(x, y))
	
	# Select random positions for crew and enemy
	if possible_positions.size() >= 2:
		var crew_index = randi() % possible_positions.size()
		var crew_pos = possible_positions[crew_index]
		possible_positions.remove_at(crew_index)
		
		var enemy_index = randi() % possible_positions.size()
		var enemy_pos = possible_positions[enemy_index]
		
		zones.append({
			"type": "player",
			"rect": Rect2(crew_pos, size)
		})
		zones.append({
			"type": "enemy",
			"rect": Rect2(enemy_pos, size)
		})
	else:
		# Fallback to standard deployment if not enough valid positions
		zones = _generate_standard_zones(size)
	
	return zones

func _has_nearby_cover(position: Vector2) -> bool:
	for terrain in terrain_layout:
		if terrain.type == GameEnums.TerrainFeatureType.COVER_HIGH or terrain.type == GameEnums.TerrainFeatureType.COVER_LOW:
			var distance = position.distance_to(terrain.position)
			if distance < 3:
				return true
	return false

func _get_random_valid_position() -> Vector2:
	var valid_positions = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2(x, y)
			var is_valid = true
			for terrain in terrain_layout:
				if terrain.position == pos:
					is_valid = false
					break
			if is_valid:
				valid_positions.append(pos)
	
	if valid_positions.size() > 0:
		return valid_positions[randi() % valid_positions.size()]
	return Vector2.ZERO

func _get_feature_size(feature_type: GameEnums.BattlefieldFeature) -> Vector2:
	match feature_type:
		GameEnums.BattlefieldFeature.COVER:
			return Vector2(1, 1)
		GameEnums.BattlefieldFeature.BARRICADE:
			return Vector2(2, 1)
		GameEnums.BattlefieldFeature.RUINS:
			return Vector2(2, 2)
		GameEnums.BattlefieldFeature.HAZARD:
			return Vector2(2, 1)
		GameEnums.BattlefieldFeature.HIGH_GROUND:
			return Vector2(2, 2)
		GameEnums.BattlefieldFeature.OBSTACLE:
			return Vector2(3, 2)
		_:
			return Vector2(1, 1)

func _generate_standard_terrain(features: Array) -> void:
	for feature in features:
		var position = _get_random_valid_position()
		terrain_layout.append({
			"type": feature,
			"position": position,
			"size": _get_feature_size(feature)
		})

func _generate_line_terrain(features: Array) -> void:
	var center_line = grid_size.x / 2
	
	for feature in features:
		var position = Vector2(
			center_line + randf_range(-2, 2),
			randf_range(4, grid_size.y - 4)
		)
		terrain_layout.append({
			"type": feature,
			"position": position,
			"size": _get_feature_size(feature)
		})

func _generate_scattered_terrain(features: Array) -> void:
	var quadrants = [
		Rect2(Vector2.ZERO, Vector2(grid_size.x/2, grid_size.y/2)),
		Rect2(Vector2(grid_size.x/2, 0), Vector2(grid_size.x/2, grid_size.y/2)),
		Rect2(Vector2(0, grid_size.y/2), Vector2(grid_size.x/2, grid_size.y/2)),
		Rect2(Vector2(grid_size.x/2, grid_size.y/2), Vector2(grid_size.x/2, grid_size.y/2))
	]
	
	for feature in features:
		var quadrant = quadrants[randi() % quadrants.size()]
		var position = Vector2(
			quadrant.position.x + randf() * quadrant.size.x,
			quadrant.position.y + randf() * quadrant.size.y
		)
		terrain_layout.append({
			"type": feature,
			"position": position,
			"size": _get_feature_size(feature)
		})
  