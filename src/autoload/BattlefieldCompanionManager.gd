extends Node

## Battlefield Companion Autoload
##
## Global access point for the battlefield companion system.
## Provides simplified API for campaign manager integration and handles
## system initialization, cleanup, and cross-scene persistence.
##
## Usage in project.godot autoload settings:
## Name: BattlefieldCompanionManager
## Path: res://src/autoload/BattlefieldCompanionManager.gd

# Dependencies
const BattlefieldCompanion = preload("res://src/core/battle/BattlefieldCompanion.gd")
const FPCM_BattleSystemIntegration = preload("res://src/core/battle/BattleSystemIntegration.gd")
const FPCM_BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# Global signals for campaign integration
signal battle_system_ready()
signal battle_phase_changed(phase: String)
signal battle_completed(results: Dictionary)
signal system_error(error_code: String, details: Dictionary)

# JSON configuration support
var companion_config_data: Dictionary = {}
var battlefield_settings: Dictionary = {}

# System references
var integration_system: FPCM_BattleSystemIntegration = null
var current_session_id: String = ""
var system_initialized: bool = false

# Configuration (with JSON override support)
var auto_initialize: bool = true
var debug_mode: bool = false
var performance_monitoring: bool = false

# Tutorial integration (for guided campaign mode)
var guided_mode_enabled: bool = false  # Toggle for story-driven tutorials
var story_track_system: Variant = null  # Reference to StoryTrackSystem

func _ready() -> void:
	"""Initialize global battlefield companion system"""
	_load_companion_configuration()
	_setup_debug_configuration()

	if auto_initialize:
		initialize_system()

	# Connect to StoryTrackSystem for guided mode (deferred to allow scene tree setup)
	call_deferred("_connect_to_story_track_system")

func _load_companion_configuration() -> void:
	"""Load companion configuration from JSON files"""
	# DataManager is static, use direct static calls
	
	# Load companion config data
	companion_config_data = DataManager._load_json_safe("res://data/battlefield/companion_config.json", "BattlefieldCompanionManager")
	if companion_config_data.is_empty():
		print("BattlefieldCompanionManager: companion_config.json not found, using defaults")
		_create_companion_config_fallback()
	else:
		print("BattlefieldCompanionManager: Loaded companion configuration from JSON")
		_apply_companion_configuration()
	
	# Extract battlefield settings
	battlefield_settings = companion_config_data.get("battlefield_settings", {})

func _create_companion_config_fallback() -> void:
	"""Create fallback companion configuration when JSON unavailable"""
	companion_config_data = {
		"system_settings": {
			"auto_initialize": true,
			"debug_mode_default": false,
			"performance_monitoring_default": false,
			"session_timeout_minutes": 60,
			"max_concurrent_battles": 1
		},
		"battlefield_settings": {
			"default_terrain_complexity": "medium",
			"setup_time_target_minutes": 10,
			"auto_terrain_generation": true,
			"quick_setup_enabled": true,
			"advanced_features_enabled": false
		},
		"integration_settings": {
			"campaign_integration_enabled": true,
			"crew_data_validation": true,
			"mission_data_validation": true,
			"result_persistence": true,
			"performance_tracking": false
		},
		"ui_settings": {
			"show_detailed_tooltips": true,
			"enable_keyboard_shortcuts": true,
			"auto_save_preferences": true,
			"theme": "default"
		}
	}
	
	battlefield_settings = companion_config_data.battlefield_settings

func _apply_companion_configuration() -> void:
	"""Apply companion configuration from JSON data"""
	if companion_config_data.has("system_settings"):
		var settings = companion_config_data.system_settings
		auto_initialize = settings.get("auto_initialize", true)
		# Note: debug_mode and performance_monitoring are set later in _setup_debug_configuration()
	
	if companion_config_data.has("battlefield_settings"):
		battlefield_settings = companion_config_data.battlefield_settings

func _setup_debug_configuration() -> void:
	"""Setup debug configuration based on build type"""
	if OS and OS.has_method("is_debug_build"):
		debug_mode = OS.is_debug_build()
	else:
		debug_mode = false
	performance_monitoring = debug_mode

	if debug_mode:
		print("BattlefieldCompanionManager: Debug mode enabled")

