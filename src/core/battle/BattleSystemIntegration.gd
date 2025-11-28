class_name FPCM_BattleSystemIntegration
extends Node

## Battle System Integration Layer
##
## Master integration script that replaces the old complex tactical battle UI
## with the new streamlined battlefield companion system. Provides backward
## compatibility while transitioning to the simplified architecture.
##
## This script serves as a bridge between the campaign manager and the new
## battlefield companion, handling data translation and workflow management.

# Dependencies
const BattlefieldCompanion = preload("res://src/core/battle/BattlefieldCompanion.gd")
const BattleCompanionUI = preload("res://src/ui/screens/battle/BattleCompanionUI.gd")
const SimpleUnitCard = preload("res://src/ui/components/combat/SimpleUnitCard.gd")
const QuickDicePopup = preload("res://src/ui/components/QuickDicePopup.gd")
const BattleEventNotification = preload("res://src/ui/components/BattleEventNotification.gd")

# Integration signals - for campaign manager communication
signal battle_phase_ready(phase_data: Dictionary)
signal battle_workflow_complete(results: Dictionary)
signal integration_error(error_code: String, details: Dictionary)

# Core system references
var battlefield_companion: BattlefieldCompanion = null
var companion_ui: BattleCompanionUI = null
var campaign_manager: Node = null

# Legacy compatibility data
var legacy_battle_data: Dictionary = {}
var migration_complete: bool = false

func _ready() -> void:
	"""Initialize battle system integration"""
	_initialize_campaign_integration()
	_setup_companion_systems()
	_setup_legacy_compatibility()

func _initialize_campaign_integration() -> void:
	"""Initialize integration with campaign manager"""
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

	if campaign_manager:
		# Connect to campaign manager signals if they exist
		_connect_campaign_signals()

func _connect_campaign_signals() -> void:
	"""Connect campaign manager signals for battle integration"""
	# These connections depend on your existing campaign manager API
	# Adjust based on your actual campaign manager implementation

	if campaign_manager.has_signal("battle_requested"):
		campaign_manager.battle_requested.connect(_on_battle_requested)

	if campaign_manager.has_signal("mission_selected"):
		campaign_manager.mission_selected.connect(_on_mission_selected)

func _setup_companion_systems() -> void:
	"""Initialize battlefield companion and UI systems"""
	# Create battlefield companion
	battlefield_companion = BattlefieldCompanion.new()
	add_child(battlefield_companion)

	# Connect companion signals
	battlefield_companion.battle_completed.connect(_on_battle_completed)
	battlefield_companion.companion_error.connect(_on_companion_error)

func _setup_legacy_compatibility() -> void:
	"""Setup compatibility layer for legacy battle system"""
	# This provides backward compatibility for existing save files
	# and campaign data that might reference the old battle system
	pass

# =====================================================
# CAMPAIGN MANAGER INTEGRATION
# =====================================================

func _on_battle_requested(mission_data: Resource, crew_data: Array) -> void:
	"""Handle battle request from campaign manager"""
	# Translate campaign manager request to battlefield companion format
	var battle_request := {
		"mission": mission_data,
		"crew": crew_data,
		"timestamp": Time.get_unix_time_from_system()
	}

	start_battle_workflow(battle_request)

func _on_mission_selected(mission: Resource) -> void:
	"""Handle mission selection for battlefield preparation"""
	# Pre-load mission data into battlefield companion
	if battlefield_companion:
		battlefield_companion.session_data["selected_mission"] = mission

func start_battle_workflow(battle_request: Dictionary) -> bool:
	"""
	Start the complete battle workflow using the companion system

	@param battle_request: Dictionary containing mission and crew data
	@return: Success status
	"""
	if not battlefield_companion:
		integration_error.emit("COMPANION_NOT_INITIALIZED", battle_request)
		return false

	# Initialize companion UI if not already present
	if not companion_ui:
		_initialize_companion_ui()

	# Start battlefield companion workflow
	var success := battlefield_companion.transition_to_phase(battlefield_companion.FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN)

	if success:
		# Populate with battle request data
		_populate_companion_data(battle_request)
		battle_phase_ready.emit({"phase": "setup", "data": battle_request})

	return success

