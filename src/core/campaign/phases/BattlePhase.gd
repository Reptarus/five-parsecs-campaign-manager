extends Node
class_name BattlePhase

## Battle Phase Implementation - Official Five Parsecs Rules
## Handles the complete Battle Phase sequence (Phase 3 of campaign turn)

# Safe imports
const EnemyGenerator = preload("res://src/core/systems/EnemyGenerator.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const ProgressiveDifficultyTrackerRef = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
const CompendiumNoMinisCombat = preload("res://src/data/compendium_no_minis.gd")
const BattleResolverClass = preload("res://src/core/battle/BattleResolver.gd")
const RedZoneSystem = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystem = preload("res://src/core/mission/BlackZoneSystem.gd")

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
var _initialization_complete: bool = false # True after _initialize_autoloads completes

## Battle configuration
var max_rounds: int = 8 # Standard Five Parsecs battle length
var initiative_roll: int = 0
var crew_deployed: Array[Dictionary] = []
var enemies_deployed: Array[Dictionary] = []

## Sprint 11.1: BattleRoundTracker for actual combat rounds (Five Parsecs p.118)
var round_tracker: Node = null # BattleRoundTracker instance
var use_tactical_combat: bool = false # User choice: tactical vs auto-resolve (Sprint 11.2)

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

	# Get mission type from setup data or generate
	var mission_type = battle_setup_data.get("mission_type", _generate_mission_type())

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
		print("BattlePhase: BLACK ZONE — %d enemies (%d teams of %d), Mission: %s" % [
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
		print("BattlePhase: RED ZONE — %d enemies, Threat: %s, Time: %s" % [
			enemy_count, red_zone_threat.get("name", "None"), red_zone_time_constraint.get("name", "None")
		])
	else:
		enemy_count = _determine_enemy_count()
	var enemy_types = _generate_enemies(enemy_count)

	# Get difficulty for Unique Individual and specialist modifiers
	var difficulty: int = GlobalEnums.DifficultyLevel.NORMAL
	if game_state_manager and game_state_manager.has_method("get_difficulty"):
		difficulty = game_state_manager.get_difficulty()

	# Insanity mode: +1 specialist enemy per battle (Core Rules p.65)
	var specialist_bonus: int = DifficultyModifiers.get_specialist_enemy_modifier(difficulty)
	if specialist_bonus > 0:
		for i in range(specialist_bonus):
			var specialist: Dictionary = {
				"id": "specialist_bonus_%d" % i,
				"type": _get_random_enemy_type(),
				"combat_skill": randi_range(1, 3),
				"toughness": randi_range(4, 5),
				"speed": randi_range(4, 6),
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

	# Store setup data
	battle_setup_data = {
		"mission_type": mission_type,
		"enemy_count": enemy_types.size(),
		"enemy_types": enemy_types,
		"terrain": terrain_type,
		"deployment": deployment_conditions,
		"round_limit": max_rounds,
		"unique_individual": unique_individual,
		"difficulty": difficulty,
		"is_red_zone": is_red_zone,
		"red_zone_threat": red_zone_threat,
		"red_zone_time_constraint": red_zone_time_constraint,
		"is_black_zone": is_black_zone,
		"black_zone_mission": black_zone_mission
	}

	# DLC: Apply compendium difficulty modifiers
	_apply_dlc_difficulty_modifiers(battle_setup_data)

	# DLC: Tag combat mode flags for UI and resolution
	var dlc_cm = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_cm and dlc_cm.has_method("is_feature_enabled"):
		battle_setup_data["no_minis_combat"] = dlc_cm.is_feature_enabled(dlc_cm.ContentFlag.NO_MINIS_COMBAT)
		battle_setup_data["grid_based_movement"] = dlc_cm.is_feature_enabled(dlc_cm.ContentFlag.GRID_BASED_MOVEMENT)

	battle_setup_completed.emit(battle_setup_data)

	# Allow signal to be processed before continuing
	await _safe_await_frame()

	# Continue to deployment
	await _process_deployment()

func _generate_mission_type() -> int:
	## Generate random mission type
	if GlobalEnums:
		# Standard patrol mission (most common)
		return GlobalEnums.MissionType.PATROL
	return 0

func _determine_enemy_count() -> int:
	## Determine number of enemies based on Core Rules (p.63)
	##
	## Crew Size Rules:
	## - Size 6: Roll 2D6, pick HIGHER result
	## - Size 5: Roll 1D6
	## - Size 4: Roll 2D6, pick LOWER result
	##
	## This uses EnemyGenerator._calculate_enemy_count() for consistency.

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
	## Generate enemy force composition
	var enemies: Array[Dictionary] = []

	# Check DLC flags for enemy modifiers
	var elite_enabled := false
	var krag_enabled := false
	var skulker_enabled := false
	var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc and dlc.has_method("is_feature_enabled"):
		elite_enabled = dlc.is_feature_enabled(dlc.ContentFlag.ELITE_ENEMIES)
		krag_enabled = dlc.is_feature_enabled(dlc.ContentFlag.SPECIES_KRAG)
		skulker_enabled = dlc.is_feature_enabled(dlc.ContentFlag.SPECIES_SKULKER)

	for i in range(count):
		var enemy = {
			"id": "enemy_%d" % i,
			"type": _get_random_enemy_type(),
			"combat_skill": randi_range(0, 2),
			"toughness": randi_range(3, 5),
			"speed": randi_range(4, 6),
			"weapons": ["Basic Rifle"],
			"weapon_traits": ["ranged"]
		}
		# ELITE_ENEMIES: upgrade enemy stats per Compendium elite rules
		if elite_enabled:
			enemy["combat_skill"] += 1
			enemy["toughness"] += 1
			if randi_range(1, 6) >= 4:
				enemy["weapons"] = ["Military Rifle"]
			# Some elite enemies carry melee weapons
			elif randi_range(1, 6) == 6:
				enemy["weapons"] = ["Power Blade"]
				enemy["weapon_traits"] = ["melee"]
			enemy["is_elite"] = true
		# SPECIES: 20% chance per enemy to be Krag or Skulker variant
		if krag_enabled and randi_range(1, 10) <= 2:
			enemy["species"] = "krag"
			enemy["toughness"] = max(enemy["toughness"], 4)
			enemy["speed"] = min(enemy["speed"], 4)
			enemy["special_rules"] = ["no_dash", "belligerent_reroll"]
		elif skulker_enabled and randi_range(1, 10) <= 2:
			enemy["species"] = "skulker"
			enemy["toughness"] = min(enemy["toughness"], 3)
			enemy["speed"] = max(enemy["speed"], 6)
			enemy["special_rules"] = ["nimble", "low_profile"]
		enemies.append(enemy)

	return enemies

func _get_random_enemy_type() -> int:
	## Get random enemy type
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
	## Determine terrain type for battle
	if GlobalEnums:
		return GlobalEnums.PlanetEnvironment.TEMPERATE
	return 0

func _determine_deployment_conditions() -> Dictionary:
	## Determine deployment conditions
	return {
		"crew_deployment_zone": "standard",
		"enemy_deployment_zone": "standard",
		"special_conditions": []
	}

func _determine_unique_individual(difficulty: int, mission_type: int) -> Dictionary:
	## Determine if a Unique Individual is present (Core Rules pp.64-65, 94)
	##
	## - Standard: Roll 2D6, on 9+ a Unique Individual is present
	## - Hardcore: +1 to the roll
	## - Insanity: Always forced. On 2D6 roll of 11-12, TWO Unique Individuals
	## - Invasion battles and Roving Threats: no Unique Individual (standard rules)
	var result: Dictionary = {"present": false, "count": 0, "forced": false}

	# Check if Unique Individual is forced (Insanity mode)
	if DifficultyModifiers.is_unique_individual_forced(difficulty):
		result.present = true
		result.count = 1
		result.forced = true
		# Insanity: Roll 2D6, on 11-12 include TWO Unique Individuals
		if DifficultyModifiers.can_have_double_unique_individual(difficulty):
			var double_roll: int = randi_range(1, 6) + randi_range(1, 6)
			if double_roll >= 11:
				result.count = 2
				print("BattlePhase: INSANITY — Double Unique Individual! (rolled %d)" % double_roll)
		print("BattlePhase: INSANITY — Forced Unique Individual (count: %d)" % result.count)
		return result

	# Standard roll: 2D6, 9+ = Unique Individual present
	var roll: int = randi_range(1, 6) + randi_range(1, 6)

	# Hardcore: +1 to roll for Unique Individual
	var modifier: int = DifficultyModifiers.get_unique_individual_roll_modifier(difficulty)
	var final_roll: int = roll + modifier

	if final_roll >= 9:
		result.present = true
		result.count = 1
		print("BattlePhase: Unique Individual present (roll %d + mod %d = %d >= 9)" % [roll, modifier, final_roll])
	else:
		print("BattlePhase: No Unique Individual (roll %d + mod %d = %d < 9)" % [roll, modifier, final_roll])

	return result

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

	if game_state_manager and game_state_manager.has_method("get_deployable_crew"):
		var deployable = game_state_manager.get_deployable_crew()
		if deployable == null:
			push_warning("BattlePhase: get_deployable_crew() returned null")
			deployable = []
		for member in deployable:
			var member_dict: Dictionary = _normalize_crew_member_to_dict(member)
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
	## Step 3: Initiative - Determine turn order
	if GlobalEnums:
		current_substep = GlobalEnums.BattleCampaignSubStep.COMBAT
		battle_substep_changed.emit(current_substep)

	# Roll initiative (1D6, 4+ crew goes first)
	initiative_roll = randi_range(1, 6)
	var crew_first = initiative_roll >= 4

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
		"casualties": casualties, # Task 14.3: Fatal casualties [{crew_id, type, round, cause}]
		"mission_type": battle_setup_data.get("mission_type", 0),
		"mission_id": battle_setup_data.get("mission_id", ""),
		"combat_mode": "tactical"
	}

	await _complete_battle_phase()

func _simulate_battle_outcome() -> void:
	## Simulate battle outcome using BattleResolver for rules-accurate resolution
	# Prepare resolver inputs
	var battlefield_data: Dictionary = battle_setup_data.get("battlefield_data", {})
	var deployment_condition: Dictionary = battle_setup_data.get("deployment", {})
	var dice_roller: Callable = func(): return randi_range(1, 6)

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

	# Calculate payment based on mission type and difficulty
	var base_payment = battle_setup_data.get("base_payment", 100)
	var difficulty_bonus = battle_setup_data.get("difficulty", 2) * 25
	var success_bonus = 50 if success else 0
	var payment = base_payment + difficulty_bonus + success_bonus

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
		"payment": payment,
		"credits_earned": payment,

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

		# Field control from resolver
		"held_field": resolver_result.get("held_field", success),

		# DLC combat mode flags
		"no_minis_combat": battle_setup_data.get("no_minis_combat", false),
		"grid_based_movement": battle_setup_data.get("grid_based_movement", false),
		"combat_mode": "auto_resolve"
	}

	# DLC: Append no-minis location data if enabled
	if combat_results.get("no_minis_combat", false):
		combat_results["combat_mode"] = "no_minis"
		var locations = CompendiumNoMinisCombat.LOCATION_TYPES
		var battle_locations: Array[String] = []
		var num_locations = randi_range(3, 5)
		for loc_i in range(num_locations):
			var loc = locations[loc_i % locations.size()]
			battle_locations.append(loc.get("instruction", ""))
		combat_results["no_minis_locations"] = battle_locations

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

	# Progressive Difficulty: turn-based scaling
	var turn_num: int = 0
	if game_state_manager and "turn_number" in game_state_manager:
		turn_num = game_state_manager.turn_number
	if turn_num > 0:
		var prog_text: String = ProgressiveDifficultyTrackerRef.get_instruction_text(
			turn_num, ProgressiveDifficultyTrackerRef.ProgressionType.BASIC
		)
		if not prog_text.is_empty():
			difficulty_instructions.append(prog_text)
		var bonus: int = ProgressiveDifficultyTrackerRef.get_enemy_count_bonus(
			turn_num, ProgressiveDifficultyTrackerRef.ProgressionType.BASIC
		)
		if bonus > 0:
			setup_data["enemy_count"] = setup_data.get("enemy_count", 0) + bonus

	# Difficulty Toggles: active toggle instructions
	var toggles: Array[Dictionary] = CompendiumDifficultyTogglesRef.get_difficulty_toggles()
	for toggle in toggles:
		difficulty_instructions.append(toggle.get("instruction", ""))

	# AI Behavior: roll for enemy AI variation
	var ai: Dictionary = CompendiumDifficultyTogglesRef.roll_ai_behavior()
	if not ai.is_empty():
		difficulty_instructions.append(ai.get("instruction", ""))
		setup_data["dlc_ai_type"] = ai.get("id", "")

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
