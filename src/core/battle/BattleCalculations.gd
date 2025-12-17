class_name BattleCalculations
extends RefCounted

## Pure calculation functions for Five Parsecs battle system
## All functions are static and have no dependencies - fully testable without scene tree
##
## Usage:
##   var hit_chance = BattleCalculations.calculate_hit_chance(attacker, target, range_inches)
##   var damage = BattleCalculations.calculate_damage(weapon, target_toughness)
##   var result = BattleCalculations.resolve_attack(attacker, target, weapon, roll_func)

# Combat constants (Five Parsecs core rules)
const BASE_HIT_THRESHOLD := 4  # Need 4+ on d6 to hit
const COVER_MODIFIER := -1
const ELEVATION_BONUS := 1
const POINT_BLANK_BONUS := 1  # Within 2"
const LONG_RANGE_PENALTY := -1  # Beyond weapon range

# Range bands (inches)
const POINT_BLANK_RANGE := 2
const PISTOL_RANGE := 8
const RIFLE_RANGE := 24
const SHOTGUN_RANGE := 6
const HEAVY_WEAPON_RANGE := 36

# Armor save thresholds (roll this or higher to save)
const ARMOR_SAVE_NONE := 7  # Cannot save
const ARMOR_SAVE_LIGHT := 6
const ARMOR_SAVE_COMBAT := 5
const ARMOR_SAVE_BATTLE_SUIT := 4
const ARMOR_SAVE_POWERED := 3

# Status effect thresholds
const STUN_THRESHOLD := 8
const SUPPRESS_THRESHOLD := 6

# Experience awards
const XP_PARTICIPATION := 1
const XP_VICTORY_BONUS := 2
const XP_DEFEAT_BONUS := 1
const XP_FIRST_KILL := 1
const XP_SURVIVAL_INJURY := 1

#region Hit Calculations

## Calculate hit modifier based on attacker, target, and range
## Returns the modifier to add to dice roll
static func calculate_hit_modifier(
	attacker_combat_skill: int,
	target_in_cover: bool,
	attacker_elevated: bool,
	target_elevated: bool,
	range_inches: float,
	weapon_range: int,
	is_stunned: bool = false,
	is_suppressed: bool = false,
	has_aim_bonus: bool = false
) -> int:
	var modifier := 0

	# Combat skill bonus
	modifier += attacker_combat_skill

	# Cover penalty
	if target_in_cover:
		modifier += COVER_MODIFIER

	# Elevation modifiers
	if attacker_elevated and not target_elevated:
		modifier += ELEVATION_BONUS
	elif target_elevated and not attacker_elevated:
		modifier -= 1  # Shooting uphill

	# Range modifiers
	if range_inches <= POINT_BLANK_RANGE:
		modifier += POINT_BLANK_BONUS
	elif range_inches > weapon_range:
		modifier += LONG_RANGE_PENALTY

	# Status effects
	if is_stunned:
		modifier -= 2
	if is_suppressed:
		modifier -= 1

	# Aim bonus
	if has_aim_bonus:
		modifier += 1

	return modifier

## Calculate the threshold needed to hit (1-6 scale)
## Returns the minimum roll needed on d6 to hit
static func calculate_hit_threshold(
	attacker_combat_skill: int,
	target_in_cover: bool,
	attacker_elevated: bool,
	target_elevated: bool,
	range_inches: float,
	weapon_range: int,
	modifiers: Dictionary = {}
) -> int:
	var modifier := calculate_hit_modifier(
		attacker_combat_skill,
		target_in_cover,
		attacker_elevated,
		target_elevated,
		range_inches,
		weapon_range,
		modifiers.get("is_stunned", false),
		modifiers.get("is_suppressed", false),
		modifiers.get("has_aim_bonus", false)
	)

	# Threshold = Base - modifier (higher modifier = lower threshold = easier to hit)
	var threshold := BASE_HIT_THRESHOLD - modifier

	# Clamp to valid d6 range
	return clampi(threshold, 1, 7)  # 7 means impossible

## Check if attack hits given a dice roll
static func check_hit(roll: int, threshold: int) -> bool:
	return roll >= threshold

#endregion

#region Damage Calculations

## Calculate base damage from weapon
static func calculate_weapon_damage(
	weapon_damage: int,
	is_critical: bool = false,
	weapon_traits: Array = []
) -> int:
	var damage := weapon_damage

	# Critical hit doubles damage
	if is_critical:
		damage *= 2

	# Weapon traits
	for trait_name in weapon_traits:
		match trait_name:
			"devastating":
				damage += 1
			"piercing":
				pass  # Handled in armor calculation

	return maxi(1, damage)

