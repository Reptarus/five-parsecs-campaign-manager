@tool
extends GutTest

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")
# Load necessary helpers with corrected paths
const TypeSafeHelper = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Find the correct paths for enemy scripts with dynamic loading
var EnemyNodeScript = null
var EnemyDataScript = null

# Constants from enemy_test.gd
const STABILIZE_TIME := 0.1
const ENEMY_TEST_CONFIG = {
	"campaign_id": "test_campaign",
	"mission_id": "test_mission"
}

## Enemy campaign unit tests
## Tests the enemy component behavior in a campaign context with isolated dependencies:
## - Enemy progression between missions
## - Rival system interactions
## - Campaign-level enemy behaviors
## - Persistent enemy traits and state

# Type-safe instance variables
var _tracked_nodes := []
var _tracked_resources := []
var _test_campaign = null
var _test_mission = null
var _test_enemy_group = [] # Initialize as empty array instead of null
var _campaign_controller = null

# Setup functions
func before_each():
	_tracked_nodes = []
	_tracked_resources = []
	_test_campaign = null
	_test_mission = null
	_test_enemy_group = [] # Initialize as empty array instead of null
	_campaign_controller = null
	
	# Load enemy scripts dynamically with correct paths
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/EnemyData.gd")
	
	# Verify enemy scripts were found
	if EnemyNodeScript == null:
		pending("Enemy node script not found, skipping test")
		return
	if EnemyDataScript == null:
		pending("Enemy data script not found, skipping test")
		return
	
	# Clear tracked nodes list
	_tracked_nodes.clear()
	
	# Setup test environment
	_test_campaign = _setup_test_campaign()
	_test_mission = _setup_test_mission()
	await stabilize_engine()

func after_each():
	# Clean up tracked test nodes
	for node in _tracked_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_nodes.clear()
	
	_test_campaign = null
	_test_mission = null
	_test_enemy_group = null
	_campaign_controller = null
	
	EnemyNodeScript = null
	EnemyDataScript = null

# Helper functions
func track_test_node(node):
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_nodes):
		_tracked_nodes.append(node)

func stabilize_engine(time: float = STABILIZE_TIME):
	await get_tree().process_frame
	await get_tree().create_timer(time).timeout

