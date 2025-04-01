@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/terrain/TerrainEffects.gd")

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsTerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")

## Handles dynamic terrain effects and environmental conditions

## Signals
signal terrain_effect_applied(effect_type: String, position: Vector2, intensity: float)
signal terrain_effect_removed(effect_type: String, position: Vector2)
signal environment_condition_changed(condition: String, intensity: float)
signal hazard_damage_dealt(position: Vector2, damage: int)

## Effect types
enum EffectType {
    NONE,
    FIRE,
    SMOKE,
    RADIATION,
    TOXIC_GAS,
    ENERGY_FIELD,
    DEBRIS
}

## Effect parameters
const EFFECT_DURATIONS = {
    EffectType.FIRE: 3,
    EffectType.SMOKE: 2,
    EffectType.RADIATION: 5,
    EffectType.TOXIC_GAS: 4,
    EffectType.ENERGY_FIELD: 3,
    EffectType.DEBRIS: 2
}

const EFFECT_DAMAGE = {
    EffectType.FIRE: 2,
    EffectType.RADIATION: 1,
    EffectType.TOXIC_GAS: 1
}

## References to required systems
@export var terrain_system: Node # Will be cast to TerrainSystem
@export var battlefield_manager: Node # Will be cast to BattlefieldManager

## Effect tracking
var _active_effects: Dictionary = {} # Maps Vector2 position to Array of active effects
var _effect_timers: Dictionary = {} # Maps Vector2 position to Dictionary of effect durations
var _current_environment_conditions: Dictionary = {}

## Called when the node enters the scene tree
func _ready() -> void:
    if not terrain_system:
        push_warning("TerrainEffects: No terrain system assigned")
    if not battlefield_manager:
        push_warning("TerrainEffects: No battlefield manager assigned")

## Applies a terrain effect at a position
func apply_effect(position: Vector2, effect_type: EffectType) -> void:
    if not _active_effects.has(position):
        _active_effects[position] = []
        _effect_timers[position] = {}
    
    if not effect_type in _active_effects[position]:
        _active_effects[position].append(effect_type)
        _effect_timers[position][effect_type] = EFFECT_DURATIONS.get(effect_type, 1)
        terrain_effect_applied.emit(EffectType.keys()[effect_type], position, 1.0)

## Removes a terrain effect at a position
func remove_effect(position: Vector2, effect_type: EffectType) -> void:
    if position in _active_effects and effect_type in _active_effects[position]:
        _active_effects[position].erase(effect_type)
        _effect_timers[position].erase(effect_type)
        
        if _active_effects[position].is_empty():
            _active_effects.erase(position)
            _effect_timers.erase(position)
        
        terrain_effect_removed.emit(EffectType.keys()[effect_type], position)

## Updates effect durations and applies effects
func update_effects() -> void:
    var positions_to_update := _effect_timers.keys()
    
    for position in positions_to_update:
        var effects_to_remove: Array[EffectType] = []
        
        for effect_type in _effect_timers[position].keys():
            _effect_timers[position][effect_type] -= 1
            
            if _effect_timers[position][effect_type] <= 0:
                effects_to_remove.append(effect_type)
            else:
                _apply_effect_damage(position, effect_type)
        
        for effect in effects_to_remove:
            remove_effect(position, effect)

## Applies effect damage to characters at a position
func _apply_effect_damage(position: Vector2, effect_type: EffectType) -> void:
    if not EFFECT_DAMAGE.has(effect_type):
        return
    
    var damage: int = EFFECT_DAMAGE[effect_type]
    var characters: Array[FiveParsecsCharacter] = battlefield_manager.get_characters_at_position(position)
    
    for character in characters:
        character.take_damage(damage)
        hazard_damage_dealt.emit(position, damage)

## Sets an environment condition
func set_environment_condition(condition: String, intensity: float) -> void:
    _current_environment_conditions[condition] = intensity
    environment_condition_changed.emit(condition, intensity)

## Gets active effects at a position
func get_active_effects(position: Vector2) -> Array[EffectType]:
    return _active_effects.get(position, []).duplicate()

## Gets effect duration at a position
func get_effect_duration(position: Vector2, effect_type: EffectType) -> int:
    if position in _effect_timers and effect_type in _effect_timers[position]:
        return _effect_timers[position][effect_type]
    return 0

## Gets current environment conditions
func get_environment_conditions() -> Dictionary:
    return _current_environment_conditions.duplicate()

## Checks if a position has a specific effect
func has_effect(position: Vector2, effect_type: EffectType) -> bool:
    return position in _active_effects and effect_type in _active_effects[position]

## Gets movement penalty for a position
func get_movement_penalty(position: Vector2) -> float:
    var penalty: float = 0.0
    
    if position in _active_effects:
        for effect in _active_effects[position]:
            match effect:
                EffectType.FIRE:
                    penalty += 0.5
                EffectType.SMOKE:
                    penalty += 0.25
                EffectType.DEBRIS:
                    penalty += 0.75
    
    return penalty

## Gets visibility penalty for a position
func get_visibility_penalty(position: Vector2) -> float:
    var penalty: float = 0.0
    
    if position in _active_effects:
        for effect in _active_effects[position]:
            match effect:
                EffectType.SMOKE:
                    penalty += 0.5
                EffectType.FIRE:
                    penalty += 0.25
    
    return penalty

## Gets combat modifier for a position
func get_combat_modifier(position: Vector2) -> int:
    var modifier: int = 0
    
    if position in _active_effects:
        for effect in _active_effects[position]:
            match effect:
                EffectType.SMOKE:
                    modifier -= 2
                EffectType.ENERGY_FIELD:
                    modifier -= 1
    
    return modifier

## Spreads effects to adjacent positions
func spread_effects() -> void:
    var positions_to_spread := _active_effects.keys()
    var new_effects: Dictionary = {}
    
    for position in positions_to_spread:
        for effect_type in _active_effects[position]:
            match effect_type:
                EffectType.FIRE:
                    _spread_fire(position, new_effects)
                EffectType.TOXIC_GAS:
                    _spread_gas(position, new_effects)
    
    # Apply new effects
    for pos in new_effects:
        for effect in new_effects[pos]:
            apply_effect(pos, effect)

## Spreads fire to adjacent positions
func _spread_fire(position: Vector2, new_effects: Dictionary) -> void:
    var spread_chance := 0.3
    
    for adjacent_pos: Vector2 in _get_adjacent_positions(position):
        if randf() < spread_chance:
            if not new_effects.has(adjacent_pos):
                new_effects[adjacent_pos] = []
            new_effects[adjacent_pos].append(EffectType.FIRE)

## Spreads gas to adjacent positions
func _spread_gas(position: Vector2, new_effects: Dictionary) -> void:
    var spread_chance := 0.5
    
    for adjacent_pos: Vector2 in _get_adjacent_positions(position):
        if randf() < spread_chance:
            if not new_effects.has(adjacent_pos):
                new_effects[adjacent_pos] = []
            new_effects[adjacent_pos].append(EffectType.TOXIC_GAS)

## Gets adjacent positions
func _get_adjacent_positions(position: Vector2) -> Array[Vector2]:
    var adjacent: Array[Vector2] = []
    var offsets: Array[Vector2] = [
        Vector2(-1, 0), Vector2(1, 0),
        Vector2(0, -1), Vector2(0, 1)
    ]
    
    for offset in offsets:
        var adjacent_pos: Vector2 = position + offset
        if battlefield_manager.is_valid_position(adjacent_pos):
            adjacent.append(adjacent_pos)
    
    return adjacent