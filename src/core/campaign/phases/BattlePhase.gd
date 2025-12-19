extends Node
class_name BattlePhase

## Battle Phase Implementation - Official Five Parsecs Rules
## Handles the complete Battle Phase sequence (Phase 3 of campaign turn)

# Safe imports

# Safe dependency loading - loaded at runtime in _ready()
# GlobalEnums available as autoload singleton
var dice_manager: Variant = null
var game_state_manager: Variant = null

## Battle Phase Signals
signal ready_for_battle()  # Emitted when initialization is complete
signal battle_phase_started()
signal battle_phase_completed()
signal battle_substep_changed(substep: int)
signal battle_setup_completed(setup_data: Dictionary)
signal deployment_completed(deployment_data: Dictionary)
signal initiative_determined(initiative_roll: int)
signal combat_round_started(round: int)
signal combat_round_completed(round: int)
signal battle_results_ready(results: Dictionary)

## Current battle state
var current_substep: int = 0 # Will be set to BattlePhase.NONE in _ready()
var current_round: int = 0
var battle_in_progress: bool = false
var battle_setup_data: Dictionary = {}
var deployment_data: Dictionary = {}
var combat_results: Dictionary = {}

## Battle configuration
var max_rounds: int = 8 # Standard Five Parsecs battle length
var initiative_roll: int = 0
var crew_deployed: Array[Dictionary] = []
var enemies_deployed: Array[Dictionary] = []

func _ready() -> void:
	# Initialize enum values after loading GlobalEnums
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.NONE

	# Defer autoload access to avoid loading order issues
	call_deferred("_initialize_autoloads")
	print("BattlePhase: Initialized successfully")

func _initialize_autoloads() -> void:
	"""Initialize autoloads with retry logic to handle loading order"""
	# Wait for DiceManager to be ready
	for i in range(10):
		dice_manager = get_node_or_null("/root/DiceManager")
		if dice_manager:
			print("BattlePhase: ✅ DiceManager found on attempt ", i + 1)
			break
		print("BattlePhase: ⏳ Waiting for DiceManager... attempt ", i + 1)
		await get_tree().create_timer(0.1).timeout
	
	if not dice_manager:
		push_error("BattlePhase: DiceManager autoload not found after retries")
		print("BattlePhase: ❌ DiceManager not available - using fallback random generation")
	
	# Wait for GameStateManager to be ready
	for i in range(10):
		game_state_manager = get_node_or_null("/root/GameStateManager")
		if game_state_manager:
			print("BattlePhase: ✅ GameStateManager found on attempt ", i + 1)
			break
		print("BattlePhase: ⏳ Waiting for GameStateManager... attempt ", i + 1)
		await get_tree().create_timer(0.1).timeout
	
	if not game_state_manager:
		push_error("BattlePhase: GameStateManager not found after retries")
		# Try alternative access methods
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			if game_state_manager:
				print("BattlePhase: ✅ Found GameStateManager via AlphaGameManager")
		else:
			print("BattlePhase: ❌ No valid GameStateManager fallback available")

	# Emit ready signal after initialization completes (success or failure)
	ready_for_battle.emit()

## Main Battle Phase Processing
func start_battle_phase(mission_data: Dictionary = {}) -> void:
	"""Begin the Battle Phase sequence"""
	print("BattlePhase: Starting Battle Phase")
	battle_setup_data = mission_data.duplicate()
	battle_in_progress = true
	current_round = 0
	
	self.battle_phase_started.emit()

	# Step 1: Battle Setup
	_process_battle_setup()

func _process_battle_setup() -> void:
	"""Step 1: Battle Setup - Determine mission, enemies, terrain"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.SETUP
		self.battle_substep_changed.emit(current_substep)

	# Get mission type from setup data or generate
	var mission_type = battle_setup_data.get("mission_type", _generate_mission_type())
	
	# Generate enemy forces
	var enemy_count = _determine_enemy_count()
	var enemy_types = _generate_enemies(enemy_count)
	
	# Determine battlefield conditions
	var terrain_type = _determine_terrain()
	var deployment_conditions = _determine_deployment_conditions()
	
	# Store setup data
	battle_setup_data = {
		"mission_type": mission_type,
		"enemy_count": enemy_count,
		"enemy_types": enemy_types,
		"terrain": terrain_type,
		"deployment": deployment_conditions,
		"round_limit": max_rounds
	}

	print("BattlePhase: Battle setup completed - Mission: %s, Enemies: %d" % [mission_type, enemy_count])
	self.battle_setup_completed.emit(battle_setup_data)

	# Continue to deployment
	_process_deployment()

func _generate_mission_type() -> int:
	"""Generate random mission type"""
	if GlobalEnums:
		# Standard patrol mission (most common)
		return GlobalEnums.MissionType.PATROL
	return 0

func _determine_enemy_count() -> int:
	"""Determine number of enemies based on crew size and difficulty"""
	var crew_size = 4 # Default
	if game_state_manager and game_state_manager.has_method("get_crew_size"):
		crew_size = game_state_manager.get_crew_size()
	
	# Standard Five Parsecs: Crew size + 1D6
	var bonus_roll = randi_range(1, 6)
	return crew_size + bonus_roll

func _generate_enemies(count: int) -> Array[Dictionary]:
	"""Generate enemy force composition"""
	var enemies: Array[Dictionary] = []
	
	for i in range(count):
		var enemy = {
			"id": "enemy_%d" % i,
			"type": _get_random_enemy_type(),
			"combat_skill": randi_range(0, 2),
			"toughness": randi_range(3, 5),
			"speed": randi_range(4, 6),
			"weapons": ["Basic Rifle"]
		}
		enemies.append(enemy)
	
	return enemies

func _get_random_enemy_type() -> int:
	"""Get random enemy type"""
	if GlobalEnums:
		var enemy_types = [
			GlobalEnums.EnemyType.GANGERS,
			GlobalEnums.EnemyType.RAIDERS,
			GlobalEnums.EnemyType.PIRATES,
			GlobalEnums.EnemyType.CULTISTS
		]
		return enemy_types[randi() % enemy_types.size()]
	return 0

func _determine_terrain() -> int:
	"""Determine terrain type for battle"""
	if GlobalEnums:
		return GlobalEnums.PlanetEnvironment.TEMPERATE
	return 0

func _determine_deployment_conditions() -> Dictionary:
	"""Determine deployment conditions"""
	return {
		"crew_deployment_zone": "standard",
		"enemy_deployment_zone": "standard",
		"special_conditions": []
	}

func _process_deployment() -> void:
	"""Step 2: Deployment - Position forces on battlefield"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.DEPLOYMENT
		self.battle_substep_changed.emit(current_substep)

	# Get crew members for battle
	crew_deployed = _get_deployed_crew()
	enemies_deployed = battle_setup_data.get("enemy_types", [])

	deployment_data = {
		"crew_positions": _generate_deployment_positions(crew_deployed.size(), "crew"),
		"enemy_positions": _generate_deployment_positions(enemies_deployed.size(), "enemy"),
		"deployment_type": "standard"
	}

	print("BattlePhase: Deployment completed - Crew: %d, Enemies: %d" % [crew_deployed.size(), enemies_deployed.size()])
	self.deployment_completed.emit(deployment_data)

	# Continue to initiative
	_process_initiative()

