@tool
@warning_ignore("return_value_discarded")
	extends Node

# Pre-run script that executes before any tests
# This ensures proper initialization of dependencies

const REQUIRED_AUTOLOADS = {
	"GameEnums": "res://src/core/systems/GlobalEnums.gd"
}

func _init() -> void:
	print("Running pre-test initialization...")
	_ensure_autoloads()
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

func _ensure_autoloads() -> void:
	for autoload_name in REQUIRED_AUTOLOADS:
		if not Engine.has_singleton(autoload_name):
			print("Adding required autoload: ", autoload_name)
			@warning_ignore("return_value_discarded")
	add_child(load(REQUIRED_AUTOLOADS[autoload_name]).new())

func setup() -> void:
	# Ensure all core systems are initialized
	if not Engine.has_singleton("GameState"):
		var game_state = load("res://src/core/state/GameState.gd").new()
		@warning_ignore("return_value_discarded")
	add_child(game_state)
	
	# Wait for a frame to ensure everything is initialized
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

func cleanup() -> void:
	# Clean up any test resources
	for child in get_children():
		child.@warning_ignore("return_value_discarded")
	queue_free()
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame