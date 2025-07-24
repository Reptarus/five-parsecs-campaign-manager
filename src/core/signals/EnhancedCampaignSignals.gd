@tool
extends RefCounted
class_name EnhancedCampaignSignals

## Enhanced Campaign Signals - Centralized signal management for enhanced features
## Follows established signal patterns from successful existing systems
## Provides event-driven communication for dashboard and logbook systems

# Data signals for enhanced campaign tracking
signal planet_data_updated(planet_name: String, data: Dictionary)
signal mission_logged(mission_data: Dictionary)
signal relationship_changed(entity_name: String, change: Dictionary)
signal economic_data_updated(credits: int, debt: int)
signal crew_status_changed(crew_member: String, status: Dictionary)
signal ship_status_updated(ship_data: Dictionary)

# UI signals for enhanced dashboard and logbook
signal dashboard_panel_changed(panel_type: String)
signal logbook_entry_selected(entry_id: String)
signal quick_action_requested(action: String, context: Dictionary)
signal quest_progress_updated(quest_id: String, progress: float)
signal world_info_requested(world_name: String)

# Enhanced logbook signals
signal logbook_search_performed(search_term: String, results: Array)
signal logbook_filter_applied(filter_type: String, filter_value: Variant)
signal predictive_suggestion_generated(suggestion_type: String, data: Dictionary)
signal data_visualization_requested(chart_type: String, data: Array)

# Crew management signals
signal crew_member_selected(crew_id: String)
signal crew_performance_updated(crew_id: String, performance: Dictionary)
signal crew_equipment_changed(crew_id: String, equipment: Dictionary)
signal crew_health_changed(crew_id: String, health_ratio: float)

# Ship management signals
signal ship_hull_damaged(damage_amount: int)
signal ship_repair_completed(repair_amount: int)
signal ship_modification_added(modification: Dictionary)
signal ship_debt_changed(new_debt: int)

# Quest and mission signals
signal quest_started(quest_data: Dictionary)
signal quest_completed(quest_data: Dictionary, rewards: Dictionary)
signal quest_failed(quest_data: Dictionary, reason: String)
signal quest_progress_made(quest_id: String, step_completed: String)

# World and exploration signals
signal world_discovered(world_data: Dictionary)
signal location_explored(location_name: String, discoveries: Array)
signal patron_encountered(patron_data: Dictionary)
signal rival_threat_identified(threat_data: Dictionary)

# World Phase specific signals - Feature 3 integration
signal world_phase_started(phase_data: Dictionary)
signal world_phase_completed(phase_results: Dictionary)
signal world_substep_changed(substep_id: String, substep_name: String)
signal world_substep_completed(substep_id: String, results: Dictionary)

# Crew task signals for World Phase
signal crew_task_assigned(crew_id: String, task_type: String, task_data: Dictionary)
signal crew_task_started(crew_id: String, task_type: String)
signal crew_task_rolling(crew_id: String, dice_type: String, context: String)
signal crew_task_result(crew_id: String, task_result: Dictionary)
signal crew_task_completed(crew_id: String, task_type: String, success: bool, rewards: Dictionary)
signal all_crew_tasks_resolved(crew_results: Array)

# World Phase automation signals
signal automation_started(assigned_tasks: Dictionary)
signal automation_progress_updated(completed_count: int, total_count: int)
signal automation_completed(all_results: Dictionary)
signal automation_paused(current_task: String, reason: String)

# World Phase job and patron signals
signal patron_contact_established(patron_data: Dictionary)
signal patron_relationship_changed(patron_id: String, relationship_change: int)
signal job_offer_generated(job_data: Dictionary)
signal job_opportunity_discovered(opportunity_type: String, data: Dictionary)
signal job_offers_updated(available_jobs: Array)

# World Phase trade signals
signal trade_opportunity_found(trade_data: Dictionary)
signal trade_transaction_completed(result: Dictionary)
signal market_analysis_completed(market_data: Dictionary)

# World Phase exploration enhancement signals
signal exploration_site_discovered(site_data: Dictionary)
signal exploration_result_processed(exploration_result: Dictionary)
signal valuable_discovery_made(discovery_type: String, value: int)
signal equipment_discovered(equipment_data: Dictionary)
signal story_point_gained(source: String, points: int)

# World Phase world interaction signals
signal world_trait_discovered(trait_name: String, trait_data: Dictionary)
signal world_modifier_applied(modifier_type: String, modifier_value: int)
signal world_danger_assessed(danger_level: int, factors: Array)
signal world_economic_status_updated(economy_data: Dictionary)

