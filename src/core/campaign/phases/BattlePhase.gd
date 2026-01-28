extends Node
class_name BattlePhase

## Battle Phase Implementation - Official Five Parsecs Rules
## Handles the complete Battle Phase sequence (Phase 3 of campaign turn)

# Safe imports
const EnemyGenerator = preload("res://src/core/systems/EnemyGenerator.gd")

# Safe dependency loading - loaded at runtime in _ready()
# GlobalEnums available as autoload singleton
var dice_manager: Variant = null
var game_state_manager: Variant = null
var enemy_generator: EnemyGenerator = null

## Battle Phase Signals
## Sprint 25.3: ready_for_battle signals async initialization complete (for tests/late subscribers)
## Note: This is NOT a phase lifecycle signal like battle_phase_started()
signal ready_for_battle()
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
var _initialization_complete: bool = false  # True after _initialize_autoloads completes

## Battle configuration
var max_rounds: int = 8 # Standard Five Parsecs battle length
var initiative_roll: int = 0
var crew_deployed: Array[Dictionary] = []
var enemies_deployed: Array[Dictionary] = []

## Sprint 11.1: BattleRoundTracker for actual combat rounds (Five Parsecs p.118)
var round_tracker: Node = null  # BattleRoundTracker instance
var use_tactical_combat: bool = false  # User choice: tactical vs auto-resolve (Sprint 11.2)

## Campaign reference - set by CampaignPhaseManager
var _campaign: Variant = null

## Set the campaign reference for this phase handler
func set_campaign(campaign: Variant) -> void:
	"""Receive campaign reference from CampaignPhaseManager."""
	_campaign = campaign
	print("BattlePhase: Campaign reference set")

## SPRINT 7.1: Consistent access pattern for campaign configuration
## Source of truth: Campaign resource (difficulty, house_rules, victory_conditions, story_track)
func _get_campaign_config(key: String, default_value: Variant = null) -> Variant:
	if _campaign:
		match key:
			"difficulty":
				if _campaign.has_method("get") and _campaign.get("difficulty") != null:
					return _campaign.difficulty
				elif "difficulty" in _campaign:
					return _campaign.difficulty
			"house_rules":
				if _campaign.has_method("get_house_rules"):
					return _campaign.get_house_rules()
				elif "house_rules" in _campaign:
					return _campaign.house_rules
			"victory_conditions":
				if _campaign.has_method("get_victory_conditions"):
					return _campaign.get_victory_conditions()
				elif "victory_conditions" in _campaign:
					return _campaign.victory_conditions
			"story_track_enabled":
				if _campaign.has_method("get_story_track_enabled"):
					return _campaign.get_story_track_enabled()
				elif "story_track_enabled" in _campaign:
					return _campaign.story_track_enabled
	# Fallback to GameStateManager
	if game_state_manager:
		match key:
			"difficulty":
				if game_state_manager.has_method("get_difficulty_level"):
					return game_state_manager.get_difficulty_level()
			"house_rules":
				if game_state_manager.has_method("get_house_rules"):
					return game_state_manager.get_house_rules()
			"victory_conditions":
				if game_state_manager.has_method("get_victory_conditions"):
					return game_state_manager.get_victory_conditions()
			"story_track_enabled":
				if game_state_manager.has_method("get_story_track_enabled"):
					return game_state_manager.get_story_track_enabled()
	return default_value

## SPRINT 7.1: Consistent access pattern for runtime state
## Source of truth: GameStateManager (credits, turn_number, current_location, etc.)
func _get_runtime_state(key: String, default_value: Variant = null) -> Variant:
	if game_state_manager:
		match key:
			"credits":
				if game_state_manager.has_method("get_credits"):
					return game_state_manager.get_credits()
			"turn_number":
				if "turn_number" in game_state_manager:
					return game_state_manager.turn_number
			"current_location":
				if game_state_manager.has_method("get_current_location"):
					return game_state_manager.get_current_location()
			"story_points":
				if game_state_manager.has_method("get_story_points"):
					return game_state_manager.get_story_points()
			"crew_size":
				if game_state_manager.has_method("get_crew_size"):
					return game_state_manager.get_crew_size()
	return default_value

func _ready() -> void:
	# Initialize enum values after loading GlobalEnums
	# Sprint 24.2: Use BattleCampaignSubStep for campaign turn tracking
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.NONE

	# Initialize EnemyGenerator for proper Core Rules enemy count formula
	enemy_generator = EnemyGenerator.new()

	# Sprint 11.1: Initialize BattleRoundTracker for actual combat
	_initialize_round_tracker()

	# Defer autoload access to avoid loading order issues
	call_deferred("_initialize_autoloads")
	print("BattlePhase: Initialized successfully")

## Sprint 11.1: Initialize BattleRoundTracker
func _initialize_round_tracker() -> void:
	"""Initialize the battle round tracking system"""
	var BattleRoundTracker = load("res://src/core/battle/BattleRoundTracker.gd")
	if BattleRoundTracker:
		round_tracker = BattleRoundTracker.new()
		add_child(round_tracker)
		_connect_round_tracker_signals()
		print("BattlePhase: BattleRoundTracker initialized")
	else:
		push_error("BattlePhase: Failed to load BattleRoundTracker")

