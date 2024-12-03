class_name CharacterStats
extends Resource

# Core Rules base stats
@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0

# Core Rules derived stats
@export var max_health: int = 10
@export var current_health: int = 10
@export var morale: int = 10
@export var experience: int = 0
@export var level: int = 1

# Core Rules skill levels
@export var combat_training: int = 0
@export var technical_skill: int = 0
@export var survival_skill: int = 0
@export var medical_skill: int = 0
@export var leadership: int = 0

# Core Rules advancement tracking
var advances_available: int = 0
var skills_improved_this_level: Array[String] = []

func _init() -> void:
    reset_to_base_stats()

func reset_to_base_stats() -> void:
    reactions = 1
    speed = 4
    combat_skill = 0
    toughness = 3
    savvy = 0
    
    max_health = 10
    current_health = max_health
    morale = 10

func can_improve_stat(stat_name: String) -> bool:
    # Core Rules stat improvement limits
    match stat_name:
        "reactions": return reactions < 6
        "speed": return speed < 8
        "combat_skill": return combat_skill < 3
        "toughness": return toughness < 6
        "savvy": return savvy < 3
        _: return false

func improve_stat(stat_name: String) -> bool:
    if not can_improve_stat(stat_name):
        return false
        
    match stat_name:
        "reactions": reactions += 1
        "speed": speed += 1
        "combat_skill": combat_skill += 1
        "toughness": toughness += 1
        "savvy": savvy += 1
        _: return false
    
    return true

func can_improve_skill(skill_name: String) -> bool:
    # Core Rules skill improvement limits
    var current_level = get_skill_level(skill_name)
    return current_level < 3 and not skill_name in skills_improved_this_level

func improve_skill(skill_name: String) -> bool:
    if not can_improve_skill(skill_name):
        return false
        
    match skill_name:
        "combat_training": combat_training += 1
        "technical_skill": technical_skill += 1
        "survival_skill": survival_skill += 1
        "medical_skill": medical_skill += 1
        "leadership": leadership += 1
        _: return false
    
    skills_improved_this_level.append(skill_name)
    return true

func get_skill_level(skill_name: String) -> int:
    match skill_name:
        "combat_training": return combat_training
        "technical_skill": return technical_skill
        "survival_skill": return survival_skill
        "medical_skill": return medical_skill
        "leadership": return leadership
        _: return 0

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)

func heal(amount: int) -> void:
    current_health = min(max_health, current_health + amount)

func modify_morale(amount: int) -> void:
    morale = clamp(morale + amount, 0, 10)

func add_experience(amount: int) -> void:
    experience += amount
    check_level_up()

func check_level_up() -> void:
    # Core Rules experience thresholds
    var xp_needed = level * 100
    if experience >= xp_needed:
        level_up()

func level_up() -> void:
    level += 1
    advances_available += 1
    skills_improved_this_level.clear()

func serialize() -> Dictionary:
    return {
        "reactions": reactions,
        "speed": speed,
        "combat_skill": combat_skill,
        "toughness": toughness,
        "savvy": savvy,
        "max_health": max_health,
        "current_health": current_health,
        "morale": morale,
        "experience": experience,
        "level": level,
        "combat_training": combat_training,
        "technical_skill": technical_skill,
        "survival_skill": survival_skill,
        "medical_skill": medical_skill,
        "leadership": leadership,
        "advances_available": advances_available,
        "skills_improved_this_level": skills_improved_this_level
    }

func deserialize(data: Dictionary) -> void:
    reactions = data.get("reactions", 1)
    speed = data.get("speed", 4)
    combat_skill = data.get("combat_skill", 0)
    toughness = data.get("toughness", 3)
    savvy = data.get("savvy", 0)
    max_health = data.get("max_health", 10)
    current_health = data.get("current_health", max_health)
    morale = data.get("morale", 10)
    experience = data.get("experience", 0)
    level = data.get("level", 1)
    combat_training = data.get("combat_training", 0)
    technical_skill = data.get("technical_skill", 0)
    survival_skill = data.get("survival_skill", 0)
    medical_skill = data.get("medical_skill", 0)
    leadership = data.get("leadership", 0)
    advances_available = data.get("advances_available", 0)
    skills_improved_this_level = data.get("skills_improved_this_level", []) 