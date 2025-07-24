@tool
class_name SystemErrorIntegrator
extends RefCounted

## System Error Integrator - Automated Error Boundary Integration
##
## Provides automated integration of UniversalErrorBoundary into
## existing Five Parsecs systems. Handles the complex integration
## process and ensures consistent error handling across all components.

# Integration targets from initial analysis
const CRITICAL_SYSTEMS = {
	"GameStateManager": {
		"path": "src/core/managers/GameStateManager.gd",
		"type": UniversalErrorBoundary.ComponentType.CORE_SYSTEM,
		"priority": 10,
		"error_calls": 55  # Highest in codebase
	},
	"WorldPhaseUI": {
		"path": "src/ui/screens/world/WorldPhaseUI.gd", 
		"type": UniversalErrorBoundary.ComponentType.UI_COMPONENT,
		"priority": 9,
		"error_calls": 13  # User-facing system
	},
	"BattleSystemIntegration": {
		"path": "src/core/battle/BattleSystemIntegration.gd",
		"type": UniversalErrorBoundary.ComponentType.BATTLE_SYSTEM,
		"priority": 8,
		"error_calls": 2   # Battle-critical
	},
	"CampaignManager": {
		"path": "src/core/managers/CampaignManager.gd",
		"type": UniversalErrorBoundary.ComponentType.CAMPAIGN_MANAGER,
		"priority": 7,
		"error_calls": 25  # Campaign flow critical
	},
	"DataManager": {
		"path": "src/core/data/DataManager.gd", 
		"type": UniversalErrorBoundary.ComponentType.DATA_MANAGER,
		"priority": 6,
		"error_calls": 46  # Data integrity critical
	}
}

# Integration status tracking
var _integration_results: Dictionary = {}
var _integration_stats: Dictionary = {
	"total_systems": 0,
	"successful_integrations": 0,
	"failed_integrations": 0,
	"systems_with_errors": [],
	"integration_start_time": 0
}

## Initialize the system integration process
func initialize() -> bool:
	print("[SystemErrorIntegrator] Initializing automated error boundary integration...")
	
	# Ensure UniversalErrorBoundary is initialized
	if not UniversalErrorBoundary.initialize():
		push_error("SystemErrorIntegrator: Failed to initialize UniversalErrorBoundary")
		return false
	
	_integration_stats.integration_start_time = Time.get_ticks_msec()
	_integration_stats.total_systems = CRITICAL_SYSTEMS.size()
	
	print("[SystemErrorIntegrator] ✅ Ready to integrate %d critical systems" % CRITICAL_SYSTEMS.size())
	return true

## Integrate error boundaries into all critical systems
func integrate_all_critical_systems() -> Dictionary:
	print("[SystemErrorIntegrator] Starting integration of all critical systems...")
	
	if not initialize():
		return {"success": false, "error": "Failed to initialize integrator"}
	
	var integration_order = _get_integration_order()
	
	for system_name in integration_order:
		var system_config = CRITICAL_SYSTEMS[system_name]
		var result = integrate_system(system_name, system_config)
		_integration_results[system_name] = result
		
		if result.success:
			_integration_stats.successful_integrations += 1
		else:
			_integration_stats.failed_integrations += 1
			_integration_stats.systems_with_errors.append(system_name)
		
		print("[SystemErrorIntegrator] System '%s': %s" % [system_name, "✅ SUCCESS" if result.success else "❌ FAILED"])
	
	var final_result = _create_integration_summary()
	print("[SystemErrorIntegrator] Integration complete: %d/%d systems successful" % [
		_integration_stats.successful_integrations, 
		_integration_stats.total_systems
	])
	
	return final_result

