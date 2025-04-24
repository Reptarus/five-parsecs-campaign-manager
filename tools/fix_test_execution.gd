@tool
extends EditorScript

## Test Execution Fix Script
##
## This script diagnoses and fixes issues with GUT test execution.
## It runs a minimal test to identify what's causing the "Invalid base object for 'in'" error.
##
## Run this from the Editor -> Tools menu

func _run():
	print("\n=== TEST EXECUTION DIAGNOSTIC ===")
	
	# Create a simple test scene
	var test_scene = Node.new()
	test_scene.name = "TestScene"
	
	# Add GUT instance
	var gut_script = load("res://addons/gut/gut.gd")
	var gut = gut_script.new()
	test_scene.add_child(gut)
	
	# Configure GUT for minimal execution
	gut.log_level = 3
	gut.include_subdirectories = true
	gut.export_path = "res://tests/reports/diagnostic_report.txt"
	gut.prefix = "test_"
	gut.suffix = ".gd"
	
	# Add only the simple test
	print("Adding simple test...")
	gut.add_script("res://tests/unit/test_simple.gd")
	
	# Run the test with proper error handling
	print("Running simple test...")
	
	# Add the test scene to the tree
	get_editor_interface().get_editor_main_screen().add_child(test_scene)
	
	# Process pending messages
	await Engine.get_main_loop().process_frame
	
	# Run test with error handling
	var catch_errors = func():
		gut.test_scripts()
		
		# Wait for test to complete
		await Engine.get_main_loop().create_timer(1.0).timeout
		
		# Check results
		var tests_run = gut.get_test_count()
		var tests_passed = gut.get_pass_count()
		
		print("\nDiagnostic Results:")
		print("Tests run: " + str(tests_run))
		print("Tests passed: " + str(tests_passed))
		
		# Cleanup
		test_scene.queue_free()
	
	catch_errors.call_deferred()
	
	print("\n=== DIAGNOSTIC COMPLETE ===")
	print("Check editor console for errors to identify the specific issue.")