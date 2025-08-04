extends RefCounted
class_name FiveParsecsUIController

## Minimal Base Controller - Framework Bible Compliant
## Simple controller pattern for campaign panel logic
## NO Enhanced/Manager bloat - just essential functionality

# Simple controller signals
signal controller_updated()
signal controller_error(error_message: String)

# Basic controller state
var is_initialized: bool = false

func _init() -> void:
	initialize_controller()

## Core Controller Interface
func initialize_controller() -> void:
	"""Initialize controller - override in derived classes"""
	is_initialized = true

func update_controller() -> void:
	"""Update controller state"""
	controller_updated.emit()

func cleanup_controller() -> void:
	"""Clean up controller resources"""
	is_initialized = false

## Error handling
func handle_error(error: String) -> void:
	"""Handle controller errors"""
	controller_error.emit(error)
	push_error("BaseController: " + error)