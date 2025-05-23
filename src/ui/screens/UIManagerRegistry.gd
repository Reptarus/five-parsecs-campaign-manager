@tool
extends Node

## Registry for providing global access to the UIManager
## This is intended to be loaded as an autoload singleton

var ui_manager: Node = null

## Set the active UI manager instance
func register_ui_manager(manager: Node) -> void:
	ui_manager = manager
	
## Get the current UI manager instance
func get_ui_manager() -> Node:
	return ui_manager
	
## Check if a UI manager is registered
func has_ui_manager() -> bool:
	return ui_manager != null