extends SceneTree

const TEST_RUNNER = preload("res://src/tests/run_tests.gd")

func _init() -> void:
    print("Starting build process...")
    
    # Configure debug output
    if OS.is_debug_build():
        print_debug("Debug mode enabled")
        _setup_debug_logging()
    
    # Validate project structure
    var validation_result = _validate_project()
    if not validation_result.is_empty():
        push_error("Project validation failed:")
        for error in validation_result:
            push_error("- " + error)
        quit(1)
    
    # Run tests if in test mode
    if "--run-tests" in OS.get_cmdline_args():
        _run_tests()
    else:
        print("Build completed successfully")
        quit(0)

func _setup_debug_logging() -> void:
    print_debug("Setting up debug logging...")
    # Configure any additional debug settings here
    
func _validate_project() -> Array[String]:
    var errors: Array[String] = []
    
    # Validate core directories
    var required_dirs = [
        "res://src/core",
        "res://src/scenes",
        "res://src/tests",
        "res://assets"
    ]
    
    for dir in required_dirs:
        if not DirAccess.dir_exists_absolute(dir):
            errors.append("Missing required directory: " + dir)
    
    # Validate core scripts
    var required_scripts = [
        "res://src/core/systems/GlobalEnums.gd",
        "res://src/core/managers/GameStateManager.gd",
        "res://src/core/character/Management/CharacterManager.gd"
    ]
    
    for script in required_scripts:
        if not FileAccess.file_exists(script):
            errors.append("Missing required script: " + script)
    
    return errors

func _run_tests() -> void:
    print("Running tests...")
    var test_runner = TEST_RUNNER.new()
    root.add_child(test_runner)