func _connect_round_tracker_signals() -> void:
	"""Connect BattleRoundTracker signals for combat flow"""
	if not round_tracker:
		return

	if round_tracker.has_signal("phase_changed"):
		round_tracker.phase_changed.connect(_on_battle_round_phase_changed)
	if round_tracker.has_signal("round_changed"):
		round_tracker.round_changed.connect(_on_battle_round_changed)
	if round_tracker.has_signal("round_started"):
		round_tracker.round_started.connect(_on_battle_round_started)
	if round_tracker.has_signal("round_ended"):
		round_tracker.round_ended.connect(_on_battle_round_ended)
	if round_tracker.has_signal("battle_event_triggered"):
		round_tracker.battle_event_triggered.connect(_on_battle_event_triggered)
	if round_tracker.has_signal("battle_started"):
		round_tracker.battle_started.connect(_on_battle_tracker_started)
	if round_tracker.has_signal("battle_ended"):
		round_tracker.battle_ended.connect(_on_battle_tracker_ended)

	print("BattlePhase: Round tracker signals connected")

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

	# Mark initialization complete and emit ready signal (success or failure)
	_initialization_complete = true
	ready_for_battle.emit()

## Main Battle Phase Processing
func start_battle_phase(mission_data: Dictionary = {}) -> void:
	"""Begin the Battle Phase sequence"""
	print("BattlePhase: Starting Battle Phase")
	battle_setup_data = mission_data.duplicate()
	battle_in_progress = true
	current_round = 0

	# Sprint 26.4: Debug logging for data handoff verification
	_debug_log_battle_setup(mission_data)

	battle_phase_started.emit()

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Step 1: Battle Setup
	await _process_battle_setup()

