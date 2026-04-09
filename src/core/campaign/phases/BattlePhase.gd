extends Node
class_name BattlePhase

## DEPRECATED (Session 48c/50): This file is NOT used in the production battle flow.
## CampaignPhaseManager.battle_phase_handler is null — all battle mechanics run through
## CampaignTurnController._initiate_battle_sequence() → PreBattleUI → TacticalBattleUI.
## Kept for reference only. Safe to delete once all mechanics are verified in the live path.
##
## Original: Battle Phase Implementation - Official Five Parsecs Rules

# Safe imports
const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")
const EnemyGenerator = preload("res://src/core/systems/EnemyGenerator.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const ProgressiveDifficultyTrackerRef = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
const CompendiumNoMinisCombat = preload("res://src/data/compendium_no_minis.gd")
const CompendiumDeploymentVars = preload("res://src/data/compendium_deployment_variables.gd")
const CompendiumEscalation = preload("res://src/data/compendium_escalating_battles.gd")
const CompendiumStealthMissions = preload("res://src/data/compendium_stealth_missions.gd")
const CompendiumStreetFights = preload("res://src/data/compendium_street_fights.gd")
const CompendiumSalvageJobs = preload("res://src/data/compendium_salvage_jobs.gd")
const BattleResolverClass = preload("res://src/core/battle/BattleResolver.gd")
const RedZoneSystem = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystem = preload("res://src/core/mission/BlackZoneSystem.gd")
const SeizeInitiativeSystemClass = preload("res://src/core/battle/SeizeInitiativeSystem.gd")
const DeploymentConditionsSystemClass = preload("res://src/core/battle/DeploymentConditionsSystem.gd")
const MissionTableManagerClass = preload("res://src/core/mission/MissionTableManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
# GlobalEnums available as autoload singleton
var dice_manager: Variant = null
var game_state_manager: Variant = null
var enemy_generator: EnemyGenerator = null

# Unique Individual mechanics — loaded from data/unique_individual.json (Core Rules pp.64-65, 93-94)
static var _ui_mechanics: Dictionary = {}
static var _ui_mechanics_loaded: bool = false

static func _load_unique_individual_mechanics() -> void:
	if _ui_mechanics_loaded:
		return
	var file := FileAccess.open("res://data/unique_individual.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			_ui_mechanics = json.data
	if _ui_mechanics.is_empty():
		push_warning("BattlePhase: Failed to load unique_individual.json, using fallback values")
	_ui_mechanics_loaded = true

static func _get_ui_threshold() -> int:
	_load_unique_individual_mechanics()
	var base_roll: Dictionary = _ui_mechanics.get("presence_mechanics", {}).get("base_roll", {})
	return int(base_roll.get("threshold", 9))

static func _get_ui_interested_parties_modifier() -> int:
	_load_unique_individual_mechanics()
	var mods: Dictionary = _ui_mechanics.get("presence_mechanics", {}).get("modifiers", {})
	return int(mods.get("interested_parties", {}).get("value", 1))

static func _get_ui_double_threshold() -> int:
	_load_unique_individual_mechanics()
	var insanity: Dictionary = _ui_mechanics.get("presence_mechanics", {}).get("insanity_mode", {})
	var double_check: Dictionary = insanity.get("double_check", {})
	return int(double_check.get("threshold", 11))

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
var _initialization_complete: bool = false # True after _initialize_autoloads completes

## Battle configuration
var max_rounds: int = 8 # Standard Five Parsecs battle length
var initiative_roll: int = 0
var crew_deployed: Array[Dictionary] = []
var enemies_deployed: Array[Dictionary] = []

## Sprint 11.1: BattleRoundTracker for actual combat rounds (Five Parsecs p.118)
var round_tracker: Node = null # BattleRoundTracker instance
var use_tactical_combat: bool = false # User choice: tactical vs auto-resolve (Sprint 11.2)

## Core Rules systems (Session 48: wire existing systems into battle setup)
var seize_initiative_system: Resource = null # FPCM_SeizeInitiativeSystem
var deployment_conditions_system: Resource = null # FPCM_DeploymentConditionsSystem
var mission_table_manager: RefCounted = null # MissionTableManager

## Campaign reference - set by CampaignPhaseManager
var _campaign: Variant = null

## Set the campaign reference for this phase handler
func set_campaign(campaign: Variant) -> void:
	## Receive campaign reference from CampaignPhaseManager.
	_campaign = campaign

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

	# Session 48: Initialize Core Rules battle systems
	seize_initiative_system = SeizeInitiativeSystemClass.new()
	deployment_conditions_system = DeploymentConditionsSystemClass.new()
	mission_table_manager = MissionTableManagerClass.new()

	# Sprint 11.1: Initialize BattleRoundTracker for actual combat
	_initialize_round_tracker()

	# Defer autoload access to avoid loading order issues
	call_deferred("_initialize_autoloads")

## Sprint 11.1: Initialize BattleRoundTracker
func _initialize_round_tracker() -> void:
	## Initialize the battle round tracking system
	var BattleRoundTracker = load("res://src/core/battle/BattleRoundTracker.gd")
	if BattleRoundTracker:
		round_tracker = BattleRoundTracker.new()
		add_child(round_tracker)
		_connect_round_tracker_signals()
	else:
		push_error("BattlePhase: Failed to load BattleRoundTracker")

func _connect_round_tracker_signals() -> void:
	## Connect BattleRoundTracker signals for combat flow
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


func _initialize_autoloads() -> void:
	## Initialize autoloads with retry logic to handle loading order
	# Wait for DiceManager to be ready
	for i in range(10):
		dice_manager = get_node_or_null("/root/DiceManager")
		if dice_manager:
			break
		await get_tree().create_timer(0.1).timeout
	
	if not dice_manager:
		push_error("BattlePhase: DiceManager autoload not found after retries")
	
	# Wait for GameStateManager to be ready
	for i in range(10):
		game_state_manager = get_node_or_null("/root/GameStateManager")
		if game_state_manager:
			break
		await get_tree().create_timer(0.1).timeout
	
	if not game_state_manager:
		push_error("BattlePhase: GameStateManager not found after retries")
		# Try alternative access methods
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			if game_state_manager:
				pass
		else:
			pass

	# Mark initialization complete and emit ready signal (success or failure)
	_initialization_complete = true
	ready_for_battle.emit()

## Main Battle Phase Processing
func start_battle_phase(mission_data: Dictionary = {}) -> void:
	## Begin the Battle Phase sequence
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
	## Step 1: Battle Setup - Determine mission, enemies, terrain
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.SETUP
		battle_substep_changed.emit(current_substep)

	# Story Track override: inject story battle config
	if _is_story_event_battle():
		_apply_story_battle_config()

	# Get mission type from setup data or generate
	var mission_type = battle_setup_data.get(
		"mission_type", _generate_mission_type())

	# Session 48: Roll mission objective on D10 table (Core Rules pp.89-91)
	var mission_objective: Dictionary = battle_setup_data.get(
		"mission_objective", {})
	if mission_objective.is_empty():
		if battle_setup_data.get("is_rival_battle", false):
			# Rival battles use the Rival Attack Type table (Core Rules p.91)
			var rival_attack: Dictionary = _roll_rival_attack_type()
			battle_setup_data["rival_attack_type"] = rival_attack
			# Apply rival attack modifiers
			match rival_attack.get("type", "SHOWDOWN"):
				"AMBUSH":
					# Deploy one fewer crew, cannot Seize Initiative
					battle_setup_data["rival_ambush_crew_reduction"] = 1
					battle_setup_data["cannot_seize_initiative"] = true
				"BROUGHT_FRIENDS":
					# +1 additional enemy
					battle_setup_data["rival_extra_enemies"] = 1
				"ASSAULT":
					# +1 enemy, crew in/adjacent building
					battle_setup_data["rival_extra_enemies"] = 1
					battle_setup_data["rival_assault_building"] = true
				"RAID":
					# Ship hull damage if fail to Hold Field
					battle_setup_data["rival_raid_ship_risk"] = true
			print_verbose("BattlePhase: Rival Attack — %s" % rival_attack.get(
				"type", "SHOWDOWN"))
		else:
			mission_objective = _roll_mission_objective(mission_type)
			battle_setup_data["mission_objective"] = mission_objective
			# Defend objective: change enemy AI to Aggressive, +1 enemy
			if mission_objective.get("type", "") == "DEFEND":
				battle_setup_data["defend_ai_override"] = "aggressive"
				battle_setup_data["defend_extra_enemies"] = 1
			# Quest finale: +1 enemy (Core Rules p.89)
			if mission_objective.get("quest_finale", false):
				battle_setup_data["quest_finale_extra_enemies"] = 1
			print_verbose("BattlePhase: Objective — %s (%s)" % [
				mission_objective.get("name", "Unknown"),
				mission_objective.get("type", "?")])

	# DLC: Determine battle type (conventional/stealth/street_fight/salvage)
	# from Compendium p.118 mission selection table
	var battle_type: String = battle_setup_data.get("battle_type", "conventional")
	var mission_source: String = battle_setup_data.get("mission_source", "")
	if battle_type == "conventional" and not mission_source.is_empty():
		battle_type = CompendiumStealthMissions.roll_battle_type(mission_source)
	battle_setup_data["battle_type"] = battle_type

	# Check if this is a Red/Black Zone mission (Core Rules Appendix III)
	var is_red_zone: bool = battle_setup_data.get("is_red_zone", false)
	var is_black_zone: bool = battle_setup_data.get("is_black_zone", false)
	var red_zone_threat: Dictionary = {}
	var red_zone_time_constraint: Dictionary = {}
	var black_zone_mission: Dictionary = {}

	# Generate enemy forces (Red/Black Zone override standard count)
	var enemy_count: int
	if is_black_zone:
		# Black Zone: 4 teams of 4 from Roving Threats (initial wave only)
		var bz_opposition := BlackZoneSystem.get_opposition_rules()
		var team_size: int = bz_opposition.get("team_size", 4)
		var initial_teams: int = bz_opposition.get("initial_teams", 4)
		enemy_count = team_size * initial_teams
		black_zone_mission = BlackZoneSystem.roll_mission_type()
		print_verbose("BattlePhase: BLACK ZONE — %d enemies (%d teams of %d), Mission: %s" % [
			enemy_count, initial_teams, team_size, black_zone_mission.get("name", "Unknown")
		])
	elif is_red_zone:
		var opposition := RedZoneSystem.get_opposition_rules()
		enemy_count = opposition.get("base_enemy_count", 7)
		red_zone_threat = RedZoneSystem.roll_threat_condition()
		red_zone_time_constraint = RedZoneSystem.roll_time_constraint()
		# Heavy Opposition threat condition: +2 enemies
		if red_zone_threat.get("name", "") == "Heavy Opposition":
			enemy_count += 2
		print_verbose("BattlePhase: RED ZONE — %d enemies, Threat: %s, Time: %s" % [
			enemy_count, red_zone_threat.get("name", "None"), red_zone_time_constraint.get("name", "None")
		])
	else:
		enemy_count = _determine_enemy_count()

	# Session 48: Apply extra enemy modifiers from objectives/rival attacks
	enemy_count += battle_setup_data.get("rival_extra_enemies", 0)
	enemy_count += battle_setup_data.get("defend_extra_enemies", 0)
	enemy_count += battle_setup_data.get("quest_finale_extra_enemies", 0)

	# Fielding fewer crew reduction (Core Rules p.93):
	# If deploying 2+ fewer figures than campaign crew size, subtract 1
	var _campaign_crew_size: int = 6
	if game_state_manager and game_state_manager.has_method("get_campaign_crew_size"):
		_campaign_crew_size = game_state_manager.get_campaign_crew_size()
	var deployed_count: int = battle_setup_data.get(
		"deployed_crew_count", _campaign_crew_size)
	if deployed_count <= _campaign_crew_size - 2:
		enemy_count = maxi(1, enemy_count - 1)

	var enemy_types = _generate_enemies(enemy_count, mission_source)

	# Get difficulty for Unique Individual and specialist modifiers
	var difficulty: int = GlobalEnums.DifficultyLevel.NORMAL
	if game_state_manager and game_state_manager.has_method("get_difficulty"):
		difficulty = game_state_manager.get_difficulty()

	# Insanity mode: +1 specialist enemy per battle (Core Rules p.65)
	var specialist_bonus: int = DifficultyModifiers.get_specialist_enemy_modifier(difficulty)
	if specialist_bonus > 0:
		for i in range(specialist_bonus):
			# Use EnemyGenerator for specialist type selection too
			var spec_template: Dictionary = {}
			if enemy_generator:
				spec_template = enemy_generator.select_enemy_for_mission(
					mission_source if not mission_source.is_empty() else "patron"
				)
			var spec_name: String = spec_template.get("name", "Specialist")
			var specialist: Dictionary = {
				"id": "specialist_bonus_%d" % i,
				"type": spec_name,
				"name": spec_name + " Specialist",
				"combat_skill": spec_template.get("combat_skill", randi_range(1, 3)),
				"toughness": spec_template.get("toughness", randi_range(4, 5)),
				"speed": spec_template.get("speed", randi_range(4, 6)),
				"weapons": ["Military Rifle"],
				"weapon_traits": ["ranged"],
				"is_specialist": true
			}
			enemy_types.append(specialist)

	# Determine Unique Individual presence (Core Rules pp.64-65, 94)
	var unique_individual: Dictionary = _determine_unique_individual(difficulty, mission_type)

	# Determine battlefield conditions
	var terrain_type = _determine_terrain()
	var deployment_conditions = _determine_deployment_conditions()

	# Roll Notable Sights (Core Rules p.88) — not during Invasion battles
	var notable_sight: Dictionary = {}
	var is_invasion: bool = battle_setup_data.get("is_invasion", false)
	if not is_invasion and not is_black_zone:
		var sights_system := NotableSightsSystem.new()
		if sights_system.is_loaded():
			var is_patron: bool = battle_setup_data.get("is_patron_mission", false)
			var is_rival: bool = battle_setup_data.get("is_rival_battle", false)
			var is_quest: bool = battle_setup_data.get("is_quest_mission", false)
			var column: String = sights_system.get_mission_column(is_patron, is_rival, is_quest)
			notable_sight = sights_system.roll_notable_sight(column)

	# Build canonical enemy_force dict (single type per Core Rules pp.91-94)
	var _primary_template: Dictionary = {}
	if enemy_generator:
		# Re-lookup the type name from the first enemy's type field
		var _primary_name: String = ""
		if not enemy_types.is_empty():
			_primary_name = enemy_types[0].get("type", "")
		if not _primary_name.is_empty():
			var _edb: Dictionary = enemy_generator.enemy_data
			for _cat in _edb.get("enemy_categories", []):
				for _entry in _cat.get("enemies", []):
					if _entry.get("name", "") == _primary_name:
						_primary_template = _entry
						break

	var _ef_type: String = _primary_template.get(
		"name", enemy_types[0].get("type", "Unknown") if not enemy_types.is_empty() else "Unknown")
	var _ef_category: String = enemy_types[0].get("category", "") if not enemy_types.is_empty() else ""
	var enemy_force_dict: Dictionary = {
		"type": _ef_type,
		"category": _ef_category,
		"count": enemy_types.size(),
		"panic": _primary_template.get("panic", "1-2"),
		"speed": _primary_template.get("speed", 4),
		"combat_skill": _primary_template.get("combat_skill", 0),
		"toughness": _primary_template.get("toughness", 3),
		"ai": _primary_template.get("ai", "A"),
		"weapons": _primary_template.get("weapons", "1 A"),
		"numbers": _primary_template.get("numbers", "+0"),
		"special_rules": _primary_template.get("special_rules", []),
		"units": enemy_types,
	}

	# Store setup data
	battle_setup_data = {
		"mission_type": mission_type,
		"enemy_count": enemy_types.size(),
		"enemy_types": enemy_types,  # Legacy key kept for compatibility
		"enemy_force": enemy_force_dict,  # New canonical single-type dict
		"terrain": terrain_type,
		"deployment": deployment_conditions,
		"round_limit": max_rounds,
		"unique_individual": unique_individual,
		"notable_sight": notable_sight,
		"difficulty": difficulty,
		"is_red_zone": is_red_zone,
		"red_zone_threat": red_zone_threat,
		"red_zone_time_constraint": red_zone_time_constraint,
		"is_black_zone": is_black_zone,
		"black_zone_mission": black_zone_mission,
		"mission_objective": mission_objective,
		"rival_attack_type": battle_setup_data.get("rival_attack_type", {}),
		"is_rival_battle": battle_setup_data.get("is_rival_battle", false),
		"is_patron_mission": battle_setup_data.get("is_patron_mission", false),
		"is_quest_mission": battle_setup_data.get("is_quest_mission", false),
		"is_invasion": battle_setup_data.get("is_invasion", false),
	}

	# Drop Launcher: 2D6, on 8+ drop deployment (Core Rules p.61)
	if ShipComponentQuery.has_component("drop_launcher"):
		var drop_roll: int = randi_range(1, 6) + randi_range(1, 6)
		battle_setup_data["drop_deployment_available"] = drop_roll >= 8
		battle_setup_data["drop_deployment_roll"] = drop_roll
		var journal_node: Variant = Engine.get_main_loop().root.get_node_or_null(
			"/root/CampaignJournal") if Engine.get_main_loop() else null
		if journal_node and journal_node.has_method("create_entry"):
			if drop_roll >= 8:
				journal_node.create_entry({
					"type": "battle",
					"title": "Drop Launcher Activated",
					"description": (
						"Drop deployment authorized (rolled %d). "
						+ "Select up to 2 crew for orbital insertion. "
						+ "At end of any round: place marker, move "
						+ "1D6\" random, set up both within 1\". "
						+ "Cannot act on arrival round."
					) % drop_roll,
					"tags": ["ship_component", "drop_launcher", "deployment"],
					"auto_generated": true,
				})
			else:
				journal_node.create_entry({
					"type": "battle",
					"title": "Drop Launcher — No Window",
					"description": "Drop deployment not viable (rolled %d, needed 8+)." % drop_roll,
					"tags": ["ship_component", "drop_launcher"],
					"auto_generated": true,
				})

	# DLC: Apply compendium difficulty modifiers
	_apply_dlc_difficulty_modifiers(battle_setup_data)

	# DLC: Tag combat mode flags for UI and resolution
	var dlc_cm = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_cm and dlc_cm.has_method("is_feature_enabled"):
		battle_setup_data["no_minis_combat"] = dlc_cm.is_feature_enabled(dlc_cm.ContentFlag.NO_MINIS_COMBAT)
		battle_setup_data["grid_based_movement"] = dlc_cm.is_feature_enabled(dlc_cm.ContentFlag.GRID_BASED_MOVEMENT)

	# DLC: Generate special mission type setup data (Compendium pp.117-147)
	match battle_type:
		"stealth":
			var stealth_setup: Dictionary = CompendiumStealthMissions.generate_mission_setup()
			if not stealth_setup.is_empty():
				battle_setup_data["stealth_mission"] = stealth_setup
				battle_setup_data["no_minis_combat"] = false # Stealth incompatible with no-minis
				battle_setup_data["grid_based_movement"] = false # Stealth incompatible with grid
				print_verbose("BattlePhase DLC: Stealth Mission — %s" % stealth_setup.get("objective", {}).get("id", "unknown"))
		"street_fight":
			var street_setup: Dictionary = CompendiumStreetFights.generate_mission_setup()
			if not street_setup.is_empty():
				battle_setup_data["street_fight"] = street_setup
				print_verbose("BattlePhase DLC: Street Fight — %s" % street_setup.get("objective", {}).get("id", "unknown"))
		"salvage":
			var salvage_setup: Dictionary = CompendiumSalvageJobs.generate_mission_setup()
			if not salvage_setup.is_empty():
				battle_setup_data["salvage_mission"] = salvage_setup
				print_verbose("BattlePhase DLC: Salvage Job")

	# DLC: Escalating Battles check data (Compendium pp.46-47)
	# Pre-compute whether escalation is applicable for this battle type
	var escalation_applicable: bool = battle_type == "conventional"
	if battle_type == "stealth":
		escalation_applicable = false # Not during stealth rounds or Round 1
	elif battle_type == "street_fight" or battle_type == "salvage":
		escalation_applicable = false # Not used in Street Fights or Salvage
	battle_setup_data["escalation_applicable"] = escalation_applicable
	if escalation_applicable:
		battle_setup_data["escalation_trigger_rules"] = CompendiumEscalation.TRIGGER_RULES

	battle_setup_completed.emit(battle_setup_data)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Continue to deployment
	await _process_deployment()

func _generate_mission_type() -> int:
	## Generate random mission type — returns enum for campaign phase tracking.
	## The actual D10 objective roll is done separately in _roll_mission_objective().
	# DEPRECATED: This entire file is dead (Session 48c/50). Using PATRON enum
	# for patron missions; all others return NONE since RIVAL/QUEST/INVASION/
	# OPPORTUNITY don't exist in GlobalEnums.MissionType.
	if GlobalEnums:
		if battle_setup_data.get("is_patron_mission", false):
			return GlobalEnums.MissionType.PATRON
	return GlobalEnums.MissionType.NONE if GlobalEnums else 0

func _roll_mission_objective(mission_type: int) -> Dictionary:
	## Roll D10 on the mission objective table (Core Rules pp.89-91).
	## Uses MissionTableManager for JSON-backed table lookup.
	## Returns Dictionary with type, name, description, victory_condition.

	# Invasion battles have no objective — just survive 6 rounds
	if battle_setup_data.get("is_invasion", false):
		return {
			"type": "INVASION_SURVIVE",
			"name": "Survive",
			"description": "Hold out for 6 rounds against the invasion force. "
				+ "Any figure leaving before Round 6 becomes a casualty.",
			"victory_condition": "Survive 6 rounds, then flee or Hold the Field.",
			"roll": 0,
		}

	# Quest finale is always Fight Off with +1 enemy (Core Rules p.89)
	if battle_setup_data.get("is_quest_finale", false):
		var def: Dictionary = {}
		if mission_table_manager:
			def = mission_table_manager.get_objective_definition("FIGHT_OFF")
		return {
			"type": "FIGHT_OFF",
			"name": def.get("name", "Fight Off"),
			"description": def.get("description",
				"Final Quest battle. Fight to the death."),
			"victory_condition": def.get("victory_condition",
				"Hold the Field."),
			"quest_finale": true,
			"enemy_count_modifier": 1,
			"roll": 0,
		}

	if not mission_table_manager:
		return {"type": "FIGHT_OFF", "name": "Fight Off",
			"description": "Drive off the enemy.", "roll": 0}

	# Map mission type enum to table key
	var table_key: String = "opportunity"
	if battle_setup_data.get("is_patron_mission", false):
		table_key = "patron"
	elif battle_setup_data.get("is_quest_mission", false):
		table_key = "quest"
	# Note: Rival battles use the rival attack type table, not objectives

	return mission_table_manager.roll_mission_objective(table_key)

func _roll_rival_attack_type() -> Dictionary:
	## Roll D10 on the Rival Attack Type table (Core Rules p.91).
	## Returns Dictionary with type (AMBUSH/BROUGHT_FRIENDS/SHOWDOWN/
	## ASSAULT/RAID), description, and roll.
	if not mission_table_manager:
		return {"type": "SHOWDOWN",
			"description": "Straight-up fight.", "roll": 0}

	var tracked_down: bool = battle_setup_data.get(
		"rival_tracked_down", false)
	return mission_table_manager.roll_rival_attack_type(tracked_down)

func _determine_enemy_count() -> int:
	## Determine number of enemies based on Core Rules (p.63)
	##
	## Crew Size Rules:
	## - Size 6: Roll 2D6, pick HIGHER result
	## - Size 5: Roll 1D6
	## - Size 4: Roll 2D6, pick LOWER result
	##
	## This uses EnemyGenerator._calculate_enemy_count() for consistency.

	var crew_size = 6 # Default to 6 (standard campaign crew size)
	var difficulty = 2 # Default to NORMAL difficulty

	if game_state_manager:
		# Use campaign crew size SETTING (4/5/6), not roster count
		if game_state_manager.has_method("get_campaign_crew_size"):
			crew_size = game_state_manager.get_campaign_crew_size()
		if game_state_manager.has_method("get_difficulty"):
			difficulty = game_state_manager.get_difficulty()

	# Use EnemyGenerator's Core Rules-compliant formula
	if enemy_generator:
		return enemy_generator.calculate_enemy_count(difficulty, crew_size)

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


func _generate_enemies(
	count: int, mission_source: String = "patron"
) -> Array[Dictionary]:
	## Generate enemy force composition using EnemyGenerator D100 tables.
	## Pulls stats from enemy_types.json instead of random ranges.
	var enemies: Array[Dictionary] = []

	# Check DLC flags for enemy modifiers
	var elite_enabled := false
	var krag_enabled := false
	var skulker_enabled := false
	var dlc_node = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager"
	) if Engine.get_main_loop() else null
	if dlc_node and dlc_node.has_method("is_feature_enabled"):
		elite_enabled = dlc_node.is_feature_enabled(
			dlc_node.ContentFlag.ELITE_ENEMIES
		)
		krag_enabled = dlc_node.is_feature_enabled(
			dlc_node.ContentFlag.SPECIES_KRAG
		)
		skulker_enabled = dlc_node.is_feature_enabled(
			dlc_node.ContentFlag.SPECIES_SKULKER
		)

	# Roll once on encounter category table for this battle
	# (all enemies in a battle are from the same category per Core Rules)
	var category: String = "criminal_elements"
	if enemy_generator:
		category = enemy_generator._roll_encounter_category(
			mission_source if not mission_source.is_empty() else "patron"
		)

	# Roll ONE specific enemy type within category (Core Rules pp.91-94)
	# ALL enemies in this battle are the SAME type
	var template: Dictionary = {}
	if enemy_generator:
		template = enemy_generator._roll_enemy_in_category(category)

	var enemy_name: String = template.get("name", "Unknown Hostiles")
	var base_weapons: Array = []
	if enemy_generator and not template.is_empty():
		base_weapons = enemy_generator._resolve_weapon_code(
			template.get("weapons", "1 A")
		)
	else:
		base_weapons = ["Basic Rifle"]

	# Specialist/Lieutenant assignment (Core Rules p.93)
	var specialist_count: int = 0
	if count >= 7:
		specialist_count = 2
	elif count >= 3:
		specialist_count = 1
	var has_lieutenant: bool = (count >= 4)

	# Resolve specialist weapons (different weapon column)
	var specialist_weapons: Array = base_weapons
	if enemy_generator and not template.is_empty() and specialist_count > 0:
		var weapon_code: String = template.get("weapons", "1 A")
		# Specialist column is the letter part (A/B/C)
		var parts: PackedStringArray = weapon_code.strip_edges().split(" ")
		if parts.size() >= 2:
			var spec_code: String = "1 " + parts[1]
			specialist_weapons = enemy_generator._resolve_weapon_code(spec_code)

	for i in range(count):
		# Determine role for this figure
		var role: String = "standard"
		var combat_mod: int = 0
		var weapons: Array = base_weapons.duplicate()
		var extra_weapons: Array = []

		if has_lieutenant and i == 0:
			role = "lieutenant"
			combat_mod = 1  # Core Rules p.93: +1 Combat Skill
			extra_weapons = ["Blade"]  # Lieutenant carries a Blade
		elif specialist_count > 0 and i >= (count - specialist_count):
			role = "specialist"
			weapons = specialist_weapons.duplicate()

		var display_name: String = enemy_name
		if role == "lieutenant":
			display_name = "%s Lieutenant" % enemy_name
		elif role == "specialist":
			display_name = "%s Specialist" % enemy_name

		var enemy: Dictionary = {
			"id": "enemy_%d" % i,
			"type": enemy_name,  # ALL same type
			"name": display_name,
			"role": role,
			"combat_skill": template.get("combat_skill", 0) + combat_mod,
			"toughness": template.get("toughness", 3),
			"speed": template.get("speed", 4),
			"weapons": weapons + extra_weapons,
			"weapon_traits": ["ranged"],
			"ai": template.get("ai", "A"),
			"panic": template.get("panic", "1-2"),
			"special_rules": template.get("special_rules", []),
			"category": category,
		}

		# ELITE_ENEMIES: upgrade stats per Compendium elite rules
		if elite_enabled:
			enemy["combat_skill"] += 1
			enemy["toughness"] += 1
			if randi_range(1, 6) >= 4:
				enemy["weapons"] = ["Military Rifle"]
			elif randi_range(1, 6) == 6:
				enemy["weapons"] = ["Power Blade"]
				enemy["weapon_traits"] = ["melee"]
			enemy["is_elite"] = true

		# SPECIES: 20% chance per enemy to be Krag or Skulker variant
		if krag_enabled and randi_range(1, 10) <= 2:
			enemy["species"] = "krag"
			enemy["toughness"] = max(enemy["toughness"], 4)
			enemy["speed"] = min(enemy["speed"], 4)
			enemy["special_rules"] = [
				"no_dash", "belligerent_reroll"
			]
		elif skulker_enabled and randi_range(1, 10) <= 2:
			enemy["species"] = "skulker"
			enemy["toughness"] = min(enemy["toughness"], 3)
			enemy["speed"] = max(enemy["speed"], 6)
			enemy["special_rules"] = ["nimble", "low_profile"]
		enemies.append(enemy)

	return enemies

func _determine_terrain() -> int:
	## Determine terrain type for battle
	if GlobalEnums:
		return GlobalEnums.PlanetEnvironment.TEMPERATE
	return 0

func _determine_deployment_conditions() -> Dictionary:
	## Determine deployment conditions — Core Rules p.88 D100 table + DLC overlay.
	##
	## Step 1: Roll D100 on Core Rules deployment conditions table (by mission type).
	##         Skipped for Invasion battles (Core Rules p.88).
	## Step 2: Apply DLC Deployment Variables (Compendium pp.44-45) if conventional.
	var result: Dictionary = {
		"crew_deployment_zone": "standard",
		"enemy_deployment_zone": "standard",
		"special_conditions": [],
		"condition_id": "NO_CONDITION",
		"condition_title": "No Condition",
		"condition_description": "",
		"condition_effects": {},
	}

	# Step 1: Core Rules D100 Deployment Conditions (skipped for Invasion)
	var is_invasion: bool = battle_setup_data.get("is_invasion", false)
	if not is_invasion and deployment_conditions_system:
		# Determine mission type for correct D100 column
		var mission_type_enum: int = DeploymentConditionsSystemClass.MissionType.OPPORTUNITY
		if battle_setup_data.get("is_patron_mission", false):
			mission_type_enum = DeploymentConditionsSystemClass.MissionType.PATRON
		elif battle_setup_data.get("is_rival_battle", false):
			mission_type_enum = DeploymentConditionsSystemClass.MissionType.RIVAL
		elif battle_setup_data.get("is_quest_mission", false):
			mission_type_enum = DeploymentConditionsSystemClass.MissionType.QUEST

		var condition = deployment_conditions_system.roll_deployment_condition(
			mission_type_enum)
		if condition:
			result["condition_id"] = condition.condition_id
			result["condition_title"] = condition.title
			result["condition_description"] = condition.description
			result["condition_effects"] = condition.effects
			if condition.condition_id != "NO_CONDITION":
				result["special_conditions"].append(condition.description)
				print_verbose(
					"BattlePhase: Deployment Condition — %s" % condition.title)

			# Apply condition effects to battle state
			var modified_state: Dictionary = deployment_conditions_system.apply_condition(
				condition, {
					"enemy_count": battle_setup_data.get("enemy_count", 0),
					"crew_count": crew_deployed.size() if not crew_deployed.is_empty() else 6,
				})
			# Propagate enemy count changes from conditions like Small Encounter
			if modified_state.has("enemy_count"):
				var new_count: int = modified_state["enemy_count"]
				var old_count: int = battle_setup_data.get("enemy_count", 0)
				if new_count != old_count:
					result["enemy_count_adjustment"] = new_count - old_count
			# Propagate crew sitting out
			if modified_state.has("crew_sits_out"):
				result["crew_sits_out"] = modified_state["crew_sits_out"]
			# Propagate all modifier flags for UI/resolver
			for key in modified_state:
				if key not in ["enemy_count", "crew_count"]:
					result[key] = modified_state[key]

	# Step 2: DLC Deployment Variables (Compendium pp.44-45)
	var battle_type: String = battle_setup_data.get("battle_type", "conventional")
	if battle_type == "conventional":
		var seized: bool = battle_setup_data.get("seized_initiative", false)
		var ai_type: String = battle_setup_data.get("dlc_ai_type", "tactical")
		var deploy: Dictionary = CompendiumDeploymentVars.roll_deployment(
			ai_type, seized)
		if not deploy.is_empty():
			result["dlc_deployment"] = deploy
			result["special_conditions"].append(
				deploy.get("instruction", ""))
			print_verbose(
				"BattlePhase DLC: Deployment Variable — %s" % deploy.get(
					"name", "Line"))

	return result

func _determine_unique_individual(difficulty: int, mission_type: int) -> Dictionary:
	## Determine if a Unique Individual is present (Core Rules pp.64-65, 93-94)
	## Thresholds loaded from data/unique_individual.json.
	##
	## - Standard: Roll 2D6, on 9+ a Unique Individual is present
	## - +1 if fighting Interested Parties (Core Rules p.93)
	## - Hardcore: +1 to the roll (Core Rules p.65)
	## - Insanity: Always forced. On 2D6 roll of 11-12, TWO Unique Individuals
	## - Invasion battles and Roving Threats: no Unique Individual (standard rules)
	var result: Dictionary = {"present": false, "count": 0, "forced": false, "individuals": []}
	var threshold: int = _get_ui_threshold()  # Default 9, from JSON

	# Check if Unique Individual is forced (Insanity mode)
	if DifficultyModifiers.is_unique_individual_forced(difficulty):
		result.present = true
		result.count = 1
		result.forced = true
		# Insanity: Roll 2D6, on 11-12 include TWO Unique Individuals
		if DifficultyModifiers.can_have_double_unique_individual(difficulty):
			var double_threshold: int = _get_ui_double_threshold()  # Default 11, from JSON
			var double_roll: int = randi_range(1, 6) + randi_range(1, 6)
			if double_roll >= double_threshold:
				result.count = 2
				print_verbose("BattlePhase: INSANITY — Double Unique Individual! (rolled %d >= %d)" % [double_roll, double_threshold])
		print_verbose("BattlePhase: INSANITY — Forced Unique Individual (count: %d)" % result.count)
		# Roll on the Unique Individual table for each
		for i in range(result.count):
			var individual: Dictionary = _roll_unique_individual_type()
			if not individual.is_empty():
				result.individuals.append(individual)
		return result

	# Standard roll: 2D6, threshold+ = Unique Individual present
	var roll: int = randi_range(1, 6) + randi_range(1, 6)

	# Difficulty modifier: Hardcore +1 (Core Rules p.65)
	var modifier: int = DifficultyModifiers.get_unique_individual_roll_modifier(difficulty)

	# Interested Parties modifier: +1 (Core Rules p.93)
	var enemy_category: String = battle_setup_data.get("enemy_category", "")
	if enemy_category == "interested_parties":
		modifier += _get_ui_interested_parties_modifier()

	var final_roll: int = roll + modifier

	if final_roll >= threshold:
		result.present = true
		result.count = 1
		var individual: Dictionary = _roll_unique_individual_type()
		if not individual.is_empty():
			result.individuals.append(individual)
		print_verbose("BattlePhase: Unique Individual present (roll %d + mod %d = %d >= %d) — %s" % [
			roll, modifier, final_roll, threshold,
			individual.get("name", "unknown")])
	else:
		print_verbose("BattlePhase: No Unique Individual (roll %d + mod %d = %d < %d)" % [roll, modifier, final_roll, threshold])

	return result

func _roll_unique_individual_type() -> Dictionary:
	## Roll D100 on the unique_individuals table from enemy_types.json (Core Rules pp.64-65)
	var data_manager = get_node_or_null("/root/GameDataManager")
	if not data_manager:
		data_manager = get_node_or_null("/root/DataManager")
	var enemy_data: Dictionary = {}
	if data_manager and data_manager.has_method("get_enemy_data"):
		enemy_data = data_manager.get_enemy_data()
	# Fallback: load directly
	if enemy_data.is_empty():
		var path := "res://data/enemy_types.json"
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				enemy_data = json.data

	var individuals: Array = enemy_data.get("unique_individuals", [])
	if individuals.is_empty():
		return {}

	var roll: int = (randi() % 100) + 1  # 1-100
	for entry in individuals:
		var roll_range: Array = entry.get("roll_range", [])
		if roll_range.size() == 2:
			if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
				return entry.duplicate()
	return {}

func _process_deployment() -> void:
	## Step 2: Deployment - Position forces on battlefield
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

	deployment_completed.emit(deployment_data)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Continue to initiative
	await _process_initiative()

func _get_deployed_crew() -> Array[Dictionary]:
	## Uses GameStateManager.get_deployable_crew() which checks is_dead/is_wounded.
	var crew: Array[Dictionary] = []

	var is_invasion_battle: bool = battle_setup_data.get("is_invasion", false)

	if game_state_manager and game_state_manager.has_method("get_deployable_crew"):
		var deployable = game_state_manager.get_deployable_crew()
		if deployable == null:
			push_warning("BattlePhase: get_deployable_crew() returned null")
			deployable = []
		for member in deployable:
			var member_dict: Dictionary = _normalize_crew_member_to_dict(member)

			# Character Event restrictions (Core Rules pp.128-130)
			var status_effs: Array = member_dict.get("status_effects", [])
			var battle_blocked := false
			for eff in status_effs:
				var eff_type: String = str(eff.get("type", ""))
				if eff_type == "unavailable" or eff_type == "departed":
					battle_blocked = true
					break
				if eff_type == "skip_next_battle":
					# Violence is Depressing: invasion exception (Core Rules p.128)
					if not (is_invasion_battle and eff.get("invasion_exception", false)):
						battle_blocked = true
						break
			if battle_blocked:
				continue

			crew.append(member_dict)

	# Fallback: Generate default crew for testing when no game_state_manager
	if crew.is_empty():
		crew = _generate_default_crew()

	return crew

func _normalize_crew_member_to_dict(member: Variant) -> Dictionary:
	## B-3 fix: Convert crew member to Dictionary format regardless of source type
	##
	## Handles:
	## - Dictionary: Returns as-is
	## - Character Resource: Calls to_dictionary() if available, or extracts properties
	## - Other types: Creates minimal dictionary with available data
	##
	## Sprint 26.3: Character-Everywhere - crew members are always Character objects

	# Try Character-first (Sprint 26.3 standard)
	if member is Character and member.has_method("to_dictionary"):
		var char_dict = member.to_dictionary()
		# Sprint 10: Derive weapon_traits for brawl bonus calculations
		if not char_dict.has("weapon_traits"):
			char_dict["weapon_traits"] = _derive_weapon_traits(char_dict)
		return char_dict

	if member is Dictionary:
		if not member.has("weapon_traits"):
			member["weapon_traits"] = _derive_weapon_traits(member)
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
		if "equipment" in member:
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
	push_warning("BattlePhase: Unknown crew member type: %s" % typeof(member))
	return {"id": "unknown_" + str(Time.get_ticks_msec()), "status": 0}


## Sprint 10: Derive weapon_traits from equipment/weapons for brawl bonus calculations
func _derive_weapon_traits(char_dict: Dictionary) -> Array:
	var traits: Array = []
	# Check equipment list for weapon type keywords
	var all_items: Array = char_dict.get("equipment", [])
	all_items.append_array(char_dict.get("weapons", []))
	for item_name: Variant in all_items:
		if item_name is not String:
			continue
		var lower: String = item_name.to_lower()
		if "blade" in lower or "knife" in lower or "sword" in lower or "melee" in lower or "club" in lower or "axe" in lower:
			if "melee" not in traits:
				traits.append("melee")
		elif "pistol" in lower or "handgun" in lower or "sidearm" in lower:
			if "pistol" not in traits:
				traits.append("pistol")
		elif "rifle" in lower or "gun" in lower or "carbine" in lower:
			if "ranged" not in traits:
				traits.append("ranged")
	return traits

func _generate_default_crew() -> Array[Dictionary]:
	## Generate default crew for testing when GameStateManager unavailable
	var default_crew: Array[Dictionary] = []
	for i in range(4):  # Default 4 crew members
		default_crew.append({
			"id": "crew_%d" % i,
			"character_name": "Test Crew %d" % (i + 1),
			"status": 0
		})
	return default_crew

func _generate_deployment_positions(count: int, side: String) -> Array:
	## Generate deployment positions for units
	var positions = []
	for i in range(count):
		positions.append({
			"unit_id": "%s_%d" % [side, i],
			"position": Vector2(i * 2, 0 if side == "crew" else 20)
		})
	return positions

func _process_initiative() -> void:
	## Step 3: Seize the Initiative — Core Rules p.112
	## Roll 2D6 + highest Savvy + modifiers. On 10+, crew may move OR fire (natural 6 only).
	## This replaces the simplified 1D6 >= 4 check from Sprint 11.
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.COMBAT
		battle_substep_changed.emit(current_substep)

	# Configure SeizeInitiativeSystem with current battle context
	var seize_result: Variant = null
	if seize_initiative_system:
		# Set crew data for Savvy bonus and Feral detection
		seize_initiative_system.set_crew_data(crew_deployed)

		# Set difficulty mode
		var difficulty: int = GlobalEnums.DifficultyLevel.NORMAL
		if game_state_manager and game_state_manager.has_method("get_difficulty"):
			difficulty = game_state_manager.get_difficulty()
		match difficulty:
			GlobalEnums.DifficultyLevel.HARDCORE:
				seize_initiative_system.set_difficulty_mode(
					SeizeInitiativeSystemClass.DifficultyMode.HARDCORE)
			GlobalEnums.DifficultyLevel.INSANITY:
				seize_initiative_system.set_difficulty_mode(
					SeizeInitiativeSystemClass.DifficultyMode.INSANITY)
			_:
				seize_initiative_system.set_difficulty_mode(
					SeizeInitiativeSystemClass.DifficultyMode.NORMAL)

		# Check if outnumbered (Core Rules p.112: +1 if outnumbered)
		seize_initiative_system.set_outnumbered(
			enemies_deployed.size() > crew_deployed.size())

		# Check for Hired Muscle category (Core Rules p.96: -1)
		var enemy_category: String = battle_setup_data.get("enemy_force", {}).get("category", "")
		seize_initiative_system.set_hired_muscle(enemy_category == "hired_muscle")

		# Apply enemy-specific modifiers from special_rules
		# (Careless: +1, Alert: -1, Prediction: cannot seize, etc.)
		var enemy_special: Array = battle_setup_data.get("enemy_force", {}).get("special_rules", [])
		var enemy_modifier: int = 0
		var cannot_seize: bool = false
		for rule in enemy_special:
			var rule_str: String = str(rule).to_lower()
			if "careless" in rule_str:
				enemy_modifier += 1
			elif "alert" in rule_str:
				enemy_modifier -= 1
			elif "prediction" in rule_str or "cannot seize" in rule_str:
				cannot_seize = true
			elif "unpredictable" in rule_str:
				# Unpredictable: roll is always unmodified — clear all enemy mods
				enemy_modifier = 0
		seize_initiative_system.set_enemy_modifier(enemy_modifier,
			battle_setup_data.get("enemy_force", {}).get("type", "Enemy"))

		# Check ship components for Motion Tracker / Scanner Bot
		seize_initiative_system.set_motion_tracker(
			ShipComponentQuery.has_component("motion_tracker"))
		seize_initiative_system.set_scanner_bot(
			ShipComponentQuery.has_component("scanner_bot"))

		# Also check rival AMBUSH flag (Core Rules p.91: cannot Seize)
		if battle_setup_data.get("cannot_seize_initiative", false):
			cannot_seize = true

		# Roll for Seize the Initiative
		if cannot_seize:
			# Precursor Exiles: "You cannot Seize the Initiative"
			seize_result = SeizeInitiativeSystemClass.InitiativeResult.new()
			seize_result.success = false
			seize_result.roll_total = 0
			seize_result.dice_values = [0, 0]
			print_verbose("BattlePhase: Cannot Seize Initiative (enemy special rule)")
		else:
			seize_result = seize_initiative_system.roll_initiative()
			print_verbose("BattlePhase: Seize Initiative — %s" % seize_result.get_summary().replace("\n", " | "))

		# Store result in battle data for UI display
		initiative_roll = seize_result.roll_total
		battle_setup_data["seize_initiative_result"] = {
			"success": seize_result.success,
			"roll_total": seize_result.roll_total,
			"dice_values": seize_result.dice_values,
			"savvy_bonus": seize_result.savvy_bonus,
			"modifiers": seize_result.modifiers_breakdown,
			"cannot_seize": cannot_seize,
		}
	else:
		# Fallback if system failed to initialize
		push_warning("BattlePhase: SeizeInitiativeSystem unavailable, using fallback 2D6")
		initiative_roll = randi_range(1, 6) + randi_range(1, 6)
		battle_setup_data["seize_initiative_result"] = {
			"success": initiative_roll >= 10,
			"roll_total": initiative_roll,
			"dice_values": [],
			"savvy_bonus": 0,
			"modifiers": [],
			"cannot_seize": false,
		}

	initiative_determined.emit(initiative_roll)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Start combat rounds
	await _process_combat_rounds()

func _process_combat_rounds() -> void:
	## Sprint 11.3: Now supports both tactical and auto-resolve modes

	# Note: current_substep already set to COMBAT in _process_initiative()
	# Re-emitting for any late subscribers
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.COMBAT
		battle_substep_changed.emit(current_substep)

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
		await _execute_tactical_combat()
	else:
		# Use quick auto-resolve (existing simulation)
		await _simulate_battle_outcome()

## Sprint 11.3: Tactical Combat Execution
func _execute_tactical_combat() -> void:
	## Execute turn-by-turn tactical combat using BattleRoundTracker
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

enum BattleResult {ONGOING, VICTORY, DEFEAT, RETREAT}

func _check_battle_result() -> int:
	## Check if battle has ended with victory, defeat, or ongoing
	# Count surviving crew and enemies
	var crew_alive := 0
	var enemies_alive := 0

	for crew in crew_deployed:
		var crew_status = crew.get("status", GlobalEnums.CharacterStatus.HEALTHY)
		if crew_status == GlobalEnums.CharacterStatus.HEALTHY or crew_status == GlobalEnums.CharacterStatus.NONE:
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
	## Finalize results after tactical combat completion
	# Calculate final battle statistics
	var crew_casualties := 0
	var enemies_defeated := 0

	for crew in crew_deployed:
		var crew_status = crew.get("status", GlobalEnums.CharacterStatus.HEALTHY)
		if crew_status != GlobalEnums.CharacterStatus.HEALTHY and crew_status != GlobalEnums.CharacterStatus.NONE:
			crew_casualties += 1

	for enemy in enemies_deployed:
		if enemy.get("defeated", false):
			enemies_defeated += 1

	var success = enemies_defeated >= enemies_deployed.size() / 2 # Victory if half defeated

	# Build crew_participants list
	var crew_participants: Array[Dictionary] = []
	for crew_member in crew_deployed:
		var participant = crew_member.duplicate()
		participant["participated"] = true
		var member_status = crew_member.get("status", GlobalEnums.CharacterStatus.HEALTHY)
		participant["survived"] = member_status == GlobalEnums.CharacterStatus.HEALTHY or member_status == GlobalEnums.CharacterStatus.NONE
		crew_participants.append(participant)

	# Build defeated_enemy_list
	var defeated_enemy_list: Array[Dictionary] = []
	for enemy in enemies_deployed:
		if enemy.get("defeated", false):
			defeated_enemy_list.append(enemy.duplicate())

	# Build injuries list and casualties array (Task 14.3)
	var injuries_sustained: Array[Dictionary] = []
	var casualties: Array[Dictionary] = [] # Fatal casualties for PostBattle tracking
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
				"type": "killed", # Default type; PostBattle injury roll may change
				"round": round_tracker.get_current_round() if round_tracker else current_round,
				"cause": "tactical_combat"
			})

	# Payment calculated by PostBattlePaymentProcessor (Core Rules p.120: 1D6 credits)
	# Do NOT calculate payment here — PostBattle handles all credit awards.

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
		"payment": 0,
		"credits_earned": 0,
		"xp_per_participant": 1,
		"xp_victory_bonus": 2 if success else 0,
		"injured_crew": [],
		"injuries_sustained": injuries_sustained,
		"casualties": casualties, # Task 14.3: Fatal casualties [{crew_id, type, round, cause}]
		"mission_type": battle_setup_data.get("mission_type", 0),
		"mission_id": battle_setup_data.get("mission_id", ""),
		"mission_objective": battle_setup_data.get("mission_objective", {}),
		"rival_attack_type": battle_setup_data.get("rival_attack_type", {}),
		"deployment_condition": battle_setup_data.get("deployment", {}),
		"seize_initiative_result": battle_setup_data.get("seize_initiative_result", {}),
		"combat_mode": "tactical"
	}

	await _complete_battle_phase()