# Economic signals
signal trade_opportunity_identified(opportunity: Dictionary)
signal market_price_changed(commodity: String, new_price: int)
signal credit_transaction(amount: int, reason: String)
signal debt_payment_made(amount: int)

# Predictive analysis signals
signal pattern_discovered(pattern_type: String, confidence: float)
signal suggestion_generated(suggestion_type: String, data: Dictionary)
signal risk_assessment(risk_level: String, factors: Array)

# Universal safety signals
signal data_validation_failed(component: String, error: String)
signal safe_operation_completed(operation: String, result: Dictionary)
signal error_recovered(component: String, recovery_method: String)

# Responsive design signals
signal layout_changed(orientation: String)
signal touch_optimization_applied()
signal accessibility_feature_toggled(feature: String, enabled: bool)

# Performance monitoring signals
signal performance_metric_recorded(metric: String, value: float)
signal memory_usage_updated(usage_mb: float)
signal frame_rate_monitored(fps: float)

# Integration signals with existing systems
signal dice_system_integration(dice_result: int, context: String)
signal story_track_updated(story_event: Dictionary)
signal battle_event_logged(battle_data: Dictionary)

# Data persistence signals
signal data_saved(save_type: String, success: bool)
signal data_loaded(load_type: String, success: bool)
signal backup_created(backup_id: String)
signal data_exported(export_type: String, file_path: String)

# Notification signals
signal notification_displayed(message: String, type: String)
signal alert_triggered(alert_type: String, data: Dictionary)
signal confirmation_requested(message: String, callback: Callable)

# Debug and development signals
signal debug_info_logged(component: String, info: String)
signal development_mode_toggled(enabled: bool)
signal test_mode_activated(test_type: String)

## Signal connection helpers following Universal Safety patterns
func connect_signal_safely(signal_name: String, target: Object, method: String) -> bool:
	if not has_signal(signal_name):
		push_warning("EnhancedCampaignSignals: Signal '%s' not found" % signal_name)
		return false
	
	if not target or not target.has_method(method):
		push_warning("EnhancedCampaignSignals: Target method '%s' not found" % method)
		return false
	
	# Use Callable for Godot 4.4 signal connections
	var callable = Callable(target, method)
	connect(signal_name, callable)
	return true

func disconnect_signal_safely(signal_name: String, target: Object, method: String) -> bool:
	if not has_signal(signal_name):
		return false
	
	if not target:
		return false
	
	# Use Callable for Godot 4.4 signal disconnections
	var callable = Callable(target, method)
	if is_connected(signal_name, callable):
		disconnect(signal_name, callable)
		return true
	
	return false

## Signal emission helpers with validation
func emit_safe_signal(signal_name: String, args: Array = []) -> bool:
	if not has_signal(signal_name):
		push_warning("EnhancedCampaignSignals: Cannot emit unknown signal '%s'" % signal_name)
		return false
	
	callv(signal_name, args)
	return true

## Batch signal operations for performance
func emit_batch_signals(signals_data: Array) -> void:
	for signal_data in signals_data:
		var signal_name: String = signal_data.get("signal", "")
		var args: Array = signal_data.get("args", [])
		emit_safe_signal(signal_name, args)

## Signal monitoring for debugging
var _signal_monitor: Dictionary = {}

func start_signal_monitoring(signal_name: String) -> void:
	if not _signal_monitor.has(signal_name):
		_signal_monitor[signal_name] = 0
	
	# Use Callable for Godot 4.4 signal connections
	var callable = Callable(self, "_on_signal_monitored")
	connect(signal_name, callable)
	_signal_monitor[signal_name] = 0

func stop_signal_monitoring(signal_name: String) -> void:
	if _signal_monitor.has(signal_name):
		# Use Callable for Godot 4.4 signal disconnections
		var callable = Callable(self, "_on_signal_monitored")
		disconnect(signal_name, callable)
		_signal_monitor.erase(signal_name)

func _on_signal_monitored() -> void:
	var signal_name: String = get_signal_list()[0].name
	if _signal_monitor.has(signal_name):
		_signal_monitor[signal_name] += 1

func get_signal_count(signal_name: String) -> int:
	return _signal_monitor.get(signal_name, 0)

## World Phase specific signal helpers - Feature 3 integration

