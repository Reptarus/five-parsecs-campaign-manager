extends PanelContainer

signal terrain_regenerated
signal map_exported_as_png
signal map_exported_as_json

@onready var battlefield_grid = %BattlefieldGrid
@onready var map_legend = %MapLegend
@onready var regenerate_button = %RegenerateButton
@onready var export_png_button = %ExportPNGButton
@onready var export_json_button = %ExportJSONButton

var cell_size := Vector2(32, 32)
var grid_size := Vector2(24, 24)
var current_battlefield_data: Dictionary

func _ready() -> void:
	setup_buttons()
	setup_grid()

func setup_buttons() -> void:
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	export_png_button.pressed.connect(_on_export_png_pressed)
	export_json_button.pressed.connect(_on_export_json_pressed)

func setup_grid() -> void:
	battlefield_grid.custom_minimum_size = grid_size * cell_size

func update_preview(battlefield_data: Dictionary) -> void:
	current_battlefield_data = battlefield_data
	_clear_grid()
	_draw_terrain()
	_draw_objectives()
	_draw_deployment_zones()

func _clear_grid() -> void:
	for child in battlefield_grid.get_children():
		child.queue_free()

func _draw_terrain() -> void:
	for terrain in current_battlefield_data.terrain:
		var terrain_rect = ColorRect.new()
		terrain_rect.size = cell_size
		terrain_rect.position = terrain.position * cell_size
		terrain_rect.color = _get_terrain_color(terrain.type)
		battlefield_grid.add_child(terrain_rect)

func _draw_objectives() -> void:
	for objective in current_battlefield_data.objectives:
		var icon = TextureRect.new()
		icon.texture = load("res://Assets/Icons/%s.png" % objective.type)
		icon.position = objective.position * cell_size
		battlefield_grid.add_child(icon)

func _draw_deployment_zones() -> void:
	for zone in current_battlefield_data.deployment_zones:
		var zone_rect = ColorRect.new()
		zone_rect.size = zone.size * cell_size
		zone_rect.position = zone.position * cell_size
		zone_rect.color = Color(0.2, 0.2, 1.0, 0.3)
		battlefield_grid.add_child(zone_rect)

func _get_terrain_color(terrain_type: String) -> Color:
	match terrain_type:
		"cover": return Color(0.5, 0.5, 0.5)
		"difficult": return Color(0.7, 0.4, 0.1)
		"impassable": return Color(0.2, 0.2, 0.2)
		_: return Color(0.3, 0.6, 0.3)

func _on_regenerate_pressed() -> void:
	terrain_regenerated.emit()

func _on_export_png_pressed() -> void:
	map_exported_as_png.emit()

func _on_export_json_pressed() -> void:
	map_exported_as_json.emit()