func _simulate_battle_outcome() -> void:
	## Simulate battle outcome using BattleResolver for rules-accurate resolution
	# Prepare resolver inputs
	var battlefield_data: Dictionary = battle_setup_data.get("battlefield_data", {})
	var deployment_condition: Dictionary = battle_setup_data.get("deployment", {})
	var dice_roller: Callable = func(): return randi_range(1, 6)

	# Inject seize initiative difficulty modifier (Core Rules p.65: Hardcore -2, Insanity -3)
	var sim_difficulty: int = GlobalEnums.DifficultyLevel.NORMAL
	if game_state_manager and game_state_manager.has_method("get_difficulty"):
		sim_difficulty = game_state_manager.get_difficulty()
	battlefield_data["seize_initiative_modifier"] = DifficultyModifiers.get_seize_initiative_modifier(sim_difficulty)

	# Sprint 26.5: Debug log combat mode BEFORE resolution
	var crew_first = initiative_roll >= 4
	var crew_strength = crew_deployed.size() * 5
	var enemy_strength = enemies_deployed.size() * 4
	_debug_log_combat_mode(false, max_rounds, initiative_roll, crew_first, crew_strength, enemy_strength)

	# Use BattleResolver for rules-accurate combat simulation
	var resolver_result: Dictionary = BattleResolverClass.resolve_battle(
		crew_deployed, enemies_deployed, battlefield_data,
		deployment_condition, dice_roller
	)

	var success: bool = resolver_result.get("success", false)
	var crew_casualties_count: int = resolver_result.get("crew_casualties", 0)
	var enemies_defeated_count: int = resolver_result.get("enemies_defeated", 0)
	var rounds_fought: int = resolver_result.get("rounds_fought", 3)

	# Build crew_participants using resolver's unit final state
	var crew_participants: Array[Dictionary] = []
	var crew_units_final: Array = resolver_result.get("crew_units_final", [])
	for i in range(crew_deployed.size()):
		var participant: Dictionary
		var crew_item = crew_deployed[i]
		if crew_item is Dictionary:
			participant = crew_item.duplicate()
		elif crew_item is Object and crew_item.has_method("to_dictionary"):
			participant = crew_item.to_dictionary()
		else:
			participant = {"character_name": "Crew Member"}
		participant["participated"] = true
		# Use resolver's is_alive tracking if available
		if i < crew_units_final.size():
			participant["survived"] = crew_units_final[i].get("is_alive", true)
		else:
			participant["survived"] = true
		crew_participants.append(participant)

	# Build injury/casualty data from crew_participants
	var casualty_indices: Array = []
	var injuries_sustained: Array[Dictionary] = []
	var casualties: Array[Dictionary] = []
	for i in range(crew_participants.size()):
		if not crew_participants[i].get("survived", true):
			casualty_indices.append(i)
			var crew_id = crew_participants[i].get(
				"id", crew_participants[i].get(
					"character_id", "unknown_%d" % i
				)
			)
			injuries_sustained.append({
				"crew_id": crew_id,
				"crew_index": i,
				"type": "injury",
				"source": "battle_casualty"
			})
			casualties.append({
				"crew_id": crew_id,
				"type": "killed",
				"round": mini(rounds_fought, randi_range(1, rounds_fought)),
				"cause": "combat"
			})

	# Build defeated_enemy_list from resolver's enemy final state
	var defeated_enemy_list: Array[Dictionary] = []
	var enemy_units_final: Array = resolver_result.get("enemy_units_final", [])
	for i in range(enemies_deployed.size()):
		if i < enemy_units_final.size() and not enemy_units_final[i].get("is_alive", true):
			var enemy: Dictionary = enemies_deployed[i].duplicate() if enemies_deployed[i] is Dictionary else {}
			enemy["defeated"] = true
			defeated_enemy_list.append(enemy)

	# Payment calculated by PostBattlePaymentProcessor (Core Rules p.120: 1D6 credits)
	# Do NOT calculate payment here — PostBattle handles all credit awards.

	combat_results = {
		# Victory status
		"success": success,
		"victory": success,

		# Battle statistics
		"rounds_fought": rounds_fought,
		"crew_casualties": crew_casualties_count,
		"enemies_defeated": enemies_defeated_count,

		# Detailed participant data (CRITICAL for PostBattle phase)
		"crew_participants": crew_participants,
		"defeated_enemy_list": defeated_enemy_list,

		# Loot and rewards (Core Rules p.85-87)
		"loot_opportunities": resolver_result.get("loot_opportunities", enemies_defeated_count),
		"battlefield_finds": resolver_result.get("battlefield_finds", 0),
		"payment": 0,
		"credits_earned": 0,

		# XP tracking
		"xp_per_participant": 1,
		"xp_victory_bonus": 2 if success else 0,

		# Injury data (Full injury records for PostBattle)
		"injured_crew": casualty_indices,
		"injuries_sustained": injuries_sustained,
		"casualties": casualties,

		# Mission reference
		"mission_type": battle_setup_data.get("mission_type", 0),
		"mission_id": battle_setup_data.get("mission_id", ""),
		"mission_objective": battle_setup_data.get("mission_objective", {}),
		"rival_attack_type": battle_setup_data.get("rival_attack_type", {}),
		"deployment_condition": battle_setup_data.get("deployment", {}),
		"seize_initiative_result": battle_setup_data.get("seize_initiative_result", {}),

		# Field control from resolver
		"held_field": resolver_result.get("held_field", success),

		# DLC combat mode flags
		"no_minis_combat": battle_setup_data.get("no_minis_combat", false),
		"grid_based_movement": battle_setup_data.get("grid_based_movement", false),
		"combat_mode": "auto_resolve"
	}

	# DLC: Append no-minis setup data if enabled (Compendium pp.68-75)
	if combat_results.get("no_minis_combat", false):
		combat_results["combat_mode"] = "no_minis"
		var crew_size: int = battle_setup_data.get("crew_size", 4)
		var enemy_count: int = combat_results.get("enemy_count", 6)
		var no_minis_setup: Dictionary = CompendiumNoMinisCombat.generate_battle_setup(
			crew_size, enemy_count)
		combat_results["no_minis_setup"] = no_minis_setup
		combat_results["no_minis_instructions"] = CompendiumNoMinisCombat.generate_setup_text(
			no_minis_setup)

	# DLC: Append grid movement instructions if enabled (Compendium p.66)
	if combat_results.get("grid_based_movement", false):
		var grid_instructions: Array[String] = [
			"GRID MOVEMENT ACTIVE: 1 square = 2\". Convert all distances.",
			"Speed: 4\"=2sq, 6\"=3sq, 8\"=4sq",
			"Range: 12\"=6sq, 24\"=12sq, 36\"=18sq",
			"Close Quarters: Enemy in same square = automatic Brawl",
			"Flanking: Attack from adjacent square = +1 to hit",
			"Large Features: Span multiple squares; enter via adjacent square",
		]
		combat_results["grid_movement_instructions"] = grid_instructions

	# DLC: Include battle type and escalation data in results
	combat_results["battle_type"] = battle_setup_data.get("battle_type", "conventional")
	if battle_setup_data.get("escalation_applicable", false):
		# Roll an escalation check for auto-resolve results to include as instruction
		var ai_type: String = battle_setup_data.get("dlc_ai_type", "tactical")
		var escalation: Dictionary = CompendiumEscalation.roll_escalation(ai_type)
		if not escalation.is_empty():
			combat_results["escalation_effect"] = escalation

	# Include special mission data in results for PostBattle reference
	if battle_setup_data.has("stealth_mission"):
		combat_results["stealth_mission"] = battle_setup_data["stealth_mission"]
	if battle_setup_data.has("street_fight"):
		combat_results["street_fight"] = battle_setup_data["street_fight"]
	if battle_setup_data.has("salvage_mission"):
		combat_results["salvage_mission"] = battle_setup_data["salvage_mission"]

	# Complete battle phase
	await _complete_battle_phase()