func _initialize_companion_ui() -> void:
	"""Initialize companion UI and integrate with scene"""
	# This would typically be done through scene management
	# For now, create programmatically
	companion_ui = BattleCompanionUI.new()

	# Connect UI signals
	companion_ui.battle_action_triggered.connect(_on_ui_action_triggered)
	companion_ui.ui_error_occurred.connect(_on_ui_error)

	# Add to scene (adjust based on your scene structure)
	get_tree().current_scene.add_child(companion_ui)

func _populate_companion_data(battle_request: Dictionary) -> void:
	"""Populate companion with battle request data"""
	if not battlefield_companion:
		return

	# Store mission data
	if battle_request.has("mission"):
		battlefield_companion.session_data["mission_data"] = battle_request.mission

	# Store crew data
	if battle_request.has("crew"):
		battlefield_companion.session_data["crew_data"] = battle_request.crew

# =====================================================
# BATTLE WORKFLOW ORCHESTRATION
# =====================================================

func _on_battle_completed(results: FPCM_BattlefieldTypes.LegacyBattleResults) -> void:
	"""Handle battle completion and return results to campaign"""
	# Translate companion results to campaign manager format
	var campaign_results := _translate_results_for_campaign(results)

	# Notify campaign manager
	if campaign_manager and campaign_manager.has_method("handle_battle_results"):
		campaign_manager.handle_battle_results(campaign_results)

	# Emit completion signal
	battle_workflow_complete.emit(campaign_results)

	# Cleanup for next battle
	_cleanup_battle_session()

func _translate_results_for_campaign(companion_results: FPCM_BattlefieldTypes.LegacyBattleResults) -> Dictionary:
	"""Translate companion results to campaign manager format"""
	var campaign_results := {
		# Core results
		"victory": companion_results.victory,
		"rounds_fought": companion_results.rounds_fought,

		# Casualties in campaign format
		"casualties": [],
		"injuries": [],

		# Experience and progression
		"experience_gained": companion_results.experience_gained.duplicate(),

		# Loot and rewards
		"loot_opportunities": companion_results.loot_opportunities.duplicate(),

		# Metadata
		"battle_id": companion_results.battle_id,
		"completion_time": Time.get_unix_time_from_system()
	}

	# Process casualties for campaign format
	for casualty in companion_results.casualties:
		campaign_results.casualties.append({
			"character_name": casualty.get("name", "Unknown"),
			"casualty_type": casualty.get("type", "killed_in_action"),
			"round_occurred": casualty.get("round", 0)
		})

	# Process injuries for campaign format
	for injury in companion_results.injuries:
		campaign_results.injuries.append({
			"character_name": injury.get("name", "Unknown"),
			"injury_type": injury.get("injury", "light_wound"),
			"recovery_time": injury.get("recovery_rounds", 1),
			"treatment_options": injury.get("treatment_options", [])
		})

	return campaign_results

func _cleanup_battle_session() -> void:
	"""Clean up after battle completion"""
	if battlefield_companion:
		battlefield_companion.reset_companion_session()

	# Clear legacy data
	legacy_battle_data.clear()

# =====================================================
# UI EVENT HANDLING
# =====================================================

func _on_ui_action_triggered(action: String, data: Dictionary) -> void:
	"""Handle UI actions from companion interface"""
	match action:
		"continue_campaign":
			_return_to_campaign(data)
		"restart_battle":
			_restart_battle_workflow()
		"save_session":
			_save_battle_session(data)
		"load_session":
			_load_battle_session(data)

func _on_ui_error(error: String, context: Dictionary) -> void:
	"""Handle UI errors"""
	integration_error.emit("UI_ERROR", {"error": error, "context": context})

func _return_to_campaign(completion_data: Dictionary) -> void:
	"""Return control to campaign manager"""
	# Switch back to campaign scene/UI
	if campaign_manager and campaign_manager.has_method("return_from_battle"):
		campaign_manager.return_from_battle(completion_data)

	# Cleanup companion UI
	if companion_ui:
		companion_ui.queue_free()
		companion_ui = null

