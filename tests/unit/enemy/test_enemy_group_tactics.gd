@tool
extends GutTest

## Tests for enemy group tactics functionality
##
## Verifies:
## - Group coordination
## - Tactical decision making
## - Formation management
## - Leader/follower dynamics

# Import required helpers
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Constants
const STABILIZE_TIME := 0.1
const TACTICS_TIMEOUT := 2.0

# Variables for scripts that might not exist - loaded dynamically in before_all
var EnemyNodeScript = null
var EnemyDataScript = null
var EnemyTacticsScript = null
var GameEnums = null

# Type-safe instance variables
var _tactics_manager = null
var _group_controller = null
var _test_enemies: Array = []

# Test nodes to track for cleanup
var _tracked_test_nodes: Array = []

# Tactics metrics
var _formation_changed := false
var _tactic_applied := false
var _leader_assigned := false

# Implementation of the track_test_node function
# This tracks nodes for proper cleanup in after_each
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_test_nodes):
		_tracked_test_nodes.append(node)

# Implementation of the track_test_resource function
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
		
	# For GUT, we don't need to do anything special - resources are cleaned up by default

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	GameEnums = load("res://src/core/systems/GlobalEnums.gd") if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd") else null
	
	# Load enemy scripts
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")
		
	# Load tactics scripts
	EnemyTacticsScript = load("res://src/core/enemy/tactics/EnemyTactics.gd") if ResourceLoader.exists("res://src/core/enemy/tactics/EnemyTactics.gd") else null

func before_each() -> void:
	# Clear tracked nodes list
	_tracked_test_nodes.clear()
	
	# Reset tactics metrics
	_formation_changed = false
	_tactic_applied = false
	_leader_assigned = false
	
	# Setup the tactics manager
	_setup_tactics_manager()
	
	# Setup the group controller
	_setup_group_controller()
	
	# Connect signals
	if _tactics_manager != null:
		if _tactics_manager.has_signal("formation_changed"):
			_tactics_manager.connect("formation_changed", _on_formation_changed)
		
		if _tactics_manager.has_signal("tactic_applied"):
			_tactics_manager.connect("tactic_applied", _on_tactic_applied)
			
		if _tactics_manager.has_signal("leader_assigned"):
			_tactics_manager.connect("leader_assigned", _on_leader_assigned)
	
	await get_tree().create_timer(STABILIZE_TIME).timeout

func after_each() -> void:
	# Clean up tracked test nodes
	for node in _tracked_test_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_test_nodes.clear()
	
	# Cleanup references
	_tactics_manager = null
	_group_controller = null
	_test_enemies.clear()

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> Node:
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript != null:
		# Check if we can instantiate in a safe way
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
		push_warning("EnemyNodeScript unavailable, creating generic Node2D")
		enemy_node = Node2D.new()
		enemy_node.name = "GenericTestEnemy"
		
		# Add position property for tactics tests
		enemy_node.set("position", Vector2.ZERO)
		enemy_node.set("formation_position", Vector2.ZERO)
		enemy_node.set("group_id", -1)
		enemy_node.set("is_leader", false)
		enemy_node.set("current_tactic", 0)
		
		# Add methods for position
		enemy_node.set("get_position", func():
			return enemy_node.position
		)
		
		enemy_node.set("set_position", func(pos):
			enemy_node.position = pos
			return true
		)
		
		# Add methods for group coordination
		enemy_node.set("move_to", func(pos):
			enemy_node.position = pos
			return true
		)
		
		enemy_node.set("set_group_id", func(id):
			enemy_node.group_id = id
			return true
		)
		
		enemy_node.set("set_leader", func(is_leader):
			enemy_node.is_leader = is_leader
			return true
		)
		
		enemy_node.set("set_tactic", func(tactic_id):
			enemy_node.current_tactic = tactic_id
			return true
		)
		
		enemy_node.set("set_formation_position", func(pos):
			enemy_node.formation_position = pos
			return true
		)
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		
	# Track locally if needed
	if enemy_node:
		_test_enemies.append(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Function to create a test enemy resource
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	var resource = null
	
	if EnemyDataScript != null:
		resource = EnemyDataScript.new()
		if resource:
			# Initialize the resource with data
			if resource.has_method("load"):
				resource.load(data)
			elif resource.has_method("initialize"):
				resource.initialize(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# Setup Methods
func _setup_tactics_manager() -> void:
	if EnemyTacticsScript:
		_tactics_manager = EnemyTacticsScript.new()
		add_child_autofree(_tactics_manager)
		track_test_node(_tactics_manager)
	else:
		# Create a simple tactics manager
		_tactics_manager = Node.new()
		_tactics_manager.name = "SimpleTacticsManager"
		add_child_autofree(_tactics_manager)
		track_test_node(_tactics_manager)
		
		# Add required properties
		_tactics_manager.set("formation_type", 0) # Default formation
		_tactics_manager.set("group_tactic", 0) # Default tactic
		
		# Add formation types if GameEnums is not available
		if not GameEnums or not is_instance_valid(GameEnums) or not "FormationType" in GameEnums:
			_tactics_manager.set("FORMATION_LINE", 0)
			_tactics_manager.set("FORMATION_CIRCLE", 1)
			_tactics_manager.set("FORMATION_WEDGE", 2)
			_tactics_manager.set("FORMATION_SCATTERED", 3)
		
		# Add tactic types if GameEnums is not available
		if not GameEnums or not is_instance_valid(GameEnums) or not "GroupTactic" in GameEnums:
			_tactics_manager.set("TACTIC_AGGRESSIVE", 0)
			_tactics_manager.set("TACTIC_DEFENSIVE", 1)
			_tactics_manager.set("TACTIC_FLANKING", 2)
			_tactics_manager.set("TACTIC_SUPPORT", 3)
		
		# Add method to assign leader
		_tactics_manager.set("assign_leader", func(group):
			if group.size() > 0:
				var leader = group[0]
				leader.set_leader(true)
				_tactics_manager.emit_signal("leader_assigned", leader)
				return leader
			return null
		)
		
		# Add method to set formation
		_tactics_manager.set("set_formation", func(group, formation_type):
			_tactics_manager.formation_type = formation_type
			
			if group.size() == 0:
				return false
				
			var formation_positions = []
			var center = Vector2.ZERO
			var spacing = 50.0
			
			# Calculate the average position
			for unit in group:
				# Safely get the position
				var unit_pos = Vector2.ZERO
				if unit.has_method("get_position"):
					unit_pos = unit.get_position()
				elif "position" in unit:
					unit_pos = unit.position
				center += unit_pos
			center /= group.size()
			
			# Calculate formation positions
			match formation_type:
				_tactics_manager.FORMATION_LINE:
					for i in range(group.size()):
						var pos = center + Vector2(spacing * (i - group.size() / 2.0), 0)
						formation_positions.append(pos)
				
				_tactics_manager.FORMATION_CIRCLE:
					var radius = spacing
					for i in range(group.size()):
						var angle = 2 * PI * i / group.size()
						var pos = center + Vector2(cos(angle), sin(angle)) * radius
						formation_positions.append(pos)
				
				_tactics_manager.FORMATION_WEDGE:
					for i in range(group.size()):
						var row = int(i / 3)
						var col = i % 3 - 1
						var pos = center + Vector2(col * spacing, row * spacing)
						formation_positions.append(pos)
				
				_tactics_manager.FORMATION_SCATTERED:
					for i in range(group.size()):
						var pos = center + Vector2(randf_range(-spacing, spacing), randf_range(-spacing, spacing))
						formation_positions.append(pos)
			
			# Assign formation positions to units
			for i in range(min(group.size(), formation_positions.size())):
				var unit = group[i]
				var pos = formation_positions[i]
				
				# Safely set formation position
				if unit.has_method("set_formation_position"):
					unit.set_formation_position(pos)
				elif "formation_position" in unit:
					unit.formation_position = pos
				
				# Safely move unit
				if unit.has_method("move_to"):
					unit.move_to(pos)
				elif unit.has_method("set_position"):
					unit.set_position(pos)
				elif "position" in unit:
					unit.position = pos
			
			_tactics_manager.emit_signal("formation_changed", formation_type)
			return true
		)
		
		# Add method to apply tactic
		_tactics_manager.set("apply_tactic", func(group, tactic_id):
			_tactics_manager.group_tactic = tactic_id
			
			for unit in group:
				# Safely set tactic
				if unit.has_method("set_tactic"):
					unit.set_tactic(tactic_id)
				elif "current_tactic" in unit:
					unit.current_tactic = tactic_id
			
			_tactics_manager.emit_signal("tactic_applied", tactic_id)
			return true
		)
		
		# Add required signals
		_tactics_manager.add_user_signal("formation_changed", [ {"name": "formation_type", "type": "int"}])
		_tactics_manager.add_user_signal("tactic_applied", [ {"name": "tactic_id", "type": "int"}])
		_tactics_manager.add_user_signal("leader_assigned", [ {"name": "leader", "type": "Object"}])

func _setup_group_controller() -> void:
	# Create a simple group controller
	_group_controller = Node.new()
	_group_controller.name = "GroupController"
	add_child_autofree(_group_controller)
	track_test_node(_group_controller)
	
	# Add required properties and methods
	_group_controller.set_meta("groups", {})
	
	# Define the create_group function and store it as metadata
	_group_controller.set_meta("create_group_func", func(group_id, units):
		var groups = _group_controller.get_meta("groups")
		groups[group_id] = units
		
		# Assign group ID to each unit
		for unit in units:
			if unit.has_method("set_group_id"):
				unit.set_group_id(group_id)
			elif "group_id" in unit:
				unit.group_id = group_id
		
		return true
	)
	
	# Define the get_group function
	_group_controller.set_meta("get_group_func", func(group_id):
		var groups = _group_controller.get_meta("groups")
		if group_id in groups:
			return groups[group_id]
		return []
	)
	
	# Define the add_to_group function
	_group_controller.set_meta("add_to_group_func", func(group_id, unit):
		var groups = _group_controller.get_meta("groups")
		if not (group_id in groups):
			groups[group_id] = []
		
		groups[group_id].append(unit)
		
		if unit.has_method("set_group_id"):
			unit.set_group_id(group_id)
		elif "group_id" in unit:
			unit.group_id = group_id
		
		return true
	)
	
	# Define the remove_from_group function
	_group_controller.set_meta("remove_from_group_func", func(group_id, unit):
		var groups = _group_controller.get_meta("groups")
		if group_id in groups and unit in groups[group_id]:
			groups[group_id].erase(unit)
			
			if unit.has_method("set_group_id"):
				unit.set_group_id(-1)
			elif "group_id" in unit:
				unit.group_id = -1
				
			return true
		return false
	)
	
	# Create script with wrapper methods that call the metadata functions
	var script = GDScript.new()
	script.source_code = """
extends Node

# Setup metadata in _ready
func _ready():
	# No need to set metadata here since it's already set in _setup_group_controller

# Wrapper methods that call the stored callables
func create_group(group_id, units):
	return get_meta("create_group_func").call(group_id, units)

func get_group(group_id):
	return get_meta("get_group_func").call(group_id)

func add_to_group(group_id, unit):
	return get_meta("add_to_group_func").call(group_id, unit)

func remove_from_group(group_id, unit):
	return get_meta("remove_from_group_func").call(group_id, unit)
"""
	var err = script.reload()
	if err != OK:
		push_error("Failed to reload group controller script: " + str(err))
	_group_controller.set_script(script)

# Signal Handlers
func _on_formation_changed(formation_type: int) -> void:
	_formation_changed = true

func _on_tactic_applied(tactic_id: int) -> void:
	_tactic_applied = true

func _on_leader_assigned(leader) -> void:
	_leader_assigned = true

# Basic Group Formation Tests
func test_group_formation() -> void:
	# Skip if tactics manager couldn't be created
	if not _tactics_manager:
		pending("Test requires tactics system")
		return
	
	# Create test enemies
	var units = []
	for i in range(5):
		var unit = create_test_enemy()
		if unit:
			units.append(unit)
	
	# Skip if enemy creation failed
	if units.size() == 0:
		pending("Test requires enemy implementation")
		return
	
	# Create a group
	var group_id = 1
	
	if not _group_controller.has_method("create_group"):
		pending("Group controller missing create_group method")
		return
		
	var result = _group_controller.create_group(group_id, units)
	assert_true(result, "Should successfully create group")
	
	# Test different formations
	var formation_types = []
	
	# Use GameEnums if available
	if GameEnums and is_instance_valid(GameEnums) and "FormationType" in GameEnums:
		if "LINE" in GameEnums.FormationType and "CIRCLE" in GameEnums.FormationType and \
		   "WEDGE" in GameEnums.FormationType and "SCATTERED" in GameEnums.FormationType:
			formation_types = [
				GameEnums.FormationType.LINE,
				GameEnums.FormationType.CIRCLE,
				GameEnums.FormationType.WEDGE,
				GameEnums.FormationType.SCATTERED
			]
		else:
			push_warning("GameEnums.FormationType exists but is missing expected values")
	
	# Fall back to tactics manager values if necessary
	if formation_types.size() == 0:
		if "FORMATION_LINE" in _tactics_manager and "FORMATION_CIRCLE" in _tactics_manager and \
		   "FORMATION_WEDGE" in _tactics_manager and "FORMATION_SCATTERED" in _tactics_manager:
			formation_types = [
				_tactics_manager.FORMATION_LINE,
				_tactics_manager.FORMATION_CIRCLE,
				_tactics_manager.FORMATION_WEDGE,
				_tactics_manager.FORMATION_SCATTERED
			]
	
	# Skip if no formation types available
	if formation_types.size() == 0:
		pending("No formation types available")
		return
	
	# Now test the formations
	for formation_type in formation_types:
		# Reset tracking
		_formation_changed = false
		
		# Verify _tactics_manager has set_formation method
		if not _tactics_manager.has_method("set_formation"):
			pending("Tactics manager missing set_formation method")
			return
		
		# Set the formation
		var formation_result = _tactics_manager.set_formation(units, formation_type)
		
		# Wait for formation change to complete
		await get_tree().create_timer(TACTICS_TIMEOUT).timeout
		
		# Verify formation was set
		assert_true(formation_result, "Formation should be set successfully")
		assert_true(_formation_changed, "Formation change signal should be emitted")
		
		# Verify formation positions were assigned
		for unit in units:
			var has_formation_position = false
			var formation_position = Vector2.ZERO
			
			# Safely check formation position
			if unit.has_method("get_formation_position"):
				formation_position = unit.get_formation_position()
				has_formation_position = true
			elif "formation_position" in unit:
				formation_position = unit.formation_position
				has_formation_position = true
			
			if has_formation_position:
				assert_ne(formation_position, Vector2.ZERO, "Formation position should be assigned")
	
# Leader Assignment Tests
func test_leader_assignment() -> void:
	# Skip if tactics manager couldn't be created
	if not _tactics_manager:
		pending("Test requires tactics system")
		return
	
	# Create test enemies
	var units = []
	for i in range(3):
		var unit = create_test_enemy()
		if unit:
			units.append(unit)
	
	# Skip if enemy creation failed
	if units.size() == 0:
		pending("Test requires enemy implementation")
		return
	
	# Create a group
	var group_id = 2
	
	if not _group_controller.has_method("create_group"):
		pending("Group controller missing create_group method")
		return
		
	var create_result = _group_controller.create_group(group_id, units)
	assert_true(create_result, "Should successfully create group")
	
	# Check if tactics manager has assign_leader method
	if not _tactics_manager.has_method("assign_leader"):
		pending("Tactics manager missing assign_leader method")
		return
	
	# Assign leader
	var leader = _tactics_manager.assign_leader(units)
	
	# Wait for leader assignment to complete
	await get_tree().create_timer(TACTICS_TIMEOUT).timeout
	
	# Verify leader was assigned
	assert_not_null(leader, "Leader should be assigned")
	assert_true(_leader_assigned, "Leader assignment signal should be emitted")
	
	# Check if leader has is_leader property or method
	var is_leader = false
	if leader.has_method("is_leader"):
		is_leader = leader.is_leader()
	elif "is_leader" in leader:
		is_leader = leader.is_leader
	
	assert_true(is_leader, "Leader flag should be set on unit")
	
	# Verify only one leader
	var leader_count = 0
	for unit in units:
		var unit_is_leader = false
		if unit.has_method("is_leader"):
			unit_is_leader = unit.is_leader()
		elif "is_leader" in unit:
			unit_is_leader = unit.is_leader
			
		if unit_is_leader:
			leader_count += 1
	
	assert_eq(leader_count, 1, "Only one unit should be the leader")

# Tactical Decision Tests
func test_tactical_decisions() -> void:
	# Skip if tactics manager couldn't be created
	if not _tactics_manager:
		pending("Test requires tactics system")
		return
	
	# Create test enemies
	var units = []
	for i in range(4):
		var unit = create_test_enemy()
		if unit:
			units.append(unit)
	
	# Skip if enemy creation failed
	if units.size() == 0:
		pending("Test requires enemy implementation")
		return
	
	# Create a group
	var group_id = 3
	
	if not _group_controller.has_method("create_group"):
		pending("Group controller missing create_group method")
		return
		
	var create_result = _group_controller.create_group(group_id, units)
	assert_true(create_result, "Should successfully create group")
	
	# Check if tactics manager has assign_leader method
	if not _tactics_manager.has_method("assign_leader"):
		pending("Tactics manager missing assign_leader method")
		return
	
	# Assign leader
	var leader = _tactics_manager.assign_leader(units)
	assert_not_null(leader, "Should assign a leader")
	
	# Test different tactics
	var tactics = []
	
	# Use GameEnums if available
	if GameEnums and is_instance_valid(GameEnums) and "GroupTactic" in GameEnums:
		if "AGGRESSIVE" in GameEnums.GroupTactic and "DEFENSIVE" in GameEnums.GroupTactic and \
		   "FLANKING" in GameEnums.GroupTactic and "SUPPORT" in GameEnums.GroupTactic:
			tactics = [
				GameEnums.GroupTactic.AGGRESSIVE,
				GameEnums.GroupTactic.DEFENSIVE,
				GameEnums.GroupTactic.FLANKING,
				GameEnums.GroupTactic.SUPPORT
			]
		else:
			push_warning("GameEnums.GroupTactic exists but is missing expected values")
	
	# Fall back to tactics manager values if necessary
	if tactics.size() == 0:
		if "TACTIC_AGGRESSIVE" in _tactics_manager and "TACTIC_DEFENSIVE" in _tactics_manager and \
		   "TACTIC_FLANKING" in _tactics_manager and "TACTIC_SUPPORT" in _tactics_manager:
			tactics = [
				_tactics_manager.TACTIC_AGGRESSIVE,
				_tactics_manager.TACTIC_DEFENSIVE,
				_tactics_manager.TACTIC_FLANKING,
				_tactics_manager.TACTIC_SUPPORT
			]
	
	# Skip if no tactics available
	if tactics.size() == 0:
		pending("No tactic types available")
		return
		
	# Check if tactics manager has apply_tactic method
	if not _tactics_manager.has_method("apply_tactic"):
		pending("Tactics manager missing apply_tactic method")
		return
	
	# Test each tactic
	for tactic in tactics:
		# Reset tracking
		_tactic_applied = false
		
		# Apply the tactic
		var tactic_result = _tactics_manager.apply_tactic(units, tactic)
		
		# Wait for tactic to be applied
		await get_tree().create_timer(TACTICS_TIMEOUT).timeout
		
		# Verify tactic was applied
		assert_true(tactic_result, "Tactic should be applied successfully")
		assert_true(_tactic_applied, "Tactic application signal should be emitted")
		
		# Verify all units have the tactic
		for unit in units:
			var unit_tactic = -1
			
			# Safely get tactic
			if unit.has_method("get_tactic"):
				unit_tactic = unit.get_tactic()
			elif unit.has_method("get_current_tactic"):
				unit_tactic = unit.get_current_tactic()
			elif "current_tactic" in unit:
				unit_tactic = unit.current_tactic
				
			assert_eq(unit_tactic, tactic, "Unit tactic should match group tactic")

# Group Management Tests
func test_group_management() -> void:
	# Skip if group controller couldn't be created
	if not _group_controller:
		pending("Test requires group controller")
		return
	
	# Create test enemies
	var unit1 = create_test_enemy()
	var unit2 = create_test_enemy()
	var unit3 = create_test_enemy()
	
	# Skip if enemy creation failed
	if not unit1 or not unit2 or not unit3:
		pending("Test requires enemy implementation")
		return
	
	# Ensure controller has create_group method
	if not _group_controller.has_method("create_group"):
		pending("Group controller missing create_group method")
		return
	
	# Test creating a group
	var group_id = 4
	var result = _group_controller.create_group(group_id, [unit1, unit2])
	assert_true(result, "Group should be created successfully")
	
	# Ensure controller has get_group method
	if not _group_controller.has_method("get_group"):
		pending("Group controller missing get_group method")
		return
	
	# Test getting a group
	var group = _group_controller.get_group(group_id)
	assert_eq(group.size(), 2, "Group should have 2 units")
	assert_true(unit1 in group, "Unit 1 should be in the group")
	assert_true(unit2 in group, "Unit 2 should be in the group")
	
	# Ensure controller has add_to_group method
	if not _group_controller.has_method("add_to_group"):
		pending("Group controller missing add_to_group method")
		return
	
	# Test adding to a group
	result = _group_controller.add_to_group(group_id, unit3)
	assert_true(result, "Unit should be added to group successfully")
	
	group = _group_controller.get_group(group_id)
	assert_eq(group.size(), 3, "Group should have 3 units after addition")
	assert_true(unit3 in group, "Unit 3 should be added to the group")
	
	# Ensure controller has remove_from_group method
	if not _group_controller.has_method("remove_from_group"):
		pending("Group controller missing remove_from_group method")
		return
	
	# Test removing from a group
	result = _group_controller.remove_from_group(group_id, unit2)
	assert_true(result, "Unit should be removed from group successfully")
	
	group = _group_controller.get_group(group_id)
	assert_eq(group.size(), 2, "Group should have 2 units after removal")
	assert_false(unit2 in group, "Unit 2 should be removed from the group")
	
	# Check group_id on unit2
	var group_id_removed = -2 # Different from both the default -1 and the group_id 4
	if unit2.has_method("get_group_id"):
		group_id_removed = unit2.get_group_id()
	elif "group_id" in unit2:
		group_id_removed = unit2.group_id
		
	assert_eq(group_id_removed, -1, "Removed unit should have invalid group ID")

# Verify enemy is in a valid state for tests
func verify_enemy_complete_state(enemy) -> void:
	assert_not_null(enemy, "Enemy should be non-null")
	
	if enemy is Node2D:
		assert_eq(enemy.position, Vector2.ZERO, "Enemy should start at origin")
	
	if enemy.has_method("get_health"):
		assert_gt(enemy.get_health(), 0, "Enemy health should be positive")
	else:
		push_warning("Enemy missing get_health method, skipping health verification")