func _complete_battle_phase() -> void:
	## Complete the Battle Phase
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.RESOLUTION
		battle_substep_changed.emit(current_substep)

	battle_in_progress = false

	# Sprint 26.5: Debug log battle resolution with all results
	_debug_log_battle_resolution(combat_results)

	battle_results_ready.emit(combat_results)

	# Allow signal to be processed before emitting completion
	await _safe_await_frame()

	battle_phase_completed.emit()

## Public API Methods
func get_current_substep() -> int:
	## Get the current battle sub-step
	return current_substep

func get_battle_results() -> Dictionary:
	## Get battle results data
	return combat_results.duplicate()

func is_battle_phase_active() -> bool:
	## Check if battle phase is currently active
	return battle_in_progress

func is_combat_started() -> bool:
	## Sprint 10.2: Check if actual combat has started (prevents rollback after combat begins)
	##
	## Returns true if:
	## - Battle is in progress AND
	## - We've moved past deployment (INITIATIVE or later substeps)
	##
	## This allows back navigation during SETUP/DEPLOYMENT but not once combat begins.

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
	## Handle combat round phase changes (Reaction -> Quick -> Enemy -> Slow -> End)
	# Could emit signal for UI update here
	pass

func _on_battle_round_changed(new_round: int) -> void:
	## Handle round number changes
	current_round = new_round
	combat_round_started.emit(new_round)

