@tool
class_name AuditLogger
extends RefCounted

## Audit Logger for Security Events
## Provides secure logging of security-related events with tamper resistance

# Audit configuration
const MAX_LOG_SIZE = 1024 * 1024  # 1MB
const MAX_LOG_ENTRIES = 10000
const LOG_ROTATION_COUNT = 5

# Audit state
var _session_id: String = ""
var _log_file_path: String = ""
var _log_entries: Array[Dictionary] = []
var _log_file: FileAccess
var _is_initialized: bool = false
var _entries_count: int = 0

func initialize(session_id: String) -> void:
	"""Initialize audit logger with session ID"""
	_session_id = session_id
	_setup_log_file()
	_is_initialized = true
	
	# Log initialization
	log_event({
		"event": "AUDIT_LOGGER_INITIALIZED",
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"log_file": _log_file_path
	})

func _setup_log_file() -> void:
	"""Setup audit log file with proper permissions"""
	var logs_dir = "user://logs/audit"
	
	# Ensure logs directory exists
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.open("user://").make_dir_recursive("logs/audit")
	
	# Create log file with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_log_file_path = "%s/audit_%s_%s.log" % [logs_dir, _session_id, timestamp]
	
	# Open log file for writing
	_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if not _log_file:
		push_error("AuditLogger: Failed to create audit log file: %s" % _log_file_path)
		return
	
	# Write log header
	var header = {
		"audit_log_version": "1.0",
		"session_id": _session_id,
		"created_at": Time.get_unix_time_from_system(),
		"godot_version": Engine.get_version_info(),
		"platform": OS.get_name()
	}
	
	_write_log_entry(header)
	_log_file.flush()

func log_event(event_data: Dictionary) -> void:
	"""Log a security event with integrity protection"""
	if not _is_initialized:
		push_warning("AuditLogger: Attempted to log event before initialization")
		return
	
	# Add metadata
	var enhanced_event = event_data.duplicate(true)
	enhanced_event["log_sequence"] = _entries_count
	enhanced_event["log_timestamp"] = Time.get_unix_time_from_system()
	enhanced_event["integrity_hash"] = _calculate_event_hash(enhanced_event)
	
	# Add to in-memory buffer
	_log_entries.append(enhanced_event)
	_entries_count += 1
	
	# Write to file if available
	if _log_file:
		_write_log_entry(enhanced_event)
		_log_file.flush()
	
	# Check for log rotation
	if _entries_count >= MAX_LOG_ENTRIES:
		_rotate_logs()

func _write_log_entry(entry: Dictionary) -> void:
	"""Write log entry to file"""
	if not _log_file:
		return
	
	var json_line = JSON.stringify(entry) + "\n"
	_log_file.store_string(json_line)

func _calculate_event_hash(event: Dictionary) -> String:
	"""Calculate simple integrity hash for event"""
	var event_copy = event.duplicate(true)
	event_copy.erase("integrity_hash")  # Don't include hash in hash calculation
	
	var event_string = JSON.stringify(event_copy)
	var hash_input = event_string + _session_id
	
	# Simple hash (in production, use proper cryptographic hash)
	var hash_value = hash_input.hash()
	return str(hash_value)

func _rotate_logs() -> void:
	"""Rotate log files when they get too large"""
	if not _log_file:
		return
	
	# Close current log file
	_log_file.close()
	_log_file = null
	
	# Create new log file
	_setup_log_file()
	
	# Log rotation event
	log_event({
		"event": "LOG_ROTATED",
		"previous_entries": _entries_count,
		"rotation_reason": "max_entries_reached"
	})
	
	# Clear in-memory buffer
	_log_entries.clear()
	_entries_count = 0

func get_recent_events(count: int = 50) -> Array[Dictionary]:
	"""Get recent audit events from memory buffer"""
	var recent_count = min(count, _log_entries.size())
	var start_index = max(0, _log_entries.size() - recent_count)
	
	var recent_events: Array[Dictionary] = []
	for i in range(start_index, _log_entries.size()):
		recent_events.append(_log_entries[i])
	
	return recent_events

