@tool
extends SceneTree

## Compatibility Tests Runner
##
## This script runs a subset of tests that were previously failing
## due to property_exists compatibility issues with Godot 4.4+.
##
## Run with: godot --headless --script tests/compatibility_tests.gd

# Define patch script path 
const PROPERTY_EXISTS_PATCH_PATH = "res://tests/fixtures/helpers/property_exists_patch.gd"

# We'll load the patch dynamically to avoid linter errors
var PropertyExistsPatch = null

# Tests to run (focus on previously failing tests)
const TEST_PATHS = [
	"res://tests/integration/enemy/test_enemy_campaign_flow.gd",
	"res://tests/unit/ship/test_ship.gd",
	"res://tests/unit/core/test_serializable_resource.gd",
	"res://tests/unit/mission/test_mission_generator.gd"
]

var _gut = null
var _tests_completed = false
var _tests_passed = 0
var _tests_failed = 0

func _init():
	print("\n======== FIVE PARSECS COMPATIBILITY TESTS ========")
	print("Running compatibility tests for Godot 4.4+ property_exists issues...")
	
	# Load dependencies
	_load_dependencies()
	
	# Initialize resource cleaner
	_setup_compatibility_patches()
	
	# Initialize and configure GUT
	_init_gut()
	
	# Run the specified tests
	_gut.test_scripts(TEST_PATHS)
	
	# Wait for tests to complete
	await _wait_for_tests_to_complete()
	
	# Verify if patching was successful
	print("\n======== COMPATIBILITY TEST SUMMARY ========")
	print("Total tests passed: " + str(_tests_passed))
	print("Total tests failed: " + str(_tests_failed))
	
	if _tests_failed == 0:
		print("\n✅ COMPATIBILITY PATCHES SUCCESSFUL!")
	else:
		print("\n❌ SOME COMPATIBILITY ISSUES REMAIN!")
		
	if OS.has_feature("headless") or not OS.has_feature("editor"):
		quit(_tests_failed > 0)

func _load_dependencies() -> void:
	# Dynamically load the property exists patch
	if ResourceLoader.exists(PROPERTY_EXISTS_PATCH_PATH):
		PropertyExistsPatch = load(PROPERTY_EXISTS_PATCH_PATH)
		print("Successfully loaded PropertyExistsPatch")
	else:
		push_error("Could not find PropertyExistsPatch script at " + PROPERTY_EXISTS_PATCH_PATH)
		print("WARNING: PropertyExistsPatch not found, tests may fail")

func _setup_compatibility_patches() -> void:
	print("Setting up compatibility patches...")
	
	# Add autoload for property_exists_patch
	if PropertyExistsPatch != null:
		Engine.register_singleton("PropertyExistsPatch", PropertyExistsPatch)
		print("- Registered PropertyExistsPatch singleton")
	else:
		print("- WARNING: Could not register PropertyExistsPatch singleton")
	
	# Apply patch to Resource base class
	var resource_script = GDScript.new()
	resource_script.source_code = """
@tool
extends Resource

func has(property_name: String) -> bool:
	# Check if property exists in property list
	for prop in get_property_list():
		if prop.name == property_name:
			return true
	
	# Fallback to direct property access
	return property_name in self
"""
	resource_script.reload()
	Engine.set_meta("resource_has_patch", resource_script)
	print("- Created Resource has() method patch")

func _init_gut() -> void:
	var gut_path = "res://addons/gut/gut.gd"
	var gut_exists = ResourceLoader.exists(gut_path)
	if not gut_exists:
		print("ERROR: GUT not found at " + gut_path)
		quit(1)
		return
		
	var gut_script = load(gut_path)
	_gut = gut_script.new()
	get_root().add_child(_gut)
	
	# Configure GUT for our compatibility tests
	_gut.log_level = 3 # Show warnings and errors
	_gut.include_subdirectories = true
	_gut.prefix = "test_"
	_gut.suffix = ".gd"
	
	# Enable detailed logging for debugging
	_gut.log_level = 3
	_gut.should_yield = true
	_gut.should_yield_between_tests = true
	
	print("- GUT initialized")

func _wait_for_tests_to_complete():
	print("Waiting for tests to complete...")
	
	# This loop will continue until all tests are done
	var start_time = Time.get_ticks_msec()
	var timeout = 60 * 1000 # 60 second timeout
	
	while (Time.get_ticks_msec() - start_time) < timeout:
		# Process a frame
		await Engine.get_main_loop().process_frame
		
		# Check if GUT has completed all tests
		if _gut.is_passing() != null: # Test completion is determined
			_tests_passed = _gut.get_pass_count()
			_tests_failed = _gut.get_fail_count()
			_tests_completed = true
			print("Tests completed: " + str(_gut.get_test_count()))
			return
	
	# If we reach here, tests timed out
	print("ERROR: Tests timed out after 60 seconds")
	_tests_failed = 1
	_tests_completed = true