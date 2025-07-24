extends RefCounted
class_name BaseCampaignDashboardSystem

## Base Campaign Dashboard System
## Unified dashboard logic without UI dependencies
## Consolidates functionality from CampaignDashboard and EnhancedCampaignDashboard
## Part of Phase 2C Campaign Dashboard Integration

# Safe imports
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const CampaignPhaseManagerScript = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# Dashboard modes
enum DashboardMode {
	BASIC,
	ENHANCED,
	RESPONSIVE,
	MINIMAL
}

# Dashboard signals (to be connected by UI components)
signal campaign_data_updated(data: Dictionary)
signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed()
signal phase_event_triggered(event: Dictionary)
signal dashboard_panel_changed(panel_type: String)
signal quick_action_requested(action: String, context: Dictionary)

# Core dashboard data
var current_campaign_data: Dictionary = {}
var current_game_state: GameState = null
var phase_manager: Node = null
var current_mode: DashboardMode = DashboardMode.BASIC
var is_responsive_mode: bool = false

# Manager references
var alpha_manager: Node = null
var campaign_manager: Node = null

# Performance data
var performance_cache: Dictionary = {}
var last_update_time: float = 0.0

func _init() -> void:
	_initialize_dashboard_system()

func _initialize_dashboard_system() -> void:
	"""Initialize dashboard system with fallback managers"""
	# Try to get managers from autoloads
	if Engine.get_singleton("SceneTree"):
		var tree = Engine.get_singleton("SceneTree")
		if tree.has_group("autoload"):
			alpha_manager = tree.get_first_node_in_group("alpha_manager")
			campaign_manager = tree.get_first_node_in_group("campaign_manager")
	
	# Initialize performance cache
	_reset_performance_cache()

func _reset_performance_cache() -> void:
	"""Reset performance cache to defaults"""
	performance_cache = {
		"crew_health": 0.0,
		"ship_condition": 0.0,
		"quest_progress": 0.0,
		"overall_rating": 0.0,
		"last_calculated": 0.0
	}

## Core Dashboard Functionality

func setup_dashboard(mode: DashboardMode = DashboardMode.BASIC, game_state: GameState = null) -> bool:
	"""Setup dashboard with specified mode and game state"""
	current_mode = mode
	current_game_state = game_state
	
	# Initialize managers if not provided
	if not current_game_state:
		current_game_state = _get_fallback_game_state()
	
	if not phase_manager:
		phase_manager = _create_fallback_phase_manager()
	
	# Setup based on mode
	match current_mode:
		DashboardMode.ENHANCED:
			_setup_enhanced_mode()
		DashboardMode.RESPONSIVE:
			_setup_responsive_mode()
		DashboardMode.MINIMAL:
			_setup_minimal_mode()
		_:
			_setup_basic_mode()
	
	return true

func _get_fallback_game_state() -> GameState:
	"""Get fallback game state if none provided"""
	# Try to get from autoload first
	if Engine.get_singleton("SceneTree"):
		var tree = Engine.get_singleton("SceneTree")
		var game_state_node = tree.get_first_node_in_group("game_state")
		if game_state_node:
			return game_state_node
	
	# Create fallback game state
	var fallback_state = GameState.new()
	return fallback_state

func _create_fallback_phase_manager() -> Node:
	"""Create fallback phase manager"""
	var manager = CampaignPhaseManagerScript.new()
	manager.name = "FallbackPhaseManager"
	return manager

func _setup_basic_mode() -> void:
	"""Setup basic dashboard mode"""
	is_responsive_mode = false

func _setup_enhanced_mode() -> void:
	"""Setup enhanced dashboard mode with all features"""
	is_responsive_mode = false
	_enable_enhanced_features()

func _setup_responsive_mode() -> void:
	"""Setup responsive dashboard mode"""
	is_responsive_mode = true
	_enable_enhanced_features()

func _setup_minimal_mode() -> void:
	"""Setup minimal dashboard mode for performance"""
	is_responsive_mode = false

func _enable_enhanced_features() -> void:
	"""Enable enhanced dashboard features"""
	# Enhanced features enabled by mode

## Campaign Data Management

func update_campaign_data(campaign_data: Dictionary) -> void:
	"""Update campaign data and notify UI components"""
	current_campaign_data = campaign_data
	last_update_time = Time.get_time_dict_from_system()["unix"]
	
	# Invalidate performance cache
	_reset_performance_cache()
	
	# Emit update signal
	campaign_data_updated.emit(campaign_data)

func get_campaign_data() -> Dictionary:
	"""Get current campaign data"""
	return current_campaign_data

