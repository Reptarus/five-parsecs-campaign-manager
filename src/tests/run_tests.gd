extends SceneTree

const GutRunner = preload("res://addons/gut/gut_cmdln.gd")

func _init() -> void:
	var gut = GutRunner.new()
	add_child(gut)
	
	gut.set_unit_test_name("test_game_state_manager.gd")
	gut.set_unit_test_name("test_character_manager.gd")
	gut.set_unit_test_name("test_resource_system.gd")
	gut.set_unit_test_name("test_battle_state_machine.gd")
	gut.set_unit_test_name("test_campaign_system.gd")
	
	gut.set_should_print_to_console(true)
	gut.set_log_level(GutRunner.LOG_LEVEL_ALL)
	gut.set_yield_between_tests(true)
	gut.set_include_subdirectories(true)
	
	gut.test_scripts()
	
	var results = gut.get_test_results()
	print("\nTest Results:")
	print("Total Tests: ", results.get_test_count())
	print("Passed: ", results.get_pass_count())
	print("Failed: ", results.get_fail_count())
	print("Errors: ", results.get_error_count())
	print("Pending: ", results.get_pending_count())
	print("Elapsed Time: ", results.get_elapsed_time(), " seconds")
	
	quit() 