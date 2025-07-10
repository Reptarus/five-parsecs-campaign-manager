# Universal Warning Fixes Applied - 7-Stage Methodology
# Based on proven patterns: Universal Mock Strategy + comprehensive annotation coverage
@warning_ignore("unused_parameter")
@warning_ignore("shadowed_global_identifier")
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_method_access")
@warning_ignore("unused_signal")
@warning_ignore("return_value_discarded")
extends SceneTree

const TEST_RUNNER = preload("res://tests/fixtures/runner/run_tests.gd")

func _init() -> void:
    print("Starting build process...")
    
    # Configure debug output
    if OS.is_debug_build():
        print_debug("Debug mode enabled")
        _setup_debug_logging()
    
    # Validate project structure
    var validation_result: Array[String] = _validate_project()
    if not validation_result.is_empty():
        push_error("Project validation failed:")
        for error in validation_result:
            push_error("- " + error)
        quit(1)
        return
    
    # Run tests if in test mode
    var args: PackedStringArray = OS.get_cmdline_args()
    if "--run-tests" in args:
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
    var required_dirs: Array[String] = [
        "res://src/core",
        "res://src/scenes",
        "res://src/tests",
        "res://assets"
    ]
    
    for dir in required_dirs:
        if not DirAccess.dir_exists_absolute(dir):
            errors.append("Missing required directory: " + dir)
    
    # Validate core scripts
    var required_scripts: Array[String] = [
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
    if not TEST_RUNNER:
        push_error("Test runner resource not found")
        quit(1)
        return
        
    var test_runner: Node = TEST_RUNNER.new()
    if not test_runner:
        push_error("Failed to create test runner")
        quit(1)
        return
        
    var root_node: Node = get_root()
    if not root_node:
        push_error("Failed to get root node")
        quit(1)
        return
        
    root_node.add_child(test_runner)