class_name CampaignCreationCoordinator
extends Node

## CampaignCreationCoordinator - Lightweight orchestration for campaign creation workflow
## Implements Coordinator Pattern to manage phase transitions and navigation state
## Extracted from CampaignCreationUI monolith to reduce complexity and improve maintainability

# GlobalEnums available as autoload singleton

# GDScript 2.0: Typed constants
const CampaignCreationStateManager := preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const AutoloadManager := preload("res://src/core/systems/AutoloadManager.gd")

# GDScript 2.0: Typed signals
signal navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
signal phase_transition_requested(from_phase: CampaignCreationStateManager.Phase, to_phase: CampaignCreationStateManager.Phase)
signal step_changed(step: int, total_steps: int)

# PHASE 2 INTEGRATION: Unified state management signals  
signal equipment_state_updated(equipment_data: Dictionary)
signal ship_state_updated(ship_data: Dictionary)
signal crew_state_updated(crew_data: Dictionary)
signal campaign_data_updated(campaign_data: Dictionary)
signal campaign_state_updated(state_data: Dictionary)

# GDScript 2.0: Typed member variables
var state_manager: CampaignCreationStateManager
var current_step: int = 0
var total_steps: int = 7 # CONFIG (includes victory), CAPTAIN_CREATION, CREW_SETUP, SHIP_ASSIGNMENT, EQUIPMENT_GENERATION, WORLD_GENERATION, FINAL_REVIEW

# Signal debouncing to prevent storm
var _navigation_update_pending: bool = false

# GDScript 2.0: Phase completion tracking (VICTORY_CONDITIONS removed)
var phase_completion_status: Dictionary = {
	CampaignCreationStateManager.Phase.CONFIG: false,  # Includes victory conditions
	# REMOVED: CampaignCreationStateManager.Phase.VICTORY_CONDITIONS
	CampaignCreationStateManager.Phase.CAPTAIN_CREATION: false,
	CampaignCreationStateManager.Phase.CREW_SETUP: false,
	CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT: false,
	CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION: false,
	CampaignCreationStateManager.Phase.WORLD_GENERATION: false,
	CampaignCreationStateManager.Phase.FINAL_REVIEW: false
}

# PHASE 2 INTEGRATION: Unified campaign state
var unified_campaign_state: Dictionary = {
	"crew": {
		"members": [],
		"captain": null,
		"patrons": [],
		"rivals": [],
		"starting_equipment": [],
		"is_complete": false
	},
	"equipment": {
		"items": [],
		"credits": 0,
		"is_complete": false
	},
	"ship": {
		"name": "",
		"type": "",
		"hull_points": 0,
		"max_hull": 0,
		"debt": 0,
		"is_complete": false
	},
	"captain": {
		"name": "",
		"character_name": "",  # SPRINT 5 FIX: Provide both keys for compatibility
		"background": "",
		"motivation": "",
		"is_complete": false
	},
	"difficulty": {
		"modifiers": {},
		"is_complete": false
	},
	"crew_flavor": {
		"flavor": "",
		"bonuses": {},
		"is_complete": false
	},
	# REMOVED: separate "victory_conditions" section - now merged into campaign_config
	"campaign_config": {
		"campaign_name": "",
		"campaign_type": "standard",
		"victory_conditions": {},  # Integrated here
		"story_track": "",
		"tutorial_mode": "",
		"is_complete": false
	},
	# SPRINT 5.3 FIX: World section for WorldInfoPanel integration
	"world": {
		"name": "",
		"type": "",
		"type_name": "",
		"danger_level": 1,
		"tech_level": 3,
		"government_type": "",
		"traits": [],
		"locations": [],
		"special_features": [],
		"opportunities": [],
		"threats": [],
		"is_complete": false
	},
	"is_complete": false
}

func _init(campaign_state_manager: CampaignCreationStateManager = null) -> void:
	if campaign_state_manager:
		state_manager = campaign_state_manager
	else:
		state_manager = CampaignCreationStateManager.new()
	
	_connect_state_manager_signals()
	_initialize_navigation_state()
	_initialize_unified_state()
	
	# CRITICAL: Connect to GameStateManager for system coordination
	_connect_to_game_state_manager()

func _connect_state_manager_signals() -> void:
	"""Connect to state manager signals for phase updates"""
	if state_manager:
		state_manager.state_updated.connect(_on_state_updated)
		state_manager.phase_completed.connect(_on_phase_completed)
		state_manager.validation_changed.connect(_on_validation_changed)

func _initialize_navigation_state() -> void:
	"""Initialize navigation state based on current phase"""
	current_step = int(state_manager.current_phase)
	_update_navigation_state()

# PHASE 2 INTEGRATION: Initialize unified state management
func _initialize_unified_state() -> void:
	"""Initialize unified campaign state management"""
	print("CampaignCreationCoordinator: Initializing unified state management")
	
	# Initialize default values
	unified_campaign_state.crew.members = []
	unified_campaign_state.crew.captain = null
	unified_campaign_state.crew.size = 6  # Default crew size per core rules (4, 5, or 6)
	unified_campaign_state.crew.is_complete = false

	unified_campaign_state.equipment.items = []
	unified_campaign_state.equipment.credits = 1000 # Default starting credits
	unified_campaign_state.equipment.is_complete = false
	
	unified_campaign_state.ship.name = "Wandering Star"
	unified_campaign_state.ship.type = "Worn Freighter"
	unified_campaign_state.ship.hull_points = 25
	unified_campaign_state.ship.max_hull = 30
	unified_campaign_state.ship.debt = 15
	unified_campaign_state.ship.is_complete = false
	
	unified_campaign_state.captain.name = ""
	unified_campaign_state.captain.character_name = ""  # SPRINT 5 FIX: Provide both keys
	unified_campaign_state.captain.background = ""
	unified_campaign_state.captain.motivation = ""
	unified_campaign_state.captain.is_complete = false
	
	unified_campaign_state.difficulty.modifiers = {}
	unified_campaign_state.difficulty.is_complete = false
	
	# SPRINT 5.3 FIX: Initialize world section for WorldInfoPanel integration
	unified_campaign_state["world"] = {
		"name": "",
		"type": "",
		"type_name": "",
		"danger_level": 1,
		"tech_level": 3,
		"government_type": "",
		"traits": [],
		"locations": [],
		"special_features": [],
		"opportunities": [],
		"threats": [],
		"is_complete": false
	}
	
	unified_campaign_state.is_complete = false
	
	print("CampaignCreationCoordinator: Unified state initialized")

