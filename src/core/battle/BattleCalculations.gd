class_name BattleCalculations
extends RefCounted

const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")

## Pure calculation functions for Five Parsecs battle system
## All functions are static and have no dependencies - fully testable without scene tree
##
## Usage:
##   var hit_chance = BattleCalculations.calculate_hit_chance(attacker, target, range_inches)
##   var damage = BattleCalculations.calculate_damage(weapon, target_toughness)
##   var result = BattleCalculations.resolve_attack(attacker, target, weapon, roll_func)

# Save Type Enum - Distinguishes between armor and screen saves (Five Parsecs rules)
# Piercing weapons ignore ARMOR saves but NOT screen saves
enum SaveType {
	NONE,      # No save available
	ARMOR,     # Physical armor - can be ignored by piercing
	SCREEN,    # Energy screen - NOT ignored by piercing
	COMBINED   # Both armor and screen present
}

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

# Screen save thresholds (NOT ignored by piercing weapons)
const SCREEN_SAVE_NONE := 7      # No screen
const SCREEN_SAVE_BASIC := 6     # Basic energy screen
const SCREEN_SAVE_MILITARY := 5  # Military-grade screen
const SCREEN_SAVE_ADVANCED := 4  # Advanced screen technology

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
	has_aim_bonus: bool = false,
	attacker_species: String = ""
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
	# Ferals ignore suppression penalties (Five Parsecs p.20)
	if is_suppressed and attacker_species.to_lower() != "feral":
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

	# Critical hit handling
	# Default (Five Parsecs rules): Critical = instant kill (very high damage)
	# HOUSE RULE brutal_combat: Critical = double damage instead
	if is_critical:
		if HouseRulesHelper.is_enabled("brutal_combat"):
			damage *= 2  # House rule: double damage on crit
		else:
			damage = 999  # Default: instant kill on crit

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
static func get_armor_save_threshold(armor_type: String, species: String = "") -> int:
	# Soulless have innate 6+ armor save (Five Parsecs p.19)
	if species.to_lower() == "soulless":
		var base_threshold = ARMOR_SAVE_LIGHT  # 6+ save
		# If they have better armor, use that instead
		var armor_threshold = ARMOR_SAVE_NONE
		match armor_type.to_lower():
			"light", "flak":
				armor_threshold = ARMOR_SAVE_LIGHT
			"combat", "tactical":
				armor_threshold = ARMOR_SAVE_COMBAT
			"battle_suit", "heavy":
				armor_threshold = ARMOR_SAVE_BATTLE_SUIT
			"powered", "power_armor":
				armor_threshold = ARMOR_SAVE_POWERED
		# Return best (lowest) threshold
		return mini(base_threshold, armor_threshold)
	
	# Standard armor saves
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

## Get screen save threshold based on screen type
static func get_screen_save_threshold(screen_type: String) -> int:
	match screen_type.to_lower():
		"none", "":
			return SCREEN_SAVE_NONE
		"basic", "personal":
			return SCREEN_SAVE_BASIC
		"military", "combat":
			return SCREEN_SAVE_MILITARY
		"advanced", "elite":
			return SCREEN_SAVE_ADVANCED
		_:
			return SCREEN_SAVE_NONE

## Check if screen saves against damage (NOT affected by piercing)
static func check_screen_save(roll: int, screen_type: String, _damage: int = 1) -> bool:
	var threshold := get_screen_save_threshold(screen_type)
	return roll >= threshold

## Get the save type for a target based on their protection
static func get_save_type(target: Dictionary) -> SaveType:
	var armor_val: String = target.get("armor", "none")
	var screen_val: String = target.get("screen", "none")
	var has_armor: bool = armor_val != "none" and armor_val != ""
	var has_screen: bool = screen_val != "none" and screen_val != ""

	if has_armor and has_screen:
		return SaveType.COMBINED
	elif has_screen:
		return SaveType.SCREEN
	elif has_armor:
		return SaveType.ARMOR
	return SaveType.NONE

## Resolve saves with proper piercing handling
## CRITICAL: Piercing ignores ARMOR saves but NOT screen saves
static func resolve_saves(
	roll: int,
	target: Dictionary,
	weapon_traits: Array,
	damage: int = 1
) -> Dictionary:
	var result := {
		"saved": false,
		"save_type_used": SaveType.NONE,
		"armor_checked": false,
		"screen_checked": false,
		"armor_pierced": false
	}

	var save_type := get_save_type(target)
	var has_piercing := "piercing" in weapon_traits

	# Check screen first (if present) - NOT affected by piercing
	if save_type == SaveType.SCREEN or save_type == SaveType.COMBINED:
		result["screen_checked"] = true
		var screen_type: String = target.get("screen", "none")
		if check_screen_save(roll, screen_type, damage):
			result["saved"] = true
			result["save_type_used"] = SaveType.SCREEN
			return result

	# Check armor (if present and not pierced)
	if save_type == SaveType.ARMOR or save_type == SaveType.COMBINED:
		result["armor_checked"] = true
		if has_piercing:
			# Piercing ignores armor saves
			result["armor_pierced"] = true
		else:
			var armor_type: String = target.get("armor", "none")
			if check_armor_save(roll, armor_type, damage):
				result["saved"] = true
				result["save_type_used"] = SaveType.ARMOR

	return result

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
		"screen_saved": false,
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

	# Check saves (screen first, then armor - piercing only ignores armor)
	var save_roll: int = dice_roller.call()
	result["armor_roll"] = save_roll  # Keep for backwards compatibility
	result["save_roll"] = save_roll

	var save_result := resolve_saves(save_roll, target, weapon_traits, raw_damage)
	result["save_result"] = save_result

	if save_result["armor_pierced"]:
		result["effects"].append("armor_pierced")

	if save_result["saved"]:
		result["save_type"] = save_result["save_type_used"]
		# Set specific save type flags
		if save_result["save_type_used"] == SaveType.SCREEN:
			result["screen_saved"] = true
		elif save_result["save_type_used"] == SaveType.ARMOR:
			result["armor_saved"] = true
		else:
			result["armor_saved"] = true  # Default for backwards compatibility
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

