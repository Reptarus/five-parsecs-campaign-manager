@tool
extends Node

# GlobalEnums available as autoload singleton
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
# FiveParsecsMissionGenerator/BaseMissionGenerationSystem removed - file does not exist
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")

# Import the mission type enum directly to avoid reference issues
# const FiveParsecsMissionType = FiveParsecsMissionGenerator.FiveParsecsMissionType

# Signal declarations
signal missions_generated(missions: Array)
signal mission_selected(mission: Dictionary)
signal mission_preparation_complete(mission: Dictionary)
signal mission_canceled(mission: Dictionary)

var campaign_phase_manager: CampaignPhaseManager
# DISABLED - FiveParsecsMissionGenerator does not exist
# var mission_generator: FiveParsecsMissionGenerator
var mission_generator = null  # Type removed - FiveParsecsMissionGenerator does not exist
var battle_results_manager: BattleResultsManager
var game_state: GameState

# Current mission data
var _current_mission: Dictionary = {}
var _available_missions: Array = []
var _mission_history: Array = []

func _init() -> void:
	# DISABLED - FiveParsecsMissionGenerator does not exist
	# mission_generator = FiveParsecsMissionGenerator.new()
	pass
func _ready() -> void:
	_current_mission = {}
	_available_missions = []
func setup(state: GameState, phase_manager: CampaignPhaseManager, results_manager: BattleResultsManager) -> void:
	game_state = state
	campaign_phase_manager = phase_manager
	battle_results_manager = results_manager

	# Connect signals from campaign phase _manager
	if campaign_phase_manager:
		# Connect to phase change signal to detect when we enter the Campaign phase
		if campaign_phase_manager.is_connected("phase_changed", _on_phase_changed):
			@warning_ignore("return_value_discarded")
			campaign_phase_manager.disconnect("phase_changed", _on_phase_changed)

		@warning_ignore("return_value_discarded")
		campaign_phase_manager.connect("phase_changed", _on_phase_changed)

		# Connect to sub-phase change signal to detect when we enter the Mission Selection sub-phase
		if campaign_phase_manager.is_connected("sub_phase_changed", _on_sub_phase_changed):
			@warning_ignore("return_value_discarded")
			campaign_phase_manager.disconnect("sub_phase_changed", _on_sub_phase_changed)

		@warning_ignore("return_value_discarded")
		campaign_phase_manager.connect("sub_phase_changed", _on_sub_phase_changed)

## Generate mission options based on the current world, patron, and circumstances
func generate_mission_options(count: int = 3, include_patron_mission: bool = true) -> Array:
	var missions: Array = []
	var world_data = game_state.current_campaign.current_world
	var patron_available = game_state.current_campaign.has_active_patron()
	var current_turn = game_state.turn_number

	# Consider world traits for _mission generation

	var world_type = world_data.get("type", GlobalEnums.WorldTrait.NONE)

	var world_danger = world_data.get("danger_level", 1)

	# Base difficulty on turn number and world danger
	var min_difficulty = max(1, min(world_danger, current_turn / 5.0))
	var max_difficulty = max(2, min(world_danger + 1, current_turn / 3.0))

	# Generate regular _mission options
	var regular_count = count - 1 if include_patron_mission else count
	for i: int in range(regular_count):
		var mission_type = _get_appropriate_mission_type(world_type)
		var difficulty = min_difficulty + randi() % (max_difficulty - min_difficulty + 1)

		var _mission = mission_generator.generate_mission(difficulty)
		_mission["is_patron"] = false

		missions.append(_mission)

	# Add a patron _mission if requested and available
	if include_patron_mission and patron_available:
		var patron_data = game_state.current_campaign.get_active_patron()
		var patron_mission = _generate_patron_mission(patron_data)

		missions.append(patron_mission)

	_available_missions = missions
	missions_generated.emit(missions)

	return missions

## Select a _mission from the available options
func select_mission(mission_index: int) -> Dictionary:
	if mission_index < 0 or mission_index >= _available_missions.size():
		push_error("Invalid mission _index selected")
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

	# Begin the battle by transitioning to the Battle phase
	if campaign_phase_manager:
		campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

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

@warning_ignore("unused_parameter")
func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	# When entering Campaign _phase, reset available missions
	if new_phase == GlobalEnums.FiveParsecsCampaignPhase.WORLD:
		_available_missions = []
	# When entering Battle phase, ensure mission is prepared
	elif new_phase == GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
		if _current_mission.is_empty() or not _current_mission.get("prepared", false):
			push_warning("Entering Battle phase without a prepared mission")
@warning_ignore("unused_parameter")
func _on_sub_phase_changed(old_sub_phase: int, new_sub_phase: int) -> void:
	# When entering a new sub-phase, check if we need to generate mission options
	# This will be handled by the campaign phase manager instead
	pass