func _connect_to_story_track_system() -> void:
	"""Connect to StoryTrackSystem for guided campaign mode"""
	# Try to get StoryTrackSystem from GameStateManager or AlphaGameManager
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager and game_state_manager.has_method("get_story_track_system"):
		story_track_system = game_state_manager.get_story_track_system()
	else:
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_story_track_system"):
			story_track_system = alpha_manager.get_story_track_system()

	# Connect to tutorial_requested signal if StoryTrackSystem is available
	if story_track_system and story_track_system.has_signal("tutorial_requested"):
		var connection_result = story_track_system.tutorial_requested.connect(_on_tutorial_requested)
		if connection_result == OK:
			print("BattlefieldCompanionManager: Connected to StoryTrackSystem tutorial signals")
		else:
			push_warning("BattlefieldCompanionManager: Failed to connect to StoryTrackSystem tutorial signals")
	else:
		if debug_mode:
			print("BattlefieldCompanionManager: StoryTrackSystem not available for guided mode")

func _on_tutorial_requested(event_id: String, companion_tools: Array, story_context: String) -> void:
	"""Handle tutorial request from StoryTrackSystem"""
	if not guided_mode_enabled:
		return  # Silently ignore if guided mode is disabled

	if debug_mode:
		print("BattlefieldCompanionManager: Tutorial requested for event '%s' with %d tools" % [event_id, companion_tools.size()])
		print("  Story context: %s" % story_context)
		print("  Companion tools: %s" % str(companion_tools))

	# Route tutorial request to TutorialOverlay via BattleCompanionUI
	# (This will be implemented in the next step when wiring TutorialOverlay)
	_route_tutorial_to_overlay(event_id, companion_tools, story_context)

func _route_tutorial_to_overlay(event_id: String, companion_tools: Array, story_context: String) -> void:
	"""Route tutorial request to TutorialOverlay"""
	# Get TutorialOverlay from the current scene
	var tutorial_overlay: Node = _find_tutorial_overlay()

	if not tutorial_overlay:
		if debug_mode:
			print("BattlefieldCompanionManager: TutorialOverlay not found in current scene")
		return

	# Call show_story_hint on TutorialOverlay
	if tutorial_overlay.has_method("show_story_hint"):
		tutorial_overlay.show_story_hint(companion_tools, story_context)
		if debug_mode:
			print("BattlefieldCompanionManager: Story hint displayed via TutorialOverlay")
	else:
		push_warning("BattlefieldCompanionManager: TutorialOverlay missing show_story_hint method")

func _find_tutorial_overlay() -> Node:
	"""Find TutorialOverlay in the current scene tree"""
	# Try to find in BattleCompanionUI or other battle screens
	var root := get_tree().root
	if not root:
		return null

	# Search for TutorialOverlay node (could be child of any battle UI)
	var overlays := _find_nodes_by_class(root, "FPCM_TutorialOverlay")
	if overlays.size() > 0:
		return overlays[0]

	return null

func _find_nodes_by_class(node: Node, target_class: String) -> Array:
	"""Recursively find nodes by class name"""
	var result: Array = []

	if node.get_class() == target_class or (node.get_script() and node.get_script().get_global_name() == target_class):
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_nodes_by_class(child, target_class))

	return result

## Enable or disable guided campaign mode
func set_guided_mode(enabled: bool) -> void:
	guided_mode_enabled = enabled

	# Also enable guided mode in StoryTrackSystem if available
	if story_track_system and story_track_system.has_method("set_guided_mode"):
		story_track_system.set_guided_mode(enabled)

	if debug_mode:
		if enabled:
			print("BattlefieldCompanionManager: Guided campaign mode enabled")
		else:
			print("BattlefieldCompanionManager: Guided campaign mode disabled")

# =====================================================
# SYSTEM INITIALIZATION
# =====================================================

func initialize_system() -> bool:
	"""
	Initialize the battlefield companion system

	@return: Success status
	"""
	if system_initialized:
		push_warning("BattlefieldCompanionManager: System already initialized")
		return true

	# Create integration system with null safety
	if FPCM_BattleSystemIntegration:
		integration_system = FPCM_BattleSystemIntegration.new()
		if integration_system:
			add_child(integration_system)
		else:
			push_error("BattlefieldCompanionManager: Failed to create integration system")
			return false
	else:
		push_error("BattlefieldCompanionManager: FPCM_BattleSystemIntegration not available")
		return false

	# Connect integration signals
	_connect_integration_signals()

	# Mark as initialized
	system_initialized = true
	current_session_id = _generate_session_id()

	battle_system_ready.emit()

	if debug_mode:
		print("BattlefieldCompanionManager: System initialized successfully")

	return true

func shutdown_system() -> void:
	"""Shutdown the battlefield companion system"""
	if integration_system and integration_system.has_method("queue_free"):
		integration_system.queue_free()
		integration_system = null

	system_initialized = false
	current_session_id = ""

	if debug_mode:
		print("BattlefieldCompanionManager: System shutdown complete")