# PHASE 2 INTEGRATION: Unified state management methods
func update_equipment_state(equipment_data: Dictionary) -> void:
	"""Update equipment state and emit signal"""
	print("CampaignCreationCoordinator: Updating equipment state")
	
	# Sprint 26.7: Standardized to equipment key (check legacy items key for backwards compat)
	if equipment_data.has("equipment"):
		unified_campaign_state.equipment.items = equipment_data.equipment
		print("CampaignCreationCoordinator: Equipment set from equipment key (%d items)" % equipment_data.equipment.size())
	elif equipment_data.has("items"):
		unified_campaign_state.equipment.items = equipment_data.items
		print("CampaignCreationCoordinator: Equipment set from items key (legacy, %d items)" % equipment_data.items.size())
	
	if equipment_data.has("credits"):
		unified_campaign_state.equipment.credits = equipment_data.credits
	elif equipment_data.has("starting_credits"):
		unified_campaign_state.equipment.credits = equipment_data.starting_credits
	if equipment_data.has("is_complete"):
		unified_campaign_state.equipment.is_complete = equipment_data.is_complete
	
	# Emit signals - both specific and campaign-wide
	equipment_state_updated.emit(unified_campaign_state.equipment)

	# CRITICAL FIX: Emit campaign_state_updated so all panels receive equipment data
	campaign_state_updated.emit({
		"equipment": unified_campaign_state.equipment,
		"crew": unified_campaign_state.crew,
		"captain": unified_campaign_state.captain,
		"phase": "equipment_update",
		"source": "equipment_panel"
	})

	# CORE FIX: Sync to StateManager for validation
	if state_manager:
		state_manager.set_phase_data(
			CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION,
			unified_campaign_state.equipment.duplicate()
		)
		print("CampaignCreationCoordinator: Synced equipment to StateManager")

	# Update overall completion status
	_update_campaign_completion_status()

func update_ship_state(ship_data: Dictionary) -> void:
	"""Update ship state and emit signal"""
	print("CampaignCreationCoordinator: Updating ship state")
	
	# Update ship data
	if ship_data.has("name"):
		unified_campaign_state.ship.name = ship_data.name
	if ship_data.has("type"):
		unified_campaign_state.ship.type = ship_data.type
	if ship_data.has("hull_points"):
		unified_campaign_state.ship.hull_points = ship_data.hull_points
	if ship_data.has("max_hull"):
		unified_campaign_state.ship.max_hull = ship_data.max_hull
	if ship_data.has("debt"):
		unified_campaign_state.ship.debt = ship_data.debt
	if ship_data.has("is_complete"):
		unified_campaign_state.ship.is_complete = ship_data.is_complete
	
	# Emit signals - both specific and campaign-wide
	ship_state_updated.emit(unified_campaign_state.ship)

	# CRITICAL FIX: Emit campaign_state_updated so all panels receive ship data
	campaign_state_updated.emit({
		"ship": unified_campaign_state.ship,
		"crew": unified_campaign_state.crew,
		"captain": unified_campaign_state.captain,
		"phase": "ship_update",
		"source": "ship_panel"
	})

	# CORE FIX: Sync to StateManager for validation
	if state_manager:
		state_manager.set_phase_data(
			CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT,
			unified_campaign_state.ship.duplicate()
		)
		print("CampaignCreationCoordinator: Synced ship to StateManager")

	# Update overall completion status
	_update_campaign_completion_status()

func update_crew_state(crew_data: Dictionary) -> void:
	"""Update crew state and emit signal"""
	print("CampaignCreationCoordinator: Updating crew state")

	# Update crew data - SPRINT 5 FIX: Normalize members through _character_to_dict
	if crew_data.has("members"):
		var normalized_members = []
		for member in crew_data.members:
			normalized_members.append(_character_to_dict(member))
		unified_campaign_state.crew.members = normalized_members
	# Store crew size (4/5/6) for EnemyGenerator and FinalPanel
	# Sprint 26.7: Standardized to crew_size key (check legacy keys for backwards compat)
	if crew_data.has("crew_size"):
		unified_campaign_state.crew.size = crew_data.crew_size
		print("CampaignCreationCoordinator: Crew size set to %d (from crew_size)" % crew_data.crew_size)
	elif crew_data.has("selected_size"):
		unified_campaign_state.crew.size = crew_data.selected_size
		print("CampaignCreationCoordinator: Crew size set to %d (from selected_size - legacy)" % crew_data.selected_size)
	elif crew_data.has("size") and crew_data.size > 0:
		unified_campaign_state.crew.size = crew_data.size
		print("CampaignCreationCoordinator: Crew size set to %d (from size - legacy)" % crew_data.size)
	if crew_data.has("captain"):
		# CROSS-PANEL DEPENDENCY FIX: Normalize captain to dictionary and sync
		var captain = crew_data.captain
		if captain != null:
			var captain_name = ""
			var captain_dict = {}

			# Handle Character object (Resource)
			if captain is Resource and "name" in captain:
				captain_name = captain.character_name if captain.get("character_name") else captain.name
				captain_dict = {
					"name": captain_name,
					"character_name": captain_name,
					"character": captain  # Keep reference to original object
				}
			# Handle Dictionary
			elif captain is Dictionary:
				captain_name = captain.get("character_name", captain.get("name", ""))
				captain_dict = captain.duplicate()
				if not captain_dict.has("name"):
					captain_dict["name"] = captain_name
				if not captain_dict.has("character_name"):
					captain_dict["character_name"] = captain_name

			# Store normalized dictionary
			unified_campaign_state.crew.captain = captain_dict

			if not captain_name.is_empty():
				unified_campaign_state.captain.name = captain_name
				unified_campaign_state.captain.is_complete = true
				print("CampaignCreationCoordinator: Synchronized crew captain '%s' with captain state" % captain_name)
		else:
			unified_campaign_state.crew.captain = crew_data.captain
		
	if crew_data.has("patrons"):
		unified_campaign_state.crew.patrons = crew_data.patrons
	if crew_data.has("rivals"):
		unified_campaign_state.crew.rivals = crew_data.rivals
	if crew_data.has("starting_equipment"):
		unified_campaign_state.crew.starting_equipment = crew_data.starting_equipment
	if crew_data.has("is_complete"):
		unified_campaign_state.crew.is_complete = crew_data.is_complete
	
	# SPRINT 26 FIX: Set has_captain flag if captain exists in crew data
	if crew_data.has("has_captain"):
		unified_campaign_state.crew.has_captain = crew_data.has_captain
	elif unified_campaign_state.crew.captain != null:
		unified_campaign_state.crew.has_captain = true

	# Emit signals - both specific and campaign-wide
	crew_state_updated.emit(unified_campaign_state.crew)

	# CRITICAL FIX: Emit campaign_state_updated so EquipmentPanel receives crew data
	campaign_state_updated.emit({
		"crew": unified_campaign_state.crew,
		"captain": unified_campaign_state.captain,
		"config": unified_campaign_state.get("campaign_config", {}),
		"phase": "crew_update",
		"source": "crew_panel"
	})

	# CORE FIX: Sync to StateManager for validation
	if state_manager:
		state_manager.set_phase_data(
			CampaignCreationStateManager.Phase.CREW_SETUP,
			unified_campaign_state.crew.duplicate()
		)
		print("CampaignCreationCoordinator: Synced crew to StateManager")

	# Update overall completion status
	_update_campaign_completion_status()

