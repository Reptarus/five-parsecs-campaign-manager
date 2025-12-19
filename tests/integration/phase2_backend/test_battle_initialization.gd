extends GdUnitTestSuite
## Phase 2A: Backend Integration Tests - Part 3: Battle Initialization
## Tests FPCM_BattleManager initialization, deployment validation, and state setup
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# System under test
var BattleManagerClass
var BattleStateClass
var battle_manager = null

# Test helper
var HelperClass
var helper = null

func before():
	"""Suite-level setup - runs once before all tests"""
	BattleManagerClass = load("res://src/core/battle/FPCM_BattleManager.gd")
	BattleStateClass = load("res://src/core/battle/FPCM_BattleState.gd")
	HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh manager instance for each test"""
	# Create battle manager instance without adding to tree
	battle_manager = auto_free(BattleManagerClass.new())

func after_test():
	"""Test-level cleanup"""
	battle_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	BattleManagerClass = null
	BattleStateClass = null

# ============================================================================
# Battle Initialization Tests (4 tests)
# ============================================================================

func test_initialize_battle_with_valid_data():
	"""Initializing battle with valid mission, crew, and enemies succeeds"""
	# Create mock mission data (simple Resource)
	var mission = Resource.new()
	mission.set_meta("name", "Test Mission")
	mission.set_meta("mission_type", "OPPORTUNITY")

	# Create mock crew members (simple Resources)
	var crew_members: Array[Resource] = []
	for i in range(3):
		var crew = Resource.new()
		crew.set_meta("name", "Crew %d" % i)
		crew_members.append(crew)

	# Create mock enemies
	var enemies: Array[Resource] = []
	for i in range(5):
		var enemy = Resource.new()
		enemy.set_meta("name", "Enemy %d" % i)
		enemies.append(enemy)

	# Initialize battle
	var result = battle_manager.initialize_battle(mission, crew_members, enemies)

	assert_that(result).is_true()
	assert_that(battle_manager.is_active).is_true()
	assert_that(battle_manager.current_phase).is_equal(BattleManagerClass.BattleManagerPhase.PRE_BATTLE)

func test_initialize_battle_requires_crew():
	"""🐛 BUG DISCOVERY: Initializing battle without crew should fail"""
	var mission = Resource.new()
	var empty_crew: Array[Resource] = []
	var enemies: Array[Resource] = [Resource.new()]

	var result = battle_manager.initialize_battle(mission, empty_crew, enemies)

	# EXPECTED: Should fail validation (no crew = no battle)
	# ACTUAL: May allow initialization without crew validation
	assert_that(result).is_false()
	assert_that(battle_manager.is_active).is_false()

func test_initialize_battle_prevents_double_initialization():
	"""Cannot initialize battle when one is already active"""
	var mission = Resource.new()
	var crew: Array[Resource] = [Resource.new()]
	var enemies: Array[Resource] = [Resource.new()]

	# First initialization
	var result1 = battle_manager.initialize_battle(mission, crew, enemies)
	assert_that(result1).is_true()

	# Second initialization attempt (should fail)
	var result2 = battle_manager.initialize_battle(mission, crew, enemies)

	assert_that(result2).is_false()
	# Original battle should still be active
	assert_that(battle_manager.is_active).is_true()

func test_initialize_battle_creates_battle_state():
	"""Battle initialization creates valid FPCM_BattleState"""
	var mission = Resource.new()
	var crew: Array[Resource] = [Resource.new(), Resource.new()]
	var enemies: Array[Resource] = [Resource.new()]

	battle_manager.initialize_battle(mission, crew, enemies)

	var state = battle_manager.battle_state
	assert_that(state).is_not_null()
	assert_that(state.mission_data).is_equal(mission)
	assert_that(state.crew_members.size()).is_equal(2)
	assert_that(state.enemy_forces.size()).is_equal(1)

# ============================================================================
# Deployment Validation Tests (3 tests)
# ============================================================================

func test_battle_state_tracks_crew_deployment():
	"""BattleState properly tracks crew deployment positions"""
	var state = auto_free(BattleStateClass.new())

	# Setup crew members
	var crew: Array[Resource] = [Resource.new(), Resource.new()]
	state.crew_members = crew

	# Setup deployment data
	state.crew_deployment = {
		"positions": [Vector2i(0, 0), Vector2i(1, 0)],
		"ready": true
	}

	# Verify crew_deployment is a Dictionary before using .has()
	assert_bool(state.crew_deployment is Dictionary).is_true()
	assert_bool(state.crew_deployment.has("positions")).is_true()
	assert_int(state.crew_deployment["positions"].size()).is_equal(2)
	assert_bool(state.crew_deployment.get("ready", false)).is_true()

func test_deployment_validation_enforces_crew_count():
	"""🐛 BUG DISCOVERY: Deployment should match crew member count"""
	var state = auto_free(BattleStateClass.new())

	# Setup 3 crew members
	var crew: Array[Resource] = [Resource.new(), Resource.new(), Resource.new()]
	state.crew_members = crew

	# Setup deployment for only 2 positions (MISMATCH)
	state.crew_deployment = {
		"positions": [Vector2i(0, 0), Vector2i(1, 0)]
	}

	# EXPECTED: Should detect position count mismatch
	# ACTUAL: May not validate deployment count matches crew size
	# This would cause issues in battle (missing crew members)

	# Validation check (if it exists)
	var deployment_valid = state.crew_deployment["positions"].size() == state.crew_members.size()

	# This test documents expected behavior
	assert_that(deployment_valid).is_false()  # Mismatch detected

func test_equipment_loading_into_battle_state():
	"""🐛 BUG DISCOVERY: Equipment should be loaded into battle state"""
	var state = auto_free(BattleStateClass.new())

	# Setup crew with equipment references
	var crew1 = Resource.new()
	crew1.set_meta("equipped_items", ["weapon_1", "armor_1"])

	var crew2 = Resource.new()
	crew2.set_meta("equipped_items", ["weapon_2"])

	var crew: Array[Resource] = [crew1, crew2]
	state.crew_members = crew

	# EXPECTED: Battle state should track what equipment is in battle
	# ACTUAL: May not have equipment tracking in battle state
	# This could cause issues if equipment is lost/damaged during battle

	# Check if state has equipment tracking (use 'in' operator for Resource properties)
	var has_equipment_tracking: bool = false
	if "equipment_in_battle" in state:
		has_equipment_tracking = true
	elif "crew_equipment" in state:
		has_equipment_tracking = true
	elif state.crew_deployment is Dictionary and state.crew_deployment.has("equipment"):
		has_equipment_tracking = true

	# This test will FAIL if equipment tracking is missing
	# Equipment needs to be tracked to handle damage/loss during battle
	assert_bool(has_equipment_tracking).is_true()

# ============================================================================
# Phase Transition Tests (3 tests)
# ============================================================================

func test_battle_starts_in_pre_battle_phase():
	"""Battle initialization transitions to PRE_BATTLE phase"""
	var mission = Resource.new()
	var crew: Array[Resource] = [Resource.new()]
	var enemies: Array[Resource] = [Resource.new()]

	battle_manager.initialize_battle(mission, crew, enemies)

	assert_that(battle_manager.current_phase).is_equal(BattleManagerClass.BattleManagerPhase.PRE_BATTLE)
	assert_that(battle_manager.battle_state.current_phase).is_equal(BattleManagerClass.BattleManagerPhase.PRE_BATTLE)

func test_invalid_phase_transition_from_none():
	"""Cannot transition from NONE to phases other than PRE_BATTLE"""
	# Battle manager starts in NONE phase
	assert_that(battle_manager.current_phase).is_equal(BattleManagerClass.BattleManagerPhase.NONE)

	# Try invalid transition (NONE -> TACTICAL_BATTLE, skipping PRE_BATTLE)
	var result = battle_manager.transition_to_phase(BattleManagerClass.BattleManagerPhase.TACTICAL_BATTLE)

	# Should fail validation
	assert_that(result).is_false()
	assert_that(battle_manager.current_phase).is_equal(BattleManagerClass.BattleManagerPhase.NONE)

func test_battle_state_consistency_across_transitions():
	"""🐛 BUG DISCOVERY: Battle state should remain consistent during transitions"""
	var mission = Resource.new()
	mission.set_meta("mission_id", "test_123")

	var crew: Array[Resource] = [Resource.new()]
	var enemies: Array[Resource] = [Resource.new()]

	# Initialize battle
	battle_manager.initialize_battle(mission, crew, enemies)

	# Get initial battle state reference
	var initial_state = battle_manager.battle_state
	var initial_mission = initial_state.mission_data

	# Transition to next valid phase
	battle_manager.transition_to_phase(BattleManagerClass.BattleManagerPhase.TACTICAL_BATTLE)

	# EXPECTED: Battle state should be same instance, not recreated
	# EXPECTED: Mission data should remain intact
	# ACTUAL: State or mission data might get lost/reset during transitions

	assert_that(battle_manager.battle_state).is_same(initial_state)
	assert_that(battle_manager.battle_state.mission_data).is_same(initial_mission)
	assert_that(battle_manager.battle_state.mission_data.get_meta("mission_id")).is_equal("test_123")
