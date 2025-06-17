@tool
extends GdUnitGameTest

const Enemy: GDScript = preload("res://src/core/enemy/base/Enemy.gd")

# Common test scenarios
const SCENARIOS: Dictionary = {
	"BASIC_COMBAT": {
		"enemies": [
			{"type": "BASIC", "position": Vector2(0, 0)},
			{"type": "BASIC", "position": Vector2(10, 0)}
		],
		"terrain": [],
		"objectives": []
	},
	"GROUP_TACTICS": {
		"enemies": [
			{"type": "ELITE", "position": Vector2(0, 0), "role": "leader"},
			{"type": "BASIC", "position": Vector2(5, 5), "role": "support"},
			{"type": "BASIC", "position": Vector2(-5, 5), "role": "support"}
		],
		"terrain": [
			{"type": "cover", "position": Vector2(10, 10)},
			{"type": "cover", "position": Vector2(-10, 10)}
		],
		"objectives": [
			{"type": "control_point", "position": Vector2(0, 20)}
		]
	},
	"AMBUSH": {
		"enemies": [
			{"type": "ELITE", "position": Vector2(-10, 0), "role": "leader"},
			{"type": "BASIC", "position": Vector2(10, 0), "role": "flanker"},
			{"type": "BASIC", "position": Vector2(0, 10), "role": "support"}
		],
		"terrain": [
			{"type": "cover", "position": Vector2(-5, 0)},
			{"type": "cover", "position": Vector2(5, 0)}
		],
		"objectives": []
	}
}

# Test data generation
static func create_scenario(scenario_name: String, test_instance: GdUnitGameTest) -> Dictionary:
	assert(SCENARIOS.has(scenario_name), "Invalid scenario name")
	var scenario: Dictionary = SCENARIOS[scenario_name]
	
	var result: Dictionary = {
		"enemies": [],
		"terrain": [],
		"objectives": []
	}
	
	# Create enemies
	for enemy_data in scenario.enemies:
		var enemy: Enemy = test_instance.create_test_enemy(enemy_data.type)
		enemy.position = enemy_data.position
		if enemy_data.has("role"):
			enemy.set_meta("role", enemy_data.role)
		result.enemies.append(enemy)
	
	# Create terrain
	for terrain_data in scenario.terrain:
		var terrain: Node2D = Node2D.new()
		terrain.position = terrain_data.position
		terrain.set_meta("type", terrain_data.type)
		test_instance.track_node(terrain)
		result.terrain.append(terrain)
	
	# Create objectives
	for objective_data in scenario.objectives:
		var objective: Node2D = Node2D.new()
		objective.position = objective_data.position
		objective.set_meta("type", objective_data.type)
		test_instance.track_node(objective)
		result.objectives.append(objective)
	
	return result

# Scenario validation
static func validate_scenario_state(scenario: Dictionary, expected_state: Dictionary) -> bool:
	var valid: bool = true
	
	# Validate enemy positions and states
	if expected_state.has("enemy_positions"):
		for i in range(scenario.enemies.size()):
			if i < expected_state.enemy_positions.size():
				valid = valid and scenario.enemies[i].position.distance_to(
					expected_state.enemy_positions[i]) < 1.0
	
	# Validate objective control
	if expected_state.has("objective_control"):
		for i in range(scenario.objectives.size()):
			if i < expected_state.objective_control.size():
				valid = valid and scenario.objectives[i].get_meta(
					"controlled_by") == expected_state.objective_control[i]
	
	return valid

# Helper methods
static func get_enemies_by_role(scenario: Dictionary, role: String) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in scenario.enemies:
		if enemy.has_meta("role") and enemy.get_meta("role") == role:
			result.append(enemy)
	return result

static func get_terrain_by_type(scenario: Dictionary, type: String) -> Array[Node]:
	var result: Array[Node] = []
	for terrain in scenario.terrain:
		if terrain.has_meta("type") and terrain.get_meta("type") == type:
			result.append(terrain)
	return result

static func get_objectives_by_type(scenario: Dictionary, type: String) -> Array[Node]:
	var result: Array[Node] = []
	for objective in scenario.objectives:
		if objective.has_meta("type") and objective.get_meta("type") == type:
			result.append(objective)
	return result