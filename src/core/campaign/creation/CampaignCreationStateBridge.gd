class_name CampaignCreationStateBridgeClass
extends Node

## Campaign Creation State Bridge
## Provides centralized state coordination between CampaignCreationStateManager and individual scenes
## Manages scene transitions, state preservation, and navigation history

const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SceneRouter = preload("res://src/ui/screens/SceneRouter.gd")

# Singleton reference - this will be an autoload
static var instance: CampaignCreationStateBridgeClass = null

# State management
var state_manager: CampaignCreationStateManager = null
var scene_router: SceneRouter = null

# Scene transition data
var scene_history: Array[String] = []
var current_scene: String = ""
var scene_context: Dictionary = {}
var scene_contexts: Dictionary = {} # Scene contexts for each scene
var scene_states: Dictionary = {} # Saved states for each scene

# Campaign creation flow definition
const CAMPAIGN_FLOW_SCENES = [
	"campaign_setup",
	"crew_creation",
	"character_creator", # Used for character editing
	"equipment_generation",
	"final_review",
	"campaign_turn_controller"
]

# Scene validation states
var scene_validation_states: Dictionary = {}

# Signals for scene coordination
signal scene_transition_started(from_scene: String, to_scene: String, context: Dictionary)
signal scene_transition_completed(scene: String, context: Dictionary)
signal scene_validation_changed(scene: String, is_valid: bool)
signal campaign_creation_progress_updated(completed_scenes: Array[String], current_scene: String)
signal state_saved(scene: String, state_data: Dictionary)
signal state_restored(scene: String, state_data: Dictionary)
signal auto_save_completed(save_path: String)
signal recovery_data_found(recovery_data: Dictionary)

func _init() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("CampaignCreationStateBridge: Multiple instances detected")

func _ready() -> void:
	_initialize_systems()
	# Initialize auto-save timer
	_setup_auto_save_timer()

func _initialize_systems() -> void:
	## Initialize state manager and scene router connections
	# Initialize state manager
	state_manager = CampaignCreationStateManager.new()
	if state_manager:
		_connect_state_manager_signals()
	else:
		push_error("CampaignCreationStateBridge: Failed to create state manager")
	
	# Connect to scene router
	scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router:
		_connect_scene_router_signals()
	else:
		push_warning("CampaignCreationStateBridge: Scene router not found, will retry on scene transitions")

func _connect_state_manager_signals() -> void:
	## Connect to state manager signals
	if not state_manager:
		return
	
	if state_manager.has_signal("state_updated"):
		state_manager.state_updated.connect(_on_state_manager_updated)
	if state_manager.has_signal("validation_changed"):
		state_manager.validation_changed.connect(_on_state_validation_changed)
	if state_manager.has_signal("phase_completed"):
		state_manager.phase_completed.connect(_on_phase_completed)
	if state_manager.has_signal("creation_completed"):
		state_manager.creation_completed.connect(_on_creation_completed)

func _connect_scene_router_signals() -> void:
	## Connect to scene router signals
	if not scene_router:
		return
	
	if scene_router.has_signal("scene_changed"):
		scene_router.scene_changed.connect(_on_scene_changed)
	if scene_router.has_signal("navigation_error"):
		scene_router.navigation_error.connect(_on_navigation_error)

## Scene Transition Management

func transition_to_scene(scene_name: String, context: Dictionary = {}) -> void:
	## Transition to a new scene with state preservation
	
	# Save current scene state if we have a current scene
	if not current_scene.is_empty():
		save_current_scene_state()
	
	# Emit transition started signal
	scene_transition_started.emit(current_scene, scene_name, context)
	
	# Store context for the new scene
	scene_context = context.duplicate()
	
	# Update scene history
	if not current_scene.is_empty():
		scene_history.append(current_scene)
	
	# Ensure scene router is available
	if not scene_router:
		scene_router = get_node_or_null("/root/SceneRouter")
	
	if scene_router and scene_router.has_method("navigate_to"):
		# Use scene router for navigation
		scene_router.navigate_to(scene_name, context)
		current_scene = scene_name
	else:
		push_error("CampaignCreationStateBridge: Scene router not available for transition to %s" % scene_name)

func return_to_previous_scene() -> void:
	## Return to the previous scene in history
	if scene_history.is_empty():
		push_warning("CampaignCreationStateBridge: No previous scene to return to")
		return
	
	var previous_scene = scene_history.pop_back()
	
	# Restore previous scene context if available
	var restored_context = scene_states.get(previous_scene, {})
	transition_to_scene(previous_scene, restored_context)

func get_next_scene_in_flow(current: String) -> String:
	## Get the next scene in the campaign creation flow
	var current_index = CAMPAIGN_FLOW_SCENES.find(current)
	if current_index >= 0 and current_index < CAMPAIGN_FLOW_SCENES.size() - 1:
		return CAMPAIGN_FLOW_SCENES[current_index + 1]
	return ""

