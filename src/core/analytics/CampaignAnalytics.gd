class_name CampaignAnalytics
extends RefCounted

## CampaignAnalytics - Comprehensive analytics tracking for campaign creation
## Tracks completion times, validation errors, drop-off points, and feature usage

# Analytics data storage
var session_data: Dictionary = {}
var phase_times: Dictionary = {}
var validation_errors: Dictionary = {}
var feature_usage: Dictionary = {}
var user_interactions: Array[Dictionary] = []

# Session tracking
var session_start_time: float = 0.0
var current_phase_start_time: float = 0.0
var current_phase: String = ""

# Analytics events
signal analytics_event_recorded(event_type: String, data: Dictionary)

func _init():
	session_start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	session_data = {
		"session_id": _generate_session_id(),
		"start_time": session_start_time,
		"godot_version": Engine.get_version_info(),
		"platform": OS.get_name(),
		"screen_size": DisplayServer.screen_get_size()
	}

## Public API - Phase Tracking

func start_phase(phase_name: String) -> void:
	## Start tracking a new phase
	# End previous phase if active
	if not current_phase.is_empty():
		end_phase(current_phase)
	
	current_phase = phase_name
	current_phase_start_time = _get_current_time()
	
	# Initialize phase data
	if not phase_times.has(phase_name):
		phase_times[phase_name] = {
			"total_time": 0.0,
			"attempts": 0,
			"completed": false,
			"first_visit_time": current_phase_start_time
		}
	
	phase_times[phase_name].attempts += 1
	
	_record_interaction("phase_started", {
		"phase": phase_name,
		"attempt": phase_times[phase_name].attempts
	})

func end_phase(phase_name: String, completed: bool = true) -> void:
	## End tracking for a phase
	if not phase_times.has(phase_name):
		return
	
	var phase_duration = _get_current_time() - current_phase_start_time
	phase_times[phase_name].total_time += phase_duration
	phase_times[phase_name].completed = completed
	
	_record_interaction("phase_ended", {
		"phase": phase_name,
		"duration": phase_duration,
		"completed": completed,
		"total_time": phase_times[phase_name].total_time
	})
	
	current_phase = ""
	current_phase_start_time = 0.0

func mark_phase_complete(phase_name: String) -> void:
	## Mark a phase as completed
	if phase_times.has(phase_name):
		phase_times[phase_name].completed = true
		_record_interaction("phase_completed", {"phase": phase_name})

## Public API - Validation Error Tracking

func record_validation_error(phase: String, error_type: String, error_message: String) -> void:
	## Record a validation error
	if not validation_errors.has(phase):
		validation_errors[phase] = {}
	
	if not validation_errors[phase].has(error_type):
		validation_errors[phase][error_type] = {
			"count": 0,
			"messages": [],
			"first_occurrence": _get_current_time()
		}
	
	validation_errors[phase][error_type].count += 1
	if not validation_errors[phase][error_type].messages.has(error_message):
		validation_errors[phase][error_type].messages.append(error_message)
	
	_record_interaction("validation_error", {
		"phase": phase,
		"error_type": error_type,
		"error_message": error_message
	})

func record_validation_success(phase: String) -> void:
	## Record successful validation
	_record_interaction("validation_success", {"phase": phase})

## Public API - Feature Usage Tracking

func record_feature_usage(feature_name: String, feature_value: Variant = null) -> void:
	## Record usage of a specific feature
	if not feature_usage.has(feature_name):
		feature_usage[feature_name] = {
			"usage_count": 0,
			"values": {},
			"first_used": _get_current_time()
		}
	
	feature_usage[feature_name].usage_count += 1
	
	if feature_value != null:
		var value_key = str(feature_value)
		if not feature_usage[feature_name].values.has(value_key):
			feature_usage[feature_name].values[value_key] = 0
		feature_usage[feature_name].values[value_key] += 1
	
	_record_interaction("feature_used", {
		"feature": feature_name,
		"value": feature_value
	})

func record_drop_off(phase: String, reason: String = "unknown") -> void:
	## Record when user drops off without completing
	_record_interaction("drop_off", {
		"phase": phase,
		"reason": reason,
		"completion_percentage": _calculate_completion_percentage()
	})

## Public API - Analytics Reporting

func get_session_summary() -> Dictionary:
	## Get comprehensive session analytics summary
	var current_time = _get_current_time()
	var session_duration = current_time - session_start_time
	
	return {
		"session_data": session_data,
		"session_duration": session_duration,
		"phase_analytics": _get_phase_analytics(),
		"validation_analytics": _get_validation_analytics(),
		"feature_analytics": _get_feature_analytics(),
		"interaction_count": user_interactions.size(),
		"completion_percentage": _calculate_completion_percentage(),
		"performance_metrics": _get_performance_metrics()
	}

func get_phase_completion_times() -> Dictionary:
	## Get completion times for each phase
	var completion_times = {}
	for phase in phase_times:
		if phase_times[phase].completed:
			completion_times[phase] = phase_times[phase].total_time
	return completion_times

