@tool
class_name CursorIntegration
extends RefCounted

## Real-time Cursor IDE Integration for Five Parsecs Campaign Manager
## 
## Provides live error monitoring, problem detection, and IDE interaction
## to streamline development workflow with Claude Code.

signal errors_detected(errors: Array)
signal compilation_completed(success: bool, output: String)
signal test_run_completed(results: Dictionary)

const CURSOR_BRIDGE_SCRIPT = "res://scripts/cursor_mcp_bridge.py"
var _monitoring_thread: Thread
var _is_monitoring: bool = false
var _last_error_check: float = 0.0

## Start real-time monitoring of Cursor IDE for errors and problems
func start_error_monitoring(duration_seconds: int = 300) -> void:
	if _is_monitoring:
		print("CursorIntegration: Already monitoring")
		return

	print("CursorIntegration: Starting real-time error monitoring...")
	_is_monitoring = true

	# Start monitoring in background
	var script_path = ProjectSettings.globalize_path(CURSOR_BRIDGE_SCRIPT)
	var project_path = ProjectSettings.globalize_path("res://")

	var args = [
		"python3", script_path,
		"monitor",
		"--project", project_path,
		"--duration", str(duration_seconds)
	]

	print("CursorIntegration: Executing: ", " ".join(args))

	# Start monitoring process
	_monitoring_thread = Thread.new()
	_monitoring_thread.start(_monitoring_worker.bind(args))

## Stop error monitoring
func stop_error_monitoring() -> void:
	_is_monitoring = false
	if _monitoring_thread and _monitoring_thread.is_started():
		_monitoring_thread.wait_to_finish()
	print("CursorIntegration: Error monitoring stopped")

## Get current error state from Cursor IDE
func get_current_errors() -> Dictionary:
	var script_path = ProjectSettings.globalize_path(CURSOR_BRIDGE_SCRIPT)
	var project_path = ProjectSettings.globalize_path("res://")

	var output: Array = []
	var exit_code = OS.execute("python3", [script_path, "errors", "--project", project_path], output)

	if exit_code == 0 and output.size() > 0:
		var json_text: String = "\n".join(output)
		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result == OK:
			return json.data

	return {"error": "Failed to get current errors", "exit_code": exit_code}

