## Handles tactical decision making for enemy units in combat
class_name EnemyTacticalAI
extends Node

## Signals
signal decision_made(enemy: Character, action: Dictionary)
signal tactic_changed(enemy: Character, new_tactic: int)
signal group_coordination_updated(group: Array[Character], leader: Character)

## Dependencies
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const BattlefieldManager := preload("res://src/core/battle/BattlefieldManager.gd")

## AI Personality types
enum AIPersonality {
    AGGRESSIVE,
    CAUTIOUS,
    TACTICAL,
    PROTECTIVE,
    UNPREDICTABLE
}

## Group tactics
enum GroupTactic {
    NONE,
    COORDINATED_ATTACK,
    DEFENSIVE_FORMATION,
    FLANKING_MANEUVER,
    SUPPRESSION_PATTERN
}

## References to required systems
@export var battlefield_manager: BattlefieldManager
@export var combat_manager: Node # Will be cast to CombatManager

## AI state tracking
var _enemy_personalities: Dictionary = {}
var _group_assignments: Dictionary = {}
var _tactical_states: Dictionary = {}
var _threat_assessments: Dictionary = {}

## Called when the node enters the scene tree
func _ready() -> void:
    if not battlefield_manager:
        push_warning("EnemyTacticalAI: No battlefield manager assigned")
    if not combat_manager:
        push_warning("EnemyTacticalAI: No combat manager assigned")

## Initializes AI for an enemy unit
func initialize_enemy_ai(enemy: Character, personality: AIPersonality = AIPersonality.TACTICAL) -> void:
    _enemy_personalities[enemy] = personality
    _tactical_states[enemy] = {
        "current_tactic": GlobalEnums.CombatTactic.NONE,
        "target": null,
        "group": null,
        "last_position": Vector2.ZERO,
        "threat_level": 0
    }

## Makes a tactical decision for an enemy unit
func make_tactical_decision(enemy: Character) -> Dictionary:
    if not enemy in _enemy_personalities:
        push_warning("EnemyTacticalAI: Enemy not initialized with AI")
        return {}
        
    var personality: AIPersonality = _enemy_personalities[enemy]
    var state: Dictionary = _tactical_states[enemy]
    
    # Update threat assessment
    _update_threat_assessment(enemy)
    
    # Check for group coordination
    if state.group:
        return _make_group_decision(enemy, state.group)
    
    # Make individual decision based on personality
    match personality:
        AIPersonality.AGGRESSIVE:
            return _make_aggressive_decision(enemy)
        AIPersonality.CAUTIOUS:
            return _make_cautious_decision(enemy)
        AIPersonality.TACTICAL:
            return _make_tactical_decision(enemy)
        AIPersonality.PROTECTIVE:
            return _make_protective_decision(enemy)
        AIPersonality.UNPREDICTABLE:
            return _make_unpredictable_decision(enemy)
        _:
            return _make_default_decision(enemy)

## Updates threat assessment for an enemy
func _update_threat_assessment(enemy: Character) -> void:
    var threats: Dictionary = {}
    var enemy_pos: Vector2 = battlefield_manager.get_character_position(enemy)
    
    for target in battlefield_manager.get_player_characters():
        var target_pos: Vector2 = battlefield_manager.get_character_position(target)
        var distance: float = enemy_pos.distance_to(target_pos)
        var threat_score: float = _calculate_threat_score(target, distance)
        threats[target] = threat_score
    
    _threat_assessments[enemy] = threats
    _tactical_states[enemy].threat_level = threats.values().max()

## Calculates threat score for a target
func _calculate_threat_score(target: Character, distance: float) -> float:
    var base_threat: float = target.get_combat_rating()
    var distance_factor: float = 1.0 / max(1.0, distance)
    var health_factor: float = float(target.get_health()) / float(target.get_max_health())
    
    return base_threat * distance_factor * health_factor

## Makes a decision for aggressive personality
func _make_aggressive_decision(enemy: Character) -> Dictionary:
    var state: Dictionary = _tactical_states[enemy]
    var threats: Dictionary = _threat_assessments[enemy]
    
    # Find closest high-threat target
    var best_target: Character = null
    var highest_threat: float = 0.0
    
    for target in threats:
        var threat_score: float = threats[target]
        if threat_score > highest_threat:
            highest_threat = threat_score
            best_target = target
    
    if best_target:
        return {
            "action": GlobalEnums.UnitAction.ATTACK,
            "target": best_target,
            "tactic": GlobalEnums.CombatTactic.AGGRESSIVE
        }
    
    return _make_default_decision(enemy)

