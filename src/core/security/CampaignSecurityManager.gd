@tool
class_name CampaignSecurityManager
extends RefCounted

## Campaign Security Manager
## Provides comprehensive security validation and protection for campaign data
## Implements data encryption, audit logging, and secure session management

const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const AuditLoggerClass = preload("res://src/core/security/AuditLogger.gd")

# Security configuration
enum SecurityLevel {
	BASIC, # Basic validation only
	STANDARD, # Standard encryption + validation
	ENHANCED, # Full security with audit logging
	PARANOID # Maximum security with all features
}

enum DataClassification {
	PUBLIC, # No sensitive data
	INTERNAL, # Campaign data, no PII
	SENSITIVE, # User data, preferences
	RESTRICTED # Authentication data, keys
}

enum AuditEvent {
	CAMPAIGN_CREATED,
	CAMPAIGN_LOADED,
	CAMPAIGN_SAVED,
	DATA_EXPORT,
	DATA_IMPORT,
	SECURITY_VIOLATION,
	UNAUTHORIZED_ACCESS,
	DATA_CORRUPTION_DETECTED
}

# Security state
static var _instance: CampaignSecurityManager
static var _security_level: SecurityLevel = SecurityLevel.STANDARD
static var _session_id: String = ""
static var _audit_logger: AuditLoggerClass
static var _encryption_key: PackedByteArray = PackedByteArray()
static var _is_initialized: bool = false

# Security metrics
static var _security_violations: int = 0
static var _last_audit_time: int = 0
static var _session_start_time: int = 0

static func get_instance() -> CampaignSecurityManager:
	"""Get singleton instance with lazy initialization"""
	if not _instance:
		_instance = CampaignSecurityManager.new()
		_initialize_security()
	return _instance

static func _initialize_security() -> void:
	"""Initialize security subsystem"""
	if _is_initialized:
		return
	
	print("CampaignSecurityManager: Initializing security subsystem")
	
	# Generate session ID
	_session_id = _generate_session_id()
	_session_start_time = Time.get_unix_time_from_system()
	
	# Initialize encryption key (in production, this would be more secure)
	_encryption_key = _generate_encryption_key()
	
	# Initialize audit logger
	_audit_logger = AuditLoggerClass.new()
	_audit_logger.initialize(_session_id)
	
	# Set security level from project settings
	var security_setting = ProjectSettings.get_setting("security/campaign_security_level", "STANDARD")
	_security_level = _parse_security_level(security_setting)
	
	# Log initialization
	log_audit_event(AuditEvent.CAMPAIGN_CREATED, {
		"session_id": _session_id,
		"security_level": str(_security_level),
		"timestamp": Time.get_unix_time_from_system()
	})
	
	_is_initialized = true
	print("CampaignSecurityManager: Security initialization complete - Level: %s" % str(_security_level))

static func _parse_security_level(level_string: String) -> SecurityLevel:
	"""Parse security level from string"""
	match level_string.to_upper():
		"BASIC": return SecurityLevel.BASIC
		"STANDARD": return SecurityLevel.STANDARD
		"ENHANCED": return SecurityLevel.ENHANCED
		"PARANOID": return SecurityLevel.PARANOID
		_: return SecurityLevel.STANDARD

static func _generate_session_id() -> String:
	"""Generate secure session ID"""
	var timestamp = str(Time.get_unix_time_from_system())
	var random_bytes = PackedByteArray()
	for i in range(16):
		random_bytes.append(randi() % 256)
	var random_hex = random_bytes.hex_encode()
	return "%s_%s" % [timestamp, random_hex]

static func _generate_encryption_key() -> PackedByteArray:
	"""Generate encryption key (simplified for demo)"""
	var key = PackedByteArray()
	for i in range(32): # 256-bit key
		key.append(randi() % 256)
	return key

## Data Security Operations

static func encrypt_campaign_data(data: Dictionary, classification: DataClassification = DataClassification.INTERNAL) -> Dictionary:
	"""Encrypt campaign data based on classification level"""
	if _security_level == SecurityLevel.BASIC or classification == DataClassification.PUBLIC:
		return data # No encryption for basic level or public data
	
	var encrypted_data = {}
	var serialized = JSON.stringify(data)
	
	# Simple XOR encryption (in production, use proper encryption)
	var encrypted_bytes = _xor_encrypt(serialized.to_utf8_buffer(), _encryption_key)
	
	encrypted_data["encrypted"] = true
	encrypted_data["data"] = encrypted_bytes.hex_encode()
	encrypted_data["classification"] = str(classification)
	encrypted_data["timestamp"] = Time.get_unix_time_from_system()
	encrypted_data["session_id"] = _session_id
	
	log_audit_event(AuditEvent.DATA_EXPORT, {
		"classification": str(classification),
		"data_size": serialized.length(),
		"encrypted": true
	})
	
	return encrypted_data

