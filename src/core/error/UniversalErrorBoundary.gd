@tool
class_name UniversalErrorBoundary
extends RefCounted

## Universal Error Boundary - Production Error Integration System
##
## Provides seamless integration of ProductionErrorHandler into all
## critical Five Parsecs systems. Acts as a universal wrapper that can
## be injected into any component to provide enterprise-grade error handling.

# Global error handler instance
static var _error_handler: ProductionErrorHandler = null
static var _integration_stats: Dictionary = {}
static var _initialized: bool = false

# Integration configuration
enum IntegrationMode {
	SILENT, # Log errors, continue operation
	GRACEFUL, # Attempt recovery, degrade gracefully
	STRICT, # Halt operation on critical errors
	DEVELOPMENT # Show all errors, detailed logging
}

# Component types for specialized handling
enum ComponentType {
	UI_COMPONENT,
	CORE_SYSTEM,
	DATA_MANAGER,
	DATA_SYSTEM, # Added for Gemini analysis compatibility
	BATTLE_SYSTEM,
	CAMPAIGN_MANAGER
}

## Initialize the universal error boundary system
static func initialize() -> bool:
	if _initialized:
		return true
		
	print("[UniversalErrorBoundary] Initializing production error integration...")
	
	# Create error handler instance
	_error_handler = ProductionErrorHandler.new()
	
	# Initialize integration statistics
	_integration_stats = {
		"total_integrations": 0,
		"active_components": {},
		"error_recovery_rate": 0.0,
		"last_health_check": Time.get_ticks_msec()
	}
	
	# Connect to error handler signals
	if _error_handler:
		_error_handler.error_occurred.connect(_on_global_error_occurred)
		_error_handler.recovery_completed.connect(_on_global_recovery_completed)
		_error_handler.system_health_changed.connect(_on_system_health_changed)
		
		_initialized = true
		print("[UniversalErrorBoundary] ✅ Production error boundary initialized")
		return true
	else:
		push_error("UniversalErrorBoundary: Failed to initialize ProductionErrorHandler")
		return false

## Create error boundary for a specific component
static func wrap_component(component: Object, component_name: String, component_type: ComponentType, mode: IntegrationMode = IntegrationMode.GRACEFUL) -> ErrorBoundaryWrapper:
	if not _initialized:
		if not initialize():
			return null
	
	var wrapper = ErrorBoundaryWrapper.new()
	wrapper.initialize(component, component_name, component_type, mode, _error_handler)
	
	# Register the component
	_integration_stats.total_integrations += 1
	_integration_stats.active_components[component_name] = {
		"type": ComponentType.keys()[component_type],
		"mode": IntegrationMode.keys()[mode],
		"integration_time": Time.get_ticks_msec(),
		"error_count": 0,
		"recovery_count": 0
	}
	
	print("[UniversalErrorBoundary] Component '%s' integrated with %s mode" % [component_name, IntegrationMode.keys()[mode]])
	return wrapper

## Inject error boundary into existing systems (for legacy integration)
static func inject_into_system(system: Object, system_name: String) -> bool:
	if not _initialized and not initialize():
		return false
	
	# Add error boundary methods to existing system
	if system.has_method("_handle_error"):
		print("[UniversalErrorBoundary] Warning: System '%s' already has error handling" % system_name)
	
	# Create injection wrapper  
	var injection = SystemErrorInjection.new()
	injection.inject_error_handling(system, system_name, _error_handler)
	
	_integration_stats.active_components[system_name] = {
		"type": "INJECTED_SYSTEM",
		"mode": "GRACEFUL",
		"integration_time": Time.get_ticks_msec(),
		"error_count": 0,
		"recovery_count": 0
	}
	
	print("[UniversalErrorBoundary] Error handling injected into system '%s'" % system_name)
	return true

## Get system-wide error statistics
static func get_error_statistics() -> Dictionary:
	if not _error_handler:
		return {}
	
	var stats = _error_handler.get_error_report()
	stats["integration_stats"] = _integration_stats.duplicate()
	stats["active_components_count"] = _integration_stats.active_components.size()
	
	return stats

