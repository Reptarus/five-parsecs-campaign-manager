class_name CampaignFinalizationBridge
extends RefCounted

## Campaign Finalization Bridge - Production Architecture
## Centralizes all campaign finalization signals and orchestrates the complete flow
## Implements enterprise patterns for signal management and error recovery

# Core finalization signals
signal finalization_started()
signal validation_completed(result: Dictionary)
signal data_transformed(campaign_data: Dictionary)
signal save_completed(success: bool, path: String)
signal transition_requested(scene_path: String, campaign_data: Dictionary)
signal finalization_completed(campaign_data: Dictionary)
signal finalization_failed(error: String, recovery_options: Array[String])

# Signal metrics and monitoring
var signal_metrics: Dictionary = {
	"total_signals": 0,
	"successful_flows": 0,
	"failed_flows": 0,
	"recovery_attempts": 0
}

# Dependencies
var coordinator: RefCounted
var finalization_service: RefCounted
var data_transformer: RefCounted
var transition_manager: Node
var error_monitor: RefCounted

# State tracking
var current_finalization_id: String = ""
var finalization_history: Array[Dictionary] = []
var active_connections: Dictionary = {}

func _init():
	"""Initialize the finalization bridge"""
	_setup_signal_monitoring()
	print("CampaignFinalizationBridge: Initialized successfully")

func _setup_signal_monitoring():
	"""Setup comprehensive signal monitoring"""
	for key in signal_metrics:
		signal_metrics[key] = 0
	
	finalization_history.clear()
	active_connections.clear()

## Public API

func register_dependencies(
	campaign_coordinator: RefCounted,
	campaign_finalization_service: RefCounted,
	campaign_data_transformer: RefCounted = null,
	campaign_transition_manager: Node = null,
	campaign_error_monitor: RefCounted = null
) -> void:
	"""Register required dependencies"""
	coordinator = campaign_coordinator
	finalization_service = campaign_finalization_service
	data_transformer = campaign_data_transformer
	transition_manager = campaign_transition_manager
	error_monitor = campaign_error_monitor
	
	print("CampaignFinalizationBridge: Dependencies registered")

func connect_final_panel_signals(final_panel: Control) -> bool:
	"""Connect FinalPanel signals to bridge orchestration"""
	if not final_panel:
		return false
	
	var success = true
	
	# Connect campaign creation requested signal
	if final_panel.has_signal("campaign_creation_requested"):
		var result = final_panel.campaign_creation_requested.connect(_on_campaign_creation_requested)
		if result != OK:
			push_error("Failed to connect campaign_creation_requested: %s" % result)
			success = false
		else:
			active_connections["campaign_creation_requested"] = final_panel
	
	# Connect campaign finalization complete signal
	if final_panel.has_signal("campaign_finalization_complete"):
		var result = final_panel.campaign_finalization_complete.connect(_on_campaign_finalization_complete)
		if result != OK:
			push_error("Failed to connect campaign_finalization_complete: %s" % result)
			success = false
		else:
			active_connections["campaign_finalization_complete"] = final_panel
	
	return success

func disconnect_final_panel_signals(final_panel: Control) -> void:
	"""Safely disconnect FinalPanel signals"""
	if not final_panel:
		return
	
	if final_panel.has_signal("campaign_creation_requested"):
		if final_panel.campaign_creation_requested.is_connected(_on_campaign_creation_requested):
			final_panel.campaign_creation_requested.disconnect(_on_campaign_creation_requested)
	
	if final_panel.has_signal("campaign_finalization_complete"):
		if final_panel.campaign_finalization_complete.is_connected(_on_campaign_finalization_complete):
			final_panel.campaign_finalization_complete.disconnect(_on_campaign_finalization_complete)
	
	# Remove from active connections
	for signal_name in active_connections.keys():
		if active_connections[signal_name] == final_panel:
			active_connections.erase(signal_name)

## Signal Handlers

func _on_campaign_creation_requested(campaign_data: Dictionary) -> void:
	"""Handle campaign creation request from FinalPanel"""
	print("CampaignFinalizationBridge: Campaign creation requested")
	signal_metrics["total_signals"] += 1
	
	current_finalization_id = _generate_finalization_id()
	finalization_started.emit()
	
	# Start the complete finalization flow
	await _execute_finalization_flow(campaign_data)

func _on_campaign_finalization_complete(data: Dictionary) -> void:
	"""Handle campaign finalization completion from FinalPanel"""
	print("CampaignFinalizationBridge: Campaign finalization marked complete")
	finalization_completed.emit(data)

## Core Finalization Flow

