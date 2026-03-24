class_name FPCM_BattlefieldRenderer
extends Node3D

## Renders a battlefield grid data structure into a 3D scene.
## Creates visual representations of terrain, cover, and objectives.

@export var cell_size: float = 1.0
@export var base_material: Material

# Internal state
var current_grid_data: Dictionary = {}
var feature_nodes: Dictionary = {}

func _ready() -> void:
	# Create a default material if one isn't assigned
	if not base_material:
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = UIColors.COLOR_TEXT_SECONDARY

## Public API: Main rendering function
func render_battlefield(grid_data: Dictionary) -> void:
	clear_battlefield()
	self.current_grid_data = grid_data

	if not grid_data.has("grid") or typeof(grid_data.grid) != TYPE_ARRAY:
		push_error("Invalid grid data provided to renderer.")
		return

	var grid = grid_data.grid
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var cell = grid[y][x]
			var world_pos = _grid_to_world(Vector2i(x, y))

			# Render base terrain
			if cell.base_terrain:
				_render_feature(cell.base_terrain, world_pos)

			# Render feature
			if cell.feature:
				_render_feature(cell.feature, world_pos)

			# Render objective
			if cell.objective:
				_render_feature(cell.objective, world_pos, true)

## Clear the battlefield of all generated nodes
func clear_battlefield() -> void:
	for child in get_children():
		child.queue_free()
	feature_nodes.clear()
	current_grid_data = {}

## Internal Rendering Logic
func _render_feature(feature_data: Dictionary, position: Vector3, is_objective: bool = false) -> void:
	var asset_info = feature_data.get("asset")
	if not asset_info or typeof(asset_info) != TYPE_DICTIONARY:
		push_warning("Feature '%s' has no asset info, skipping render." % feature_data.get("name", "Unknown"))
		return

	var feature_node: Node3D

	match asset_info.get("type"):
		"primitive":
			feature_node = _create_primitive(asset_info)
		"scene":
			feature_node = _instance_scene(asset_info)
		"scatter_plane":
			feature_node = _create_scatter_plane(asset_info)
		_:
			push_warning("Unknown asset type: %s" % asset_info.get("type"))
			return

	if feature_node:
		feature_node.position = position
		if is_objective:
			feature_node.position.y += 0.1 # Slightly raise objectives
		add_child(feature_node)
		feature_nodes[feature_data.id] = feature_node

func _create_primitive(asset_info: Dictionary) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var shape = asset_info.get("shape", "box")
	var size = asset_info.get("size_3d", Vector3(1, 1, 1))
	var color_hex = asset_info.get("color", "#808080")

	match shape:
		"box":
			var box_mesh = BoxMesh.new()
			box_mesh.size = size
			mesh_instance.mesh = box_mesh
		"cylinder":
			var cyl_mesh = CylinderMesh.new()
			cyl_mesh.top_radius = size.x
			cyl_mesh.bottom_radius = size.x
			cyl_mesh.height = size.y
			mesh_instance.mesh = cyl_mesh
		"plane":
			# This is for the background, rendered slightly differently
			var plane_mesh = PlaneMesh.new()
			plane_mesh.size = Vector2(cell_size, cell_size)
			mesh_instance.mesh = plane_mesh
			# Position plane at the bottom
			mesh_instance.rotate_x(deg_to_rad(-90))

	# Apply material
	var material = base_material.duplicate() as StandardMaterial3D
	material.albedo_color = Color(color_hex)
    
	if asset_info.has("material") and asset_info.material.has("albedo_texture"):
		var texture = load(asset_info.material.albedo_texture)
		if texture:
			material.albedo_texture = texture

	mesh_instance.material_override = material
	return mesh_instance

func _instance_scene(asset_info: Dictionary) -> Node3D:
	var path = asset_info.get("path", "")
	if not ResourceLoader.exists(path):
		push_error("Scene file not found for asset: %s" % path)
		return null

	var scene = load(path) as PackedScene
	if scene:
		return scene.instantiate() as Node3D
	return null

func _create_scatter_plane(asset_info: Dictionary) -> Node3D:
	# This is a visual effect for difficult terrain, not a physical object
	var plane = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(cell_size, cell_size)
	plane.mesh = plane_mesh
	plane.rotate_x(deg_to_rad(-90))
	plane.position.y += 0.05 # Slightly above the base ground

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(asset_info.get("color", "#FFFFFF"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.4
	plane.material_override = material
	return plane

## Coordinate Conversion
func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)