func get_validation_error_summary() -> Dictionary:
	## Get summary of validation errors
	var error_summary = {
		"total_errors": 0,
		"errors_by_phase": {},
		"most_common_errors": []
	}
	
	var error_counts = {}
	
	for phase in validation_errors:
		error_summary.errors_by_phase[phase] = 0
		for error_type in validation_errors[phase]:
			var count = validation_errors[phase][error_type].count
			error_summary.total_errors += count
			error_summary.errors_by_phase[phase] += count
			
			# Track most common errors
			if not error_counts.has(error_type):
				error_counts[error_type] = 0
			error_counts[error_type] += count
	
	# Sort errors by frequency
	var sorted_errors = []
	for error_type in error_counts:
		sorted_errors.append({"type": error_type, "count": error_counts[error_type]})
	
	sorted_errors.sort_custom(func(a, b): return a.count > b.count)
	error_summary.most_common_errors = sorted_errors.slice(0, 5)  # Top 5
	
	return error_summary

func export_analytics_data() -> Dictionary:
	## Export complete analytics data for external analysis
	return {
		"session_summary": get_session_summary(),
		"raw_interactions": user_interactions,
		"detailed_phase_times": phase_times,
		"detailed_validation_errors": validation_errors,
		"detailed_feature_usage": feature_usage,
		"export_timestamp": _get_current_time()
	}

## Internal Methods

func _generate_session_id() -> String:
	## Generate unique session ID
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "session_%d_%04d" % [timestamp, random_suffix]

func _get_current_time() -> float:
	## Get current time as float for calculations
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600.0 + time_dict.minute * 60.0 + time_dict.second

func _record_interaction(event_type: String, data: Dictionary) -> void:
	## Record a user interaction
	var interaction = {
		"timestamp": _get_current_time(),
		"event_type": event_type,
		"data": data
	}
	
	user_interactions.append(interaction)
	analytics_event_recorded.emit(event_type, data)
	
	# Limit interaction history to prevent memory issues
	if user_interactions.size() > 1000:
		user_interactions = user_interactions.slice(-500)  # Keep last 500

func _get_phase_analytics() -> Dictionary:
	## Get phase analytics summary
	var analytics = {
		"phases_attempted": phase_times.keys().size(),
		"phases_completed": 0,
		"average_time_per_phase": 0.0,
		"total_time_all_phases": 0.0,
		"phase_details": {}
	}
	
	var total_time = 0.0
	for phase in phase_times:
		var phase_data = phase_times[phase]
		total_time += phase_data.total_time
		
		if phase_data.completed:
			analytics.phases_completed += 1
		
		analytics.phase_details[phase] = {
			"completed": phase_data.completed,
			"total_time": phase_data.total_time,
			"attempts": phase_data.attempts,
			"average_time_per_attempt": phase_data.total_time / max(1, phase_data.attempts)
		}
	
	analytics.total_time_all_phases = total_time
	if analytics.phases_attempted > 0:
		analytics.average_time_per_phase = total_time / analytics.phases_attempted
	
	return analytics

func _get_validation_analytics() -> Dictionary:
	## Get validation analytics summary
	return get_validation_error_summary()

func _get_feature_analytics() -> Dictionary:
	## Get feature usage analytics
	var analytics = {
		"features_used": feature_usage.keys().size(),
		"total_feature_interactions": 0,
		"most_used_features": []
	}
	
	var feature_counts = []
	for feature in feature_usage:
		var count = feature_usage[feature].usage_count
		analytics.total_feature_interactions += count
		feature_counts.append({"feature": feature, "count": count})
	
	feature_counts.sort_custom(func(a, b): return a.count > b.count)
	analytics.most_used_features = feature_counts.slice(0, 10)  # Top 10
	
	return analytics

func _calculate_completion_percentage() -> float:
	## Calculate overall completion percentage
	if phase_times.is_empty():
		return 0.0
	
	var expected_phases = ["configuration", "crew_setup", "captain_creation", "ship_assignment", "equipment_generation", "final_review"]
	var completed_count = 0
	
	for phase in expected_phases:
		if phase_times.has(phase) and phase_times[phase].completed:
			completed_count += 1
	
	return (float(completed_count) / float(expected_phases.size())) * 100.0

func _get_performance_metrics() -> Dictionary:
	## Get performance-related metrics
	return {
		"total_interactions": user_interactions.size(),
		"average_time_between_interactions": _calculate_average_interaction_time(),
		"session_duration": _get_current_time() - session_start_time
	}

func _calculate_average_interaction_time() -> float:
	## Calculate average time between interactions
	if user_interactions.size() < 2:
		return 0.0
	
	var total_time_diff = 0.0
	for i in range(1, user_interactions.size()):
		total_time_diff += user_interactions[i].timestamp - user_interactions[i-1].timestamp
	
	return total_time_diff / (user_interactions.size() - 1)
