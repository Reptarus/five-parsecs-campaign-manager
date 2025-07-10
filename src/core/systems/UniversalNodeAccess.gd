extends RefCounted
class_name UniversalNodeAccess

func initialize() -> void:
	pass

func get_node_safe(path: String) -> Node:
	return null

func validate_node(node: Node) -> bool:
	return node != null