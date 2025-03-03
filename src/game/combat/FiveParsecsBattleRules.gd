@tool
extends BaseBattleRules
class_name FiveParsecsBattleRules

## Five Parsecs implementation of battle rules
##
## Extends the base battle rules with Five Parsecs specific functionality

# Import game-specific enums
# Note: These paths need to be updated to match your actual enum file locations
# We're using a conditional approach to avoid errors if the files don't exist
var GameEnums = null
var GlobalEnums = null

func _ready() -> void:
    # Try to load the enum files
    if ResourceLoader.exists("res://src/core/systems/GameEnums.gd"):
        GameEnums = load("res://src/core/systems/GameEnums.gd")
    if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd"):
        GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific combat modifiers class that extends the base class
# We're using a new class to avoid property conflicts
class FiveParsecsCombatModifiers:
    # Base properties
    var cover: bool = false
    var height_advantage: bool = false
    var flanking: bool = false
    var suppressed: bool = false
    var range_modifier: float = 0.0
    var critical: bool = false
    var armor: int = 0
    
    # Five Parsecs specific properties
    var combat_advantage: int = 0 # Will be set to GameEnums.CombatAdvantage.NONE
    var combat_status: int = 0 # Will be set to GameEnums.CombatStatus.NONE
    var combat_range: int = 0 # Will be set to GameEnums.CombatRange.MEDIUM
    var combat_tactic: int = 0 # Will be set to GameEnums.CombatTactic.NONE
    
    func _init() -> void:
        # Initialize with default values
        # These will be set to the proper enum values when GameEnums is available
        pass

func _init() -> void:
    # Initialize with Five Parsecs specific values
    # Core game constants remain the same as base class
    pass

## Get the cost of an action
## @param action: The action to get the cost for
## @return: The cost of the action
func get_action_cost(action: int) -> int:
    # Note: Update these to use your actual enum values
    # For now, we'll use the base implementation
    return super.get_action_cost(action)

## Calculate the hit chance for an attack
## @param base_chance: The base hit chance
## @param modifiers: The combat modifiers
## @return: The final hit chance
func calculate_hit_chance(base_chance: float, modifiers) -> float:
    # Check if we're using our custom modifiers class
    var five_parsecs_modifiers = modifiers as FiveParsecsCombatModifiers
    if not five_parsecs_modifiers:
        # If not, use the base implementation
        if modifiers is BaseCombatModifiers:
            return super.calculate_hit_chance(base_chance, modifiers)
        # Otherwise, create a temporary BaseCombatModifiers
        var base_modifiers = BaseCombatModifiers.new()
        # Copy over the properties we can
        if modifiers.has("cover"):
            base_modifiers.cover = modifiers.cover
        if modifiers.has("height_advantage"):
            base_modifiers.height_advantage = modifiers.height_advantage
        if modifiers.has("flanking"):
            base_modifiers.flanking = modifiers.flanking
        if modifiers.has("suppressed"):
            base_modifiers.suppressed = modifiers.suppressed
        if modifiers.has("armor"):
            base_modifiers.armor = modifiers.armor
        return super.calculate_hit_chance(base_chance, base_modifiers)
    
    # Use our custom implementation
    var final_chance := base_chance
    
    # Apply standard modifiers
    if five_parsecs_modifiers.cover:
        final_chance += COVER_MODIFIER
    if five_parsecs_modifiers.height_advantage:
        final_chance += HEIGHT_MODIFIER
    if five_parsecs_modifiers.flanking:
        final_chance += FLANK_MODIFIER
    if five_parsecs_modifiers.suppressed:
        final_chance += SUPPRESSION_MODIFIER
    
    # Apply Five Parsecs specific range modifiers
    # Note: Update these to use your actual enum values
    # For now, we'll use hardcoded values
    var combat_range = five_parsecs_modifiers.combat_range
    if combat_range == 0: # POINT_BLANK
        final_chance += OPTIMAL_RANGE_BONUS
    elif combat_range == 2: # LONG
        final_chance += LONG_RANGE_PENALTY
    elif combat_range == 3: # EXTREME
        final_chance += EXTREME_RANGE_PENALTY
    
    return clampf(final_chance, MINIMUM_HIT_CHANCE, MAXIMUM_HIT_CHANCE)

## Calculate the damage for an attack
## @param base_damage: The base damage
## @param modifiers: The combat modifiers
## @return: The final damage
func calculate_damage(base_damage: int, modifiers) -> int:
    # Similar implementation as calculate_hit_chance
    # For brevity, we'll use a simplified version
    var final_damage := base_damage
    
    # Apply critical hit if applicable
    if modifiers.has("critical") and modifiers.critical:
        final_damage *= 2
    
    # Apply damage modifiers
    if modifiers.has("flanking") and modifiers.flanking:
        final_damage += 1
    if modifiers.has("height_advantage") and modifiers.height_advantage:
        final_damage += 1
    
    # Apply armor reduction if applicable
    if modifiers.has("armor"):
        final_damage = maxi(1, final_damage - modifiers.armor) # Minimum 1 damage
    
    return final_damage

## Calculate the movement cost for a distance
## @param distance: The distance to move
## @param terrain_type: The type of terrain
## @return: The movement cost
func calculate_movement_cost(distance: float, terrain_type: int) -> int:
    var cost := int(distance / BASE_MOVEMENT)
    
    # Apply terrain modifiers
    # Note: Update these to use your actual enum values
    # For now, we'll use hardcoded values
    if terrain_type == 1: # DIFFICULT_TERRAIN
        cost *= 2
    elif terrain_type == 2: # HAZARDOUS
        cost *= 2
    elif terrain_type == 3: # MOVEMENT_PENALTY
        cost += 1
    elif terrain_type == 4: # WATER_HAZARD
        cost *= 2
    
    return maxi(1, cost) # Minimum 1 movement point

## Get the result of a combat roll
## @param hit_chance: The hit chance
## @param modifiers: The combat modifiers
## @return: The combat result
func get_combat_result(hit_chance: float, modifiers) -> int:
    # Similar implementation as calculate_hit_chance
    # For brevity, we'll use a simplified version
    var roll := randf()
    
    var is_suppressed = modifiers.has("suppressed") and modifiers.suppressed
    
    if roll >= CRITICAL_THRESHOLD and not is_suppressed:
        return 1 # CRITICAL
    elif roll >= hit_chance:
        # Check for dodge if applicable
        if modifiers.has("combat_tactic") and modifiers.combat_tactic == 1 and randf() < 0.3:
            return 4 # DODGE
        return 0 # MISS
    elif roll <= GRAZE_THRESHOLD:
        # Check for block if applicable
        if modifiers.has("combat_tactic") and modifiers.combat_tactic == 2 and randf() < 0.3:
            return 5 # BLOCK
        return 2 # GRAZE
    
    return 3 # HIT