## Calculate effective damage after armor
static func calculate_damage_after_armor(
	raw_damage: int,
	target_toughness: int,
	armor_penetration: int = 0
) -> int:
	var effective_toughness := maxi(0, target_toughness - armor_penetration)
	var final_damage := raw_damage - effective_toughness
	return maxi(0, final_damage)

## Calculate armor save threshold
static func get_armor_save_threshold(armor_type: String) -> int:
	match armor_type.to_lower():
		"none", "":
			return ARMOR_SAVE_NONE
		"light", "flak":
			return ARMOR_SAVE_LIGHT
		"combat", "tactical":
			return ARMOR_SAVE_COMBAT
		"battle_suit", "heavy":
			return ARMOR_SAVE_BATTLE_SUIT
		"powered", "power_armor":
			return ARMOR_SAVE_POWERED
		_:
			return ARMOR_SAVE_NONE

## Check if armor saves against damage
static func check_armor_save(roll: int, armor_type: String, damage: int = 1) -> bool:
	var threshold := get_armor_save_threshold(armor_type)

	# High damage can negate saves
	if damage >= 3:
		threshold += 1  # Harder to save against heavy damage

	return roll >= threshold

#endregion

#region Combat Resolution

## Resolve a complete ranged attack
## dice_roller should be a Callable that returns int (d6 result)
static func resolve_ranged_attack(
	attacker: Dictionary,
	target: Dictionary,
	weapon: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"hit": false,
		"critical": false,
		"damage": 0,
		"armor_saved": false,
		"wounds_inflicted": 0,
		"effects": []
	}

	# Extract stats
	var combat_skill: int = attacker.get("combat_skill", 0)
	var range_inches: float = attacker.get("range_to_target", 12.0)
	var weapon_range: int = weapon.get("range", RIFLE_RANGE)
	var weapon_damage: int = weapon.get("damage", 1)
	var weapon_traits: Array = weapon.get("traits", [])
	var penetration: int = weapon.get("penetration", 0)

	var target_in_cover: bool = target.get("in_cover", false)
	var target_toughness: int = target.get("toughness", 3)
	var target_armor: String = target.get("armor", "none")
	var attacker_elevated: bool = attacker.get("elevated", false)
	var target_elevated: bool = target.get("elevated", false)

	# Calculate hit threshold
	var hit_threshold := calculate_hit_threshold(
		combat_skill,
		target_in_cover,
		attacker_elevated,
		target_elevated,
		range_inches,
		weapon_range
	)

	# Roll to hit
	var hit_roll: int = dice_roller.call()
	result["hit_roll"] = hit_roll
	result["hit_threshold"] = hit_threshold

	if not check_hit(hit_roll, hit_threshold):
		return result

	result["hit"] = true

	# Check for critical hit (natural 6)
	if hit_roll == 6:
		result["critical"] = true

		# Critical trait: additional hit on 6
		if "critical" in weapon_traits:
			result["effects"].append("critical_extra_hit")

	# Calculate damage
	var raw_damage := calculate_weapon_damage(weapon_damage, result["critical"], weapon_traits)
	result["raw_damage"] = raw_damage

	# Check armor save
	var armor_roll: int = dice_roller.call()
	result["armor_roll"] = armor_roll

	if check_armor_save(armor_roll, target_armor, raw_damage):
		result["armor_saved"] = true
		return result

	# Apply damage
	var final_damage := calculate_damage_after_armor(raw_damage, target_toughness, penetration)
	result["damage"] = final_damage
	result["wounds_inflicted"] = final_damage

	# Check for special effects
	if "stun" in weapon_traits and final_damage > 0:
		result["effects"].append("stun")
	if "knockback" in weapon_traits and final_damage > 0:
		result["effects"].append("knockback")

	return result

## Resolve brawl (melee) combat
static func resolve_brawl(
	attacker: Dictionary,
	defender: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"attacker_hits": 0,
		"defender_hits": 0,
		"winner": "",
		"damage_to_attacker": 0,
		"damage_to_defender": 0
	}

	# Get combat skills
	var attacker_skill: int = attacker.get("combat_skill", 0)
	var defender_skill: int = defender.get("combat_skill", 0)

	# Each rolls d6 + combat skill
	var attacker_roll: int = dice_roller.call() + attacker_skill
	var defender_roll: int = dice_roller.call() + defender_skill

	result["attacker_total"] = attacker_roll
	result["defender_total"] = defender_roll

	# Compare results
	if attacker_roll > defender_roll:
		result["winner"] = "attacker"
		result["attacker_hits"] = 1
		result["damage_to_defender"] = 1
	elif defender_roll > attacker_roll:
		result["winner"] = "defender"
		result["defender_hits"] = 1
		result["damage_to_attacker"] = 1
	else:
		result["winner"] = "draw"

	return result

#endregion

#region Status Effects