## Makes a decision for cautious personality
func _make_cautious_decision(enemy: Character) -> Dictionary:
    var state: Dictionary = _tactical_states[enemy]
    var threats: Dictionary = _threat_assessments[enemy]
    
    # Find safest position with attack opportunity
    var current_pos: Vector2 = battlefield_manager.get_character_position(enemy)
    var safe_positions: Array[Vector2] = _find_safe_positions(enemy)
    
    if not safe_positions.is_empty():
        var best_pos: Vector2 = safe_positions[0]
        return {
            "action": GlobalEnums.UnitAction.MOVE,
            "position": best_pos,
            "tactic": GlobalEnums.CombatTactic.DEFENSIVE
        }
    
    return _make_default_decision(enemy)

## Makes a decision for tactical personality
func _make_tactical_decision(enemy: Character) -> Dictionary:
    var state: Dictionary = _tactical_states[enemy]
    var threats: Dictionary = _threat_assessments[enemy]
    
    # Analyze battlefield situation
    var situation: String = _analyze_battlefield_situation(enemy)
    
    match situation:
        "advantageous":
            return _make_aggressive_decision(enemy)
        "disadvantageous":
            return _make_cautious_decision(enemy)
        "neutral":
            return _make_balanced_decision(enemy)
    
    return _make_default_decision(enemy)

## Makes a decision for protective personality
func _make_protective_decision(enemy: Character) -> Dictionary:
    var state: Dictionary = _tactical_states[enemy]
    
    # Find allies to protect
    var allies: Array[Character] = _find_nearby_allies(enemy)
    var threatened_ally: Character = _find_most_threatened_ally(allies)
    
    if threatened_ally:
        return {
            "action": GlobalEnums.UnitAction.PROTECT,
            "target": threatened_ally,
            "tactic": GlobalEnums.CombatTactic.DEFENSIVE
        }
    
    return _make_default_decision(enemy)

## Makes an unpredictable decision
func _make_unpredictable_decision(enemy: Character) -> Dictionary:
    var decisions := [
        func(): return _make_aggressive_decision(enemy),
        func(): return _make_cautious_decision(enemy),
        func(): return _make_tactical_decision(enemy),
        func(): return _make_protective_decision(enemy)
    ]
    
    var random_decision = decisions[randi() % decisions.size()]
    return random_decision.call()

## Makes a default decision
func _make_default_decision(enemy: Character) -> Dictionary:
    return {
        "action": GlobalEnums.UnitAction.DEFEND,
        "tactic": GlobalEnums.CombatTactic.BALANCED
    }

## Makes a group-coordinated decision
func _make_group_decision(enemy: Character, group: Array[Character]) -> Dictionary:
    var group_state: Dictionary = _analyze_group_state(group)
    var group_tactic: GroupTactic = _determine_group_tactic(group_state)
    
    match group_tactic:
        GroupTactic.COORDINATED_ATTACK:
            return _coordinate_group_attack(enemy, group)
        GroupTactic.DEFENSIVE_FORMATION:
            return _coordinate_group_defense(enemy, group)
        GroupTactic.FLANKING_MANEUVER:
            return _coordinate_group_flanking(enemy, group)
        GroupTactic.SUPPRESSION_PATTERN:
            return _coordinate_group_suppression(enemy, group)
        _:
            return _make_default_decision(enemy)

## Finds safe positions for a unit
func _find_safe_positions(enemy: Character) -> Array[Vector2]:
    var safe_positions: Array[Vector2] = []
    var current_pos: Vector2 = battlefield_manager.get_character_position(enemy)
    var movement_range: int = enemy.get_movement_range()
    
    # Analyze positions within movement range
    for x in range(-movement_range, movement_range + 1):
        for y in range(-movement_range, movement_range + 1):
            var test_pos: Vector2 = Vector2(current_pos.x + x, current_pos.y + y)
            if _is_position_safe(enemy, test_pos):
                safe_positions.append(test_pos)
    
    return safe_positions