func _on_battle_round_started(round_number: int) -> void:
	## Handle start of new round
	pass

func _on_battle_round_ended(round_number: int) -> void:
	## Handle end of round
	combat_round_completed.emit(round_number)

func _on_battle_event_triggered(round_num: int, event_type: String) -> void:
	## Handle battle events (rounds 2 and 4 per Five Parsecs rules)
	# Delegate to FPCM_BattleEventsSystem for d100 roll + event resolution
	var events_system := FPCM_BattleEventsSystem.new()
	events_system.initialize_battle()
	events_system.current_round = round_num
	events_system.trigger_battle_event()
	# Store triggered event descriptions for the battle log
	for evt in events_system.events_triggered:
		var event_entry := {
			"round": round_num,
			"title": evt.title if evt else event_type,
			"description": evt.description if evt else "",
			"effects": evt.effects if evt else {},
		}
		combat_results["battle_events"] = combat_results.get("battle_events", [])
		combat_results["battle_events"].append(event_entry)

func _on_battle_tracker_started() -> void:
	## Handle BattleRoundTracker battle start signal
	pass

func _on_battle_tracker_ended() -> void:
	## Handle BattleRoundTracker battle end signal
	pass

## Sprint 11.2: Battle Mode Selection
signal battle_mode_selection_requested(crew_count: int, enemy_count: int)
signal battle_mode_selected(use_tactical: bool)

