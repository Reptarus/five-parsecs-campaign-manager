extends SceneTree

func _init():
    var root = get_root()
    var mcp_bridge = MCPBridge.new()
    root.add_child(mcp_bridge)

    mcp_bridge.godot_operation_completed.connect(func(result):
        print(result)
        get_tree().quit()
    )

    mcp_bridge.get_project_info()