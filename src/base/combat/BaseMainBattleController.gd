@tool
extends Node
class_name BaseMainBattleController

# Dependencies
const BaseBattlefieldManager = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const BaseBattlefieldGenerator = preload("res://src/base/combat/battlefield/BaseBattlefieldGenerator.gd")
const BaseCombatManager = preload("res://src/base/combat/BaseCombatManager.gd")
const BaseBattleRules = preload("res://src/base/combat/BaseBattleRules.gd")
const BaseBattleData = preload("res://src/base/combat/BaseBattleData.gd")

# Signals
signal battle_initialized(battle_data: Dictionary)
signal battle_started()
signal battle_ended(result: Dictionary)
signal turn_started(turn_number: int, active_faction: int)
signal turn_ended(turn_number: int, active_faction: int)
signal phase_changed(phase: int)
signal unit_activated(unit: Node)
signal unit_deactivated(unit: Node)
signal action_performed(unit: Node, action: Dictionary)
signal objective_completed(objective_id: String, faction: int)

# Battle state
var battle_data: Dictionary = {}
var current_turn: int = 0
var current_phase: int = 0
var active_faction: int = 0
var active_unit: Node = null
var battle_active: bool = false
var battle_result: Dictionary = {}
var objectives: Array = []
var completed_objectives: Dictionary = {}

# System references
var battlefield_manager: BaseBattlefieldManager = null
var battlefield_generator: BaseBattlefieldGenerator = null
var combat_manager: BaseCombatManager = null
var battle_rules: BaseBattleRules = null

# Virtual methods to be implemented by derived classes
func _ready() -> void:
	_initialize_systems()
	_connect_signals()

func _initialize_systems() -> void:
	# Override in derived classes to initialize game-specific systems
	pass

func _connect_signals() -> void:
	# Connect signals from battlefield manager
	if battlefield_manager:
		battlefield_manager.unit_moved.connect(_on_unit_moved)
		battlefield_manager.unit_added.connect(_on_unit_added)
		battlefield_manager.unit_removed.connect(_on_unit_removed)
	
	# Connect signals from combat manager
	if combat_manager:
		combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
		combat_manager.character_position_updated.connect(_on_character_position_updated)
	
	# Connect signals from battlefield generator
	if battlefield_generator:
		battlefield_generator.generation_completed.connect(_on_battlefield_generation_completed)

# Battle initialization and control
func initialize_battle(battle_config: Dictionary = {}) -> void:
	battle_active = false
	current_turn = 0
	current_phase = 0
	active_faction = 0
	active_unit = null
	battle_result = {}
	objectives = []
	completed_objectives = {}
	
	# Generate battlefield if not provided
	if not "battlefield" in battle_config:
		_generate_battlefield(battle_config.get("battlefield_config", {}))
	else:
		_load_battlefield(battle_config.battlefield)
	
	# Initialize units
	_initialize_units(battle_config.get("units", {}))
	
	# Initialize objectives
	_initialize_objectives(battle_config.get("objectives", []))
	
	# Compile battle data
	battle_data = {
		"config": battle_config,
		"battlefield": battlefield_manager.validate_battlefield(),
		"units": _get_units_data(),
		"objectives": objectives
	}
	
	battle_initialized.emit(battle_data)

func start_battle() -> void:
	if not battle_active:
		battle_active = true
		current_turn = 1
		current_phase = 0
		
		# Determine starting faction
		active_faction = _determine_starting_faction()
		
		battle_started.emit()
		_start_turn()

func end_battle(result: Dictionary = {}) -> void:
	if battle_active:
		battle_active = false
		battle_result = result
		battle_ended.emit(result)

func next_turn() -> void:
	if battle_active:
		current_turn += 1
		_start_turn()

func next_phase() -> void:
	if battle_active:
		current_phase += 1
		phase_changed.emit(current_phase)
		_process_phase()

func activate_unit(unit: Node) -> void:
	if battle_active and unit:
		active_unit = unit
		unit_activated.emit(unit)

func deactivate_unit() -> void:
	if battle_active and active_unit:
		var unit = active_unit
		active_unit = null
		unit_deactivated.emit(unit)

