@tool
extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const FiveParsecsMissionGenerator = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

# Import the mission type enum directly to avoid reference issues
const FiveParsecsMissionType = FiveParsecsMissionGenerator.FiveParsecsMissionType

# Signal declarations
signal missions_generated(missions: Array)
signal mission_selected(mission: Dictionary)
signal mission_preparation_complete(mission: Dictionary)
signal mission_canceled(mission: Dictionary)
signal mission_integrated(mission_data)
signal mission_completed(mission_data, results)

var campaign_phase_manager: CampaignPhaseManager
var mission_generator: RefCounted = null
var battle_results_manager: BattleResultsManager
var game_state: FiveParsecsGameState
var _mission_generator_node: Node = null # Added for Node wrapper support

# Current mission data
var _current_mission: Dictionary = {}
var _available_missions: Array = []
var _mission_history: Array = []

func _init() -> void:
	# Initialize core components - using generator directly as RefCounted
	mission_generator = FiveParsecsMissionGenerator.new()

func _ready() -> void:
	_current_mission = {}
	_available_missions = []
	
	# Create a node wrapper for the mission generator
	# Use try-except to handle potential errors with static methods
	_create_node_wrapper()

func _exit_tree() -> void:
	# Clean up resources
	mission_generator = null
	if _mission_generator_node:
		if _mission_generator_node.get_parent() == self:
			remove_child(_mission_generator_node)
		_mission_generator_node.queue_free()
		_mission_generator_node = null

func setup(state: FiveParsecsGameState, phase_manager: CampaignPhaseManager, results_manager: BattleResultsManager) -> void:
	game_state = state
	campaign_phase_manager = phase_manager
	battle_results_manager = results_manager
	
	# Connect signals from campaign phase manager
	if campaign_phase_manager:
		# Connect to phase change signal to detect when we enter the Campaign phase
		if campaign_phase_manager.is_connected("phase_changed", _on_phase_changed):
			campaign_phase_manager.disconnect("phase_changed", _on_phase_changed)
		campaign_phase_manager.connect("phase_changed", _on_phase_changed)
		
		# Connect to sub-phase change signal to detect when we enter the Mission Selection sub-phase
		if campaign_phase_manager.is_connected("sub_phase_changed", _on_sub_phase_changed):
			campaign_phase_manager.disconnect("sub_phase_changed", _on_sub_phase_changed)
		campaign_phase_manager.connect("sub_phase_changed", _on_sub_phase_changed)

## Generate mission options based on the current world, patron, and circumstances
func generate_mission_options(count: int = 3, include_patron_mission: bool = true) -> Array:
	var missions = []
	var world_data = game_state.current_campaign.current_world
	var patron_available = game_state.current_campaign.has_active_patron()
	var current_turn = game_state.turn_number
	
	# Consider world traits for mission generation
	var world_type = world_data.get("type", GameEnums.WorldTrait.NONE)
	var world_danger = world_data.get("danger_level", 1)
	
	# Base difficulty on turn number and world danger
	var min_difficulty = max(1, min(world_danger, current_turn / 5))
	var max_difficulty = max(2, min(world_danger + 1, current_turn / 3))
	
	# Generate regular mission options
	var regular_count = count - 1 if include_patron_mission else count
	for i in range(regular_count):
		var mission_type = _get_appropriate_mission_type(world_type)
		var difficulty = min_difficulty + randi() % (max_difficulty - min_difficulty + 1)
		
		var mission = generate_mission(difficulty, mission_type)
		mission["is_patron"] = false
		missions.append(mission)
	
	# Add a patron mission if requested and available
	if include_patron_mission and patron_available:
		var patron_data = game_state.current_campaign.get_active_patron()
		var patron_mission = _generate_patron_mission(patron_data)
		missions.append(patron_mission)
	
	_available_missions = missions
	missions_generated.emit(missions)
	
	return missions

## Select a mission from the available options
func select_mission(mission_index: int) -> Dictionary:
	if mission_index < 0 or mission_index >= _available_missions.size():
		push_error("Invalid mission index selected")
		return {}
	
	_current_mission = _available_missions[mission_index]
	mission_selected.emit(_current_mission)
	
	# Mark the mission selection action as completed in the campaign phase manager
	if campaign_phase_manager:
		campaign_phase_manager.complete_phase_action("mission_selected")
	
	return _current_mission

## Prepare the selected mission for battle
func prepare_mission() -> Dictionary:
	if _current_mission.is_empty():
		push_error("No mission selected to prepare")
		return {}
	
	# Setup battle parameters based on mission data
	_current_mission["battlefield"] = _generate_battlefield_data()
	_current_mission["enemy_forces"] = _generate_enemy_forces()
	_current_mission["deployment_options"] = _generate_deployment_options()
	_current_mission["prepared"] = true
	
	# Mark the mission preparation action as completed in the campaign phase manager
	if campaign_phase_manager:
		campaign_phase_manager.complete_phase_action("mission_prepared")
	
	mission_preparation_complete.emit(_current_mission)
	return _current_mission

