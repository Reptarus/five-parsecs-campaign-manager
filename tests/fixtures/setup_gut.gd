@tool
extends EditorScript

const DEFAULT_DIRS = [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/performance",
	"res://tests/mobile",
	"res://tests/fixtures"
]

const DEFAULT_CONFIG = {
	"dirs": ["res://tests/"],
	"double_strategy": "script_only",
	"ignore_pause": true,
	"include_subdirs": true,
	"log_level": 1,
	"prefix": "test_",
	"should_exit": true,
	"should_maximize": true,
	"should_exit_on_success": true,
	"inner_class": false,
	"selected": "",
	"suffix": ".gd",
	"tests": [],
	"unit_test_name": "",
	"post_run_script": "res://tests/fixtures/post_run.gd",
	"pre_run_script": "res://tests/fixtures/pre_run.gd"
}

const EDITOR_CONFIG = {
	"background_color": Color(0.2, 0.2, 0.2, 1),
	"font": "CourierPrime",
	"font_size": 16,
	"hide_orphans": true,
	"include_subdirs": true,
	"directory_0": "res://tests/",
	"compact_mode": false,
	"opacity": 100,
	"panel_options": {
		"font": "CourierPrime",
		"font_size": 16
	}
}

const INIT_FLAG_FILE = "res://.gut_initialized"

func _run() -> void:
	if FileAccess.file_exists(INIT_FLAG_FILE):
		print("GUT already initialized. Running test discovery...")
		_discover_tests()
		return
		
	print("First-time GUT initialization starting...")
	
	# Create directory structure
	for dir in DEFAULT_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			print("Creating directory: ", dir)
			DirAccess.make_dir_recursive_absolute(dir)
	
	# Create default config file
	var config_path := "res://tests/gut_config.json"
	var config_file := FileAccess.open(config_path, FileAccess.WRITE)
	if config_file:
		print("Creating GUT config file: ", config_path)
		config_file.store_string(JSON.stringify(DEFAULT_CONFIG, "  "))
		config_file.close()
	
	# Create editor config file
	var editor_config_path := "res://.gut_editor_config.json"
	var editor_config_file := FileAccess.open(editor_config_path, FileAccess.WRITE)
	if editor_config_file:
		print("Creating GUT editor config: ", editor_config_path)
		editor_config_file.store_string(JSON.stringify(EDITOR_CONFIG, "  "))
		editor_config_file.close()
	
	# Create pre/post run scripts if they don't exist
	_create_hook_script("res://tests/fixtures/pre_run.gd", "pre")
	_create_hook_script("res://tests/fixtures/post_run.gd", "post")
	
	# Create test discovery helper
	_create_test_discovery_helper()
	
	# Create test generator
	_create_test_generator()
	
	# Create example tests
	_create_example_tests()
	
	# Create initialization flag
	var flag_file := FileAccess.open(INIT_FLAG_FILE, FileAccess.WRITE)
	if flag_file:
		flag_file.store_string(Time.get_datetime_string_from_system())
		flag_file.close()
	
	print("GUT initialization complete!")
	print("Running initial test discovery...")
	_discover_tests()
	
	print("\nSetup complete! You can now:")
	print("1. Open the GUT panel")
	print("2. Click 'Run All' to verify the setup")
	print("3. Check the test directories for example tests")
	print("\nTo create new tests, use the test generator:")
	print("  tests/fixtures/test_generator.gd")

func _create_hook_script(path: String, hook_type: String) -> void:
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			print("Creating %s-run hook: %s" % [hook_type, path])
			var template := """@tool
extends Node

func _init() -> void:
	print("Running%s-test hook...")

func setup() -> void:
	# Add your %s-test setup code here
	pass

func cleanup() -> void:
	# Add your %s-test cleanup code here
	pass
""" % [hook_type, hook_type, hook_type]
			file.store_string(template)
			file.close()

func _create_test_discovery_helper() -> void:
	var path := "res://tests/fixtures/test_discovery.gd"
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			print("Creating test discovery helper: ", path)
			var template := """@tool
extends Node

const TEST_DIRS = [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/performance",
	"res://tests/mobile"
]

func discover_tests() -> Array[String]:
	var tests: Array[String] = []
	for dir in TEST_DIRS:
		tests.append_array(_scan_directory(dir))
	return tests

func _scan_directory(path: String) -> Array[String]:
	var tests: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.begins_with("test_") and file_name.ends_with(".gd"):
					tests.append(path.path_join(file_name))
			file_name = dir.get_next()
	return tests
"""
			file.store_string(template)
			file.close()

func _create_test_generator() -> void:
	var path := "res://tests/fixtures/test_generator.gd"
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			print("Creating test generator: ", path)
			var template := """@tool
extends EditorScript

const TEST_TEMPLATE = '''@tool
extends BaseTest

# Optional - Enable performance monitoring
func before_all() -> void:
	super.before_all()
	# _performance_monitoring = true

func before_each() -> void:
	super.before_each()
	# Initialize test resources here

func after_each() -> void:
	# Clean up test resources here
	super.after_each()

func test_example() -> void:
	# Arrange
	var test_value := 42
	
	# Act
	var result := test_value * 2
	
	# Assert
	assert_eq(result, 84, "Multiplication should work")
'''

func _run() -> void:
	var dialog := EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.current_dir = "res://tests"
	dialog.add_filter("*.gd", "GDScript")
	
	dialog.file_selected.connect(func(path: String):
		if not path.begins_with("test_"):
			path = path.get_base_dir().path_join("test_" + path.get_file())
		if not path.ends_with(".gd"):
			path += ".gd"
		
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(TEST_TEMPLATE)
			file.close()
			print("Created test file: ", path)
		dialog.queue_free()
	)
	
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))
"""
			file.store_string(template)
			file.close()

func _create_example_tests() -> void:
	var examples := {
		"unit": """@tool
extends BaseTest

func test_basic_math() -> void:
	assert_eq(2 + 2, 4, "Basic addition should work")
	assert_eq(10 - 5, 5, "Basic subtraction should work")
""",
		"integration": """@tool
extends BaseTest

func test_system_interaction() -> void:
	var system_a := Node.new()
	var system_b := Node.new()
	add_child(system_a)
	add_child(system_b)
	
	assert_true(system_a.is_inside_tree(), "System A should be in tree")
	assert_true(system_b.is_inside_tree(), "System B should be in tree")
""",
		"performance": """@tool
extends BaseTest

func before_all() -> void:
	super.before_all()
	_performance_monitoring = true

func test_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	# Simulate work
	for i in range(1000):
		var _temp := Vector2(i, i).normalized()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_less(duration, 100, "Operation should complete within 100ms")
"""
	}
	
	for type in examples:
		var path := "res://tests/%s/test_example_%s.gd" % [type, type]
		if not FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file:
				print("Creating example %s test: %s" % [type, path])
				file.store_string(examples[type])
				file.close()

func _discover_tests() -> void:
	var discovery_script: Node = load("res://tests/fixtures/test_discovery.gd").new()
	var tests: Array[String] = discovery_script.discover_tests()
	discovery_script.free()
	
	print("\nDiscovered Tests:")
	for test in tests:
		print("- ", test)
	
	# Update config with discovered tests
	var config := DEFAULT_CONFIG.duplicate()
	config.tests = tests
	
	var config_file := FileAccess.open("res://tests/gut_config.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(config, "  "))
		config_file.close()
