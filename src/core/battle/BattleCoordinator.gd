@tool
extends Node
class_name BattleCoordinator

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterUnit = preload("res://src/core/battle/CharacterUnit.gd")
const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const AIController = preload("res://src/core/battle/AIController.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")
const EnemyData = preload("res://src/core/enemy/EnemyData.gd")

# Signals
signal battle_setup_complete(battle_context)
signal battle_setup_failed(error_message)
signal battle_completed(results)
signal initialization_progress(progress, message)

# Components
var state_machine = null
var battlefield_manager = null
var ai_controller = null
var results_manager = null

# Battle context
var battle_context = {
	"player_units": [],
	"enemy_units": [],
	"mission_data": {},
	"battlefield_data": {},
	"campaign_data": {}
}

# State tracking
var _setup_complete = false
var _initialization_steps = 0
var _total_initialization_steps = 6 # Total steps in battle setup

func _init():
	# Initialize with null references to avoid errors
	state_machine = null
	battlefield_manager = null
	ai_controller = null
	results_manager = null
	_setup_complete = false

func _ready():
	# When added to scene tree, prevent multiple initializations
	set_process(false)
	
# Setup the battle with all required data
func setup_battle(mission_data, campaign_data = null):
	_setup_complete = false
	_initialization_steps = 0
	battle_context.mission_data = mission_data
	battle_context.campaign_data = campaign_data
	
	# Begin initialization steps
	_update_initialization_progress("Starting battle setup", 0.0)
	
	# Step 1: Initialize battlefield
	var battlefield_result = _initialize_battlefield()
	if not battlefield_result.success:
		battle_setup_failed.emit(battlefield_result.error)
		return false
	
	# Step 2: Initialize battle state machine
	var state_result = _initialize_state_machine()
	if not state_result.success:
		battle_setup_failed.emit(state_result.error)
		return false
	
	# Step 3: Initialize AI controller
	var ai_result = _initialize_ai_controller()
	if not ai_result.success:
		battle_setup_failed.emit(ai_result.error)
		return false
	
	# Step 4: Initialize result manager
	var results_result = _initialize_results_manager()
	if not results_result.success:
		battle_setup_failed.emit(results_result.error)
		return false
	
	# Step 5: Setup player units
	var player_result = _setup_player_units()
	if not player_result.success:
		battle_setup_failed.emit(player_result.error)
		return false
	
	# Step 6: Setup enemy units
	var enemy_result = _setup_enemy_units()
	if not enemy_result.success:
		battle_setup_failed.emit(enemy_result.error)
		return false
	
	# Final setup and connections
	_connect_battle_signals()
	_setup_complete = true
	
	# Notify completion
	_update_initialization_progress("Battle setup complete", 1.0)
	battle_setup_complete.emit(battle_context)
	return true

# Initialize battlefield with mission data
func _initialize_battlefield():
	_update_initialization_progress("Initializing battlefield", 1.0 / _total_initialization_steps)
	
	battlefield_manager = BattlefieldManager.new()
	if not is_instance_valid(battlefield_manager):
		return {success = false, error = "Failed to create battlefield manager"}
	
	add_child(battlefield_manager)
	
	# Set up battlefield based on mission data
	var config = battle_context.mission_data.get("battlefield_config", {})
	var generate_result = battlefield_manager.generate_battlefield(config)
	
	if not generate_result or generate_result.size() == 0:
		return {success = false, error = "Failed to generate battlefield"}
	
	battle_context.battlefield_data = generate_result
	return {success = true}

# Initialize the battle state machine
func _initialize_state_machine():
	_update_initialization_progress("Initializing battle state machine", 2.0 / _total_initialization_steps)
	
	state_machine = BattleStateMachine.new()
	if not is_instance_valid(state_machine):
		return {success = false, error = "Failed to create battle state machine"}
	
	add_child(state_machine)
	
	# Initialize state machine with battlefield reference
	if state_machine.has_method("set_battlefield_manager"):
		state_machine.set_battlefield_manager(battlefield_manager)
	
	return {success = true}

