extends "res://addons/gut/test.gd"

# Core system tests
const BattlefieldGeneratorTest = preload("res://tests/test_battlefield_generator.gd")
const CharacterManagerTest = preload("res://tests/test_character_manager.gd")
const PerformanceTest = preload("res://tests/test_performance.gd")

var test_files := {
    "Battlefield Generator": BattlefieldGeneratorTest,
    "Character Manager": CharacterManagerTest,
    "Performance": PerformanceTest
}

func before_all() -> void:
    super.before_all()
    print("\nRunning Five Parsecs Test Suite")

func after_all() -> void:
    super.after_all()
    print("\nTest Suite Complete")

func test_run_all() -> void:
    for test_name in test_files:
        print("\nRunning %s Tests..." % test_name)
        var test_script = test_files[test_name].new()
        add_child(test_script)
        
        # Run test lifecycle
        test_script.before_all()
        
        # Get all test methods
        var methods = test_script.get_method_list()
        for method in methods:
            if method.name.begins_with("test_"):
                print("  Running: %s" % method.name)
                await test_script.call(method.name)
        
        test_script.after_all()
        test_script.queue_free()
        
        print("%s Tests Complete" % test_name)