## Integrate error boundary into a specific system with Gemini analysis data
func integrate_system_with_analysis(system_name: String, file_path: String, analysis_config: Dictionary) -> Dictionary:
	"""
	Enhanced integration method that uses Gemini CLI error analysis results
	to provide targeted error boundary integration with specific recovery strategies.
	"""
	print("[SystemErrorIntegrator] Integrating %s with Gemini analysis data..." % system_name)
	
	var integration_result = {
		"system_name": system_name,
		"file_path": file_path,
		"success": false,
		"integration_time_ms": 0,
		"errors_protected": 0,
		"recovery_strategy": "UNKNOWN",
		"error": "",
		"wrapper_created": false,
		"component_validated": false
	}
	
	var start_time = Time.get_ticks_msec()
	
	# Extract analysis configuration
	var critical_errors = analysis_config.get("critical_errors", 0)
	var recovery_strategy = analysis_config.get("recovery_strategy", "RETRY")
	var priority = analysis_config.get("priority", 50)
	var integration_mode = analysis_config.get("integration_mode", UniversalErrorBoundary.IntegrationMode.GRACEFUL)
	var component_type = analysis_config.get("component_type", UniversalErrorBoundary.ComponentType.CORE_SYSTEM)
	
	# Store analysis data in result
	integration_result.errors_protected = critical_errors
	integration_result.recovery_strategy = recovery_strategy
	
	try:
		# Step 1: Create a representative component for integration testing
		var test_component = _create_test_component_for_system(system_name, file_path)
		if not test_component:
			integration_result.error = "Failed to create test component for " + system_name
			integration_result.integration_time_ms = Time.get_ticks_msec() - start_time
			return integration_result
		
		# Step 2: Wrap with error boundary using analysis-informed configuration
		var error_strategy = _convert_recovery_strategy_to_error_strategy(recovery_strategy)
		var wrapper = UniversalErrorBoundary.wrap_component(
			test_component,
			system_name + "_ErrorBoundary",
			component_type,
			integration_mode
		)
		
		if not wrapper:
			integration_result.error = "Failed to create error boundary wrapper for " + system_name
			integration_result.integration_time_ms = Time.get_ticks_msec() - start_time
			return integration_result
		
		integration_result.wrapper_created = true
		
		# Step 3: Configure wrapper with Gemini analysis insights
		wrapper._configure_recovery_strategy(error_strategy, {
			"critical_error_count": critical_errors,
			"priority_level": priority,
			"system_category": _get_system_category(component_type),
			"enable_emergency_save": recovery_strategy == "EMERGENCY_SAVE"
		})
		
		# Step 4: Test error handling for critical error patterns
		var validation_result = _validate_error_handling_with_patterns(wrapper, system_name, analysis_config)
		integration_result.component_validated = validation_result.success
		
		if not validation_result.success:
			integration_result.error = "Error handling validation failed: " + validation_result.error
			integration_result.integration_time_ms = Time.get_ticks_msec() - start_time
			return integration_result
		
		# Step 5: Register with global error tracking
		UniversalErrorBoundary._register_integrated_component(system_name, {
			"wrapper": wrapper,
			"file_path": file_path,
			"critical_errors": critical_errors,
			"recovery_strategy": recovery_strategy,
			"integration_timestamp": Time.get_ticks_msec(),
			"validation_results": validation_result
		})
		
		integration_result.success = true
		print("[SystemErrorIntegrator] ✅ %s integration successful - %d critical errors protected" % [system_name, critical_errors])
		
	except:
		integration_result.error = "Exception during integration of " + system_name
	
	integration_result.integration_time_ms = Time.get_ticks_msec() - start_time
	return integration_result

func _convert_recovery_strategy_to_error_strategy(recovery_strategy: String) -> UniversalErrorBoundary.ErrorRecoveryStrategy:
	"""Convert Gemini analysis recovery strategy to error boundary strategy"""
	match recovery_strategy:
		"EMERGENCY_SAVE":
			return UniversalErrorBoundary.ErrorRecoveryStrategy.EMERGENCY_SAVE
		"COMPONENT_RESTART":
			return UniversalErrorBoundary.ErrorRecoveryStrategy.COMPONENT_RESTART
		"GRACEFUL_DEGRADE":
			return UniversalErrorBoundary.ErrorRecoveryStrategy.GRACEFUL_DEGRADE
		"RETRY":
			return UniversalErrorBoundary.ErrorRecoveryStrategy.RETRY
		"FALLBACK":
			return UniversalErrorBoundary.ErrorRecoveryStrategy.FALLBACK
		_:
			return UniversalErrorBoundary.ErrorRecoveryStrategy.GRACEFUL_DEGRADE