# Initialize the AI controller
func _initialize_ai_controller():
	_update_initialization_progress("Initializing AI controller", 3.0 / _total_initialization_steps)
	
	ai_controller = AIController.new()
	if not is_instance_valid(ai_controller):
		return {success = false, error = "Failed to create AI controller"}
	
	add_child(ai_controller)
	
	# Configure AI
	ai_controller.set_battlefield_manager(battlefield_manager)
	
	# Set difficulty based on mission data
	var difficulty = battle_context.mission_data.get("difficulty", 3)
	ai_controller.set_difficulty(difficulty)
	
	return {success = true}

# Initialize the results manager
func _initialize_results_manager():
	_update_initialization_progress("Initializing results manager", 4.0 / _total_initialization_steps)
	
	results_manager = BattleResultsManager.new()
	if not is_instance_valid(results_manager):
		return {success = false, error = "Failed to create results manager"}
	
	add_child(results_manager)
	
	# Configure with mission info
	if results_manager.has_method("set_mission_data"):
		results_manager.set_mission_data(battle_context.mission_data)
	
	if results_manager.has_method("set_campaign_data") and battle_context.campaign_data:
		results_manager.set_campaign_data(battle_context.campaign_data)
	
	return {success = true}

# Setup player units from mission data
func _setup_player_units():
	_update_initialization_progress("Setting up player units", 5.0 / _total_initialization_steps)
	
	var player_units_data = battle_context.mission_data.get("player_units", [])
	if player_units_data.is_empty():
		return {success = false, error = "No player units found in mission data"}
	
	battle_context.player_units = []
	
	for unit_data in player_units_data:
		var unit = _create_character_unit(unit_data, true)
		if not is_instance_valid(unit):
			continue
			
		# Register with state machine
		if is_instance_valid(state_machine):
			state_machine.add_character(unit)
		
		battle_context.player_units.append(unit)
	
	# Validate we have at least one player unit
	if battle_context.player_units.is_empty():
		return {success = false, error = "Failed to create any player units"}
	
	return {success = true}

# Setup enemy units from mission data
func _setup_enemy_units():
	_update_initialization_progress("Setting up enemy units", 6.0 / _total_initialization_steps)
	
	var enemy_units_data = battle_context.mission_data.get("enemy_units", [])
	if enemy_units_data.is_empty():
		return {success = false, error = "No enemy units found in mission data"}
	
	battle_context.enemy_units = []
	
	for unit_data in enemy_units_data:
		var unit = _create_character_unit(unit_data, false)
		if not is_instance_valid(unit):
			continue
			
		# Initialize enemy data
		_initialize_enemy_data(unit, unit_data)
		
		# Register with state machine
		if is_instance_valid(state_machine):
			state_machine.add_character(unit)
		
		battle_context.enemy_units.append(unit)
	
	# Register units with AI controller
	if is_instance_valid(ai_controller):
		ai_controller.register_units(battle_context.enemy_units, battle_context.player_units)
	
	# Validate we have at least one enemy unit
	if battle_context.enemy_units.is_empty():
		return {success = false, error = "Failed to create any enemy units"}
	
	return {success = true}

# Create a character unit from unit data
func _create_character_unit(unit_data, is_player):
	var unit = CharacterUnit.new()
	if not is_instance_valid(unit):
		push_error("Failed to create CharacterUnit instance")
		return null
	
	# Basic setup
	unit.set_is_player(is_player)
	
	# Set unit data
	if unit_data.has("name"):
		unit.set_name(unit_data.name)
	
	if unit_data.has("health"):
		unit.set_health(unit_data.health)
	
	if unit_data.has("attack"):
		unit.set_attack(unit_data.attack)
	
	if unit_data.has("defense"):
		unit.set_defense(unit_data.defense)
	
	if unit_data.has("speed"):
		unit.set_speed(unit_data.speed)
	
	# Position unit on battlefield
	if is_instance_valid(battlefield_manager) and unit_data.has("position"):
		unit.global_position = unit_data.position
	elif is_instance_valid(battlefield_manager):
		# Auto-position based on deployment zones
		if is_player:
			unit.global_position = battlefield_manager.get_player_deployment_position()
		else:
			unit.global_position = battlefield_manager.get_enemy_deployment_position()
	
	add_child(unit)
	return unit

