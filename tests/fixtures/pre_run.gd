@tool
extends Node

# Pre-run script that executes before any tests
# This ensures proper initialization of dependencies

const REQUIRED_AUTOLOADS = {
	"GameEnums": "res://src/core/systems/GlobalEnums.gd"
}

func _init() -> void:
	print("Running pre-test initialization...")
	_ensure_autoloads()
	await get_tree().process_frame

func _ensure_autoloads() -> void:
	for autoload_name in REQUIRED_AUTOLOADS:
		if not Engine.has_singleton(autoload_name):
			print("Adding required autoload: ", autoload_name)
			add_child(load(REQUIRED_AUTOLOADS[autoload_name]).new())

func setup() -> void:
	# Ensure all core systems are initialized
	if not Engine.has_singleton("GameState"):
		var game_state = load("res://src/core/state/GameState.gd").new()
		add_child(game_state)
	
	# Wait for a frame to ensure everything is initialized
	await get_tree().process_frame

func cleanup() -> void:
	# Clean up any test resources
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame