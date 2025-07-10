class_name MCPBridge
extends RefCounted

## Bridge to MCP servers for Five Parsecs Campaign Manager
##
## Provides integration with Obsidian MCP and Desktop Commander
## for documentation, rule tracking, and system operations.

signal obsidian_search_completed(results: Dictionary)
signal obsidian_note_created(success: bool, path: String)
signal desktop_command_completed(result: Dictionary)
signal rule_documented(success: bool, rule_name: String)
signal godot_operation_completed(result: Dictionary)

const SCRIPT_PATH = "res://scripts/mcp_interface.py"
const GODOT_MCP_SERVER_PATH = "res://godot-mcp-server/build/index.js"
var _active_processes: Array[int] = []

## Search Obsidian vault for Five Parsecs related content
func search_obsidian_vault(query: String) -> void:
	var args = ["obsidian-search", query]
	_execute_mcp_command(args, _on_obsidian_search_completed)

## Create a new note in Obsidian vault
func create_obsidian_note(title: String, content: String, folder: String = "") -> void:
	var args = ["obsidian-note", title, content]
	if not folder.is_empty():
		args.append(folder)
	_execute_mcp_command(args, _on_obsidian_note_created)

## Execute a desktop command through Desktop Commander
func execute_desktop_command(command: String, command_args: Array[String] = []) -> void:
	var args = ["desktop-cmd", command]
	args.append_array(command_args)
	_execute_mcp_command(args, _on_desktop_command_completed)

## Document a Five Parsecs rule implementation
func document_rule_implementation(rule_name: String, implementation_details: String) -> void:
	var args = ["document-rule", rule_name, implementation_details]
	_execute_mcp_command(args, _on_rule_documented)

## Search existing Five Parsecs rule documentation
func search_rules_documentation(search_term: String) -> void:
	var args = ["search-rules", search_term]
	_execute_mcp_command(args, _on_obsidian_search_completed)

## Build the project using MCP
func build_project() -> void:
	_execute_mcp_command(["build"], _on_desktop_command_completed)

## Run project tests using MCP
func run_tests() -> void:
	_execute_mcp_command(["test"], _on_desktop_command_completed)

## Export project for specified platform
func export_project(platform: String = "Windows Desktop") -> void:
	_execute_mcp_command(["export", platform], _on_desktop_command_completed)

## Godot MCP Server Functions

## Connect to existing debug session instead of launching new editor
func connect_to_debug_session() -> void:
	var debug_bridge = preload("res://src/utils/GodotDebugBridge.gd").new()
	if debug_bridge.connect_to_debug_port():
		print("MCPBridge: Connected to existing debug session on port 6008")
	else:
		print("MCPBridge: Failed to connect to debug session, falling back to MCP server")
		_execute_godot_mcp_command(["launch_editor"], _on_godot_operation_completed)

## Test integration through existing debug session 
func test_integration_via_debug() -> void:
	var debug_bridge = preload("res://src/utils/GodotDebugBridge.gd").new()
	debug_bridge.quick_test_integration()

## Launch Godot editor for this project (fallback)
func launch_godot_editor() -> void:
	print("MCPBridge: WARNING - This may conflict with existing debug session")
	_execute_godot_mcp_command(["launch_editor"], _on_godot_operation_completed)

## Run the Godot project (fallback)
func run_godot_project() -> void:
	print("MCPBridge: WARNING - This may conflict with existing debug session")
	_execute_godot_mcp_command(["run_project"], _on_godot_operation_completed)

## Run Godot project tests
func run_godot_tests() -> void:
	_execute_godot_mcp_command(["run_tests"], _on_godot_operation_completed)

## Get project information
func get_project_info() -> void:
	_execute_godot_mcp_command(["get_project_info"], _on_godot_operation_completed)

## Execute custom GDScript code
func execute_gdscript(script_content: String) -> void:
	_execute_godot_mcp_command(["execute_script", script_content], _on_godot_operation_completed)

## Helper method to execute MCP commands
func _execute_mcp_command(args: Array[String], callback: Callable) -> void:
	var script_path = ProjectSettings.globalize_path(SCRIPT_PATH)
	var full_args = ["python3", script_path]
	full_args.append_array(args)

	print("MCPBridge: Executing command: ", " ".join(full_args))

	# For now, we'll use a simple approach since OS.execute is synchronous
	# In a production environment, you might want to use threads or async execution
	var output: Array = []
	var exit_code = OS.execute("python3", [script_path] + args, output)

	var result: Variant = {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"success": exit_code == 0
	}

	# Parse JSON output if possible
	if result.success and not (safe_call_method(output, "is_empty") == true):
		var json = JSON.new()
		var parse_result = json.parse(result.output)
		if parse_result == OK:
			result["data"] = json.data

	# Call the callback with results
	callback.call(result)