func get_events_by_type(event_type: String, max_count: int = 100) -> Array[Dictionary]:
	"""Get events filtered by type"""
	var filtered_events: Array[Dictionary] = []
	
	for event in _log_entries:
		if event.get("event", "") == event_type:
			filtered_events.append(event)
			if filtered_events.size() >= max_count:
				break
	
	return filtered_events

func get_security_violations(max_count: int = 100) -> Array[Dictionary]:
	"""Get all security violation events"""
	return get_events_by_type("SECURITY_VIOLATION", max_count)

func verify_log_integrity() -> Dictionary:
	"""Verify integrity of logged events"""
	var verification_result = {
		"valid": true,
		"total_events": _log_entries.size(),
		"corrupted_events": [],
		"verification_time": Time.get_unix_time_from_system()
	}
	
	for i in range(_log_entries.size()):
		var event = _log_entries[i]
		var stored_hash = event.get("integrity_hash", "")
		var calculated_hash = _calculate_event_hash(event)
		
		if stored_hash != calculated_hash:
			verification_result.valid = false
			verification_result.corrupted_events.append({
				"sequence": i,
				"event_type": event.get("event", "UNKNOWN"),
				"stored_hash": stored_hash,
				"calculated_hash": calculated_hash
			})
	
	return verification_result

func export_audit_log(export_path: String = "") -> bool:
	"""Export audit log to specified path"""
	if export_path.is_empty():
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		export_path = "user://audit_export_%s.json" % timestamp
	
	var export_file = FileAccess.open(export_path, FileAccess.WRITE)
	if not export_file:
		push_error("AuditLogger: Failed to create export file: %s" % export_path)
		return false
	
	var export_data = {
		"export_metadata": {
			"session_id": _session_id,
			"export_timestamp": Time.get_unix_time_from_system(),
			"total_events": _log_entries.size(),
			"integrity_verified": verify_log_integrity().valid
		},
		"events": _log_entries
	}
	
	var json_string = JSON.stringify(export_data, "\t")
	export_file.store_string(json_string)
	export_file.close()
	
	# Log the export event
	log_event({
		"event": "AUDIT_LOG_EXPORTED",
		"export_path": export_path,
		"events_exported": _log_entries.size()
	})
	
	return true

func get_audit_statistics() -> Dictionary:
	"""Get audit log statistics"""
	var event_types = {}
	var earliest_event = Time.get_unix_time_from_system()
	var latest_event = 0
	
	for event in _log_entries:
		var event_type = event.get("event", "UNKNOWN")
		event_types[event_type] = event_types.get(event_type, 0) + 1
		
		var event_time = event.get("log_timestamp", 0)
		if event_time > 0:
			earliest_event = min(earliest_event, event_time)
			latest_event = max(latest_event, event_time)
	
	return {
		"total_events": _log_entries.size(),
		"event_types": event_types,
		"time_span": {
			"earliest": earliest_event,
			"latest": latest_event,
			"duration": latest_event - earliest_event
		},
		"session_id": _session_id,
		"log_file": _log_file_path,
		"integrity_status": verify_log_integrity().valid
	}

func search_events(query: Dictionary, max_results: int = 100) -> Array[Dictionary]:
	"""Search events by criteria"""
	var results: Array[Dictionary] = []
	
	for event in _log_entries:
		var matches = true
		
		# Check each query criterion
		for key in query.keys():
			var query_value = query[key]
			var event_value = event.get(key, null)
			
			if event_value == null or event_value != query_value:
				matches = false
				break
		
		if matches:
			results.append(event)
			if results.size() >= max_results:
				break
	
	return results

func cleanup() -> void:
	"""Clean up audit logger resources"""
	if _is_initialized:
		log_event({
			"event": "AUDIT_LOGGER_SHUTDOWN",
			"total_events_logged": _entries_count,
			"session_duration": Time.get_unix_time_from_system() - (_log_entries[0].get("log_timestamp", 0) if _log_entries.size() > 0 else 0)
		})
	
	# Close file handle
	if _log_file:
		_log_file.flush()
		_log_file.close()
		_log_file = null
	
	# Clear sensitive data
	_log_entries.clear()
	_session_id = ""
	_log_file_path = ""
	_is_initialized = false
	_entries_count = 0
	
	print("AuditLogger: Cleanup complete")