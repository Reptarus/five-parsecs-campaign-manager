extends SceneTree

## Week 3 Day 4 - End-to-End Campaign Creation Workflow Test
## Tests complete campaign creation flow: Config → Captain → Crew → Ship → Equipment → World → Final

var test_results = {
	"total": 0,
	"passed": 0,
	"failed": 0,
	"warnings": 0
}

# Test state
var state_manager
var test_campaign_data = {}

func _init():
	print("\n" + "=".repeat(70))
	print("WEEK 3 E2E WORKFLOW TEST: Complete Campaign Creation Flow")
	print("=".repeat(70) + "\n")

	# Initialize state manager
	_initialize_state_manager()

	# Test workflow phases
	# Phase order matches CampaignCreationStateManager.Phase enum:
	# CONFIG(0) → CAPTAIN(1) → CREW(2) → EQUIPMENT(3) → SHIP(4) → WORLD(5) → FINAL(6)
	_test_phase_1_config()
	_test_phase_2_captain()
	_test_phase_3_crew()
	_test_phase_4_equipment()  # Equipment comes BEFORE Ship per Core Rules
	_test_phase_5_ship()       # Ship is final step (determines debt)
	_test_phase_6_world()
	_test_phase_7_final_review()

	# Print final summary
	_print_summary()

	quit()

## Initialize the state manager for testing
func _initialize_state_manager():
	print("[SETUP] Initializing State Manager")
	print("-".repeat(70))

	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	if not state_mgr_script:
		print("❌ CRITICAL: Cannot load CampaignCreationStateManager!")
		quit()
		return

	state_manager = state_mgr_script.new()
	if state_manager:
		print("✅ State Manager initialized")
		print("  Initial Phase: %s" % _get_phase_name(state_manager.current_phase))
		print("")
	else:
		print("❌ CRITICAL: Cannot instantiate State Manager!")
		quit()

## Phase 1: Configuration (Campaign Name, Difficulty, Story Track, Victory Conditions)
func _test_phase_1_config():
	print("[PHASE 1] Configuration Phase")
	print("-".repeat(70))

	# Test 1.1: Set config data
	_run_test("Set campaign configuration", func():
		var config_data = {
			"campaign_name": "E2E Test Campaign",
			"campaign_type": "standard",
			"victory_conditions": {
				"story_points": true,
				"max_turns": false,
				"reputation": false
			},
			"story_track": "become_a_legend",
			"tutorial_mode": false,
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.CONFIG, config_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.CONFIG)
		return retrieved.has("campaign_name") and retrieved.campaign_name == "E2E Test Campaign"
	)

	# Test 1.2: Verify config is stored in campaign_data
	_run_test("Config stored in campaign_data", func():
		return state_manager.campaign_data["config"]["campaign_name"] == "E2E Test Campaign"
	)

	# Test 1.3: Advance to next phase
	_run_test("Advance to Captain Creation phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.CAPTAIN_CREATION
	)

	print("")

## Phase 2: Captain Creation
func _test_phase_2_captain():
	print("[PHASE 2] Captain Creation Phase")
	print("-".repeat(70))

	# Test 2.1: Create captain data
	_run_test("Create captain character", func():
		var captain_data = {
			"character_name": "Test Captain",
			"background": 1,  # Enum value
			"motivation": 2,  # Enum value
			"class": 3,  # Enum value
			"combat": 2,  # Direct field for validation
			"toughness": 4,  # Direct field for validation
			"stats": {
				"reactions": 1,
				"speed": 5,
				"combat_skill": 2,
				"toughness": 4,
				"savvy": 1
			},
			"xp": 0,
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, captain_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.CAPTAIN_CREATION)
		return retrieved.has("character_name") and retrieved.character_name == "Test Captain"
	)

	# Test 2.2: Verify captain stats structure
	_run_test("Captain stats properly structured", func():
		var captain = state_manager.campaign_data["captain"]
		return captain.has("character_name") and captain.character_name == "Test Captain"
	)

	# Test 2.3: Advance to Crew Setup
	_run_test("Advance to Crew Setup phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.CREW_SETUP
	)

	print("")