## Cancel the current mission selection
func cancel_mission() -> void:
	if _current_mission.is_empty():
		return
		
	var canceled_mission = _current_mission.duplicate()
	_current_mission = {}
	mission_canceled.emit(canceled_mission)

## Start a battle with the current mission
func start_battle() -> void:
	if _current_mission.is_empty() or not _current_mission.get("prepared", false):
		push_error("Mission not prepared for battle")
		return
	
	# Begin the battle by transitioning to the Battle Setup phase
	if campaign_phase_manager:
		campaign_phase_manager.start_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP)
	
	# Initialize battle in the battle results manager
	if battle_results_manager:
		battle_results_manager.start_battle(_current_mission)

## Add the current mission to the history after completion
func complete_current_mission(success: bool) -> void:
	if _current_mission.is_empty():
		return
	
	_current_mission["completed"] = true
	_current_mission["success"] = success
	_current_mission["completion_turn"] = game_state.turn_number
	
	_mission_history.append(_current_mission.duplicate())
	_current_mission = {}
	
	# Notify mission generator
	mission_generator.complete_mission(_mission_history[-1], success)

## Get mission history for the campaign
func get_mission_history() -> Array:
	return _mission_history.duplicate()

## Get the currently available missions
func get_available_missions() -> Array:
	return _available_missions.duplicate()

## Get the currently selected mission
func get_current_mission() -> Dictionary:
	return _current_mission.duplicate()

## Private helper methods

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	# When entering Campaign phase, reset available missions
	if new_phase == GameEnums.FiveParcsecsCampaignPhase.PRE_MISSION:
		_available_missions = []
	# When entering Battle Setup phase, ensure mission is prepared
	elif new_phase == GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
		if _current_mission.is_empty() or not _current_mission.get("prepared", false):
			push_warning("Entering Battle Setup without a prepared mission")

func _on_sub_phase_changed(old_sub_phase: int, new_sub_phase: int) -> void:
	# When entering Mission Selection sub-phase, generate mission options
	if new_sub_phase == GameEnums.CampaignSubPhase.MISSION_SELECTION:
		generate_mission_options()

func _get_appropriate_mission_type(world_type: int) -> int:
	# Table for mission types based on world traits (Five Parsecs From Home rulebook p.87-94)
	# Return a mission type that's appropriate for the given world type
	var mission_types = []
	
	match world_type:
		GameEnums.WorldTrait.INDUSTRIAL_HUB:
			# Industrial worlds favor sabotage and retrieval missions
			mission_types = [
				GameEnums.MissionType.SABOTAGE,
				GameEnums.MissionType.RAID,
				GameEnums.MissionType.RED_ZONE
			]
		GameEnums.WorldTrait.FRONTIER_WORLD:
			# Frontier worlds favor patrol and defense missions
			mission_types = [
				GameEnums.MissionType.PATROL,
				GameEnums.MissionType.DEFENSE,
				GameEnums.MissionType.RESCUE
			]
		GameEnums.WorldTrait.TRADE_CENTER:
			# Trade centers favor escort and green zone missions
			mission_types = [
				GameEnums.MissionType.ESCORT,
				GameEnums.MissionType.GREEN_ZONE,
				GameEnums.MissionType.PATROL
			]
		GameEnums.WorldTrait.PIRATE_HAVEN:
			# Pirate havens favor black zone and assassination missions
			mission_types = [
				GameEnums.MissionType.BLACK_ZONE,
				GameEnums.MissionType.ASSASSINATION,
				GameEnums.MissionType.RAID
			]
		GameEnums.WorldTrait.TECH_CENTER:
			# Tech centers favor defense and sabotage missions
			mission_types = [
				GameEnums.MissionType.DEFENSE,
				GameEnums.MissionType.RED_ZONE,
				GameEnums.MissionType.SABOTAGE
			]
		GameEnums.WorldTrait.MINING_COLONY:
			# Mining colonies favor sabotage and patrol missions
			mission_types = [
				GameEnums.MissionType.SABOTAGE,
				GameEnums.MissionType.PATROL,
				GameEnums.MissionType.RAID
			]
		GameEnums.WorldTrait.AGRICULTURAL_WORLD:
			# Agricultural worlds favor defense and patrol missions
			mission_types = [
				GameEnums.MissionType.DEFENSE,
				GameEnums.MissionType.PATROL,
				GameEnums.MissionType.RESCUE
			]
		_:
			# Default for other world types - general mission mix
			mission_types = [
				GameEnums.MissionType.PATROL,
				GameEnums.MissionType.RESCUE,
				GameEnums.MissionType.SABOTAGE,
				GameEnums.MissionType.RAID,
				GameEnums.MissionType.DEFENSE,
				GameEnums.MissionType.ESCORT
			]
	
	# Select a random mission type from the appropriate list
	return mission_types[randi() % mission_types.size()]