## Resolve brawl (melee) combat with full Five Parsecs rules
## K'Erin special: Roll twice, use better result
## Weapon bonuses: Melee +2, Pistol +1
## Natural 6: Inflicts extra hit, Natural 1: Suffers extra hit
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
		"damage_to_defender": 0,
		"attacker_raw_roll": 0,
		"defender_raw_roll": 0,
		"attacker_kerin_rerolled": false,
		"defender_kerin_rerolled": false,
		"attacker_rerolled": false,
		"defender_rerolled": false,
		"attacker_damage_bonus": 0,
		"defender_damage_bonus": 0,
		"effects": []
	}

	# Get combat skills and species
	var attacker_skill: int = attacker.get("combat_skill", 0)
	var defender_skill: int = defender.get("combat_skill", 0)
	var attacker_species: String = attacker.get("species", "human").to_lower()
	var defender_species: String = defender.get("species", "human").to_lower()

	# Get weapon bonuses
	var attacker_weapon_bonus := _get_brawl_weapon_bonus(attacker)
	var defender_weapon_bonus := _get_brawl_weapon_bonus(defender)

	# Species combat bonuses
	var attacker_species_bonus := _get_species_brawl_bonus(attacker_species)
	var defender_species_bonus := _get_species_brawl_bonus(defender_species)

	# Get weapon traits for Elegant trait check
	var attacker_traits: Array = attacker.get("weapon_traits", [])
	var defender_traits: Array = defender.get("weapon_traits", [])

	# Roll for attacker (K'Erin rolls twice, uses better)
	var attacker_first_roll: int = dice_roller.call()
	var attacker_natural: int = attacker_first_roll
	if _is_kerin(attacker_species):
		var attacker_second_roll: int = dice_roller.call()
		# K'Erin takes the better of two rolls
		attacker_natural = maxi(attacker_first_roll, attacker_second_roll)
		result["attacker_kerin_rerolled"] = true
		result["effects"].append("kerin_brawl_reroll")
	# Elegant trait: reroll if rolled < 4
	elif "elegant" in attacker_traits and attacker_first_roll < 4:
		attacker_natural = dice_roller.call()
		result["attacker_rerolled"] = true
		result["effects"].append("elegant_reroll")

	# Roll for defender (K'Erin rolls twice, uses better)
	var defender_first_roll: int = dice_roller.call()
	var defender_natural: int = defender_first_roll
	if _is_kerin(defender_species):
		var defender_second_roll: int = dice_roller.call()
		# K'Erin takes the better of two rolls
		defender_natural = maxi(defender_first_roll, defender_second_roll)
		result["defender_kerin_rerolled"] = true
		result["effects"].append("kerin_brawl_reroll_defense")
	# Elegant trait: reroll if rolled < 4
	elif "elegant" in defender_traits and defender_first_roll < 4:
		defender_natural = dice_roller.call()
		result["defender_rerolled"] = true
		result["effects"].append("elegant_reroll_defense")

	result["attacker_raw_roll"] = attacker_natural
	result["defender_raw_roll"] = defender_natural

	# Calculate totals
	var attacker_total: int = attacker_natural + attacker_skill + attacker_weapon_bonus + attacker_species_bonus
	var defender_total: int = defender_natural + defender_skill + defender_weapon_bonus + defender_species_bonus

	result["attacker_total"] = attacker_total
	result["defender_total"] = defender_total
	result["attacker_weapon_bonus"] = attacker_weapon_bonus
	result["defender_weapon_bonus"] = defender_weapon_bonus
	result["attacker_species_bonus"] = attacker_species_bonus
	result["defender_species_bonus"] = defender_species_bonus

	# Determine winner
	if attacker_total > defender_total:
		result["winner"] = "attacker"
		result["attacker_hits"] = 1
		result["damage_to_defender"] = 1

		# Natural 6: Extra hit for attacker
		if attacker_natural == 6:
			result["attacker_hits"] += 1
			result["damage_to_defender"] += 1
			result["effects"].append("natural_6_extra_hit")

		# Natural 1: Attacker suffers hit even when winning
		if attacker_natural == 1:
			result["defender_hits"] += 1
			result["damage_to_attacker"] += 1
			result["effects"].append("natural_1_penalty")

	elif defender_total > attacker_total:
		result["winner"] = "defender"
		result["defender_hits"] = 1
		result["damage_to_attacker"] = 1

		# Natural 6: Extra hit for defender
		if defender_natural == 6:
			result["defender_hits"] += 1
			result["damage_to_attacker"] += 1
			result["effects"].append("natural_6_extra_hit_defense")

		# Natural 1: Defender suffers hit even when winning
		if defender_natural == 1:
			result["attacker_hits"] += 1
			result["damage_to_defender"] += 1
			result["effects"].append("natural_1_penalty_defense")
	else:
		# Draw: Both combatants take a hit
		result["winner"] = "draw"
		result["attacker_hits"] = 1
		result["defender_hits"] = 1
		result["damage_to_attacker"] = 1
		result["damage_to_defender"] = 1
		result["effects"].append("draw_both_hit")

	# Apply Hulker bonus damage (+2 melee damage)
	if result["damage_to_defender"] > 0 and _is_hulker(attacker_species):
		result["attacker_damage_bonus"] = 2
		result["damage_to_defender"] += 2
		result["effects"].append("hulker_melee_bonus")

	if result["damage_to_attacker"] > 0 and _is_hulker(defender_species):
		result["defender_damage_bonus"] = 2
		result["damage_to_attacker"] += 2
		result["effects"].append("hulker_melee_bonus_defense")
	
	# Apply K'Erin bonus damage (+1 melee damage, Five Parsecs p.18)
	if result["damage_to_defender"] > 0 and _is_kerin(attacker_species):
		result["damage_to_defender"] += 1
		result["effects"].append("kerin_melee_bonus")
	
	if result["damage_to_attacker"] > 0 and _is_kerin(defender_species):
		result["damage_to_attacker"] += 1
		result["effects"].append("kerin_melee_bonus_defense")

	return result