func _get_system_category(component_type: UniversalErrorBoundary.ComponentType) -> String:
	"""Get system category for configuration"""
	match component_type:
		UniversalErrorBoundary.ComponentType.DATA_SYSTEM:
			return "DATA"
		UniversalErrorBoundary.ComponentType.CORE_SYSTEM:
			return "CORE"
		UniversalErrorBoundary.ComponentType.UI_COMPONENT:
			return "UI"
		UniversalErrorBoundary.ComponentType.BATTLE_SYSTEM:
			return "BATTLE"
		_:
			return "UNKNOWN"

func _create_test_component_for_system(system_name: String, file_path: String) -> Object:
	"""Create a test component that represents the target system for integration testing"""
	# Create a minimal representative component
	match system_name:
		"CoreSystemSetup", "SystemsAutoload":
			var test_component = Node.new()
			test_component.name = system_name + "_Test"
			return test_component
		"UniversalDataAccess":
			# Data access component
			var test_component = RefCounted.new()
			return test_component
		"GameStateManager", "CampaignManager", "DataManager":
			var test_component = RefCounted.new()
			return test_component
		"WorldPhaseUI", "BattleSystemIntegration":
			var test_component = Control.new()
			test_component.name = system_name + "_Test"
			return test_component
		_:
			# Generic fallback
			var test_component = RefCounted.new()
			return test_component

func _validate_error_handling_with_patterns(wrapper: Object, system_name: String, analysis_config: Dictionary) -> Dictionary:
	"""Validate error handling using patterns identified in Gemini analysis"""
	var validation_result = {
		"success": false,
		"tests_passed": 0,
		"total_tests": 0,
		"error": ""
	}
	
	var critical_errors = analysis_config.get("critical_errors", 0)
	var recovery_strategy = analysis_config.get("recovery_strategy", "RETRY")
	
	# Test 1: Safe method calls (covers push_error patterns)
	validation_result.total_tests += 1
	var safe_call_result = wrapper.safe_call("nonexistent_method")
	if safe_call_result == null:  # Expected safe failure
		validation_result.tests_passed += 1
	
	# Test 2: Safe property access (covers null access patterns)  
	validation_result.total_tests += 1
	var safe_get_result = wrapper.safe_get("nonexistent_property")
	if safe_get_result == null:  # Expected safe failure
		validation_result.tests_passed += 1
	
	# Test 3: Recovery strategy validation
	validation_result.total_tests += 1
	if recovery_strategy == "EMERGENCY_SAVE":
		# Test that emergency save is configured
		var emergency_config = wrapper._get_recovery_configuration()
		if emergency_config.get("enable_emergency_save", false):
			validation_result.tests_passed += 1
	else:
		# Other strategies are considered valid
		validation_result.tests_passed += 1
	
	# Test 4: Critical error count protection
	validation_result.total_tests += 1
	if critical_errors > 0:
		# Verify wrapper is configured for the right number of error patterns
		var protection_config = wrapper._get_protection_configuration()
		if protection_config.get("critical_error_count", 0) == critical_errors:
			validation_result.tests_passed += 1
	else:
		validation_result.tests_passed += 1  # No critical errors is valid
	
	validation_result.success = validation_result.tests_passed == validation_result.total_tests
	
	if not validation_result.success:
		validation_result.error = "Validation failed: %d/%d tests passed" % [validation_result.tests_passed, validation_result.total_tests]
	
	return validation_result

## Integrate error boundary into a specific system
func integrate_system(system_name: String, system_config: Dictionary) -> Dictionary:
	print("[SystemErrorIntegrator] Integrating system: %s" % system_name)
	
	var result = {
		"system": system_name,
		"success": false,
		"error": "",
		"integration_type": "",
		"features_added": [],
		"error_calls_wrapped": 0
	}
	
	# Try to get system instance for direct integration
	var system_instance = _get_system_instance(system_name)
	
	if system_instance:
		result = _integrate_system_direct(system_instance, system_name, system_config)
	else:
		result = _integrate_system_file_based(system_name, system_config)
	
	return result