## Emit crew task sequence signals with validation
func emit_crew_task_sequence(crew_id: String, task_type: String, task_data: Dictionary, dice_type: String = "") -> void:
	"""Emit the complete sequence of crew task signals with validation"""
	if crew_id.is_empty() or task_type.is_empty():
		push_warning("EnhancedCampaignSignals: Invalid crew task parameters")
		return
	
	# Task assignment
	crew_task_assigned.emit(crew_id, task_type, task_data)
	
	# Task start
	crew_task_started.emit(crew_id, task_type)
	
	# Rolling if dice type specified
	if not dice_type.is_empty():
		crew_task_rolling.emit(crew_id, dice_type, task_type)

## Emit world phase progress signals
func emit_world_phase_progress(phase_results: Dictionary) -> void:
	"""Emit comprehensive world phase completion signals"""
	if phase_results.is_empty():
		push_warning("EnhancedCampaignSignals: Empty phase results provided")
		return
	
	# Emit individual result signals based on content
	if phase_results.has("patrons_found"):
		var patrons = phase_results["patrons_found"]
		if typeof(patrons) == TYPE_ARRAY:
			for patron in patrons:
				if typeof(patron) == TYPE_DICTIONARY:
					patron_contact_established.emit(patron)
	
	if phase_results.has("equipment_found"):
		var equipment = phase_results["equipment_found"]
		if typeof(equipment) == TYPE_ARRAY:
			for item in equipment:
				if typeof(item) == TYPE_DICTIONARY:
					equipment_discovered.emit(item)
	
	if phase_results.has("story_points_gained"):
		var points = phase_results.get("story_points_gained", 0)
		if points > 0:
			story_point_gained.emit("world_phase", points)
	
	# Final completion signal
	world_phase_completed.emit(phase_results)

## Emit automation progress with safety
func emit_automation_progress(completed: int, total: int, current_results: Dictionary = {}) -> void:
	"""Emit automation progress with validation"""
	if completed < 0 or total <= 0 or completed > total:
		push_warning("EnhancedCampaignSignals: Invalid automation progress values")
		return
	
	automation_progress_updated.emit(completed, total)
	
	# If automation is complete
	if completed == total and not current_results.is_empty():
		automation_completed.emit(current_results)

## Batch emit world phase discovery signals
func emit_world_phase_discoveries(discoveries: Array) -> void:
	"""Batch emit multiple discovery signals efficiently"""
	if discoveries.is_empty():
		return
	
	var signal_batch: Array = []
	
	for discovery in discoveries:
		if typeof(discovery) != TYPE_DICTIONARY:
			continue
		
		var discovery_dict: Dictionary = discovery
		var discovery_type = discovery_dict.get("type", "")
		
		match discovery_type:
			"patron":
				signal_batch.append({"signal": "patron_contact_established", "args": [discovery_dict]})
			"equipment":
				signal_batch.append({"signal": "equipment_discovered", "args": [discovery_dict]})
			"trade":
				signal_batch.append({"signal": "trade_opportunity_found", "args": [discovery_dict]})
			"exploration":
				signal_batch.append({"signal": "exploration_site_discovered", "args": [discovery_dict]})
			"world_trait":
				var trait_name = discovery_dict.get("name", "unknown")
				signal_batch.append({"signal": "world_trait_discovered", "args": [trait_name, discovery_dict]})
	
	emit_batch_signals(signal_batch)

## Connect world phase signals safely to target object
func connect_world_phase_signals(target: Object) -> bool:
	"""Connect all world phase signals to target object with standard method names"""
	if not target:
		push_warning("EnhancedCampaignSignals: Cannot connect to null target")
		return false
	
	var connections_made: int = 0
	var world_phase_signals: Array[String] = [
		"world_phase_started", "world_phase_completed", "world_substep_changed",
		"crew_task_assigned", "crew_task_started", "crew_task_rolling", 
		"crew_task_result", "crew_task_completed", "all_crew_tasks_resolved",
		"automation_started", "automation_progress_updated", "automation_completed",
		"patron_contact_established", "job_offer_generated", "trade_opportunity_found",
		"exploration_result_processed", "equipment_discovered", "story_point_gained"
	]
	
	for signal_name in world_phase_signals:
		var method_name = "_on_" + signal_name
		if target.has_method(method_name):
			if connect_signal_safely(signal_name, target, method_name):
				connections_made += 1
	
	print("EnhancedCampaignSignals: Connected %d world phase signals to %s" % [connections_made, target.get_class()])
	return connections_made > 0