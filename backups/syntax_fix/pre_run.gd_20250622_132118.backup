@tool
extends Node

# Pre-run script that executes before any tests
#

const REQUIRED_AUTOLOADS = {
		"GameEnums": "res://src/core/systems/GlobalEnums.gd",
func _init() -> void:
	pass
# 	print("Running pre-test initialization...")
# 	_ensure_autoloads()
#

func _ensure_autoloads() -> void:
	for autoload_name in REQUIRED_AUTOLOADS:
		if not Engine.has_singleton(autoload_name):
		pass
			add_child(load(REQUIRED_AUTOLOADS[autoload_name]).new())

func setup() -> void:
	pass
	#
	if not Engine.has_singleton("GameState"):
		pass
# 		# add_child(node)
	
	# Wait for a frame to ensure everything is initialized
#

func cleanup() -> void:
	pass
	#
	for child in get_children():
		child.queue_free()
pass