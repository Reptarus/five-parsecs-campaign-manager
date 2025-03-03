@tool
extends BaseCombatManager
class_name FiveParsecsCombatManager

## Five Parsecs implementation of the combat manager
##
## Manages combat state and coordinates combat-related systems
## specific to the Five Parsecs From Home ruleset.

## Required dependencies
var GameEnums = null
var GlobalEnums = null
const Character = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsBattleRules = preload("res://src/game/combat/FiveParsecsBattleRules.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

# Five Parsecs specific constants
const BASE_ACTION_POINTS: int = 2

## Five Parsecs specific combat state
class CombatState extends BaseCombatState:
    # Five Parsecs specific properties
    var reaction_used: bool = false
    var cover_level: int = 0
    var height_advantage: bool = false
    var flanking: bool = false
    var suppressed: bool = false
    
    func _init(char: Character) -> void:
        super._init(char)
        action_points = FiveParsecsCombatManager.BASE_ACTION_POINTS
        combat_advantage = 0 # NONE
        combat_status = 0 # NONE
        combat_tactic = 0 # NONE

## Called when the node enters the scene tree
func _ready() -> void:
    super._ready()
    
    # Try to load enums
    if ResourceLoader.exists("res://src/game/enums/GameEnums.gd"):
        GameEnums = load("res://src/game/enums/GameEnums.gd")
    
    if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd"):
        GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
    
    if not battlefield_manager:
        push_warning("FiveParsecsCombatManager: No battlefield manager assigned")

## Five Parsecs specific combat methods
func initialize_combat(combatants: Array[Character], battlefield: Node) -> void:
    # Cast to the appropriate array type
    var typed_combatants: Array = []
    for combatant in combatants:
        typed_combatants.append(combatant)
    
    _active_combatants = typed_combatants
    battlefield_manager = battlefield
    
    # Initialize combat state for each combatant
    for combatant in _active_combatants:
        var state = CombatState.new(combatant)
        _combat_positions[combatant] = state.position
        _combat_advantages[combatant] = state.combat_advantage
        _combat_statuses[combatant] = state.combat_status
    
    # Emit signal that combat state has changed
    combat_state_changed.emit({
        "active_combatants": _active_combatants,
        "positions": _combat_positions,
        "advantages": _combat_advantages,
        "statuses": _combat_statuses
    })

func update_combatant_position(character: Character, new_position: Vector2i) -> void:
    if not character in _active_combatants:
        return
    
    _combat_positions[character] = new_position
    character_position_updated.emit(character, new_position)
    
    # Check for terrain modifiers at the new position
    if _terrain_modifiers.has(new_position):
        var modifier = _terrain_modifiers[new_position]
        terrain_modifier_applied.emit(new_position, modifier)
        
        # Apply terrain effects based on modifier
        _apply_terrain_effects(character, modifier)

func _apply_terrain_effects(character: Character, terrain_modifier: int) -> void:
    # Apply Five Parsecs specific terrain effects
    match terrain_modifier:
        1: # COVER_LIGHT
            # Apply light cover effects
            pass
        2: # COVER_MEDIUM
            # Apply medium cover effects
            pass
        3: # COVER_HEAVY
            # Apply heavy cover effects
            pass
        4: # DIFFICULT
            # Apply difficult terrain effects
            pass
        5: # HAZARDOUS
            # Apply hazardous terrain effects
            pass
        6: # ELEVATED
            # Apply elevated terrain effects
            pass

func calculate_combat_result(attacker: Character, target: Character, weapon_data: Dictionary) -> Dictionary:
    if not attacker in _active_combatants or not target in _active_combatants:
        return {"result": 0} # MISS result
    
    var attacker_position = _combat_positions.get(attacker, Vector2i.ZERO)
    var target_position = _combat_positions.get(target, Vector2i.ZERO)
    var distance = attacker_position.distance_to(target_position)
    
    # Get combat modifiers
    var attacker_advantage = _combat_advantages.get(attacker, 0)
    var target_status = _combat_statuses.get(target, 0)
    
    # Create an instance of battle rules
    var battle_rules = FiveParsecsBattleRules.new()
    
    # Calculate hit chance using Five Parsecs battle rules
    var hit_chance = 50 # Default value
    
    # Apply modifiers based on distance, advantage, and status
    hit_chance += distance * -5 # Decrease hit chance with distance
    hit_chance += attacker_advantage * 10 # Increase with advantage
    hit_chance -= target_status * 5 # Decrease with target status
    
    # Apply weapon modifiers
    if weapon_data.has("accuracy"):
        hit_chance += weapon_data.accuracy
    
    # Clamp hit chance between 5% and 95%
    hit_chance = clamp(hit_chance, 5, 95)
    
    # Roll for hit
    var roll = randi() % 100 + 1
    var result = 0 # MISS result
    
    if roll <= hit_chance:
        # Calculate damage (simplified)
        var damage = 1 # Default damage
        
        if weapon_data.has("damage"):
            damage = weapon_data.damage
        
        # Determine result type based on damage
        if damage >= target.get_health() * 0.5:
            result = 3 # CRITICAL_HIT result
        else:
            result = 1 # HIT result
    elif roll <= hit_chance + 10:
        result = 2 # GRAZE result
    
    # Emit signal with combat result
    combat_result_calculated.emit(attacker, target, result)
    
    var damage_value = 0
    if result > 0:
        damage_value = weapon_data.get("damage", 1)
    
    return {
        "result": result,
        "hit_chance": hit_chance,
        "roll": roll,
        "damage": damage_value
    }

func update_combat_advantage(character: Character, advantage: int) -> void:
    if not character in _active_combatants:
        return
    
    _combat_advantages[character] = advantage
    combat_advantage_changed.emit(character, advantage)

func update_combat_status(character: Character, status: int) -> void:
    if not character in _active_combatants:
        return
    
    _combat_statuses[character] = status
    combat_status_changed.emit(character, status)

## Five Parsecs specific verification methods
func _verify_phase_consistency() -> bool:
    # Implement Five Parsecs specific phase consistency checks
    return true

func _verify_unit_states() -> bool:
    # Implement Five Parsecs specific unit state verification
    var all_valid = true
    
    for combatant in _active_combatants:
        if not _combat_positions.has(combatant):
            all_valid = false
            break
        
        if not _combat_advantages.has(combatant):
            all_valid = false
            break
        
        if not _combat_statuses.has(combatant):
            all_valid = false
            break
    
    return all_valid

func _verify_modifiers() -> bool:
    # Implement Five Parsecs specific modifier verification
    return true

## Signal handlers specific to Five Parsecs
func _on_character_activated(character: Character) -> void:
    if not character in _active_combatants:
        return
    
    # Reset action points for the activated character
    var state = CombatState.new(character)
    state.position = _combat_positions.get(character, Vector2i.ZERO)
    state.action_points = BASE_ACTION_POINTS
    state.combat_advantage = _combat_advantages.get(character, 0)
    state.combat_status = _combat_statuses.get(character, 0)
    
    # Apply house rule modifiers if any
    state.action_points = int(apply_house_rule_modifiers(state.action_points, "action_points"))
    
    # Update combat state
    _combat_positions[character] = state.position
    _combat_advantages[character] = state.combat_advantage
    _combat_statuses[character] = state.combat_status
    
    # Emit signal that combat state has changed
    combat_state_changed.emit({
        "active_character": character,
        "position": state.position,
        "action_points": state.action_points,
        "advantage": state.combat_advantage,
        "status": state.combat_status
    })

func _on_character_deactivated(character: Character) -> void:
    if not character in _active_combatants:
        return
    
    # Reset reaction flag for the deactivated character
    var state = CombatState.new(character)
    state.position = _combat_positions.get(character, Vector2i.ZERO)
    state.action_points = 0 # No actions left
    state.combat_advantage = _combat_advantages.get(character, 0)
    state.combat_status = _combat_statuses.get(character, 0)
    state.reaction_used = false
    
    # Update combat state
    _combat_positions[character] = state.position
    _combat_advantages[character] = state.combat_advantage
    _combat_statuses[character] = state.combat_status
    
    # Emit signal that combat state has changed
    combat_state_changed.emit({
        "active_character": character,
        "position": state.position,
        "action_points": state.action_points,
        "advantage": state.combat_advantage,
        "status": state.combat_status
    })