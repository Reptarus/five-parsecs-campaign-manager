class_name StatusEffect
extends Resource

const Character = preload("res://src/core/character/Base/Character.gd")

enum StatusEffectType {
    STUN,
    POISON,
    BUFF,
    DEBUFF,
    NEUTRAL,
    REGENERATION,
    SHIELD
}

@export var type: StatusEffectType = StatusEffectType.STUN
@export var duration: int = 1
@export var intensity: int = 1

func _init(_type: StatusEffectType = StatusEffectType.STUN, _duration: int = 1, _intensity: int = 1) -> void:
    type = _type
    duration = max(1, _duration)
    intensity = max(1, _intensity)

func process(character: Character) -> void:
    if not character:
        push_error("Character is required for status effect processing")
        return
        
    match type:
        StatusEffectType.STUN:
            process_stunned(character)
        StatusEffectType.POISON:
            process_poisoned(character)
        StatusEffectType.BUFF:
            process_buff(character)
        StatusEffectType.DEBUFF:
            process_debuff(character)
        StatusEffectType.NEUTRAL:
            process_neutral(character)
        StatusEffectType.REGENERATION:
            process_regeneration(character)
        StatusEffectType.SHIELD:
            process_shield(character)
    duration = max(0, duration - 1)

func is_expired() -> bool:
    return duration <= 0

func process_stunned(character: Character) -> void:
    character.apply_status_effect("stunned", intensity)
    character.reactions -= 1
    character.speed -= 1

func process_poisoned(character: Character) -> void:
    character.take_damage(intensity)
    character.toughness -= 1

func process_buff(character: Character) -> void:
    character.apply_status_effect("buffed", intensity)
    character.combat_skill += 1
    character.toughness += 1

func process_debuff(character: Character) -> void:
    character.apply_status_effect("debuffed", intensity)
    character.combat_skill -= 1
    character.toughness -= 1

func process_neutral(character: Character) -> void:
    character.apply_status_effect("neutral", intensity)

func process_regeneration(character: Character) -> void:
    character.heal(intensity)

func process_shield(character: Character) -> void:
    character.apply_status_effect("shielded", intensity)
    character.toughness += intensity

func serialize() -> Dictionary:
    return {
        "type": StatusEffectType.keys()[type],
        "duration": duration,
        "intensity": intensity
    }

static func deserialize(data: Dictionary) -> StatusEffect:
    return StatusEffect.new(
        StatusEffectType[data["type"]],
        data["duration"],
        data["intensity"]
    )
