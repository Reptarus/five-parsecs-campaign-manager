class_name BattleResolver
extends RefCounted

## Thin orchestration layer that calls BattleCalculations for real combat resolution
## 
## This class provides a clean interface for BattlePhase to use real combat calculations
## instead of fake math. All actual combat math is in BattleCalculations.gd (95% complete, 79 tests pass).
##
## Usage:
##   var result = BattleResolver.resolve_battle(crew_deployed, enemies_deployed, battlefield_data, deployment_condition, dice_roller)
##   # Returns: {success: bool, crew_casualties: int, enemies_defeated: int, held_field: bool, ...}

# Safety cap to prevent infinite loops (Core Rules has no round limit —
# battles end when one side is eliminated or crew withdraws)
const _SAFETY_MAX_ROUNDS := 100

# Victory conditions (Core Rules p.119)
const HOLD_FIELD_ENEMY_THRESHOLD := 3  # Must eliminate 3+ enemies to hold field on retreat
const VICTORY_LOSS_RATIO_MULTIPLIER := 1.2  # Enemy loss% must meet/exceed crew loss% * this

# Post-battle rewards (Core Rules p.119-120)
const BATTLEFIELD_FINDS_MIN := 0
const BATTLEFIELD_FINDS_MAX := 2  # Held-field bonus finds range

# Default unit toughness (fallback for missing data)
const DEFAULT_TOUGHNESS := 3

# Deployment condition modifiers (Core Rules p.115)
const AMBUSH_HIT_BONUS := 2
const SURROUNDED_ENEMY_BONUS := 2
const SURROUNDED_CREW_PENALTY := -1
const DEFENSIVE_COVER_BONUS := 1
const HEADLONG_ASSAULT_HIT_BONUS := 1

# Range estimation (simplified combat)
const MIN_ENGAGEMENT_RANGE := 6.0  # Minimum estimated range in inches
const DEFAULT_COVER_CHANCE := 0.5  # 50% chance of cover when no battlefield data

