@tool
extends SceneTree

## Five Parsecs Campaign Manager Test Runner
##
## This script runs all tests for the Five Parsecs Campaign Manager project.
## It can be run from the command line or from the editor.
## 
## Command line usage:
## godot --headless --script tests/run_five_parsecs_tests.gd
##
## Editor usage:
## Run this script as a tool script from the editor

const TEST_DIRECTORIES = [
	"res://tests/unit/character/",
	"res://tests/unit/campaign/",
	"res://tests/unit/mission/",
	"res://tests/unit/ships/",
	"res://tests/unit/battle/",
	"res://tests/unit/enemy/",
	"res://tests/integration/"
]

const GUT_SETTINGS = {
	"log_level": 3,
	"include_subdirs": true,
	"prefix": "test_",
	"suffix": ".gd",
	"double_strategy": "partial",
	"should_maximize": true
}

var _gut_instance = null
var _test_count = 0
var _failures = 0
var _errors = 0

func _init():
	print("Five Parsecs Campaign Manager - Test Runner")
	print("--------------------------------------------")
	
	# Initialize GUT and configure it
	_initialize_gut()
	
	# Run tests
	_run_tests()
	
	# Print summary and quit
	_print_results()
	quit()

func _initialize_gut():
	# Load GUT
	var GutScene = load("res://addons/gut/gut.gd")
	_gut_instance = GutScene.new()
	
	# Configure GUT with settings
	for key in GUT_SETTINGS:
		_gut_instance.set(key, GUT_SETTINGS[key])
	
	# Add GUT to the scene tree
	get_root().add_child(_gut_instance)
	
	# Set up directories
	for directory in TEST_DIRECTORIES:
		_gut_instance.add_directory(directory)
	
	# Connect signals
	_gut_instance.connect("tests_finished", _on_tests_finished)

func _run_tests():
	print("Running tests...")
	_gut_instance.test_scripts()

func _on_tests_finished():
	_test_count = _gut_instance.get_test_count()
	_failures = _gut_instance.get_fail_count()
	_errors = _gut_instance.get_error_count()

func _print_results():
	print("\nTest Results:")
	print("--------------------------------------------")
	print("Tests run: %d" % _test_count)
	print("Failures: %d" % _failures)
	print("Errors: %d" % _errors)
	
	if _failures == 0 and _errors == 0:
		print("\n✅ All tests passed!")
	else:
		print("\n❌ Tests failed!")
		
	print("--------------------------------------------")
	print("For detailed results, check the report in 'res://tests/reports/'")