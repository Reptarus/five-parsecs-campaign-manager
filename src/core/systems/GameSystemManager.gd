@tool
extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
# Note: CharacterManager is an autoload - access via get_node("/root/CharacterManager")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")
const MissionIntegrator = preload("res://src/core/mission/MissionIntegrator.gd")
const EquipmentManager = preload("res://src/core/equipment/EquipmentManager.gd")

signal system_initialized
signal campaign_loaded(campaign_data: Dictionary)
signal phase_changed(old_phase: int, new_phase: int)
signal game_state_changed
signal turn_advanced(new_turn: int)

# Core game state
var game_state: GameState
var campaign_phase_manager: CampaignPhaseManager
var character_manager: Node # CharacterManagerAutoload
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
	game_state = GameState.new()
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
	character_manager = get_node_or_null("/root/CharacterManagerAutoload")
	if not character_manager:
		push_error("CharacterManagerAutoload autoload not found")

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
	@warning_ignore("return_value_discarded")
	campaign_phase_manager.connect("phase_changed", _on_phase_changed) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	campaign_phase_manager.connect("phase_error", _on_phase_error) # warning: return value discarded (intentional)

	# Connect game state signals

	@warning_ignore("return_value_discarded")
	var _connect_result: int = game_state.connect("turn_advanced", _on_turn_advanced) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	game_state.connect("resources_changed", _on_resources_changed) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	game_state.connect("campaign_created", _on_campaign_created) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	game_state.connect("campaign_loaded", _on_campaign_loaded) # warning: return value discarded (intentional)

	# Connect battle results manager signals

	@warning_ignore("return_value_discarded")
	battle_results_manager.connect("battle_results_recorded", _on_battle_results_recorded) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	battle_results_manager.connect("casualties_processed", _on_casualties_processed) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	battle_results_manager.connect("rewards_calculated", _on_rewards_calculated) # warning: return value discarded (intentional)

	# Connect mission integrator signals

	@warning_ignore("return_value_discarded")
	mission_integrator.connect("mission_selected", _on_mission_selected) # warning: return value discarded (intentional)
	@warning_ignore("return_value_discarded")
	mission_integrator.connect("mission_preparation_complete", _on_mission_preparation_complete) # warning: return value discarded (intentional)

	# Connect equipment manager signals

	@warning_ignore("return_value_discarded")
	equipment_manager.connect("equipment_acquired", _on_equipment_acquired) # warning: return value discarded (intentional)

## Start a new campaign with initial setup
func start_new_campaign(campaign_data: Dictionary) -> void:
	if not _initialized:
		_initialize_systems()

	game_state.create_campaign(campaign_data)

	# Start with the setup phase
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.SETUP)

## Load an existing campaign
func load_campaign(campaign_data: Dictionary) -> void:
	if not _initialized:
		_initialize_systems()

	_loading = true

	game_state.load_campaign(campaign_data)

	# Initialize character manager with saved characters

	var characters: Array[Dictionary] = campaign_data.get("characters", [])
	for character_data in characters:
		character_manager.add_character(character_data)

	# Initialize equipment manager with saved equipment

	var equipment: Array[Dictionary] = campaign_data.get("equipment", [])
	for equipment_data in equipment:
		equipment_manager.add_equipment(equipment_data)

	# Restore character equipment assignments

	var char_equipment: Dictionary = campaign_data.get("character_equipment", {})
	for char_id in char_equipment:
		var equipment_list = char_equipment[char_id]
		for equipment_id in equipment_list:
			equipment_manager.assign_equipment_to_character(char_id, equipment_id)

	# Start in the appropriate phase

	var current_phase = campaign_data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.NONE)
	if current_phase != GlobalEnums.FiveParsecsCampaignPhase.NONE:
		campaign_phase_manager.start_phase(current_phase)

	_loading = false
	campaign_loaded.emit(campaign_data) # warning: return value discarded (intentional)

## Save the current campaign state
func save_campaign() -> Dictionary:
	if not game_state.current_campaign:
		push_error("No active campaign to save")
		return {}

	var campaign_data = game_state.serialize_campaign()

	# Add character data
	campaign_data["characters"] = []
	for character in character_manager.get_all_characters():
		campaign_data["characters"].append(character)

	# Add equipment data
	campaign_data["equipment"] = equipment_manager.get_all_equipment()

	# Add character equipment assignments
	campaign_data["character_equipment"] = {}
	for char_id in equipment_manager.get_all_equipment():
		campaign_data["character_equipment"][char_id] = equipment_manager.get_equipment_for_character(char_id)

	# Add current phase information
	campaign_data["current_phase"] = campaign_phase_manager.current_phase
	campaign_data["current_sub_phase"] = campaign_phase_manager.current_sub_phase

	return campaign_data

## Advance to the next campaign phase
func advance_to_next_phase() -> bool:
	var next_phase = _get_next_campaign_phase()
	if next_phase == GlobalEnums.FiveParsecsCampaignPhase.NONE:
		push_error("No valid next phase from current phase")
		return false

	return campaign_phase_manager.start_phase(next_phase)