func update_captain_state(captain_data: Dictionary) -> void:
	"""Update captain state and emit signal"""
	print("CampaignCreationCoordinator: Updating captain state")

	# NORMALIZATION: Extract captain name from multiple possible locations
	var captain_name = ""
	if captain_data.has("name"):
		captain_name = captain_data.name
	elif captain_data.has("character_name"):
		captain_name = captain_data.character_name
	elif captain_data.has("captain") and captain_data.captain is Dictionary:
		captain_name = captain_data.captain.get("character_name", captain_data.captain.get("name", ""))

	# Update captain data - SPRINT 5 FIX: Provide BOTH keys for compatibility
	if not captain_name.is_empty():
		unified_campaign_state.captain.name = captain_name
		unified_campaign_state.captain.character_name = captain_name  # Normalize both keys
		print("CampaignCreationCoordinator: Set captain name to: %s" % captain_name)

	# Extract background from nested or top-level
	if captain_data.has("background"):
		unified_campaign_state.captain.background = captain_data.background
	elif captain_data.has("captain") and captain_data.captain is Dictionary:
		unified_campaign_state.captain.background = captain_data.captain.get("background", "")

	# Extract motivation from nested or top-level
	if captain_data.has("motivation"):
		unified_campaign_state.captain.motivation = captain_data.motivation
	elif captain_data.has("captain") and captain_data.captain is Dictionary:
		unified_campaign_state.captain.motivation = captain_data.captain.get("motivation", "")

	if captain_data.has("is_complete"):
		unified_campaign_state.captain.is_complete = captain_data.is_complete

	# CROSS-PANEL DEPENDENCY FIX: Synchronize captain with crew state
	# PHASE 10 FIX: Normalize Character objects to consistent dictionary format
	if captain_data.has("captain_character") and captain_data.captain_character != null:
		var captain_char = captain_data.captain_character
		# Normalize Character object to dictionary
		if captain_char is Resource or (captain_char is Object and captain_char.has_method("get")):
			var char_name = ""
			if captain_char.get("character_name"):
				char_name = captain_char.character_name
			elif captain_char.get("name"):
				char_name = captain_char.name
			unified_campaign_state.crew.captain = {
				"name": char_name,
				"character_name": char_name,
				"character": captain_char  # Keep reference
			}
			print("CampaignCreationCoordinator: Normalized captain_character to dictionary with name '%s'" % char_name)
		else:
			unified_campaign_state.crew.captain = captain_char
			print("CampaignCreationCoordinator: Synchronized captain_character with crew state")
	elif captain_data.has("captain") and captain_data.captain != null:
		var captain = captain_data.captain
		# Normalize Character object to dictionary
		if captain is Resource or (captain is Object and captain.has_method("get")):
			var char_name = ""
			if captain.get("character_name"):
				char_name = captain.character_name
			elif captain.get("name"):
				char_name = captain.name
			unified_campaign_state.crew.captain = {
				"name": char_name,
				"character_name": char_name,
				"character": captain  # Keep reference
			}
			print("CampaignCreationCoordinator: Normalized captain to dictionary with name '%s'" % char_name)
		else:
			unified_campaign_state.crew.captain = captain
			print("CampaignCreationCoordinator: Synchronized captain with crew state")
	
	# NEW: Mark phase complete if captain is valid
	var captain_complete = false
	if captain_data.has("is_complete") and captain_data.is_complete:
		captain_complete = true
	elif captain_data.has("captain_character") and captain_data.captain_character != null:
		# Alternative validation: has a captain object
		captain_complete = true
	elif captain_data.has("name") and not captain_data.name.is_empty():
		# Fallback validation: has a name
		captain_complete = true
	
	if captain_complete:
		phase_completion_status[CampaignCreationStateManager.Phase.CAPTAIN_CREATION] = true
		print("CampaignCreationCoordinator: Captain phase marked complete")
		_update_navigation_state()

	# SPRINT 26 FIX: Extract combat stats from Character for StateManager validation
	var captain_char = captain_data.get("captain_character", captain_data.get("captain", null))
	if captain_char != null and (captain_char is Dictionary or captain_char is Resource or (captain_char is Object and captain_char.has_method("get"))):
		# Extract stats that StateManager validation expects
		if "combat" in captain_char:
			unified_campaign_state.captain.combat = captain_char.combat if captain_char.combat else 1
		elif captain_char.get("combat"):
			unified_campaign_state.captain.combat = captain_char.get("combat")
		else:
			unified_campaign_state.captain.combat = 1  # Default

		if "toughness" in captain_char:
			unified_campaign_state.captain.toughness = captain_char.toughness if captain_char.toughness else 3
		elif captain_char.get("toughness"):
			unified_campaign_state.captain.toughness = captain_char.get("toughness")
		else:
			unified_campaign_state.captain.toughness = 3  # Default

		if "reactions" in captain_char:
			unified_campaign_state.captain.reactions = captain_char.reactions if captain_char.reactions else 1
		elif captain_char.get("reactions"):
			unified_campaign_state.captain.reactions = captain_char.get("reactions")
		else:
			unified_campaign_state.captain.reactions = 1

		if "savvy" in captain_char:
			unified_campaign_state.captain.savvy = captain_char.savvy if captain_char.savvy else 0
		elif captain_char.get("savvy"):
			unified_campaign_state.captain.savvy = captain_char.get("savvy")
		else:
			unified_campaign_state.captain.savvy = 0

		if "speed" in captain_char:
			unified_campaign_state.captain.speed = captain_char.speed if captain_char.speed else 4
		elif captain_char.get("speed"):
			unified_campaign_state.captain.speed = captain_char.get("speed")
		else:
			unified_campaign_state.captain.speed = 4

		print("CampaignCreationCoordinator: Extracted captain stats - Combat:%d Toughness:%d Reactions:%d" % [
			unified_campaign_state.captain.combat,
			unified_campaign_state.captain.toughness,
			unified_campaign_state.captain.reactions])

	# SPRINT 26 FIX: Set has_captain flag for StateManager validation
	if unified_campaign_state.crew.captain != null or captain_complete:
		unified_campaign_state.crew.has_captain = true
		print("CampaignCreationCoordinator: Set has_captain flag = true")

	# CRITICAL FIX: Emit campaign_state_updated so all panels receive captain data
	campaign_state_updated.emit({
		"captain": unified_campaign_state.captain,
		"crew": unified_campaign_state.crew,
		"config": unified_campaign_state.get("campaign_config", {}),
		"phase": "captain_update",
		"source": "captain_panel"
	})

	# CORE FIX: Sync to StateManager for validation
	if state_manager:
		state_manager.set_phase_data(
			CampaignCreationStateManager.Phase.CAPTAIN_CREATION,
			unified_campaign_state.captain.duplicate()
		)
		print("CampaignCreationCoordinator: Synced captain to StateManager")

	# Update overall completion status
	_update_campaign_completion_status()

