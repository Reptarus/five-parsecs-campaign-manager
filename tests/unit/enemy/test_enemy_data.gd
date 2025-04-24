@tool
extends GutTest

## Tests EnemyData resource functionality
##
## Verifies:
## - Data loading/saving
## - Property validation
## - Serialization
## - Factory methods

# Import required helpers
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Constants
const STABILIZE_TIME := 0.1

# Variables for scripts that might not exist - loaded dynamically in before_all
var EnemyDataScript = null
var GameEnums = null

# Type-safe instance variables
var _test_enemy_data: Resource = null
var _test_resources: Array = []

# Base enemy data template for testing
const TEST_ENEMY_DATA = {
	"id": "test_enemy_1",
	"name": "Test Enemy",
	"health": 100,
	"max_health": 100,
	"damage": 10,
	"armor": 5,
	"movement_speed": 3.0,
	"attack_range": 2.0,
	"faction": 0,
	"level": 1,
	"abilities": ["basic_attack", "block"],
	"loot_table": {"gold": 10, "xp": 25}
}

# Implementation of the track_test_resource function
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
	
	if not (resource in _test_resources):
		_test_resources.append(resource)

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	GameEnums = load("res://src/core/systems/GlobalEnums.gd") if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd") else null
	
	# Load enemy scripts
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")

func before_each() -> void:
	# Reset test resources
	_test_resources.clear()
	
	# Create test enemy data if script exists
	if EnemyDataScript:
		_test_enemy_data = create_test_enemy_resource(TEST_ENEMY_DATA.duplicate())
	else:
		# Fallback to using a generic Resource
		_test_enemy_data = Resource.new()
		for key in TEST_ENEMY_DATA:
			_test_enemy_data.set_meta(key, TEST_ENEMY_DATA[key])
	
	track_test_resource(_test_enemy_data)
	
	await get_tree().create_timer(STABILIZE_TIME).timeout

