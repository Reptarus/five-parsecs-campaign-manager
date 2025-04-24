## Handles tooltips for terrain features and effects
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self := "res://src/ui/components/combat/TerrainTooltip.gd" # Use string path instead of preload

## Dependencies
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainEffects := preload("res://src/core/terrain/TerrainEffects.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

## References to required systems
@export var terrain_system: TerrainSystem
@export var terrain_effects: TerrainEffects

## References to UI elements
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var features_label: Label = $Panel/VBoxContainer/FeaturesLabel
@onready var effects_label: Label = $Panel/VBoxContainer/EffectsLabel
@onready var modifiers_label: Label = $Panel/VBoxContainer/ModifiersLabel

## Feature descriptions
var terrain_descriptions := {}

## Effect descriptions
const EFFECT_DESCRIPTIONS := {
    TerrainEffects.EffectType.FIRE: "Fire - Deals damage over time",
    TerrainEffects.EffectType.SMOKE: "Smoke - Reduces visibility",
    TerrainEffects.EffectType.RADIATION: "Radiation - Continuous damage",
    TerrainEffects.EffectType.TOXIC_GAS: "Toxic Gas - Poisonous area",
    TerrainEffects.EffectType.ENERGY_FIELD: "Energy Field - Combat penalties",
    TerrainEffects.EffectType.DEBRIS: "Debris - Slows movement"
}

func _ready() -> void:
    # Initialize terrain descriptions
    terrain_descriptions = {
        TerrainTypes.Type.WALL: "Wall - Blocks movement and line of sight",
        TerrainTypes.Type.COVER_LOW: "Low Cover - Provides partial protection",
        TerrainTypes.Type.COVER_HIGH: "High Cover - Provides significant protection",
        TerrainTypes.Type.WATER: "Water - Slows movement",
        TerrainTypes.Type.HAZARD: "Hazard - Dangerous area",
        TerrainTypes.Type.DIFFICULT: "Difficult Terrain - Hard to traverse"
    }

## Updates tooltip content for a grid position
func update_tooltip(grid_position: Vector2) -> void:
    if not terrain_system or not terrain_effects:
        hide()
        return
    
    var features := _get_terrain_features(grid_position)
    var effects := _get_active_effects(grid_position)
    var modifiers := _get_terrain_modifiers(grid_position)
    
    if features.is_empty() and effects.is_empty():
        hide()
        return
    
    title_label.text = "Position: (%d, %d)" % [grid_position.x, grid_position.y]
    
    var features_text := "Features:"
    for feature in features:
        features_text += "\n" + feature
    features_label.text = features_text
    
    var effects_text := "Effects:"
    for effect in effects:
        effects_text += "\n" + effect
    effects_label.text = effects_text
    
    var modifiers_text := "Modifiers:"
    for modifier in modifiers:
        modifiers_text += "\n" + modifier
    modifiers_label.text = modifiers_text
    
    show()

## Gets terrain feature descriptions for a position
func _get_terrain_features(position: Vector2) -> Array[String]:
    var features: Array[String] = []
    var terrain_type = terrain_system._get_terrain_at(position)
    
    if terrain_type in terrain_descriptions:
        features.append(terrain_descriptions[terrain_type])
    
    var elevation: int = terrain_system.get_elevation(position)
    if elevation > 0:
        features.append("Elevation: Level %d" % elevation)
    
    return features

## Gets active effect descriptions for a position
func _get_active_effects(position: Vector2) -> Array[String]:
    var effects: Array[String] = []
    var active_effects := terrain_effects.get_active_effects(position)
    
    for effect in active_effects:
        if effect in EFFECT_DESCRIPTIONS:
            var duration := terrain_effects.get_effect_duration(position, effect)
            effects.append("%s (%d turns)" % [EFFECT_DESCRIPTIONS[effect], duration])
    
    return effects

## Gets terrain modifier descriptions for a position
func _get_terrain_modifiers(position: Vector2) -> Array[String]:
    var modifiers: Array[String] = []
    
    var movement_penalty := terrain_effects.get_movement_penalty(position)
    if movement_penalty > 0:
        modifiers.append("Movement: -%d%%" % (movement_penalty * 100))
    
    var visibility_penalty := terrain_effects.get_visibility_penalty(position)
    if visibility_penalty > 0:
        modifiers.append("Visibility: -%d%%" % (visibility_penalty * 100))
    
    var combat_modifier := terrain_effects.get_combat_modifier(position)
    if combat_modifier != 0:
        modifiers.append("Combat: %+d" % combat_modifier)
    
    return modifiers

## Sets tooltip position near the mouse
func set_tooltip_position(mouse_position: Vector2) -> void:
    # Add some offset to prevent tooltip from appearing under the cursor
    var offset := Vector2(10, 10)
    position = mouse_position + offset
    
    # Ensure tooltip stays within view
    var viewport_size := get_viewport_rect().size
    if position.x + size.x > viewport_size.x:
        position.x = viewport_size.x - size.x
    if position.y + size.y > viewport_size.y:
        position.y = viewport_size.y - size.y