func get_previous_scene_in_flow(current: String) -> String:
	## Get the previous scene in the campaign creation flow
	var current_index = CAMPAIGN_FLOW_SCENES.find(current)
	if current_index > 0:
		return CAMPAIGN_FLOW_SCENES[current_index - 1]
	return ""

## State Management

func save_current_scene_state() -> void:
	## Save the current scene's state
	if current_scene.is_empty():
		return
	
	var scene_data = {
		"context": scene_context.duplicate(),
		"timestamp": Time.get_unix_time_from_system(),
		"validation_state": scene_validation_states.get(current_scene, false)
	}
	
	# Add state manager data for the current phase
	if state_manager:
		scene_data["campaign_data"] = state_manager.get_campaign_data()
		scene_data["current_phase"] = state_manager.get_current_phase()
	
	scene_states[current_scene] = scene_data
	state_saved.emit(current_scene, scene_data)

func restore_scene_state(scene_name: String) -> Dictionary:
	## Restore state for a specific scene
	var scene_data = scene_states.get(scene_name, {})
	if not scene_data.is_empty():
		state_restored.emit(scene_name, scene_data)
	
	return scene_data

func get_scene_context() -> Dictionary:
	## Get the current scene context
	return scene_context.duplicate()

func update_scene_context(new_context: Dictionary) -> void:
	## Update the current scene context
	scene_context.merge(new_context)

## Campaign Data Management

func update_campaign_data(phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	## Update campaign data for a specific phase
	if not state_manager:
		push_error("CampaignCreationStateBridge: State manager not available")
		return
	
	state_manager.update_phase_data(phase, data)

func get_campaign_data() -> Dictionary:
	## Get the current campaign data
	if state_manager:
		return state_manager.get_campaign_data()
	return {}

func validate_current_phase() -> bool:
	## Validate the current phase data
	if state_manager:
		return state_manager.validate_current_phase()
	return false

func can_proceed_to_next_phase() -> bool:
	## Check if we can proceed to the next phase
	return validate_current_phase()

## Scene-Specific Data Handlers

func handle_crew_creation_data(crew_data: Dictionary) -> void:
	## Handle crew creation completion
	update_campaign_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)
	
	# Mark crew creation as complete
	scene_validation_states["crew_creation"] = true
	scene_validation_changed.emit("crew_creation", true)
	

func handle_character_update(character: Character) -> void:
	## Handle character updates from CharacterCreator
	# Update the character in the current campaign data
	var campaign_data = get_campaign_data()
	var crew_data = campaign_data.get("crew", {})
	
	# Find and update the character in crew data
	var crew_members = crew_data.get("crew_members", [])
	for i in range(crew_members.size()):
		if crew_members[i].character_name == character.character_name:
			crew_members[i] = character
			break
	
	# Update campaign data
	crew_data["crew_members"] = crew_members
	update_campaign_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)
	

func handle_equipment_generation(equipment_data: Dictionary) -> void:
	## Handle equipment generation completion
	update_campaign_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, equipment_data)
	
	# Mark equipment generation as complete  
	scene_validation_states["equipment_generation"] = true
	scene_validation_changed.emit("equipment_generation", true)
	

func handle_campaign_config(config_data: Dictionary) -> void:
	## Handle campaign configuration data
	update_campaign_data(CampaignCreationStateManager.Phase.CONFIG, config_data)
	
	# Mark config as complete
	scene_validation_states["campaign_setup"] = true
	scene_validation_changed.emit("campaign_setup", true)
	

## Progress Tracking

func get_creation_progress() -> Dictionary:
	## Get campaign creation progress
	var completed_scenes: Array[String] = []
	
	for scene_name in CAMPAIGN_FLOW_SCENES:
		if scene_validation_states.get(scene_name, false):
			completed_scenes.append(scene_name)
	
	return {
		"completed_scenes": completed_scenes,
		"current_scene": current_scene,
		"total_scenes": CAMPAIGN_FLOW_SCENES.size(),
		"completion_percentage": float(completed_scenes.size()) / float(CAMPAIGN_FLOW_SCENES.size()) * 100.0
	}

func is_campaign_creation_complete() -> bool:
	## Check if campaign creation is complete
	for scene_name in CAMPAIGN_FLOW_SCENES:
		if scene_name == "character_creator": # Skip character creator as it's optional
			continue
		if not scene_validation_states.get(scene_name, false):
			return false
	return true

## Signal Handlers