## Get brawl weapon bonus from character's weapon
static func _get_brawl_weapon_bonus(character: Dictionary) -> int:
	var weapon_traits: Array = character.get("weapon_traits", [])

	# Melee weapon: +2 in brawl
	if "melee" in weapon_traits:
		return 2
	# Pistol: +1 in brawl
	if "pistol" in weapon_traits:
		return 1
	return 0

## Get species brawl bonus
static func _get_species_brawl_bonus(species: String) -> int:
	match species.to_lower():
		"kerin", "k'erin":
			return 1  # K'Erin get +1 in brawl
		_:
			return 0

## Check if species is K'Erin (rolls twice in brawl)
static func _is_kerin(species: String) -> bool:
	return species.to_lower() in ["kerin", "k'erin", "k_erin"]

## Check if species is Hulker (+2 melee damage)
static func _is_hulker(species: String) -> bool:
	return species.to_lower() in ["hulker", "hulkers"]

#endregion

#region Armor Modifications - All 10 armor mods with battle effects

## Check and apply all armor modification effects during combat
## Returns Dictionary with all active modification effects
static func check_armor_modifications(
	target: Dictionary,
	attack_context: Dictionary = {}
) -> Dictionary:
	var result := {
		"save_bonus": 0,
		"hit_penalty_to_attacker": 0,
		"movement_bonus": 0,
		"first_wound_negated": false,
		"environmental_immunity": false,
		"effects": []
	}

	var armor_mods: Array = target.get("armor_modifications", [])
	var used_mods: Array = target.get("_used_armor_mods_this_battle", [])

	for mod_id: Variant in armor_mods:
		var mod_name: String = mod_id if mod_id is String else str(mod_id)
		_apply_armor_mod_effect(mod_name, result, attack_context, used_mods)

	return result

## Apply individual armor modification effect
static func _apply_armor_mod_effect(
	mod_name: String,
	result: Dictionary,
	attack_context: Dictionary,
	used_mods: Array
) -> void:
	match mod_name.to_lower():
		"reinforced_plating":
			# +1 to armor save
			result["save_bonus"] += 1
			result["effects"].append("reinforced_plating_+1_save")

		"lightweight_materials":
			# No movement penalty from armor
			result["movement_bonus"] += 1
			result["effects"].append("lightweight_no_movement_penalty")

		"auto_medicator":
			# Negate first wound per battle (one-time use)
			if "auto_medicator" not in used_mods:
				result["first_wound_negated"] = true
				result["effects"].append("auto_medicator_ready")

		"stealth_coating":
			# -1 to enemy hit rolls against this target
			result["hit_penalty_to_attacker"] += 1
			result["effects"].append("stealth_coating_-1_enemy_hit")

		"enhanced_power_cells":
			# Powered armor lasts longer (extended duration)
			result["effects"].append("enhanced_power_cells_extended")

		"integrated_jetpack":
			# Alternative movement (jump capability)
			result["movement_bonus"] += 2
			result["effects"].append("jetpack_available")

		"enhanced_targeting":
			# +1 to hit (wearer's attacks)
			result["effects"].append("enhanced_targeting_+1_hit")

		"environmental_seals":
			# Immune to environmental hazards
			result["environmental_immunity"] = true
			result["effects"].append("environmental_immunity")

		"reactive_plating":
			# Additional save against explosive/area attacks
			var is_area_attack: bool = attack_context.get("is_area_attack", false)
			if is_area_attack:
				result["save_bonus"] += 2
				result["effects"].append("reactive_plating_+2_vs_area")

		"camouflage_system":
			# -1 to enemy hit at long range
			var range_band: String = attack_context.get("range_band", "medium")
			if range_band == "long":
				result["hit_penalty_to_attacker"] += 1
				result["effects"].append("camo_-1_long_range")

## Get armor modification hit modifier (penalty to attacker)
static func get_armor_mod_hit_penalty(target: Dictionary, attack_context: Dictionary = {}) -> int:
	var mods := check_armor_modifications(target, attack_context)
	return mods.get("hit_penalty_to_attacker", 0)

