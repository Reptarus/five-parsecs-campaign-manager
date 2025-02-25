class_name FiveParsecsBattleRules
extends Node

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Core game constants
const BASE_MOVEMENT: int = 6 # Base movement in inches
const BASE_ACTION_POINTS: int = 2 # Base action points per turn
const BASE_ATTACK_RANGE: int = 24 # Base attack range in inches
const BASE_HIT_CHANCE: float = 0.65 # Base 65% hit chance
const BASE_DAMAGE: int = 3 # Base damage value

## Combat modifiers
const COVER_MODIFIER: float = -0.25 # -25% when target is in cover
const HEIGHT_MODIFIER: float = 0.15 # +15% when attacker has height advantage
const FLANK_MODIFIER: float = 0.2 # +20% when attacking from flank
const SUPPRESSION_MODIFIER: float = -0.2 # -20% when suppressed

## Range modifiers
const OPTIMAL_RANGE_BONUS: float = 0.1 # +10% at optimal range
const LONG_RANGE_PENALTY: float = -0.2 # -20% at long range
const EXTREME_RANGE_PENALTY: float = -0.4 # -40% at extreme range

## Status effect thresholds
const CRITICAL_THRESHOLD: float = 0.9 # 90% for critical hits
const GRAZE_THRESHOLD: float = 0.35 # 35% for graze hits
const MINIMUM_HIT_CHANCE: float = 0.05 # 5% minimum hit chance
const MAXIMUM_HIT_CHANCE: float = 0.95 # 95% maximum hit chance

## Action point costs
const MOVE_COST: int = 1
const ATTACK_COST: int = 1
const DEFEND_COST: int = 1
const OVERWATCH_COST: int = 2
const RELOAD_COST: int = 1
const USE_ITEM_COST: int = 1
const SPECIAL_COST: int = 2
const TAKE_COVER_COST: int = 1
const DASH_COST: int = 2
const BRAWL_COST: int = 1
const SNAP_FIRE_COST: int = 1
const END_TURN_COST: int = 0

## Terrain effects
const DIFFICULT_TERRAIN_MODIFIER: float = 0.5 # Halves movement
const HAZARDOUS_TERRAIN_DAMAGE: int = 1 # Damage per turn in hazardous terrain

class CombatModifiers:
	var cover: bool = false
	var height_advantage: bool = false
	var flanking: bool = false
	var suppressed: bool = false
	var range_modifier: float = 0.0
	var critical: bool = false
	var armor: int = 0
	var combat_advantage: int = GameEnums.CombatAdvantage.NONE
	var combat_status: int = GameEnums.CombatStatus.NONE
	var combat_range: int = GameEnums.CombatRange.MEDIUM
	var combat_tactic: int = GameEnums.CombatTactic.NONE

## Static methods for rule checking
static func can_perform_action(action: int, action_points: int) -> bool:
	var cost := get_action_cost(action)
	return action_points >= cost

static func get_action_cost(action: int) -> int:
	match action:
		GameEnums.UnitAction.MOVE:
			return MOVE_COST
		GameEnums.UnitAction.ATTACK:
			return ATTACK_COST
		GameEnums.UnitAction.DEFEND:
			return DEFEND_COST
		GameEnums.UnitAction.OVERWATCH:
			return OVERWATCH_COST
		GameEnums.UnitAction.RELOAD:
			return RELOAD_COST
		GameEnums.UnitAction.USE_ITEM:
			return USE_ITEM_COST
		GameEnums.UnitAction.SPECIAL:
			return SPECIAL_COST
		GameEnums.UnitAction.TAKE_COVER:
			return TAKE_COVER_COST
		GameEnums.UnitAction.DASH:
			return DASH_COST
		GameEnums.UnitAction.BRAWL:
			return BRAWL_COST
		GameEnums.UnitAction.SNAP_FIRE:
			return SNAP_FIRE_COST
		GameEnums.UnitAction.END_TURN:
			return END_TURN_COST
		_:
			return 1

static func calculate_hit_chance(base_chance: float, modifiers: CombatModifiers) -> float:
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
	
	# Apply range modifiers
	match modifiers.combat_range:
		GameEnums.CombatRange.POINT_BLANK:
			final_chance += OPTIMAL_RANGE_BONUS
		GameEnums.CombatRange.LONG:
			final_chance += LONG_RANGE_PENALTY
		GameEnums.CombatRange.EXTREME:
			final_chance += EXTREME_RANGE_PENALTY
	
	# Clamp final chance between minimum and maximum
	return clampf(final_chance, MINIMUM_HIT_CHANCE, MAXIMUM_HIT_CHANCE)

static func calculate_damage(base_damage: int, modifiers: CombatModifiers) -> int:
	var final_damage := base_damage
	
	# Apply critical hit
	if modifiers.critical:
		final_damage *= 2
	
	# Apply damage modifiers
	if modifiers.flanking:
		final_damage += 1
	if modifiers.height_advantage:
		final_damage += 1
	
	# Apply combat advantage modifiers
	match modifiers.combat_advantage:
		GameEnums.CombatAdvantage.MINOR:
			final_damage += 1
		GameEnums.CombatAdvantage.MAJOR:
			final_damage += 2
		GameEnums.CombatAdvantage.OVERWHELMING:
			final_damage += 3
	
	# Apply armor reduction
	final_damage = maxi(1, final_damage - modifiers.armor) # Minimum 1 damage
	
	return final_damage

static func calculate_movement_cost(distance: float, terrain_type: int) -> int:
	var cost := int(distance / BASE_MOVEMENT)
	
	match terrain_type:
		GameEnums.TerrainModifier.DIFFICULT_TERRAIN:
			cost *= 2
		GameEnums.TerrainModifier.HAZARDOUS:
			cost *= 2
		GameEnums.TerrainModifier.MOVEMENT_PENALTY:
			cost += 1
		GameEnums.TerrainModifier.WATER_HAZARD:
			cost *= 2
	
	return maxi(1, cost) # Minimum 1 movement point

static func get_combat_result(hit_chance: float, modifiers: CombatModifiers) -> int:
	var roll := randf()
	
	if roll >= CRITICAL_THRESHOLD and not modifiers.suppressed:
		return GameEnums.CombatResult.CRITICAL
	elif roll >= hit_chance:
		if modifiers.combat_tactic == GameEnums.CombatTactic.EVASIVE and randf() < 0.3:
			return GameEnums.CombatResult.DODGE
		return GameEnums.CombatResult.MISS
	elif roll <= GRAZE_THRESHOLD:
		if modifiers.combat_tactic == GameEnums.CombatTactic.DEFENSIVE and randf() < 0.3:
			return GameEnums.CombatResult.BLOCK
		return GameEnums.CombatResult.GRAZE
	
	return GameEnums.CombatResult.HIT