## Checks if a position is safe
func _is_position_safe(enemy: Character, position: Vector2) -> bool:
    if not battlefield_manager.is_valid_position(position):
        return false
        
    # Check for cover
    var has_cover: bool = battlefield_manager.position_has_cover(position)
    
    # Check enemy lines of sight
    var exposed_to_enemies: bool = false
    for target in battlefield_manager.get_player_characters():
        if battlefield_manager.check_line_of_sight(position, battlefield_manager.get_character_position(target)):
            exposed_to_enemies = true
            break
    
    return has_cover and not exposed_to_enemies

## Finds nearby allies
func _find_nearby_allies(enemy: Character) -> Array[Character]:
    var allies: Array[Character] = []
    var enemy_pos: Vector2 = battlefield_manager.get_character_position(enemy)
    
    for other in battlefield_manager.get_enemy_characters():
        if other == enemy:
            continue
            
        var other_pos: Vector2 = battlefield_manager.get_character_position(other)
        if enemy_pos.distance_to(other_pos) <= 5: # 5 tile radius
            allies.append(other)
    
    return allies

## Finds the most threatened ally
func _find_most_threatened_ally(allies: Array[Character]) -> Character:
    var most_threatened: Character = null
    var highest_threat: float = 0.0
    
    for ally in allies:
        var threat: float = _tactical_states.get(ally, {}).get("threat_level", 0.0)
        if threat > highest_threat:
            highest_threat = threat
            most_threatened = ally
    
    return most_threatened

## Analyzes the battlefield situation
func _analyze_battlefield_situation(enemy: Character) -> String:
    var enemy_strength: float = _calculate_force_strength([enemy])
    var player_strength: float = _calculate_force_strength(battlefield_manager.get_player_characters())
    
    var strength_ratio: float = enemy_strength / max(1.0, player_strength)
    
    if strength_ratio > 1.2:
        return "advantageous"
    elif strength_ratio < 0.8:
        return "disadvantageous"
    else:
        return "neutral"

## Calculates total force strength
func _calculate_force_strength(forces: Array[Character]) -> float:
    var total_strength := 0.0
    
    for unit in forces:
        var health_ratio := float(unit.get_health()) / float(unit.get_max_health())
        total_strength += unit.get_combat_rating() * health_ratio
    
    return total_strength

## Makes a balanced decision
func _make_balanced_decision(enemy: Character) -> Dictionary:
    var state: Dictionary = _tactical_states[enemy]
    var threats: Dictionary = _threat_assessments[enemy]
    
    # Find moderate position with both offensive and defensive options
    var current_pos: Vector2 = battlefield_manager.get_character_position(enemy)
    var safe_positions: Array[Vector2] = _find_safe_positions(enemy)
    
    if not safe_positions.is_empty():
        var best_pos: Vector2 = safe_positions[0]
        return {
            "action": GlobalEnums.UnitAction.MOVE,
            "position": best_pos,
            "tactic": GlobalEnums.CombatTactic.NONE
        }
    
    return _make_default_decision(enemy)

## Analyzes the state of a group
func _analyze_group_state(group: Array[Character]) -> Dictionary:
    var group_health := 0.0
    var group_strength := 0.0
    var group_positions: Array[Vector2] = []
    
    for member in group:
        group_health += float(member.get_health()) / float(member.get_max_health())
        group_strength += member.get_combat_rating()
        group_positions.append(battlefield_manager.get_character_position(member))
    
    return {
        "average_health": group_health / float(group.size()),
        "total_strength": group_strength,
        "positions": group_positions,
        "size": group.size()
    }

## Determines the best tactic for a group
func _determine_group_tactic(group_state: Dictionary) -> GroupTactic:
    var average_health: float = group_state.get("average_health", 0.0)
    var total_strength: float = group_state.get("total_strength", 0.0)
    var size: int = group_state.get("size", 0)
    
    if average_health > 0.7 and total_strength > 10.0:
        return GroupTactic.COORDINATED_ATTACK
    elif average_health < 0.3:
        return GroupTactic.DEFENSIVE_FORMATION
    elif size >= 3:
        return GroupTactic.FLANKING_MANEUVER
    else:
        return GroupTactic.SUPPRESSION_PATTERN

