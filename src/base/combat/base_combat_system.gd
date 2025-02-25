@tool
extends Node

## Base class for combat systems
##
## Provides the core functionality and interface for combat systems.
## Implementations should extend this class to provide game-specific combat mechanics.

# Combat state signals
signal combat_started
signal combat_ended
signal turn_started(unit: Node)
signal turn_ended(unit: Node)
signal action_performed(unit: Node, action: int)

# Combat state
var is_combat_active: bool = false
var current_turn: int = 0
var active_unit: Node = null
var combat_units: Array[Node] = []

# Virtual methods to be implemented by derived classes
func initialize_combat() -> void:
	pass

func start_combat() -> void:
	is_combat_active = true
	current_turn = 0
	combat_started.emit()

func end_combat() -> void:
	is_combat_active = false
	combat_ended.emit()

func start_turn(unit: Node) -> void:
	if not unit in combat_units:
		push_error("Invalid unit for turn start")
		return
	
	active_unit = unit
	turn_started.emit(unit)

func end_turn(unit: Node) -> void:
	if unit != active_unit:
		push_error("Trying to end turn for non-active unit")
		return
	
	turn_ended.emit(unit)
	active_unit = null

func perform_action(unit: Node, action: int) -> void:
	if not unit in combat_units:
		push_error("Invalid unit for action")
		return
	
	if not is_combat_active:
		push_error("Cannot perform action outside of combat")
		return
	
	action_performed.emit(unit, action)

func add_combat_unit(unit: Node) -> void:
	if not unit in combat_units:
		combat_units.append(unit)

func remove_combat_unit(unit: Node) -> void:
	combat_units.erase(unit)

func get_combat_units() -> Array[Node]:
	return combat_units.duplicate()

func is_valid_action(unit: Node, action: int) -> bool:
	return unit in combat_units and is_combat_active