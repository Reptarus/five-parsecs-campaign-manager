@tool
extends EditorPlugin

const GeometricShape = preload("./shapes/GeometricShape.gd")
const Handle = preload("./handles/Handle.gd")

func _enter_tree() -> void:
	add_custom_type("Rectangle", "Node2D", preload("./shapes/Rectangle.gd"), null)
	add_custom_type("Ellipse", "Node2D", preload("./shapes/Ellipse.gd"), null)
	add_custom_type("Arrow", "Node2D", preload("./shapes/Arrow.gd"), null)
	add_custom_type("Triangle", "Node2D", preload("./shapes/Triangle.gd"), null)
	add_custom_type("Polygon", "Node2D", preload("./shapes/Polygon.gd"), null)
	add_custom_type("Star", "Node2D", preload("./shapes/Star.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("Rectangle")
	remove_custom_type("Ellipse")
	remove_custom_type("Arrow")
	remove_custom_type("Triangle")
	remove_custom_type("Polygon")
	remove_custom_type("Star")