func get_campaign_summary() -> Dictionary:
	"""Get campaign summary data for display"""
	var crew_count = current_campaign_data.get("crew", []).size()
	var ship_data = current_campaign_data.get("ship", {})
	var ship_hull = ship_data.get("hull_current", 0)
	var ship_max_hull = ship_data.get("hull_max", 100)
	var active_quests = current_campaign_data.get("quests", []).size()
	var current_world = current_campaign_data.get("current_world", "Unknown")
	
	return {
		"crew_count": crew_count,
		"ship_hull_percent": (ship_hull * 100) / ship_max_hull if ship_max_hull > 0 else 0,
		"active_quests": active_quests,
		"current_world": current_world,
		"credits": current_campaign_data.get("credits", 0),
		"story_points": current_campaign_data.get("story_points", 0)
	}

## Phase Management

func get_current_phase() -> int:
	"""Get current campaign phase"""
	if campaign_manager and campaign_manager.has_method("get_current_phase"):
		return campaign_manager.get_current_phase()
	elif phase_manager and phase_manager.has_method("get_current_phase"):
		return phase_manager.get_current_phase()
	elif current_game_state and current_game_state.has_method("get_current_phase"):
		return current_game_state.get_current_phase()
	return 0 # Default to first phase

func advance_to_next_phase() -> bool:
	"""Advance to next campaign phase"""
	var current_phase = get_current_phase()
	var next_phase = _get_next_phase(current_phase)
	
	if next_phase == current_phase:
		return false # No valid next phase
	
	return _start_phase(next_phase)

func _start_phase(phase: int) -> bool:
	"""Start specified campaign phase"""
	var old_phase = get_current_phase()
	
	# Try campaign manager first
	if campaign_manager and campaign_manager.has_method("start_phase"):
		campaign_manager.start_phase(phase)
		phase_changed.emit(old_phase, phase)
		return true
	
	# Try phase manager
	if phase_manager and phase_manager.has_method("start_phase"):
		phase_manager.start_phase(phase)
		phase_changed.emit(old_phase, phase)
		return true
	
	return false

func _get_next_phase(current: int) -> int:
	"""Get next phase in campaign turn sequence"""
	# Five Parsecs campaign phases: SETUP(0) -> TRAVEL(1) -> WORLD(2) -> BATTLE(3) -> POST_BATTLE(4) -> back to TRAVEL(1)
	match current:
		0: return 1 # SETUP -> TRAVEL
		1: return 2 # TRAVEL -> WORLD
		2: return 3 # WORLD -> BATTLE
		3: return 4 # BATTLE -> POST_BATTLE
		4: return 1 # POST_BATTLE -> TRAVEL (new turn)
		_: return 1 # Default to TRAVEL

func get_phase_name(phase: int) -> String:
	"""Get human-readable phase name"""
	var phase_names = ["SETUP", "TRAVEL", "WORLD", "BATTLE", "POST_BATTLE"]
	return phase_names[phase] if phase >= 0 and phase < phase_names.size() else "UNKNOWN"

## Performance Calculation

func calculate_campaign_performance() -> Dictionary:
	"""Calculate campaign performance metrics"""
	var current_time = Time.get_time_dict_from_system()["unix"]
	
	# Use cache if recent (within 30 seconds)
	if performance_cache.get("last_calculated", 0.0) > current_time - 30.0:
		return performance_cache
	
	var performance = {
		"crew_health": _calculate_crew_health(),
		"ship_condition": _calculate_ship_condition(),
		"quest_progress": _calculate_quest_progress(),
		"overall_rating": 0.0,
		"last_calculated": current_time
	}
	
	# Calculate overall rating
	performance.overall_rating = (
		performance.crew_health * 0.3 +
		performance.ship_condition * 0.3 +
		performance.quest_progress * 0.4
	)
	
	# Cache result
	performance_cache = performance
	return performance

func _calculate_crew_health() -> float:
	"""Calculate average crew health ratio"""
	var crew_data = current_campaign_data.get("crew", [])
	if crew_data.is_empty():
		return 0.0
	
	var total_health = 0.0
	for crew_member in crew_data:
		var health_current = crew_member.get("health", 0)
		var health_max = crew_member.get("max_health", 1)
		total_health += float(health_current) / float(health_max) if health_max > 0 else 0.0
	
	return total_health / crew_data.size()

func _calculate_ship_condition() -> float:
	"""Calculate ship condition ratio"""
	var ship_data = current_campaign_data.get("ship", {})
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	
	return float(hull_current) / float(hull_max) if hull_max > 0 else 0.0

func _calculate_quest_progress() -> float:
	"""Calculate average quest progress"""
	var quest_data = current_campaign_data.get("quests", [])
	if quest_data.is_empty():
		return 0.0
	
	var total_progress = 0.0
	for quest in quest_data:
		var progress = quest.get("progress", 0)
		var total_steps = quest.get("total_steps", 1)
		total_progress += float(progress) / float(total_steps) if total_steps > 0 else 0.0
	
	return total_progress / quest_data.size()

## Enhanced Dashboard Features

