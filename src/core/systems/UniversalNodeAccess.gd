# Universal Safe Node Access - Apply to ALL files
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name UniversalNodeAccess
extends RefCounted

static func get_node_safe(node: Node, path: NodePath, context: String = "") -> Node:
	if not node:
		push_error("CRASH PREVENTION: Source node is null - %s" % context)
		return null

	if not node.has_node(path):
		push_error("CRASH PREVENTION: Node path not found: %s - %s" % [path, context])
		return null

	var target_node: Node = node.get_node(path)
	if not target_node:
		push_error("CRASH PREVENTION: Node exists but is null: %s - %s" % [path, context])
		return null

	return target_node

static func get_child_safe(node: Node, index: int, context: String = "") -> Node:
	if not node:
		push_error("CRASH PREVENTION: Source node is null for child access - %s" % context)
		return null

	if index < 0 or index >= node.get_child_count():
		push_error("CRASH PREVENTION: Child index out of range: %d (max: %d) - %s" % [index, node.get_child_count() - 1, context])
		return null

	var child_node: Node = node.get_child(index)
	if not child_node:
		push_error("CRASH PREVENTION: Child exists but is null at index %d - %s" % [index, context])
		return null

	return child_node

static func find_child_safe(node: Node, pattern: String, recursive: bool = true, owned: bool = true, context: String = "") -> Node:
	if not node:
		push_error("CRASH PREVENTION: Source node is null for find_child - %s" % context)
		return null

	if (pattern.is_empty()):
		push_error("CRASH PREVENTION: Empty search pattern for find_child - %s" % context)
		return null

	var found_node: Node = node.find_child(pattern, recursive, owned)
	if not found_node:
		push_warning("Node not found with pattern '%s' - %s" % [pattern, context])
		return null

	return found_node

static func add_child_safe(parent: Node, child: Node, context: String = "") -> bool:
	if not parent:
		push_error("CRASH PREVENTION: Parent node is null for add_child - %s" % context)
		return false

	if not child:
		push_error("CRASH PREVENTION: Child node is null for add_child - %s" % context)
		return false

	if child.get_parent():
		push_warning("Child node already has a parent, removing first - %s" % context)
		child.get_parent().remove_child(child)

	parent.add_child(child)
	return true

static func remove_child_safe(parent: Node, child: Node, context: String = "") -> bool:
	if not parent:
		push_error("CRASH PREVENTION: Parent node is null for remove_child - %s" % context)
		return false

	if not child:
		push_error("CRASH PREVENTION: Child node is null for remove_child - %s" % context)
		return false

	if child.get_parent() != parent:
		push_error("CRASH PREVENTION: Child is not a child of the specified parent - %s" % context)
		return false

	parent.remove_child(child)
	return true

## Remove child from parent and free its memory safely
static func remove_and_free_child_safe(parent: Node, child: Node, context: String = "") -> bool:
	if not parent:
		push_error("CRASH PREVENTION: Parent node is null for remove_and_free_child - %s" % context)
		return false

	if not child:
		push_error("CRASH PREVENTION: Child node is null for remove_and_free_child - %s" % context)
		return false

	if child.get_parent() != parent:
		push_error("CRASH PREVENTION: Child is not a child of the specified parent - %s" % context)
		return false

	parent.remove_child(child)
	child.queue_free()  # Properly free memory
	return true

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null