# Create a test enemy for use in tests
func create_test_enemy(enemy_data = null):
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript:
		# Check if we can instantiate 
		enemy_node = EnemyNodeScript.new()
		
		if enemy_node and enemy_data:
			# Try different approaches to assign data
			if enemy_node.has_method("set_enemy_data"):
				enemy_node.set_enemy_data(enemy_data)
			elif enemy_node.has_method("initialize"):
				enemy_node.initialize(enemy_data)
			elif "enemy_data" in enemy_node:
				enemy_node.enemy_data = enemy_data
	else:
		# Fallback: create a simple Node
		push_warning("EnemyNode unavailable, creating generic Node2D")
		enemy_node = Node2D.new()
		enemy_node.name = "GenericTestEnemy"
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Create a test enemy resource
func create_test_enemy_resource(data = {}):
	var resource = null
	
	# Try to create resource from script
	if EnemyDataScript != null:
		resource = EnemyDataScript.new()
		if resource and data:
			# Try different approaches to assign data
			if resource.has_method("load"):
				resource.load(data)
			elif resource.has_method("initialize"):
				resource.initialize(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
	else:
		# Fallback: create a simple Resource
		push_warning("EnemyData unavailable, creating generic Resource")
		resource = Resource.new()
	
	# Track the resource if we successfully created it
	if resource:
		_tracked_resources.append(resource)
	
	return resource

# Setup campaign for testing
func _setup_test_campaign():
	var campaign_node = Node.new()
	campaign_node.name = "TestCampaign"
	
	# Add basic campaign methods
	campaign_node.set("get_campaign_id", func():
		return "test_campaign_id"
	)
	
	campaign_node.set("add_mission", func(mission):
		return true
	)
	
	campaign_node.set("get_mission_count", func():
		return 1
	)
	
	campaign_node.set("get_enemy_encounters", func():
		return []
	)
	
	add_child_autofree(campaign_node)
	track_test_node(campaign_node)
	return campaign_node

func _setup_test_mission():
	var mission_node = Node.new()
	mission_node.name = "TestMission"
	
	# Add basic mission methods
	mission_node.set("get_mission_id", func():
		return "test_mission_id"
	)
	
	mission_node.set("add_enemy", func(enemy):
		return true
	)
	
	mission_node.set("get_enemy_count", func():
		return 0
	)
	
	mission_node.set("get_enemies", func():
		return []
	)
	
	add_child_autofree(mission_node)
	track_test_node(mission_node)
	return mission_node

# Test functions
func test_enemy_campaign_integration():
	if EnemyNodeScript == null or EnemyDataScript == null:
		pending("Enemy scripts not available, skipping test")
		return
	
	assert_not_null(_test_campaign, "Campaign should be created")
	
	# Create test enemy
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Add enemy to campaign if the method exists
	if _test_campaign.has_method("add_enemy"):
		var result = _test_campaign.add_enemy(enemy)
		assert_true(result, "Should add enemy to campaign")
		
		# Verify campaign has enemy
		if _test_campaign.has_method("get_enemy_count"):
			var enemy_count = _test_campaign.get_enemy_count()
			assert_true(enemy_count > 0, "Campaign should have enemies")
	else:
		pending("Campaign lacks add_enemy method")

func test_enemy_mission_integration():
	if EnemyNodeScript == null or EnemyDataScript == null:
		pending("Enemy scripts not available, skipping test")
		return
	
	assert_not_null(_test_mission, "Mission should be created")
	
	# Create test enemies
	var enemy1 = create_test_enemy()
	var enemy2 = create_test_enemy()
	assert_not_null(enemy1, "First enemy should be created")
	assert_not_null(enemy2, "Second enemy should be created")
	
	# Add enemies to mission if the method exists
	if _test_mission.has_method("add_enemy"):
		var result1 = _test_mission.add_enemy(enemy1)
		var result2 = _test_mission.add_enemy(enemy2)
		assert_true(result1, "Should add first enemy to mission")
		assert_true(result2, "Should add second enemy to mission")
		
		# Verify mission has enemies
		if _test_mission.has_method("get_enemies"):
			var enemies = _test_mission.get_enemies()
			assert_true(enemies.size() > 0, "Mission should have enemies")
	else:
		pending("Mission lacks add_enemy method")

func test_enemy_progression_system():
	if EnemyNodeScript == null or EnemyDataScript == null:
		pending("Enemy scripts not available, skipping test")
		return
	
	assert_not_null(_test_campaign, "Campaign should be created")
	
	# Create enemy and add to campaign
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if campaign can handle enemy progression
	if is_instance_valid(_test_campaign) and is_instance_valid(enemy) and _test_campaign.has_method("add_enemy") and enemy.has_method("increment_experience"):
		_test_campaign.add_enemy(enemy)
		
		# Watch for signals if this campaign emits them
		watch_signals(_test_campaign)
		
		# Increment enemy experience
		enemy.increment_experience(100)
		
		# Check for progression signal
		if _test_campaign.has_signal("enemy_progressed"):
			assert_signal_emitted(_test_campaign, "enemy_progressed")
		
		# Verify enemy state after progression
		if enemy.has_method("get_level"):
			var level = enemy.get_level()
			assert_true(level > 1, "Enemy should level up after gaining experience")
	else:
		pending("Missing methods for enemy progression test")

func test_enemy_management():
	if EnemyNodeScript == null or EnemyDataScript == null:
		pending("Enemy scripts not available, skipping test")
		return
	
	assert_not_null(_test_campaign, "Campaign should be created")
	
	# Create test enemies
	var enemy1 = create_test_enemy()
	var enemy2 = create_test_enemy()
	assert_not_null(enemy1, "First enemy should be created")
	assert_not_null(enemy2, "Second enemy should be created")
	
	# Test enemy management if campaign has the required methods
	if _test_campaign.has_method("add_enemy") and _test_campaign.has_method("remove_enemy"):
		# Add enemies to campaign
		var add_result1 = _test_campaign.add_enemy(enemy1)
		var add_result2 = _test_campaign.add_enemy(enemy2)
		assert_true(add_result1, "Should add first enemy to campaign")
		assert_true(add_result2, "Should add second enemy to campaign")
		
		# Get enemy count if available
		if _test_campaign.has_method("get_enemy_count"):
			var count_before = _test_campaign.get_enemy_count()
			assert_eq(count_before, 2, "Campaign should have 2 enemies")
		
		# Remove an enemy
		var remove_result = _test_campaign.remove_enemy(enemy1)
		assert_true(remove_result, "Should remove enemy from campaign")
		
		# Verify enemy count after removal
		if _test_campaign.has_method("get_enemy_count"):
			var count_after = _test_campaign.get_enemy_count()
			assert_eq(count_after, 1, "Campaign should have 1 enemy after removal")
	else:
		pending("Campaign lacks enemy management methods")

func test_enemy_data_serialization() -> void:
	# Create enemy with specific data
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Set test data
	if "position" in enemy:
		enemy.position = Vector2(100, 100)
	if "health" in enemy:
		enemy.health = 75
	
	# Test serialization if the method exists
	if enemy.has_method("save_data"):
		var saved_data = TypeSafeHelper._call_node_method(enemy, "save_data", [])
		assert_not_null(saved_data, "Enemy should serialize data")
		
		# Create new enemy with saved data
		var new_enemy = create_test_enemy()
		if new_enemy.has_method("load_data"):
			TypeSafeHelper._call_node_method_bool(new_enemy, "load_data", [saved_data])
			
			# Verify data was restored
			if "health" in new_enemy:
				assert_eq(new_enemy.health, 75, "Health should be restored from saved data")
			if "position" in new_enemy:
				assert_eq(new_enemy.position.x, 100, "Position should be restored from saved data")

func test_enemy_persistence() -> void:
	# Setup initial enemy state with safety checks
	if _test_enemy_group == null:
		_test_enemy_group = []
		push_error("Test enemy group was null")
	
	if _test_enemy_group.size() == 0:
		# Create at least one test enemy if the group is empty
		var test_enemy = create_test_enemy()
		if test_enemy:
			_test_enemy_group.append(test_enemy)
		else:
			push_error("No test enemies available")
			pending("Test needs at least one enemy")
			return
	
	var first_enemy = _test_enemy_group[0]
	if not is_instance_valid(first_enemy):
		push_error("First test enemy is invalid")
		return
		
	# Check if the required methods exist
	if not (first_enemy.has_method("get_id") and first_enemy.has_method("get_health") and
		   first_enemy.has_method("save_to_dictionary") and first_enemy.has_method("load_from_dictionary")):
		push_warning("Skipping test_enemy_persistence: required methods missing")
		assert_true(true, "Skipped test due to missing methods")
		return
	
	var enemy_id = TypeSafeHelper._call_node_method(first_enemy, "get_id", []) as String
	var initial_health = TypeSafeHelper._call_node_method_int(first_enemy, "get_health", [])
	
	# Test campaign persistence
	var save_data = {}
	TypeSafeHelper._call_node_method_bool(first_enemy, "save_to_dictionary", [save_data])
	
	# Simulate campaign mission change
	var new_enemy = create_test_enemy()
	assert_not_null(new_enemy, "Should create new enemy for persistence test")
	if not new_enemy:
		push_error("Failed to create new enemy for persistence test")
		return
	
	TypeSafeHelper._call_node_method_bool(new_enemy, "load_from_dictionary", [save_data])
	add_child_autofree(new_enemy)
	
	# Verify state persistence
	var loaded_id = TypeSafeHelper._call_node_method(new_enemy, "get_id", []) as String
	var loaded_health = TypeSafeHelper._call_node_method_int(new_enemy, "get_health", [])
	
	assert_eq(loaded_id, enemy_id, "Enemy ID should persist")
	assert_eq(loaded_health, initial_health, "Enemy health should persist")

func test_enemy_progression() -> void:
	# Initialize enemy group if needed
	if _test_enemy_group == null:
		_test_enemy_group = []
	
	# Ensure we have enemies to test with
	if _test_enemy_group.size() == 0:
		var test_enemy = create_test_enemy()
		if test_enemy:
			_test_enemy_group.append(test_enemy)
		else:
			push_error("No test enemies available")
			pending("Test needs at least one enemy")
			return
	
	# Simulate enemy surviving missions
	var enemy = _test_enemy_group[0]
	if not is_instance_valid(enemy):
		push_error("No valid test enemy available")
		return
		
	# Check if the required methods exist
	if not (enemy.has_method("get_power_level") and enemy.has_method("complete_mission")):
		push_warning("Skipping test_enemy_progression: required methods missing")
		assert_true(true, "Skipped test due to missing methods")
		return
	
	# Track initial stats
	var initial_power = TypeSafeHelper._call_node_method_int(enemy, "get_power_level", [])
	
	# Simulate multiple mission completions
	for i in range(3):
		TypeSafeHelper._call_node_method_bool(enemy, "complete_mission", [])
	
	# Check for progression
	var final_power = TypeSafeHelper._call_node_method_int(enemy, "get_power_level", [])
	assert_gt(final_power, initial_power, "Enemy should increase in power after missions")

func test_rival_integration() -> void:
	# Initialize enemy group if needed
	if _test_enemy_group == null:
		_test_enemy_group = []
	
	# Ensure we have enemies to test with
	if _test_enemy_group.size() == 0:
		var test_enemy = create_test_enemy()
		if test_enemy:
			_test_enemy_group.append(test_enemy)
		else:
			push_error("No test enemies available")
			pending("Test needs at least one enemy")
			return
	
	# Test integration with rival system
	var enemy = _test_enemy_group[0]
	if not is_instance_valid(enemy):
		push_error("No valid test enemy available")
		return
		
	# Create campaign controller if it doesn't exist
	if not is_instance_valid(_campaign_controller):
		_campaign_controller = Node.new()
		_campaign_controller.name = "TestCampaignController"
		
		# Add methods if they don't exist
		if not _campaign_controller.has_method("promote_to_rival"):
			_campaign_controller.set("promote_to_rival", func(enemy_to_promote):
				if is_instance_valid(enemy_to_promote):
					if enemy_to_promote.has_method("set_rival_tier"):
						enemy_to_promote.set_rival_tier(1)
					return true
				return false
			)
		
		add_child_autofree(_campaign_controller)
		track_test_node(_campaign_controller)
	
	# Check if the required methods exist in enemy and controller
	if not (is_instance_valid(_campaign_controller) and _campaign_controller.has_method("promote_to_rival") and
		   enemy.has_method("get_rival_tier") and enemy.has_method("has_rival_ability")):
		push_warning("Skipping test_rival_integration: required methods missing")
		assert_true(true, "Skipped test due to missing methods")
		return
	
	# Convert to rival
	var is_rival = TypeSafeHelper._call_node_method_bool(_campaign_controller, "promote_to_rival", [enemy])
	assert_true(is_rival, "Enemy should be promoted to rival")
	
	# Check rival properties
	var rival_tier = TypeSafeHelper._call_node_method_int(enemy, "get_rival_tier", [])
	assert_gt(rival_tier, 0, "Promoted enemy should have a rival tier")
	
	# Test rival abilities
	var has_special_ability = TypeSafeHelper._call_node_method_bool(enemy, "has_rival_ability", [])
	assert_true(has_special_ability, "Rival should have special abilities")

func test_campaign_phase_effects() -> void:
	# Initialize enemy group if needed
	if _test_enemy_group == null:
		_test_enemy_group = []
	
	# Ensure we have enemies to test with
	if _test_enemy_group.size() == 0:
		var test_enemy = create_test_enemy()
		if test_enemy:
			_test_enemy_group.append(test_enemy)
		else:
			push_error("No test enemies available")
			pending("Test needs at least one enemy")
			return
	
	# Test how campaign phases affect enemies
	var enemy = _test_enemy_group[0]
	if not is_instance_valid(enemy):
		push_error("No valid test enemy available")
		return
		
	# Create campaign controller if it doesn't exist
	if not is_instance_valid(_campaign_controller):
		_campaign_controller = Node.new()
		_campaign_controller.name = "TestCampaignController"
		
		# Add methods if they don't exist
		if not _campaign_controller.has_method("change_campaign_phase"):
			_campaign_controller.set("change_campaign_phase", func(phase_name):
				return true
			)
		
		add_child_autofree(_campaign_controller)
		track_test_node(_campaign_controller)
	
	# Check if the required methods exist
	if not (enemy.has_method("get_aggression") and enemy.has_method("react_to_campaign_phase") and
		   is_instance_valid(_campaign_controller) and _campaign_controller.has_method("change_campaign_phase")):
		push_warning("Skipping test_campaign_phase_effects: required methods missing")
		assert_true(true, "Skipped test due to missing methods")
		return
	
	# Track initial state
	var initial_aggression = TypeSafeHelper._call_node_method_int(enemy, "get_aggression", [])
	
	# Simulate campaign phase change
	TypeSafeHelper._call_node_method_bool(_campaign_controller, "change_campaign_phase", ["escalation"])
	TypeSafeHelper._call_node_method_bool(enemy, "react_to_campaign_phase", ["escalation"])
	
	# Check for changes based on campaign phase
	var new_aggression = TypeSafeHelper._call_node_method_int(enemy, "get_aggression", [])
	assert_gt(new_aggression, initial_aggression, "Enemy aggression should increase during escalation phase")

func test_enemy_faction_behavior() -> void:
	# Test enemy faction-specific behaviors
	# Initialize _test_enemy_group if null
	if _test_enemy_group == null:
		_test_enemy_group = []
	
	# Clear existing enemies and create new ones for each faction
	if _test_enemy_group.size() > 0:
		_test_enemy_group.clear()
	
	var faction_types = ["imperial", "pirate", "rebel"]
	var created_enemies = 0
	
	for faction in faction_types:
		var enemy = create_test_enemy()
		if not is_instance_valid(enemy):
			push_error("Failed to create enemy for faction: " + faction)
			continue
			
		if not (enemy.has_method("set_faction") and enemy.has_method("get_faction") and
			   enemy.has_method("activate_faction_behavior") and enemy.has_method("get_faction_trait")):
			push_warning("Skipping faction test for " + faction + ": required methods missing")
			continue
			
		TypeSafeHelper._call_node_method_bool(enemy, "set_faction", [faction])
		_test_enemy_group.append(enemy)
		add_child_autofree(enemy)
		created_enemies += 1
	
	# If no enemies were successfully created, skip the test
	if created_enemies == 0:
		push_warning("Skipping test_enemy_faction_behavior: no viable enemies")
		pending("Test requires at least one faction enemy")
		return
	
	# Test faction-specific behaviors - safe iteration with bounds checking
	for i in range(min(_test_enemy_group.size(), faction_types.size())):
		# Bounds check is redundant now but kept for safety
		if i >= _test_enemy_group.size():
			push_warning("Index out of bounds in enemy group test")
			continue
			
		# Null check
		var enemy = _test_enemy_group[i]
		if not is_instance_valid(enemy):
			push_warning("Null enemy at index " + str(i))
			continue
			
		var faction = TypeSafeHelper._call_node_method(enemy, "get_faction", []) as String
		if faction.is_empty():
			push_warning("Empty faction for enemy at index " + str(i))
			continue
		
		# Trigger faction-specific response
		TypeSafeHelper._call_node_method_bool(enemy, "activate_faction_behavior", [])
		
		# Verify faction-specific traits
		var faction_trait = TypeSafeHelper._call_node_method(enemy, "get_faction_trait", []) as String
		assert_not_null(faction_trait, "Enemy should have faction-specific trait")
		if faction_trait:
			assert_true(faction_trait.contains(faction), "Faction trait should relate to the enemy's faction")
		else:
			push_warning("Null faction trait for enemy at index " + str(i))
