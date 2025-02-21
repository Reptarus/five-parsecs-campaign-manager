@tool
extends FiveParsecsEnemyTest

const TerrainLayoutGenerator = preload("res://src/core/terrain/TerrainLayoutGenerator.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")

var generator
var terrain_system
var position_validator

func before_each() -> void:
	await super.before_each()
	
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	track_test_node(terrain_system)
	terrain_system.initialize_grid(Vector2(10, 10))
	
	position_validator = PositionValidator.new()
	add_child(position_validator)
	track_test_node(position_validator)
	
	generator = TerrainLayoutGenerator.new(terrain_system)
	add_child(generator)
	track_test_node(generator)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	generator = null
	terrain_system = null