func request_battle_mode_selection() -> void:
	## Request user to choose between tactical and auto-resolve modes
	battle_mode_selection_requested.emit(crew_deployed.size(), enemies_deployed.size())

func set_battle_mode(tactical: bool) -> void:
	## Set the battle mode choice (tactical or auto-resolve)
	use_tactical_combat = tactical
	battle_mode_selected.emit(tactical)

## BP-1: Helper to await battle mode with timeout fallback
func _await_battle_mode_with_timeout(timeout_timer: SceneTreeTimer) -> String:
	## Returns 'signal' if mode was selected, 'timeout' if timed out.
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
	## Find and configure TacticalBattleUI with round tracker for phase-based combat
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

		# Initialize battle with current crew and enemies
		if tactical_ui.has_method("initialize_battle"):
			tactical_ui.initialize_battle(crew_deployed, enemies_deployed, battle_setup_data)
	else:
		push_warning("BattlePhase: TacticalBattleUI not found in scene tree")

func _find_node_by_class(class_name_str: String) -> Node:
	## Find a node by its class_name in the scene tree
	if not is_inside_tree():
		return null

	var root = get_tree().root
	return _recursive_find_by_class(root, class_name_str)

func _recursive_find_by_class(node: Node, class_name_str: String) -> Node:
	## Recursively search for a node with matching class_name
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
	## Force specific battle outcome (for UI/testing)
	combat_results = outcome_data.duplicate()
	_complete_battle_phase()