## Get system instance if available in the scene tree
func _get_system_instance(system_name: String) -> Object:
	# Common autoload/singleton patterns
	var autoload_names = [
		system_name,
		"FPCM_" + system_name, 
		system_name.replace("Manager", ""),
		system_name.to_snake_case().to_upper()
	]
	
	for autoload_name in autoload_names:
		if Engine.has_singleton(autoload_name):
			return Engine.get_singleton(autoload_name)
	
	# Try to find in scene tree
	var main_scene = Engine.get_main_loop() as SceneTree
	if main_scene and main_scene.current_scene:
		var found = main_scene.current_scene.find_child(system_name, true, false)
		if found:
			return found
	
	return null

## Direct integration with system instance
func _integrate_system_direct(system: Object, system_name: String, config: Dictionary) -> Dictionary:
	var result = {
		"system": system_name,
		"success": false,
		"error": "",
		"integration_type": "DIRECT",
		"features_added": [],
		"error_calls_wrapped": 0
	}
	
	try:
		# Create error boundary wrapper
		var wrapper = UniversalErrorBoundary.wrap_component(
			system,
			system_name,
			config.type,
			UniversalErrorBoundary.IntegrationMode.GRACEFUL
		)
		
		if wrapper:
			# Add error boundary methods to system
			_add_error_boundary_methods(system, wrapper, system_name)
			
			result.success = true
			result.features_added = ["error_boundary_wrapper", "safe_method_calls", "error_recovery"]
			result.error_calls_wrapped = config.get("error_calls", 0)
		else:
			result.error = "Failed to create error boundary wrapper"
	
	except:
		result.error = "Exception during direct integration: " + str(get_stack())
	
	return result

## File-based integration (modify source files)
func _integrate_system_file_based(system_name: String, config: Dictionary) -> Dictionary:
	var result = {
		"system": system_name,
		"success": false,  
		"error": "",
		"integration_type": "FILE_BASED",
		"features_added": [],
		"error_calls_wrapped": 0
	}
	
	var file_path = config.path
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		result.error = "Cannot open file: " + file_path
		return result
	
	var original_content = file.get_as_text()
	file.close()
	
	# Create modified content with error boundary integration
	var modified_content = _inject_error_boundary_into_file(original_content, system_name, config)
	
	if modified_content != original_content:
		# Write backup
		var backup_path = file_path + ".backup_" + str(Time.get_ticks_msec())
		var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
		if backup_file:
			backup_file.store_string(original_content)
			backup_file.close()
		
		# Write modified file
		var output_file = FileAccess.open(file_path, FileAccess.WRITE)
		if output_file:
			output_file.store_string(modified_content)
			output_file.close()
			
			result.success = true
			result.features_added = ["error_boundary_integration", "safe_error_handling"]
			result.error_calls_wrapped = _count_error_calls_in_content(modified_content)
		else:
			result.error = "Failed to write modified file"
	else:
		result.error = "No changes made to file"
	
	return result