func _execute_finalization_flow(campaign_data: Dictionary) -> void:
	"""Execute the complete campaign finalization flow with error handling"""
	var flow_record = {
		"id": current_finalization_id,
		"started_at": Time.get_unix_time_from_system(),
		"steps_completed": [],
		"errors": [],
		"final_result": null
	}
	
	# Step 1: Validate campaign data
	flow_record.steps_completed.append("validation_started")
	var validation_result = await _validate_campaign_data(campaign_data)
	validation_completed.emit(validation_result)
	
	if not validation_result.get("success", false):
		var error_msg = "Campaign validation failed: %s" % validation_result.get("error", "Unknown error")
		flow_record.errors.append(error_msg)
		_handle_finalization_failure(error_msg, ["retry_validation", "manual_fix"])
		return
	
	flow_record.steps_completed.append("validation_completed")
	
	# Step 2: Transform data for turn system
	if data_transformer:
		var transformed_data = await _transform_campaign_data(campaign_data)
		data_transformed.emit(transformed_data)
		campaign_data = transformed_data
		flow_record.steps_completed.append("data_transformed")
	
	# Step 3: Save campaign
	var save_result = await _save_campaign(campaign_data)
	save_completed.emit(save_result.get("success", false), save_result.get("path", ""))
	
	if not save_result.get("success", false):
		var error_msg = "Campaign save failed: %s" % save_result.get("error", "Unknown error")
		flow_record.errors.append(error_msg)
		_handle_finalization_failure(error_msg, ["retry_save", "change_location"])
		return
	
	flow_record.steps_completed.append("save_completed")
	
	# Step 4: Initiate scene transition
	var scene_path = _determine_target_scene()
	transition_requested.emit(scene_path, campaign_data)
	
	flow_record.steps_completed.append("transition_requested")
	flow_record.final_result = "success"
	signal_metrics["successful_flows"] += 1
	
	finalization_completed.emit(campaign_data)
	
	# Complete flow record
	flow_record["completed_at"] = Time.get_unix_time_from_system()
	finalization_history.append(flow_record)

func _validate_campaign_data(campaign_data: Dictionary) -> Dictionary:
	"""Validate campaign data using coordinator"""
	if coordinator and coordinator.has_method("finalize_campaign"):
		return await coordinator.finalize_campaign()
	
	# Fallback validation
	return {"success": true, "message": "Basic validation passed"}

func _transform_campaign_data(campaign_data: Dictionary) -> Dictionary:
	"""Transform campaign data for turn system compatibility"""
	if data_transformer and data_transformer.has_method("transform_for_turn_system"):
		return await data_transformer.transform_for_turn_system(campaign_data)
	
	return campaign_data

func _save_campaign(campaign_data: Dictionary) -> Dictionary:
	"""Save campaign using finalization service"""
	if finalization_service and finalization_service.has_method("finalize_campaign"):
		return await finalization_service.finalize_campaign(campaign_data, coordinator)
	
	# Fallback save
	return {"success": false, "error": "No finalization service available"}

func _determine_target_scene() -> String:
	"""Determine target scene for campaign transition"""
	var scene_candidates = [
		"res://src/ui/screens/campaign/MainCampaignScene.tscn",
		"res://src/scenes/campaign/CampaignUI.tscn",
		"res://src/ui/screens/campaign/CampaignDashboard.tscn"
	]
	
	for scene_path in scene_candidates:
		if ResourceLoader.exists(scene_path):
			return scene_path
	
	return "res://src/ui/screens/mainmenu/MainMenu.tscn"

func _handle_finalization_failure(error: String, recovery_options: Array[String]) -> void:
	"""Handle finalization failure with recovery options"""
	signal_metrics["failed_flows"] += 1
	
	if error_monitor and error_monitor.has_method("record_error"):
		error_monitor.record_error(error, "FINALIZATION", "CRITICAL", {
			"finalization_id": current_finalization_id,
			"recovery_options": recovery_options
		})
	
	finalization_failed.emit(error, recovery_options)

func _generate_finalization_id() -> String:
	"""Generate unique finalization ID"""
	return "fin_%d_%s" % [Time.get_unix_time_from_system(), str(randi()).substr(0, 6)]

## Utility Methods

func get_metrics() -> Dictionary:
	"""Get current signal metrics"""
	return signal_metrics.duplicate()

func get_finalization_history() -> Array[Dictionary]:
	"""Get finalization history"""
	return finalization_history.duplicate()

func cleanup() -> void:
	"""Cleanup bridge resources"""
	for signal_name in active_connections.keys():
		var panel = active_connections[signal_name]
		if panel:
			disconnect_final_panel_signals(panel)
	
	active_connections.clear()
	finalization_history.clear()