static func decrypt_campaign_data(encrypted_data: Dictionary) -> Dictionary:
	"""Decrypt campaign data"""
	if not encrypted_data.get("encrypted", false):
		return encrypted_data # Not encrypted
	
	if not encrypted_data.has("data"):
		push_error("CampaignSecurityManager: Missing encrypted data")
		return {}
	
	var hex_data = encrypted_data["data"]
	var encrypted_bytes = hex_data.hex_decode()
	var decrypted_bytes = _xor_encrypt(encrypted_bytes, _encryption_key)
	var decrypted_string = decrypted_bytes.get_string_from_utf8()
	
	var json = JSON.new()
	var parse_result = json.parse(decrypted_string)
	if parse_result != OK:
		push_error("CampaignSecurityManager: Failed to parse decrypted data")
		log_security_violation("DATA_CORRUPTION", "Failed to decrypt campaign data")
		return {}
	
	log_audit_event(AuditEvent.DATA_IMPORT, {
		"classification": encrypted_data.get("classification", "UNKNOWN"),
		"data_size": decrypted_string.length(),
		"decrypted": true
	})
	
	return json.data

static func _xor_encrypt(data: PackedByteArray, key: PackedByteArray) -> PackedByteArray:
	"""Simple XOR encryption (for demo purposes)"""
	var result = PackedByteArray()
	for i in range(data.size()):
		var key_byte = key[i % key.size()]
		result.append(data[i] ^ key_byte)
	return result

## Data Validation

static func validate_campaign_data(data: Dictionary, expected_structure: Dictionary = {}) -> ValidationResult:
	"""Validate campaign data for security and integrity"""
	var validator = SecurityValidator.new()
	var result = validator.validate_data_structure(data, expected_structure)
	
	# Additional security checks
	if result.valid:
		result = _perform_security_checks(data, result)
	
	if not result.valid:
		log_security_violation("DATA_VALIDATION_FAILED", result.error)
	
	return result

static func _perform_security_checks(data: Dictionary, result: ValidationResult) -> ValidationResult:
	"""Perform additional security-specific validation"""
	
	# Check for suspicious data patterns
	var suspicious_patterns = ["<script", "javascript:", "eval(", "exec("]
	var data_string = JSON.stringify(data)
	
	for pattern in suspicious_patterns:
		if pattern in data_string.to_lower():
			result.valid = false
			result.error = "Suspicious data pattern detected: %s" % pattern
			return result
	
	# Check data size limits
	if data_string.length() > 10 * 1024 * 1024: # 10MB limit
		result.valid = false
		result.error = "Data size exceeds security limit"
		return result
	
	# Check for excessive nesting (potential DoS)
	if _get_max_nesting_depth(data) > 50:
		result.valid = false
		result.error = "Data structure too deeply nested"
		return result
	
	return result

static func _get_max_nesting_depth(obj, current_depth: int = 0) -> int:
	"""Calculate maximum nesting depth of data structure"""
	if current_depth > 100: # Prevent stack overflow
		return current_depth
	
	var max_depth = current_depth
	
	if obj is Dictionary:
		for value in obj.values():
			if value is Dictionary or value is Array:
				var child_depth = _get_max_nesting_depth(value, current_depth + 1)
				max_depth = max(max_depth, child_depth)
	elif obj is Array:
		for item in obj:
			if item is Dictionary or item is Array:
				var child_depth = _get_max_nesting_depth(item, current_depth + 1)
				max_depth = max(max_depth, child_depth)
	
	return max_depth

## Audit Logging

static func log_audit_event(event: AuditEvent, details: Dictionary = {}) -> void:
	"""Log security audit event"""
	if _security_level < SecurityLevel.ENHANCED:
		return # Skip audit logging for basic/standard levels
	
	if not _audit_logger:
		return
	
	var audit_data = {
		"event": str(event),
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": _session_id,
		"details": details
	}
	
	_audit_logger.log_event(audit_data)
	_last_audit_time = Time.get_unix_time_from_system()

static func log_security_violation(violation_type: String, details: String) -> void:
	"""Log security violation with escalation"""
	_security_violations += 1
	
	var violation_data = {
		"violation_type": violation_type,
		"details": details,
		"violation_count": _security_violations,
		"severity": _calculate_violation_severity(violation_type)
	}
	
	log_audit_event(AuditEvent.SECURITY_VIOLATION, violation_data)
	
	# Escalate critical violations
	if violation_data.severity == "CRITICAL":
		_handle_critical_violation(violation_data)
	
	push_warning("CampaignSecurityManager: Security violation - %s: %s" % [violation_type, details])