func update_difficulty_state(difficulty_data: Dictionary) -> void:
	"""Update difficulty state and emit signal"""
	print("CampaignCreationCoordinator: Updating difficulty state")
	
	# Update difficulty data
	if difficulty_data.has("modifiers"):
		unified_campaign_state.difficulty.modifiers = difficulty_data.modifiers
	if difficulty_data.has("is_complete"):
		unified_campaign_state.difficulty.is_complete = difficulty_data.is_complete
	
	# Update overall completion status
	_update_campaign_completion_status()

func update_campaign_config_state(campaign_config_data: Dictionary) -> void:
	"""Update campaign config state and emit signal"""
	print("CampaignCreationCoordinator: Updating campaign config state")

	# Update campaign config data
	if campaign_config_data.has("campaign_name"):
		unified_campaign_state.campaign_config.campaign_name = campaign_config_data.campaign_name
	if campaign_config_data.has("campaign_type"):
		unified_campaign_state.campaign_config.campaign_type = campaign_config_data.campaign_type
	if campaign_config_data.has("victory_conditions"):
		unified_campaign_state.campaign_config.victory_conditions = campaign_config_data.victory_conditions
	if campaign_config_data.has("story_track"):
		unified_campaign_state.campaign_config.story_track = campaign_config_data.story_track
	if campaign_config_data.has("tutorial_mode"):
		unified_campaign_state.campaign_config.tutorial_mode = campaign_config_data.tutorial_mode
	if campaign_config_data.has("is_complete"):
		unified_campaign_state.campaign_config.is_complete = campaign_config_data.is_complete

	# SPRINT 5 FIX: Handle alternative key names for test compatibility
	if campaign_config_data.has("difficulty"):
		unified_campaign_state.campaign_config.difficulty = campaign_config_data.difficulty
	elif campaign_config_data.has("difficulty_level"):  # From ExpandedConfigPanel
		unified_campaign_state.campaign_config.difficulty = campaign_config_data.difficulty_level
		unified_campaign_state.campaign_config.difficulty_level = campaign_config_data.difficulty_level
	if campaign_config_data.has("victory_condition"):  # Singular form alias
		unified_campaign_state.campaign_config.victory_condition = campaign_config_data.victory_condition
	if campaign_config_data.has("story_track_enabled"):  # Alternative key name
		unified_campaign_state.campaign_config.story_track_enabled = campaign_config_data.story_track_enabled

	# CORE FIX: Sync to StateManager for validation
	if state_manager:
		state_manager.set_phase_data(
			CampaignCreationStateManager.Phase.CONFIG,
			unified_campaign_state.campaign_config.duplicate()
		)
		print("CampaignCreationCoordinator: Synced config to StateManager")

	# Update overall completion status
	_update_campaign_completion_status()

func update_victory_conditions_state(victory_conditions_data: Dictionary) -> void:
	"""Update victory conditions state and emit signal"""
	print("CampaignCreationCoordinator: Updating victory conditions state")
	
	# Ensure campaign_config exists and has victory_conditions section
	if not unified_campaign_state.has("campaign_config"):
		unified_campaign_state["campaign_config"] = {}
	if not unified_campaign_state.campaign_config.has("victory_conditions"):
		unified_campaign_state.campaign_config["victory_conditions"] = {}
	
	# Update victory conditions data in the correct location
	if victory_conditions_data.has("selected_conditions"):
		unified_campaign_state.campaign_config.victory_conditions["selected_conditions"] = victory_conditions_data.selected_conditions
	if victory_conditions_data.has("custom_conditions"):
		unified_campaign_state.campaign_config.victory_conditions["custom_conditions"] = victory_conditions_data.custom_conditions
	if victory_conditions_data.has("total_conditions"):
		unified_campaign_state.campaign_config.victory_conditions["total_conditions"] = victory_conditions_data.total_conditions
	if victory_conditions_data.has("is_complete"):
		unified_campaign_state.campaign_config.victory_conditions["is_complete"] = victory_conditions_data.is_complete
	
	# Update overall completion status
	_update_campaign_completion_status()

func _update_campaign_completion_status() -> void:
	"""Update overall campaign completion status"""
	var was_complete = unified_campaign_state.is_complete
	
	# Check if all major components are complete
	var victory_conditions_complete = unified_campaign_state.get("campaign_config", {}).get("victory_conditions", {}).get("is_complete", false)
	unified_campaign_state.is_complete = (
		unified_campaign_state.crew.is_complete and
		unified_campaign_state.equipment.is_complete and
		unified_campaign_state.ship.is_complete and
		unified_campaign_state.captain.is_complete and
		victory_conditions_complete and # Victory conditions now in campaign_config
		unified_campaign_state.difficulty.is_complete and
		unified_campaign_state.campaign_config.is_complete
	)
	
	# Emit campaign data updated signal
	campaign_data_updated.emit(unified_campaign_state)
	
	# Log completion status change
	if unified_campaign_state.is_complete and not was_complete:
		print("CampaignCreationCoordinator: Campaign creation completed!")
	elif not unified_campaign_state.is_complete and was_complete:
		print("CampaignCreationCoordinator: Campaign creation status changed to incomplete")