# Initialize enemy AI and data
func _initialize_enemy_data(enemy_unit, unit_data):
	if not is_instance_valid(enemy_unit):
		return
	
	# Create enemy data
	var enemy_data = EnemyData.new()
	if not is_instance_valid(enemy_data):
		push_error("Failed to create EnemyData instance")
		return
	
	# Set enemy type
	if unit_data.has("enemy_type"):
		enemy_data.type = unit_data.enemy_type
	else:
		enemy_data.type = GameEnums.EnemyType.NONE
	
	# Initialize enemy data and AI
	if enemy_unit.has_method("set_enemy_data"):
		enemy_unit.set_enemy_data(enemy_data)
	
	# Initialize additional enemy properties based on type
	if unit_data.has("ai_behavior"):
		# Load and apply AI script if needed
		_initialize_enemy_ai(enemy_unit, unit_data.ai_behavior)

# Initialize enemy AI based on behavior type
func _initialize_enemy_ai(enemy_unit, ai_behavior):
	# Different AI behaviors would be handled here
	# This is where you'd attach the appropriate AI script/behavior
	pass

# Connect battle-related signals
func _connect_battle_signals():
	# Connect state machine signals
	if is_instance_valid(state_machine):
		if not state_machine.is_connected("battle_ended", Callable(self, "_on_battle_ended")):
			state_machine.connect("battle_ended", Callable(self, "_on_battle_ended"))
	
	# Connect AI controller signals
	if is_instance_valid(ai_controller):
		if not ai_controller.is_connected("ai_turn_ended", Callable(self, "_on_ai_turn_ended")):
			ai_controller.connect("ai_turn_ended", Callable(self, "_on_ai_turn_ended"))
	
	# Connect results manager signals
	if is_instance_valid(results_manager):
		if not results_manager.is_connected("results_processed", Callable(self, "_on_results_processed")):
			results_manager.connect("results_processed", Callable(self, "_on_results_processed"))

# Start the battle (after setup is complete)
func start_battle():
	if not _setup_complete:
		push_error("Cannot start battle: setup not complete")
		return false
	
	if is_instance_valid(state_machine):
		state_machine.start_battle()
		return true
	
	return false

# Update initialization progress
func _update_initialization_progress(message, progress):
	_initialization_steps += 1
	initialization_progress.emit(progress, message)

# Cleanup after battle is done
func cleanup():
	# Disconnect signals
	if is_instance_valid(state_machine):
		if state_machine.is_connected("battle_ended", Callable(self, "_on_battle_ended")):
			state_machine.disconnect("battle_ended", Callable(self, "_on_battle_ended"))
	
	if is_instance_valid(ai_controller):
		if ai_controller.is_connected("ai_turn_ended", Callable(self, "_on_ai_turn_ended")):
			ai_controller.disconnect("ai_turn_ended", Callable(self, "_on_ai_turn_ended"))
	
	if is_instance_valid(results_manager):
		if results_manager.is_connected("results_processed", Callable(self, "_on_results_processed")):
			results_manager.disconnect("results_processed", Callable(self, "_on_results_processed"))
	
	# Free resources
	for unit in battle_context.player_units + battle_context.enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	
	battle_context.player_units.clear()
	battle_context.enemy_units.clear()
	
	# Queue free components
	if is_instance_valid(state_machine):
		state_machine.queue_free()
	state_machine = null
	
	if is_instance_valid(battlefield_manager):
		battlefield_manager.queue_free()
	battlefield_manager = null
	
	if is_instance_valid(ai_controller):
		ai_controller.queue_free()
	ai_controller = null
	
	if is_instance_valid(results_manager):
		results_manager.queue_free()
	results_manager = null
	
	# Reset state
	_setup_complete = false
	
	# Force garbage collection
	OS.delay_msec(100)
	
	return true

# Signal handlers
func _on_battle_ended(victory):
	if is_instance_valid(results_manager):
		var results = results_manager.process_battle_results({
			"victory": victory,
			"player_units": battle_context.player_units,
			"enemy_units": battle_context.enemy_units,
			"mission_data": battle_context.mission_data
		})
		
		battle_completed.emit(results)

func _on_ai_turn_ended():
	# Handle AI turn completion
	pass

func _on_results_processed(results):
	# Process the battle results for campaign updates
	pass
