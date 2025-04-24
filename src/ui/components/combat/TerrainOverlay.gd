## Handles visual overlay for terrain features and dynamic effects
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node2D

const Self := "res://src/ui/components/combat/TerrainOverlay.gd" # Use string path instead of preload

## Dependencies
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainEffects := preload("res://src/core/terrain/TerrainEffects.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

## Visual settings
const EFFECT_COLORS := {
    TerrainEffects.EffectType.FIRE: Color(1.0, 0.4, 0.0, 0.6),
    TerrainEffects.EffectType.SMOKE: Color(0.7, 0.7, 0.7, 0.5),
    TerrainEffects.EffectType.RADIATION: Color(0.0, 1.0, 0.0, 0.4),
    TerrainEffects.EffectType.TOXIC_GAS: Color(0.2, 0.8, 0.2, 0.5),
    TerrainEffects.EffectType.ENERGY_FIELD: Color(0.0, 0.5, 1.0, 0.4),
    TerrainEffects.EffectType.DEBRIS: Color(0.6, 0.4, 0.2, 0.5)
}

## Terrain color mapping
var terrain_colors := {}

## References to required systems
@export var terrain_system: TerrainSystem
@export var terrain_effects: TerrainEffects

## Visual properties
@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var elevation_indicator_color: Color = Color(1.0, 1.0, 1.0, 0.7)

## References to particle systems
@onready var fire_particles: CPUParticles2D = $EffectParticles/FireParticles
@onready var smoke_particles: CPUParticles2D = $EffectParticles/SmokeParticles
@onready var radiation_particles: CPUParticles2D = $EffectParticles/RadiationParticles

## Effect particle mapping
const EFFECT_PARTICLES = {
    TerrainEffects.EffectType.FIRE: "fire_particles",
    TerrainEffects.EffectType.SMOKE: "smoke_particles",
    TerrainEffects.EffectType.RADIATION: "radiation_particles"
}

## Called when the node enters the scene tree
func _ready() -> void:
    if not terrain_system:
        push_warning("TerrainOverlay: No terrain system assigned")
    if not terrain_effects:
        push_warning("TerrainOverlay: No terrain effects system assigned")
    
    # Initialize terrain colors
    terrain_colors = {
        TerrainTypes.Type.WALL: Color(0.3, 0.3, 0.3, 1.0),
        TerrainTypes.Type.COVER_LOW: Color(0.5, 0.5, 0.5, 0.8),
        TerrainTypes.Type.COVER_HIGH: Color(0.4, 0.4, 0.4, 0.9),
        TerrainTypes.Type.WATER: Color(0.2, 0.4, 0.8, 0.6),
        TerrainTypes.Type.HAZARD: Color(0.8, 0.2, 0.2, 0.7),
        TerrainTypes.Type.DIFFICULT: Color(0.6, 0.6, 0.2, 0.6)
    }
    
    # Connect signals
    if terrain_system:
        terrain_system.terrain_modified.connect(_on_terrain_modified)
        terrain_system.elevation_changed.connect(_on_elevation_changed)
    
    if terrain_effects:
        terrain_effects.effect_applied.connect(_on_effect_applied)
        terrain_effects.effect_removed.connect(_on_effect_removed)

## Draw terrain and effects
func _draw() -> void:
    _draw_grid()
    _draw_terrain_features()
    _draw_effects()
    _draw_elevation_indicators()

## Draws the grid
func _draw_grid() -> void:
    if not terrain_system:
        return
    
    var grid_size := _get_grid_size()
    
    # Draw vertical lines
    for x in range(grid_size.x + 1):
        var start := Vector2(x * cell_size.x, 0)
        var end := Vector2(x * cell_size.x, grid_size.y * cell_size.y)
        draw_line(start, end, grid_color)
    
    # Draw horizontal lines
    for y in range(grid_size.y + 1):
        var start := Vector2(0, y * cell_size.y)
        var end := Vector2(grid_size.x * cell_size.x, y * cell_size.y)
        draw_line(start, end, grid_color)

## Draws terrain features
func _draw_terrain_features() -> void:
    if not terrain_system:
        return
    
    var features: Dictionary = terrain_system.get_terrain_features()
    for pos in features:
        var feature_type = features[pos]
        if feature_type in terrain_colors:
            var rect := _get_cell_rect(pos)
            draw_rect(rect, terrain_colors[feature_type])

## Draws active effects
func _draw_effects() -> void:
    if not terrain_effects:
        return
    
    var grid_size := _get_grid_size()
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var pos := Vector2(x, y)
            var effects := terrain_effects.get_active_effects(pos)
            for effect in effects:
                if effect in EFFECT_COLORS:
                    var rect := _get_cell_rect(pos)
                    draw_rect(rect, EFFECT_COLORS[effect])

## Draws elevation indicators
func _draw_elevation_indicators() -> void:
    if not terrain_system:
        return
    
    var features: Dictionary = terrain_system.get_terrain_features()
    for pos in features:
        var elevation: int = terrain_system.get_elevation(pos)
        if elevation > 0:
            var rect := _get_cell_rect(pos)
            var center := rect.position + rect.size / 2
            var radius: float = min(cell_size.x, cell_size.y) * 0.2
            
            for i in range(elevation):
                var offset := Vector2(i * radius * 0.5, i * radius * 0.5)
                draw_circle(center + offset, radius, elevation_indicator_color)

## Gets the cell rectangle for a grid position
func _get_cell_rect(pos: Vector2) -> Rect2:
    return Rect2(pos * cell_size, cell_size)

## Gets the grid size from the terrain system
func _get_grid_size() -> Vector2:
    if terrain_system and not terrain_system._terrain_grid.is_empty():
        return Vector2(
            terrain_system._terrain_grid.size(),
            terrain_system._terrain_grid[0].size()
        )
    return Vector2.ZERO

## Signal handlers
func _on_terrain_modified(_position: Vector2, _modifier: int) -> void:
    queue_redraw()

func _on_elevation_changed(_position: Vector2, _new_elevation: int) -> void:
    queue_redraw()

func _on_effect_applied(position: Vector2, effect_type: String) -> void:
    queue_redraw()
    var effect_enum: TerrainEffects.EffectType = TerrainEffects.EffectType.get(effect_type)
    if effect_enum != null:
        _update_particles(position, effect_enum, true)

func _on_effect_removed(position: Vector2, effect_type: String) -> void:
    queue_redraw()
    var effect_enum: TerrainEffects.EffectType = TerrainEffects.EffectType.get(effect_type)
    if effect_enum != null:
        _update_particles(position, effect_enum, false)

## Updates the overlay
func update_overlay() -> void:
    queue_redraw()

## Updates particle effects for a position
func _update_particles(position: Vector2, effect_type: TerrainEffects.EffectType, active: bool) -> void:
    if not effect_type in EFFECT_PARTICLES:
        return
    
    var particles: CPUParticles2D = get(EFFECT_PARTICLES[effect_type])
    if not particles:
        return
    
    if active:
        particles.position = position * cell_size + cell_size / 2
        particles.emission_rect_extents = cell_size / 2
        particles.emitting = true
    else:
        particles.emitting = false