func _character_to_dict(character) -> Dictionary:
	"""Convert Character object or nested Dictionary to flat Dictionary for serialization"""
	if character == null:
		return {}

	# If already a flat Dictionary with all expected keys, return with normalized name keys
	if character is Dictionary and character.has("character_name") and character.has("background"):
		# NORMALIZATION FIX: Ensure both "name" and "character_name" keys exist
		if not character.has("name"):
			character["name"] = character.get("character_name", "")
		return character

	# Extract from Character object or Dictionary
	var result = {}

	# Helper to safely get property from Resource or Dictionary
	# Resource.get() takes 1 arg, Dictionary.get() takes 2
	var is_dict = character is Dictionary

	# Name handling - support both character_name and name
	var char_name = ""
	if is_dict:
		char_name = character.get("character_name", character.get("name", ""))
	else:
		# Resource - use property access with null check
		if "character_name" in character and character.character_name:
			char_name = character.character_name
		elif "name" in character and character.name:
			char_name = character.name
	if not char_name.is_empty():
		result["character_name"] = char_name
		result["name"] = char_name

	# Extract character properties with fallback names
	if "background" in character:
		result["background"] = character.background if not is_dict else character.get("background")
	if "motivation" in character:
		result["motivation"] = character.motivation if not is_dict else character.get("motivation")

	# Origin (with species fallback)
	if "origin" in character:
		result["origin"] = character.origin if not is_dict else character.get("origin")
	elif "species" in character:
		result["origin"] = character.species if not is_dict else character.get("species")

	# Character class (with class fallback)
	if "character_class" in character:
		result["character_class"] = character.character_class if not is_dict else character.get("character_class")
	elif "class" in character:
		result["character_class"] = character.get("class") if is_dict else null

	# Stats - use property access for Resource, .get() for Dictionary
	if "combat" in character:
		result["combat"] = character.combat if not is_dict else character.get("combat")
	elif "combat_skill" in character:
		result["combat"] = character.combat_skill if not is_dict else character.get("combat_skill")

	if "reactions" in character:
		result["reactions"] = character.reactions if not is_dict else character.get("reactions")
	elif "reaction" in character:
		result["reactions"] = character.reaction if not is_dict else character.get("reaction")

	if "toughness" in character:
		result["toughness"] = character.toughness if not is_dict else character.get("toughness")
	if "savvy" in character:
		result["savvy"] = character.savvy if not is_dict else character.get("savvy")
	if "tech" in character:
		result["tech"] = character.tech if not is_dict else character.get("tech")
	if "speed" in character:
		result["speed"] = character.speed if not is_dict else character.get("speed")
	if "luck" in character:
		result["luck"] = character.luck if not is_dict else character.get("luck")

	# XP/Experience (with fallback)
	if "xp" in character:
		result["xp"] = character.xp if not is_dict else character.get("xp")
	elif "experience" in character:
		result["xp"] = character.experience if not is_dict else character.get("experience")

	if "is_captain" in character:
		result["is_captain"] = character.is_captain if not is_dict else character.get("is_captain")

	# DISPLAY FIX: Preserve original Character object reference for CharacterCard display
	# CharacterCard.set_character() requires a Character object, not a Dictionary
	if not is_dict and character is Resource:
		result["character_object"] = character
	elif is_dict and character.has("character_object"):
		result["character_object"] = character.get("character_object")

	return result

func get_unified_campaign_state() -> Dictionary:
	"""Get the complete unified campaign state with Character objects converted to Dictionaries"""
	var state = unified_campaign_state.duplicate(true)

	# COMPATIBILITY FIX: Provide both "config" and "campaign_config" keys for test compatibility
	if state.has("campaign_config") and not state.has("config"):
		state["config"] = state["campaign_config"]

	# Convert crew members Array[Character] → Array[Dictionary]
	if state.crew.has("members") and state.crew.members is Array:
		var dict_members: Array[Dictionary] = []
		for member in state.crew.members:
			var member_dict = _character_to_dict(member)
			if not member_dict.is_empty():
				dict_members.append(member_dict)
		state.crew.members = dict_members

	# Convert captain Character → Dictionary if needed
	if state.crew.has("captain") and state.crew.captain != null:
		state.crew.captain = _character_to_dict(state.crew.captain)

	return state

func update_config_state(data: Dictionary) -> void:
	"""Alias to update_campaign_config_state() for API compatibility"""
	update_campaign_config_state(data)

func get_complete_campaign_state_for_panel(panel_name: String = "") -> Dictionary:
	"""Get complete campaign state with all data for panel consumption"""
	var complete_state = unified_campaign_state.duplicate(true)

	# COMPATIBILITY FIX: Provide both "config" and "campaign_config" keys for test compatibility
	if complete_state.has("campaign_config") and not complete_state.has("config"):
		complete_state["config"] = complete_state["campaign_config"]

	# Add completion status
	complete_state["completion_status"] = phase_completion_status.duplicate()
	
	# Add current phase information
	if state_manager:
		complete_state["current_phase"] = CampaignCreationStateManager.Phase.keys()[state_manager.current_phase]
	
	# Add metadata for panel debugging
	complete_state["_metadata"] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"requested_by": panel_name,
		"total_steps": total_steps,
		"current_step": current_step
	}
	
	print("CampaignCreationCoordinator: Providing complete state to %s with %d sections" % [panel_name, complete_state.keys().size()])
	
	return complete_state

func provide_initial_state_to_panel(panel: Control) -> void:
	"""Provide initial campaign state to panel when it becomes active"""
	if not panel:
		return
	
	var panel_name = panel.get_class() if panel else "unknown"
	print("CampaignCreationCoordinator: Providing initial state to %s" % panel_name)
	
	# Get complete state
	var complete_state = get_complete_campaign_state_for_panel(panel_name)
	
	# Send state to panel if it has the method
	if panel.has_method("_on_campaign_state_updated"):
		panel._on_campaign_state_updated(complete_state)
		print("CampaignCreationCoordinator: ✅ Initial state sent to %s" % panel_name)
	else:
		print("CampaignCreationCoordinator: ⚠️ Panel %s missing _on_campaign_state_updated method" % panel_name)

func get_campaign_data_for_save() -> Dictionary:
	"""Get campaign data formatted for saving"""
	var save_data = unified_campaign_state.duplicate(true)

	# COMPATIBILITY FIX: Provide both "config" and "campaign_config" keys
	if save_data.has("campaign_config") and not save_data.has("config"):
		save_data["config"] = save_data["campaign_config"]

	save_data["version"] = "1.0"
	save_data["created_date"] = Time.get_datetime_string_from_system()
	return save_data

func load_campaign_data_from_save(save_data: Dictionary) -> void:
	"""Load campaign data from saved data"""
	if save_data.has("crew"):
		update_crew_state(save_data.crew)
	if save_data.has("equipment"):
		update_equipment_state(save_data.equipment)
	if save_data.has("ship"):
		update_ship_state(save_data.ship)
	if save_data.has("captain"):
		update_captain_state(save_data.captain)
	if save_data.has("victory_conditions"): # NEW
		update_victory_conditions_state(save_data.victory_conditions)
	if save_data.has("difficulty"):
		update_difficulty_state(save_data.difficulty)
	if save_data.has("campaign_config"):
		update_campaign_config_state(save_data.campaign_config)
	
	print("CampaignCreationCoordinator: Campaign data loaded from save")