## Get armor modification save bonus
static func get_armor_mod_save_bonus(target: Dictionary, attack_context: Dictionary = {}) -> int:
	var mods := check_armor_modifications(target, attack_context)
	return mods.get("save_bonus", 0)

## Check if auto-medicator can negate wound
static func can_auto_medicator_negate(target: Dictionary) -> bool:
	var armor_mods: Array = target.get("armor_modifications", [])
	var used_mods: Array = target.get("_used_armor_mods_this_battle", [])
	return "auto_medicator" in armor_mods and "auto_medicator" not in used_mods

## Mark auto-medicator as used this battle
static func mark_auto_medicator_used(target: Dictionary) -> void:
	if not target.has("_used_armor_mods_this_battle"):
		target["_used_armor_mods_this_battle"] = []
	target["_used_armor_mods_this_battle"].append("auto_medicator")

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

#region Area/Template Weapons - Multi-target resolution system

## Check if weapon has area/template traits
static func is_area_weapon(weapon_traits: Array) -> bool:
	return "area" in weapon_traits or "template" in weapon_traits or "explosive" in weapon_traits or "spread" in weapon_traits

## Get targets within area radius (for Area/Explosive weapons)
## Returns array of targets within radius from impact point
static func get_targets_in_area(
	impact_pos: Vector2,
	radius_inches: float,
	all_units: Array
) -> Array:
	var targets_in_area := []
	var radius_units := radius_inches * 2.0  # Convert inches to game units (2 units per inch)

	for unit: Variant in all_units:
		if unit is Dictionary:
			var unit_pos: Vector2 = unit.get("position", Vector2.ZERO)
			var distance := impact_pos.distance_to(unit_pos)
			if distance <= radius_units:
				targets_in_area.append(unit)

	return targets_in_area

## Get targets within spread cone (for Spread/Shotgun weapons)
## Returns array of targets within cone angle from attacker to primary target
static func get_targets_in_spread(
	attacker_pos: Vector2,
	primary_target_pos: Vector2,
	cone_width_degrees: float,
	all_units: Array
) -> Array:
	var targets_in_spread := []
	var attack_dir := (primary_target_pos - attacker_pos).normalized()
	var attack_distance := attacker_pos.distance_to(primary_target_pos)
	var half_cone := deg_to_rad(cone_width_degrees / 2.0)

	for unit: Variant in all_units:
		if unit is Dictionary:
			var unit_pos: Vector2 = unit.get("position", Vector2.ZERO)
			var to_unit := (unit_pos - attacker_pos).normalized()
			var unit_distance := attacker_pos.distance_to(unit_pos)

			# Check if within cone angle
			var angle := acos(attack_dir.dot(to_unit))
			if angle <= half_cone and unit_distance <= attack_distance * 1.2:
				targets_in_spread.append(unit)

	return targets_in_spread

