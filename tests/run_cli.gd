@tool
extends SceneTree

## Command-line Test Runner
##
## A standalone script that can be run from the command line to execute tests
## Usage: godot --script res://tests/run_cli.gd --test-file res://tests/unit/test_simple_fix.gd

const GutScene: PackedScene = preload("res://addons/gut/GutScene.tscn")
const CleanupHelper = preload("res://tests/cleanup_resources.gd")

var _gut: Node
var _start_time: int
var _specific_test: String = ""
var _specific_test_func: String = ""
var _test_scene: Node = null

func _init():
	print("\n=== Five Parsecs CLI Test Runner ===")
	_parse_arguments()
	
	print("Command-line arguments parsed:")
	print("- Test file: ", _specific_test if not _specific_test.is_empty() else "None")
	print("- Test function: ", _specific_test_func if not _specific_test_func.is_empty() else "None")
	
	_run_tests()
	
	# Allow time for tests to complete before quitting
	await get_root().process_frame
	var timer = Timer.new()
	get_root().add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.start()
	await timer.timeout
	timer.queue_free()
	_clean_up_resources()
	quit()

func _parse_arguments():
	var arguments = OS.get_cmdline_args()
	for i in range(arguments.size()):
		var arg = arguments[i]
		if arg == "--test-file":
			if i + 1 < arguments.size():
				_specific_test = arguments[i + 1]
		elif arg == "--test-func":
			if i + 1 < arguments.size():
				_specific_test_func = arguments[i + 1]

func _run_tests():
	print("\n--- Running Tests ---")
	_start_time = Time.get_ticks_msec()

	# Create test scene
	print("Creating GUT scene...")
	_test_scene = GutScene.instantiate()
	if not _test_scene:
		print("ERROR: Failed to instantiate GUT scene!")
		return
	
	# Find the Gut node
	_gut = _test_scene.get_node("Gut")
	if not _gut:
		print("ERROR: Could not find Gut node in the test scene!")
		return
	
	print("Configuring test environment...")
	
	# Configure directories to test
	if _specific_test.is_empty():
		print("Adding test directories...")
		_gut.add_directory("res://tests/unit")
		_gut.add_directory("res://tests/integration")
	else:
		print("Running specific test: " + _specific_test)
		_gut.add_script(_specific_test)
		
		if not _specific_test_func.is_empty():
			print("Running specific function: " + _specific_test_func)
			_gut.set_unit_test_name(_specific_test_func)
	
	# Connect signals
	if _gut.is_connected("tests_finished", _on_tests_finished):
		_gut.disconnect("tests_finished", _on_tests_finished)
	_gut.connect("tests_finished", _on_tests_finished)
	
	# Add to scene tree and run
	print("Adding GUT to scene tree...")
	get_root().add_child(_test_scene)
	
	print("Starting test execution...")
	_gut.test_scripts()

func _on_tests_finished():
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - _start_time) / 1000.0
	
	print("\n--- Test Run Complete ---")
	print("Duration: %.2f seconds" % duration)
	print("Tests passed: %d" % _gut.get_pass_count())
	print("Tests failed: %d" % _gut.get_fail_count())
	print("Tests pending: %d" % _gut.get_pending_count())
	
	# Report failed tests
	if _gut.get_fail_count() > 0:
		print("\nFailed tests:")
		var failed_tests = []
		for test_script in _gut._test_collector.get_failed_tests():
			failed_tests.append("- " + test_script)
		print("\n".join(failed_tests))
	
	# Summary
	if _gut.get_fail_count() == 0:
		print("\n✅ All tests passed!")
	else:
		print("\n❌ Some tests failed!")

func _clean_up_resources():
	print("\n--- Cleaning up resources ---")
	
	# Manual cleanup without external helpers
	# Since this is a SceneTree itself, we don't need get_tree()
	
	# Clean up GUT test scene
	if _test_scene:
		if is_instance_valid(_test_scene) and _test_scene.is_inside_tree():
			# First clean up any test scenes created by GUT
			if _gut and is_instance_valid(_gut):
				var test_nodes = get_nodes_in_group("gut_test_objects")
				for node in test_nodes:
					if is_instance_valid(node) and node.is_inside_tree():
						node.get_parent().remove_child(node)
						node.queue_free()
				
				# Wait a frame for queue_free to process
				await get_root().process_frame
				
				# Properly disconnect GUT signals
				if _gut.is_connected("tests_finished", _on_tests_finished):
					_gut.disconnect("tests_finished", _on_tests_finished)
					
				# Call cleanup methods if they exist
				if _gut.has_method("cleanup"):
					_gut.cleanup()
				
				# GUT might have created any temp resources to clean up
				if _gut.has_method("get_temp_directory"):
					var temp_dir = _gut.get_temp_directory()
					if temp_dir and DirAccess.dir_exists_absolute(temp_dir):
						var dir = DirAccess.open(temp_dir)
						if dir:
							dir.list_dir_begin()
							var file_name = dir.get_next()
							while file_name != "":
								if not dir.current_is_dir():
									dir.remove(file_name)
								file_name = dir.get_next()
							dir.list_dir_end()
			
			# Remove from tree and free
			_test_scene.get_parent().remove_child(_test_scene)
			_test_scene.queue_free()
			
			# Force garbage collection
			await get_root().process_frame
	
	print("Resource cleanup complete")