## Public API - Navigation Control

# API Aliases for test compatibility
var current_panel_index: int:
	get:
		return current_step
	set(value):
		current_step = value

func get_current_panel() -> Control:
	"""Get the current panel - requires CampaignCreationUI parent reference"""
	# Look for parent CampaignCreationUI that has panels
	var parent = get_parent()
	if parent and parent.has_method("get_current_panel"):
		return parent.get_current_panel()
	return null

func next_panel() -> bool:
	"""Alias for advance_to_next_phase - provides API compatibility"""
	return advance_to_next_phase()

func previous_panel() -> bool:
	"""Alias for go_back_to_previous_phase - provides API compatibility"""
	return go_back_to_previous_phase()

func can_advance_to_next_phase() -> bool:
	"""Check if we can advance to the next phase"""
	var current_phase = state_manager.current_phase
	
	# Special case: Allow advancing from CONFIG phase even if empty for initial setup
	if current_phase == CampaignCreationStateManager.Phase.CONFIG:
		return true
	
	# Check if current phase is completed
	return phase_completion_status.get(current_phase, false)

func advance_to_next_phase() -> bool:
	"""Advance to the next phase if possible"""
	if not can_advance_to_next_phase():
		return false
	
	var current_phase = state_manager.current_phase
	var next_phase_int = int(current_phase) + 1
	
	if next_phase_int >= CampaignCreationStateManager.Phase.FINAL_REVIEW + 1:
		return false # Already at final phase
	
	var next_phase = CampaignCreationStateManager.Phase.values()[next_phase_int]
	phase_transition_requested.emit(current_phase, next_phase)
	
	if state_manager.advance_to_next_phase():
		current_step = next_phase_int
		_update_navigation_state()
		return true
	
	return false

func can_go_back_to_previous_phase() -> bool:
	"""Check if we can go back to the previous phase"""
	return current_step > 0

func go_back_to_previous_phase() -> bool:
	"""Go back to the previous phase if possible"""
	if not can_go_back_to_previous_phase():
		return false
	
	var current_phase = state_manager.current_phase
	var previous_phase_int = int(current_phase) - 1
	
	if previous_phase_int < 0:
		return false
	
	var previous_phase = CampaignCreationStateManager.Phase.values()[previous_phase_int]
	phase_transition_requested.emit(current_phase, previous_phase)
	
	if state_manager.go_to_previous_phase():
		current_step = previous_phase_int
		_update_navigation_state()
		return true
	
	return false

func set_phase_completion_status(phase: int, is_complete: bool) -> void:
	"""Set completion status for a phase - used by tests and UI validation"""
	if phase in phase_completion_status:
		phase_completion_status[phase] = is_complete

func can_finish_campaign_creation() -> bool:
	"""Check if all phases are complete and we can finish"""
	# Must be at FINAL_REVIEW phase or beyond
	if state_manager.current_phase < CampaignCreationStateManager.Phase.FINAL_REVIEW:
		return false
	
	# Check all critical phases are completed
	var required_phases = [
		CampaignCreationStateManager.Phase.CONFIG,
		CampaignCreationStateManager.Phase.CREW_SETUP,
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION,
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION
	]
	
	for phase in required_phases:
		if not phase_completion_status.get(phase, false):
			return false
	
	return true

## Phase Status Management

func mark_phase_complete(phase: CampaignCreationStateManager.Phase, is_complete: bool = true) -> void:
	"""Mark a specific phase as complete or incomplete"""
	phase_completion_status[phase] = is_complete
	_update_navigation_state()

func get_phase_completion_status(phase: CampaignCreationStateManager.Phase) -> bool:
	"""Get completion status for a specific phase"""
	return phase_completion_status.get(phase, false)

func get_overall_completion_percentage() -> float:
	"""Get overall completion percentage across all phases"""
	var completed_count = 0
	var total_count = phase_completion_status.size()
	
	for phase in phase_completion_status:
		if phase_completion_status[phase]:
			completed_count += 1
	
	return float(completed_count) / float(total_count)

## State Manager Event Handlers

func _on_state_updated(phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	"""Handle state manager updates"""
	current_step = int(phase)
	_update_navigation_state()

func _on_phase_completed(phase: CampaignCreationStateManager.Phase) -> void:
	"""Handle phase completion from state manager"""
	mark_phase_complete(phase, true)

func _on_validation_changed(is_valid: bool, errors: Array) -> void:
	"""Handle validation changes from state manager"""
	# Update navigation based on current phase validation
	_update_navigation_state()

## Internal Navigation Logic

func _update_navigation_state() -> void:
	"""Centralized navigation state update - single source of truth with debouncing"""
	# Debounce: Skip if update already scheduled
	if _navigation_update_pending:
		return
	_navigation_update_pending = true
	call_deferred("_do_navigation_update")

func _do_navigation_update() -> void:
	"""Execute the actual navigation state update"""
	_navigation_update_pending = false

	var nav_state = _calculate_navigation_state()

	# Emit consolidated navigation signals
	navigation_updated.emit(nav_state.can_go_back, nav_state.can_go_forward, nav_state.can_finish)
	step_changed.emit(nav_state.current_step, nav_state.total_steps)

	# Debug logging for navigation state changes
	print("CampaignCreationCoordinator: Navigation updated - Back:%s Forward:%s Finish:%s Step:%d/%d" % [
		nav_state.can_go_back, nav_state.can_go_forward, nav_state.can_finish,
		nav_state.current_step, nav_state.total_steps
	])

func _calculate_navigation_state() -> Dictionary:
	"""Calculate complete navigation state in one place"""
	return {
		"can_go_back": can_go_back_to_previous_phase(),
		"can_go_forward": can_advance_to_next_phase(),
		"can_finish": can_finish_campaign_creation(),
		"current_step": current_step,
		"total_steps": total_steps,
		"current_phase": state_manager.current_phase if state_manager else 0,
		"completion_percentage": get_overall_completion_percentage()
	}

## Debug and Information

func get_current_phase_name() -> String:
	"""Get human-readable name for current phase"""
	match state_manager.current_phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"

func get_navigation_state() -> Dictionary:
	"""Get current navigation state for UI updates - uses centralized calculation"""
	var nav_state = _calculate_navigation_state()
	nav_state["current_phase_name"] = get_current_phase_name()
	return nav_state

func get_debug_info() -> Dictionary:
	"""Get debug information about coordinator state - uses centralized navigation"""
	var debug_info = _calculate_navigation_state()
	debug_info["current_phase_name"] = get_current_phase_name()
	debug_info["phase_completion_status"] = phase_completion_status
	debug_info["overall_completion"] = get_overall_completion_percentage()
	return debug_info

## Campaign Finalization

func finalize_campaign() -> Dictionary:
	"""Finalize campaign creation by aggregating all phase data"""
	print("CampaignCreationCoordinator: Finalizing campaign creation...")
	
	# Validate all required phases are complete
	var validation_result = _validate_campaign_completion()
	if not validation_result.valid:
		print("CampaignCreationCoordinator: Campaign finalization failed validation: ", validation_result.errors)
		return {
			"success": false,
			"error": "Campaign validation failed",
			"errors": validation_result.errors,
			"completion_percentage": get_overall_completion_percentage()
		}
	
	# Aggregate all phase data
	var finalized_campaign_data = _aggregate_all_phase_data()
	
	# Add finalization metadata
	finalized_campaign_data["finalization"] = {
		"finalized_at": Time.get_datetime_string_from_system(),
		"finalized_by": "CampaignCreationCoordinator",
		"version": "1.0",
		"completion_percentage": get_overall_completion_percentage(),
		"total_phases": total_steps,
		"coordinator_state": get_debug_info()
	}
	
	print("CampaignCreationCoordinator: ✅ Campaign finalization complete")
	return {
		"success": true,
		"campaign_data": finalized_campaign_data,
		"completion_percentage": get_overall_completion_percentage()
	}

func _validate_campaign_completion() -> Dictionary:
	"""Validate that campaign is ready for finalization"""
	var errors: Array[String] = []
	
	# Check minimum required phases
	var required_phases = [
		CampaignCreationStateManager.Phase.CONFIG,
		CampaignCreationStateManager.Phase.CREW_SETUP,
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION
	]
	
	for phase in required_phases:
		if not phase_completion_status.get(phase, false):
			errors.append("Required phase not complete: %s" % get_phase_name(phase))
	
	# Check overall completion percentage
	var completion_pct = get_overall_completion_percentage()
	if completion_pct < 75.0: # Require at least 75% completion
		errors.append("Campaign is only %.1f%% complete. Need at least 75%% for finalization." % completion_pct)
	
	# Validate state manager has data
	if not state_manager:
		errors.append("State manager is not available.")
	else:
		var validation_summary = state_manager.get_validation_summary()
		if validation_summary.get("has_critical_errors", false):
			errors.append("Campaign has critical validation errors.")
	
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}

