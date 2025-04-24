@tool
extends Node

## Five Parsecs Test Framework Initialization
## Provides automatic setup and configuration for test files
## Simply preload this file in your test to get all test utilities

# Core dependencies
const TypeSafeMixin := preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const MockProvider := preload("res://tests/fixtures/helpers/mock_provider.gd")
const GameTestMockExtension := preload("res://tests/fixtures/base/game_test_mock_extension.gd")
const GutCompatibility := preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Automatic initialization flag
var _initialized := false

# Global mock provider instance (shared across tests)
var mock_provider: MockProvider = null

func _init() -> void:
	# Initialize mock provider if needed
	if mock_provider == null:
		mock_provider = MockProvider.new()

	# Mark as initialized
	_initialized = true

## Gets the mock provider instance
## @return: Shared mock provider instance
func get_mock_provider() -> MockProvider:
	if mock_provider == null:
		mock_provider = MockProvider.new()
	return mock_provider

## Creates a preconfigured test instance with mock support
## @return: A GameTestMockExtension instance ready for use in tests
func create_test_instance() -> GameTestMockExtension:
	return GameTestMockExtension.new()

## Creates a testable UI control ready for testing
## @return: A Control with mock methods
func create_test_control() -> Control:
	var control = mock_provider.create_mock_control()
	return control

## Creates a mock object with standard test methods
## @param methods: Dictionary of method names to return values
## @param properties: Dictionary of property names to values
## @return: A mock object for testing
func create_mock(methods: Dictionary = {}, properties: Dictionary = {}) -> RefCounted:
	var mock = mock_provider.create_mock_object()
	
	# Add methods
	for method_name in methods:
		mock.set_mock_value(method_name, methods[method_name])
	
	# Add properties
	for property_name in properties:
		mock.set_mock_value(property_name, properties[property_name])
	
	return mock

## Creates a mock manager of specified type
## @param manager_type: Type of manager to create (e.g., "ResourceManager")
## @return: A mock manager with appropriate methods and data
func create_mock_manager(manager_type: String) -> RefCounted:
	return mock_provider.create_manager_mock(manager_type)

## Helper method for automatic error recovery in tests
## @param object: Object to check or fix
## @return: Fixed object if needed, original otherwise
func auto_fix_object(object: Object) -> Object:
	if object == null or not is_instance_valid(object):
		return null
		
	if object is Control:
		return mock_provider.fix_missing_methods(object)
	
	return object

## Global convenience method for creating a test with all fixtures
## @return: A new test instance with all dependencies set up
static func create_test() -> GameTestMockExtension:
	var init = load("res://tests/fixtures/test_init.gd").new()
	return init.create_test_instance()

# Create singleton instance for easy access
var _instance = null

func _get_instance():
	if _instance == null:
		_instance = load("res://tests/fixtures/test_init.gd").new()
	return _instance

# Global access to singleton
static func get_instance():
	var script = load("res://tests/fixtures/test_init.gd")
	var temp = script.new()
	return temp._get_instance()