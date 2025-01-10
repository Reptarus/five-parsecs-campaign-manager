class_name BattleEventTypes
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Event definitions with their effects and requirements
const BATTLE_EVENTS = {
    "CRITICAL_HIT": {
        "category": GameEnums.EventCategory.COMBAT,
        "probability": 0.15,
        "effect": {
            "type": "damage_multiplier",
            "value": 2.0
        },
        "requirements": ["attack_roll >= 6"]
    },
    "WEAPON_JAM": {
        "category": GameEnums.EventCategory.EQUIPMENT,
        "probability": 0.1,
        "effect": {
            "type": "disable_weapon",
            "duration": 1
        },
        "requirements": ["has_ranged_weapon", "attack_roll <= 1"]
    },
    "TAKE_COVER": {
        "category": GameEnums.EventCategory.TACTICAL,
        "probability": 0.2,
        "effect": {
            "type": "defense_bonus",
            "value": 2,
            "duration": 1
        },
        "requirements": ["near_cover"]
    },
    # Add more Core Rules events...
}

# Event trigger conditions
static func check_event_requirements(event_name: String, context: Dictionary) -> bool:
    if not BATTLE_EVENTS.has(event_name):
        return false
        
    var event = BATTLE_EVENTS[event_name]
    for requirement in event.requirements:
        if not _evaluate_requirement(requirement, context):
            return false
    
    return true

static func _evaluate_requirement(requirement: String, context: Dictionary) -> bool:
    var parts = requirement.split(" ")
    match parts[0]:
        "attack_roll":
            var roll = context.get("attack_roll", 0)
            return _compare_value(roll, parts[1], parts[2].to_int())
        "has_ranged_weapon":
            return context.get("has_ranged_weapon", false)
        "near_cover":
            return context.get("near_cover", false)
        _:
            push_warning("Unknown requirement: " + requirement)
            return false

static func _compare_value(value: float, operator: String, target: float) -> bool:
    match operator:
        ">=": return value >= target
        "<=": return value <= target
        ">": return value > target
        "<": return value < target
        "==": return value == target
        _: return false