func _aggregate_all_phase_data() -> Dictionary:
	"""Aggregate data from all phases into final campaign structure"""
	if not state_manager:
		return {}
	
	var campaign_data = {
		"config": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CONFIG),
		"crew": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP),
		"captain": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION),
		"ship": state_manager.get_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT),
		"equipment": state_manager.get_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION),
		"world": state_manager.get_phase_data(CampaignCreationStateManager.Phase.WORLD_GENERATION),
		"validation_summary": state_manager.get_validation_summary(),
		"completion_status": state_manager.get_completion_status(),
		"phase_completion": phase_completion_status.duplicate()
	}
	
	# CRITICAL FIX: Include victory condition data from config phase
	var config_data = campaign_data.get("config", {})
	if config_data.has("victory_condition"):
		campaign_data["victory_condition"] = config_data.get("victory_condition")
		campaign_data["story_track_enabled"] = config_data.get("story_track_enabled", false)
		print("CampaignCreationCoordinator: Victory condition '%s' included in campaign data" % config_data.get("victory_condition", "none"))
	else:
		print("CampaignCreationCoordinator: Warning - No victory condition found in config data")
	
	print("CampaignCreationCoordinator: Aggregated %d phases of campaign data" % campaign_data.keys().size())
	return campaign_data

func get_phase_name(phase: CampaignCreationStateManager.Phase) -> String:
	"""Get human-readable name for any phase"""
	match phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.WORLD_GENERATION:
			return "World Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"

# Additional state update methods for UI integration
func update_campaign_name(name: String) -> void:
	"""Update campaign name"""
	print("CampaignCreationCoordinator: Updating campaign name: %s" % name)
	unified_campaign_state["campaign_config"]["campaign_name"] = name
	campaign_data_updated.emit(unified_campaign_state)

func update_difficulty(difficulty: int) -> void:
	"""Update difficulty setting"""
	print("CampaignCreationCoordinator: Updating difficulty: %d" % difficulty)
	unified_campaign_state["difficulty"]["modifiers"]["level"] = difficulty
	campaign_data_updated.emit(unified_campaign_state)

func update_ironman_mode(enabled: bool) -> void:
	"""Update ironman mode setting"""
	print("CampaignCreationCoordinator: Updating ironman mode: %s" % enabled)
	unified_campaign_state["difficulty"]["modifiers"]["ironman"] = enabled
	campaign_data_updated.emit(unified_campaign_state)

func add_crew_member(member_data: Dictionary) -> void:
	"""Add a crew member"""
	print("CampaignCreationCoordinator: Adding crew member")
	unified_campaign_state["crew"]["members"].append(member_data)
	campaign_data_updated.emit(unified_campaign_state)

func update_world_state(world_data: Dictionary) -> void:
	"""Update world state"""
	print("CampaignCreationCoordinator: Updating world state")
	unified_campaign_state["world"] = world_data
	unified_campaign_state["world"]["is_complete"] = true
	phase_completion_status[CampaignCreationStateManager.Phase.WORLD_GENERATION] = true
	campaign_data_updated.emit(unified_campaign_state)

func update_review_state(review_data: Dictionary) -> void:
	"""Update review state"""
	print("CampaignCreationCoordinator: Updating review state")
	unified_campaign_state["review"] = review_data
	unified_campaign_state["review"]["is_complete"] = true
	phase_completion_status[CampaignCreationStateManager.Phase.FINAL_REVIEW] = true
	campaign_data_updated.emit(unified_campaign_state)

func update_validation_state(validation_data: Dictionary) -> void:
	"""Update validation state"""
	print("CampaignCreationCoordinator: Updating validation state")
	unified_campaign_state["validation"] = validation_data
	campaign_data_updated.emit(unified_campaign_state)

# GDScript 2.0: Typed function for victory condition validation
func _has_victory_condition_selected(conditions: Dictionary) -> bool:
	"""Check if at least one victory condition is selected"""
	for key: String in conditions:
		if conditions.get(key, false) == true:
			return true
	return false

