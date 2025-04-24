@tool
extends GutTest

# Load necessary helpers
const TypeSafeHelper = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd") # Corrected path
const TestCleanupHelper = preload("res://tests/fixtures/helpers/test_cleanup_helper.gd")

# Load enemy scripts with dynamic loading to avoid errors
var EnemyNodeScript = null
var EnemyDataScript = null

# Constants 
const STABILIZE_TIME := 0.2
const ENEMY_TEST_CONFIG = {
	"stabilize_time": 0.2,
	"timeout": 5.0
}

# Type-safe instance variables for tactical testing
var _tactical_manager: Node = null
var _combat_manager: Node = null
var _test_battlefield: Node2D = null # Must be Node2D for 2D positioning
var _tactics_system: Node = null
var _test_squad: Array = []
var _test_objectives: Array = []
var _tracked_nodes: Array = [] # Array to track nodes for cleanup
var _cleanup_helper = null

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")

# Add local implementation of track_test_node to fix linter errors
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_nodes):
		_tracked_nodes.append(node)

func before_each() -> void:
	# Clear tracked nodes
	_tracked_nodes.clear()
	
	# Initialize cleanup helper
	_cleanup_helper = TestCleanupHelper.new()
	
	# Setup tactical test environment
	_tactical_manager = Node.new()
	_tactical_manager.name = "TacticalManager"
	add_child_autofree(_tactical_manager)
	track_test_node(_tactical_manager)
	
	# Add mock methods to tactical manager
	_add_mock_tactical_methods()
	
	_combat_manager = Node.new()
	_combat_manager.name = "CombatManager"
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	# Create a 2D battlefield since we're working with CharacterBody2D enemies
	_test_battlefield = Node2D.new()
	_test_battlefield.name = "TestBattlefield"
	add_child_autofree(_test_battlefield)
	track_test_node(_test_battlefield)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	# Clean up tracked nodes using the helper
	if _cleanup_helper and _cleanup_helper.has_method("cleanup_nodes"):
		_cleanup_helper.cleanup_nodes(_tracked_nodes)
	else:
		# Fallback if helper doesn't work
		for node in _tracked_nodes:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
	
	_tracked_nodes.clear()
	
	# Reset references
	_tactical_manager = null
	_combat_manager = null
	_test_battlefield = null
	_test_squad.clear()
	_test_objectives.clear()
	_cleanup_helper = null

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(time).timeout

# Add mock implementations of tactical methods
func _add_mock_tactical_methods() -> void:
	# Create a script with all required tactical methods
	var script = GDScript.new()
	script.source_code = """extends Node

func set_group_formation(group, formation_data):
	if not group or group.is_empty():
		return false
	
	# Simple formation logic
	var leader = group[0]
	if not leader or not is_instance_valid(leader):
		return false
		
	var spacing = formation_data.get("spacing", 2.0)
	var facing = formation_data.get("facing", Vector2.RIGHT)
	
	# Position group members
	for i in range(1, group.size()):
		if not is_instance_valid(group[i]):
			continue
		var offset = facing.rotated(PI / 4 * i) * spacing * i
		group[i].position = leader.position + offset
	
	return true

func coordinate_group_attack(group, target):
	if not group or group.is_empty() or not target:
		return false
	
	# Assign target to all group members
	for member in group:
		if not is_instance_valid(member):
			continue
		if member.has_method("set_current_target"):
			member.set_current_target(target)
	
	# Emit signal from leader if it has one
	if group[0] and group[0].has_signal("group_attack_coordinated"):
		group[0].emit_signal("group_attack_coordinated")
	
	return true

func move_group_to(group, target_pos):
	if not group or group.is_empty():
		return false
	
	# Simple group movement - for CharacterBody2D nodes
	for member in group:
		if not is_instance_valid(member):
			continue
			
		# Calculate offset from leader to maintain formation
		var offset = member.position - group[0].position
		
		# Set new position
		member.position = target_pos + offset
	
	# Emit signal from leader if it has one
	if group[0] and group[0].has_signal("group_movement_completed"):
		group[0].emit_signal("group_movement_completed")
	
	return true

func assign_group_targets(group, targets):
	if not group or group.is_empty() or not targets or targets.is_empty():
		return false
	
	# Assign targets one-to-one where possible
	for i in range(min(group.size(), targets.size())):
		if not is_instance_valid(group[i]):
			continue
		if group[i].has_method("set_current_target"):
			group[i].set_current_target(targets[i])
	
	return true

func assign_group_cover(group, cover_points):
	if not group or group.is_empty() or not cover_points or cover_points.is_empty():
		return false
	
	# Assign cover points
	for i in range(min(group.size(), cover_points.size())):
		if not is_instance_valid(group[i]):
			continue
		if not "cover_position" in group[i]:
			group[i].set_meta("cover_position", Vector2())
		
		group[i].set_meta("cover_position", cover_points[i])
	
	return true
"""
	script.reload()
	
	# Apply the script to the tactical manager
	_tactical_manager.set_script(script)

# Group Tactical Tests
func test_group_tactical_initialization() -> void:
	pending("Pending until tactical group implementation is complete")
	
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	assert_eq(group.size(), 3, "Tactical group should have correct size")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var leader = group[0]
	assert_not_null(leader, "Leader should be valid")
	
	verify_enemy_complete_state(leader)
	
	if not leader.has_method("is_leader"):
		push_warning("Leader doesn't have is_leader method, skipping test")
		return
		
	assert_true(TypeSafeHelper._call_node_method_bool(leader, "is_leader", [], false), "First enemy should be group leader")
	
	for member in group.slice(1):
		verify_enemy_complete_state(member)
		assert_false(TypeSafeHelper._call_node_method_bool(member, "is_leader", [], false), "Other enemies should not be leaders")

