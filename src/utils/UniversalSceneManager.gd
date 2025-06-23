# Universal Safe Scene Transitions - Apply to ALL files
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name UniversalSceneManager
extends RefCounted

static func change_scene_safe(tree: SceneTree, scene_path: String, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null - %s" % context)  
		return false
	
	if not ResourceLoader.exists(scene_path):
		push_error("CRASH PREVENTION: Scene file not found: %s - %s" % [scene_path, context])
		return false
	
	# Use call_deferred for safety
	tree.call_deferred("change_scene_to_file", scene_path)
	return true

static func instantiate_scene_safe(scene_path: String, context: String = "") -> Node:
	var scene_resource = UniversalResourceLoader.load_scene_safe(scene_path, context)
	if not scene_resource:
		return null
	
	var scene_instance = scene_resource.instantiate()
	if not scene_instance:
		push_error("CRASH PREVENTION: Failed to instantiate scene: %s - %s" % [scene_path, context])
		return null
	
	return scene_instance

static func change_scene_to_packed_safe(tree: SceneTree, packed_scene: PackedScene, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for packed scene change - %s" % context)
		return false
	
	if not packed_scene:
		push_error("CRASH PREVENTION: PackedScene is null - %s" % context)
		return false
	
	# Use call_deferred for safety
	tree.call_deferred("change_scene_to_packed", packed_scene)
	return true

static func reload_current_scene_safe(tree: SceneTree, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for scene reload - %s" % context)
		return false
	
	# Use call_deferred for safety
	tree.call_deferred("reload_current_scene")
	return true

static func add_scene_to_tree_safe(tree: SceneTree, scene_instance: Node, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for scene addition - %s" % context)
		return false
	
	if not scene_instance:
		push_error("CRASH PREVENTION: Scene instance is null - %s" % context)
		return false
	
	var root = tree.current_scene
	if not root:
		push_error("CRASH PREVENTION: Current scene is null, cannot add scene - %s" % context)
		return false
	
	root.add_child(scene_instance)
	return true

static func remove_scene_from_tree_safe(scene_instance: Node, free_after_remove: bool = true, context: String = "") -> bool:
	if not scene_instance:
		push_error("CRASH PREVENTION: Scene instance is null for removal - %s" % context)
		return false
	
	var parent = scene_instance.get_parent()
	if not parent:
		push_warning("Scene instance has no parent, cannot remove - %s" % context)
		return false
	
	parent.remove_child(scene_instance)
	
	if free_after_remove:
		scene_instance.queue_free()
	
	return true

static func get_current_scene_safe(tree: SceneTree, context: String = "") -> Node:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for current scene access - %s" % context)
		return null
	
	var current_scene = tree.current_scene
	if not current_scene:
		push_warning("Current scene is null - %s" % context)
		return null
	
	return current_scene

static func validate_scene_tree_safe(tree: SceneTree, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for validation - %s" % context)
		return false
	
	var root = tree.get_root()
	if not root:
		push_error("CRASH PREVENTION: SceneTree root is null - %s" % context)
		return false
	
	var current_scene = tree.current_scene
	if not current_scene:
		push_warning("Current scene is null but tree exists - %s" % context)
		return true  # This might be valid during transitions
	
	return true

static func create_scene_instance_safe(scene_script: Script, context: String = "") -> Node:
	if not scene_script:
		push_error("CRASH PREVENTION: Scene script is null - %s" % context)
		return null
	
	var instance = scene_script.new()
	if not instance:
		push_error("CRASH PREVENTION: Failed to create instance from script - %s" % context)
		return null
	
	if not instance is Node:
		push_error("CRASH PREVENTION: Script instance is not a Node - %s" % context)
		if instance is RefCounted:
			# Don't need to free RefCounted objects
			pass
		else:
			instance.free()
		return null
	
	return instance as Node

static func queue_scene_change_safe(tree: SceneTree, scene_path: String, delay: float = 0.0, context: String = "") -> bool:
	if not tree:
		push_error("CRASH PREVENTION: SceneTree is null for queued scene change - %s" % context)
		return false
	
	if not ResourceLoader.exists(scene_path):
		push_error("CRASH PREVENTION: Scene file not found for queued change: %s - %s" % [scene_path, context])
		return false
	
	if delay <= 0.0:
		return change_scene_safe(tree, scene_path, context)
	
	# Create a timer for delayed scene change
	var timer = tree.create_timer(delay)
	if not timer:
		push_error("CRASH PREVENTION: Failed to create timer for delayed scene change - %s" % context)
		return false
	
	timer.timeout.connect(func(): change_scene_safe(tree, scene_path, context))
	return true