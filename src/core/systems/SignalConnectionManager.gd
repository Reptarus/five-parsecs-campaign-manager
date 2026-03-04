@tool
class_name SignalConnectionManager
extends RefCounted

## Signal Connection Manager with Naming Consistency
## Handles signal naming variations and ensures robust connections
## Prevents connection failures due to signal naming inconsistencies

## Standardized signal connection wrapper with fallbacks
static func connect_panel_signals_safely(panel: Control, coordinator) -> bool:
	if not panel or not coordinator:
		push_error("SignalConnectionManager: Invalid panel or coordinator")
		return false
	
	var panel_class = panel.get_class()
	
	var success_count = 0
	var total_attempts = 0
	
	# Get signal mappings for this panel type
	var mappings = _get_signal_mappings(panel_class)
	
	for mapping in mappings:
		total_attempts += 1
		if _connect_single_signal(panel, coordinator, mapping):
			success_count += 1
	
	# Connect common panel signals
	var common_mappings = _get_common_signal_mappings()
	for mapping in common_mappings:
		total_attempts += 1
		if _connect_single_signal(panel, coordinator, mapping):
			success_count += 1
	
	var success_rate = (float(success_count) / float(total_attempts)) * 100.0 if total_attempts > 0 else 0.0
	pass # Signals connected
	
	return success_count > 0

static func _connect_single_signal(panel: Control, coordinator, mapping: Dictionary) -> bool:
	## Connect a single signal with fallback attempts
	var signal_variants = mapping.get("signal_variants", [mapping.signal ])
	var method_name = mapping.method
	
	# Verify coordinator has the target method
	if not coordinator.has_method(method_name):
		push_warning("SignalConnectionManager: Coordinator missing method: %s" % method_name)
		return false
	
	# Try each signal variant until one works
	for signal_name in signal_variants:
		if panel.has_signal(signal_name):
			# Check if already connected to avoid duplicate connections
			var callable_method = Callable(coordinator, method_name)
			if not panel.is_connected(signal_name, callable_method):
				panel.connect(signal_name, callable_method)
				return true
			else:
				return true
	
	# Log missing signals for debugging
	return false

static func _get_signal_mappings(panel_class: String) -> Array[Dictionary]:
	## Get signal mappings specific to panel type
	var mappings: Array[Dictionary] = []
	
	match panel_class:
		"CrewPanel", "FPCM_CrewPanel":
			mappings = [
				{
					"signal_variants": ["crew_updated", "crew_data_complete", "crew_changed", "crew_data_changed"],
					"method": "update_crew_state"
				},
				{
					"signal_variants": ["character_generated", "character_created", "crew_member_added"],
					"method": "on_character_generated"
				}
			]
		
		"CaptainPanel", "FPCM_CaptainPanel":
			mappings = [
				{
					"signal_variants": ["captain_created", "captain_updated", "captain_generated", "captain_changed"],
					"method": "update_captain_state"
				},
				{
					"signal_variants": ["captain_customization_requested", "captain_edit_requested"],
					"method": "on_captain_customization_requested"
				}
			]
		
		"VictoryConditionsPanel":
			mappings = [
				{
					"signal_variants": ["victory_conditions_updated", "victory_conditions_changed", "conditions_updated"],
					"method": "update_victory_conditions_state"
				}
			]
		
		"WorldInfoPanel":
			mappings = [
				{
					"signal_variants": ["world_generated", "world_updated", "world_created", "planet_generated"],
					"method": "update_world_state"
				}
			]
		
		"EquipmentPanel":
			mappings = [
				{
					"signal_variants": ["equipment_generated", "equipment_updated", "equipment_created", "equipment_changed"],
					"method": "update_equipment_state"
				}
			]
		
		"ShipPanel":
			mappings = [
				{
					"signal_variants": ["ship_updated", "ship_changed", "ship_assigned", "ship_selected"],
					"method": "update_ship_state"
				}
			]
		
		"FinalPanel":
			mappings = [
				{
					"signal_variants": ["review_completed", "final_review_complete", "campaign_validated"],
					"method": "on_final_review_completed"
				}
			]
	
	return mappings

static func _get_common_signal_mappings() -> Array[Dictionary]:
	## Get signal mappings common to all panels
	return [
		{
			"signal_variants": ["panel_data_changed", "data_changed", "state_changed"],
			"method": "_on_panel_data_changed"
		},
		{
			"signal_variants": ["panel_completed", "panel_finished", "step_completed"],
			"method": "_on_panel_completed"
		},
		{
			"signal_variants": ["panel_ready", "initialization_complete", "setup_complete"],
			"method": "_on_panel_ready"
		},
		{
			"signal_variants": ["validation_failed", "panel_error", "error_occurred"],
			"method": "_on_panel_error"
		}
	]

## Connect state update methods specifically  
static func connect_state_update_methods(panel: Control, coordinator) -> bool:
	## Connect existing _on_campaign_state_updated methods to coordinator
	if not panel or not coordinator:
		return false
	
	var connected = false
	
	# Check for existing state update methods
	var state_update_methods = [
		"_on_campaign_state_updated",
		"_on_state_updated",
		"on_campaign_state_updated",
		"update_from_state"
	]
	
	for method in state_update_methods:
		if panel.has_method(method):
			# Connect coordinator's state update signal to panel method
			if coordinator.has_signal("campaign_data_updated"):
				var callable_method = Callable(panel, method)
				if not coordinator.is_connected("campaign_data_updated", callable_method):
					coordinator.connect("campaign_data_updated", callable_method)
					pass # State updates connected
					connected = true
				else:
					pass # Already connected
					connected = true
				break
	
	if not connected:
		pass # No state update method found
	
	return connected

## Disconnect all signals safely
static func disconnect_panel_signals_safely(panel: Control, coordinator) -> void:
	## Safely disconnect all panel signals
	if not panel or not coordinator or not is_instance_valid(panel) or not is_instance_valid(coordinator):
		return
	
	pass # Disconnecting signals
	
	# Get all potential signal connections
	var all_mappings = _get_signal_mappings(panel.get_class())
	all_mappings.append_array(_get_common_signal_mappings())
	
	for mapping in all_mappings:
		var method_name = mapping.method
		if coordinator.has_method(method_name):
			var callable_method = Callable(coordinator, method_name)
			
			for signal_name in mapping.get("signal_variants", []):
				if panel.has_signal(signal_name) and panel.is_connected(signal_name, callable_method):
					panel.disconnect(signal_name, callable_method)

## Debug: List all signals available on a panel
static func debug_list_panel_signals(panel: Control) -> Array[String]:
	## List all available signals on a panel for debugging
	var signals: Array[String] = []
	
	if not panel:
		return signals
	
	var signal_list = panel.get_signal_list()
	for signal_info in signal_list:
		signals.append(signal_info.name)
	
	pass # Panel signals listed
	return signals

## Debug: List all methods available on coordinator
static func debug_list_coordinator_methods(coordinator) -> Array[String]:
	## List all available methods on coordinator for debugging
	var methods: Array[String] = []
	
	if not coordinator:
		return methods
	
	var method_list = coordinator.get_method_list()
	for method_info in method_list:
		if method_info.name.begins_with("update_") or method_info.name.begins_with("on_"):
			methods.append(method_info.name)
	
	pass # Coordinator methods listed
	return methods