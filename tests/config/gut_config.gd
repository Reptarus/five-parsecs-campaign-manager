@tool
extends Resource

## GUT test configuration resource
## Manages test paths and dependencies for the Five Parsecs Campaign Manager

const TEST_DIRS := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

const FIXTURE_PATH := "res://tests/fixtures"
const HELPER_PATH := "res://tests/fixtures/helpers"
const TEST_RESOURCES_PATH := "res://tests/fixtures/resources"

# Configure test paths relative to project root
static func get_test_paths() -> Dictionary:
	return {
		"test_dirs": TEST_DIRS,
		"fixture_path": FIXTURE_PATH,
		"helper_path": HELPER_PATH,
		"resources_path": TEST_RESOURCES_PATH
	}

# Get all test script paths
static func get_test_scripts() -> Array[String]:
	var scripts: Array[String] = []
	for dir_key: String in TEST_DIRS.keys():
		var dir_path: String = TEST_DIRS[dir_key]
		scripts.append_array(_get_test_files_in_dir(dir_path))
	return scripts

# Helper to recursively get test files
static func _get_test_files_in_dir(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		# In Godot 4, list_dir_begin() takes no parameters or optional parameters
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				files.append_array(_get_test_files_in_dir(path.path_join(file_name)))
			elif file_name.begins_with("test_") and file_name.ends_with(".gd"):
				files.append(path.path_join(file_name))
			file_name = dir.get_next()
	return files

# Configure test dependencies
static func configure_test_dependencies(gut_instance) -> void:
	# Check if the instance has the required methods before calling them
	if gut_instance == null:
		push_warning("GUT instance is null")
		return
		
	# Add helper scripts to autoload
	if gut_instance.has_method("add_directory"):
		gut_instance.add_directory(HELPER_PATH)
	else:
		push_warning("GUT instance doesn't have add_directory method")
	
	# Configure paths for resource loading
	if gut_instance.has_method("set_test_metadata"):
		gut_instance.set_test_metadata({
			"fixture_path": FIXTURE_PATH,
			"resources_path": TEST_RESOURCES_PATH
		})
	else:
		push_warning("GUT instance doesn't have set_test_metadata method")
		
	# Set common test configuration
	if gut_instance.has_method("set_should_maximize"):
		gut_instance.set_should_maximize(true)
	
	if gut_instance.has_method("set_include_subdirectories"):
		gut_instance.set_include_subdirectories(true)
		
	if gut_instance.has_method("set_unit_test_name"):
		gut_instance.set_unit_test_name("test_*.gd")
		
	if gut_instance.has_method("set_double_strategy"):
		gut_instance.set_double_strategy(1) # DOUBLE_STRATEGY.PARTIAL
		
	if gut_instance.has_method("set_log_level"):
		gut_instance.set_log_level(2) # LOG_LEVEL_ALL_ASSERTS
	else:
		push_warning("GUT instance doesn't have set_log_level method")