## Validate system integrity across all integrated components
static func validate_system_integrity() -> Dictionary:
	if not _error_handler:
		return {"error": "Error handler not initialized"}
	
	var validation = _error_handler.validate_system_integrity()
	
	# Add component-specific validation
	var component_issues = []
	for component_name in _integration_stats.active_components.keys():
		var component_stats = _integration_stats.active_components[component_name]
		var error_rate = float(component_stats.error_count) / max(float(Time.get_ticks_msec() - component_stats.integration_time) / 60000.0, 1.0)
		
		if error_rate > 5.0: # More than 5 errors per minute
			component_issues.append({
				"component": component_name,
				"issue": "High error rate: %.1f errors/minute" % error_rate,
				"recommendation": "Investigate component stability"
			})
	
	if not component_issues.is_empty():
		validation.issues_found.append_array(component_issues)
		validation.integrity_check_passed = false
	
	return validation

## Emergency shutdown with comprehensive error reporting
static func emergency_shutdown(reason: String) -> void:
	print("[UniversalErrorBoundary] 🚨 EMERGENCY SHUTDOWN INITIATED: %s" % reason)
	
	if _error_handler:
		var critical_error = {
			"type": "emergency_shutdown",
			"message": reason,
			"component": "UniversalErrorBoundary",
			"severity": ProductionErrorHandler.ErrorSeverity.CRITICAL,
			"system_state": _capture_emergency_state()
		}
		
		_error_handler.handle_critical_failure(critical_error)

## Signal handlers for global error management
static func _on_global_error_occurred(error_data: Dictionary) -> void:
	var component_name = error_data.get("component", "unknown")
	if component_name in _integration_stats.active_components:
		_integration_stats.active_components[component_name].error_count += 1

static func _on_global_recovery_completed(recovery_data: Dictionary) -> void:
	var component_name = recovery_data.get("component", "unknown")
	if component_name in _integration_stats.active_components:
		_integration_stats.active_components[component_name].recovery_count += 1

static func _on_system_health_changed(health_score: float) -> void:
	if health_score < 50.0:
		print("[UniversalErrorBoundary] ⚠️ SYSTEM HEALTH CRITICAL: %.1f%%" % health_score)
	elif health_score < 70.0:
		print("[UniversalErrorBoundary] ⚠️ System health degraded: %.1f%%" % health_score)

static func _capture_emergency_state() -> Dictionary:
	return {
		"integration_stats": _integration_stats.duplicate(),
		"active_components": _integration_stats.active_components.keys(),
		"timestamp": Time.get_ticks_msec(),
		"memory_usage": OS.get_memory_info()
	}

## Cleanup function for system shutdown
static func cleanup() -> void:
	if _error_handler:
		_error_handler.shutdown()
		_error_handler = null
	
	_integration_stats.clear()
	_initialized = false
	
	print("[UniversalErrorBoundary] System cleanup completed")

# =====================================================================
# COMPONENT WRAPPER CLASS
# =====================================================================