func _restart_battle_workflow() -> void:
	"""Restart the battle workflow"""
	if battlefield_companion:
		battlefield_companion.reset_companion_session()
		battlefield_companion.transition_to_phase(battlefield_companion.FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN)

# =====================================================
# LEGACY SYSTEM COMPATIBILITY
# =====================================================

func migrate_legacy_battle_data(legacy_data: Dictionary) -> Dictionary:
	"""
	Migrate data from old tactical battle system to new companion format

	This function handles the translation of data from the old complex battle UI
	to the new streamlined companion system.
	"""
	var migrated_data := {}

	# Migrate unit data
	if legacy_data.has("tracked_units"):
		migrated_data["units"] = _migrate_unit_data(legacy_data.tracked_units)

	# Migrate battlefield data
	if legacy_data.has("battlefield_state"):
		migrated_data["battlefield"] = _migrate_battlefield_data(legacy_data.battlefield_state)

	# Migrate battle state
	if legacy_data.has("battle_state"):
		migrated_data["battle_progress"] = _migrate_battle_state(legacy_data.battle_state)

	migration_complete = true
	return migrated_data

func _migrate_unit_data(legacy_units: Dictionary) -> Array:
	"""Migrate unit data from legacy format"""
	var migrated_units: Array = []

	for unit_id in legacy_units.keys():
		var legacy_unit = legacy_units[unit_id]
		var migrated_unit := {
			"name": legacy_unit.get("name", "Unknown"),
			"team": legacy_unit.get("team", "crew"),
			"health": legacy_unit.get("current_health", 3),
			"max_health": legacy_unit.get("max_health", 3),
			"activated": legacy_unit.get("activated_this_round", false)
		}
		migrated_units.append(migrated_unit)

	return migrated_units

func _migrate_battlefield_data(legacy_battlefield: Dictionary) -> Dictionary:
	"""Migrate battlefield data from legacy format"""
	return {
		"terrain_features": legacy_battlefield.get("terrain_features", []),
		"objectives": legacy_battlefield.get("objectives", []),
		"special_rules": legacy_battlefield.get("special_rules", [])
	}

func _migrate_battle_state(legacy_state: Dictionary) -> Dictionary:
	"""Migrate battle state from legacy format"""
	return {
		"current_round": legacy_state.get("current_round", 1),
		"phase": legacy_state.get("phase", "setup"),
		"events": legacy_state.get("battle_events", [])
	}

# =====================================================
# SYSTEM DIAGNOSTICS AND UTILITIES
# =====================================================

func get_integration_status() -> Dictionary:
	"""Get current integration system status"""
	return {
		"companion_active": battlefield_companion != null,
		"ui_active": companion_ui != null,
		"campaign_connected": campaign_manager != null,
		"migration_complete": migration_complete,
		"legacy_data_size": legacy_battle_data.size()
	}

func run_system_diagnostics() -> Dictionary:
	"""Run comprehensive system diagnostics"""
	var diagnostics := {
		"timestamp": Time.get_unix_time_from_system(),
		"integration_status": get_integration_status(),
		"companion_status": {},
		"performance_metrics": {}
	}

	# Companion system diagnostics
	if battlefield_companion:
		diagnostics.companion_status = battlefield_companion.get_system_status()

	# Performance metrics
	diagnostics.performance_metrics = {
		"memory_usage": OS.get_static_memory_usage(),
		"scene_nodes": get_tree().get_node_count_in_group("battle_system")
	}

	return diagnostics

func force_system_reset() -> void:
	"""Force complete system reset for error recovery"""
	# Reset companion
	if battlefield_companion:
		battlefield_companion.reset_companion_session()

	# Reset UI
	if companion_ui:
		companion_ui.queue_free()
		companion_ui = null

	# Clear all data
	legacy_battle_data.clear()
	migration_complete = false

	# Reinitialize
	_setup_companion_systems()

# =====================================================
# SESSION PERSISTENCE
# =====================================================