## Helper method to execute Godot MCP commands
func _execute_godot_mcp_command(args: Array[String], callback: Callable) -> void:
	var server_path = ProjectSettings.globalize_path(GODOT_MCP_SERVER_PATH)
	var godot_path: String = "/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.4-stable_mono_win64/Godot_v4.4-stable_mono_win64.exe"

	# Environment variables can be set using the 5th argument of OS.execute if needed.
	# The following code is invalid and has been removed:
	# var env = OS.get_environment()
	# env["GODOT_PATH"] = godot_path
	# env["PROJECT_PATH"] = ProjectSettings.globalize_path("res://")

	print("MCPBridge: Executing Godot MCP command: ", " ".join(args))
	print("MCPBridge: Using Godot at: ", godot_path)

	# Execute the MCP server with the command
	var output: Array = []
	var exit_code = OS.execute("node", [server_path] + args, output, false, false)

	var result: Variant = {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"success": exit_code == 0,
		"command": args[0] if (safe_call_method(args, "size") as int) > 0 else "unknown"
	}

	# Parse JSON output if possible
	if result.success and not (safe_call_method(output, "is_empty") == true):
		var json = JSON.new()
		var parse_result = json.parse(result.output)
		if parse_result == OK:
			result["data"] = json.data

	# Call the callback with results
	callback.call(result)

## Callback handlers for different operations

func _on_obsidian_search_completed(result: Dictionary) -> void:
	print("MCPBridge: Obsidian search completed: ", result)
	obsidian_search_completed.emit(result)

func _on_obsidian_note_created(result: Dictionary) -> void:
	var success = result.get("success", false)
	var path: String = ""
	if result.has("data") and result.data.has("result"):
		path = str(result.data.get("result", ""))

	print("MCPBridge: Obsidian note creation ", "succeeded" if success else "failed")
	obsidian_note_created.emit(success, path)

func _on_desktop_command_completed(result: Dictionary) -> void:
	print("MCPBridge: Desktop command completed: ", result)
	desktop_command_completed.emit(result)

func _on_rule_documented(result: Dictionary) -> void:
	var success = result.get("success", false)
	var rule_name: String = ""
	if result.has("data"):
		rule_name = str(result.data.get("rule_name", ""))

	print("MCPBridge: Rule documentation ", "succeeded" if success else "failed")
	rule_documented.emit(success, rule_name)

func _on_godot_operation_completed(result: Dictionary) -> void:
	var command = result.get("command", "unknown")
	var success = result.get("success", false)
	print("MCPBridge: Godot operation '", command, "' ", "succeeded" if success else "failed")
	if not success:
		print("MCPBridge: Error output: ", result.get("output", ""))
	godot_operation_completed.emit(result)

## Cleanup method
func cleanup() -> void:
	# Clean up any active processes if needed
	_active_processes.clear()

## Static convenience methods for common operations

## Quick method to document a character system implementation
static func document_character_system(system_name: String, implementation: String) -> void:
	var bridge = MCPBridge.new()
	var full_impl: String = """
## Character System: %s

### Implementation
%s

### Five Parsecs Rules Reference
- Core Rulebook pages 12-17 (Character Creation)
- Character advancement rules
- Background and motivation tables

### Code Location
- Base: src/base/character/
- Core: src/core/character/
- Implementation: src/game/character/

### Testing
- Unit tests in tests/unit/character/
- Integration tests in tests/integration/character/
""" % [system_name, implementation]

	bridge.document_rule_implementation("Character System - " + str(system_name), full_impl)

## Quick method to document a combat system implementation
static func document_combat_system(system_name: String, implementation: String) -> void:
	var bridge = MCPBridge.new()
	var full_impl: String = """
## Combat System: %s

### Implementation
%s

### Five Parsecs Rules Reference
- Core Rulebook pages 71-84 (Combat)
- Attack resolution: d10 + Combat skill vs target 4+
- Range modifiers and cover rules
- Critical hit mechanics

### Code Location
- Base: src/base/combat/
- Core: src/core/battle/
- Implementation: src/game/combat/

### Testing
- Unit tests in tests/unit/combat/
- Integration tests in tests/integration/battle/
""" % [system_name, implementation]

	bridge.document_rule_implementation("Combat System - " + str(system_name), full_impl)

## Quick method to document a campaign system implementation
static func document_campaign_system(system_name: String, implementation: String) -> void:
	var bridge = MCPBridge.new()
	var full_impl: String = """
## Campaign System: %s

### Implementation
%s

### Five Parsecs Rules Reference
- Core Rulebook pages 34-52 (Campaign Turn)
- Four-phase turn structure: Travel, World, Battle, Resolution
- Campaign events and progression

### Code Location
- Base: src/base/campaign/
- Core: src/core/campaign/
- Implementation: src/game/campaign/

### Testing
- Unit tests in tests/unit/campaign/
- Integration tests in tests/integration/campaign/
""" % [system_name, implementation]

	bridge.document_rule_implementation("Campaign System - " + str(system_name), full_impl)

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