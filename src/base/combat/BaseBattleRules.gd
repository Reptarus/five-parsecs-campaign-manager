@tool
extends Node
class_name BaseBattleRules

## Base class for battle rules
##
## Defines the core rules and constants for the battle system.
## Game-specific implementations should extend this class.

## Core game constants
var BASE_MOVEMENT: int = 6 # Base movement in inches
var BASE_ACTION_POINTS: int = 2 # Base action points per turn
var BASE_ATTACK_RANGE: int = 24 # Base attack range in inches
var BASE_HIT_CHANCE: float = 0.65 # Base 65% hit chance
var BASE_DAMAGE: int = 3 # Base damage value

## Combat modifiers
var COVER_MODIFIER: float = -0.25 # -25% when target is in cover
var HEIGHT_MODIFIER: float = 0.15 # +15% when attacker has height advantage
var FLANK_MODIFIER: float = 0.2 # +20% when attacking from flank
var SUPPRESSION_MODIFIER: float = -0.2 # -20% when suppressed

## Range modifiers
var OPTIMAL_RANGE_BONUS: float = 0.1 # +10% at optimal range
var LONG_RANGE_PENALTY: float = -0.2 # -20% at long range
var EXTREME_RANGE_PENALTY: float = -0.4 # -40% at extreme range

## Status effect thresholds
var CRITICAL_THRESHOLD: float = 0.9 # 90% for critical hits
var GRAZE_THRESHOLD: float = 0.35 # 35% for graze hits
var MINIMUM_HIT_CHANCE: float = 0.05 # 5% minimum hit chance
var MAXIMUM_HIT_CHANCE: float = 0.95 # 95% maximum hit chance

## Action point costs
var MOVE_COST: int = 1
var ATTACK_COST: int = 1
var DEFEND_COST: int = 1
var OVERWATCH_COST: int = 2
var RELOAD_COST: int = 1
var USE_ITEM_COST: int = 1
var SPECIAL_COST: int = 2
var TAKE_COVER_COST: int = 1
var DASH_COST: int = 2
var BRAWL_COST: int = 1
var SNAP_FIRE_COST: int = 1
var END_TURN_COST: int = 0

## Terrain effects
var DIFFICULT_TERRAIN_MODIFIER: float = 0.5 # Halves movement
var HAZARDOUS_TERRAIN_DAMAGE: int = 1 # Damage per turn in hazardous terrain

## Base class for combat modifiers
class BaseCombatModifiers:
    var cover: bool = false
    var height_advantage: bool = false
    var flanking: bool = false
    var suppressed: bool = false
    var range_modifier: float = 0.0
    var critical: bool = false
    var armor: int = 0
    
    # These should be overridden in game-specific implementations
    var combat_advantage: int = 0
    var combat_status: int = 0
    var combat_range: int = 0
    var combat_tactic: int = 0

## Check if an action can be performed with the available action points
## @param action: The action to check
## @param action_points: The available action points
## @return: Whether the action can be performed
func can_perform_action(action: int, action_points: int) -> bool:
    var cost := get_action_cost(action)
    return action_points >= cost

## Get the cost of an action
## @param action: The action to get the cost for
## @return: The cost of the action
func get_action_cost(action: int) -> int:
    # This should be overridden in game-specific implementations
    # with appropriate action enums
    return 1

## Calculate the hit chance for an attack
## @param base_chance: The base hit chance
## @param modifiers: The combat modifiers
## @return: The final hit chance
func calculate_hit_chance(base_chance: float, modifiers: BaseCombatModifiers) -> float:
    var final_chance := base_chance
    
    # Apply standard modifiers
    if modifiers.cover:
        final_chance += COVER_MODIFIER
    if modifiers.height_advantage:
        final_chance += HEIGHT_MODIFIER
    if modifiers.flanking:
        final_chance += FLANK_MODIFIER
    if modifiers.suppressed:
        final_chance += SUPPRESSION_MODIFIER
    
    # Apply range modifiers - should be implemented in derived classes
    
    # Clamp final chance between minimum and maximum
    return clampf(final_chance, MINIMUM_HIT_CHANCE, MAXIMUM_HIT_CHANCE)

## Calculate the damage for an attack
## @param base_damage: The base damage
## @param modifiers: The combat modifiers
## @return: The final damage
func calculate_damage(base_damage: int, modifiers: BaseCombatModifiers) -> int:
    var final_damage := base_damage
    
    # Apply critical hit
    if modifiers.critical:
        final_damage *= 2
    
    # Apply damage modifiers
    if modifiers.flanking:
        final_damage += 1
    if modifiers.height_advantage:
        final_damage += 1
    
    # Apply combat advantage modifiers - should be implemented in derived classes
    
    # Apply armor reduction
    final_damage = maxi(1, final_damage - modifiers.armor) # Minimum 1 damage
    
    return final_damage

## Calculate the movement cost for a distance
## @param distance: The distance to move
## @param terrain_type: The type of terrain
## @return: The movement cost
func calculate_movement_cost(distance: float, terrain_type: int) -> int:
    var cost := int(distance / BASE_MOVEMENT)
    
    # Apply terrain modifiers - should be implemented in derived classes
    
    return maxi(1, cost) # Minimum 1 movement point

## Get the result of a combat roll
## @param hit_chance: The hit chance
## @param modifiers: The combat modifiers
## @return: The combat result
func get_combat_result(hit_chance: float, modifiers: BaseCombatModifiers) -> int:
    var roll := randf()
    
    if roll >= CRITICAL_THRESHOLD and not modifiers.suppressed:
        return 1 # Critical hit - should use appropriate enum in derived classes
    elif roll >= hit_chance:
        return 0 # Miss - should use appropriate enum in derived classes
    elif roll <= GRAZE_THRESHOLD:
        return 2 # Graze - should use appropriate enum in derived classes
    
    return 3 # Hit - should use appropriate enum in derived classes