func _get_appropriate_mission_type(world_type: int) -> int:
	# Table for mission types based on world traits (Five Parsecs From Home rulebook p.87-94)
	# Return a mission _type that's appropriate for the given world _type
	var mission_types: Array = []

	match world_type:
		GlobalEnums.WorldTrait.INDUSTRIAL:
			# Industrial worlds favor sabotage and retrieval missions
			mission_types = [
				GlobalEnums.MissionType.SABOTAGE,
				GlobalEnums.MissionType.RAID,
				GlobalEnums.MissionType.RED_ZONE
			]
		GlobalEnums.WorldTrait.FRONTIER:
			# Frontier worlds favor patrol and defense missions
			mission_types = [
				GlobalEnums.MissionType.PATROL,
				GlobalEnums.MissionType.DEFENSE,
				GlobalEnums.MissionType.RESCUE
			]
		GlobalEnums.WorldTrait.TRADE_HUB:
			# Trade centers favor escort and green zone missions
			mission_types = [
				GlobalEnums.MissionType.ESCORT,
				GlobalEnums.MissionType.GREEN_ZONE,
				GlobalEnums.MissionType.PATROL
			]
		GlobalEnums.WorldTrait.CRIMINAL:
			# Criminal worlds favor black zone and assassination missions
			mission_types = [
				GlobalEnums.MissionType.BLACK_ZONE,
				GlobalEnums.MissionType.ASSASSINATION,
				GlobalEnums.MissionType.RAID
			]
		GlobalEnums.WorldTrait.RESEARCH:
			# Research worlds favor defense and sabotage missions
			mission_types = [
				GlobalEnums.MissionType.DEFENSE,
				GlobalEnums.MissionType.RED_ZONE,
				GlobalEnums.MissionType.SABOTAGE
			]
		GlobalEnums.WorldTrait.DANGEROUS:
			# Dangerous worlds favor sabotage and patrol missions
			mission_types = [
				GlobalEnums.MissionType.SABOTAGE,
				GlobalEnums.MissionType.PATROL,
				GlobalEnums.MissionType.RAID
			]
		GlobalEnums.WorldTrait.AFFLUENT:
			# Affluent worlds favor defense and patrol missions
			mission_types = [
				GlobalEnums.MissionType.DEFENSE,
				GlobalEnums.MissionType.PATROL,
				GlobalEnums.MissionType.RESCUE
			]
		_:
			# Default for other world types - general mission mix
			mission_types = [
				GlobalEnums.MissionType.PATROL,
				GlobalEnums.MissionType.RESCUE,
				GlobalEnums.MissionType.SABOTAGE,
				GlobalEnums.MissionType.RAID,
				GlobalEnums.MissionType.DEFENSE,
				GlobalEnums.MissionType.ESCORT
			]

	# Select a random mission _type from the appropriate list
	return mission_types[randi() % mission_types.size()]

func _generate_patron_mission(patron_data: Dictionary) -> Dictionary:
	var difficulty = patron_data.get("tier", 2) + 1
	var mission = mission_generator.generate_mission(difficulty)

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
	var battlefield: Dictionary = {
		"terrain_type": "urban",
		"size": "medium",
		"environment": "standard",
		"special_features": []
	}

	# Customize based on mission type
	match mission_type:
		1: # SALVAGE_RUN
			battlefield["terrain_type"] = "industrial"
			battlefield["special_features"].append("salvage_points")
		2: # RESCUE_OPERATION
			battlefield["special_features"].append("hostages")
		3: # DEFENSE
			battlefield["special_features"].append("defensive_positions")

	# Randomize some aspects
	if randf() < 0.3:
		battlefield["environment"] = ["night", "storm", "fog", "radiation"].pick_random()

	return battlefield

func _generate_enemy_forces() -> Array:
	var enemy_forces: Array = []

	var difficulty = _current_mission.get("difficulty", 2)

	var enemy_count: int = _current_mission.get("enemy_count", 4)

	var enemy_faction: String = _current_mission.get("enemy_faction", "Marauders")

	# Generate basic enemy composition
	for i: int in range(enemy_count):
		var enemy: Dictionary = {
			"id": "enemy_" + str(i),
			"faction": enemy_faction,
			"type": "standard",
			"combat_skill": 2 + (randi() % difficulty),
			"toughness": 1 + (randi() % (difficulty / 2.0 + 1)),
			"reactions": 2 + (randi() % (difficulty / 2.0 + 1)),
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
	var weapons: Array = []
	var weapon_count: int = 1 + (randi() % 2)

	for i: int in range(weapon_count):
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
	var deployment_options: Array = []

	var mission_type = _current_mission.get("type", 0)

	# Standard deployment is always available

	deployment_options.append({
		"name": "Standard Deployment",
		"type": GlobalEnums.DeploymentType.STANDARD,
		"description": "Deploy your forces in the standard deployment zone."
	})

	# Add mission-specific deployment options
	match mission_type:
		0: # BATTLE
			deployment_options.append({
				"name": "Defensive Deployment",
				"type": GlobalEnums.DeploymentType.DEFENSIVE,
				"description": "Deploy your forces in defensive positions."
			})
		1: # SALVAGE_RUN
			deployment_options.append({
				"name": "Scattered Deployment",
				"type": GlobalEnums.DeploymentType.SCATTERED,
				"description": "Deploy your forces in a scattered pattern around salvage points."
			})
		3: # DEFENSE
			deployment_options.append({
				"name": "Defensive Deployment",
				"type": GlobalEnums.DeploymentType.DEFENSIVE,
				"description": "Deploy your forces in a defensive position."
					})

	return deployment_options