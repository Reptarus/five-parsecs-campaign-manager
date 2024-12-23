class_name BattleRules
extends Node

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Core game constants
const BASE_MOVEMENT: int = 6  # Base movement in inches
const BASE_ACTION_POINTS: int = 2  # Base action points per turn
const BASE_ATTACK_RANGE: int = 24  # Base attack range in inches
const BASE_HIT_CHANCE: float = 0.65  # Base 65% hit chance
const BASE_DAMAGE: int = 3  # Base damage value

## Combat modifiers
const COVER_MODIFIER: float = -0.25  # -25% when target is in cover
const HEIGHT_MODIFIER: float = 0.15  # +15% when attacker has height advantage
const FLANK_MODIFIER: float = 0.2  # +20% when attacking from flank
const SUPPRESSION_MODIFIER: float = -0.2  # -20% when suppressed

## Range modifiers
const OPTIMAL_RANGE_BONUS: float = 0.1  # +10% at optimal range
const LONG_RANGE_PENALTY: float = -0.2  # -20% at long range
const EXTREME_RANGE_PENALTY: float = -0.4  # -40% at extreme range

## Status effect thresholds
const CRITICAL_THRESHOLD: float = 0.9  # 90% for critical hits
const GRAZE_THRESHOLD: float = 0.35  # 35% for graze hits
const MINIMUM_HIT_CHANCE: float = 0.05  # 5% minimum hit chance
const MAXIMUM_HIT_CHANCE: float = 0.95  # 95% maximum hit chance

## Action point costs
const MOVE_COST: int = 1
const ATTACK_COST: int = 1
const DASH_COST: int = 2
const OVERWATCH_COST: int = 2
const RELOAD_COST: int = 1

## Terrain effects
const DIFFICULT_TERRAIN_MODIFIER: float = 0.5  # Halves movement
const HAZARDOUS_TERRAIN_DAMAGE: int = 1  # Damage per turn in hazardous terrain

class CombatModifiers:
	var cover: bool = false
	var height_advantage: bool = false
	var flanking: bool = false
	var suppressed: bool = false
	var range_modifier: float = 0.0
	var critical: bool = false
	var armor: int = 0
	var combat_advantage: int = GlobalEnums.CombatAdvantage.NONE
	var combat_status: int = GlobalEnums.CombatStatus.NONE
	var combat_range: int = GlobalEnums.CombatRange.MEDIUM
	var combat_tactic: int = GlobalEnums.CombatTactic.NONE

## Static methods for rule checking
static func can_perform_action(action: int, action_points: int) -> bool:
	var cost := get_action_cost(action)
	return action_points >= cost

static func get_action_cost(action: int) -> int:
	match action:
		GlobalEnums.UnitAction.MOVE:
			return MOVE_COST
		GlobalEnums.UnitAction.ATTACK:
			return ATTACK_COST
		GlobalEnums.UnitAction.DASH:
			return DASH_COST
		GlobalEnums.UnitAction.OVERWATCH:
			return OVERWATCH_COST
		GlobalEnums.UnitAction.RELOAD:
			return RELOAD_COST
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
		GlobalEnums.CombatRange.POINT_BLANK:
			final_chance += OPTIMAL_RANGE_BONUS
		GlobalEnums.CombatRange.LONG:
			final_chance += LONG_RANGE_PENALTY
		GlobalEnums.CombatRange.EXTREME:
			final_chance += EXTREME_RANGE_PENALTY
	
	# Apply combat advantage modifiers
	match modifiers.combat_advantage:
		GlobalEnums.CombatAdvantage.MINOR:
			final_chance += 0.1
		GlobalEnums.CombatAdvantage.MAJOR:
			final_chance += 0.2
		GlobalEnums.CombatAdvantage.OVERWHELMING:
			final_chance += 0.3
	
	# Apply combat status modifiers
	match modifiers.combat_status:
		GlobalEnums.CombatStatus.PINNED:
			final_chance -= 0.2
		GlobalEnums.CombatStatus.FLANKED:
			final_chance -= 0.1
		GlobalEnums.CombatStatus.SURROUNDED:
			final_chance -= 0.3
	
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
		GlobalEnums.CombatAdvantage.MINOR:
			final_damage += 1
		GlobalEnums.CombatAdvantage.MAJOR:
			final_damage += 2
		GlobalEnums.CombatAdvantage.OVERWHELMING:
			final_damage += 3
	
	# Apply armor reduction
	final_damage = maxi(1, final_damage - modifiers.armor)  # Minimum 1 damage
	
	return final_damage

static func calculate_movement_cost(distance: float, terrain_type: int) -> int:
	var cost := int(distance / BASE_MOVEMENT)
	
	match terrain_type:
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN:
			cost *= 2
		GlobalEnums.TerrainModifier.HAZARDOUS:
			cost *= 2
		GlobalEnums.TerrainModifier.MOVEMENT_PENALTY:
			cost += 1
		GlobalEnums.TerrainModifier.WATER_HAZARD:
			cost *= 2
	
	return maxi(1, cost)  # Minimum 1 movement point

static func get_combat_result(hit_chance: float, modifiers: CombatModifiers) -> int:
	var roll := randf()
	
	if roll >= CRITICAL_THRESHOLD and not modifiers.suppressed:
		return GlobalEnums.CombatResult.CRITICAL
	elif roll >= hit_chance:
		if modifiers.combat_tactic == GlobalEnums.CombatTactic.EVASIVE and randf() < 0.3:
			return GlobalEnums.CombatResult.DODGE
		return GlobalEnums.CombatResult.MISS
	elif roll <= GRAZE_THRESHOLD:
		if modifiers.combat_tactic == GlobalEnums.CombatTactic.DEFENSIVE and randf() < 0.3:
			return GlobalEnums.CombatResult.BLOCK
		return GlobalEnums.CombatResult.GRAZE
	
	return GlobalEnums.CombatResult.HIT