func get_deployed_crew() -> Array[Dictionary]:
	## Get crew members currently deployed
	return crew_deployed.duplicate()

func get_deployed_enemies() -> Array[Dictionary]:
	## Get enemies currently deployed
	return enemies_deployed.duplicate()

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Substep-Level Debug Output
## ═══════════════════════════════════════════════════════════════════════════════

func _debug_log_battle_setup(_mission_data: Dictionary) -> void:
	## Log battle setup data for debugging (no-op in release)
	pass

func _debug_log_deployment(_crew_count: int, _enemy_count: int, _deployment_type: String, _crew_names: Array, _enemy_types: Array) -> void:
	## Log deployment data for debugging (no-op in release)
	pass

func _debug_log_combat_mode(_is_tactical: bool, _max_rounds_cfg: int, _initiative_roll: int, _crew_first: bool, _crew_strength: int, _enemy_strength: int) -> void:
	## Log combat mode selection and initial state (no-op in release)
	pass

func _debug_log_battle_resolution(_results: Dictionary) -> void:
	## Log battle resolution summary (no-op in release)
	pass


## Safe await helper - handles case when node isn't in scene tree (testing)
## SPRINT 5 FIX: Return early if no tree to avoid null reference in await
func _safe_await_frame() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if tree == null:
		return
	await tree.process_frame