func get_crew_display_data() -> Array[Dictionary]:
	"""Get crew data formatted for display"""
	var crew_data = current_campaign_data.get("crew", [])
	var display_data: Array[Dictionary] = []
	
	for member in crew_data:
		var display_member = {
			"name": member.get("character_name", "Unknown"),
			"health_ratio": _get_health_ratio(member),
			"status": _get_crew_status(member),
			"role": member.get("role", "Crew Member"),
			"portrait": member.get("portrait_path", "")
		}
		display_data.append(display_member)
	
	return display_data

func get_ship_display_data() -> Dictionary:
	"""Get ship data formatted for display"""
	var ship_data = current_campaign_data.get("ship", {})
	
	return {
		"name": ship_data.get("name", "Unknown Vessel"),
		"class": ship_data.get("class", "Light Freighter"),
		"hull_ratio": _calculate_ship_condition(),
		"fuel": ship_data.get("fuel", 0),
		"max_fuel": ship_data.get("max_fuel", 100),
		"cargo_used": ship_data.get("cargo_used", 0),
		"cargo_capacity": ship_data.get("cargo_capacity", 10)
	}

func get_quest_display_data() -> Array[Dictionary]:
	"""Get quest data formatted for display"""
	var quest_data = current_campaign_data.get("quests", [])
	var display_data: Array[Dictionary] = []
	
	for quest in quest_data:
		var display_quest = {
			"title": quest.get("title", "Unknown Quest"),
			"progress_ratio": _get_quest_progress_ratio(quest),
			"priority": quest.get("priority", "Normal"),
			"type": quest.get("type", "Mission"),
			"description": quest.get("description", "")
		}
		display_data.append(display_quest)
	
	return display_data

func get_world_display_data() -> Dictionary:
	"""Get world data formatted for display"""
	var world_name = current_campaign_data.get("current_world", "Unknown")
	var world_data = current_campaign_data.get("world_info", {})
	
	return {
		"name": world_name,
		"type": world_data.get("type", "Standard"),
		"trade_goods": world_data.get("trade_goods", []),
		"factions": world_data.get("factions", []),
		"threats": world_data.get("threats", []),
		"opportunities": world_data.get("opportunities", [])
	}

## Helper Methods

func _get_health_ratio(crew_member: Dictionary) -> float:
	"""Get health ratio for crew member"""
	var health_current = crew_member.get("health", 0)
	var health_max = crew_member.get("max_health", 1)
	return float(health_current) / float(health_max) if health_max > 0 else 0.0

func _get_crew_status(crew_member: Dictionary) -> String:
	"""Get status string for crew member"""
	var health_ratio = _get_health_ratio(crew_member)
	
	if health_ratio <= 0.0:
		return "Critically Injured"
	elif health_ratio <= 0.25:
		return "Severely Injured"
	elif health_ratio <= 0.5:
		return "Injured"
	elif health_ratio <= 0.75:
		return "Wounded"
	else:
		return "Healthy"

func _get_quest_progress_ratio(quest: Dictionary) -> float:
	"""Get progress ratio for quest"""
	var progress = quest.get("progress", 0)
	var total_steps = quest.get("total_steps", 1)
	return float(progress) / float(total_steps) if total_steps > 0 else 0.0

## Dashboard Actions

func execute_quick_action(action: String, context: Dictionary = {}) -> bool:
	"""Execute quick dashboard action"""
	match action:
		"advance_phase":
			return advance_to_next_phase()
		"save_campaign":
			return _save_campaign()
		"refresh_data":
			_refresh_dashboard_data()
			return true
		"manage_crew":
			quick_action_requested.emit("manage_crew", context)
			return true
		"ship_management":
			quick_action_requested.emit("ship_management", context)
			return true
		_:
			quick_action_requested.emit(action, context)
			return true

func _save_campaign() -> bool:
	"""Save current campaign"""
	if campaign_manager and campaign_manager.has_method("save_current_campaign"):
		campaign_manager.save_current_campaign()
		return true
	elif current_game_state and current_game_state.has_method("save_campaign"):
		current_game_state.save_campaign()
		return true
	return false

func _refresh_dashboard_data() -> void:
	"""Refresh dashboard data from managers"""
	if campaign_manager and campaign_manager.has_method("get_current_campaign"):
		var campaign_data = campaign_manager.get_current_campaign()
		if campaign_data:
			update_campaign_data(campaign_data)

## System Information

func get_dashboard_status() -> Dictionary:
	"""Get dashboard system status"""
	return {
		"mode": current_mode,
		"responsive": is_responsive_mode,
		"campaign_manager_available": campaign_manager != null,
		"phase_manager_available": phase_manager != null,
		"game_state_available": current_game_state != null,
		"last_update": last_update_time,
		"performance_cache_age": Time.get_time_dict_from_system()["unix"] - performance_cache.get("last_calculated", 0.0)
	}

## Safe utility methods
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object:
		if obj.has_method("get"):
			var value = obj.get(property)
			return value if value != null else default_value
		else:
			return default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null