func _process_battle_setup() -> void:
	"""Step 1: Battle Setup - Determine mission, enemies, terrain"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.SETUP
		battle_substep_changed.emit(current_substep)

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
	battle_setup_completed.emit(battle_setup_data)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Continue to deployment
	await _process_deployment()

func _generate_mission_type() -> int:
	"""Generate random mission type"""
	if GlobalEnums:
		# Standard patrol mission (most common)
		return GlobalEnums.MissionType.PATROL
	return 0

func _determine_enemy_count() -> int:
	"""Determine number of enemies based on Core Rules (p.63)

	Crew Size Rules:
	- Size 6: Roll 2D6, pick HIGHER result
	- Size 5: Roll 1D6
	- Size 4: Roll 2D6, pick LOWER result

	This uses EnemyGenerator._calculate_enemy_count() for consistency.
	"""
	var crew_size = 6 # Default to 6 (standard crew)
	var difficulty = 2 # Default to NORMAL difficulty

	if game_state_manager:
		if game_state_manager.has_method("get_crew_size"):
			crew_size = game_state_manager.get_crew_size()
		if game_state_manager.has_method("get_difficulty"):
			difficulty = game_state_manager.get_difficulty()

	# Use EnemyGenerator's Core Rules-compliant formula
	if enemy_generator:
		return enemy_generator._calculate_enemy_count(difficulty, crew_size)

	# Fallback: Implement Core Rules formula inline
	var base_count: int = 0
	match crew_size:
		6:
			# Roll 2D6, pick higher
			var roll1 = randi_range(1, 6)
			var roll2 = randi_range(1, 6)
			base_count = max(roll1, roll2)
		5:
			# Roll 1D6
			base_count = randi_range(1, 6)
		4:
			# Roll 2D6, pick lower
			var roll1 = randi_range(1, 6)
			var roll2 = randi_range(1, 6)
			base_count = min(roll1, roll2)
		_:
			# Default to crew size 6 behavior
			var roll1 = randi_range(1, 6)
			var roll2 = randi_range(1, 6)
			base_count = max(roll1, roll2)

	return max(1, base_count)

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
		current_substep = GlobalEnums.BattleCampaignSubStep.DEPLOYMENT
		battle_substep_changed.emit(current_substep)

	# Get crew members for battle
	crew_deployed = _get_deployed_crew()
	enemies_deployed = battle_setup_data.get("enemy_types", [])

	# SPRINT 26.23: Validate crew deployed before proceeding
	if crew_deployed.is_empty():
		push_warning("BattlePhase: No crew members available for deployment!")

	deployment_data = {
		"crew_positions": _generate_deployment_positions(crew_deployed.size(), "crew"),
		"enemy_positions": _generate_deployment_positions(enemies_deployed.size(), "enemy"),
		"deployment_type": "standard"
	}

	# Sprint 26.5: Gather debug data before emitting signals
	var crew_names: Array = []
	for member in crew_deployed:
		crew_names.append(member.get("character_name", member.get("name", "Unknown")))
	var enemy_type_names: Array = []
	for enemy in enemies_deployed:
		enemy_type_names.append(enemy.get("type", "Unknown"))
	_debug_log_deployment(crew_deployed.size(), enemies_deployed.size(), "standard", crew_names, enemy_type_names)

	print("BattlePhase: Deployment completed - Crew: %d, Enemies: %d" % [crew_deployed.size(), enemies_deployed.size()])
	deployment_completed.emit(deployment_data)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Continue to initiative
	await _process_initiative()

func _get_deployed_crew() -> Array[Dictionary]:
	"""Get crew members deployed to battle (B-3 fix: normalized to Dictionary format)
	SPRINT 26.23: Added null safety for get_crew_members() return"""
	var crew: Array[Dictionary] = []

	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		var all_crew = game_state_manager.get_crew_members()
		# SPRINT 26.23: Null check for get_crew_members() return
		if all_crew == null:
			push_warning("BattlePhase: get_crew_members() returned null")
			all_crew = []
		# Filter to only healthy crew members and normalize to Dictionary
		for member in all_crew:
			var member_dict: Dictionary = _normalize_crew_member_to_dict(member)
			if member_dict.get("status", 0) == 0: # HEALTHY status
				crew.append(member_dict)

	# Fallback: Generate default crew for testing when no game_state_manager
	if crew.is_empty():
		crew = _generate_default_crew()

	return crew

func _normalize_crew_member_to_dict(member: Variant) -> Dictionary:
	"""B-3 fix: Convert crew member to Dictionary format regardless of source type

	Handles:
	- Dictionary: Returns as-is
	- Character Resource: Calls to_dictionary() if available, or extracts properties
	- Other types: Creates minimal dictionary with available data

	Sprint 26.3: Character-Everywhere - crew members are always Character objects
	"""
	# Try Character-first (Sprint 26.3 standard)
	if member is Character and member.has_method("to_dictionary"):
		var char_dict = member.to_dictionary()
		# Sprint 27.4: Enrich with EquipmentManager equipment (source of truth)
		var char_id = char_dict.get("character_id", char_dict.get("id", ""))
		var equipment_manager_node = get_node_or_null("/root/EquipmentManager")
		if equipment_manager_node and equipment_manager_node.has_method("get_character_equipment") and not char_id.is_empty():
			var equipment_from_manager = equipment_manager_node.get_character_equipment(char_id)
			if not equipment_from_manager.is_empty():
				char_dict["equipment"] = equipment_from_manager
		return char_dict

	if member is Dictionary:
		# Sprint 27.4: Also enrich Dictionary members with EquipmentManager equipment
		var char_id = member.get("character_id", member.get("id", ""))
		if not char_id.is_empty():
			var equipment_manager_node = get_node_or_null("/root/EquipmentManager")
			if equipment_manager_node and equipment_manager_node.has_method("get_character_equipment"):
				var equipment_from_manager = equipment_manager_node.get_character_equipment(char_id)
				if not equipment_from_manager.is_empty():
					var result = member.duplicate()
					result["equipment"] = equipment_from_manager
					return result
		return member

	# Handle Resource types (Character, etc.)
	if member is Resource:
		# Try to_dict() method first (standard serialization)
		if member.has_method("to_dict"):
			return member.to_dict()

		# Fallback: Extract common properties manually
		var dict: Dictionary = {}

		# Standard Character properties
		if "id" in member:
			dict["id"] = member.id
		if "character_id" in member:
			dict["character_id"] = member.character_id
		if "name" in member:
			dict["name"] = member.name
		if "character_name" in member:
			dict["character_name"] = member.character_name
		if "status" in member:
			dict["status"] = member.status
		if "combat_skill" in member:
			dict["combat_skill"] = member.combat_skill
		if "toughness" in member:
			dict["toughness"] = member.toughness
		if "speed" in member:
			dict["speed"] = member.speed
		if "reactions" in member:
			dict["reactions"] = member.reactions
		if "savvy" in member:
			dict["savvy"] = member.savvy
		if "luck" in member:
			dict["luck"] = member.luck

		# Equipment data (critical for combat calculations)
		# Sprint 27.4: Query EquipmentManager for assigned equipment (source of truth)
		var char_id = dict.get("character_id", dict.get("id", ""))
		if char_id.is_empty() and "character_id" in member:
			char_id = member.character_id
		elif char_id.is_empty() and "id" in member:
			char_id = member.id

		# Try EquipmentManager first (authoritative for equipment assignments)
		var equipment_from_manager: Array = []
		var equipment_manager_node = get_node_or_null("/root/EquipmentManager")
		if equipment_manager_node and equipment_manager_node.has_method("get_character_equipment") and not char_id.is_empty():
			equipment_from_manager = equipment_manager_node.get_character_equipment(char_id)

		# Use EquipmentManager data if available, otherwise fall back to character property
		if not equipment_from_manager.is_empty():
			dict["equipment"] = equipment_from_manager
		elif "equipment" in member:
			dict["equipment"] = member.equipment

		if "weapons" in member:
			dict["weapons"] = member.weapons
		if "armor" in member:
			dict["armor"] = member.armor
		if "gear" in member:
			dict["gear"] = member.gear
		if "equipped_weapon" in member:
			dict["equipped_weapon"] = member.equipped_weapon
		if "equipped_armor" in member:
			dict["equipped_armor"] = member.equipped_armor

		# Generate ID if missing
		if dict.is_empty() or (not dict.has("id") and not dict.has("character_id")):
			dict["id"] = "crew_" + str(Time.get_ticks_msec())

		return dict

	# Unknown type - create minimal dictionary
	print("BattlePhase: ⚠️ Unknown crew member type: %s" % typeof(member))
	return {"id": "unknown_" + str(Time.get_ticks_msec()), "status": 0}

func _generate_default_crew() -> Array[Dictionary]:
	"""Generate default crew for testing when GameStateManager unavailable"""
	var default_crew: Array[Dictionary] = []
	for i in range(4):  # Default 4 crew members
		default_crew.append({
			"id": "crew_%d" % i,
			"character_name": "Test Crew %d" % (i + 1),
			"status": 0
		})
	return default_crew

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
		current_substep = GlobalEnums.BattleCampaignSubStep.COMBAT
		battle_substep_changed.emit(current_substep)

	# Roll initiative (1D6, 4+ crew goes first)
	initiative_roll = randi_range(1, 6)
	var crew_first = initiative_roll >= 4

	print("BattlePhase: Initiative roll: %d - %s goes first" % [initiative_roll, "Crew" if crew_first else "Enemy"])
	initiative_determined.emit(initiative_roll)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Start combat rounds
	await _process_combat_rounds()

func _process_combat_rounds() -> void:
	"""Step 4: Combat Rounds - Execute battle
	Sprint 11.3: Now supports both tactical and auto-resolve modes
	"""
	# Note: current_substep already set to COMBAT in _process_initiative()
	# Re-emitting for any late subscribers
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.COMBAT
		battle_substep_changed.emit(current_substep)

	print("BattlePhase: Beginning combat rounds (max %d rounds)" % max_rounds)

	# Sprint 11.2: Request battle mode selection from user
	request_battle_mode_selection()

	# BP-1: Wait for user choice with timeout fallback to auto-resolve
	var timeout_seconds: float = 30.0
	var mode_selected: bool = false

	# Create a timeout timer
	var timeout_timer := get_tree().create_timer(timeout_seconds)

	# Wait for either signal or timeout
	var result = await _await_battle_mode_with_timeout(timeout_timer)
	if result == "timeout":
		push_warning("BattlePhase: Battle mode selection timed out after %d seconds - defaulting to auto-resolve" % int(timeout_seconds))
		use_tactical_combat = false
	# else: signal received, use_tactical_combat was set by set_battle_mode()

	if use_tactical_combat:
		# Sprint 11.3: Execute turn-by-turn tactical combat using BattleRoundTracker
		print("BattlePhase: Starting tactical combat mode")
		await _execute_tactical_combat()
	else:
		# Use quick auto-resolve (existing simulation)
		print("BattlePhase: Starting auto-resolve mode")
		await _simulate_battle_outcome()

## Sprint 11.3: Tactical Combat Execution
func _execute_tactical_combat() -> void:
	"""Execute turn-by-turn tactical combat using BattleRoundTracker"""
	if not round_tracker:
		push_warning("BattlePhase: No round tracker - falling back to simulation")
		await _simulate_battle_outcome()
		return

	# Sprint 11.4: Wire TacticalBattleUI to round tracker before starting combat
	_wire_tactical_battle_ui()

	# Start the battle in round tracker
	round_tracker.start_battle()

	# Sprint 26.5: Debug log tactical combat mode
	var crew_strength = crew_deployed.size() * 5
	var enemy_strength = enemies_deployed.size() * 4
	var crew_first = initiative_roll >= 4
	_debug_log_combat_mode(true, max_rounds, initiative_roll, crew_first, crew_strength, enemy_strength)

	# Combat continues until victory/defeat or max rounds
	var battle_active := true
	while battle_active and round_tracker.get_current_round() <= max_rounds:
		# Wait for round completion (UI drives advance_phase calls through round tracker)
		# This allows the tactical UI to control combat flow
		await round_tracker.round_ended

		# Check victory/defeat conditions after each round
		var result = _check_battle_result()
		if result != BattleResult.ONGOING:
			battle_active = false
			break

	# End the battle in round tracker
	round_tracker.end_battle()

	# Generate final results
	await _finalize_tactical_battle_results()

enum BattleResult { ONGOING, VICTORY, DEFEAT, RETREAT }

func _check_battle_result() -> int:
	"""Check if battle has ended with victory, defeat, or ongoing"""
	# Count surviving crew and enemies
	var crew_alive := 0
	var enemies_alive := 0

	for crew in crew_deployed:
		if crew.get("status", 0) == 0:  # HEALTHY
			crew_alive += 1

	for enemy in enemies_deployed:
		if not enemy.get("defeated", false):
			enemies_alive += 1

	if enemies_alive == 0:
		return BattleResult.VICTORY
	if crew_alive == 0:
		return BattleResult.DEFEAT

	return BattleResult.ONGOING

func _finalize_tactical_battle_results() -> void:
	"""Finalize results after tactical combat completion"""
	# Calculate final battle statistics
	var crew_casualties := 0
	var enemies_defeated := 0

	for crew in crew_deployed:
		if crew.get("status", 0) != 0:  # Not HEALTHY
			crew_casualties += 1

	for enemy in enemies_deployed:
		if enemy.get("defeated", false):
			enemies_defeated += 1

	var success = enemies_defeated >= enemies_deployed.size() / 2  # Victory if half defeated

	# Build crew_participants list
	var crew_participants: Array[Dictionary] = []
	for crew_member in crew_deployed:
		var participant = crew_member.duplicate()
		participant["participated"] = true
		participant["survived"] = crew_member.get("status", 0) == 0
		crew_participants.append(participant)

	# Build defeated_enemy_list
	var defeated_enemy_list: Array[Dictionary] = []
	for enemy in enemies_deployed:
		if enemy.get("defeated", false):
			defeated_enemy_list.append(enemy.duplicate())

	# Build injuries list and casualties array (Task 14.3)
	var injuries_sustained: Array[Dictionary] = []
	var casualties: Array[Dictionary] = []  # Fatal casualties for PostBattle tracking
	for i in range(crew_participants.size()):
		if not crew_participants[i].get("survived", true):
			var crew_id = crew_participants[i].get("id", crew_participants[i].get("character_id", "unknown_%d" % i))
			injuries_sustained.append({
				"crew_id": crew_id,
				"crew_index": i,
				"type": "injury",
				"source": "tactical_combat"
			})
			# Task 14.3: Add to casualties array
			casualties.append({
				"crew_id": crew_id,
				"type": "killed",  # Default type; PostBattle injury roll may change
				"round": round_tracker.get_current_round() if round_tracker else current_round,
				"cause": "tactical_combat"
			})

	# Calculate rewards
	var base_payment = battle_setup_data.get("base_payment", 100)
	var difficulty_bonus = battle_setup_data.get("difficulty", 2) * 25
	var success_bonus = 50 if success else 0
	var payment = base_payment + difficulty_bonus + success_bonus

	combat_results = {
		"success": success,
		"victory": success,
		"rounds_fought": round_tracker.get_current_round() if round_tracker else current_round,
		"crew_casualties": crew_casualties,
		"enemies_defeated": enemies_defeated,
		"crew_participants": crew_participants,
		"defeated_enemy_list": defeated_enemy_list,
		"loot_opportunities": enemies_defeated,
		"battlefield_finds": randi_range(0, 2),
		"payment": payment,
		"credits_earned": payment,
		"xp_per_participant": 1,
		"xp_victory_bonus": 2 if success else 0,
		"injured_crew": [],
		"injuries_sustained": injuries_sustained,
		"casualties": casualties,  # Task 14.3: Fatal casualties [{crew_id, type, round, cause}]
		"mission_type": battle_setup_data.get("mission_type", 0),
		"mission_id": battle_setup_data.get("mission_id", ""),
		"combat_mode": "tactical"
	}

	print("BattlePhase: Tactical combat concluded - Victory: %s, Rounds: %d, Enemies Defeated: %d" % [
		str(success), combat_results.rounds_fought, enemies_defeated
	])

	await _complete_battle_phase()

func _simulate_battle_outcome() -> void:
	"""Simulate battle outcome (placeholder for full tactical combat)"""
	# Determine battle outcome
	var crew_strength = crew_deployed.size() * 5 # Simplified
	var enemy_strength = enemies_deployed.size() * 4 # Simplified

	# Sprint 26.5: Debug log combat mode BEFORE resolution
	var crew_first = initiative_roll >= 4
	_debug_log_combat_mode(false, max_rounds, initiative_roll, crew_first, crew_strength, enemy_strength)

	var victory_roll = randi_range(1, 6)
	var success = (crew_strength + victory_roll) > enemy_strength

	# Calculate casualties
	var crew_casualties_count = 0 if success else randi_range(0, 2)
	var enemies_defeated_count = enemies_deployed.size() if success else randi_range(1, 3)

	# Build crew_participants list (who actually fought)
	var crew_participants: Array[Dictionary] = []
	for crew_member in crew_deployed:
		var participant = crew_member.duplicate()
		participant["participated"] = true
		participant["survived"] = true # Will be set to false for casualties
		crew_participants.append(participant)

	# Mark casualties and build injury data for PostBattle
	var casualty_indices = []
	var injuries_sustained: Array[Dictionary] = []
	var casualties: Array[Dictionary] = []  # Task 14.3: Fatal casualties array
	for i in range(min(crew_casualties_count, crew_participants.size())):
		var idx = randi() % crew_participants.size()
		while idx in casualty_indices:
			idx = randi() % crew_participants.size()
		casualty_indices.append(idx)
		crew_participants[idx]["survived"] = false

		# Build injury record for PostBattlePhase (P-1 fix)
		var crew_id = crew_participants[idx].get("id", crew_participants[idx].get("character_id", "unknown_%d" % idx))
		injuries_sustained.append({
			"crew_id": crew_id,
			"crew_index": idx,
			"type": "injury",  # PostBattle will roll on injury table
			"source": "battle_casualty"
		})

		# Task 14.3: Add to casualties array for PostBattle tracking
		# Note: These are initially marked as casualties; PostBattle will determine final fate
		casualties.append({
			"crew_id": crew_id,
			"type": "killed",  # Default to killed; PostBattle injury roll may change this
			"round": randi_range(1, 5),  # Simulated round when casualty occurred
			"cause": "combat"
		})

	# Build defeated_enemy_list with actual enemy data
	var defeated_enemy_list: Array[Dictionary] = []
	for i in range(min(enemies_defeated_count, enemies_deployed.size())):
		var enemy = enemies_deployed[i].duplicate() if i < enemies_deployed.size() else {}
		enemy["defeated"] = true
		defeated_enemy_list.append(enemy)

	# Calculate payment based on mission type and difficulty
	var base_payment = battle_setup_data.get("base_payment", 100)
	var difficulty_bonus = battle_setup_data.get("difficulty", 2) * 25
	var success_bonus = 50 if success else 0
	var payment = base_payment + difficulty_bonus + success_bonus

	combat_results = {
		# Victory status
		"success": success,
		"victory": success, # Alias for compatibility

		# Battle statistics
		"rounds_fought": randi_range(3, 6),
		"crew_casualties": crew_casualties_count,
		"enemies_defeated": enemies_defeated_count,

		# Detailed participant data (CRITICAL for PostBattle phase)
		"crew_participants": crew_participants,
		"defeated_enemy_list": defeated_enemy_list,

		# Loot and rewards (Core Rules p.85-87)
		"loot_opportunities": enemies_defeated_count,
		"battlefield_finds": randi_range(0, 2),
		"payment": payment,
		"credits_earned": payment,

		# XP tracking
		"xp_per_participant": 1,
		"xp_victory_bonus": 2 if success else 0,

		# Injury data (P-1 fix: Full injury records for PostBattle)
		"injured_crew": casualty_indices,
		"injuries_sustained": injuries_sustained,  # Array[Dictionary] with crew_id and type
		"casualties": casualties,  # Task 14.3: Fatal casualties [{crew_id, type, round, cause}]

		# Mission reference
		"mission_type": battle_setup_data.get("mission_type", 0),
		"mission_id": battle_setup_data.get("mission_id", "")
	}

	print("BattlePhase: Battle concluded - Victory: %s, Enemies: %d, Casualties: %d, Payment: %d" % [
		str(success), enemies_defeated_count, crew_casualties_count, payment
	])

	# Complete battle phase
	await _complete_battle_phase()

func _complete_battle_phase() -> void:
	"""Complete the Battle Phase"""
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.RESOLUTION
		battle_substep_changed.emit(current_substep)

	battle_in_progress = false

	# Sprint 26.5: Debug log battle resolution with all results
	_debug_log_battle_resolution(combat_results)

	print("BattlePhase: Battle Phase completed")
	battle_results_ready.emit(combat_results)

	# Allow signal to be processed before emitting completion
	await _safe_await_frame()

	battle_phase_completed.emit()

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

func is_combat_started() -> bool:
	"""Sprint 10.2: Check if actual combat has started (prevents rollback after combat begins)

	Returns true if:
	- Battle is in progress AND
	- We've moved past deployment (INITIATIVE or later substeps)

	This allows back navigation during SETUP/DEPLOYMENT but not once combat begins.
	"""
	if not battle_in_progress:
		return false

	# Check if we're past the deployment phase (combat has truly started)
	if GlobalEnums:
		# Combat starts at COMBAT substep (when initiative is determined and rounds begin)
		return current_substep >= GlobalEnums.BattleCampaignSubStep.COMBAT

	# Fallback: If any combat round has completed, combat has started
	return current_round > 0

## Sprint 11.1: BattleRoundTracker Signal Handlers
func _on_battle_round_phase_changed(phase: int, phase_name: String) -> void:
	"""Handle combat round phase changes (Reaction → Quick → Enemy → Slow → End)"""
	print("BattlePhase: Round phase changed to %s (%d)" % [phase_name, phase])
	# Could emit signal for UI update here

func _on_battle_round_changed(new_round: int) -> void:
	"""Handle round number changes"""
	current_round = new_round
	print("BattlePhase: Now on round %d" % new_round)
	combat_round_started.emit(new_round)

func _on_battle_round_started(round_number: int) -> void:
	"""Handle start of new round"""
	print("BattlePhase: Round %d started" % round_number)

func _on_battle_round_ended(round_number: int) -> void:
	"""Handle end of round"""
	print("BattlePhase: Round %d ended" % round_number)
	combat_round_completed.emit(round_number)

func _on_battle_event_triggered(round_num: int, event_type: String) -> void:
	"""Handle battle events (rounds 2 and 4 per Five Parsecs rules)"""
	print("BattlePhase: Battle event triggered on round %d - type: %s" % [round_num, event_type])
	# TODO: Roll on battle events table and apply effects

func _on_battle_tracker_started() -> void:
	"""Handle BattleRoundTracker battle start signal"""
	print("BattlePhase: Battle tracker started - tactical combat active")

func _on_battle_tracker_ended() -> void:
	"""Handle BattleRoundTracker battle end signal"""
	print("BattlePhase: Battle tracker ended - tactical combat complete")

## Sprint 11.2: Battle Mode Selection
signal battle_mode_selection_requested(crew_count: int, enemy_count: int)
signal battle_mode_selected(use_tactical: bool)

func request_battle_mode_selection() -> void:
	"""Request user to choose between tactical and auto-resolve modes"""
	print("BattlePhase: Requesting battle mode selection")
	battle_mode_selection_requested.emit(crew_deployed.size(), enemies_deployed.size())

func set_battle_mode(tactical: bool) -> void:
	"""Set the battle mode choice (tactical or auto-resolve)"""
	use_tactical_combat = tactical
	print("BattlePhase: Battle mode set to %s" % ("Tactical" if tactical else "Auto-Resolve"))
	battle_mode_selected.emit(tactical)

## BP-1: Helper to await battle mode with timeout fallback
func _await_battle_mode_with_timeout(timeout_timer: SceneTreeTimer) -> String:
	"""Wait for battle_mode_selected signal OR timeout, whichever comes first.
	Returns 'signal' if mode was selected, 'timeout' if timed out."""
	var signal_received: bool = false
	var timed_out: bool = false

	# Connect to both possible events
	var mode_callback := func(_tactical: bool): signal_received = true
	battle_mode_selected.connect(mode_callback, CONNECT_ONE_SHOT)

	var timeout_callback := func(): timed_out = true
	timeout_timer.timeout.connect(timeout_callback, CONNECT_ONE_SHOT)

	# Poll until one of them fires
	while not signal_received and not timed_out:
		await get_tree().process_frame

	# Disconnect any remaining connection
	if battle_mode_selected.is_connected(mode_callback):
		battle_mode_selected.disconnect(mode_callback)

	return "signal" if signal_received else "timeout"

## Sprint 11.4: Wire TacticalBattleUI to round tracker
func _wire_tactical_battle_ui() -> void:
	"""Find and configure TacticalBattleUI with round tracker for phase-based combat"""
	if not round_tracker:
		push_warning("BattlePhase: Cannot wire TacticalBattleUI - no round tracker")
		return

	# Try to find TacticalBattleUI in the scene tree
	var tactical_ui: Node = null

	# Check common locations
	var paths_to_check = [
		"/root/TacticalBattleUI",
		"/root/BattleScreen/TacticalBattleUI",
		"/root/Main/BattleScreen/TacticalBattleUI"
	]

	for path in paths_to_check:
		tactical_ui = get_node_or_null(path)
		if tactical_ui:
			break

	# Fallback: Search for TacticalBattleUI by class name
	if not tactical_ui:
		tactical_ui = _find_node_by_class("FPCM_TacticalBattleUI")

	if tactical_ui:
		# Connect round tracker to TacticalBattleUI
		if tactical_ui.has_method("set_round_tracker"):
			tactical_ui.set_round_tracker(round_tracker)
			print("BattlePhase: ✅ TacticalBattleUI wired to round tracker")

		# Initialize battle with current crew and enemies
		if tactical_ui.has_method("initialize_battle"):
			tactical_ui.initialize_battle(crew_deployed, enemies_deployed, battle_setup_data)
			print("BattlePhase: ✅ TacticalBattleUI initialized with battle data")
	else:
		push_warning("BattlePhase: TacticalBattleUI not found in scene tree")

func _find_node_by_class(class_name_str: String) -> Node:
	"""Find a node by its class_name in the scene tree"""
	if not is_inside_tree():
		return null

	var root = get_tree().root
	return _recursive_find_by_class(root, class_name_str)

func _recursive_find_by_class(node: Node, class_name_str: String) -> Node:
	"""Recursively search for a node with matching class_name"""
	if node.get_class() == class_name_str:
		return node

	# Check script class name
	var script = node.get_script()
	if script:
		var script_class = script.get_global_name() if script.has_method("get_global_name") else ""
		if script_class == class_name_str:
			return node

	# Check children
	for child in node.get_children():
		var found = _recursive_find_by_class(child, class_name_str)
		if found:
			return found

	return null

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

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Substep-Level Debug Output
## ═══════════════════════════════════════════════════════════════════════════════

func _debug_log_battle_setup(mission_data: Dictionary) -> void:
	"""Log battle setup data for debugging handoff from World Phase"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ BATTLE SUBSTEP: SETUP                                       │")
	print("├─────────────────────────────────────────────────────────────┤")

	# Mission data
	print("  MISSION DATA:")
	print("    Keys: %s" % str(mission_data.keys()))
	print("    Mission Type: %s" % str(mission_data.get("mission_type", mission_data.get("type", "MISSING"))))
	print("    Mission ID: %s" % str(mission_data.get("mission_id", mission_data.get("id", "MISSING"))))
	print("    Difficulty: %s" % str(mission_data.get("difficulty", "MISSING")))

	# Enemy data from mission
	print("  ENEMY DATA (from mission):")
	print("    Enemy Count: %s" % str(mission_data.get("enemy_count", "MISSING")))
	print("    Enemy Type: %s" % str(mission_data.get("enemy_type", mission_data.get("enemy_faction", "MISSING"))))
	print("    Deployment: %s" % str(mission_data.get("deployment", "MISSING")))

	# Check crew availability
	print("  CREW AVAILABILITY:")
	if _campaign:
		var crew: Array = []
		if _campaign.has_method("get_crew_members"):
			crew = _campaign.get_crew_members()
		elif "crew_members" in _campaign:
			crew = _campaign.crew_members

		print("    Total Crew: %d members" % crew.size())

		# Count healthy crew (available for battle)
		var healthy_count: int = 0
		var injured_names: Array = []
		for member in crew:
			var recovery_turns: int = 0
			var member_name: String = "Unknown"

			if member is Dictionary:
				recovery_turns = member.get("recovery_turns", 0)
				member_name = member.get("character_name", member.get("name", "Unknown"))
			elif member != null:
				if "recovery_turns" in member:
					recovery_turns = member.recovery_turns
				if "character_name" in member:
					member_name = member.character_name
				elif "name" in member:
					member_name = member.name

			if recovery_turns == 0:
				healthy_count += 1
			else:
				injured_names.append("%s (%d turns)" % [member_name, recovery_turns])

		print("    Healthy (deployable): %d members" % healthy_count)
		if not injured_names.is_empty():
			print("    Injured: %s" % str(injured_names))
	elif game_state_manager and game_state_manager.has_method("get_crew_members"):
		var crew = game_state_manager.get_crew_members()
		print("    Total Crew: %d members (from GameStateManager)" % crew.size())
	else:
		print("    ⚠️  NO CAMPAIGN OR GAME STATE - Cannot verify crew!")

	# Check battle configuration
	print("  BATTLE CONFIG:")
	print("    Max Rounds: %d" % max_rounds)
	print("    Tactical Mode: %s" % ("Yes" if use_tactical_combat else "No"))
	print("    Round Tracker: %s" % ("Available" if round_tracker else "MISSING"))

	print("└─────────────────────────────────────────────────────────────┘")


