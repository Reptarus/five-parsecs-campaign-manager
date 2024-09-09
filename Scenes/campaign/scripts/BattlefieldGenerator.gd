class_name BattlefieldLayoutGenerator
extends Node

enum TerrainType { INDUSTRIAL, WILDERNESS, ALIEN_RUIN, CRASH_SITE }
enum FeatureSize { LARGE, SMALL, LINEAR }

const GRID_SIZE: Vector2i = Vector2i(24, 24)  # 24" x 24" battlefield
const SECTORS_PER_QUARTER: int = 4

var game_state: GameState
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	rng.randomize()

func generate_battlefield(mission_type: String, terrain_type: TerrainType) -> Dictionary:
	var battlefield = {
		"grid": [],
		"center_feature": {},
		"quarters": [],
		"deployment_condition": generate_deployment_condition(mission_type),
		"notable_sight": generate_notable_sight(mission_type),
		"mission_type": mission_type,
		"terrain_type": terrain_type
	}
	
	_initialize_grid(battlefield.grid)
	_generate_center_feature(battlefield, terrain_type)
	_generate_quarters(battlefield, terrain_type)
	
	return battlefield

func _initialize_grid(grid: Array) -> void:
	for x in range(GRID_SIZE.x):
		grid.append([])
		for y in range(GRID_SIZE.y):
			grid[x].append(".")  # Open space

func _generate_center_feature(battlefield: Dictionary, terrain_type: TerrainType) -> void:
	var feature = _roll_notable_feature(terrain_type)
	battlefield.center_feature = {
		"type": feature,
		"position": Vector2i(GRID_SIZE.x / 2, GRID_SIZE.y / 2)
	}
	_apply_feature_to_grid(battlefield.grid, battlefield.center_feature)

func _generate_quarters(battlefield: Dictionary, terrain_type: TerrainType) -> void:
	for q in range(4):
		var quarter = {
			"features": [],
			"scatter_terrain": []
		}
		
		# Generate 4 regular features per quarter
		for i in range(SECTORS_PER_QUARTER):
			var feature = _roll_regular_feature(terrain_type)
			quarter.features.append(feature)
		
		# Generate scatter terrain
		var scatter_count = rng.randi_range(1, 6)
		for i in range(scatter_count):
			quarter.scatter_terrain.append(_generate_scatter_terrain())
		
		battlefield.quarters.append(quarter)
	
	_apply_quarters_to_grid(battlefield)

func _roll_notable_feature(terrain_type: TerrainType) -> String:
	var table = _get_notable_feature_table(terrain_type)
	return table[rng.randi() % table.size()]

func _roll_regular_feature(terrain_type: TerrainType) -> Dictionary:
	var table = _get_regular_feature_table(terrain_type)
	var feature_type = table[rng.randi() % table.size()]
	return {
		"type": feature_type,
		"size": _determine_feature_size(feature_type)
	}

func _determine_feature_size(feature_type: String) -> FeatureSize:
	# Implement logic to determine feature size based on type
	return FeatureSize.SMALL  # Placeholder

func _generate_scatter_terrain() -> String:
	var scatter_types = ["Fuel Barrel", "Crate", "Rock", "Rubble", "Tree"]
	return scatter_types[rng.randi() % scatter_types.size()]

func _apply_quarters_to_grid(battlefield: Dictionary) -> void:
	var quarter_size = Vector2i(GRID_SIZE.x / 2, GRID_SIZE.y / 2)
	for q in range(4):
		var start_x = (q % 2) * quarter_size.x
		var start_y = (q / 2) * quarter_size.y
		
		for feature in battlefield.quarters[q].features:
			var position = Vector2i(
				rng.randi_range(start_x, start_x + quarter_size.x - 1),
				rng.randi_range(start_y, start_y + quarter_size.y - 1)
			)
			_apply_feature_to_grid(battlefield.grid, {"type": feature.type, "position": position})
		
		for scatter in battlefield.quarters[q].scatter_terrain:
			var position = Vector2i(
				rng.randi_range(start_x, start_x + quarter_size.x - 1),
				rng.randi_range(start_y, start_y + quarter_size.y - 1)
			)
			battlefield.grid[position.x][position.y] = "S"  # S for scatter