## Coordinates a group attack
func _coordinate_group_attack(enemy: Character, group: Array[Character]) -> Dictionary:
    var target := _find_best_group_target(group)
    if not target:
        return _make_default_decision(enemy)
    
    return {
        "action": GlobalEnums.UnitAction.MOVE,
        "target": target,
        "tactic": GlobalEnums.CombatTactic.AGGRESSIVE,
        "group_action": true
    }

## Coordinates group defense
func _coordinate_group_defense(enemy: Character, group: Array[Character]) -> Dictionary:
    var defensive_position := _find_best_defensive_position(group)
    
    return {
        "action": GlobalEnums.UnitAction.MOVE,
        "position": defensive_position,
        "tactic": GlobalEnums.CombatTactic.DEFENSIVE,
        "group_action": true
    }

## Coordinates group flanking
func _coordinate_group_flanking(enemy: Character, group: Array[Character]) -> Dictionary:
    var target := _find_best_group_target(group)
    if not target:
        return _make_default_decision(enemy)
    
    var flank_position := _calculate_flank_position(target, enemy)
    
    return {
        "action": GlobalEnums.UnitAction.MOVE,
        "position": flank_position,
        "target": target,
        "tactic": GlobalEnums.CombatTactic.AGGRESSIVE,
        "group_action": true
    }

## Coordinates group suppression
func _coordinate_group_suppression(enemy: Character, group: Array[Character]) -> Dictionary:
    var target := _find_best_group_target(group)
    if not target:
        return _make_default_decision(enemy)
    
    return {
        "action": GlobalEnums.UnitAction.MOVE,
        "target": target,
        "tactic": GlobalEnums.CombatTactic.DEFENSIVE,
        "suppressing": true,
        "group_action": true
    }

## Finds the best target for a group
func _find_best_group_target(group: Array[Character]) -> Character:
    var best_target: Character = null
    var highest_priority := 0.0
    
    for target in battlefield_manager.get_player_characters():
        var priority := _calculate_group_target_priority(target, group)
        if priority > highest_priority:
            highest_priority = priority
            best_target = target
    
    return best_target

## Calculates target priority for a group
func _calculate_group_target_priority(target: Character, group: Array[Character]) -> float:
    var priority: float = 0.0
    var target_pos: Vector2 = battlefield_manager.get_character_position(target)
    
    for member in group:
        var member_pos: Vector2 = battlefield_manager.get_character_position(member)
        var distance: float = member_pos.distance_to(target_pos)
        priority += _calculate_threat_score(target, distance)
    
    return priority / float(group.size())

## Finds best defensive position for a group
func _find_best_defensive_position(group: Array[Character]) -> Vector2:
    var center := Vector2.ZERO
    
    for member in group:
        center += battlefield_manager.get_character_position(member)
    
    center /= float(group.size())
    
    # Find nearest position with cover
    var best_pos := center
    var best_cover := 0.0
    
    for x in range(-5, 6):
        for y in range(-5, 6):
            var test_pos := Vector2(center.x + x, center.y + y)
            if battlefield_manager.is_valid_position(test_pos):
                var cover := battlefield_manager.get_cover_value(test_pos)
                if cover > best_cover:
                    best_cover = cover
                    best_pos = test_pos
    
    return best_pos

## Calculates flanking position
func _calculate_flank_position(target: Character, flanker: Character) -> Vector2:
    var target_pos: Vector2 = battlefield_manager.get_character_position(target)
    var flanker_pos: Vector2 = battlefield_manager.get_character_position(flanker)
    
    # Calculate position behind target
    var direction: Vector2 = (target_pos - flanker_pos).normalized()
    var flank_pos: Vector2 = target_pos + direction * 3.0 # 3 tiles behind target
    
    # Ensure position is valid
    if not battlefield_manager.is_valid_position(flank_pos):
        return _find_nearest_valid_position(flank_pos)
    
    return flank_pos

## Finds nearest valid position
func _find_nearest_valid_position(position: Vector2) -> Vector2:
    var radius := 1
    var max_radius := 5
    
    while radius <= max_radius:
        for x in range(-radius, radius + 1):
            for y in range(-radius, radius + 1):
                var test_pos := Vector2(position.x + x, position.y + y)
                if battlefield_manager.is_valid_position(test_pos):
                    return test_pos
        radius += 1
    
    return position # Return original position if no valid position found