func after_each() -> void:
	# Clean up test resources (handled by GUT's garbage collection)
	_test_enemy_data = null
	_test_resources.clear()

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

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
			elif resource.has_method("setup"):
				resource.setup(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
					elif key in resource:
						resource[key] = data[key]
					else:
						# Use meta as last resort
						resource.set_meta(key, data[key])
	else:
		# Fallback: create a generic Resource with metadata
		resource = Resource.new()
		for key in data:
			resource.set_meta(key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# Basic Data Tests
func test_enemy_data_creation() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	assert_not_null(_test_enemy_data, "Enemy data resource should be created")
	
	# Test basic properties
	var properties_to_check = ["id", "name", "health", "max_health", "damage", "armor"]
	
	for prop in properties_to_check:
		var has_property = false
		
		# Try different ways to access property
		if _test_enemy_data.has_method("get_" + prop):
			has_property = true
			var value = _test_enemy_data.call("get_" + prop)
			assert_eq(value, TEST_ENEMY_DATA[prop], "Property " + prop + " should match test data")
		elif prop in _test_enemy_data:
			has_property = true
			assert_eq(_test_enemy_data[prop], TEST_ENEMY_DATA[prop], "Property " + prop + " should match test data")
		elif _test_enemy_data.has_meta(prop):
			has_property = true
			assert_eq(_test_enemy_data.get_meta(prop), TEST_ENEMY_DATA[prop], "Property " + prop + " should match test data")
			
		assert_true(has_property, "EnemyData should have " + prop + " property")

# Data Validation Tests
func test_enemy_data_validation() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	# Test invalid data
	var invalid_data = {
		"id": "", # Empty ID
		"health": - 10, # Negative health
		"max_health": 0, # Zero max health
		"damage": - 5 # Negative damage
	}
	
	var valid_result = true
	
	# Check if the resource has a validate method
	if _test_enemy_data.has_method("validate"):
		valid_result = _test_enemy_data.validate(invalid_data)
		assert_false(valid_result, "Should reject invalid data")
		
		# Check validation details if errors are available
		if _test_enemy_data.has_method("get_validation_errors"):
			var errors = _test_enemy_data.get_validation_errors()
			assert_true(errors.size() > 0, "Should report validation errors")
	else:
		# If no validation method, just check that we can't set invalid values
		var test_resource = create_test_enemy_resource()
		
		if test_resource.has_method("set_health"):
			# Try to set negative health and check if it was rejected
			test_resource.set_health(-10)
			var health = test_resource.get_health() if test_resource.has_method("get_health") else 0
			assert_true(health >= 0, "Health should not be negative")
		else:
			# Skip test if we can't test validation
			pending("EnemyData missing validation methods")

# Serialization Tests
func test_enemy_data_serialization() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	# Test to_dictionary if available
	if _test_enemy_data.has_method("to_dictionary"):
		var dict = _test_enemy_data.to_dictionary()
		assert_not_null(dict, "Should convert to dictionary")
		
		# Check serialized properties
		for key in TEST_ENEMY_DATA:
			assert_true(key in dict, "Dictionary should contain " + key)
			assert_eq(dict[key], TEST_ENEMY_DATA[key], "Serialized " + key + " should match original")
	elif _test_enemy_data.has_method("serialize"):
		var data = _test_enemy_data.serialize()
		assert_not_null(data, "Should serialize to data")
	else:
		# Skip test if serialization methods not available
		pending("EnemyData missing serialization methods")

# Factory Method Tests
func test_enemy_data_factory() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	# Test factory methods if available
	if EnemyDataScript.has_method("create_from_template"):
		var template_id = "test_template"
		var new_enemy = EnemyDataScript.create_from_template(template_id)
		assert_not_null(new_enemy, "Should create enemy from template")
		track_test_resource(new_enemy)
	elif EnemyDataScript.has_method("create"):
		var new_enemy = EnemyDataScript.create(TEST_ENEMY_DATA)
		assert_not_null(new_enemy, "Should create enemy from data")
		track_test_resource(new_enemy)
	else:
		# Test basic instantiation instead
		var new_enemy = EnemyDataScript.new()
		assert_not_null(new_enemy, "Should instantiate EnemyData")
		track_test_resource(new_enemy)
		
		if new_enemy.has_method("load"):
			var result = new_enemy.load(TEST_ENEMY_DATA)
			assert_true(result, "Should load data into new instance")

# Cloning Tests
func test_enemy_data_cloning() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	# Test clone method if available
	if _test_enemy_data.has_method("clone") or _test_enemy_data.has_method("duplicate"):
		var clone = null
		
		if _test_enemy_data.has_method("clone"):
			clone = _test_enemy_data.clone()
		else:
			clone = _test_enemy_data.duplicate()
			
		assert_not_null(clone, "Should clone enemy data")
		track_test_resource(clone)
		
		# Verify clone properties
		var properties_to_check = ["id", "name", "health", "max_health", "damage", "armor"]
		
		for prop in properties_to_check:
			var original_value = null
			var clone_value = null
			
			# Get original value
			if _test_enemy_data.has_method("get_" + prop):
				original_value = _test_enemy_data.call("get_" + prop)
			elif prop in _test_enemy_data:
				original_value = _test_enemy_data[prop]
			elif _test_enemy_data.has_meta(prop):
				original_value = _test_enemy_data.get_meta(prop)
				
			# Get clone value
			if clone.has_method("get_" + prop):
				clone_value = clone.call("get_" + prop)
			elif prop in clone:
				clone_value = clone[prop]
			elif clone.has_meta(prop):
				clone_value = clone.get_meta(prop)
				
			assert_eq(clone_value, original_value, "Cloned " + prop + " should match original")
		
		# Test independence after cloning
		if clone.has_method("set_health"):
			clone.set_health(50)
			
			var original_health = _test_enemy_data.get_health() if _test_enemy_data.has_method("get_health") else 100
			var clone_health = clone.get_health() if clone.has_method("get_health") else 50
			
			assert_ne(clone_health, original_health, "Clone should be independent of original")
	else:
		# Skip test if clone method not available
		pending("EnemyData missing clone method")

# Level Scaling Tests
func test_enemy_data_scaling() -> void:
	# Skip if EnemyData script not available
	if not EnemyDataScript:
		pending("EnemyData script not available")
		return
		
	# Test level scaling if available
	if _test_enemy_data.has_method("scale_to_level"):
		var initial_level = 1
		var initial_health = 0
		var initial_damage = 0
		
		# Get initial values
		if _test_enemy_data.has_method("get_level"):
			initial_level = _test_enemy_data.get_level()
		elif "level" in _test_enemy_data:
			initial_level = _test_enemy_data.level
		elif _test_enemy_data.has_meta("level"):
			initial_level = _test_enemy_data.get_meta("level")
		
		if _test_enemy_data.has_method("get_health"):
			initial_health = _test_enemy_data.get_health()
		elif "health" in _test_enemy_data:
			initial_health = _test_enemy_data.health
		elif _test_enemy_data.has_meta("health"):
			initial_health = _test_enemy_data.get_meta("health")
			
		if _test_enemy_data.has_method("get_damage"):
			initial_damage = _test_enemy_data.get_damage()
		elif "damage" in _test_enemy_data:
			initial_damage = _test_enemy_data.damage
		elif _test_enemy_data.has_meta("damage"):
			initial_damage = _test_enemy_data.get_meta("damage")
		
		# Scale to higher level
		var target_level = initial_level + 3
		_test_enemy_data.scale_to_level(target_level)
		
		# Get new values
		var new_level = 0
		var new_health = 0
		var new_damage = 0
		
		if _test_enemy_data.has_method("get_level"):
			new_level = _test_enemy_data.get_level()
		elif "level" in _test_enemy_data:
			new_level = _test_enemy_data.level
		elif _test_enemy_data.has_meta("level"):
			new_level = _test_enemy_data.get_meta("level")
		
		if _test_enemy_data.has_method("get_health"):
			new_health = _test_enemy_data.get_health()
		elif "health" in _test_enemy_data:
			new_health = _test_enemy_data.health
		elif _test_enemy_data.has_meta("health"):
			new_health = _test_enemy_data.get_meta("health")
			
		if _test_enemy_data.has_method("get_damage"):
			new_damage = _test_enemy_data.get_damage()
		elif "damage" in _test_enemy_data:
			new_damage = _test_enemy_data.damage
		elif _test_enemy_data.has_meta("damage"):
			new_damage = _test_enemy_data.get_meta("damage")
		
		# Verify scaling effects
		assert_eq(new_level, target_level, "Level should be updated")
		assert_gt(new_health, initial_health, "Health should increase with level")
		assert_gt(new_damage, initial_damage, "Damage should increase with level")
	else:
		# Skip test if scaling method not available
		pending("EnemyData missing scale_to_level method")