## Run tests and get immediate feedback
func run_tests_with_feedback() -> Dictionary:
	print("CursorIntegration: Running tests with real-time feedback...")

	var script_path = ProjectSettings.globalize_path(CURSOR_BRIDGE_SCRIPT)
	var project_path = ProjectSettings.globalize_path("res://")

	var output: Array = []
	var exit_code = OS.execute("python3", [script_path, "test", "--project", project_path], output)

	var result: Variant = {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"success": exit_code == 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Parse test results if possible
	var output_text = result.output
	if "test" in output_text.to_lower():
		result["test_summary"] = _parse_test_output(output_text)

	test_run_completed.emit(result)
	return result

## Build project and monitor for compilation errors
func build_with_error_monitoring() -> Dictionary:
	print("CursorIntegration: Building project with error monitoring...")

	var script_path = ProjectSettings.globalize_path(CURSOR_BRIDGE_SCRIPT)
	var project_path = ProjectSettings.globalize_path("res://")

	var output: Array = []
	var exit_code = OS.execute("python3", [script_path, "build", "--project", project_path], output)

	var result: Variant = {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"success": exit_code == 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	compilation_completed.emit(result.success, result.output)
	return result

## Check for errors periodically (call from _ready or timer)
func periodic_error_check() -> void:
	var current_time = Time.get_unix_time_from_system()

	# Check every 30 seconds
	if current_time - _last_error_check < 30.0:
		return

	_last_error_check = current_time

	var errors = get_current_errors()
	if errors.has("godot_errors") or errors.has("compilation_errors"):
		var total_errors: Array = []

		if errors.has("godot_errors"):
			total_errors.append_array(errors.godot_errors)
		if errors.has("compilation_errors"):
			total_errors.append_array(errors.compilation_errors)

		if total_errors.size() > 0:
			print("CursorIntegration: Found ", total_errors.size(), " errors")
			errors_detected.emit(total_errors)

## Validate enhanced character creation system with real-time feedback
func validate_character_creation_system() -> Dictionary:
	print("CursorIntegration: Validating enhanced character creation system...")

	var validation_results = {
		"syntax_check": true,
		"compilation_check": true,
		"test_run": true,
		"errors": [],
		"warnings": [],
		"success": true
	}

	# 1. Check current errors first
	var current_errors = get_current_errors()
	if current_errors.has("error"):
		validation_results.errors.append("Failed to get current error state")
		validation_results.success = false
		return validation_results

	# 2. Run tests specifically for character creation
	var test_result = run_tests_with_feedback()
	if not test_result.success:
		validation_results.test_run = false
		validation_results.errors.append("Character creation tests failed")
		validation_results.success = false

	# 3. Check for specific files
	var required_files = [
		"src/core/character/tables/CharacterCreationTables.gd",
		"src/core/character/equipment/StartingEquipmentGenerator.gd",
		"src/core/character/connections/CharacterConnections.gd",
		"tests/unit/character/test_enhanced_character_creation.gd"
	]

	for file_path in required_files:
		var full_path = ProjectSettings.globalize_path("res://" + file_path)
		if not FileAccess.file_exists(full_path):
			validation_results.errors.append("Missing required file: " + file_path)
			validation_results.success = false

	# 4. Summary
	if validation_results.success:
		print("CursorIntegration: ✅ Enhanced character creation system validation passed")
	else:
		print("CursorIntegration: ❌ Enhanced character creation system validation failed")
		for error in validation_results.errors:
			print("  - ", error)

	return validation_results

## Background monitoring worker
func _monitoring_worker(args: Array) -> void:
	print("CursorIntegration: Background monitoring started")

	var output: Array = []
	var exit_code = OS.execute(args[0], args.slice(1), output)

	print("CursorIntegration: Background monitoring completed with exit code: ", exit_code)
	if output.size() > 0:
		print("CursorIntegration: Monitor output: ", "\n".join(output))

## Parse test output for useful information
func _parse_test_output(output: String) -> Dictionary:
	var summary = {
		"total_tests": 0,
		"passed": 0,
		"failed": 0,
		"errors": 0
	}

	var lines = output.split("\n")
	for line in lines:
		line = line.strip_edges()

		# Look for common test result patterns
		if "test" in line.to_lower() and ("passed" in line.to_lower() or "failed" in line.to_lower()):
			if "passed" in line.to_lower():
				summary.passed += 1
			elif "failed" in line.to_lower():
				summary.failed += 1

		elif "error" in line.to_lower():
			summary.errors += 1

	summary.total_tests = summary.passed + summary.failed
	return summary

## Static convenience method for immediate error checking
static func quick_error_check() -> void:
	var integration = CursorIntegration.new()
	var errors = integration.get_current_errors()

	print("CursorIntegration Quick Check:")
	if errors.has("error"):
		print("  ❌ Error getting status: ", errors.error)
	else:
		var godot_errors = errors.get("godot_errors", [])
		var compilation_errors = errors.get("compilation_errors", [])
		var total_errors = godot_errors.size() + compilation_errors.size()

		if total_errors == 0:
			print("  ✅ No errors detected")
		else:
			print("  ⚠️ Found ", total_errors, " potential issues")
			print("    - Godot errors: ", godot_errors.size())
			print("    - Compilation errors: ", compilation_errors.size())

## Static method to validate our enhanced character creation implementation
static func validate_implementation() -> bool:
	var integration = CursorIntegration.new()
	var result: Variant = integration.validate_character_creation_system()
	return result.success
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null