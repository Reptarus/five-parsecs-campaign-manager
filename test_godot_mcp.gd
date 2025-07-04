extends Node

## Test script to verify Godot MCP server integration

func _ready():
	test_godot_mcp_integration()

func test_godot_mcp_integration():
	print("Testing Godot MCP Server Integration...")
	
	# Test MCPBridge with Godot MCP server
	var mcp_bridge = MCPBridge.new()
	
	# Connect to the signal to handle results
	mcp_bridge.godot_operation_completed.connect(_on_godot_operation_completed)
	
	# Test getting project information
	print("Requesting project information...")
	mcp_bridge.get_project_info()
	
	# Test launching Godot editor (commented out to avoid opening editor during test)
	# mcp_bridge.launch_godot_editor()

func _on_godot_operation_completed(result: Dictionary):
	print("Godot operation completed:")
	print("  Command: ", result.get("command", "unknown"))
	print("  Success: ", result.get("success", false))
	print("  Output: ", result.get("output", ""))
	
	if result.has("data"):
		print("  Data: ", result.data)
	
	# Test completed - could queue free this test node
	queue_free()