func _get_deployed_crew() -> Array[Dictionary]:
	"""Get crew members deployed to battle"""
	var crew: Array[Dictionary] = []
	
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		var all_crew = game_state_manager.get_crew_members()
		# Filter to only healthy crew members
		for member in all_crew:
			if member.get("status", 0) == 0: # HEALTHY status
				crew.append(member)
	
	return crew

func _generate_deployment_positions(count: int, side: String) -> Array:
	"""Generate deployment positions for units"""
	var positions = []
	for i in range(count):
		positions.append({
			"unit_id": "%s_%d" % [side, i],
			"position": Vector2(i * 2, 0 if side == "crew" else 20)
		})
	return positions

func _process_initiative() -> void:
	"""Step 3: Initiative - Determine turn order"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.INITIATIVE
		self.battle_substep_changed.emit(current_substep)

	# Roll initiative (1D6, 4+ crew goes first)
	initiative_roll = randi_range(1, 6)
	var crew_first = initiative_roll >= 4

	print("BattlePhase: Initiative roll: %d - %s goes first" % [initiative_roll, "Crew" if crew_first else "Enemy"])
	self.initiative_determined.emit(initiative_roll)

	# Start combat rounds
	_process_combat_rounds()

func _process_combat_rounds() -> void:
	"""Step 4: Combat Rounds - Execute battle"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.ACTIVATION
		self.battle_substep_changed.emit(current_substep)

	# In full implementation, this would handle turn-by-turn combat
	# For now, simulate battle outcome
	print("BattlePhase: Beginning combat rounds (max %d rounds)" % max_rounds)
	
	# Simulate combat completion
	_simulate_battle_outcome()

func _simulate_battle_outcome() -> void:
	"""Simulate battle outcome (placeholder for full tactical combat)"""
	# Determine battle outcome
	var crew_strength = crew_deployed.size() * 5 # Simplified
	var enemy_strength = enemies_deployed.size() * 4 # Simplified
	
	var victory_roll = randi_range(1, 6)
	var success = (crew_strength + victory_roll) > enemy_strength

	# Calculate casualties
	var crew_casualties = 0 if success else randi_range(0, 2)
	var enemies_defeated = enemies_deployed.size() if success else randi_range(1, 3)

	combat_results = {
		"success": success,
		"rounds_fought": randi_range(3, 6),
		"crew_casualties": crew_casualties,
		"enemies_defeated": enemies_defeated,
		"loot_opportunities": enemies_defeated,
		"battlefield_finds": randi_range(0, 2)
	}

	print("BattlePhase: Battle concluded - Victory: %s, Enemies defeated: %d" % [str(success), enemies_defeated])
	
	# Complete battle phase
	_complete_battle_phase()

func _complete_battle_phase() -> void:
	"""Complete the Battle Phase"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattlePhase.CLEANUP

	battle_in_progress = false
	
	print("BattlePhase: Battle Phase completed")
	self.battle_results_ready.emit(combat_results)
	self.battle_phase_completed.emit()

## Public API Methods
func get_current_substep() -> int:
	"""Get the current battle sub-step"""
	return current_substep

func get_battle_results() -> Dictionary:
	"""Get battle results data"""
	return combat_results.duplicate()

func is_battle_phase_active() -> bool:
	"""Check if battle phase is currently active"""
	return battle_in_progress

func force_battle_outcome(outcome_data: Dictionary) -> void:
	"""Force specific battle outcome (for UI/testing)"""
	combat_results = outcome_data.duplicate()
	_complete_battle_phase()

func get_deployed_crew() -> Array[Dictionary]:
	"""Get crew members currently deployed"""
	return crew_deployed.duplicate()

func get_deployed_enemies() -> Array[Dictionary]:
	"""Get enemies currently deployed"""
	return enemies_deployed.duplicate()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
