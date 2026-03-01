extends RefCounted
class_name CampaignSignals

## Simple Campaign Signals System - Framework Bible Compliant  
## Provides basic signal management for campaign events
## NO Manager/Enhanced bloat - just the essential functionality WorldInfoPanel needs

# Campaign world signals
signal world_discovered(world_data: Dictionary)
signal location_explored(location_name: String, discoveries: Array)
signal patron_encountered(patron_data: Dictionary)
signal rival_threat_identified(threat_data: Dictionary)
signal trade_opportunity_identified(opportunity: Dictionary)

# UI interaction signals
signal opportunity_selected(opportunity_id: String)
signal threat_selected(threat_id: String)
signal quick_action_requested(action: String, data: Variant)

func _init() -> void:
	pass

## Simple signal connection method
func connect_signal_safely(signal_name: String, target: Object, method_name: String) -> bool:
	## Connect signal safely with basic error checking
	if not has_signal(signal_name):
		push_warning("CampaignSignals: Signal '%s' not found" % signal_name)
		return false
	
	if not target:
		push_warning("CampaignSignals: Target is null for signal '%s'" % signal_name)
		return false
	
	if not target.has_method(method_name):
		push_warning("CampaignSignals: Target method '%s' not found" % method_name)
		return false
	
	var callable = Callable(target, method_name)
	if is_connected(signal_name, callable):
		return true # Already connected
	
	var error = connect(signal_name, callable)
	if error != OK:
		push_error("CampaignSignals: Failed to connect signal '%s': %s" % [signal_name, error])
		return false
	
	return true

## Simple signal emission method
func emit_safe_signal(signal_name: String, args: Array = []) -> bool:
	## Emit signal safely with basic error checking
	if not has_signal(signal_name):
		push_warning("CampaignSignals: Cannot emit unknown signal '%s'" % signal_name)
		return false
	
	match args.size():
		0: emit_signal(signal_name)
		1: emit_signal(signal_name, args[0])
		2: emit_signal(signal_name, args[0], args[1])
		3: emit_signal(signal_name, args[0], args[1], args[2])
		_: 
			push_warning("CampaignSignals: Too many arguments for signal '%s'" % signal_name)
			return false
	
	return true

## Convenience methods for specific campaign events
func emit_world_discovered(world_data: Dictionary) -> void:
	world_discovered.emit(world_data)

func emit_location_explored(location_name: String, discoveries: Array) -> void:
	location_explored.emit(location_name, discoveries)

func emit_patron_encountered(patron_data: Dictionary) -> void:
	patron_encountered.emit(patron_data)

func emit_rival_threat_identified(threat_data: Dictionary) -> void:
	rival_threat_identified.emit(threat_data)

func emit_trade_opportunity_identified(opportunity: Dictionary) -> void:
	trade_opportunity_identified.emit(opportunity)

func emit_opportunity_selected(opportunity_id: String) -> void:
	opportunity_selected.emit(opportunity_id)

func emit_threat_selected(threat_id: String) -> void:
	threat_selected.emit(threat_id)

func emit_quick_action_requested(action: String, data: Variant) -> void:
	quick_action_requested.emit(action, data)