# GDScript 2.0: Enhanced CONFIG phase validation with victory conditions
func update_phase_validation(phase: CampaignCreationStateManager.Phase, is_valid: bool) -> void:
	"""Update phase validation with special handling for CONFIG phase"""
	if phase == CampaignCreationStateManager.Phase.CONFIG:
		# Special validation for CONFIG with victory conditions
		var config: Dictionary = unified_campaign_state.get("campaign_config", {})
		var has_name: bool = not config.get("campaign_name", "").is_empty()
		var has_victory: bool = _has_victory_condition_selected(config.get("victory_conditions", {}))
		phase_completion_status[phase] = has_name and has_victory
	else:
		phase_completion_status[phase] = is_valid
	_update_navigation_state()


# CRITICAL: GameStateManager Integration
var game_state_manager: Node = null

func _connect_to_game_state_manager() -> void:
	"""Connect to GameStateManager autoload for system coordination"""
	game_state_manager = AutoloadManager.get_autoload_safe("GameStateManager")
	if not game_state_manager:
		push_warning("CampaignCreationCoordinator: GameStateManager not available - some features disabled")
		return
	
	print("CampaignCreationCoordinator: Connected to GameStateManager")
	
	# Register coordinator with game state
	if game_state_manager.has_method("register_campaign_coordinator"):
		game_state_manager.register_campaign_coordinator(self)
		print("CampaignCreationCoordinator: Registered with GameStateManager")

# ============ SPRINT 5.1.2: PANEL INTEGRATION METHODS ============
# Methods to connect existing panels with coordinator state management

func pass_coordinator_to_panel(panel: Control) -> void:
	"""Properly pass coordinator reference to panels - Sprint 5.1.2 integration fix"""
	if not panel:
		push_error("CampaignCreationCoordinator: Cannot pass coordinator to null panel")
		return
	
	print("CampaignCreationCoordinator: Passing coordinator to panel: %s" % panel.name)
	
	# Method 1: Set coordinator reference directly
	if panel.has_method("set_coordinator"):
		panel.set_coordinator(self)
		print("  ✓ Set coordinator reference via set_coordinator()")
	else:
		# Fallback: Set _coordinator property directly
		if "_coordinator" in panel:
			panel._coordinator = self
			print("  ✓ Set _coordinator property directly")
	
	# Method 2: Set state manager reference if panel supports it
	if panel.has_method("set_state_manager"):
		panel.set_state_manager(state_manager)
		print("  ✓ Set state manager reference")
	
	# Method 3: Set phase key for state synchronization
	var phase_key: String = _get_phase_key_for_panel(panel)
	if phase_key != "":
		if panel.has_method("set_panel_phase_key"):
			panel.call("set_panel_phase_key", phase_key)  # Use call() to avoid type warning
			print("  ✓ Set phase key: %s" % phase_key)
		elif "panel_phase_key" in panel:
			panel.panel_phase_key = phase_key
			print("  ✓ Set panel_phase_key property: %s" % phase_key)
	
	# Method 4: Trigger initial sync if panel supports it
	if panel.has_method("sync_with_coordinator"):
		panel.call_deferred("sync_with_coordinator")
		print("  ✓ Triggered initial coordinator sync")
	
	print("CampaignCreationCoordinator: Panel integration complete for %s" % panel.name)

func _get_phase_key_for_panel(panel: Control) -> String:
	"""Get the appropriate phase key for a panel based on its type"""
	if not panel:
		return ""

	var panel_name: String = panel.name.to_lower()
	var panel_class: String = panel.get_class()
	
	# Map panel names/types to unified state keys
	if "config" in panel_name or "setup" in panel_name:
		return "campaign_config"
	elif "captain" in panel_name:
		return "captain"
	elif "crew" in panel_name:
		return "crew"
	elif "ship" in panel_name:
		return "ship"
	elif "equipment" in panel_name:
		return "equipment"
	elif "world" in panel_name:
		return "world"
	elif "final" in panel_name or "review" in panel_name:
		return "review"
	else:
		# Default mapping - try to infer from panel class
		if panel_class == "EquipmentPanel":
			return "equipment"
		elif panel_class == "CrewPanel":
			return "crew"
		elif panel_class == "CaptainPanel":
			return "captain"
		elif panel_class == "ShipPanel":
			return "ship"
		elif panel_class == "WorldInfoPanel":
			return "world"
		elif panel_class == "ConfigPanel":
			return "campaign_config"
		elif panel_class == "FinalPanel":
			return "review"
	
	print("CampaignCreationCoordinator: Could not determine phase key for panel: %s (%s)" % [panel_name, panel_class])
	return ""

func connect_all_panels_to_coordinator(panels: Array) -> void:
	"""Connect multiple panels to coordinator in batch - Sprint 5.1.2 mass integration"""
	print("CampaignCreationCoordinator: Connecting %d panels to coordinator" % panels.size())
	
	var success_count: int = 0
	for panel: Variant in panels:
		if panel is Control:
			pass_coordinator_to_panel(panel as Control)  # Cast to Control for type safety
			success_count += 1
		else:
			push_warning("CampaignCreationCoordinator: Invalid panel type: %s" % typeof(panel))
	
	print("CampaignCreationCoordinator: Successfully connected %d/%d panels" % [success_count, panels.size()])

func refresh_panel_state_sync(panel: Control) -> void:
	"""Refresh state synchronization for a specific panel - useful for debugging"""
	if not panel:
		return

	print("CampaignCreationCoordinator: Refreshing state sync for panel: %s" % panel.name)

	# Get current state for panel's phase
	var phase_key = _get_phase_key_for_panel(panel)
	if phase_key != "" and unified_campaign_state.has(phase_key):
		var state_data = unified_campaign_state.duplicate()
		if panel.has_method("_on_campaign_state_updated"):
			panel._on_campaign_state_updated(state_data)
			print("  ✓ Sent state update to panel")
		else:
			print("  ⚠️ Panel does not support _on_campaign_state_updated")
	else:
		print("  ⚠️ No state data available for phase key: %s" % phase_key)

func reset_to_beginning() -> void:
	"""Reset coordinator to initial state for restart"""
	print("CampaignCreationCoordinator: Resetting to beginning")

	# Reset current step
	current_step = 0

	# Reset phase completion status
	for phase in phase_completion_status.keys():
		phase_completion_status[phase] = false

	# Reset state manager to first phase
	if state_manager:
		state_manager.current_phase = CampaignCreationStateManager.Phase.CONFIG

	# Reset unified campaign state to defaults
	unified_campaign_state = {
		"campaign_config": {},
		"captain": {},
		"crew": {"members": [], "captain": null},
		"equipment": {"items": [], "credits": 0},
		"ship": {},
		"difficulty": {},
		"victory_conditions": {},
		"is_complete": false
	}

	# Emit reset signal
	campaign_data_updated.emit(unified_campaign_state)
	print("CampaignCreationCoordinator: Reset complete")