## Resolve area/template weapon attack against multiple targets
## Primary target hit roll determines if attack lands, then affects all in area
static func resolve_area_attack(
	attacker: Dictionary,
	primary_target: Dictionary,
	all_targets: Array,
	weapon: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"template_type": "",
		"primary_result": {},
		"secondary_targets": [],
		"total_hits": 0,
		"total_damage": 0,
		"total_eliminations": 0,
		"shared_damage_roll": 0,
		"area_radius": 0.0,
		"spread_width": 0.0
	}

	var weapon_traits: Array = weapon.get("traits", [])

	# Determine template type and parameters
	if "area" in weapon_traits:
		result["template_type"] = "area"
		result["area_radius"] = weapon.get("area_radius", 2.0)
	elif "explosive" in weapon_traits:
		result["template_type"] = "area"
		result["area_radius"] = weapon.get("explosion_radius", 3.0)
	elif "spread" in weapon_traits:
		result["template_type"] = "spread"
		result["spread_width"] = weapon.get("spread_width", 30.0)
	elif "template" in weapon_traits:
		result["template_type"] = "template"
		result["area_radius"] = weapon.get("template_length", 6.0)
	else:
		# Not an area weapon, use regular resolution
		result["primary_result"] = resolve_ranged_attack(attacker, primary_target, weapon, dice_roller)
		return result

	# AREA WEAPON SPECIAL RESOLUTION:
	# For area weapons, we roll to hit once, then use a SHARED damage roll for all targets
	# Each target rolls saves individually

	# Extract stats for hit calculation
	var combat_skill: int = attacker.get("combat_skill", 0)
	var range_inches: float = attacker.get("range_to_target", 12.0)
	var weapon_range: int = weapon.get("range", RIFLE_RANGE)
	var target_in_cover: bool = primary_target.get("in_cover", false)
	var attacker_elevated: bool = attacker.get("elevated", false)
	var target_elevated: bool = primary_target.get("elevated", false)

	# Calculate hit threshold for primary target
	var hit_threshold := calculate_hit_threshold(
		combat_skill,
		target_in_cover,
		attacker_elevated,
		target_elevated,
		range_inches,
		weapon_range
	)

	# Roll to hit primary target
	var hit_roll: int = dice_roller.call()

	var primary_result := {
		"hit": false,
		"hit_roll": hit_roll,
		"hit_threshold": hit_threshold,
		"damage": 0,
		"armor_saved": false,
		"target_eliminated": false,
		"effects": []
	}

	result["primary_result"] = primary_result

	if not check_hit(hit_roll, hit_threshold):
		# Miss - no area effect
		return result

	primary_result["hit"] = true
	result["total_hits"] = 1

	# Get attacker and target positions
	var attacker_pos: Vector2 = attacker.get("position", Vector2.ZERO)
	var primary_pos: Vector2 = primary_target.get("position", Vector2.ZERO)
	var primary_id: String = primary_target.get("id", "")

	# Roll shared damage for area effect (all targets take same damage roll)
	var shared_damage_roll: int = dice_roller.call()
	result["shared_damage_roll"] = shared_damage_roll

	# Check for elimination (natural 6 on damage)
	var eliminates_on_6 := shared_damage_roll == 6

	# Apply shared damage to primary target
	var primary_toughness: int = primary_target.get("toughness", 3)
	var penetration: int = weapon.get("penetration", 0)
	var weapon_damage: int = weapon.get("damage", 1)

	# Primary target rolls armor save
	var primary_save_roll: int = dice_roller.call()
	# NOTE: Armor save penalty is based on weapon damage stat, not dice roll
	var primary_save_result := resolve_saves(primary_save_roll, primary_target, weapon_traits, weapon_damage)

	if primary_save_result.get("armor_pierced", false):
		primary_result["effects"].append("armor_pierced")

	if primary_save_result.get("saved", false):
		primary_result["armor_saved"] = true
	else:
		# Calculate damage after armor
		var primary_damage := calculate_damage_after_armor(shared_damage_roll, primary_toughness, penetration)
		primary_result["damage"] = primary_damage
		result["total_damage"] += primary_damage

		if eliminates_on_6 and primary_damage > 0:
			primary_result["target_eliminated"] = true
			result["total_eliminations"] += 1

	# Find secondary targets based on template type
	var secondary_targets := []
	if result["template_type"] == "area":
		secondary_targets = get_targets_in_area(primary_pos, result["area_radius"], all_targets)
	elif result["template_type"] == "spread":
		secondary_targets = get_targets_in_spread(attacker_pos, primary_pos, result["spread_width"], all_targets)

	# Remove primary target from secondary list
	var filtered_secondary := []
	for target: Variant in secondary_targets:
		if target is Dictionary:
			var target_id: String = target.get("id", "")
			if target_id != primary_id and target_id != "":
				filtered_secondary.append(target)

	# Resolve against each secondary target (no additional hit roll needed)
	for secondary_target: Variant in filtered_secondary:
		if not secondary_target is Dictionary:
			continue

		var secondary_result := {
			"target_id": secondary_target.get("id", ""),
			"target_name": secondary_target.get("name", "Unknown"),
			"hit": true,  # Area weapons auto-hit secondary targets
			"damage": 0,
			"armor_saved": false,
			"target_eliminated": false,
			"effects": []
		}

		# Check saves for secondary target
		var save_roll: int = dice_roller.call()
		# NOTE: Armor save penalty is based on weapon damage stat, not dice roll
		var save_result := resolve_saves(save_roll, secondary_target, weapon_traits, weapon_damage)

		if save_result.get("armor_pierced", false):
			secondary_result["effects"].append("armor_pierced")

		if save_result.get("saved", false):
			secondary_result["armor_saved"] = true
		else:
			# Apply damage
			var target_toughness: int = secondary_target.get("toughness", 3)
			var final_damage := calculate_damage_after_armor(shared_damage_roll, target_toughness, penetration)
			secondary_result["damage"] = final_damage
			result["total_damage"] += final_damage

			if eliminates_on_6 and final_damage > 0:
				secondary_result["target_eliminated"] = true
				result["total_eliminations"] += 1

		result["secondary_targets"].append(secondary_result)
		result["total_hits"] += 1

	return result

## Calculate scatter for missed area attacks (optional rule)
static func calculate_scatter(
	impact_pos: Vector2,
	scatter_distance: float,
	dice_roller: Callable
) -> Vector2:
	var direction_roll: int = dice_roller.call()
	var angle := (direction_roll - 1) * 60.0  # 6 directions (60° each)
	var scatter_vector := Vector2.RIGHT.rotated(deg_to_rad(angle)) * scatter_distance

	return impact_pos + scatter_vector

#endregion

#region Utility Device Effects