## Main entry point - runs full battle and returns results
## 
## Args:
##   crew_deployed: Array of Character dictionaries with combat stats
##   enemies_deployed: Array of Enemy dictionaries with combat stats
##   battlefield_data: Dictionary with terrain, cover positions, deployment zones
##   deployment_condition: Dictionary with condition_id and effects
##   dice_roller: Callable that returns int (d6 result)
##
## Returns: Dictionary with combat_results matching BattlePhase.combat_results format
static func resolve_battle(
	crew_deployed: Array,
	enemies_deployed: Array,
	battlefield_data: Dictionary,
	deployment_condition: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	# Step 1: Initialize battle state
	var battle_state := initialize_battle(crew_deployed, enemies_deployed, deployment_condition)
	
	# Step 2: Execute combat rounds (no round limit per Core Rules — ends on elimination)
	var round_number := 1

	while round_number <= _SAFETY_MAX_ROUNDS:
		var round_result := execute_combat_round(
			round_number,
			battle_state["crew_units"],
			battle_state["enemy_units"],
			battlefield_data,
			battle_state["condition_effects"],
			dice_roller
		)
		
		# Update battle state with casualties
		battle_state["crew_casualties"] += round_result["crew_casualties"]
		battle_state["enemy_casualties"] += round_result["enemy_casualties"]
		
		# Check for battle end conditions (all enemies eliminated or all crew down)
		var crew_alive := _count_alive_units(battle_state["crew_units"])
		var enemies_alive := _count_alive_units(battle_state["enemy_units"])
		
		if crew_alive == 0 or enemies_alive == 0:
			break
		
		round_number += 1
	
	# Step 3: Calculate final outcome
	var outcome := calculate_battle_outcome(
		battle_state["crew_casualties"],
		battle_state["enemy_casualties"],
		crew_deployed,
		enemies_deployed
	)
	
	# Step 4: Calculate post-battle rewards
	var loot_rolls := BattleCalculations.calculate_loot_rolls(
		outcome["success"],
		battle_state["enemy_casualties"],
		outcome["held_field"]
	)
	
	# Return results in format expected by BattlePhase
	return {
		# Core outcome
		"success": outcome["success"],
		"rounds_fought": round_number,
		"crew_casualties": battle_state["crew_casualties"],
		"enemies_defeated": battle_state["enemy_casualties"],
		
		# Post-Battle data (Core Rules p.119)
		"held_field": outcome["held_field"],
		
		# Loot and rewards
		"loot_opportunities": loot_rolls,
		"battlefield_finds": randi_range(BATTLEFIELD_FINDS_MIN, BATTLEFIELD_FINDS_MAX) if outcome["held_field"] else 0,
		
		# Battle state for detailed logging (optional)
		"crew_units_final": battle_state["crew_units"],
		"enemy_units_final": battle_state["enemy_units"],
		"deployment_effects": battle_state["condition_effects"]
	}

## Initialize battle state with deployment condition effects
## 
## Args:
##   crew_deployed: Array of crew Character dictionaries
##   enemies_deployed: Array of Enemy dictionaries
##   deployment_condition: Dictionary with condition_id and effects
##
## Returns: Dictionary with initialized battle state
static func initialize_battle(
	crew_deployed: Array,
	enemies_deployed: Array,
	deployment_condition: Dictionary
) -> Dictionary:
	var battle_state := {
		"crew_units": [],
		"enemy_units": [],
		"crew_casualties": 0,
		"enemy_casualties": 0,
		"condition_effects": {},
		"round_number": 1
	}
	
	# Copy crew units and apply deployment effects
	# Sprint 26.3: Character-Everywhere - check Object first
	# Phase 49: Use effective stats (injury/implant modifiers) and fix combat→combat_skill key
	for crew in crew_deployed:
		var unit: Dictionary = {}
		if crew is Character:
			# Character object: use effective stats that include injury/implant modifiers
			unit = crew.to_dictionary()
			unit["combat_skill"] = crew.get_effective_combat_skill()
			unit["toughness"] = crew.get_effective_toughness()
			unit["reactions"] = crew.get_effective_reactions()
			unit["savvy"] = crew.get_effective_savvy()
			unit["speed"] = crew.get_effective_speed()
		elif crew is Dictionary:
			unit = crew.duplicate(true)
			# Remap "combat" → "combat_skill" if needed (BattleCalculations expects "combat_skill")
			if "combat" in unit and "combat_skill" not in unit:
				unit["combat_skill"] = unit["combat"]
		elif crew != null and crew.has_method("to_dictionary"):
			unit = crew.to_dictionary()
			if "combat" in unit and "combat_skill" not in unit:
				unit["combat_skill"] = unit["combat"]
		else:
			# Fallback for objects without to_dictionary
			unit = {"character_name": crew.character_name if "character_name" in crew else "", "toughness": crew.toughness if "toughness" in crew else DEFAULT_TOUGHNESS, "combat_skill": crew.combat if "combat" in crew else 0}
		unit["hp_current"] = unit.get("toughness", DEFAULT_TOUGHNESS)
		unit["is_stunned"] = false
		unit["is_suppressed"] = false
		unit["is_alive"] = true
		unit["kills"] = 0
		battle_state["crew_units"].append(unit)

	# Copy enemy units and apply deployment effects
	for enemy in enemies_deployed:
		var unit: Dictionary = enemy.duplicate(true) if enemy is Dictionary else {}
		unit["hp_current"] = unit.get("toughness", DEFAULT_TOUGHNESS)
		unit["is_stunned"] = false
		unit["is_suppressed"] = false
		unit["is_alive"] = true
		unit["kills"] = 0
		battle_state["enemy_units"].append(unit)
	
	# Apply deployment condition effects (e.g., "ambush" gives crew first strike)
	var condition_id: String = deployment_condition.get("condition_id", "standard")
	battle_state["condition_effects"]["condition_id"] = condition_id
	
	match condition_id:
		"ambush":
			battle_state["condition_effects"]["crew_first_strike"] = true
			battle_state["condition_effects"]["crew_hit_bonus"] = AMBUSH_HIT_BONUS
		"surrounded":
			battle_state["condition_effects"]["enemy_bonus"] = SURROUNDED_ENEMY_BONUS
			battle_state["condition_effects"]["crew_hit_penalty"] = SURROUNDED_CREW_PENALTY
		"defensive":
			battle_state["condition_effects"]["crew_cover_bonus"] = DEFENSIVE_COVER_BONUS
		"headlong_assault":
			battle_state["condition_effects"]["no_cover"] = true
			battle_state["condition_effects"]["crew_hit_bonus"] = HEADLONG_ASSAULT_HIT_BONUS
		_:
			# Standard deployment - no special effects
			pass
	
	return battle_state

## Execute one combat round using BattleCalculations
## 
## Args:
##   round_number: Current round number (1-6)
##   crew_units: Array of crew unit dictionaries (with hp_current, is_stunned, etc.)
##   enemy_units: Array of enemy unit dictionaries
##   battlefield_data: Dictionary with terrain and cover info
##   condition_effects: Dictionary with deployment condition bonuses/penalties
##   dice_roller: Callable for d6 rolls
##
## Returns: Dictionary with round results {crew_casualties: int, enemy_casualties: int, events: Array}
static func execute_combat_round(
	round_number: int,
	crew_units: Array,
	enemy_units: Array,
	battlefield_data: Dictionary,
	condition_effects: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var round_result := {
		"crew_casualties": 0,
		"enemy_casualties": 0,
		"events": []
	}
	
	# Step 1: Check initiative (Core Rules p.117 - seize initiative 2d6 + highest Savvy >= 10)
	var crew_has_initiative := _check_initiative(crew_units, dice_roller)
	if condition_effects.get("crew_first_strike", false):
		crew_has_initiative = true  # Ambush always gives initiative
	
	# Step 2: Determine action order
	var first_units: Array = crew_units if crew_has_initiative else enemy_units
	var second_units: Array = enemy_units if crew_has_initiative else crew_units
	var first_is_crew := crew_has_initiative
	
	# Step 3: First side attacks
	var first_results := _execute_unit_attacks(
		first_units,
		second_units,
		first_is_crew,
		battlefield_data,
		condition_effects,
		dice_roller
	)
	
	if first_is_crew:
		round_result["enemy_casualties"] += first_results["casualties"]
	else:
		round_result["crew_casualties"] += first_results["casualties"]
	
	round_result["events"].append_array(first_results["events"])
	
	# Step 4: Second side attacks (if any units alive)
	var second_alive := _count_alive_units(second_units)
	if second_alive > 0:
		var second_results := _execute_unit_attacks(
			second_units,
			first_units,
			not first_is_crew,
			battlefield_data,
			condition_effects,
			dice_roller
		)
		
		if first_is_crew:
			round_result["crew_casualties"] += second_results["casualties"]
		else:
			round_result["enemy_casualties"] += second_results["casualties"]
		
		round_result["events"].append_array(second_results["events"])
	
	# Step 5: Clear temporary status effects at end of round
	_clear_round_status(crew_units)
	_clear_round_status(enemy_units)

	# Sprint 26.5: Debug log combat round summary
	var crew_alive := _count_alive_units(crew_units)
	var enemy_alive := _count_alive_units(enemy_units)
	_debug_log_combat_round(round_number, crew_alive, enemy_alive, round_result["crew_casualties"], round_result["enemy_casualties"], crew_has_initiative)

	return round_result

## Execute attacks for one side's units against the other side
static func _execute_unit_attacks(
	attackers: Array,
	defenders: Array,
	attackers_are_crew: bool,
	battlefield_data: Dictionary,
	condition_effects: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"casualties": 0,
		"events": []
	}
	
	for attacker in attackers:
		if not attacker.get("is_alive", false):
			continue
		
		# Find alive target
		var target := _find_alive_target(defenders)
		if target == null or target.is_empty():
			break
		
		# Prepare attack context
		var weapon: Dictionary = attacker.get("weapon", {})
		var range_inches: float = _estimate_range(attacker, target, battlefield_data)
		
		# Apply deployment condition modifiers
		var hit_modifier := 0
		if attackers_are_crew:
			hit_modifier += condition_effects.get("crew_hit_bonus", 0)
			hit_modifier += condition_effects.get("crew_hit_penalty", 0)
		else:
			hit_modifier += condition_effects.get("enemy_bonus", 0)
		
		# Set context for BattleCalculations
		attacker["range_to_target"] = range_inches
		target["in_cover"] = _has_cover(target, battlefield_data, condition_effects)
		
		# Resolve attack using BattleCalculations
		var attack_result := BattleCalculations.resolve_ranged_attack(
			attacker,
			target,
			weapon,
			dice_roller
		)
		
		# Apply damage if hit
		if attack_result["hit"] and not attack_result.get("armor_saved", false):
			var damage: int = attack_result.get("wounds_inflicted", 1)
			if not target.has("hp_current"):
				target["hp_current"] = target.get("toughness", DEFAULT_TOUGHNESS)
			target["hp_current"] -= damage

			if target["hp_current"] <= 0:
				target["is_alive"] = false
				result["casualties"] += 1
				attacker["kills"] = attacker.get("kills", 0) + 1
				
				result["events"].append({
					"type": "elimination",
					"attacker": attacker.get("name", "Unknown"),
					"target": target.get("name", "Enemy"),
					"damage": damage
				})
			elif "stunned" in attack_result.get("effects", []):
				target["is_stunned"] = true
				result["events"].append({
					"type": "stunned",
					"target": target.get("name", "Unknown")
				})
		elif attack_result["hit"] and attack_result.get("armor_saved", false):
			result["events"].append({
				"type": "armor_save",
				"target": target.get("name", "Unknown")
			})
	
	return result

## Calculate final battle outcome and determine victory/defeat
## 
## Args:
##   crew_casualties: Number of crew eliminated
##   enemy_casualties: Number of enemies eliminated
##   crew_deployed: Original crew array (for size comparison)
##   enemies_deployed: Original enemy array (for size comparison)
##
## Returns: Dictionary {success: bool, held_field: bool, margin_of_victory: int}
static func calculate_battle_outcome(
	crew_casualties: int,
	enemy_casualties: int,
	crew_deployed: Array,
	enemies_deployed: Array
) -> Dictionary:
	var total_crew := crew_deployed.size()
	var total_enemies := enemies_deployed.size()
	
	var crew_alive := total_crew - crew_casualties
	var enemies_alive := total_enemies - enemy_casualties
	
	# Victory condition: Eliminate all enemies OR eliminate majority with minimal losses
	var success := false
	var held_field := false
	
	if enemies_alive == 0:
		# Total victory
		success = true
		held_field = true
	elif crew_alive == 0:
		# Total defeat
		success = false
		held_field = false
	else:
		# Partial outcome - compare casualties
		var crew_loss_percent := float(crew_casualties) / float(total_crew)
		var enemy_loss_percent := float(enemy_casualties) / float(total_enemies)
		
		# Victory if enemy losses meet or exceed crew losses * multiplier
		success = enemy_loss_percent >= crew_loss_percent * VICTORY_LOSS_RATIO_MULTIPLIER
		
		# Held field if victory OR killed 3+ enemies (Core Rules p.119)
		held_field = success or enemy_casualties >= HOLD_FIELD_ENEMY_THRESHOLD
	
	var margin := enemy_casualties - crew_casualties

	# Sprint 26.5: Debug log battle outcome
	_debug_log_battle_outcome(success, crew_alive, enemies_alive, crew_casualties, enemy_casualties, held_field)

	return {
		"success": success,
		"held_field": held_field,
		"margin_of_victory": margin,
		"crew_alive": crew_alive,
		"enemies_alive": enemies_alive
	}

#region Helper Functions

## Check initiative for crew (2d6 + highest Savvy >= 10)
static func _check_initiative(crew_units: Array, dice_roller: Callable) -> bool:
	var highest_savvy := 0
	for unit in crew_units:
		if unit.get("is_alive", false):
			highest_savvy = int(max(highest_savvy, unit.get("savvy", 0)))
	
	var die1: int = dice_roller.call()
	var die2: int = dice_roller.call()
	
	var initiative_check := BattleCalculations.check_seize_initiative(die1, die2, highest_savvy)
	return initiative_check["seized"]

## Count alive units in array
static func _count_alive_units(units: Array) -> int:
	var count := 0
	for unit in units:
		if unit.get("is_alive", false):
			count += 1
	return count

## Find first alive target from defenders
static func _find_alive_target(defenders: Array) -> Dictionary:
	for defender in defenders:
		if defender.get("is_alive", false):
			return defender
	return {}

## Estimate range between attacker and target (simplified)
static func _estimate_range(attacker: Dictionary, target: Dictionary, battlefield_data: Dictionary) -> float:
	# Simplified: return weapon's optimal range
	var weapon: Dictionary = attacker.get("weapon", {})
	var weapon_range: int = weapon.get("range", 12)
	
	# Randomize actual range within weapon's effective range
	return randf_range(MIN_ENGAGEMENT_RANGE, float(weapon_range))

## Check if unit has cover based on battlefield data
static func _has_cover(
		unit: Dictionary,
		battlefield_data: Dictionary,
		condition_effects: Dictionary) -> bool:
	# Headlong assault removes all cover
	if condition_effects.get("no_cover", false):
		return false

	# Defensive cover deployment gives guaranteed cover
	if condition_effects.get("defensive_cover", false):
		return true

	# Use terrain-based cover density from JSON data pipeline
	var cover_chance: float = battlefield_data.get(
		"cover_density", DEFAULT_COVER_CHANCE)
	cover_chance = clampf(cover_chance, 0.0, 1.0)
	return randf() < cover_chance

## Clear temporary round-based status effects
static func _clear_round_status(units: Array) -> void:
	for unit in units:
		# Stun lasts 1 round
		if unit.get("is_stunned", false):
			unit["is_stunned"] = false
		# Suppression clears at end of round if not renewed
		if unit.get("is_suppressed", false):
			unit["is_suppressed"] = false

#endregion

#region Debug Logging (Sprint 26.5)
## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Combat Flow Tracing
## ═══════════════════════════════════════════════════════════════════════════════

## Debug flag - set to true to enable combat flow logging
static var DEBUG_COMBAT_FLOW := false

static func _debug_log_combat_round(round_num: int, crew_alive: int, enemy_alive: int, crew_casualties: int, enemy_casualties: int, crew_has_initiative: bool) -> void:
	## Log combat round summary
	if not DEBUG_COMBAT_FLOW:
		return
	print_verbose("│ Initiative: %s" % ("CREW" if crew_has_initiative else "ENEMY"))


static func _debug_log_battle_outcome(success: bool, crew_alive: int, enemies_alive: int, crew_casualties: int, enemies_defeated: int, held_field: bool) -> void:
	## Log final battle outcome
	if not DEBUG_COMBAT_FLOW:
		return
	print_verbose("│ BATTLE OUTCOME: %s                                     │" % ("VICTORY" if success else "DEFEAT "))
	print_verbose("│ Held Field: %s" % ("Yes" if held_field else "No"))


static func _debug_log_unit_attack(attacker_name: String, target_name: String, hit: bool, damage: int, target_status: String) -> void:
	## Log individual unit attack
	if not DEBUG_COMBAT_FLOW:
		return


static func enable_debug_logging() -> void:
	## Enable combat flow debug logging
	DEBUG_COMBAT_FLOW = true


static func disable_debug_logging() -> void:
	## Disable combat flow debug logging
	DEBUG_COMBAT_FLOW = false

#endregion