func _on_state_manager_updated(phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	## Handle state manager updates
	pass

func _on_state_validation_changed(is_valid: bool, errors: Array) -> void:
	## Handle state validation changes
	if not current_scene.is_empty():
		scene_validation_states[current_scene] = is_valid
		scene_validation_changed.emit(current_scene, is_valid)

func _on_phase_completed(phase: CampaignCreationStateManager.Phase) -> void:
	## Handle phase completion
	
	# Update progress
	var progress = get_creation_progress()
	campaign_creation_progress_updated.emit(progress.completed_scenes, current_scene)

func _on_creation_completed(campaign_data: Dictionary) -> void:
	## Handle campaign creation completion
	
	# Navigate to campaign dashboard
	transition_to_scene("campaign_turn_controller", {"campaign_data": campaign_data})

func _on_scene_changed(new_scene: String, previous_scene: String) -> void:
	## Handle scene router scene changes
	current_scene = new_scene
	scene_transition_completed.emit(new_scene, scene_context)

func _on_navigation_error(scene_name: String, error: String) -> void:
	## Handle scene router navigation errors
	push_error("CampaignCreationStateBridge: Navigation error for scene %s: %s" % [scene_name, error])

## Public API for Scene Integration

func register_scene_completion(scene_name: String, is_valid: bool = true) -> void:
	## Allow scenes to register their completion status
	scene_validation_states[scene_name] = is_valid
	scene_validation_changed.emit(scene_name, is_valid)
	
	if is_valid:
		var progress = get_creation_progress()
		campaign_creation_progress_updated.emit(progress.completed_scenes, current_scene)

func get_scene_validation_state(scene_name: String) -> bool:
	## Get validation state for a specific scene
	return scene_validation_states.get(scene_name, false)

func clear_campaign_creation_state() -> void:
	## Clear all campaign creation state (for starting over)
	scene_history.clear()
	scene_context.clear()
	scene_states.clear()
	scene_validation_states.clear()
	current_scene = ""
	
	if state_manager:
		state_manager.initialize() # Reset state manager
	

## Static access methods for global use
static func get_instance() -> CampaignCreationStateBridgeClass:
	## Get the singleton instance
	return instance

static func safe_transition_to_scene(scene_name: String, context: Dictionary = {}) -> void:
	## Safe static method for scene transitions
	if instance:
		instance.transition_to_scene(scene_name, context)
	else:
		push_error("CampaignCreationStateBridge: Instance not available for scene transition")

## Auto-save and Recovery System

var auto_save_enabled: bool = true
var recovery_save_path: String = "user://campaign_creation_recovery.dat"
var auto_save_interval: float = 30.0  # Seconds between auto-saves
var last_auto_save: float = 0.0  # Time since last auto-save
var _auto_save_timer: Timer

func _exit_tree() -> void:
	## Cleanup when bridge is removed from scene tree
	if _auto_save_timer:
		_auto_save_timer.stop()
		_auto_save_timer.queue_free()
		_auto_save_timer = null

func _setup_auto_save_timer() -> void:
	## Setup auto-save timer
	_auto_save_timer = Timer.new()
	add_child(_auto_save_timer)
	_auto_save_timer.wait_time = 30.0  # Auto-save every 30 seconds
	_auto_save_timer.timeout.connect(_perform_auto_save)
	if auto_save_enabled:
		_auto_save_timer.start()

func _perform_auto_save() -> void:
	## Perform automatic save of campaign creation state
	if current_scene.is_empty():
		return # Nothing to save
	
	
	var save_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"current_scene": current_scene,
		"scene_history": scene_history.duplicate(),
		"scene_contexts": scene_contexts.duplicate(),
		"scene_states": scene_states.duplicate(),
		"scene_validation_states": scene_validation_states.duplicate(),
		"campaign_data": get_campaign_data(),
		"version": "1.0"
	}
	
	var success = _save_to_file(recovery_save_path, save_data)
	if success:
		auto_save_completed.emit(recovery_save_path)
	else:
		push_error("CampaignCreationStateBridge: Auto-save failed")

func save_campaign_creation_progress(custom_path: String = "") -> bool:
	## Manually save campaign creation progress
	var save_path = custom_path if not custom_path.is_empty() else recovery_save_path
	
	var save_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"current_scene": current_scene,
		"scene_history": scene_history.duplicate(),
		"scene_contexts": scene_contexts.duplicate(),
		"scene_states": scene_states.duplicate(),
		"scene_validation_states": scene_validation_states.duplicate(),
		"campaign_data": get_campaign_data(),
		"version": "1.0",
		"manual_save": true
	}
	
	var success = _save_to_file(save_path, save_data)
	if success:
		pass
	else:
		push_error("CampaignCreationStateBridge: Manual save failed: %s" % save_path)
	
	return success

func check_for_recovery_data() -> bool:
	## Check if recovery data exists
	return FileAccess.file_exists(recovery_save_path)

