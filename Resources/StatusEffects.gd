class_name StatusEffect
extends Resource

enum EffectType {
    STUNNED,
    POISONED,
    BURNING,
    BLEEDING,
    CONFUSED,
    SHIELDED,
    ENRAGED
}

@export var type: EffectType
@export var duration: int
@export var intensity: int

func _init(_type: EffectType = EffectType.STUNNED, _duration: int = 1, _intensity: int = 1) -> void:
    type = _type
    duration = _duration
    intensity = _intensity

func process(character: Character) -> void:
    match type:
        EffectType.STUNNED:
            process_stunned(character)
        EffectType.POISONED:
            process_poisoned(character)
        EffectType.BURNING:
            process_burning(character)
        EffectType.BLEEDING:
            process_bleeding(character)
        EffectType.CONFUSED:
            process_confused(character)
        EffectType.SHIELDED:
            process_shielded(character)
        EffectType.ENRAGED:
            process_enraged(character)
    duration -= 1

func is_expired() -> bool:
    return duration <= 0

func process_stunned(character: Character) -> void:
    character.apply_status_effect("stunned", intensity)
    character.reactions -= 1
    character.speed -= 1

func process_poisoned(character: Character) -> void:
    character.take_damage(intensity)
    character.toughness -= 1

func process_burning(character: Character) -> void:
    character.take_damage(intensity * 2)
    character.speed -= 1

func process_bleeding(character: Character) -> void:
    character.take_damage(intensity)
    character.toughness -= 1

func process_confused(character: Character) -> void:
    character.apply_status_effect("confused", intensity)
    character.combat_skill -= 1
    character.savvy -= 1

func process_shielded(character: Character) -> void:
    character.apply_status_effect("shielded", intensity)
    character.toughness += intensity

func process_enraged(character: Character) -> void:
    character.apply_status_effect("enraged", intensity)
    character.combat_skill += 1
    character.toughness += 1
    character.savvy -= 1

func serialize() -> Dictionary:
    return {
        "type": EffectType.keys()[type],
        "duration": duration,
        "intensity": intensity
    }

static func deserialize(data: Dictionary) -> StatusEffect:
    return StatusEffect.new(
        EffectType[data["type"]],
        data["duration"],
        data["intensity"]
    )