func test_group_formation_tactics() -> void:
	pending("Pending until tactical group formation is complete")

func test_group_combat_coordination() -> void:
	pending("Pending until tactical group combat coordination is complete")

func test_group_movement_tactics() -> void:
	pending("Pending until tactical group movement is complete")

func test_group_target_prioritization() -> void:
	pending("Pending until tactical group targeting is complete")

func test_group_cover_tactics() -> void:
	pending("Pending until tactical group cover usage is complete")

func test_group_behavior_tree() -> void:
	pending("Pending until tactical group behavior trees are complete")

func test_group_leadership_mechanics() -> void:
	pending("Pending until group leadership mechanics are complete")

# Helper Methods
func _create_tactical_group() -> Array:
	var group = []
	
	# Create leader
	var leader = create_test_enemy()
	if leader:
		# Set as leader
		if leader.has_method("set_as_leader"):
			leader.set_as_leader(true)
		else:
			leader.set_meta("is_leader", true)
		
		# Position leader at origin - using global_position since EnemyNode extends CharacterBody2D
		leader.global_position = Vector2.ZERO
		
		# Add to the battlefield
		if _test_battlefield:
			_test_battlefield.add_child(leader)
		
		group.append(leader)
	
	# Add members
	for i in range(2):
		var member = create_test_enemy()
		if member:
			# Set as non-leader
			if member.has_method("set_as_leader"):
				member.set_as_leader(false)
			else:
				member.set_meta("is_leader", false)
			
			# Position relative to leader
			if leader:
				var offset = Vector2(i * 2.0, i * 2.0)
				member.global_position = leader.global_position + offset
			
			# Add to the battlefield
			if _test_battlefield:
				_test_battlefield.add_child(member)
			
			group.append(member)
	
	return group

func _create_target_group() -> Array:
	var targets = []
	
	# Create target enemies
	for i in range(3):
		var target = create_test_enemy()
		if target:
			# Position targets
			target.global_position = Vector2(10 + i * 5, 10 + i * 5)
			
			# Add to the battlefield
			if _test_battlefield:
				_test_battlefield.add_child(target)
				
			targets.append(target)
	
	return targets

func _create_cover_points() -> Array:
	var cover_points = []
	
	# Create mock cover points (just positions)
	for i in range(5):
		var x = 20 + i * 10
		var y = 20 + i * 5
		cover_points.append(Vector2(x, y))
	
	return cover_points

# Verify enemy is in a valid state for tests
func verify_enemy_complete_state(enemy: Node) -> void:
	assert_not_null(enemy, "Enemy should be non-null")
	
	# Check properties
	if enemy.has_method("get_health"):
		assert_gt(enemy.get_health(), 0, "Enemy health should be positive")
	elif enemy.has("health"):
		assert_gt(enemy.health, 0, "Enemy health should be positive")
	else:
		push_warning("Enemy lacks health property, skipping health check")

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> CharacterBody2D:
	# Create an EnemyNode instance
	var enemy_instance = null
	
	if EnemyNodeScript and EnemyNodeScript.can_instantiate():
		enemy_instance = EnemyNodeScript.new()
	else:
		# Fallback to creating a CharacterBody2D with custom script
		enemy_instance = CharacterBody2D.new()
		enemy_instance.name = "TestEnemy_" + str(randi())
		_setup_enemy_script(enemy_instance)
	
	# Track the node for cleanup
	track_test_node(enemy_instance)
	
	# Setup the enemy with data if provided
	if enemy_data and enemy_instance:
		if enemy_instance.has_method("initialize"):
			enemy_instance.initialize(enemy_data)
	
	# Setup navigation agent
	if enemy_instance and not enemy_instance.get_node_or_null("NavigationAgent2D"):
		var nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		enemy_instance.add_child(nav_agent)
	
	# Return the properly typed enemy instance
	return enemy_instance

func _setup_enemy_script(enemy_node: Node) -> void:
	# Create a custom script with proper methods
	var script = GDScript.new()
	script.source_code = """
extends CharacterBody2D

signal health_changed(old_value, new_value)
signal died()
signal turn_started()
signal turn_ended()
signal mission_started()
signal mission_completed()
signal experience_gained(amount)
signal group_attack_coordinated()
signal group_movement_completed()

var health = 100
var max_health = 100
var damage = 10
var armor = 5
var experience = 0
var is_leader = false
var cover_position = Vector2.ZERO
var current_target = null

func _ready():
	# Basic initialization
	pass

func get_health():
	return health

func set_health(value):
	var old_health = health
	health = clamp(value, 0, max_health)
	emit_signal("health_changed", old_health, health)
	if health <= 0 and old_health > 0:
		emit_signal("died")
	return true
	
func take_damage(amount):
	var actual_damage = max(1, amount - armor)
	set_health(health - actual_damage)
	return actual_damage
	
func is_dead():
	return health <= 0
	
func get_experience():
	return experience
	
func gain_experience(amount):
	experience += amount
	emit_signal("experience_gained", amount)
	return true
	
func set_as_leader(value):
	is_leader = value
	
func is_leader():
	return is_leader
	
func set_current_target(target):
	current_target = target
	return true
	
func move_to(target_pos):
	position = target_pos
	return true
	
func navigate_to(target_pos):
	position = target_pos
	return true
	
func attack(target):
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		return true
	return false
	
func engage_target(target):
	return attack(target)
"""
	script.reload()
	
	# Apply the script to the enemy
	if is_instance_valid(enemy_node):
		enemy_node.set_script(script)