func _debug_log_deployment(crew_count: int, enemy_count: int, deployment_type: String, crew_names: Array, enemy_types: Array) -> void:
	"""Log deployment data for debugging"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ BATTLE SUBSTEP: DEPLOYMENT                                  │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ FORCES DEPLOYED:")
	print("│   Crew Members: %d" % crew_count)
	for i in range(min(crew_names.size(), 6)):  # Max 6 to avoid spam
		print("│     - %s" % str(crew_names[i]))
	if crew_names.size() > 6:
		print("│     ... and %d more" % (crew_names.size() - 6))
	print("│   Enemy Forces: %d" % enemy_count)
	for i in range(min(enemy_types.size(), 4)):  # Max 4 to avoid spam
		print("│     - %s" % str(enemy_types[i]))
	if enemy_types.size() > 4:
		print("│     ... and %d more" % (enemy_types.size() - 4))
	print("│ DEPLOYMENT TYPE: %s" % deployment_type)
	print("│ POSITIONS:")
	print("│   Crew Zone: Standard deployment (rows 0-2)")
	print("│   Enemy Zone: Standard deployment (rows 18-20)")
	print("└─────────────────────────────────────────────────────────────┘")


func _debug_log_combat_mode(is_tactical: bool, max_rounds_cfg: int, initiative_roll: int, crew_first: bool, crew_strength: int, enemy_strength: int) -> void:
	"""Log combat mode selection and initial state"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ BATTLE SUBSTEP: COMBAT                                      │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ COMBAT MODE: %s" % ("TACTICAL (Turn-by-Turn)" if is_tactical else "AUTO-RESOLVE (Quick)"))
	print("│ MAX ROUNDS: %d" % max_rounds_cfg)
	print("│ INITIATIVE:")
	print("│   Roll: %d" % initiative_roll)
	print("│   First Turn: %s" % ("CREW" if crew_first else "ENEMY"))
	print("│ FORCE STRENGTH (Simplified Calculation):")
	print("│   Crew Strength: %d (members × 5)" % crew_strength)
	print("│   Enemy Strength: %d (enemies × 4)" % enemy_strength)
	print("│   Advantage: %s" % ("CREW" if crew_strength > enemy_strength else ("ENEMY" if enemy_strength > crew_strength else "EVEN")))
	print("└─────────────────────────────────────────────────────────────┘")