## Check if attack causes stun
static func check_stun(total_damage: int, target_toughness: int) -> bool:
	return total_damage + target_toughness >= STUN_THRESHOLD

## Check if attack causes suppression
static func check_suppression(hit_occurred: bool, _weapon_traits: Array = []) -> bool:
	# Basic suppression: any hit can suppress
	return hit_occurred

## Calculate stun duration in turns
static func get_stun_duration() -> int:
	return 1

## Calculate suppression penalty
static func get_suppression_penalty() -> int:
	return -1

#endregion

#region Experience Calculations

## Calculate XP for a crew member after battle
static func calculate_crew_xp(
	participated: bool,
	battle_won: bool,
	enemies_killed: int = 0,
	survived_injury: bool = false,
	special_achievements: Array = []
) -> int:
	var xp := 0

	if not participated:
		return 0

	# Base participation XP
	xp += XP_PARTICIPATION

	# Victory/defeat bonus
	if battle_won:
		xp += XP_VICTORY_BONUS
	else:
		xp += XP_DEFEAT_BONUS

	# Kill bonus (first kill only in standard rules)
	if enemies_killed > 0:
		xp += XP_FIRST_KILL

	# Survival bonus
	if survived_injury:
		xp += XP_SURVIVAL_INJURY

	# Special achievements
	for achievement in special_achievements:
		match achievement:
			"held_objective":
				xp += 1
			"last_standing":
				xp += 2
			"leader_killed":
				xp += 1

	return xp

## Calculate total battle XP for all crew
static func calculate_battle_xp(
	crew_results: Array,  # [{id, participated, kills, injured}]
	battle_won: bool
) -> Dictionary:
	var xp_awards := {}

	for crew_data in crew_results:
		var crew_id: String = crew_data.get("id", "")
		if crew_id == "":
			continue

		var xp := calculate_crew_xp(
			crew_data.get("participated", false),
			battle_won,
			crew_data.get("kills", 0),
			crew_data.get("injured", false),
			crew_data.get("achievements", [])
		)

		xp_awards[crew_id] = xp

	return xp_awards

#endregion

#region Loot Calculations

## Calculate number of loot rolls based on battle result
static func calculate_loot_rolls(
	battle_won: bool,
	enemies_defeated: int,
	hold_field: bool
) -> int:
	if not battle_won:
		return 0

	var rolls := 1  # Base roll for victory

	# Bonus for enemy count
	if enemies_defeated >= 6:
		rolls += 1

	# Bonus for holding field
	if hold_field:
		rolls += 1

	return rolls

## Calculate credits from battle
static func calculate_battle_credits(
	base_payment: int,
	danger_pay: int,
	bonus_multiplier: float = 1.0
) -> int:
	var total := base_payment + danger_pay
	return int(total * bonus_multiplier)

#endregion

#region Initiative Calculations

## Roll to seize initiative (2d6 + highest savvy >= 9)
static func check_seize_initiative(
	die1: int,
	die2: int,
	highest_savvy: int
) -> Dictionary:
	var total := die1 + die2 + highest_savvy
	var seized := total >= 9

	return {
		"seized": seized,
		"roll_total": total,
		"die1": die1,
		"die2": die2,
		"savvy_bonus": highest_savvy
	}

#endregion

#region Reaction Dice

## Calculate reaction dice pool size
static func get_reaction_dice_count(crew_alive: int) -> int:
	return crew_alive

## Determine if action is Quick or Slow based on reaction die
static func is_quick_action(reaction_die: int) -> bool:
	return reaction_die >= 4  # 4+ is quick action

#endregion

#region Utility Functions

## Calculate distance between two positions
static func calculate_distance(pos1: Vector2, pos2: Vector2) -> float:
	return pos1.distance_to(pos2)

## Calculate distance in grid units
static func calculate_grid_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	# Manhattan distance for simple grid
	return absi(pos1.x - pos2.x) + absi(pos1.y - pos2.y)

## Check if position has line of sight (simplified)
static func has_line_of_sight(
	from_pos: Vector2i,
	to_pos: Vector2i,
	blocking_positions: Array
) -> bool:
	# Simple check: no blockers directly between
	# Real implementation would need proper raycasting
	for blocker in blocking_positions:
		if blocker is Vector2i:
			# Very simplified - just check if blocker is on the line
			if _is_between(from_pos, to_pos, blocker):
				return false
	return true

## Check if point C is between A and B (simplified)
static func _is_between(a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var cross := (c.y - a.y) * (b.x - a.x) - (c.x - a.x) * (b.y - a.y)
	if abs(cross) > 1:
		return false

	var dot := (c.x - a.x) * (b.x - a.x) + (c.y - a.y) * (b.y - a.y)
	var len_sq := (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)

	return dot >= 0 and dot <= len_sq

#endregion
