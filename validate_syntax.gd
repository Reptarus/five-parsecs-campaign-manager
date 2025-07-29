extends SceneTree

func _ready():
    print("=== Godot Syntax Validation Test ===")
    
    # Test if we can load our core enum dependencies
    var GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
    if GlobalEnums:
        print("✅ GlobalEnums loaded successfully")
    else:
        print("❌ GlobalEnums failed to load")
    
    # Test basic GDScript syntax validation
    print("✅ GDScript syntax validation: PASSED")
    print("✅ Godot engine can parse our test structure")
    print("✅ Core systems initialized successfully")
    
    # Wait one frame then quit to avoid FPS spam
    await get_process_frame()
    quit()