class ErrorBoundaryWrapper extends RefCounted:
	var _component: Object = null
	var _component_name: String = ""
	var _component_type: ComponentType
	var _integration_mode: IntegrationMode
	var _error_handler: ProductionErrorHandler = null
	var _method_cache: Dictionary = {}
	var _recovery_strategy: ErrorRecoveryStrategy = ErrorRecoveryStrategy.GRACEFUL_DEGRADE
	
	func initialize(component: Object, name: String, type: ComponentType, mode: IntegrationMode, handler: ProductionErrorHandler) -> void:
		_component = component
		_component_name = name
		_component_type = type
		_integration_mode = mode
		_error_handler = handler
		
		# Cache important methods for performance
		_cache_component_methods()
	
	func _cache_component_methods() -> void:
		if not _component:
			return
			
		var important_methods = ["_ready", "_process", "_physics_process", "_input", "_unhandled_input"]
		for method_name in important_methods:
			if _component.has_method(method_name):
				_method_cache[method_name] = true
	
	## Wrap method calls with error boundaries
	func safe_call(method_name: String, args: Array = []) -> Variant:
		if not _component or not _component.has_method(method_name):
			return _handle_missing_method(method_name)
		
		# Safe method call with error handling
		var result = null
		match args.size():
			0:
				if _component.has_method(method_name):
					result = _component.call(method_name)
				else:
					return _handle_method_error(method_name, args, [])
			1:
				if _component.has_method(method_name):
					result = _component.call(method_name, args[0])
				else:
					return _handle_method_error(method_name, args, [])
			2:
				if _component.has_method(method_name):
					result = _component.call(method_name, args[0], args[1])
				else:
					return _handle_method_error(method_name, args, [])
			3:
				if _component.has_method(method_name):
					result = _component.call(method_name, args[0], args[1], args[2])
				else:
					return _handle_method_error(method_name, args, [])
			_:
				if _component.has_method(method_name):
					result = _component.callv(method_name, args)
				else:
					return _handle_method_error(method_name, args, [])
		
		return result
	
	## Handle property access with error boundaries
	func safe_get(property_name: String) -> Variant:
		if not _component:
			return _handle_component_unavailable()
		
		# Safe property access with error handling
		if _component.has_method("get"):
			return _component.get(property_name)
		else:
			return _handle_property_error(property_name, "get", [])
	
	func safe_set(property_name: String, value: Variant) -> bool:
		if not _component:
			_handle_component_unavailable()
			return false
		
		# Safe property setting with error handling
		if _component.has_method("set"):
			_component.set(property_name, value)
			return true
		else:
			_handle_property_error(property_name, "set", [])
			return false
	
	## Signal connection with error boundaries
	func safe_connect_signal(signal_name: String, callable: Callable, flags: int = 0) -> bool:
		if not _component or not _component.has_signal(signal_name):
			return _handle_signal_error(signal_name, "connect")
		
		# Safe signal connection with error handling
		if _component.has_signal(signal_name):
			_component.connect(signal_name, callable, flags)
			return true
		else:
			_handle_signal_error(signal_name, "connect", [])
			return false
	
	func safe_disconnect_signal(signal_name: String, callable: Callable) -> bool:
		if not _component or not _component.has_signal(signal_name):
			return _handle_signal_error(signal_name, "disconnect")
		
		# Safe signal disconnection with error handling
		if _component.has_signal(signal_name):
			_component.disconnect(signal_name, callable)
			return true
		else:
			_handle_signal_error(signal_name, "disconnect", [])
			return false
	
	# Error handling methods
	func _handle_missing_method(method_name: String) -> Variant:
		var error_data = {
			"type": "missing_method",
			"message": "Method '%s' not found on component '%s'" % [method_name, _component_name],
			"component": _component_name,
			"method": method_name,
			"severity": ProductionErrorHandler.ErrorSeverity.MEDIUM
		}
		
		if _error_handler:
			var result = _error_handler.handle_error(error_data)
			if result.recommended_action == "continue":
				return null
		
		return null
	
	func _handle_method_error(method_name: String, args: Array, stack_trace: Array) -> Variant:
		var error_data = {
			"type": "method_execution_error",
			"message": "Error executing method '%s' on component '%s'" % [method_name, _component_name],
			"component": _component_name,
			"method": method_name,
			"arguments": args,
			"stack_trace": stack_trace,
			"severity": ProductionErrorHandler.ErrorSeverity.HIGH
		}
		
		if _error_handler:
			var result = _error_handler.handle_error(error_data)
			
			# Apply recovery strategy based on integration mode
			match _integration_mode:
				IntegrationMode.SILENT:
					return null
				IntegrationMode.GRACEFUL:
					return _attempt_method_recovery(method_name, args)
				IntegrationMode.STRICT:
					push_error("STRICT MODE: Method execution failed for %s.%s" % [_component_name, method_name])
					return null
				IntegrationMode.DEVELOPMENT:
					assert(false, "Method execution failed in development mode")
					return null
		
		return null
	
	func _handle_property_error(property_name: String, operation: String, stack_trace: Array = []) -> Variant:
		var error_data = {
			"type": "property_access_error",
			"message": "Error %s property '%s' on component '%s'" % [operation, property_name, _component_name],
			"component": _component_name,
			"property": property_name,
			"operation": operation,
			"stack_trace": stack_trace,
			"severity": ProductionErrorHandler.ErrorSeverity.MEDIUM
		}
		
		if _error_handler:
			_error_handler.handle_error(error_data)
		
		return null if operation == "get" else false
	
	func _handle_signal_error(signal_name: String, operation: String, stack_trace: Array = []) -> bool:
		var error_data = {
			"type": "signal_connection_error",
			"message": "Error %s signal '%s' on component '%s'" % [operation, signal_name, _component_name],
			"component": _component_name,
			"signal": signal_name,
			"operation": operation,
			"stack_trace": stack_trace,
			"severity": ProductionErrorHandler.ErrorSeverity.MEDIUM
		}
		
		if _error_handler:
			_error_handler.handle_error(error_data)
		
		return false
	
	func _handle_component_unavailable() -> Variant:
		var error_data = {
			"type": "component_unavailable",
			"message": "Component '%s' is no longer available" % _component_name,
			"component": _component_name,
			"severity": ProductionErrorHandler.ErrorSeverity.HIGH
		}
		
		if _error_handler:
			_error_handler.handle_error(error_data)
		
		return null
	
	func _attempt_method_recovery(method_name: String, args: Array) -> Variant:
		# Try to provide safe fallback behavior based on method type
		match method_name:
			"_ready":
				print("[ErrorBoundary] Component '%s' _ready() failed, using minimal initialization" % _component_name)
				return null
			"_process", "_physics_process":
				# Skip this frame
				return null
			"save", "save_data":
				print("[ErrorBoundary] Save operation failed for '%s', data may be lost" % _component_name)
				return false
			"load", "load_data":
				print("[ErrorBoundary] Load operation failed for '%s', using default data" % _component_name)
				return null
			_:
				return null
	
	# Methods required by SystemErrorIntegrator
	func _configure_recovery_strategy(strategy: ErrorRecoveryStrategy, config: Dictionary) -> void:
		"""Configure the recovery strategy for this error boundary wrapper"""
		_recovery_strategy = strategy
		
		# Store configuration for validation
		if not has_meta("_recovery_config"):
			set_meta("_recovery_config", {})
		
		var recovery_config = get_meta("_recovery_config")
		recovery_config.merge(config)
		set_meta("_recovery_config", recovery_config)
		
		print("[ErrorBoundaryWrapper] Configured recovery strategy %s for %s" % [ErrorRecoveryStrategy.keys()[strategy], _component_name])
	
	func _get_recovery_configuration() -> Dictionary:
		"""Get the current recovery configuration"""
		return get_meta("_recovery_config", {})
	
	func _get_protection_configuration() -> Dictionary:
		"""Get the protection configuration"""
		return get_meta("_protection_config", {})