## DLC: Apply compendium difficulty modifiers to battle setup data
func _apply_dlc_difficulty_modifiers(setup_data: Dictionary) -> void:
	var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc:
		return

	var difficulty_instructions: Array[String] = []

	# Progressive Difficulty: turn-based scaling (Compendium pp.30-31)
	# Read user's chosen options from campaign data (persisted at creation)
	var turn_num: int = 0
	if game_state_manager and "turn_number" in game_state_manager:
		turn_num = game_state_manager.turn_number
	var prog_options: Array = []
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_campaign"):
		var _campaign = gs.get_campaign()
		if _campaign and "progress_data" in _campaign:
			prog_options = _campaign.progress_data.get(
				"progressive_difficulty_options", [])
	if turn_num > 0 and not prog_options.is_empty():
		for prog_type in prog_options:
			var prog_text: String = ProgressiveDifficultyTrackerRef.get_instruction_text(
				turn_num, prog_type)
			if not prog_text.is_empty():
				difficulty_instructions.append(prog_text)
		var bonus: int = 0
		for prog_type2 in prog_options:
			bonus += ProgressiveDifficultyTrackerRef.get_enemy_count_bonus(
				turn_num, prog_type2)
		if bonus > 0:
			setup_data["enemy_count"] = setup_data.get("enemy_count", 0) + bonus

	# Difficulty Toggles: active toggle instructions
	var toggles: Array[Dictionary] = []
	toggles.assign(CompendiumDifficultyTogglesRef.get_difficulty_toggles())
	for toggle in toggles:
		difficulty_instructions.append(toggle.get("instruction", ""))

	# AI Behavior: roll for enemy AI variation
	var ai: Dictionary = CompendiumDifficultyTogglesRef.roll_ai_behavior()
	if not ai.is_empty():
		difficulty_instructions.append(ai.get("instruction", ""))
		setup_data["dlc_ai_type"] = ai.get("id", "")

	# Dramatic Combat: weapon-specific narrative instructions (Compendium p.92)
	# Self-gated: get_dramatic_effect() returns "" when DRAMATIC_COMBAT flag disabled
	var dramatic_effects: Array[String] = []
	var weapon_types: Array[String] = ["blade", "pistol", "rifle", "heavy", "grenade", "melee"]
	for wt in weapon_types:
		var effect: String = CompendiumDifficultyTogglesRef.get_dramatic_effect(wt)
		if not effect.is_empty():
			dramatic_effects.append(effect)
	if not dramatic_effects.is_empty():
		setup_data["dramatic_combat_effects"] = dramatic_effects
		difficulty_instructions.append("DRAMATIC COMBAT ACTIVE: Describe weapon-specific effects per the Compendium.")

	if not difficulty_instructions.is_empty():
		setup_data["dlc_difficulty_instructions"] = difficulty_instructions


