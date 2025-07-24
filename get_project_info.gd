extends SceneTree

func _init():
	var mcp_bridge = load("res://scripts/mcp_interface.py").new()
	mcp_bridge.godot_operation_completed.connect(func(result):
		print(result)
		quit()
	)

	mcp_bridge.get_project_info()