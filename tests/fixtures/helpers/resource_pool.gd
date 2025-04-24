@tool
extends Node
class_name ResourcePool

## ResourcePool
## A helper class for managing test resources to prevent memory leaks and cyclic references
## This singleton can be used to cache and reuse resources during tests

## Dictionary of cached resources by path and type
var _resource_pool = {}

## Static singleton instance
static var _instance = null

## Get the singleton instance
static func get_instance() -> ResourcePool:
	if not _instance:
		_instance = ResourcePool.new()
	return _instance

## Constructor
func _init() -> void:
	# We won't try to auto-connect signals due to the linter issues
	# Resources will be cleaned up manually when tests are done
	pass

## Get a resource from the pool or load it if not cached
## Returns the cached or newly loaded resource
func get_test_resource(resource_path: String, type_hint: String = "") -> Resource:
	var key = resource_path
	if type_hint:
		key = resource_path + "::" + type_hint
	
	# Check if resource is already cached
	if _resource_pool.has(key) and is_instance_valid(_resource_pool[key]):
		return _resource_pool[key]
	
	# Load the resource
	var resource = load(resource_path)
	if resource:
		if type_hint and ClassDB.class_exists(type_hint):
			# Check if resource is of expected type (if type_hint is provided)
			if not is_instance_of(resource, type_hint):
				push_warning("Resource %s is not of expected type %s" % [resource_path, type_hint])
			
		# Cache the resource
		_resource_pool[key] = resource
	
	return resource

## Create a new instance of a resource with a given script
## The resource is cached by its instance ID and script path
func create_test_resource(script_path: String, name_hint: String = "") -> Resource:
	var script = load(script_path)
	if not script:
		push_error("Failed to load script: %s" % script_path)
		return null
		
	var resource = script.new()
	if not resource:
		push_error("Failed to create resource from script: %s" % script_path)
		return null
		
	# Generate a key for this resource
	var key = "%s::%s::%d" % [script_path, name_hint, resource.get_instance_id()]
	
	# Cache the resource
	_resource_pool[key] = resource
	
	return resource

## Preload a set of resources that will be used in tests
## This can help prevent resource loading during tests, which can cause timing issues
func preload_test_resources(resource_paths: Array) -> void:
	for path in resource_paths:
		get_test_resource(path)

## Clean up all resources in the pool
## This should be called after tests are complete
func cleanup_resource_pool() -> void:
	for key in _resource_pool.keys():
		var resource = _resource_pool[key]
		if resource is Resource:
			# Release the resource path to allow garbage collection
			if resource.resource_path:
				resource.take_over_path("")
			
			# Clear references
			resource = null
	
	# Clear the pool
	_resource_pool.clear()