func _connect_integration_signals() -> void:
	"""Connect integration system signals"""
	if not integration_system:
		return

	if integration_system:
		if integration_system.has_signal("battle_workflow_complete"):
			integration_system.battle_workflow_complete.connect(_on_battle_workflow_complete)
		if integration_system.has_signal("integration_error"):
			integration_system.integration_error.connect(_on_integration_error)

# =====================================================
# CAMPAIGN MANAGER API
# =====================================================

func start_battle_assistance(mission_data: Resource, crew_data: Array) -> bool:
	"""
	Start battle assistance workflow

	@param mission_data: Mission resource with battle parameters
	@param crew_data: Array of crew member resources
	@return: Success status
	"""
	if not _ensure_system_ready():
		return false

	var battle_request := {
		"mission": mission_data,
		"crew": crew_data,
		"session_id": current_session_id,
		"timestamp": Time.get_unix_time_from_system()
	}

	if integration_system and integration_system.has_method("start_battle_workflow"):
		return integration_system.start_battle_workflow(battle_request)
	else:
		push_error("BattlefieldCompanionManager: Integration system not available")
		return false

func is_battle_active() -> bool:
	"""Check if a battle session is currently active"""
	if not integration_system or not integration_system.battlefield_companion:
		return false

	return integration_system.battlefield_companion.companion_active

func get_current_battle_phase() -> String:
	"""Get current battle phase name"""
	if not integration_system or not integration_system.battlefield_companion:
		return "none"

	var phase = integration_system.battlefield_companion.current_phase
	return FPCM_BattlefieldTypes.BattleStage.keys()[phase]

func force_end_battle() -> Dictionary:
	"""Force end current battle and return results"""
	if not integration_system or not integration_system.battlefield_companion:
		return {}

	return integration_system.battlefield_companion.complete_battle_companion()

# =====================================================
# QUICK ACCESS METHODS
# =====================================================

func quick_terrain_generation(mission_type: String = "patrol") -> Dictionary:
	"""
	Quick terrain generation for immediate use

	@param mission_type: Type of mission for appropriate terrain
	@return: Terrain suggestions dictionary
	"""
	if not _ensure_system_ready():
		return {}

	# Create temporary setup assistant
	var setup_assistant = integration_system.battlefield_companion.setup_assistant
	if not setup_assistant:
		return {}

	var options := {"mission_type": mission_type}
	var suggestions = setup_assistant.generate_battlefield_suggestions(null, options)

	return _convert_suggestions_to_dict(suggestions)

func quick_dice_roll(pattern: String, context: String = "Quick Roll") -> int:
	"""
	Quick dice roll using system dice manager

	@param pattern: Dice pattern (d6, 2d6, d10, etc.)
	@param context: Context for the roll
	@return: Roll result
	"""
	var dice_manager: DiceManager = get_node_or_null("/root/DiceManager") as DiceManager
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice("BattlefieldCompanion", pattern)
	else:
		return _fallback_dice_roll(pattern)

func get_system_status() -> Dictionary:
	"""Get comprehensive system status"""
	return {
		"initialized": system_initialized,
		"session_id": current_session_id,
		"battle_active": is_battle_active(),
		"current_phase": get_current_battle_phase(),
		"integration_status": integration_system.get_integration_status() if integration_system else {},
		"debug_mode": debug_mode,
		"performance_monitoring": performance_monitoring
	}

# =====================================================
# EVENT HANDLERS
# =====================================================

func _on_battle_workflow_complete(results: Dictionary) -> void:
	"""Handle battle workflow completion"""
	battle_completed.emit(results)

	if debug_mode:
		print("BattlefieldCompanionManager: Battle workflow completed")
		print("Results: ", results)

func _on_integration_error(error_code: String, details: Dictionary) -> void:
	"""Handle integration system errors"""
	push_error("BattlefieldCompanionManager: Integration error - %s" % error_code)
	system_error.emit(error_code, details)

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _ensure_system_ready() -> bool:
	"""Ensure system is ready for operations"""
	if not system_initialized:
		if auto_initialize:
			return initialize_system()
		else:
			push_error("BattlefieldCompanionManager: System not initialized")
			return false

	return true

func _generate_session_id() -> String:
	"""Generate unique session identifier"""
	return "battle_%d_%d" % [Time.get_unix_time_from_system(), randi()]