# Error Recovery Strategies enum (required by SystemErrorIntegrator)
enum ErrorRecoveryStrategy {
	RETRY,
	FALLBACK,
	GRACEFUL_DEGRADE,
	COMPONENT_RESTART,
	EMERGENCY_SAVE,
	IMMEDIATE_SHUTDOWN
}

# =====================================================================
# SYSTEM INJECTION CLASS (for legacy systems)
# =====================================================================

class SystemErrorInjection extends RefCounted:
	func inject_error_handling(system: Object, system_name: String, error_handler: ProductionErrorHandler) -> void:
		if not system:
			return
		
		# Add error handling methods to the system
		system.set_meta("_error_handler", error_handler)
		system.set_meta("_system_name", system_name)
		
		# If the system doesn't have error handling, add it via meta
		if not system.has_method("handle_system_error"):
			system.set_meta("handle_system_error", _create_error_handler_callable(system, error_handler, system_name))
	
	func _create_error_handler_callable(system: Object, error_handler: ProductionErrorHandler, system_name: String) -> Callable:
		return func(error_data: Dictionary) -> Dictionary:
			error_data["component"] = system_name
			return error_handler.handle_error(error_data)

## Static methods required by SystemErrorIntegrator

static func _register_integrated_component(system_name: String, integration_data: Dictionary) -> void:
	"""Register an integrated component with the global error boundary system"""
	if not _initialized:
		return
		
	_integration_stats.active_components[system_name] = integration_data
	_integration_stats.total_integrations += 1
	
	print("[UniversalErrorBoundary] Registered integrated component: %s" % system_name)