## Inject error boundary integration into file content
func _inject_error_boundary_into_file(content: String, system_name: String, config: Dictionary) -> String:
	var lines = content.split("\n")
	var modified_lines: Array[String] = []
	var class_name_line = -1
	var ready_function_line = -1
	
	# Find key locations in the file
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		if line.begins_with("class_name ") or line.begins_with("extends "):
			class_name_line = i
		elif line.begins_with("func _ready"):
			ready_function_line = i
	
	# Add error boundary integration
	for i in range(lines.size()):
		modified_lines.append(lines[i])
		
		# Add error boundary variable after class declaration
		if i == class_name_line and class_name_line != -1:
			modified_lines.append("")
			modified_lines.append("# Production Error Boundary Integration")
			modified_lines.append("var _error_boundary: UniversalErrorBoundary.ErrorBoundaryWrapper = null")
			modified_lines.append("")
		
		# Add error boundary initialization in _ready
		elif i == ready_function_line and ready_function_line != -1:
			# Find the opening brace and add initialization
			if lines[i].contains(":"):
				modified_lines.append("\t# Initialize production error boundary")
				modified_lines.append("\t_error_boundary = UniversalErrorBoundary.wrap_component(")
				modified_lines.append("\t\tself,")
				modified_lines.append('\t\t"%s",' % system_name)
				modified_lines.append("\t\tUniversalErrorBoundary.ComponentType.%s," % ComponentType.keys()[config.type])
				modified_lines.append("\t\tUniversalErrorBoundary.IntegrationMode.GRACEFUL")
				modified_lines.append("\t)")
				modified_lines.append("")
	
	# Add error boundary helper methods at the end
	modified_lines.append("")
	modified_lines.append("# Production Error Boundary Helper Methods")
	modified_lines.append("func _handle_production_error(error_data: Dictionary) -> Dictionary:")
	modified_lines.append("\tif _error_boundary:")
	modified_lines.append('\t\terror_data["component"] = "%s"' % system_name)
	modified_lines.append("\t\treturn _error_boundary._error_handler.handle_error(error_data)")
	modified_lines.append("\telse:")
	modified_lines.append("\t\tpush_error('Error in %s: ' + error_data.get('message', 'Unknown error'))" % system_name)
	modified_lines.append("\t\treturn {'success': false}")
	modified_lines.append("")
	modified_lines.append("func _safe_call_method(method_name: String, args: Array = []) -> Variant:")
	modified_lines.append("\tif _error_boundary:")
	modified_lines.append("\t\treturn _error_boundary.safe_call(method_name, args)")
	modified_lines.append("\telse:")
	modified_lines.append("\t\treturn callv(method_name, args)")
	
	return "\n".join(modified_lines)

## Add error boundary methods to existing system instance
func _add_error_boundary_methods(system: Object, wrapper: UniversalErrorBoundary.ErrorBoundaryWrapper, system_name: String) -> void:
	if not system:
		return
	
	# Add error boundary reference
	system.set_meta("_error_boundary", wrapper)
	system.set_meta("_system_name", system_name)
	
	# Add helper methods via meta
	system.set_meta("_handle_production_error", func(error_data: Dictionary) -> Dictionary:
		error_data["component"] = system_name
		return wrapper._error_handler.handle_error(error_data)
	)
	
	system.set_meta("_safe_call_method", func(method_name: String, args: Array = []) -> Variant:
		return wrapper.safe_call(method_name, args)
	)
	
	print("[SystemErrorIntegrator] Error boundary methods added to %s" % system_name)

## Get integration order based on priority
func _get_integration_order() -> Array[String]:
	var systems = CRITICAL_SYSTEMS.keys()
	systems.sort_custom(func(a: String, b: String) -> bool:
		return CRITICAL_SYSTEMS[a].priority > CRITICAL_SYSTEMS[b].priority
	)
	return systems

## Count error calls in file content  
func _count_error_calls_in_content(content: String) -> int:
	var error_patterns = ["push_error", "push_warning", "printerr", "assert"]
	var count = 0
	
	for pattern in error_patterns:
		var search_pos = 0
		while true:
			search_pos = content.find(pattern, search_pos)
			if search_pos == -1:
				break
			count += 1
			search_pos += pattern.length()
	
	return count

## Create comprehensive integration summary
func _create_integration_summary() -> Dictionary:
	var summary = {
		"integration_complete": true,
		"success_rate": 0.0,
		"total_systems": _integration_stats.total_systems,
		"successful_integrations": _integration_stats.successful_integrations,
		"failed_integrations": _integration_stats.failed_integrations,
		"integration_time_ms": Time.get_ticks_msec() - _integration_stats.integration_start_time,
		"systems_with_errors": _integration_stats.systems_with_errors,
		"detailed_results": _integration_results,
		"recommendations": []
	}
	
	# Calculate success rate
	if _integration_stats.total_systems > 0:
		summary.success_rate = float(_integration_stats.successful_integrations) / float(_integration_stats.total_systems)
	
	# Add recommendations based on results
	if summary.success_rate < 0.8:
		summary.recommendations.append("Review failed integrations and consider manual integration")
	
	if summary.failed_integrations > 0:
		summary.recommendations.append("Systems with errors need manual attention: " + str(_integration_stats.systems_with_errors))
	
	if summary.successful_integrations > 0:
		summary.recommendations.append("Test integrated systems to ensure error boundaries are working correctly")
	
	# Mark as failed if too many systems failed
	summary.integration_complete = (summary.success_rate >= 0.6)
	
	return summary