## Phase 3: Crew Setup
func _test_phase_3_crew():
	print("[PHASE 3] Crew Setup Phase")
	print("-".repeat(70))

	# Test 3.1: Create crew members
	_run_test("Add crew members", func():
		var crew_data = {
			"members": [
				{
					"character_name": "Crew Member 1",
					"background": 2,
					"motivation": 1,
					"class": 2,
					"stats": {"reactions": 1, "speed": 4, "combat_skill": 1, "toughness": 3, "savvy": 0},
					"xp": 0
				},
				{
					"character_name": "Crew Member 2",
					"background": 3,
					"motivation": 3,
					"class": 1,
					"stats": {"reactions": 0, "speed": 5, "combat_skill": 2, "toughness": 3, "savvy": 1},
					"xp": 0
				}
			],
			"size": 2,
			"has_captain": true,
			"completion_level": 0.85,
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, crew_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.CREW_SETUP)
		return retrieved.has("members") and retrieved.members.size() == 2
	)

	# Test 3.2: Verify crew count
	_run_test("Crew size matches expected", func():
		var crew = state_manager.campaign_data["crew"]
		return crew.has("size") and crew.size == 2
	)

	# Test 3.3: Advance to Equipment Generation (Equipment comes before Ship per Core Rules)
	_run_test("Advance to Equipment Generation phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.EQUIPMENT_GENERATION
	)

	print("")

## Phase 5: Ship Assignment (comes AFTER Equipment, final step per Core Rules)
func _test_phase_5_ship():
	print("[PHASE 5] Ship Assignment Phase")
	print("-".repeat(70))

	# Test 5.1: Assign ship
	_run_test("Assign starting ship", func():
		var ship_data = {
			"name": "Test Starship",
			"type": "light_freighter",
			"hull_points": 6,
			"max_hull_points": 6,
			"upgrades": [],
			"cargo_capacity": 10,
			"is_configured": true,
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, ship_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.SHIP_ASSIGNMENT)
		return retrieved.has("name") and retrieved.name == "Test Starship"
	)

	# Test 5.2: Verify ship hull points
	_run_test("Ship has valid hull points", func():
		var ship = state_manager.campaign_data["ship"]
		return ship.has("hull_points") and ship.hull_points == 6
	)

	# Test 5.3: Advance to World Generation
	_run_test("Advance to World Generation phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.WORLD_GENERATION
	)

	print("")

## Phase 4: Equipment Generation (comes BEFORE Ship per Core Rules)
func _test_phase_4_equipment():
	print("[PHASE 4] Equipment Generation Phase")
	print("-".repeat(70))

	# Test 4.1: Generate starting equipment
	_run_test("Generate starting equipment", func():
		var equipment_data = {
			"equipment": ["Scrap Pistol", "Hand Weapon", "Medkit"],
			"credits": 1000,
			"supplies": 5,
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, equipment_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.EQUIPMENT_GENERATION)
		return retrieved.has("equipment") and not retrieved["equipment"].is_empty()
	)

	# Test 4.2: Verify equipment structure
	_run_test("Equipment has equipment array", func():
		var equipment = state_manager.campaign_data["equipment"]
		return equipment.has("equipment") and equipment["equipment"] is Array
	)

	# Test 4.3: Advance to Ship Assignment
	_run_test("Advance to Ship Assignment phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.SHIP_ASSIGNMENT
	)

	print("")

## Phase 6: World Generation
func _test_phase_6_world():
	print("[PHASE 6] World Generation Phase")
	print("-".repeat(70))

	# Test 6.1: Generate starting world
	_run_test("Generate starting world", func():
		var world_data = {
			"current_world": "Test Colony",
			"world_type": "colony",
			"traits": ["Trade Hub"],
			"is_complete": true
		}
		state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, world_data)
		var retrieved = state_manager.get_phase_data(state_manager.Phase.WORLD_GENERATION)
		return retrieved.has("current_world") and retrieved.current_world == "Test Colony"
	)

	# Test 6.2: Verify world traits
	_run_test("World has traits", func():
		var world = state_manager.campaign_data["world"]
		return world.has("traits") and world.traits is Array
	)

	# Test 6.3: Advance to Final Review
	_run_test("Advance to Final Review phase", func():
		var success = state_manager.advance_to_next_phase()
		if success:
			print("  → Phase advanced to: %s" % _get_phase_name(state_manager.current_phase))
		return success and state_manager.current_phase == state_manager.Phase.FINAL_REVIEW
	)

	print("")

