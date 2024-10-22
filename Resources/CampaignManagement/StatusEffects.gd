class_name StatusEffect
extends Resource

@export var type: GlobalEnums.StatusEffectType
@export var duration: int
@export var intensity: int

func _init(_type: GlobalEnums.StatusEffectType = GlobalEnums.StatusEffectType.STUN, _duration: int = 1, _intensity: int = 1) -> void:
    type = _type
    duration = _duration
    intensity = _intensity

func process(character: Character) -> void:
    match type:
        GlobalEnums.StatusEffectType.STUN:
            process_stunned(character)
        GlobalEnums.StatusEffectType.POISON:
            process_poisoned(character)
        GlobalEnums.StatusEffectType.BUFF:
            process_buff(character)
        GlobalEnums.StatusEffectType.DEBUFF:
            process_debuff(character)
        GlobalEnums.StatusEffectType.NEUTRAL:
            process_neutral(character)
        GlobalEnums.StatusEffectType.REGENERATION:
            process_regeneration(character)
        GlobalEnums.StatusEffectType.SHIELD:
            process_shield(character)
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
        "type": GlobalEnums.StatusEffectType.keys()[type],
        "duration": duration,
        "intensity": intensity
    }

static func deserialize(data: Dictionary) -> StatusEffect:
    return StatusEffect.new(
        GlobalEnums.StatusEffectType[data["type"]],
        data["duration"],
        data["intensity"]
    )