func perform_action(unit: Node, action: Dictionary) -> void:
	if battle_active and unit:
		_process_action(unit, action)
		action_performed.emit(unit, action)

# Battlefield management
func _generate_battlefield(config: Dictionary = {}) -> void:
	if battlefield_generator:
		# Apply configuration
		if "grid_size" in config:
			battlefield_generator.grid_size = config.grid_size
		if "terrain_pattern" in config:
			battlefield_generator.terrain_pattern = config.terrain_pattern
		if "deployment_style" in config:
			battlefield_generator.deployment_style = config.deployment_style
		if "seed" in config:
			battlefield_generator.generation_seed = config.seed
			battlefield_generator.use_random_seed = false
		
		# Generate battlefield
		battlefield_generator.generate_battlefield()

func _load_battlefield(battlefield_data: Dictionary) -> void:
	if battlefield_manager:
		# Initialize battlefield
		battlefield_manager.initialize_battlefield(battlefield_data.get("grid_size", Vector2i(24, 24)))
		
		# Load terrain
		for terrain in battlefield_data.get("terrain", []):
			battlefield_manager.set_terrain(terrain.position, terrain.type)
		
		# Load deployment zones
		for zone_type in battlefield_data.get("deployment_zones", {}):
			battlefield_manager.set_deployment_zone(zone_type, battlefield_data.deployment_zones[zone_type])

# Unit management
func _initialize_units(units_data: Dictionary) -> void:
	# Clear existing units
	if battlefield_manager:
		for unit in battlefield_manager.unit_positions.keys():
			battlefield_manager.remove_unit(unit)
	
	# Add player units
	for unit_data in units_data.get("player", []):
		_add_unit(unit_data, 1) # 1 = player faction
	
	# Add enemy units
	for unit_data in units_data.get("enemy", []):
		_add_unit(unit_data, 2) # 2 = enemy faction

func _add_unit(unit_data: Dictionary, faction: int) -> Node:
	# To be implemented by derived classes
	return null

func _get_units_data() -> Dictionary:
	var units_data = {
		"player": [],
		"enemy": []
	}
	
	# To be implemented by derived classes
	
	return units_data

# Objective management
func _initialize_objectives(objectives_data: Array) -> void:
	objectives = objectives_data.duplicate()
	completed_objectives = {}

func complete_objective(objective_id: String, faction: int) -> void:
	if objective_id in objectives and not objective_id in completed_objectives:
		completed_objectives[objective_id] = faction
		objective_completed.emit(objective_id, faction)
		_check_victory_conditions()

func _check_victory_conditions() -> void:
	# To be implemented by derived classes
	pass

# Turn and phase management
func _start_turn() -> void:
	current_phase = 0
	turn_started.emit(current_turn, active_faction)
	next_phase()

func _end_turn() -> void:
	turn_ended.emit(current_turn, active_faction)
	_switch_faction()
	
	if active_faction == 1: # Back to player faction
		next_turn()
	else:
		_start_turn()

func _switch_faction() -> void:
	active_faction = 3 - active_faction # Toggle between 1 and 2

func _determine_starting_faction() -> int:
	# To be implemented by derived classes
	return 1 # Default to player

func _process_phase() -> void:
	# To be implemented by derived classes
	pass

func _process_action(unit: Node, action: Dictionary) -> void:
	# To be implemented by derived classes
	pass

# Signal handlers
func _on_unit_moved(unit: Node, from: Vector2i, to: Vector2i) -> void:
	# To be implemented by derived classes
	pass

func _on_unit_added(unit: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	pass

func _on_unit_removed(unit: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	pass

func _on_combat_state_changed(new_state: Dictionary) -> void:
	# To be implemented by derived classes
	pass

func _on_combat_result_calculated(attacker: Node, target: Node, result: Dictionary) -> void:
	# To be implemented by derived classes
	pass

func _on_character_position_updated(character: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	pass

func _on_battlefield_generation_completed(battlefield_data: Dictionary) -> void:
	# To be implemented by derived classes
	pass