@tool
extends Node

## Campaign Integration Verification Test
## Tests that all campaign components are properly connected

# Test imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")

var test_results: Array[String] = []

func _ready() -> void:
	print("=== Campaign Integration Test Starting ===")
	call_deferred("run_integration_tests")

func run_integration_tests() -> void:
	"""Run comprehensive integration tests"""
	
	# Test 1: Verify core enums are accessible
	test_global_enums_accessibility()
	
	# Test 2: Test campaign phase manager initialization
	test_campaign_phase_manager_init()
	
	# Test 3: Test phase handler initialization
	test_phase_handlers_init()
	
	# Test 4: Test signal connections
	test_signal_connections()
	
	# Test 5: Test GameStateManager integration
	test_game_state_integration()
	
	print_test_results()

func test_global_enums_accessibility() -> void:
	"""Test that GlobalEnums is accessible and has required enums"""
	var test_name = "GlobalEnums Accessibility"
	
	var GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "integration_test")
	
	if not GameEnums:
		test_results.append("❌ %s: Could not load GlobalEnums" % test_name)
		return
	
	# Check for required enumerations
	var required_enums = [
		"FiveParcsecsCampaignPhase",
		"TravelSubPhase", 
		"WorldSubPhase",
		"PostBattleSubPhase",
		"CrewTaskType",
		"WorldTrait"
	]
	
	for enum_name in required_enums:
		if not enum_name in GameEnums:
			test_results.append("❌ %s: Missing enum %s" % [test_name, enum_name])
			return
	
	test_results.append("✅ %s: All required enums present" % test_name)

func test_campaign_phase_manager_init() -> void:
	"""Test CampaignPhaseManager initialization"""
	var test_name = "CampaignPhaseManager Init"
	
	var CampaignPhaseManager = UniversalResourceLoader.load_script_safe("res://src/core/campaign/CampaignPhaseManager.gd", "integration_test")
	
	if not CampaignPhaseManager:
		test_results.append("❌ %s: Could not load CampaignPhaseManager" % test_name)
		return
	
	var manager_instance = CampaignPhaseManager.new()
	add_child(manager_instance)
	
	await get_tree().process_frame
	
	# Check required methods exist
	var required_methods = [
		"start_new_campaign_turn",
		"start_phase",
		"get_current_phase",
		"get_turn_number"
	]
	
	for method_name in required_methods:
		if not manager_instance.has_method(method_name):
			test_results.append("❌ %s: Missing method %s" % [test_name, method_name])
			manager_instance.queue_free()
			return
	
	manager_instance.queue_free()
	test_results.append("✅ %s: All required methods present" % test_name)

func test_phase_handlers_init() -> void:
	"""Test phase handler initialization"""
	var test_name = "Phase Handlers Init"
	
	var phase_classes = [
		{"name": "TravelPhase", "path": "res://src/core/campaign/phases/TravelPhase.gd"},
		{"name": "WorldPhase", "path": "res://src/core/campaign/phases/WorldPhase.gd"},
		{"name": "PostBattlePhase", "path": "res://src/core/campaign/phases/PostBattlePhase.gd"}
	]
	
	for phase_info in phase_classes:
		var PhaseClass = UniversalResourceLoader.load_script_safe(phase_info.path, "integration_test")
		
		if not PhaseClass:
			test_results.append("❌ %s: Could not load %s" % [test_name, phase_info.name])
			return
		
		var phase_instance = PhaseClass.new()
		add_child(phase_instance)
		
		await get_tree().process_frame
		
		# Check for start method
		var start_method = "start_%s_phase" % phase_info.name.to_lower().replace("phase", "")
		if not phase_instance.has_method(start_method):
			test_results.append("❌ %s: %s missing start method" % [test_name, phase_info.name])
			phase_instance.queue_free()
			return
		
		phase_instance.queue_free()
	
	test_results.append("✅ %s: All phase handlers initialized successfully" % test_name)

func test_signal_connections() -> void:
	"""Test signal connections between components"""
	var test_name = "Signal Connections"
	
	var GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "integration_test")
	if not GameEnums:
		test_results.append("❌ %s: GameEnums not available" % test_name)
		return
	
	# Test signal emission safety
	var test_emitter = Node.new()
	test_emitter.add_user_signal("test_signal", [{"name": "data", "type": TYPE_INT}])
	add_child(test_emitter)
	
	var emission_result = UniversalSignalManager.emit_signal_safe(test_emitter, "test_signal", [42], "integration_test")
	
	test_emitter.queue_free()
	
	if not emission_result:
		test_results.append("❌ %s: Signal emission failed" % test_name)
		return
	
	test_results.append("✅ %s: Signal system working correctly" % test_name)

func test_game_state_integration() -> void:
	"""Test GameStateManager integration"""
	var test_name = "GameState Integration"
	
	var GameStateManager = UniversalResourceLoader.load_script_safe("res://src/core/managers/GameStateManager.gd", "integration_test")
	
	if not GameStateManager:
		test_results.append("❌ %s: Could not load GameStateManager" % test_name)
		return
	
	var manager_instance = GameStateManager.new()
	add_child(manager_instance)
	
	await get_tree().process_frame
	
	# Check required integration methods
	var required_methods = [
		"add_credits",
		"remove_credits", 
		"get_crew_members",
		"get_crew_size",
		"set_campaign_phase",
		"register_manager"
	]
	
	for method_name in required_methods:
		if not manager_instance.has_method(method_name):
			test_results.append("❌ %s: Missing method %s" % [test_name, method_name])
			manager_instance.queue_free()
			return
	
	# Test basic functionality
	manager_instance.set_credits(100)
	if manager_instance.get_credits() != 100:
		test_results.append("❌ %s: Credit system not working" % test_name)
		manager_instance.queue_free()
		return
	
	manager_instance.queue_free()
	test_results.append("✅ %s: All integration methods working" % test_name)

func print_test_results() -> void:
	"""Print comprehensive test results"""
	print("\n=== Campaign Integration Test Results ===")
	
	var passed = 0
	var failed = 0
	
	for result in test_results:
		print(result)
		if result.begins_with("✅"):
			passed += 1
		else:
			failed += 1
	
	print("\n=== Test Summary ===")
	print("✅ Passed: %d" % passed)
	print("❌ Failed: %d" % failed)
	print("📊 Total: %d" % (passed + failed))
	
	if failed == 0:
		print("🎉 ALL INTEGRATION TESTS PASSED! Campaign system is properly connected.")
	else:
		print("⚠️  Some integration tests failed. Review connections above.")
	
	print("=========================================\n")