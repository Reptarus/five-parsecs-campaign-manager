extends Node

var gut = null

func _ready():
	gut = load("res://addons/gut/gut.gd").new()
	add_child(gut)
	
	# Basic settings
	gut.set_should_print_to_console(true)
	gut.set_log_level(2) # Detailed logging
	gut.set_yield_between_tests(true)
	
	# Appearance settings
	gut.set_font("CourierPrime")
	gut.set_font_size(16)
	gut.set_opacity(100)
	
	# Directory settings
	gut.add_directory("res://src/tests")
	gut.set_include_subdirectories(true) # Include unit/ subdirectory
	gut.set_prefix("test_") # Only run files starting with "test_"
	gut.set_suffix(".gd") # Only run .gd files
	
	# Run the tests
	gut.test_scripts()
	
	# Print test results
	var results = gut.get_test_results()
	print("\nTest Results:")
	print("Total Tests: ", results.get_test_count())
	print("Passed: ", results.get_pass_count())
	print("Failed: ", results.get_fail_count())
	print("Errors: ", results.get_error_count())
	print("Pending: ", results.get_pending_count())
	print("Elapsed Time: ", results.get_elapsed_time(), " seconds")
	
	# Export results if there were failures
	if results.get_fail_count() > 0 or results.get_error_count() > 0:
		gut.export_if_tests_failed()