func _debug_log_battle_resolution(results: Dictionary) -> void:
	"""Log battle resolution summary"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ BATTLE SUBSTEP: RESOLUTION                                  │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ OUTCOME: %s" % ("VICTORY!" if results.get("success", false) else "DEFEAT"))
	print("│ BATTLE STATISTICS:")
	print("│   Rounds Fought: %d" % results.get("rounds_fought", 0))
	print("│   Enemies Defeated: %d" % results.get("enemies_defeated", 0))
	print("│   Crew Casualties: %d" % results.get("crew_casualties", 0))
	print("│ REWARDS:")
	print("│   Payment: %d credits" % results.get("payment", 0))
	print("│   Loot Opportunities: %d rolls" % results.get("loot_opportunities", 0))
	print("│   Battlefield Finds: %d" % results.get("battlefield_finds", 0))
	print("│ XP AWARDS:")
	print("│   Base XP Per Participant: %d" % results.get("xp_per_participant", 1))
	print("│   Victory Bonus: %d" % results.get("xp_victory_bonus", 0))
	# List injured crew if any
	var injuries = results.get("injuries_sustained", [])
	if not injuries.is_empty():
		print("│ INJURIES TO PROCESS (PostBattle):")
		for injury in injuries:
			print("│   - Crew ID: %s, Type: %s" % [str(injury.get("crew_id", "?")), str(injury.get("type", "unknown"))])
	else:
		print("│ INJURIES: None (all crew healthy)")
	print("│ → Data passed to PostBattlePhase for processing")
	print("└─────────────────────────────────────────────────────────────┘")


## Safe await helper - handles case when node isn't in scene tree (testing)
## SPRINT 5 FIX: Return early if no tree to avoid null reference in await
func _safe_await_frame() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if tree == null:
		return
	await tree.process_frame

## Sprint 26.12: Consistent phase handoff interface
func get_completion_data() -> Dictionary:
	"""Get Battle Phase completion data for PostBattle Phase transition.

	Returns Dictionary with:
	- combat_results: Dictionary - Full combat results including victory, casualties, loot
	- victory: bool - Whether battle was won
	- crew_deployed: Array - Crew members that participated
	- enemies_deployed: Array - Enemies that were in battle
	- rounds_fought: int - Number of rounds the battle lasted
	"""
	var data = combat_results.duplicate(true) if combat_results else {}

	# Ensure essential fields are present
	if not data.has("victory"):
		data["victory"] = false
	if not data.has("rounds_fought"):
		data["rounds_fought"] = current_round
	if not data.has("crew_deployed"):
		data["crew_deployed"] = crew_deployed.duplicate()
	if not data.has("enemies_deployed"):
		data["enemies_deployed"] = enemies_deployed.duplicate()

	return data