static func _calculate_violation_severity(violation_type: String) -> String:
	"""Calculate severity of security violation"""
	var critical_types = ["DATA_CORRUPTION", "UNAUTHORIZED_ACCESS", "MALICIOUS_DATA"]
	var major_types = ["DATA_VALIDATION_FAILED", "ENCRYPTION_FAILED"]
	
	if violation_type in critical_types:
		return "CRITICAL"
	elif violation_type in major_types:
		return "MAJOR"
	else:
		return "MINOR"

static func _handle_critical_violation(violation_data: Dictionary) -> void:
	"""Handle critical security violations"""
	print("CampaignSecurityManager: CRITICAL SECURITY VIOLATION DETECTED")
	print("Violation: %s" % violation_data)
	
	# In production, this could trigger:
	# - Immediate session termination
	# - Alert to security team
	# - Lockdown of affected systems
	# - Automated incident response

## Session Management

static func get_session_id() -> String:
	"""Get current session ID"""
	return _session_id

static func is_session_valid() -> bool:
	"""Check if current session is valid"""
	if _session_id.is_empty():
		return false
	
	var session_age = Time.get_unix_time_from_system() - _session_start_time
	var max_session_time = ProjectSettings.get_setting("security/max_session_time", 86400) # 24 hours
	
	return session_age < max_session_time

static func refresh_session() -> void:
	"""Refresh current session"""
	var old_session_id = _session_id
	_session_id = _generate_session_id()
	_session_start_time = Time.get_unix_time_from_system()
	
	log_audit_event(AuditEvent.CAMPAIGN_LOADED, {
		"old_session_id": old_session_id,
		"new_session_id": _session_id,
		"refresh_reason": "session_refresh"
	})

## Security Status and Reporting

static func get_security_status() -> Dictionary:
	"""Get comprehensive security status"""
	return {
		"initialized": _is_initialized,
		"security_level": str(_security_level),
		"session_id": _session_id,
		"session_valid": is_session_valid(),
		"session_age": Time.get_unix_time_from_system() - _session_start_time,
		"violations_count": _security_violations,
		"last_audit": _last_audit_time,
		"encryption_enabled": _security_level > SecurityLevel.BASIC,
		"audit_logging_enabled": _security_level >= SecurityLevel.ENHANCED
	}

static func get_security_report() -> Dictionary:
	"""Get detailed security report"""
	var status = get_security_status()
	
	status["recommendations"] = _generate_security_recommendations()
	status["threats_detected"] = _security_violations
	status["compliance_score"] = _calculate_compliance_score()
	
	return status

static func _generate_security_recommendations() -> Array[String]:
	"""Generate security recommendations based on current state"""
	var recommendations: Array[String] = []
	
	if _security_level == SecurityLevel.BASIC:
		recommendations.append("Consider upgrading to STANDARD security level for encryption")
	
	if _security_violations > 10:
		recommendations.append("High number of security violations detected - review system integrity")
	
	if not is_session_valid():
		recommendations.append("Session has expired - refresh recommended")
	
	var session_age = Time.get_unix_time_from_system() - _session_start_time
	if session_age > 43200: # 12 hours
		recommendations.append("Long-running session detected - consider refresh")
	
	return recommendations

static func _calculate_compliance_score() -> int:
	"""Calculate security compliance score (0-100)"""
	var score = 100
	
	# Deduct points for violations
	score -= min(_security_violations * 5, 50)
	
	# Deduct points for low security level
	if _security_level == SecurityLevel.BASIC:
		score -= 30
	elif _security_level == SecurityLevel.STANDARD:
		score -= 10
	
	# Deduct points for expired session
	if not is_session_valid():
		score -= 20
	
	return max(score, 0)

## Cleanup and Shutdown

static func cleanup_security() -> void:
	"""Clean up security resources"""
	log_audit_event(AuditEvent.CAMPAIGN_SAVED, {
		"session_duration": Time.get_unix_time_from_system() - _session_start_time,
		"violations_total": _security_violations,
		"shutdown_reason": "normal_cleanup"
	})
	
	if _audit_logger:
		_audit_logger.cleanup()
		_audit_logger = null
	
	# Clear sensitive data
	_encryption_key.clear()
	_session_id = ""
	_security_violations = 0
	_is_initialized = false
	
	print("CampaignSecurityManager: Security cleanup complete")
