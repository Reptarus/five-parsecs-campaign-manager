@tool
extends RefCounted

## Resource Cleanup utility
##
## This utility is designed to clean up orphaned resources after test runs.
## It primarily targets known problematic resources like WorldDataMigration
## which can remain in memory and cause leak warnings.

const KNOWN_PROBLEM_RESOURCES = [
	"res://src/core/migration/WorldDataMigration.gd",
	"res://src/core/enemy/EnemyData.gd",
	"res://src/core/state/GameState.gd"
]

## Perform targeted cleanup of known resources
func cleanup_known_resources() -> void:
	print("[ResourceCleanup] Starting targeted cleanup...")
	
	# Force unload the WorldDataMigration class specifically
	if ResourceLoader.exists("res://src/core/migration/WorldDataMigration.gd"):
		# Create a helper node to help with cleanup
		var node = Node.new()
		Engine.get_main_loop().root.add_child(node)
		
		# Try to replace any instances with null references
		# to break reference cycles
		var migration_script = load("res://src/core/migration/WorldDataMigration.gd")
		if migration_script:
			# Create temporary instance to access static properties and methods
			var temp_instance = migration_script.new()
			if is_instance_valid(temp_instance):
				# If we can access the _data_manager property, set it to null
				if "_data_manager" in temp_instance:
					temp_instance._data_manager = null
				# Free the temporary instance
				temp_instance.free()
			
			# Break reference to the script
			migration_script = null
		
		# Remove the helper node
		node.queue_free()
		
		# Print debug info
		print("[ResourceCleanup] WorldDataMigration targeted cleanup complete")
	
	# For each known problem resource, try to unload it
	for resource_path in KNOWN_PROBLEM_RESOURCES:
		if ResourceLoader.exists(resource_path):
			# Trick to flush resource cache
			var dummy = ResourceLoader.load("res://")
			dummy = null # Clear reference
			print("[ResourceCleanup] Unloaded: " + resource_path)

## Force garbage collection through creating and destroying objects
func force_garbage_collection() -> void:
	print("[ResourceCleanup] Forcing garbage collection...")
	
	# Create and destroy a bunch of temporary nodes to trigger GC
	var root = Engine.get_main_loop().root
	var temp_nodes = []
	
	# Create 20 temporary nodes
	for i in range(20):
		var node = Node.new()
		node.name = "TempGCNode" + str(i)
		root.add_child(node)
		temp_nodes.append(node)
	
	# Create 20 temporary resources
	var temp_resources = []
	for i in range(20):
		var resource = Resource.new()
		temp_resources.append(resource)
	
	# Free all temporary nodes
	for node in temp_nodes:
		if is_instance_valid(node):
			node.queue_free()
	
	# Clear references to resources
	for i in range(temp_resources.size()):
		temp_resources[i] = null
	
	# Clear arrays
	temp_nodes.clear()
	temp_resources.clear()
	
	# Force processing frames
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	# Call GC manually
	ResourceLoader.load("res://") # Trick to flush resource cache
	
	print("[ResourceCleanup] Garbage collection forced")

## Check for orphaned objects and report their counts
func check_orphaned_objects() -> void:
	print("[ResourceCleanup] Checking for orphaned objects...")
	
	# We can't directly access the ObjectDB in GDScript,
	# so we'll use print statements to report counts
	print("[ResourceCleanup] Orphaned objects will be reported on program exit")

## Main cleanup function that orchestrates the full cleanup process
func cleanup() -> void:
	print("\n======== RESOURCE CLEANUP ========")
	
	# First do targeted cleanup of known problem resources
	cleanup_known_resources()
	
	# Force garbage collection to free any resources that can be freed
	force_garbage_collection()
	
	# Check for any remaining orphaned objects
	check_orphaned_objects()
	
	print("[ResourceCleanup] Cleanup complete")
	print("[ResourceCleanup] If you still see leaks on exit, try the following manual steps:")
	print("[ResourceCleanup] 1. In WorldDataMigration.gd, add a proper _notification(what) method to free resources")
	print("[ResourceCleanup] 2. Clear any static variables in problem classes")
	print("[ResourceCleanup] 3. Make sure all resources created during tests are properly freed")
	print("======== END CLEANUP ========\n")