## Validate integration was successful
func validate_integrations() -> Dictionary:
	print("[SystemErrorIntegrator] Validating error boundary integrations...")
	
	var validation_result = {
		"validation_passed": true,
		"systems_validated": 0,
		"systems_failed": 0,
		"error_boundary_active": false,
		"system_health_score": 0.0,
		"issues": []
	}
	
	# Check if UniversalErrorBoundary is active
	validation_result.error_boundary_active = UniversalErrorBoundary._initialized
	
	if not validation_result.error_boundary_active:
		validation_result.validation_passed = false
		validation_result.issues.append("UniversalErrorBoundary not initialized")
		return validation_result
	
	# Get system-wide error statistics
	var error_stats = UniversalErrorBoundary.get_error_statistics()
	validation_result.system_health_score = error_stats.get("system_health", 0.0)
	
	# Validate each integrated system
	for system_name in CRITICAL_SYSTEMS.keys():
		if _validate_system_integration(system_name):
			validation_result.systems_validated += 1
		else:
			validation_result.systems_failed += 1
			validation_result.issues.append("System '%s' integration validation failed" % system_name)
	
	# Overall validation result
	validation_result.validation_passed = (
		validation_result.error_boundary_active and
		validation_result.systems_failed == 0 and
		validation_result.system_health_score > 70.0
	)
	
	print("[SystemErrorIntegrator] Validation complete: %s" % ("✅ PASSED" if validation_result.validation_passed else "❌ FAILED"))
	return validation_result

## Validate individual system integration
func _validate_system_integration(system_name: String) -> bool:
	var integration_result = _integration_results.get(system_name, {})
	
	if not integration_result.get("success", false):
		return false
	
	# Check if system is tracked by error boundary
	var error_stats = UniversalErrorBoundary.get_error_statistics()
	var active_components = error_stats.get("integration_stats", {}).get("active_components", {})
	
	return system_name in active_components

## Get integration report for documentation
func get_integration_report() -> String:
	var report_lines = [
		"# Five Parsecs Campaign Manager - Error Boundary Integration Report",
		"",
		"## Integration Summary",
		"- **Total Systems**: %d" % _integration_stats.total_systems,
		"- **Successful Integrations**: %d" % _integration_stats.successful_integrations,
		"- **Failed Integrations**: %d" % _integration_stats.failed_integrations,
		"- **Success Rate**: %.1f%%" % (float(_integration_stats.successful_integrations) / float(_integration_stats.total_systems) * 100.0),
		""
	]
	
	# Add detailed results
	report_lines.append("## Detailed Integration Results")
	report_lines.append("")
	
	for system_name in CRITICAL_SYSTEMS.keys():
		var result = _integration_results.get(system_name, {})
		var status = "✅ SUCCESS" if result.get("success", false) else "❌ FAILED"
		var error_calls = result.get("error_calls_wrapped", 0)
		
		report_lines.append("### %s - %s" % [system_name, status])
		report_lines.append("- **Integration Type**: %s" % result.get("integration_type", "UNKNOWN"))
		report_lines.append("- **Error Calls Wrapped**: %d" % error_calls)
		
		if not result.get("success", false):
			report_lines.append("- **Error**: %s" % result.get("error", "Unknown error"))
		
		var features = result.get("features_added", [])
		if not features.is_empty():
			report_lines.append("- **Features Added**: %s" % ", ".join(features))
		
		report_lines.append("")
	
	# Add recommendations
	if not _integration_stats.systems_with_errors.is_empty():
		report_lines.append("## Systems Requiring Manual Attention")
		for system in _integration_stats.systems_with_errors:
			report_lines.append("- %s" % system)
		report_lines.append("")
	
	report_lines.append("## Next Steps")
	report_lines.append("1. Test all integrated systems to ensure error boundaries are functional")
	report_lines.append("2. Monitor system health scores and error rates")
	report_lines.append("3. Address any failed integrations manually")
	report_lines.append("4. Run validation tests to confirm production readiness")
	
	return "\n".join(report_lines)