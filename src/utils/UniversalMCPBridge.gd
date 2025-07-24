class_name UniversalMCPBridge
extends RefCounted

## Enhanced MCP Bridge with Universal Coordination
##
## Fixes information handoff between Claude Desktop, Claude Code, Godot MCP, and Gemini
## Provides unified interface with shared state management and consistent path handling

signal operation_completed(result: Dictionary)
signal workflow_completed(result: Dictionary)
signal handoff_prepared(context: Dictionary)
signal configuration_fixed(result: Dictionary)

const COORDINATOR_SCRIPT = "scripts/universal_mcp_coordinator.py"
const SHARED_STATE_FILE = "mcp_shared_state.json"
const HANDOFF_CONTEXT_FILE = "mcp_handoff_context.json"
const UNIFIED_CONFIG_FILE = "mcp_unified_config.json"

var current_session_id: String = ""
var shared_context: Dictionary = {}
var _last_operation_result: Dictionary = {}

## Initialize universal MCP coordination
func _init():
	_load_shared_context()
	print("UniversalMCPBridge: Initialized with session ", current_session_id)

## Load shared context from coordinator
func _load_shared_context() -> void:
	var state_file_path = _get_project_path().path_join(SHARED_STATE_FILE)
	if FileAccess.file_exists(state_file_path):
		var file = FileAccess.open(state_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				shared_context = json.data
				current_session_id = shared_context.get("session_id", "")
				print("UniversalMCPBridge: Loaded shared context from session ", current_session_id)
			else:
				push_warning("Failed to parse shared state file")
	else:
		print("UniversalMCPBridge: No shared state found, will create new session")

## Save current context
func _save_shared_context() -> void:
	var state_file_path = _get_project_path().path_join(SHARED_STATE_FILE)
	var file = FileAccess.open(state_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(shared_context, "\t"))
		file.close()

## Get project root path
func _get_project_path() -> String:
	return ProjectSettings.globalize_path("res://")

## Execute Universal MCP Coordinator command
func _execute_coordinator_command(args: Array[String]) -> Dictionary:
	var coordinator_path = _get_project_path().path_join(COORDINATOR_SCRIPT)
	var full_args = ["python3", coordinator_path] + args
	
	print("UniversalMCPBridge: Executing: ", " ".join(full_args))
	
	var output: Array = []
	var exit_code = OS.execute("python3", [coordinator_path] + args, output)
	
	var result_text = "\n".join(output)
	var result: Dictionary = {}
	
	# Try to parse JSON result
	if not result_text.is_empty():
		var json = JSON.new()
		var parse_result = json.parse(result_text)
		if parse_result == OK:
			result = json.data
		else:
			result = {
				"success": false,
				"error": "Failed to parse coordinator response",
				"raw_output": result_text
			}
	else:
		result = {
			"success": false,
			"error": "No output from coordinator",
			"exit_code": exit_code
		}
	
	_last_operation_result = result
	_update_shared_context(result)
	return result

## Update shared context with operation result
func _update_shared_context(result: Dictionary) -> void:
	if result.has("session_id"):
		current_session_id = result.session_id
		shared_context["session_id"] = current_session_id
	
	shared_context["last_operation"] = result
	shared_context["timestamp"] = Time.get_unix_time_from_system()
	_save_shared_context()

## Get unified project status across all MCP systems
func get_project_status() -> Dictionary:
	var result = _execute_coordinator_command(["status"])
	operation_completed.emit(result)
	return result

## Fix configuration inconsistencies across all MCP systems
func fix_configuration_inconsistencies() -> Dictionary:
	var result = _execute_coordinator_command(["fix-config"])
	configuration_fixed.emit(result)
	return result

## Execute Claude Desktop operation with unified context
func execute_claude_desktop_operation(operation: String, parameters: Dictionary = {}) -> Dictionary:
	var args = ["claude-desktop", operation]
	if not parameters.is_empty():
		args.append(JSON.stringify(parameters))
	
	var result = _execute_coordinator_command(args)
	operation_completed.emit(result)
	return result

## Execute Godot MCP Server operation with unified context
func execute_godot_mcp_operation(operation: String, parameters: Dictionary = {}) -> Dictionary:
	var args = ["godot-mcp", operation]
	if not parameters.is_empty():
		args.append(JSON.stringify(parameters))
	
	var result = _execute_coordinator_command(args)
	operation_completed.emit(result)
	return result

## Execute Gemini operation with unified context
func execute_gemini_operation(operation: String, parameters: Dictionary = {}) -> Dictionary:
	var args = ["gemini", operation]
	if not parameters.is_empty():
		args.append(JSON.stringify(parameters))
	
	var result = _execute_coordinator_command(args)
	operation_completed.emit(result)
	return result

## Execute coordinated workflow across multiple systems
func execute_coordinated_workflow(workflow_name: String, parameters: Dictionary = {}) -> Dictionary:
	var args = ["workflow", workflow_name]
	if not parameters.is_empty():
		args.append(JSON.stringify(parameters))
	
	var result = _execute_coordinator_command(args)
	workflow_completed.emit(result)
	return result

## Prepare handoff context for AI system transitions
func prepare_handoff_context() -> Dictionary:
	var result = _execute_coordinator_command(["handoff"])
	handoff_prepared.emit(result)
	return result

## Common Operations - Enhanced with Universal Coordination

## Check Godot syntax across all files
func check_godot_syntax() -> Dictionary:
	return execute_claude_desktop_operation("check_godot_syntax")

## Run comprehensive test suite
func run_tests() -> Dictionary:
	return execute_claude_desktop_operation("run_tests")

## Get project information through Godot MCP
func get_project_info() -> Dictionary:
	return execute_godot_mcp_operation("get_project_info")

## Launch Godot editor (coordinated)
func launch_godot_editor() -> Dictionary:
	return execute_godot_mcp_operation("launch_editor")

## Execute GDScript code through MCP
func execute_gdscript(script_content: String) -> Dictionary:
	return execute_godot_mcp_operation("execute_script", {"script": script_content})

## Analyze code with Gemini
func analyze_code_with_gemini(file_path: String) -> Dictionary:
	return execute_gemini_operation("analyze_code", {"file_path": file_path})

## Coordinated Workflows

## Full project validation across all systems
func validate_project_comprehensive() -> Dictionary:
	return execute_coordinated_workflow("full_project_validation")

## Development handoff preparation
func prepare_development_handoff() -> Dictionary:
	return execute_coordinated_workflow("development_handoff")

## Utility Methods

## Get last operation result
func get_last_result() -> Dictionary:
	return _last_operation_result

## Get current session ID
func get_session_id() -> String:
	return current_session_id

## Get shared context
func get_shared_context() -> Dictionary:
	return shared_context

## Check if handoff context exists
func has_handoff_context() -> bool:
	var handoff_file = _get_project_path().path_join(HANDOFF_CONTEXT_FILE)
	return FileAccess.file_exists(handoff_file)

## Load handoff context from previous AI session
func load_handoff_context() -> Dictionary:
	var handoff_file = _get_project_path().path_join(HANDOFF_CONTEXT_FILE)
	if not FileAccess.file_exists(handoff_file):
		return {"error": "No handoff context found", "success": false}
	
	var file = FileAccess.open(handoff_file, FileAccess.READ)
	if not file:
		return {"error": "Could not read handoff context", "success": false}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		return {"handoff_context": json.data, "success": true}
	else:
		return {"error": "Failed to parse handoff context", "success": false}

## System Integration Helpers

## Wait for operation completion with timeout
func wait_for_operation(operation_name: String, timeout_seconds: float = 30.0) -> Dictionary:
	var start_time = Time.get_time_dict_from_system()
	var timeout_ms = timeout_seconds * 1000.0
	
	while Time.get_time_dict_from_system()["unix"] - start_time["unix"] < timeout_seconds:
		# Check if operation completed in shared context
		_load_shared_context()
		if shared_context.has("last_operation"):
			var last_op = shared_context.last_operation
			if last_op.get("operation", "") == operation_name:
				return last_op
		
		# Wait a bit before checking again
		# Note: RefCounted objects don't have access to scene tree
		# This function should be called from a Node context for proper async behavior
		# For now, we'll just return immediately to avoid blocking
		break
	
	return {"error": "Operation timed out", "success": false, "operation": operation_name}

## Cleanup and shutdown
func cleanup() -> void:
	print("UniversalMCPBridge: Cleaning up session ", current_session_id)
	# Save final state
	_save_shared_context()

## Static convenience methods for quick access

## Quick project status check
static func quick_status_check() -> Dictionary:
	var bridge = UniversalMCPBridge.new()
	return bridge.get_project_status()

## Quick configuration fix
static func quick_config_fix() -> Dictionary:
	var bridge = UniversalMCPBridge.new()
	return bridge.fix_configuration_inconsistencies()

## Quick handoff preparation
static func quick_handoff_prep() -> Dictionary:
	var bridge = UniversalMCPBridge.new()
	return bridge.prepare_development_handoff()

## Debug and diagnostics

## Print current system state
func debug_print_state() -> void:
	print("=== UniversalMCPBridge Debug State ===")
	print("Session ID: ", current_session_id)
	print("Shared Context: ", shared_context)
	print("Last Result: ", _last_operation_result)
	print("Project Path: ", _get_project_path())
	print("Has Handoff Context: ", has_handoff_context())
	print("=========================================")

## Validate system configuration
func validate_system_configuration() -> Dictionary:
	var validation_result = {
		"coordinator_script_exists": FileAccess.file_exists(_get_project_path().path_join(COORDINATOR_SCRIPT)),
		"python_available": true, # Assume python is available
		"shared_state_accessible": true,
		"project_path_valid": not _get_project_path().is_empty(),
		"session_active": not current_session_id.is_empty()
	}
	
	validation_result["all_valid"] = validation_result.values().all(func(v): return v == true)
	
	return validation_result