## Sprint 26.12: Consistent phase handoff interface
func get_completion_data() -> Dictionary:
	## Get Battle Phase completion data for PostBattle Phase transition.
	##
	## Returns Dictionary with:
	## - combat_results: Dictionary - Full combat results including victory, casualties, loot
	## - victory: bool - Whether battle was won
	## - crew_deployed: Array - Crew members that participated
	## - enemies_deployed: Array - Enemies that were in battle
	## - rounds_fought: int - Number of rounds the battle lasted
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

	# Sprint 8: Include companion tracking data if available
	if not data.has("tracking_tier"):
		data["tracking_tier"] = 0
	if not data.has("journal_narrative"):
		data["journal_narrative"] = ""

	return data


# ── Story Track Battle Integration (Core Rules Appendix V) ──

func _is_story_event_battle() -> bool:
	## Check if CampaignPhaseManager flagged this as a Story Event turn
	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if pm and pm.has_method("is_story_event_turn"):
		return pm.is_story_event_turn()
	return false


func _apply_story_battle_config() -> void:
	## Inject story event battle config into battle_setup_data.
	## Overrides normal mission/enemy generation with scripted
	## story event data (Core Rules Appendix V).
	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if not pm or not pm.has_method("get_story_battle_config"):
		return
	var config: Dictionary = pm.get_story_battle_config()
	if config.is_empty():
		return

	battle_setup_data["is_story_battle"] = true
	battle_setup_data["story_event_id"] = config.get(
		"event_id", "")
	battle_setup_data["story_event_number"] = config.get(
		"event_number", 0)

	# Override deployment if story event specifies it
	var deploy: Dictionary = config.get("deployment", {})
	if not deploy.is_empty():
		battle_setup_data["story_deployment"] = deploy
		# Most story events: no Deployment Conditions / Notable Sights
		if deploy.get("no_deployment_conditions", false):
			battle_setup_data["skip_deployment_conditions"] = true
		if deploy.get("no_notable_sights", false):
			battle_setup_data["skip_notable_sights"] = true

	# Override enemy composition
	var enemies: Dictionary = config.get("enemies", {})
	if not enemies.is_empty():
		battle_setup_data["story_enemies"] = enemies

	# Override objectives
	var objectives: Dictionary = config.get("objectives", {})
	if not objectives.is_empty():
		battle_setup_data["story_objectives"] = objectives
