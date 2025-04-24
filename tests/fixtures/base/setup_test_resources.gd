@tool
extends Node

## Test Resource Setup
## This script initializes the resource management system for tests
## It should be one of the first scripts executed in the test suite

# Load ResourcePool
const ResourcePool = preload("res://tests/fixtures/helpers/resource_pool.gd")

# Common paths that cause resource loading issues
const PROBLEMATIC_PATHS = [
	"res://src/core/mission/MissionManager.gd",
	"res://src/core/enemy/managers/EnemyManager.gd",
	"res://src/core/story/UnifiedStorySystem.gd",
	"res://src/core/managers/GameStateManager.gd",
	"res://src/core/terrain/TerrainManager.gd"
]

# Initialize the resource manager
var _resource_pool = null

func _ready() -> void:
	print("Setting up test resources...")
	
	# Initialize resource pool
	_resource_pool = ResourcePool.get_instance()
	
	# Preload problematic resources
	for path in PROBLEMATIC_PATHS:
		if ResourceLoader.exists(path):
			var resource = _resource_pool.get_test_resource(path)
			if resource:
				print("  Preloaded: " + path)
			else:
				print("  Failed to preload: " + path)
	
	print("Test resource setup complete")

func _exit_tree() -> void:
	# Clean up resources when this node is removed
	if _resource_pool:
		_resource_pool.cleanup_resource_pool()
		print("Test resources cleaned up")