func _apply_feature_to_grid(grid: Array, feature: Dictionary) -> void:
	var symbol = _get_feature_symbol(feature.type)
	grid[feature.position.x][feature.position.y] = symbol

func _get_feature_symbol(feature_type: String) -> String:
	# Implement logic to assign symbols to different feature types
	return feature_type[0].to_upper()  # Placeholder: first letter of feature type

func generate_deployment_condition(mission_type: String) -> Dictionary:
	# Use the provided generate_deployment_condition function
	return generate_deployment_condition(mission_type)

func generate_notable_sight(mission_type: String) -> Dictionary:
	# Use the provided generate_notable_sight function
	return generate_notable_sight(mission_type)

func _get_notable_feature_table(terrain_type: TerrainType) -> Array:
	match terrain_type:
		TerrainType.INDUSTRIAL:
			return ["Large structure", "Industrial cluster", "Fenced area", "Landing pad", "Cargo area", "Large structure"]
		TerrainType.WILDERNESS:
			return ["Forested hill", "Swamp", "Rock formations", "Forested area", "Large hill", "Single building"]
		TerrainType.ALIEN_RUIN:
			return ["Overgrown area", "Large debris", "Ruined building", "Overgrown plaza", "Ruined tower", "Large statue"]
		TerrainType.CRASH_SITE:
			return ["Damaged structure", "Natural features with wreckage", "Burning forest", "Wreckage pile", "Large wreckage in crater", "Large crater"]
	return []  # Should never reach here

func _get_regular_feature_table(terrain_type: TerrainType) -> Array:
	match terrain_type:
		TerrainType.INDUSTRIAL:
			return ["Linear obstacle", "Building", "Open ground", "Scatter cluster", "Statue", "Industrial item"]
		TerrainType.WILDERNESS:
			return ["Difficult terrain", "Rock formation", "Plant cluster", "Rock formation", "Open space", "Natural linear feature"]
		TerrainType.ALIEN_RUIN:
			return ["Odd feature", "Ruined building", "Partial ruin", "Open space", "Strange statue", "Scattered plants"]
		TerrainType.CRASH_SITE:
			return ["Mixed scatter", "Scattered wreckage", "Large wreckage", "Crater", "Natural feature", "Open ground"]
	return []  # Should never reach here

func get_battlefield_representation(battlefield: Dictionary) -> String:
	var representation = "Battlefield Layout:\n\n"
	
	# Add grid representation
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			representation += battlefield.grid[x][y] + " "
		representation += "\n"
	
	# Add mission info
	representation += "\nMission Type: " + battlefield.mission_type
	representation += "\nTerrain Type: " + TerrainType.keys()[battlefield.terrain_type]
	
	# Add deployment condition
	representation += "\n\nDeployment Condition: " + battlefield.deployment_condition.name
	representation += "\nEffect: " + battlefield.deployment_condition.effect
	
	# Add notable sight
	representation += "\n\nNotable Sight: " + battlefield.notable_sight.name
	representation += "\nEffect: " + battlefield.notable_sight.effect
	
	# Add center feature
	representation += "\n\nCenter Feature: " + battlefield.center_feature.type
	
	# Add quarter features
	for q in range(4):
		representation += "\n\nQuarter " + str(q+1) + " Features:"
		for feature in battlefield.quarters[q].features:
			representation += "\n- " + feature.type
		representation += "\nScatter Terrain: " + str(battlefield.quarters[q].scatter_terrain.size()) + " pieces"
	
	return representation

func _on_generate_terrain_pressed():
    game_manager.generate_battlefield()
    update_battlefield_display()

func update_battlefield_display():
    var terrain_map = game_manager.terrain_generator.get_terrain_map()
    var feature_map = game_manager.terrain_generator.get_feature_map()
    var cover_map = game_manager.terrain_generator.get_cover_map()
    var loot_map = game_manager.terrain_generator.get_loot_map()
    var enemies_map = game_manager.terrain_generator.get_enemies_map()
    var npcs_map = game_manager.terrain_generator.get_npcs_map()
    var events_map = game_manager.terrain_generator.get_events_map()
    var encounters_map = game_manager.terrain_generator.get_encounters_map()
    var missions_map = game_manager.terrain_generator.get_missions_map()