func _convert_suggestions_to_dict(suggestions) -> Dictionary:
	"""Convert suggestions object to dictionary"""
	if not suggestions:
		return {}

	return {
		"terrain_count": suggestions.get_total_terrain_pieces(),
		"setup_time": suggestions.estimated_setup_time,
		"complexity": suggestions.complexity_rating,
		"summary": suggestions.get_setup_summary()
	}

func _fallback_dice_roll(pattern: String) -> int:
	"""Fallback dice rolling for quick access"""
	match pattern.to_lower():
		"d3": return randi_range(1, 3)
		"d6": return randi_range(1, 6)
		"2d6": return randi_range(1, 6) + randi_range(1, 6)
		"d10": return randi_range(1, 10)
		"d66":
			var tens = randi_range(1, 6)
			var ones = randi_range(1, 6)
			return tens * 10 + ones
		_: return randi_range(1, 6)

# =====================================================
# DEVELOPMENT AND TESTING
# =====================================================

func setup_test_scenario() -> bool:
	"""Setup test scenario for development (debug builds only)"""
	if not debug_mode:
		return false

	print("BattlefieldCompanionManager: Setting up test scenario")

	# Create test mission data
	var test_mission = Resource.new()
	test_mission.set_meta("mission_type", "patrol")
	test_mission.set_meta("difficulty", 1)

	# Create test crew data
	var test_crew = [
		{"name": "Test Leader", "health": 4, "background": "military"},
		{"name": "Test Soldier", "health": 3, "background": "soldier"},
		{"name": "Test Specialist", "health": 3, "background": "specialist"}
	]

	return start_battle_assistance(test_mission, test_crew)

func enable_performance_monitoring() -> void:
	"""Enable performance monitoring"""
	performance_monitoring = true

	if integration_system:
		# Enable performance tracking in integration system
		pass

func get_performance_report() -> String:
	"""Get performance report (debug builds only)"""
	if not debug_mode or not integration_system:
		return "Performance monitoring not available"

	return integration_system.get_performance_report()

func force_system_reset() -> void:
	"""Force complete system reset (debug builds only)"""
	if not debug_mode:
		return

	print("BattlefieldCompanionManager: Forcing system reset")

	if integration_system:
		integration_system.force_system_reset()

	# Reinitialize
	shutdown_system()
	await get_tree().process_frame
	initialize_system()

# =====================================================
# CONFIGURATION METHODS
# =====================================================

func set_debug_mode(enabled: bool) -> void:
	"""Enable/disable debug mode"""
	debug_mode = enabled

	if integration_system:
		integration_system.enable_debug_mode() if enabled else null

func set_auto_initialization(enabled: bool) -> void:
	"""Enable/disable automatic system initialization"""
	auto_initialize = enabled

func get_version_info() -> Dictionary:
	"""Get version information for the battlefield companion system"""
	return {
		"system_version": "1.0.0",
		"architecture": "Streamlined Companion",
		"compatible_godot": "4.4+",
		"five_parsecs_rules": "Core Rules Implementation",
		"build_date": Time.get_datetime_string_from_system()
	}

# =====================================================
# SIGNAL HELPERS FOR EXTERNAL INTEGRATION
# =====================================================

func connect_to_campaign_manager(campaign_manager: Node) -> void:
	"""Connect to campaign manager signals"""
	if not campaign_manager:
		return

	# Connect battle system signals to campaign manager
	if campaign_manager.has_signal("battle_requested"):
		campaign_manager.battle_requested.connect(_on_campaign_battle_requested)

	# Connect companion signals to campaign manager
	var _connect_result: int = battle_completed.connect(campaign_manager._on_battle_completed if campaign_manager.has_method("_on_battle_completed") else func(results): pass )

func _on_campaign_battle_requested(mission: Resource, crew: Array) -> void:
	"""Handle battle request from campaign manager"""
	start_battle_assistance(mission, crew)

# =====================================================
# PERSISTENCE HELPERS
# =====================================================

func save_session(filepath: String = "user://battlefield_session.save") -> bool:
	"""Save current session state"""
	if not integration_system:
		return false

	var save_data = {
		"session_id": current_session_id,
		"system_status": get_system_status(),
		"timestamp": Time.get_unix_time_from_system()
	}

	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close() # Always close file if opened successfully
		return true

	return false

func load_session(filepath: String = "user://battlefield_session.save") -> bool:
	"""Load saved session state"""
	if not FileAccess.file_exists(filepath):
		return false

	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		return false

	var json_text = file.get_as_text()
	file.close() # Always close file if opened successfully

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		return false

	var save_data = json.data as Dictionary
	current_session_id = save_data.get("session_id", _generate_session_id())

	return true

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
