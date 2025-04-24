@tool
extends Node

const GameEnums = preload("res://src/core/systems/GameEnums.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
# Note: Using lowercase 'm' in management to match the actual directory name (case sensitivity matters)
const CharacterManager = preload("res://src/core/character/management/CharacterManager.gd")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")
const MissionIntegrator = preload("res://src/core/mission/MissionIntegrator.gd")
const EquipmentManager = preload("res://src/core/equipment/EquipmentManager.gd")

signal system_initialized
signal campaign_loaded(campaign_data: Dictionary)
signal phase_changed(old_phase: int, new_phase: int)
signal game_state_changed
signal turn_advanced(new_turn: int)

# Core game state
var game_state: FiveParsecsGameState
var campaign_phase_manager: CampaignPhaseManager
var character_manager
var battle_results_manager: BattleResultsManager
var mission_integrator: MissionIntegrator
var equipment_manager: EquipmentManager

# Game execution state
var _initialized: bool = false
var _loading: bool = false

func _init() -> void:
	pass

func _ready() -> void:
	_initialize_systems()

## Initialize all game systems
func _initialize_systems() -> void:
	if _initialized:
		return
	
	# Create game state
	game_state = FiveParsecsGameState.new()
	add_child(game_state)
	
	# Initialize and add other managers
	_initialize_character_manager()
	_initialize_campaign_phase_manager()
	_initialize_battle_results_manager()
	_initialize_mission_integrator()
	_initialize_equipment_manager()
	
	# Connect signals
	_connect_signals()
	
	_initialized = true
	system_initialized.emit()

## Initialize the character manager
func _initialize_character_manager() -> void:
	character_manager = CharacterManager.new()
	add_child(character_manager)

## Initialize the campaign phase manager
func _initialize_campaign_phase_manager() -> void:
	campaign_phase_manager = CampaignPhaseManager.new()
	add_child(campaign_phase_manager)
	campaign_phase_manager.setup(game_state)

## Initialize the battle results manager
func _initialize_battle_results_manager() -> void:
	battle_results_manager = BattleResultsManager.new()
	add_child(battle_results_manager)
	battle_results_manager.setup(game_state, character_manager)

## Initialize the mission integrator
func _initialize_mission_integrator() -> void:
	mission_integrator = MissionIntegrator.new()
	add_child(mission_integrator)
	mission_integrator.setup(game_state, campaign_phase_manager, battle_results_manager)

## Initialize the equipment manager
func _initialize_equipment_manager() -> void:
	equipment_manager = EquipmentManager.new()
	add_child(equipment_manager)
	equipment_manager.setup(game_state, character_manager, battle_results_manager)

## Connect signals between systems
func _connect_signals() -> void:
	# Connect campaign phase manager signals
	campaign_phase_manager.connect("phase_changed", _on_phase_changed)
	campaign_phase_manager.connect("phase_error", _on_phase_error)
	
	# Connect game state signals
	game_state.connect("turn_advanced", _on_turn_advanced)
	game_state.connect("resources_changed", _on_resources_changed)
	game_state.connect("campaign_created", _on_campaign_created)
	game_state.connect("campaign_loaded", _on_campaign_loaded)
	
	# Connect battle results manager signals
	battle_results_manager.connect("battle_results_recorded", _on_battle_results_recorded)
	battle_results_manager.connect("casualties_processed", _on_casualties_processed)
	battle_results_manager.connect("rewards_calculated", _on_rewards_calculated)
	
	# Connect mission integrator signals
	mission_integrator.connect("mission_selected", _on_mission_selected)
	mission_integrator.connect("mission_preparation_complete", _on_mission_preparation_complete)
	
	# Connect equipment manager signals
	equipment_manager.connect("equipment_acquired", _on_equipment_acquired)

## Start a new campaign with initial setup
func start_new_campaign(campaign_data: Dictionary) -> void:
	if not _initialized:
		_initialize_systems()
	
	game_state.create_campaign(campaign_data)
	
	# Start with the setup phase - use the integer directly
	campaign_phase_manager.start_phase(1) # SETUP = 1

## Load an existing campaign
func load_campaign(campaign_path: String) -> void:
	if not _initialized:
		_initialize_systems()
	
	_loading = true
	
	# Load campaign data from file path
	var campaign_data = game_state.load_campaign_from_path(campaign_path)
	
	# Initialize character manager with saved characters
	var characters = campaign_data.get("characters", [])
	for character_data in characters:
		character_manager.add_character(character_data)
	
	# Initialize equipment manager with saved equipment
	var equipment = campaign_data.get("equipment", [])
	for equipment_data in equipment:
		equipment_manager.add_equipment(equipment_data)
	
	# Restore character equipment assignments
	var char_equipment = campaign_data.get("character_equipment", {})
	for char_id in char_equipment:
		var equipment_list = char_equipment[char_id]
		for equipment_id in equipment_list:
			equipment_manager.assign_equipment_to_character(char_id, equipment_id)
	
	# Start in the appropriate phase
	var current_phase = campaign_data.get("current_phase", GlobalEnums.FiveParcsecsCampaignPhase.NONE)
	if current_phase != GlobalEnums.FiveParcsecsCampaignPhase.NONE:
		campaign_phase_manager.start_phase(current_phase)
	
	_loading = false
	campaign_loaded.emit(campaign_data)

## Save the current campaign state
func save_campaign() -> Dictionary:
	if not game_state.current_campaign:
		push_error("No active campaign to save")
		return {}
	
	var campaign_data = game_state.serialize_campaign()
	
	# Add character data
	campaign_data["characters"] = []
	var all_characters = character_manager.get_all_characters()
	for character in all_characters:
		if all_characters is Array:
			(campaign_data["characters"] as Array).push_back(character)
	
	# Add equipment data
	var all_equipment = equipment_manager.get_all_equipment()
	if all_equipment is Array:
		campaign_data["equipment"] = all_equipment
	else:
		campaign_data["equipment"] = []
	
	# Add character equipment assignments
	campaign_data["character_equipment"] = {}
	var assignments = equipment_manager.get_all_character_assignments()
	for char_id in assignments:
		var equipment = equipment_manager.get_character_equipment(char_id)
		if equipment is Array:
			campaign_data["character_equipment"][char_id] = equipment
	
	# Add current phase information
	campaign_data["current_phase"] = campaign_phase_manager.current_phase
	campaign_data["current_sub_phase"] = campaign_phase_manager.current_sub_phase
	
	return campaign_data

## Advance to the next campaign phase
func advance_to_next_phase() -> bool:
	var next_phase = _get_next_campaign_phase()
	if next_phase == GlobalEnums.FiveParcsecsCampaignPhase.NONE:
		push_error("No valid next phase from current phase")
		return false
	
	return campaign_phase_manager.start_phase(next_phase)

## Get the next phase in the campaign sequence
func _get_next_campaign_phase() -> int:
	var current = campaign_phase_manager.current_phase
	
	match current:
		GlobalEnums.FiveParcsecsCampaignPhase.NONE, GlobalEnums.FiveParcsecsCampaignPhase.END:
			return GlobalEnums.FiveParcsecsCampaignPhase.UPKEEP
		GlobalEnums.FiveParcsecsCampaignPhase.SETUP:
			return GlobalEnums.FiveParcsecsCampaignPhase.UPKEEP
		GlobalEnums.FiveParcsecsCampaignPhase.UPKEEP:
			return GlobalEnums.FiveParcsecsCampaignPhase.STORY
		GlobalEnums.FiveParcsecsCampaignPhase.STORY:
			return GlobalEnums.FiveParcsecsCampaignPhase.CAMPAIGN
		GlobalEnums.FiveParcsecsCampaignPhase.CAMPAIGN:
			return GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP
		GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
		GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			return GlobalEnums.FiveParcsecsCampaignPhase.ADVANCEMENT
		GlobalEnums.FiveParcsecsCampaignPhase.ADVANCEMENT:
			return GlobalEnums.FiveParcsecsCampaignPhase.TRADE
		GlobalEnums.FiveParcsecsCampaignPhase.TRADE:
			return GlobalEnums.FiveParcsecsCampaignPhase.END
		_:
			return GlobalEnums.FiveParcsecsCampaignPhase.NONE

## Create a new character for the current campaign
func create_character(character_data: Dictionary) -> Dictionary:
	var new_character = character_manager.create_character()
	
	# Set character properties
	for key in character_data:
		if new_character.has_method("set"):
			new_character.set(key, character_data[key])
		else:
			new_character[key] = character_data[key]
	
	character_manager.update_character(new_character.id, new_character)
	
	return new_character

## Process battle results and apply outcomes
func process_battle_results(battle_outcome: String) -> Dictionary:
	# Complete the battle with the specified outcome
	var battle_results = battle_results_manager.complete_battle(battle_outcome)
	
	# Process casualties
	var casualties = battle_results_manager.process_casualties()
	
	# Check for potential rival generation
	if battle_outcome == BattleResultsManager.OUTCOME_VICTORY:
		_check_for_rival_generation(battle_results)
	
	return battle_results

## Calculate and apply experience from a battle
func process_battle_experience() -> Dictionary:
	var experience_data = battle_results_manager.calculate_experience()
	battle_results_manager.apply_experience(experience_data)
	return experience_data

## Generate and process loot from a battle
func process_battle_loot() -> Array:
	var battle_data = battle_results_manager._current_battle
	var difficulty = battle_data.get("difficulty", 2)
	var success = battle_data.get("outcome", "") == BattleResultsManager.OUTCOME_VICTORY
	
	var loot_items = equipment_manager.generate_battle_loot(difficulty, success)
	
	# Add loot items to equipment storage
	for item in loot_items:
		equipment_manager.add_equipment(item)
	
	return loot_items

## Signal handlers

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	phase_changed.emit(old_phase, new_phase)

func _on_phase_error(error_message: String, is_critical: bool) -> void:
	push_error("Phase error: " + error_message)
	
	# Handle critical errors
	if is_critical:
		# Attempt to recover - use the integer directly
		if campaign_phase_manager.current_phase != 1: # SETUP = 1
			campaign_phase_manager.start_phase(1) # SETUP = 1

func _on_turn_advanced(new_turn: int) -> void:
	turn_advanced.emit(new_turn)

func _on_resources_changed(_resource: String, _amount: int) -> void:
	game_state_changed.emit()

func _on_campaign_created(_campaign_data: Dictionary) -> void:
	game_state_changed.emit()

func _on_campaign_loaded(_campaign_data: Dictionary) -> void:
	game_state_changed.emit()

func _on_battle_results_recorded(results: Dictionary) -> void:
	game_state_changed.emit()
	
	# If current phase is battle resolution, complete the "battle_completed" action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
		campaign_phase_manager.complete_phase_action("battle_completed")

func _on_casualties_processed(_casualties: Array) -> void:
	# If current phase is battle resolution, complete the "casualties_resolved" action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
		campaign_phase_manager.complete_phase_action("casualties_resolved")

func _on_rewards_calculated(_rewards: Dictionary) -> void:
	game_state_changed.emit()

func _on_mission_selected(_mission: Dictionary) -> void:
	game_state_changed.emit()

func _on_mission_preparation_complete(_mission: Dictionary) -> void:
	game_state_changed.emit()
	
	# If current phase is campaign, complete the mission preparation action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParcsecsCampaignPhase.CAMPAIGN:
		campaign_phase_manager.complete_phase_action("mission_prepared")

func _on_equipment_acquired(_equipment_data: Dictionary) -> void:
	game_state_changed.emit()

## Public accessors for each manager

# Get the character manager
func get_character_manager():
	return character_manager

# Get the battle results manager
func get_battle_results_manager() -> BattleResultsManager:
	return battle_results_manager

# Get the mission integrator
func get_mission_integrator() -> MissionIntegrator:
	return mission_integrator

# Get the equipment manager
func get_equipment_manager() -> EquipmentManager:
	return equipment_manager

# Get the campaign phase manager
func get_campaign_phase_manager() -> CampaignPhaseManager:
	return campaign_phase_manager

## Handle Rival generation according to the Five Parsecs rulebook
func _check_for_rival_generation(battle_results: Dictionary) -> void:
	# In Five Parsecs, a rival is generated when:
	# 1. An enemy leader survives the battle (roll < 50%)
	# 2. Specific mission types (roll < 25%) 
	# 3. After specific story events
	# Check for surviving enemy leader
	if battle_results.get("enemy_leader_escaped", false):
		# 50% chance to become rival according to rulebook
		if randi() % 100 < 50:
			_generate_new_rival("leader", battle_results)
	
	# Check mission type for additional rival generation chance
	var mission_type = battle_results.get("mission_type", -1)
	if mission_type == GlobalEnums.MissionType.BLACK_ZONE or mission_type == GlobalEnums.MissionType.RESCUE:
		# 25% chance to generate rival for these mission types according to rulebook
		if randi() % 100 < 25:
			_generate_new_rival("mission", battle_results)

## Generate a new rival based on the rulebook
func _generate_new_rival(source_type: String, battle_data: Dictionary) -> void:
	# Determine rival type based on source
	var rival_type = ""
	match source_type:
		"leader":
			var leader_types = ["Enemy Commander", "Crime Boss", "Bounty Hunter", "Warlord"]
			rival_type = leader_types[randi() % leader_types.size()]
		"mission":
			var mission_types = ["Mercenary", "Criminal", "Alien Threat", "Military Officer"]
			rival_type = mission_types[randi() % mission_types.size()]
		_:
			rival_type = "Unknown Rival"
	
	# Generate rival data
	var name_suffixes = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"]
	var rival_name = rival_type + " " + name_suffixes[randi() % name_suffixes.size()]
	
	# Generate rival stats according to rulebook's Rival table
	var rival_data = {
		"id": "rival_" + str(randi() % 10000),
		"name": rival_name,
		"type": rival_type,
		"threat_level": 1 + (randi() % 3),
		"grudge_level": 1,
		"last_encounter": game_state.current_turn,
		"origin": {
			"battle_id": battle_data.get("id", ""),
			"source": source_type,
			"turn": game_state.current_turn
		},
		"attributes": {
			"combat": 1 + (randi() % 3),
			"resources": 1 + (randi() % 3)
		}
	}
	
	# Add rival to game state - handle type safety
	if not game_state.get("rivals"):
		game_state.rivals = []
	
	# Check if rivals is actually an Array before using Array methods
	if game_state.rivals is Array:
		var rivals_array = game_state.rivals as Array
		rivals_array.push_back(rival_data)
	else:
		# Create a new array if rivals isn't one
		game_state.rivals = [rival_data]
	
	# Notify of rival generation
	print("New rival generated: " + rival_data.name)

## Handle Patron relationships according to the rulebook
func process_patron_relationship(patron_id: String, mission_success: bool) -> void:
	# Get patrons with safe defaults
	var patrons = game_state.get("patrons")
	
	# Ensure patrons is an Array
	if patrons == null or not (patrons is Array):
		patrons = []
	
	var patrons_array = patrons as Array
	var patron_index = -1
	
	# Find patron by ID
	for i in range(patrons_array.size()):
		var patron = patrons_array[i]
		if patron is Dictionary and patron.get("id") == patron_id:
			patron_index = i
			break
	
	if patron_index >= 0:
		var patron = patrons_array[patron_index] as Dictionary
		
		# Update relationship based on mission success
		if mission_success:
			patron["relationship"] = min(patron.get("relationship", 0) + 1, 5)
		else:
			patron["relationship"] = max(patron.get("relationship", 0) - 1, -3)
			
			# Check if patron relationship has deteriorated too much
			if patron["relationship"] <= -3:
				# According to rulebook, remove patron at relationship -3
				patrons_array.remove_at(patron_index)
				print("Patron relationship has deteriorated. Patron removed.")
				return
		
		# Update patron in game state
		patrons_array[patron_index] = patron
		game_state.patrons = patrons_array