func load_recovery_data() -> Dictionary:
	## Load recovery data if available
	if not check_for_recovery_data():
		return {}
	
	var recovery_data = _load_from_file(recovery_save_path)
	if not recovery_data.is_empty():
		recovery_data_found.emit(recovery_data)
	
	return recovery_data

func restore_from_recovery_data(recovery_data: Dictionary) -> bool:
	## Restore campaign creation state from recovery data
	if recovery_data.is_empty():
		push_warning("CampaignCreationStateBridge: Cannot restore - recovery data is empty")
		return false
	
	
	# Validate recovery data
	if not _validate_recovery_data(recovery_data):
		push_error("CampaignCreationStateBridge: Recovery data validation failed")
		return false
	
	# Restore state
	current_scene = recovery_data.get("current_scene", "")
	scene_history = recovery_data.get("scene_history", [])
	scene_contexts = recovery_data.get("scene_contexts", {})
	scene_states = recovery_data.get("scene_states", {})
	scene_validation_states = recovery_data.get("scene_validation_states", {})
	
	# Restore campaign data to state manager
	var campaign_data = recovery_data.get("campaign_data", {})
	if not campaign_data.is_empty() and state_manager:
		# Restore each phase data
		for phase_key in campaign_data:
			if phase_key != "metadata":
				var phase_data = campaign_data[phase_key]
				if not phase_data.is_empty():
					state_manager.update_phase_data(_string_to_phase(phase_key), phase_data)
	
	return true

func clear_recovery_data() -> void:
	## Clear recovery data file
	if FileAccess.file_exists(recovery_save_path):
		var dir = DirAccess.open("user://")
		if dir:
			var error = dir.remove(recovery_save_path.get_file())
			if error == OK:
				pass
			else:
				push_error("CampaignCreationStateBridge: Failed to clear recovery data")

func get_recovery_info() -> Dictionary:
	## Get information about available recovery data
	if not check_for_recovery_data():
		return {}
	
	var recovery_data = _load_from_file(recovery_save_path)
	if recovery_data.is_empty():
		return {}
	
	var timestamp = recovery_data.get("timestamp", 0)
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	
	return {
		"exists": true,
		"timestamp": timestamp,
		"datetime": datetime,
		"current_scene": recovery_data.get("current_scene", ""),
		"manual_save": recovery_data.get("manual_save", false),
		"version": recovery_data.get("version", "unknown")
	}

## Private Helper Methods for Save/Load

func _save_to_file(file_path: String, data: Dictionary) -> bool:
	## Save data to file with error handling
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("CampaignCreationStateBridge: Failed to open file for writing: %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	file.close()
	
	return true

func _load_from_file(file_path: String) -> Dictionary:
	## Load data from file with error handling
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("CampaignCreationStateBridge: Failed to open file for reading: %s" % file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("CampaignCreationStateBridge: Failed to parse JSON from file: %s" % file_path)
		return {}
	
	var data = json.data
	if not data is Dictionary:
		push_error("CampaignCreationStateBridge: Invalid data format in file: %s" % file_path)
		return {}
	
	return data

func _validate_recovery_data(recovery_data: Dictionary) -> bool:
	## Validate recovery data structure
	var required_keys = ["timestamp", "current_scene", "version"]
	
	for key in required_keys:
		if not recovery_data.has(key):
			push_error("CampaignCreationStateBridge: Recovery data missing required key: %s" % key)
			return false
	
	# Check version compatibility
	var version = recovery_data.get("version", "")
	if version != "1.0":
		push_warning("CampaignCreationStateBridge: Recovery data version mismatch: %s" % version)
		# Could still be recoverable, so don't return false
	
	return true

func _string_to_phase(phase_string: String) -> CampaignCreationStateManager.Phase:
	## Convert string to phase enum
	match phase_string:
		"config":
			return CampaignCreationStateManager.Phase.CONFIG
		"crew":
			return CampaignCreationStateManager.Phase.CREW_SETUP
		"captain":
			return CampaignCreationStateManager.Phase.CAPTAIN_CREATION
		"ship":
			return CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT
		"equipment":
			return CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION
		_:
			return CampaignCreationStateManager.Phase.CONFIG

## Auto-save Configuration

func set_auto_save_enabled(enabled: bool) -> void:
	## Enable or disable auto-save
	auto_save_enabled = enabled

func set_auto_save_interval(interval_seconds: float) -> void:
	## Set auto-save interval
	auto_save_interval = max(10.0, interval_seconds) # Minimum 10 seconds

func get_auto_save_status() -> Dictionary:
	## Get auto-save status information
	return {
		"enabled": auto_save_enabled,
		"interval": auto_save_interval,
		"last_save": last_auto_save,
		"time_until_next": auto_save_interval - last_auto_save
	}
