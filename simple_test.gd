## Simple test runner for basic validation
extends SceneTree

func _init():
	print("=== FIVE PARSECS DATA ARCHITECTURE BASIC TESTING ===")
	
	# Phase 1: Infrastructure Validation
	execute_phase_1()
	
	# Exit
	quit()

func execute_phase_1():
	print("\n=== PHASE 1: Infrastructure Validation ===")
	
	# Test autoload accessibility
	print("Testing autoload accessibility...")
	
	if DataManager != null:
		print("✓ DataManager autoload accessible")
	else:
		print("✗ DataManager autoload NOT accessible")
		return
	
	if GlobalEnums != null:
		print("✓ GlobalEnums autoload accessible")
	else:
		print("✗ GlobalEnums autoload NOT accessible")
		return
		
	# Test basic DataManager functionality
	print("\nTesting DataManager initialization...")
	var start_time = Time.get_ticks_msec()
	var init_result = DataManager.initialize_data_system()
	var end_time = Time.get_ticks_msec()
	var load_time = end_time - start_time
	
	if init_result:
		print("✓ DataManager initialization: SUCCESS")
		print("✓ Load time: %d ms" % load_time)
		
		if load_time < 1000:
			print("✓ Performance target (<1000ms): PASS")
		else:
			print("⚠ Performance target (<1000ms): FAIL")
	else:
		print("✗ DataManager initialization: FAILED")
		return
	
	# Test basic data access
	print("\nTesting basic data access...")
	var human_data = DataManager.get_origin_data("HUMAN")
	if not human_data.is_empty():
		print("✓ Origin data access: SUCCESS")
		print("  Human stats: %s" % human_data.get("base_stats", {}))
	else:
		print("✗ Origin data access: FAILED")
	
	var military_data = DataManager.get_background_data("military") 
	if not military_data.is_empty():
		print("✓ Background data access: SUCCESS")
		print("  Military bonuses: %s" % military_data.get("stat_bonuses", {}))
	else:
		print("✗ Background data access: FAILED")
	
	print("\nPhase 1 completed successfully!")