## Get the next phase in the campaign sequence
func _get_next_campaign_phase() -> int:
	var current = campaign_phase_manager.current_phase

	match current:
		GlobalEnums.FiveParsecsCampaignPhase.NONE:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return GlobalEnums.FiveParsecsCampaignPhase.WORLD
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return GlobalEnums.FiveParsecsCampaignPhase.BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		_:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL # Default fallback

## Create a new character for the current campaign
func create_character(character_data: Dictionary) -> Dictionary:
	var new_character: Variant = character_manager.create_character()

	# Set character properties
	for key in character_data:
		if new_character and new_character.has_method("set"):
			new_character.set(key, character_data[key])
		else:
			new_character[key] = character_data[key]

	character_manager.update_character(new_character.get("id"), new_character)

	return new_character

## Process battle results and apply outcomes
func process_battle_results(battle_outcome: String) -> Dictionary:
	# Complete the battle with the specified _outcome
	var battle_results: Dictionary = battle_results_manager.complete_battle(battle_outcome)

	# Process casualties
	var casualties: Array[Dictionary] = battle_results_manager.process_casualties()

	# Check for potential rival generation
	if battle_outcome == BattleResultsManager.OUTCOME_VICTORY:
		_check_for_rival_generation(battle_results)

	return battle_results

## Calculate and apply experience from a battle
func process_battle_experience() -> Dictionary:
	var experience_data: Dictionary = battle_results_manager.get_experience_data()
	return experience_data

## Generate and process loot from a battle
func process_battle_loot() -> Array:
	var battle_data: Dictionary = battle_results_manager._current_battle

	var difficulty = battle_data.get("difficulty", 2)

	var success = battle_data.get("outcome", "") == BattleResultsManager.OUTCOME_VICTORY

	var loot_items: Array[Dictionary] = equipment_manager.generate_battle_loot(difficulty, success)

	# Add loot items to equipment storage
	for item in loot_items:
		equipment_manager.add_equipment(item)

	return loot_items

## Signal handlers

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	phase_changed.emit(old_phase, new_phase) # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_phase_error(error_message: String, is_critical: bool) -> void:
	push_error("Phase error: " + error_message)

	# Handle _critical errors
	if is_critical:
		# Attempt to recover
		if campaign_phase_manager.current_phase != GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.SETUP)
func _on_turn_advanced(new_turn: int) -> void:
	turn_advanced.emit(new_turn) # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_resources_changed(_resource: String, _amount: int) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_campaign_created(_campaign_data: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_campaign_loaded(_campaign_data: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_battle_results_recorded(results: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

	# If current phase is battle resolution, complete the "battle_completed" action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
		campaign_phase_manager.complete_phase_action("battle_completed")

@warning_ignore("unused_parameter")
func _on_casualties_processed(_casualties: Array) -> void:
	# If current phase is battle resolution, complete the "casualties_resolved" action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
		campaign_phase_manager.complete_phase_action("casualties_resolved")
@warning_ignore("unused_parameter")
func _on_rewards_calculated(_rewards: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_mission_selected(_mission: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

@warning_ignore("unused_parameter")
func _on_mission_preparation_complete(_mission: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

	# If current phase is campaign, complete the _mission preparation action
	if campaign_phase_manager.current_phase == GlobalEnums.FiveParsecsCampaignPhase.WORLD:
		campaign_phase_manager.complete_phase_action("mission_prepared")

@warning_ignore("unused_parameter")
func _on_equipment_acquired(_equipment_data: Dictionary) -> void:
	game_state_changed.emit() # warning: return value discarded (intentional)

## Public accessors for each manager

# Get the character manager
func get_character_manager() -> Node: # Returns CharacterManagerAutoload
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
	var rival_type: String = ""
	match source_type:
		"leader":
			rival_type = ["Enemy Commander", "Crime Boss", "Bounty Hunter", "Warlord"][randi() % 4]
		"mission":
			rival_type = ["Mercenary", "Criminal", "Alien Threat", "Military Officer"][randi() % 4]
		_:
			rival_type = "Unknown Rival"

	# Generate rival stats according to rulebook's Rival table
	var rival_data = {
		"id": "rival_" + str(randi() % 10000),
		"name": rival_type + " " + ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"][randi() % 5],
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

	# Add rival to game state
	game_state.rivals.append(rival_data)

	# Notify of rival generation (signal could be added to GameSystemManager)
	print("New rival generated: " + rival_data.name)

## Handle Patron relationships according to the rulebook
func process_patron_relationship(patron_id: String, mission_success: bool) -> void:
	var patrons = game_state.patrons if game_state.has("patrons") else []
	var patron_index = -1

	# Find patron by ID
	for i: int in range(patrons.size()):
		if patrons[i].get("id") == patron_id:
			patron_index = i
			break

	if patron_index >= 0:
		var patron = patrons[patron_index]

		# Update relationship based on mission _success
		if mission_success:
			patron.relationship = min(patron.get("relationship", 0) + 1, 5)
		else:
			patron.relationship = max(patron.get("relationship", 0) - 1, -3)

			# Check if patron relationship has deteriorated too much
			if patron.relationship <= -3:
				# According to rulebook, remove patron at relationship -3
				patrons.remove_at(patron_index)

				print("Patron relationship has deteriorated. Patron removed.")
				return

		# Update patron in game state
		patrons[patron_index] = patron
		game_state.patrons = patrons

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null