func _generate_patron_mission(patron_data: Dictionary) -> Dictionary:
	var difficulty = patron_data.get("tier", 2) + 1
	var mission = generate_mission(difficulty, FiveParsecsMissionType.PATRON_JOB)
	
	# Customize mission based on patron
	mission["is_patron"] = true
	mission["patron_id"] = patron_data.get("id", "")
	mission["patron_name"] = patron_data.get("name", "Unknown Patron")
	
	# Increase rewards for patron missions
	mission["reward"]["credits"] = mission["reward"].get("credits", 100) * 1.5
	mission["reward"]["reputation"] = mission["reward"].get("reputation", 1) + 2
	
	return mission

func _generate_battlefield_data() -> Dictionary:
	# Generate battlefield data based on mission type and location
	var mission_type = _current_mission.get("type", 0)
	var location = _current_mission.get("location", "")
	
	# Default battlefield
	var battlefield = {
		"terrain_type": "urban",
		"size": "medium",
		"environment": "standard",
		"special_features": []
	}
	
	# Customize based on mission type
	match mission_type:
		FiveParsecsMissionType.SALVAGE_RUN:
			battlefield["terrain_type"] = "industrial"
			battlefield["special_features"].append("salvage_points")
		FiveParsecsMissionType.RESCUE_OPERATION:
			battlefield["special_features"].append("hostages")
		FiveParsecsMissionType.DEFENSE:
			battlefield["special_features"].append("defensive_positions")
	
	# Randomize some aspects
	if randf() < 0.3:
		battlefield["environment"] = ["night", "storm", "fog", "radiation"].pick_random()
	
	return battlefield

func _generate_enemy_forces() -> Array:
	var enemy_forces = []
	var difficulty = _current_mission.get("difficulty", 2)
	var enemy_count = _current_mission.get("enemy_count", 4)
	var enemy_faction = _current_mission.get("enemy_faction", "Marauders")
	
	# Generate basic enemy composition
	for i in range(enemy_count):
		var enemy = {
			"id": "enemy_" + str(i),
			"faction": enemy_faction,
			"type": "standard",
			"combat_skill": 2 + (randi() % difficulty),
			"toughness": 1 + (randi() % (difficulty / 2 + 1)),
			"reactions": 2 + (randi() % (difficulty / 2 + 1)),
			"weapons": _generate_enemy_weapons(difficulty)
		}
		
		# Add leader for larger groups
		if i == 0 and enemy_count >= 4:
			enemy["type"] = "leader"
			enemy["combat_skill"] += 1
			enemy["toughness"] += 1
		
		# Add elite enemies for higher difficulties
		if difficulty >= 4 and i < 2:
			enemy["type"] = "elite"
			enemy["combat_skill"] += 1
		
		enemy_forces.append(enemy)
	
	return enemy_forces

func _generate_enemy_weapons(difficulty: int) -> Array:
	var weapons = []
	var weapon_count = 1 + (randi() % 2)
	
	for i in range(weapon_count):
		var weapon = {
			"name": "Standard Weapon",
			"damage": 1,
			"range": "medium"
		}
		
		# Higher difficulty means better weapons
		if difficulty >= 3:
			weapon["damage"] += 1
		if difficulty >= 5:
			weapon["name"] = "Advanced Weapon"
			weapon["damage"] += 1
		
		weapons.append(weapon)
	
	return weapons

func _generate_deployment_options() -> Array:
	var deployment_options = []
	var mission_type = _current_mission.get("type", 0)
	
	# Standard deployment is always available
	deployment_options.append({
		"name": "Standard Deployment",
		"type": GameEnums.DeploymentType.STANDARD,
		"description": "Deploy your forces in the standard deployment zone."
	})
	
	# Add mission-specific deployment options
	match mission_type:
		FiveParsecsMissionType.BATTLE:
			deployment_options.append({
				"name": "Line Deployment",
				"type": GameEnums.DeploymentType.LINE,
				"description": "Deploy your forces in a line formation."
			})
		FiveParsecsMissionType.SALVAGE_RUN:
			deployment_options.append({
				"name": "Scattered Deployment",
				"type": GameEnums.DeploymentType.SCATTERED,
				"description": "Deploy your forces in a scattered pattern around salvage points."
			})
		FiveParsecsMissionType.DEFENSE:
			deployment_options.append({
				"name": "Defensive Deployment",
				"type": GameEnums.DeploymentType.DEFENSIVE,
				"description": "Deploy your forces in a defensive position."
			})
	
	return deployment_options

## Generate a new mission
func generate_mission(difficulty: int = 2, mission_type: int = -1) -> Dictionary:
	# Use the node wrapper if available (for signals and node integration)
	if _mission_generator_node and _mission_generator_node.has_method("generate_mission"):
		return _mission_generator_node.generate_mission(difficulty, mission_type)
	
	# Fallback to direct RefCounted method
	return mission_generator.generate_mission(difficulty, mission_type)

# Helper to create node wrapper safely
func _create_node_wrapper() -> void:
	# Need to access the static method indirectly to avoid linter errors
	_mission_generator_node = null
	
	# Safe try-catch equivalent - check if we can create the wrapper
	if Engine.get_version_info().major >= 4:
		# Try to create the wrapper directly
		_mission_generator_node = FiveParsecsMissionGenerator.create_node_wrapper()
		
		if _mission_generator_node:
			add_child(_mission_generator_node)