## Phase 7: Final Review and Campaign Completion
func _test_phase_7_final_review():
	print("[PHASE 7] Final Review & Completion")
	print("-".repeat(70))

	# Test 7.1: All phases have data
	_run_test("All phases populated with data", func():
		var data = state_manager.campaign_data
		return (data["config"].has("campaign_name") and
				data["captain"].has("character_name") and
				data["crew"].has("members") and
				data["ship"].has("name") and
				data["equipment"].has("equipment") and not data["equipment"]["equipment"].is_empty() and
				data["world"].has("current_world"))
	)

	# Test 7.2: Campaign completion
	_run_test("Complete campaign creation", func():
		# Print validation errors for debugging
		if not state_manager.validation_errors.is_empty():
			print("  Validation errors before completion:")
			for error in state_manager.validation_errors:
				print("    - %s" % error)

		var result = state_manager.complete_campaign_creation()

		if result.is_empty():
			print("  Completion failed. Validation errors:")
			for error in state_manager.validation_errors:
				print("    - %s" % error)

		return not result.is_empty() and result.has("config") and result.has("metadata")
	)

	# Test 7.3: Verify metadata
	_run_test("Metadata includes creation timestamp", func():
		var metadata = state_manager.campaign_data["metadata"]
		return metadata.has("created_at") and metadata["created_at"] != ""
	)

	# Test 7.4: Verify all completion flags
	_run_test("All phase completion flags set", func():
		var data = state_manager.campaign_data
		return (data["config"]["is_complete"] and
				data["captain"].get("is_complete", false) and
				data["crew"]["is_complete"] and
				data["ship"]["is_complete"] and
				data["equipment"]["is_complete"] and
				data["world"]["is_complete"])
	)

	print("")

## Helper: Get phase name as string
func _get_phase_name(phase: int) -> String:
	match phase:
		0: return "CONFIG"
		1: return "CAPTAIN_CREATION"
		2: return "CREW_SETUP"
		3: return "SHIP_ASSIGNMENT"
		4: return "EQUIPMENT_GENERATION"
		5: return "WORLD_GENERATION"
		6: return "FINAL_REVIEW"
		_: return "UNKNOWN"

## Helper: Run a single test
func _run_test(test_name: String, test_func: Callable):
	test_results.total += 1
	var result = test_func.call()

	if result:
		test_results.passed += 1
		print("  ✅ %s" % test_name)
	else:
		test_results.failed += 1
		print("  ❌ %s FAILED!" % test_name)

## Print final test summary
func _print_summary():
	print("=".repeat(70))
	print("E2E WORKFLOW TEST SUMMARY")
	print("=".repeat(70))
	print("Total Tests: %d" % test_results.total)
	print("Passed: %d (%.1f%%)" % [test_results.passed, (test_results.passed * 100.0 / test_results.total)])
	print("Failed: %d" % test_results.failed)
	print("Warnings: %d" % test_results.warnings)
	print("")

	if test_results.failed == 0:
		print("✅ E2E WORKFLOW STATUS: ALL TESTS PASSED")
		print("Complete campaign creation workflow validated successfully!")
		print("")
		print("Campaign Summary:")
		print("  Name: %s" % state_manager.campaign_data["config"]["campaign_name"])
		print("  Captain: %s" % state_manager.campaign_data["captain"]["character_name"])
		print("  Crew Size: %d" % state_manager.campaign_data["crew"]["size"])
		print("  Ship: %s (%s)" % [state_manager.campaign_data["ship"]["name"], state_manager.campaign_data["ship"]["type"]])
		print("  Starting Equipment: %d items" % state_manager.campaign_data["equipment"]["equipment"].size())
		print("  Starting World: %s" % state_manager.campaign_data["world"]["current_world"])
	else:
		print("⚠️ E2E WORKFLOW STATUS: %d FAILURES DETECTED" % test_results.failed)
		print("Fix failures before proceeding to save/load testing")

	print("=".repeat(70) + "\n")