func _save_battle_session(session_data: Dictionary) -> bool:
	"""Save current battle session for later resumption"""
	var save_data := {
		"integration_version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"session_data": session_data,
		"companion_state": {}
	}

	# Get companion state
	if battlefield_companion:
		save_data.companion_state = battlefield_companion.get_phase_status()

	# Save to user data directory
	var save_path := "user://battle_session.save"
	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()  # Always close file if opened successfully
		return true

	return false

func _load_battle_session(load_request: Dictionary) -> bool:
	"""Load saved battle session"""
	var load_path := "user://battle_session.save"

	if not FileAccess.file_exists(load_path):
		return false

	var file := FileAccess.open(load_path, FileAccess.READ)
	if not file:
		return false

	var json_text := file.get_as_text()
	file.close()  # Always close file if opened successfully

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		return false

	var save_data := json.data as Dictionary

	# Restore session
	if save_data.has("session_data"):
		_restore_session_data(save_data.session_data)

	if save_data.has("companion_state"):
		_restore_companion_state(save_data.companion_state)

	return true

func _restore_session_data(session_data: Dictionary) -> void:
	"""Restore session data"""
	if battlefield_companion:
		battlefield_companion.session_data = session_data

func _restore_companion_state(companion_state: Dictionary) -> void:
	"""Restore companion state"""
	if battlefield_companion and companion_state.has("phase"):
		var phase_name: String = str(companion_state.phase)
		# Convert phase name to enum value and restore
		# Implementation depends on specific state restoration needs

# =====================================================
# ERROR HANDLING
# =====================================================

func _on_companion_error(error_code: String, context: Dictionary) -> void:
	"""Handle companion system errors"""
	push_error("BattleSystemIntegration: Companion error - %s" % error_code)
	integration_error.emit("COMPANION_ERROR", {"code": error_code, "context": context})

	# Attempt recovery based on error type
	match error_code:
		"INVALID_PHASE_TRANSITION":
			_attempt_phase_recovery()
		"INITIALIZATION_FAILED":
			_attempt_system_reinit()
		_:
			push_warning("Unknown companion error: %s" % error_code)

func _attempt_phase_recovery() -> void:
	"""Attempt to recover from phase transition errors"""
	if battlefield_companion:
		# Reset to safe phase
		battlefield_companion.transition_to_phase(battlefield_companion.FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN)

func _attempt_system_reinit() -> void:
	"""Attempt system reinitialization"""
	# Save current data
	var backup_data := {}
	if battlefield_companion:
		backup_data = battlefield_companion.session_data.duplicate()

	# Reinitialize
	force_system_reset()

	# Restore data if possible
	if not backup_data.is_empty() and battlefield_companion:
		battlefield_companion.session_data = backup_data

# =====================================================
# DEVELOPMENT AND TESTING UTILITIES
# =====================================================

func setup_test_battle() -> void:
	"""Setup a test battle for development purposes"""
	if not OS.is_debug_build():
		return

	var test_crew := [
		{"name": "Test Leader", "health": 4, "team": "crew"},
		{"name": "Test Soldier", "health": 3, "team": "crew"},
		{"name": "Test Specialist", "health": 3, "team": "crew"}
	]

	var test_enemies := [
		{"name": "Enemy 1", "health": 2, "team": "enemy"},
		{"name": "Enemy 2", "health": 2, "team": "enemy"}
	]

	var test_request := {
		"mission": {"mission_type": "patrol", "difficulty": 1},
		"crew": test_crew,
		"enemies": test_enemies
	}

	start_battle_workflow(test_request)

func enable_debug_mode() -> void:
	"""Enable debug mode for development"""
	if OS.is_debug_build() and battlefield_companion:
		battlefield_companion.auto_advance_phases = true
		battlefield_companion.save_session_data = false

func get_performance_report() -> String:
	"""Get formatted performance report"""
	var diagnostics := run_system_diagnostics()
	var report := "=== Battle System Performance Report ===\n"

	report += "Integration Status: %s\n" % ("Active" if diagnostics.integration_status.companion_active else "Inactive")
	report += "Memory Usage: %d bytes\n" % diagnostics.performance_metrics.memory_usage
	report += "Scene Nodes: %d\n" % diagnostics.performance_metrics.scene_nodes

	return report

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