## Check and apply utility device effects for a character
## Returns Dictionary with all active device effects
static func check_utility_devices(character: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result := {
		"jump_distance": 0,
		"climb_distance": 0,
		"detection_range": 0,
		"reroll_ones": false,
		"reaction_dice_bonus": 0,
		"can_glide": false,
		"effects": []
	}

	var devices: Array = character.get("utility_devices", [])

	for device_id: Variant in devices:
		var device_name: String = device_id if device_id is String else str(device_id)
		_apply_utility_device_effect(device_name, result, context)

	return result

## Apply individual utility device effect
static func _apply_utility_device_effect(
	device_name: String,
	result: Dictionary,
	_context: Dictionary
) -> void:
	match device_name.to_lower():
		"jump_belt":
			# Can jump up to 9" ignoring terrain
			result["jump_distance"] = 9
			result["effects"].append("jump_belt_9_inches")

		"grapple_launcher":
			# Can climb up to 12" vertically
			result["climb_distance"] = 12
			result["effects"].append("grapple_launcher_12_climb")

		"motion_tracker":
			# Detect hidden enemies within 12"
			result["detection_range"] = 12
			result["effects"].append("motion_tracker_12_detect")

		"battle_visor":
			# Reroll 1s on attack rolls
			result["reroll_ones"] = true
			result["effects"].append("battle_visor_reroll_ones")

		"communicator":
			# +1 Reaction die for the crew
			result["reaction_dice_bonus"] += 1
			result["effects"].append("communicator_+1_reaction")

## Apply battle visor reroll effect to attack roll
static func apply_battle_visor_reroll(
	original_roll: int,
	dice_roller: Callable,
	has_battle_visor: bool
) -> int:
	if has_battle_visor and original_roll == 1:
		# Reroll the 1
		return dice_roller.call()
	return original_roll

## Check if character can detect hidden enemies at range
static func can_detect_hidden(character: Dictionary, range_inches: float) -> bool:
	var device_effects := check_utility_devices(character)
	var detection_range: int = device_effects.get("detection_range", 0)
	return detection_range > 0 and range_inches <= detection_range

## Get jump distance for character (includes jump belt)
static func get_jump_distance(character: Dictionary) -> int:
	var device_effects := check_utility_devices(character)
	return device_effects.get("jump_distance", 0)

## Get climb distance for character (includes grapple launcher)
static func get_climb_distance(character: Dictionary) -> int:
	var device_effects := check_utility_devices(character)
	return device_effects.get("climb_distance", 0)

## Get total reaction dice bonus from all crew communicators (Sprint 26.3: Character-Everywhere)
static func get_crew_reaction_bonus(crew: Array) -> int:
	var total_bonus := 0
	for member: Variant in crew:
		if not member:
			continue

		# Sprint 26.3: Character-Everywhere - check Object first
		var member_dict: Dictionary
		if member.has_method("to_dictionary"):
			member_dict = member.to_dictionary()
		elif member is Dictionary:
			member_dict = member
		else:
			continue

		var device_effects := check_utility_devices(member_dict)
		total_bonus += device_effects.get("reaction_dice_bonus", 0)
	return total_bonus

#endregion

#region Species Combat Abilities

## Get all species combat abilities for a character
## Returns Dictionary with all active species effects
static func get_species_combat_abilities(character: Dictionary) -> Dictionary:
	var species: String = character.get("species", "human").to_lower()

	var result := {
		"natural_armor_save": 7,  # No natural armor by default
		"speed_modifier": 0,
		"combat_modifier": 0,
		"toughness_modifier": 0,
		"savvy_modifier": 0,
		"can_reroll_check": false,
		"xp_bonus": 0,
		"night_vision": false,
		"lightning_reflexes": false,
		"wall_climbing": false,
		"can_glide": false,
		"keen_senses_bonus": 0,
		"regeneration": false,
		"immune_to_poison": false,
		"immune_to_disease": false,
		"tech_bonus": 0,
		"psychic_powers": false,
		"mental_shield": false,
		"abilities": []
	}

	match species:
		"human":
			result["can_reroll_check"] = true  # Adaptable
			result["xp_bonus"] = 1  # Quick Learner
			result["abilities"].append("adaptable")
			result["abilities"].append("quick_learner")

		"synthoid":
			result["toughness_modifier"] = 1
			result["immune_to_poison"] = true
			result["immune_to_disease"] = true
			result["tech_bonus"] = 1  # Machine Logic
			result["regeneration"] = true  # Faster recovery
			result["abilities"].append("artificial_body")
			result["abilities"].append("machine_logic")

		"altered_human":
			result["speed_modifier"] = 1
			result["abilities"].append("enhanced_physiology")
			result["abilities"].append("specialized_adaptation")

		"avian":
			result["toughness_modifier"] = -1
			result["speed_modifier"] = 2
			result["keen_senses_bonus"] = 2  # +2 awareness
			result["can_glide"] = true
			result["abilities"].append("keen_senses")
			result["abilities"].append("gliding")

		"reptilian":
			result["toughness_modifier"] = 2
			result["speed_modifier"] = -1
			result["natural_armor_save"] = 6  # 6+ natural armor
			result["regeneration"] = true
			result["abilities"].append("natural_armor_6+")
			result["abilities"].append("regeneration")

		"insectoid":
			result["combat_modifier"] = 1
			result["speed_modifier"] = 1
			result["savvy_modifier"] = -1
			result["natural_armor_save"] = 5  # 5+ exoskeleton
			result["wall_climbing"] = true
			result["abilities"].append("exoskeleton_5+")
			result["abilities"].append("wall_climbing")

		"psyker":
			result["toughness_modifier"] = -1
			result["savvy_modifier"] = 2
			result["psychic_powers"] = true
			result["mental_shield"] = true  # +2 resist psychic
			result["abilities"].append("psychic_powers")
			result["abilities"].append("mental_shield")

		"felinoid":
			result["combat_modifier"] = 1
			result["speed_modifier"] = 1
			result["savvy_modifier"] = -1
			result["night_vision"] = true
			result["lightning_reflexes"] = true
			result["abilities"].append("night_vision")
			result["abilities"].append("lightning_reflexes")

		"soulless", "bot":
			result["natural_armor_save"] = 6  # 6+ innate
			result["abilities"].append("soulless_armor_6+")

		"kerin", "k'erin", "k_erin":
			result["abilities"].append("brawl_reroll")
			result["abilities"].append("brawl_bonus_+1")
			result["abilities"].append("melee_damage_+1")

		"hulker", "hulkers":
			result["abilities"].append("melee_damage_+2")

		"swift":
			result["speed_modifier"] = 2
			result["abilities"].append("swift_movement")
			result["abilities"].append("hard_to_hit_ranged")

		"stalker":
			result["abilities"].append("ambush_+2_hit")

		"feral":
			result["abilities"].append("ignore_suppression")

	return result

## Check if character has natural armor (from species)
static func get_natural_armor_save(character: Dictionary) -> int:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("natural_armor_save", 7)

## Get effective armor save (best of worn or natural)
static func get_effective_armor_save(character: Dictionary) -> int:
	var worn_armor: String = character.get("armor", "none")
	var worn_save := get_armor_save_threshold(worn_armor)
	var natural_save := get_natural_armor_save(character)
	# Return better (lower) save
	return mini(worn_save, natural_save)

## Check if character ignores darkness penalties
static func has_night_vision(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("night_vision", false)

## Check if character acts first in battle (lightning reflexes)
static func has_lightning_reflexes(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("lightning_reflexes", false)

## Check if character can climb walls
static func can_wall_climb(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("wall_climbing", false)

## Check if character can glide safely
static func can_glide(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("can_glide", false)

## Get keen senses bonus for awareness checks
static func get_keen_senses_bonus(character: Dictionary) -> int:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("keen_senses_bonus", 0)

## Check if character has regeneration
static func has_regeneration(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("regeneration", false)

## Check if character can use Adaptable reroll (human)
static func can_use_adaptable_reroll(character: Dictionary) -> bool:
	var abilities := get_species_combat_abilities(character)
	var already_used: bool = character.get("_used_adaptable_this_battle", false)
	return abilities.get("can_reroll_check", false) and not already_used

## Mark adaptable reroll as used
static func mark_adaptable_used(character: Dictionary) -> void:
	character["_used_adaptable_this_battle"] = true

## Check if character ignores suppression (Feral)
static func ignores_suppression(character: Dictionary) -> bool:
	var species: String = character.get("species", "human").to_lower()
	return species == "feral"

## Get XP bonus from species (human Quick Learner)
static func get_species_xp_bonus(character: Dictionary) -> int:
	var abilities := get_species_combat_abilities(character)
	return abilities.get("xp_bonus", 0)

## Get all stat modifiers from species
static func get_species_stat_modifiers(character: Dictionary) -> Dictionary:
	var abilities := get_species_combat_abilities(character)
	return {
		"combat": abilities.get("combat_modifier", 0),
		"toughness": abilities.get("toughness_modifier", 0),
		"speed": abilities.get("speed_modifier", 0),
		"savvy": abilities.get("savvy_modifier", 0)
	}

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

#region Weapon Traits - Comprehensive Effects

## All weapon traits and their effects in combat
## Based on Five Parsecs from Home core rules

## Get all applicable weapon trait effects for an attack
static func get_weapon_trait_effects(
	weapon_traits: Array,
	attack_context: Dictionary = {}
) -> Dictionary:
	var effects := {
		"hit_modifier": 0,
		"damage_modifier": 0,
		"armor_penetration": 0,
		"shots_modifier": 0,
		"range_modifier": 0,
		"is_piercing": false,
		"is_silent": false,
		"is_loud": false,
		"causes_stun": false,
		"causes_knockback": false,
		"causes_suppression": false,
		"is_area_effect": false,
		"is_melee": false,
		"is_pistol": false,
		"is_one_use": false,
		"is_reliable": false,
		"rapid_fire": false,
		"rapid_fire_shots": 0,
		"traits_applied": []
	}

	var range_band: String = attack_context.get("range_band", "medium")
	var moved_this_turn: bool = attack_context.get("moved_this_turn", false)
	var is_aimed_shot: bool = attack_context.get("is_aimed_shot", false)

	for trait_name: Variant in weapon_traits:
		var trait_str: String = trait_name if trait_name is String else str(trait_name)
		_apply_weapon_trait(trait_str.to_lower(), effects, range_band, moved_this_turn, is_aimed_shot)

	return effects

## Apply individual weapon trait effect
static func _apply_weapon_trait(
	trait_name: String,
	effects: Dictionary,
	range_band: String,
	moved_this_turn: bool,
	is_aimed_shot: bool
) -> void:
	match trait_name:
		# Accuracy Traits
		"accurate":
			effects["hit_modifier"] += 1
			effects["traits_applied"].append("accurate_+1_hit")

		"snap_shot":
			# +1 hit at close range (within 6")
			if range_band == "short":
				effects["hit_modifier"] += 1
				effects["traits_applied"].append("snap_shot_+1_close")

		"focused":
			# +1 hit if didn't move
			if not moved_this_turn:
				effects["hit_modifier"] += 1
				effects["traits_applied"].append("focused_+1_stationary")

		"slow":
			# -1 hit at close range
			if range_band == "short":
				effects["hit_modifier"] -= 1
				effects["traits_applied"].append("slow_-1_close")

		"heavy":
			# -1 hit if moved, +1 damage
			if moved_this_turn:
				effects["hit_modifier"] -= 1
				effects["traits_applied"].append("heavy_-1_moved")
			effects["damage_modifier"] += 1
			effects["traits_applied"].append("heavy_+1_damage")

		# Damage Traits
		"devastating":
			effects["damage_modifier"] += 1
			effects["traits_applied"].append("devastating_+1_damage")

		"powered":
			effects["damage_modifier"] += 1
			effects["traits_applied"].append("powered_+1_damage")

		"piercing", "armor_piercing":
			effects["is_piercing"] = true
			effects["traits_applied"].append("piercing_ignores_armor")

		"high_penetration":
			effects["armor_penetration"] += 2
			effects["traits_applied"].append("high_pen_+2")

		# Status Effect Traits
		"stun", "stunning":
			effects["causes_stun"] = true
			effects["traits_applied"].append("causes_stun")

		"impact":
			effects["causes_stun"] = true  # Double stun
			effects["traits_applied"].append("impact_double_stun")

		"knockback":
			effects["causes_knockback"] = true
			effects["traits_applied"].append("causes_knockback")

		"suppressive":
			effects["causes_suppression"] = true
			effects["traits_applied"].append("causes_suppression")

		"terrifying":
			effects["traits_applied"].append("terrifying_morale_check")

		# Range/Shots Traits
		"rapid_fire":
			effects["rapid_fire"] = true
			effects["rapid_fire_shots"] = 3  # Default rapid fire shots
			effects["traits_applied"].append("rapid_fire_3_shots")

		"burst_fire":
			effects["shots_modifier"] += 2
			effects["traits_applied"].append("burst_+2_shots")

		"single_shot":
			effects["shots_modifier"] = 0  # Force single shot
			effects["traits_applied"].append("single_shot_only")

		"long_range":
			effects["range_modifier"] += 6
			effects["traits_applied"].append("long_range_+6")

		"short_range":
			effects["range_modifier"] -= 6
			effects["traits_applied"].append("short_range_-6")

		# Weapon Type Traits
		"melee":
			effects["is_melee"] = true
			effects["traits_applied"].append("melee_weapon")

		"pistol":
			effects["is_pistol"] = true
			effects["traits_applied"].append("pistol_weapon")

		# Sound Traits
		"silent":
			effects["is_silent"] = true
			effects["traits_applied"].append("silent_no_alert")

		"loud":
			effects["is_loud"] = true
			effects["traits_applied"].append("loud_alerts_enemies")

		# Special Traits
		"reliable":
			effects["is_reliable"] = true
			effects["traits_applied"].append("reliable_no_jam")

		"one_use", "limited_ammo":
			effects["is_one_use"] = true
			effects["traits_applied"].append("one_use_only")

		"area", "explosive", "template", "spread":
			effects["is_area_effect"] = true
			effects["traits_applied"].append("area_effect")

		"clumsy":
			# -1 if opponent has faster Speed
			effects["traits_applied"].append("clumsy_check_speed")

		"elegant":
			# Reroll one die if rolled < 4
			effects["traits_applied"].append("elegant_reroll_low")

		"critical":
			# Extra hit on natural 6
			effects["traits_applied"].append("critical_extra_on_6")

		"non_lethal":
			# Target knocked out instead of killed
			effects["traits_applied"].append("non_lethal")

		"hot":
			# Risk of overheating
			effects["traits_applied"].append("hot_overheat_risk")

		"unstable":
			# Roll for malfunction
			effects["traits_applied"].append("unstable_malfunction")

## Check if weapon can fire this turn (reliable trait prevents jams)
static func can_weapon_fire(weapon: Dictionary, jam_roll: int = 0) -> bool:
	var traits: Array = weapon.get("traits", [])

	# Reliable weapons never jam
	if _has_trait(traits, "reliable"):
		return true

	# Check for jam on natural 1
	if jam_roll == 1:
		return false

	return true

## Check if weapon alerts enemies when fired
static func weapon_alerts_enemies(weapon: Dictionary) -> bool:
	var traits: Array = weapon.get("traits", [])

	# Silent weapons don't alert
	if _has_trait(traits, "silent"):
		return false

	# Loud weapons alert at extended range
	if _has_trait(traits, "loud"):
		return true

	# Default: normal alert range
	return true

## Get alert range for weapon (in inches)
static func get_weapon_alert_range(weapon: Dictionary) -> int:
	var traits: Array = weapon.get("traits", [])

	if _has_trait(traits, "silent"):
		return 0
	if _has_trait(traits, "loud"):
		return 24  # Extended alert range
	return 12  # Default alert range

## Check if weapon has specific trait
static func _has_trait(traits: Array, trait_name: String) -> bool:
	for t: Variant in traits:
		var t_str: String = t if t is String else str(t)
		if t_str.to_lower() == trait_name.to_lower():
			return true
	return false

## Get number of shots for rapid fire
static func get_rapid_fire_shots(weapon: Dictionary) -> int:
	var traits: Array = weapon.get("traits", [])
	var trait_effects := get_weapon_trait_effects(traits)
	if trait_effects.get("rapid_fire", false):
		return trait_effects.get("rapid_fire_shots", 3)
	return 1

## Check if weapon causes overheating (hot trait)
static func check_weapon_overheat(weapon: Dictionary, dice_roller: Callable) -> bool:
	var traits: Array = weapon.get("traits", [])
	if _has_trait(traits, "hot"):
		var roll: int = dice_roller.call()
		return roll == 1  # Overheat on natural 1
	return false

## Check if weapon causes non-lethal damage
static func is_non_lethal_weapon(weapon: Dictionary) -> bool:
	var traits: Array = weapon.get("traits", [])
	return _has_trait(traits, "non_lethal")

#endregion
