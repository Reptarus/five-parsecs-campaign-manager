class_name BattleCalculations
extends RefCounted

## Pure calculation functions for Five Parsecs battle system
## All functions are static and have no dependencies - fully testable without scene tree
##
## Usage:
##   var hit_chance = BattleCalculations.calculate_hit_chance(attacker, target, range_inches)
##   var damage = BattleCalculations.calculate_damage(weapon, target_toughness)
##   var result = BattleCalculations.resolve_attack(attacker, target, weapon, roll_func)

# Combat constants (Five Parsecs core rules p.44)
# Base to-hit thresholds by range and cover:
#   Open target within 6" = 3+
#   Open target at range = 5+
#   Target in cover = 6+
const HIT_THRESHOLD_CLOSE_OPEN := 3  # Within 6", no cover
const HIT_THRESHOLD_RANGE_OPEN := 5  # Beyond 6", no cover
const HIT_THRESHOLD_IN_COVER := 6    # Any range, in cover
const CLOSE_RANGE_THRESHOLD := 6.0   # 6" for close range bonus

const ELEVATION_BONUS := 1
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

# Save types for armor/screen distinction (Five Parsecs p.46-47)
# Piercing weapons ignore ARMOR saves but NOT screen saves
enum SaveType { NONE, ARMOR, SCREEN }

# Screen save thresholds (from protective devices)
const SCREEN_SAVE_ENERGY_SHIELD := 5  # Energy Shield Generator
const SCREEN_SAVE_COMBAT_SHIELD := 4  # Combat Shield (frontal only)

# Experience awards
const XP_PARTICIPATION := 1
const XP_VICTORY_BONUS := 2
const XP_DEFEAT_BONUS := 1
const XP_FIRST_KILL := 1
const XP_SURVIVAL_INJURY := 1

# Range band thresholds for weapon modifications (short/medium/long)
const RANGE_BAND_SHORT_MAX := 6.0   # Up to 6" is short range
const RANGE_BAND_MEDIUM_MAX := 18.0 # 6" to 18" is medium range (beyond is long)

## Get range band for weapon modification bonuses
## Returns: "short", "medium", or "long"
static func get_range_band(range_inches: float, weapon_range: int) -> String:
	# Short range: within 6"
	if range_inches <= RANGE_BAND_SHORT_MAX:
		return "short"
	# Long range: beyond weapon range or beyond 18"
	if range_inches > weapon_range or range_inches > RANGE_BAND_MEDIUM_MAX:
		return "long"
	# Medium: everything in between
	return "medium"

## Get weapon modification range bonus for current range band
## weapon_mods should contain "range_bonus": {"short": X, "medium": Y, "long": Z}
static func get_weapon_mod_range_bonus(weapon_mods: Dictionary, range_band: String) -> int:
	if weapon_mods.is_empty():
		return 0
	var range_bonus: Dictionary = weapon_mods.get("range_bonus", {})
	return range_bonus.get(range_band, 0)

# Species combat ability modifiers (Core Rules p.28-32, character_species.json)
# These are integrated into combat calculations based on species type
const SPECIES_MODIFIERS := {
	# K'Erin: Warrior Pride - +1 to melee/brawl attacks
	"kerin": {"brawl_bonus": 1, "melee_damage_bonus": 0},
	"k'erin": {"brawl_bonus": 1, "melee_damage_bonus": 0},

	# Hulker: Crushing Strength - +2 melee damage
	"hulker": {"brawl_bonus": 0, "melee_damage_bonus": 2},

	# Swift: Small Target - Enemies suffer -1 to ranged attacks against them
	"swift": {"ranged_defense_bonus": 1},  # Attacker penalty

	# Stalker: Ambush Expert - +2 hit, +1 damage from hiding
	"stalker": {"ambush_hit_bonus": 2, "ambush_damage_bonus": 1},

	# Felinoid: Lightning Reflexes - handled in initiative system
	"felinoid": {"initiative_bonus": true},

	# Engineer: Tech expertise - handled in character advancement
	"engineer": {"tech_bonus": 1, "repair_bonus": 1},

	# Precursor: Auto-success on one Tech check per mission
	"precursor": {"auto_tech_success": true},

	# Soulless: Can't use consumables, uses Bot injury table
	"soulless": {"no_consumables": true, "bot_injury_table": true},

	# Bot: Can't use consumables, uses Bot injury table
	"bot": {"no_consumables": true, "bot_injury_table": true},
}

# Species with natural armor saves (Core Rules p.28-32)
const SPECIES_NATURAL_ARMOR := {
	"reptilian": 6,    # Natural Armor: 6+ save
	"insectoid": 5,    # Exoskeleton: 5+ save
	"bot": 5,          # Armored Chassis: 5+ save
	"soulless": 5,     # Similar chassis to bots
}

#region Hit Calculations

## Calculate hit modifier based on attacker, target, and range
## Returns the modifier to add to dice roll (added to the roll, not the threshold)
## Note: Cover and close range are handled by the base threshold, not modifiers
## Species abilities are now integrated (Core Rules p.28-32):
##   - Swift: "Small Target" - Enemies suffer -1 to ranged attacks against them
##   - Stalker: "Ambush Expert" - +2 to hit when attacking from hiding (ambush)
## Equipment bonuses integrated (Phase 2.1):
##   - Weapon modifications (combat sight, precision scope, etc.)
##   - Utility devices (battle visor, etc.)
##   - Implants (neural enhancer, etc.)
static func calculate_hit_modifier(
	attacker_combat_skill: int,
	_target_in_cover: bool,  # Now handled by base threshold
	attacker_elevated: bool,
	target_elevated: bool,
	range_inches: float,
	weapon_range: int,
	is_stunned: bool = false,
	is_suppressed: bool = false,
	has_aim_bonus: bool = false,
	target_species: String = "",
	attacker_species: String = "",
	is_ambush: bool = false,
	equipment_bonus: int = 0
) -> int:
	var modifier := 0

	# Combat skill bonus (Five Parsecs p.44)
	modifier += attacker_combat_skill

	# Equipment bonuses (Phase 2.1: weapon modifications, utility devices, implants)
	modifier += equipment_bonus

	# Elevation modifiers
	if attacker_elevated and not target_elevated:
		modifier += ELEVATION_BONUS
	elif target_elevated and not attacker_elevated:
		modifier -= 1  # Shooting uphill

	# Long range penalty (beyond weapon range)
	if range_inches > weapon_range:
		modifier += LONG_RANGE_PENALTY

	# Status effects
	if is_stunned:
		modifier -= 2
	if is_suppressed:
		modifier -= 1

	# Aim bonus
	if has_aim_bonus:
		modifier += 1

	# Species ability: Swift "Small Target" - Enemies suffer -1 to ranged attacks (Core Rules p.28)
	var target_species_lower := target_species.to_lower() if target_species else ""
	if target_species_lower in SPECIES_MODIFIERS:
		var species_data: Dictionary = SPECIES_MODIFIERS[target_species_lower]
		if species_data.get("ranged_defense_bonus", 0) > 0:
			modifier -= species_data.ranged_defense_bonus

	# Species ability: Stalker "Ambush Expert" - +2 to hit when attacking from hiding (Core Rules p.28)
	var attacker_species_lower := attacker_species.to_lower() if attacker_species else ""
	if is_ambush and attacker_species_lower in SPECIES_MODIFIERS:
		var species_data: Dictionary = SPECIES_MODIFIERS[attacker_species_lower]
		modifier += species_data.get("ambush_hit_bonus", 0)

	return modifier

## Calculate the threshold needed to hit (1-6 scale)
## Returns the minimum roll needed on d6 to hit
## Five Parsecs rules p.44:
##   - Open target within 6" = 3+
##   - Open target at range = 5+
##   - Target in cover = 6+
## Species abilities integrated (Core Rules p.28-32)
static func calculate_hit_threshold(
	attacker_combat_skill: int,
	target_in_cover: bool,
	attacker_elevated: bool,
	target_elevated: bool,
	range_inches: float,
	weapon_range: int,
	modifiers: Dictionary = {}
) -> int:
	# Step 1: Determine base threshold from range and cover (Five Parsecs p.44)
	var base_threshold: int
	if target_in_cover:
		base_threshold = HIT_THRESHOLD_IN_COVER  # 6+ for targets in cover
	elif range_inches <= CLOSE_RANGE_THRESHOLD:
		base_threshold = HIT_THRESHOLD_CLOSE_OPEN  # 3+ within 6", open
	else:
		base_threshold = HIT_THRESHOLD_RANGE_OPEN  # 5+ at range, open

	# Step 2: Calculate modifiers (combat skill, elevation, status effects, aim, species)
	var modifier := calculate_hit_modifier(
		attacker_combat_skill,
		target_in_cover,
		attacker_elevated,
		target_elevated,
		range_inches,
		weapon_range,
		modifiers.get("is_stunned", false),
		modifiers.get("is_suppressed", false),
		modifiers.get("has_aim_bonus", false),
		modifiers.get("target_species", ""),
		modifiers.get("attacker_species", ""),
		modifiers.get("is_ambush", false)
	)

	# Step 3: Threshold = Base - modifier (higher modifier = lower threshold = easier to hit)
	var threshold := base_threshold - modifier

	# Clamp to valid d6 range
	return clampi(threshold, 1, 7)  # 7 means impossible

## Check if attack hits given a dice roll
static func check_hit(roll: int, threshold: int) -> bool:
	return roll >= threshold

#endregion

#region Damage Calculations

## Calculate base damage from weapon with comprehensive trait effects
## Phase 2.4: Now accepts weapon_modification_bonus for damage bonuses from modifications
static func calculate_weapon_damage(
	weapon_damage: int,
	is_critical: bool = false,
	weapon_traits: Array = [],
	attack_context: Dictionary = {},
	weapon_modification_bonus: int = 0
) -> int:
	var damage := weapon_damage
	var reliable_reroll := false

	# Apply weapon modification damage bonus (Phase 2.4: heavy_barrel, mono_edge, etc.)
	damage += weapon_modification_bonus

	# Critical hit doubles damage
	if is_critical:
		damage *= 2

	# Apply weapon trait effects
	for trait_name in weapon_traits:
		var trait_lower = trait_name.to_lower() if trait_name is String else ""
		match trait_lower:
			# Damage modifiers
			"heavy":
				damage += 1  # Heavy weapons deal +1 damage
			"devastating":
				damage += 1  # Devastating adds +1 damage
			"powered":
				damage += 1  # Powered melee weapons add +1 damage

			# Reliability traits
			"reliable":
				reliable_reroll = true  # Flag for potential reroll on 1s
			"unstable":
				# 10% chance of malfunction (roll fails)
				if randi_range(1, 10) == 1:
					damage = 0  # Weapon misfires

			# Hit modifiers (stored in context for hit roll)
			"accurate":
				pass  # +1 to hit, handled in hit calculation
			"slow":
				pass  # -1 to hit at close range

			# Area/spread effects
			"spread", "template":
				pass  # Hit multiple targets, handled in attack resolution
			"explosive":
				pass  # Area damage, handled in attack resolution
			"rapid_fire":
				pass  # Multiple shots, handled in attack resolution
			"suppressive":
				pass  # Pin effect, handled in attack resolution

			# Special handling traits
			"piercing":
				pass  # Handled in armor calculation
			"non_lethal":
				pass  # Can't reduce below 1 HP
			"silent":
				pass  # No alert, handled in stealth
			"loud":
				pass  # Alerts enemies, handled in stealth

			# Equipment traits
			"two_handed":
				pass  # Can't use shield, tracked in equipment
			"light":
				pass  # Can dual wield, tracked in equipment
			"thrown", "one_use":
				pass  # Consumable, tracked in inventory
			"limited_ammo":
				pass  # Low ammo, tracked in inventory
			"hot":
				pass  # Can overheat, tracked in weapon state
			"psionic":
				pass  # Requires psyker, handled in validation

	# Reliable trait: reroll damage if it was a 1
	if reliable_reroll and damage == 1 and not weapon_traits.has("Unstable"):
		var reroll = randi_range(1, 6)
		if reroll > damage:
			damage = reroll

	return maxi(0, damage)

## Get hit modifier from weapon traits
## Core Rules p.77 - Weapon Traits:
##   - Accurate: +1 to hit
##   - Slow: -1 at close range
##   - Rapid Fire: +1 for volume of fire
##   - Heavy: -1 to hit if attacker moved this turn (requires context)
##   - Snap shot: +1 to hit within 6" (short range)
##   - Terrifying: Not a hit modifier, handled in effects
static func get_trait_hit_modifier(
	weapon_traits: Array,
	range_band: String = "medium",
	attacker_context: Dictionary = {}
) -> int:
	var modifier := 0
	var attacker_moved: bool = attacker_context.get("moved_this_turn", false)
	var range_inches: float = attacker_context.get("range_inches", 12.0)

	for trait_name in weapon_traits:
		var trait_lower = trait_name.to_lower() if trait_name is String else ""
		match trait_lower:
			"accurate":
				modifier += 1  # +1 to hit (Core Rules p.77)
			"slow":
				if range_band == "short":
					modifier -= 1  # -1 at close range (Core Rules p.77)
			"rapid_fire":
				modifier += 1  # Bonus for volume of fire
			"heavy":
				# Heavy weapons: -1 to hit if you moved this turn (Core Rules p.77)
				if attacker_moved:
					modifier -= 1
			"snap_shot":
				# Snap shot: +1 to hit within 6" (Core Rules p.77)
				if range_inches <= 6.0 or range_band == "short":
					modifier += 1
			"focused":
				# Focused: +1 to hit if you didn't move (Core Rules p.77)
				if not attacker_moved:
					modifier += 1

	return modifier

## Check if weapon has specific trait
static func has_trait(weapon_traits: Array, trait_name: String) -> bool:
	for weapon_trait in weapon_traits:
		if weapon_trait is String and weapon_trait.to_lower() == trait_name.to_lower():
			return true
	return false

## Get armor penetration from weapon traits
static func get_trait_armor_penetration(weapon_traits: Array) -> int:
	var penetration := 0

	for trait_name in weapon_traits:
		var trait_lower = trait_name.to_lower() if trait_name is String else ""
		match trait_lower:
			"piercing":
				penetration += 2  # Piercing ignores 2 points of armor
			"powered":
				penetration += 1  # Powered weapons have some penetration
			"explosive":
				penetration += 1  # Explosives damage armor

	return penetration

## Check if weapon can be used silently
static func is_weapon_silent(weapon_traits: Array) -> bool:
	return has_trait(weapon_traits, "silent") and not has_trait(weapon_traits, "loud")

## Check if weapon affects area
static func is_area_weapon(weapon_traits: Array) -> bool:
	return has_trait(weapon_traits, "area") or has_trait(weapon_traits, "template") or has_trait(weapon_traits, "explosive") or has_trait(weapon_traits, "spread")

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
## Species abilities integrated (Core Rules p.28-32):
##   - Reptilian "Natural Armor": 6+ save
##   - Insectoid "Exoskeleton": 5+ save
##   - Bot "Armored Chassis": 5+ save
static func get_armor_save_threshold(armor_type: String, species: String = "") -> int:
	var species_lower := species.to_lower() if species else ""

	# Check for species natural armor first (uses best of natural or worn armor)
	var natural_armor_save := ARMOR_SAVE_NONE
	if species_lower in SPECIES_NATURAL_ARMOR:
		natural_armor_save = SPECIES_NATURAL_ARMOR[species_lower]

	# Determine worn armor save
	var worn_armor_save := ARMOR_SAVE_NONE
	match armor_type.to_lower():
		"none", "":
			worn_armor_save = ARMOR_SAVE_NONE
		"light", "flak":
			worn_armor_save = ARMOR_SAVE_LIGHT
		"combat", "tactical":
			worn_armor_save = ARMOR_SAVE_COMBAT
		"battle_suit", "heavy":
			worn_armor_save = ARMOR_SAVE_BATTLE_SUIT
		"powered", "power_armor":
			worn_armor_save = ARMOR_SAVE_POWERED
		_:
			worn_armor_save = ARMOR_SAVE_NONE

	# Use the better save (lower number = better save)
	if natural_armor_save < ARMOR_SAVE_NONE and worn_armor_save < ARMOR_SAVE_NONE:
		return mini(natural_armor_save, worn_armor_save)
	elif natural_armor_save < ARMOR_SAVE_NONE:
		return natural_armor_save
	else:
		return worn_armor_save

## Check if armor saves against damage
## Now accepts species for natural armor calculation and armor traits
static func check_armor_save(
	roll: int,
	armor_type: String,
	damage: int = 1,
	species: String = "",
	armor_traits: Array = [],
	attack_type: String = "ranged"
) -> bool:
	var threshold := get_armor_save_threshold(armor_type, species)

	# High damage can negate saves
	if damage >= 3:
		threshold += 1  # Harder to save against heavy damage
	
	# Apply armor trait bonuses
	var trait_bonus := get_armor_trait_save_bonus(armor_traits, attack_type, damage)
	threshold -= trait_bonus  # Lower threshold = easier save
	
	return roll >= threshold

## Calculate armor save bonus from armor traits
## Args:
##   armor_traits: Array of trait names (e.g., ["impact_resistant", "durable"])
##   attack_type: "ranged", "melee", "explosive"
##   damage: Damage value (for traits that trigger on high damage)
## Returns: Bonus to armor save (positive = easier save)
static func get_armor_trait_save_bonus(
	armor_traits: Array,
	attack_type: String,
	damage: int
) -> int:
	var bonus := 0
	
	for trait in armor_traits:
		var trait_lower := str(trait).to_lower() if trait else ""
		
		match trait_lower:
			"impact_resistant":
				# +2 to armor save vs melee attacks (Riot Armor special rule)
				if attack_type == "melee":
					bonus += 2
			
			"durable":
				# +1 to armor save against high damage (3+ damage)
				if damage >= 3:
					bonus += 1
			
			"heavy":
				# +1 to armor save vs explosive weapons
				if attack_type == "explosive":
					bonus += 1
			
			"ablative":
				# Special: Can absorb one extra hit then lose 1 save value
				# This requires state tracking in resolve_ranged_attack
				# For now, tracked externally
				pass
			
			"regenerating":
				# Energy Shield Generator: Deactivates for 1 turn on failed save
				# Tracked externally in battle state
				pass
	
	return bonus

## Check protective devices (shields, armor mods) before applying damage
## Returns information about protective device effects
static func check_protective_devices(character: Dictionary, damage_roll: int, dice_roller: Callable) -> Dictionary:
	"""Check protective device effects before applying damage
	
	Protective devices check order:
	1. Combat Shield / Energy Shield - blocks hit entirely if charges available
	2. Reactive Plating - allows armor save reroll on failed save
	
	Args:
		character: Character dictionary with shield_charges, equipped_armor_mods
		damage_roll: Original armor save roll
		dice_roller: Callable for dice rolls (for reactive plating reroll)
		
	Returns:
		Dictionary with: {blocked: bool, reroll_available: bool, shield_used: bool, reroll_result: int}
	"""
	var result := {
		"blocked": false,
		"reroll_available": false,
		"shield_used": false,
		"reroll_result": 0,
		"shield_charges_remaining": 0
	}
	
	# Check shield charges (Combat Shield / Energy Shield)
	var shield_charges: int = character.get("shield_charges", 0)
	if shield_charges > 0:
		# Shield blocks the hit entirely
		result["blocked"] = true
		result["shield_used"] = true
		result["shield_charges_remaining"] = shield_charges - 1
		return result
	
	# Check for reactive plating (allows armor save reroll)
	var equipped_mods: Array = character.get("equipped_armor_mods", [])
	if "reactive_plating" in equipped_mods:
		result["reroll_available"] = true
		# Reactive plating allows one reroll per turn on failed armor save
		# The caller will decide whether to use this based on the original roll
	
	return result

## Apply camouflage system modifier to hit roll
## Camouflage grants -1 to hit (attacker penalty) when character is stationary
static func apply_camouflage_modifier(target: Dictionary) -> int:
	"""Get hit penalty from camouflage system
	
	Args:
		target: Target dictionary with equipped_armor_mods and moved_this_turn
		
	Returns:
		int: Penalty to attacker's hit roll (0 or -1)
	"""
	var equipped_mods: Array = target.get("equipped_armor_mods", [])
	if "camouflage_system" not in equipped_mods:
		return 0
	
	# Camouflage only works if character didn't move this turn
	var moved: bool = target.get("moved_this_turn", false)
	if moved:
		return 0
	
	# Stationary + camouflage = -1 to attacker's hit roll
	return -1

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

	# Get weapon modification range bonus (from installed modifications)
	var range_band := get_range_band(range_inches, weapon_range)
	var weapon_mods: Dictionary = weapon.get("modification_effects", {})
	var mod_range_bonus: int = get_weapon_mod_range_bonus(weapon_mods, range_band)

	# Check armor modifications for hit bonuses/penalties
	var battle_state: Dictionary = attacker.get("battle_state", {})  # Shared battle state for one-time effects
	var attacker_armor_mods := check_armor_modifications(attacker, "attack", battle_state)
	var target_armor_mods := check_armor_modifications(target, "defense", battle_state)
	
	var armor_hit_bonus: int = attacker_armor_mods.get("hit_bonus", 0)  # Enhanced targeting
	var armor_hit_penalty: int = target_armor_mods.get("hit_penalty_vs_me", 0)  # Stealth coating

	# Apply camouflage system penalty (target is harder to hit if stationary)
	var camouflage_penalty: int = apply_camouflage_modifier(target)

	# Calculate hit threshold
	var hit_threshold := calculate_hit_threshold(
		combat_skill,
		target_in_cover,
		attacker_elevated,
		target_elevated,
		range_inches,
		weapon_range
	)

	# Roll to hit (weapon mod bonus adds to roll, camouflage adds to threshold)
	var hit_roll: int = dice_roller.call()
	
	# Battle Visor: Reroll 1s on attack rolls
	var utility_effects := check_utility_device_effects(attacker, "attack")
	if utility_effects.get("reroll_ones", false) and hit_roll == 1:
		var reroll: int = dice_roller.call()
		result["battle_visor_reroll"] = reroll
		if reroll > hit_roll:
			hit_roll = reroll
			result["battle_visor_used"] = true
	
	# Apply all hit modifiers
	var modified_hit_roll: int = hit_roll + mod_range_bonus + armor_hit_bonus
	var modified_hit_threshold: int = hit_threshold - camouflage_penalty + armor_hit_penalty
	result["hit_roll"] = hit_roll
	result["modified_hit_roll"] = modified_hit_roll
	result["hit_threshold"] = modified_hit_threshold
	result["range_band"] = range_band
	result["mod_range_bonus"] = mod_range_bonus
	result["camouflage_penalty"] = camouflage_penalty
	result["armor_hit_bonus"] = armor_hit_bonus  # Enhanced targeting
	result["armor_hit_penalty"] = armor_hit_penalty  # Stealth coating on target

	if not check_hit(modified_hit_roll, modified_hit_threshold):
		return result

	result["hit"] = true

	# Check for critical hit (natural 6)
	if hit_roll == 6:
		result["critical"] = true

		# Critical trait: Natural 6 to hit inflicts 2 Hits instead of 1 (Five Parsecs p.77)
		if has_trait(weapon_traits, "critical"):
			result["hits_inflicted"] = 2
			result["effects"].append("critical_extra_hit")
		else:
			result["hits_inflicted"] = 1
	else:
		result["hits_inflicted"] = 1

	# Calculate damage (Phase 2.4: Include weapon modification damage bonus)
	var weapon_mod_damage_bonus: int = weapon_mods.get("damage_bonus", 0)
	var raw_damage := calculate_weapon_damage(weapon_damage, result["critical"], weapon_traits, {}, weapon_mod_damage_bonus)
	result["raw_damage"] = raw_damage
	result["weapon_mod_damage_bonus"] = weapon_mod_damage_bonus

	# Roll for damage (needed for natural 6 elimination check)
	var damage_roll: int = dice_roller.call()
	result["damage_roll"] = damage_roll

	# Check protective devices BEFORE armor save (shields block hits entirely)
	var protective_check := check_protective_devices(target, 0, dice_roller)
	result["protective_devices"] = protective_check
	
	if protective_check["blocked"]:
		# Shield blocked the hit - no damage
		result["shield_blocked"] = true
		result["effects"].append("shield_blocked")
		result["armor_saved"] = true  # Treated as armor save for UI purposes
		return result

	# Armor and Screen Saves (Five Parsecs p.46-47)
	# CRITICAL: Piercing weapons ignore ARMOR saves but NOT screen saves!
	var armor_roll: int = dice_roller.call()
	result["armor_roll"] = armor_roll

	var piercing_weapon := has_trait(weapon_traits, "piercing")
	var save_succeeded := false

	# Add piercing effect immediately if piercing weapon (shown even if screen blocks later)
	# This communicates to player that piercing WOULD bypass armor, but screen still works
	if piercing_weapon:
		result["effects"].append("armor_pierced")

	# Step 1: Check SCREEN saves first (never ignored by piercing)
	# Screen saves come from protective devices like Energy Shield Generator
	var has_screen: bool = target.get("has_screen", false)
	var screen_save: int = target.get("screen_save", 0)  # e.g., 5 for 5+ save

	if has_screen and screen_save > 0:
		# Screen save: roll >= threshold to save
		if armor_roll >= screen_save:
			save_succeeded = true
			result["screen_saved"] = true
			result["effects"].append("screen_deflected")
			result["save_type"] = "screen"
			return result
		else:
			result["effects"].append("screen_failed")

	# Step 2: Check ARMOR saves (only if NOT piercing weapon)
	if not piercing_weapon:
		# Apply reinforced_plating bonus to armor save
		var armor_save_bonus: int = target_armor_mods.get("armor_save_bonus", 0)
		var modified_armor_roll: int = armor_roll + armor_save_bonus
		
		# Get armor traits for trait-based bonuses
		var armor_traits: Array = target.get("armor_traits", [])
		var attack_type: String = "ranged"  # Default to ranged attack
		
		var armor_save_succeeded := check_armor_save(
			modified_armor_roll,
			target_armor,
			raw_damage,
			target.get("species", ""),
			armor_traits,
			attack_type
		)
		
		if armor_save_bonus > 0:
			result["reinforced_plating_bonus"] = armor_save_bonus
			result["modified_armor_roll"] = modified_armor_roll

		# Reactive plating: allows reroll on failed armor save (once per turn)
		if not armor_save_succeeded and protective_check["reroll_available"]:
			var reroll: int = dice_roller.call()
			result["armor_reroll"] = reroll
			# Apply armor save bonus to reroll as well
			var modified_reroll: int = reroll + armor_save_bonus
			armor_save_succeeded = check_armor_save(
				modified_reroll,
				target_armor,
				raw_damage,
				target.get("species", ""),
				armor_traits,
				attack_type
			)
			if armor_save_succeeded:
				result["effects"].append("reactive_plating_save")

		if armor_save_succeeded:
			result["armor_saved"] = true
			result["save_type"] = "armor"
			return result
	# NOTE: Piercing effect already added above (before screen check)
	# Armor save was skipped for piercing weapons

	# Natural 6 Elimination Rule (Five Parsecs p.46):
	# Target eliminated if damage die is 6 OR modified score >= Toughness
	var modified_damage := damage_roll + raw_damage
	var target_eliminated := damage_roll == 6 or modified_damage >= target_toughness
	result["target_eliminated"] = target_eliminated

	if target_eliminated:
		result["damage"] = target_toughness  # Full elimination
		result["wounds_inflicted"] = target_toughness
		result["effects"].append("eliminated")
	else:
		# Survivor is pushed 1" back and Stunned (Five Parsecs p.46)
		result["damage"] = 1  # Non-eliminated hit still causes 1 damage
		result["wounds_inflicted"] = 1
		result["effects"].append("push_back")  # Pushed 1" back
		result["effects"].append("stunned")  # Stunned
	
	# Auto-Medicator: Once per battle, negate first wound (Toughness check 7+)
	if result["wounds_inflicted"] > 0 and not target_eliminated:
		var auto_med_check := check_auto_medicator(target, battle_state, dice_roller)
		result["auto_medicator_check"] = auto_med_check
		
		if auto_med_check.get("can_use", false) and auto_med_check.get("check_passed", false):
			# Wound negated by auto-medicator
			result["wounds_inflicted"] = 0
			result["damage"] = 0
			result["effects"].append("auto_medicator_negated_wound")
			# Remove stun/push effects since wound was negated
			var effects_copy: Array = result["effects"].duplicate()
			effects_copy.erase("stunned")
			effects_copy.erase("push_back")
			result["effects"] = effects_copy

	# Impact trait: Stunned target receives second Stun marker (Five Parsecs p.77)
	if has_trait(weapon_traits, "impact") and "stunned" in result["effects"]:
		result["effects"].append("double_stun")

	# Check for additional special effects
	if has_trait(weapon_traits, "stun") and result["wounds_inflicted"] > 0:
		if "stunned" not in result["effects"]:
			result["effects"].append("stunned")
	if has_trait(weapon_traits, "knockback") and result["wounds_inflicted"] > 0:
		if "push_back" not in result["effects"]:
			result["effects"].append("push_back")

	# Terrifying trait: Target must retreat full move away from shooter (Five Parsecs p.77)
	if has_trait(weapon_traits, "terrifying") and result["hit"]:
		result["effects"].append("forced_retreat")

	# Suppressive trait: Target becomes suppressed on hit (Five Parsecs p.77)
	if has_trait(weapon_traits, "suppressive") and result["hit"]:
		result["effects"].append("suppressed")

	return result

## Resolve brawl (melee) combat
## Five Parsecs p.45:
##   - Weapon bonuses: +2 for Melee weapons, +1 for Pistol weapons
##   - Draw: Both combatants take a Hit
##   - Natural 6: Inflict additional Hit
##   - Natural 1: Suffer additional Hit
##   - Clumsy: -1 if opponent has higher Speed
##   - Elegant: May reroll one die
## Species abilities integrated (Core Rules p.28-32):
##   - K'Erin "Warrior Pride": +1 to brawl roll
##   - Hulker "Crushing Strength": +2 melee damage
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
		"attacker_rerolled": false,
		"defender_rerolled": false,
		"attacker_species_bonus": 0,
		"defender_species_bonus": 0,
		"attacker_damage_bonus": 0,
		"defender_damage_bonus": 0
	}

	# Get combat skills and speed
	var attacker_skill: int = attacker.get("combat_skill", 0)
	var defender_skill: int = defender.get("combat_skill", 0)
	var attacker_speed: int = attacker.get("speed", 4)
	var defender_speed: int = defender.get("speed", 4)

	# Get species for combat bonuses (Core Rules p.28-32)
	var attacker_species: String = attacker.get("species", "").to_lower()
	var defender_species: String = defender.get("species", "").to_lower()

	# Get weapon traits
	var attacker_traits: Array = attacker.get("weapon_traits", [])
	var defender_traits: Array = defender.get("weapon_traits", [])

	# Roll raw dice (track for natural 6/1 effects)
	var attacker_raw: int = dice_roller.call()
	var defender_raw: int = dice_roller.call()

	# K'Erin Warrior Pride: Roll twice in Brawl, use better result (Five Parsecs p.28)
	# This happens BEFORE other reroll effects
	var attacker_is_kerin := attacker_species == "kerin" or attacker_species == "k'erin"
	var defender_is_kerin := defender_species == "kerin" or defender_species == "k'erin"

	if attacker_is_kerin:
		var second_roll: int = dice_roller.call()
		result["attacker_kerin_rolls"] = [attacker_raw, second_roll]
		if second_roll > attacker_raw:
			attacker_raw = second_roll
		result["attacker_kerin_rerolled"] = true

	if defender_is_kerin:
		var second_roll: int = dice_roller.call()
		result["defender_kerin_rolls"] = [defender_raw, second_roll]
		if second_roll > defender_raw:
			defender_raw = second_roll
		result["defender_kerin_rerolled"] = true

	# Elegant trait: May reroll one die in Brawling (Five Parsecs p.77)
	# Note: This is in addition to K'Erin ability (stacks)
	if has_trait(attacker_traits, "elegant") and attacker_raw < 4:
		attacker_raw = dice_roller.call()
		result["attacker_rerolled"] = true
	if has_trait(defender_traits, "elegant") and defender_raw < 4:
		defender_raw = dice_roller.call()
		result["defender_rerolled"] = true

	result["attacker_raw_roll"] = attacker_raw
	result["defender_raw_roll"] = defender_raw

	# Calculate weapon bonuses (Five Parsecs p.45)
	var attacker_weapon_bonus := 0
	if attacker.get("has_melee_weapon", false):
		attacker_weapon_bonus = 2  # +2 for melee weapons
	elif attacker.get("has_pistol", false):
		attacker_weapon_bonus = 1  # +1 for pistols

	var defender_weapon_bonus := 0
	if defender.get("has_melee_weapon", false):
		defender_weapon_bonus = 2
	elif defender.get("has_pistol", false):
		defender_weapon_bonus = 1

	# Species ability: K'Erin "Warrior Pride" - +1 to brawl roll (Core Rules p.28)
	var attacker_species_bonus := 0
	var defender_species_bonus := 0
	var attacker_damage_bonus := 0
	var defender_damage_bonus := 0

	if attacker_species in SPECIES_MODIFIERS:
		var species_data: Dictionary = SPECIES_MODIFIERS[attacker_species]
		attacker_species_bonus = species_data.get("brawl_bonus", 0)
		attacker_damage_bonus = species_data.get("melee_damage_bonus", 0)

	if defender_species in SPECIES_MODIFIERS:
		var species_data: Dictionary = SPECIES_MODIFIERS[defender_species]
		defender_species_bonus = species_data.get("brawl_bonus", 0)
		defender_damage_bonus = species_data.get("melee_damage_bonus", 0)

	result["attacker_species_bonus"] = attacker_species_bonus
	result["defender_species_bonus"] = defender_species_bonus
	result["attacker_damage_bonus"] = attacker_damage_bonus
	result["defender_damage_bonus"] = defender_damage_bonus

	# Clumsy trait: -1 to Brawling if opponent has higher Speed (Five Parsecs p.77)
	var attacker_clumsy_penalty := 0
	var defender_clumsy_penalty := 0
	if has_trait(attacker_traits, "clumsy") and defender_speed > attacker_speed:
		attacker_clumsy_penalty = -1
	if has_trait(defender_traits, "clumsy") and attacker_speed > defender_speed:
		defender_clumsy_penalty = -1

	# Calculate totals: d6 + combat skill + weapon bonus + species bonus + clumsy penalty
	var attacker_roll: int = attacker_raw + attacker_skill + attacker_weapon_bonus + attacker_species_bonus + attacker_clumsy_penalty
	var defender_roll: int = defender_raw + defender_skill + defender_weapon_bonus + defender_species_bonus + defender_clumsy_penalty

	result["attacker_total"] = attacker_roll
	result["defender_total"] = defender_roll

	# Determine base hits from comparison
	if attacker_roll > defender_roll:
		result["winner"] = "attacker"
		result["attacker_hits"] = 1
		result["damage_to_defender"] = 1 + attacker_damage_bonus  # Hulker +2 damage
	elif defender_roll > attacker_roll:
		result["winner"] = "defender"
		result["defender_hits"] = 1
		result["damage_to_attacker"] = 1 + defender_damage_bonus  # Hulker +2 damage
	else:
		# Draw: Both take a Hit (Five Parsecs p.45)
		result["winner"] = "draw"
		result["attacker_hits"] = 1
		result["defender_hits"] = 1
		result["damage_to_attacker"] = 1 + defender_damage_bonus
		result["damage_to_defender"] = 1 + attacker_damage_bonus

	# Natural roll effects (Five Parsecs p.45)
	# Natural 6: Inflict additional Hit (with species damage bonus)
	if attacker_raw == 6:
		result["attacker_hits"] += 1
		result["damage_to_defender"] += 1 + attacker_damage_bonus
	if defender_raw == 6:
		result["defender_hits"] += 1
		result["damage_to_attacker"] += 1 + defender_damage_bonus

	# Natural 1: Suffer additional Hit (no damage bonus when suffering hits)
	if attacker_raw == 1:
		result["defender_hits"] += 1
		result["damage_to_attacker"] += 1
	if defender_raw == 1:
		result["attacker_hits"] += 1
		result["damage_to_defender"] += 1
	
	# Store attack type for armor trait calculations
	result["attack_type"] = "melee"

	return result

## Find all targets within area of effect radius
## Args:
##   impact_position: Position where area weapon hits (Vector2)
##   radius_inches: Radius in tabletop inches (float)
##   all_units: All potential targets on battlefield (Array[Dictionary])
## Returns: Array of targets within radius
static func get_targets_in_area(
	impact_position: Vector2,
	radius_inches: float,
	all_units: Array
) -> Array:
	var targets_in_area: Array = []
	var radius_game_units: float = radius_inches * 2.0  # Assuming 2 game units = 1 inch
	
	for unit in all_units:
		if unit is Dictionary:
			var unit_pos: Vector2 = unit.get("position", Vector2.ZERO)
			var distance: float = impact_position.distance_to(unit_pos)
			if distance <= radius_game_units:
				targets_in_area.append(unit)
	
	return targets_in_area

## Find all targets in spread cone from attacker
## Args:
##   attacker_position: Shooter position (Vector2)
##   primary_target_position: Initial target position (Vector2)
##   cone_width_degrees: Cone width in degrees (default 30°)
##   all_units: All potential targets (Array[Dictionary])
## Returns: Array of targets within cone
static func get_targets_in_spread(
	attacker_position: Vector2,
	primary_target_position: Vector2,
	cone_width_degrees: float,
	all_units: Array
) -> Array:
	var targets_in_cone: Array = []
	
	# Calculate primary direction vector
	var primary_direction: Vector2 = (primary_target_position - attacker_position).normalized()
	var cone_half_angle: float = deg_to_rad(cone_width_degrees / 2.0)
	
	for unit in all_units:
		if unit is Dictionary:
			var unit_pos: Vector2 = unit.get("position", Vector2.ZERO)
			var to_unit: Vector2 = (unit_pos - attacker_position).normalized()
			
			# Calculate angle between primary direction and unit direction
			var angle: float = primary_direction.angle_to(to_unit)
			
			# Check if unit is within cone
			if abs(angle) <= cone_half_angle:
				targets_in_cone.append(unit)
	
	return targets_in_cone

## Resolve area/template weapon attack against multiple targets
## Five Parsecs Rules (Core Rules p.77):
##   - Area weapons: All models within X inches of impact point are hit
##   - Spread weapons: Cone from attacker, multiple targets in arc
##   - Template weapons: All models under template marker
##   - Roll damage ONCE, apply to each target
##   - Each target makes own armor save
## Args:
##   attacker: Attacker dictionary with combat stats
##   primary_target: Initial target dictionary
##   all_potential_targets: All enemies near impact point (Array[Dictionary])
##   weapon: Weapon dictionary with traits and damage
##   dice_roller: Callable returning int (d6 result)
## Returns: Dictionary with primary_result, secondary_targets, template_type, total_hits
static func resolve_area_attack(
	attacker: Dictionary,
	primary_target: Dictionary,
	all_potential_targets: Array,
	weapon: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"primary_result": {},
		"secondary_targets": [],
		"template_type": "",
		"total_hits": 0,
		"total_eliminations": 0,
		"area_radius": 0.0,
		"spread_width": 0.0
	}
	
	# Determine template type from weapon traits
	var weapon_traits: Array = weapon.get("traits", [])
	var template_type: String = ""
	var area_radius: float = 0.0
	var spread_width: float = 30.0  # Default 30° cone
	
	if has_trait(weapon_traits, "area"):
		template_type = "area"
		# Extract area radius from weapon data (default 2" if not specified)
		area_radius = weapon.get("area_radius", 2.0)
	elif has_trait(weapon_traits, "spread"):
		template_type = "spread"
		spread_width = weapon.get("spread_width", 30.0)
	elif has_trait(weapon_traits, "template"):
		template_type = "template"
		area_radius = weapon.get("template_radius", 3.0)
	elif has_trait(weapon_traits, "explosive"):
		template_type = "area"
		area_radius = weapon.get("explosion_radius", 2.0)
	
	result["template_type"] = template_type
	result["area_radius"] = area_radius
	result["spread_width"] = spread_width
	
	# Step 1: Resolve primary target attack normally
	var primary_result := resolve_ranged_attack(attacker, primary_target, weapon, dice_roller)
	result["primary_result"] = primary_result
	
	if primary_result.get("hit", false):
		result["total_hits"] += 1
		if primary_result.get("target_eliminated", false):
			result["total_eliminations"] += 1
	
	# Step 2: Find secondary targets based on template type
	var secondary_targets: Array = []
	var impact_position: Vector2 = primary_target.get("position", Vector2.ZERO)
	var attacker_position: Vector2 = attacker.get("position", Vector2.ZERO)
	
	match template_type:
		"area", "template":
			# All units within radius of impact point
			secondary_targets = get_targets_in_area(impact_position, area_radius, all_potential_targets)
		"spread":
			# All units in cone from attacker
			secondary_targets = get_targets_in_spread(attacker_position, impact_position, spread_width, all_potential_targets)
	
	# Remove primary target from secondary list (already resolved)
	var primary_id: String = primary_target.get("id", "")
	for i in range(secondary_targets.size() - 1, -1, -1):
		var target: Dictionary = secondary_targets[i]
		if target.get("id", "") == primary_id:
			secondary_targets.remove_at(i)
			break
	
	# Step 3: Roll damage ONCE for all targets (Five Parsecs rule)
	var weapon_damage: int = weapon.get("damage", 1)
	var weapon_mods: Dictionary = weapon.get("modification_effects", {})
	var weapon_mod_damage_bonus: int = weapon_mods.get("damage_bonus", 0)
	
	# Use primary hit roll result if available, otherwise roll damage
	var shared_damage_roll: int = primary_result.get("damage_roll", dice_roller.call())
	var raw_damage := calculate_weapon_damage(
		weapon_damage,
		primary_result.get("critical", false),
		weapon_traits,
		{},
		weapon_mod_damage_bonus
	)
	
	result["shared_damage_roll"] = shared_damage_roll
	result["shared_raw_damage"] = raw_damage
	
	# Step 4: Apply damage to each secondary target with individual armor saves
	var secondary_results: Array = []
	
	for target in secondary_targets:
		var target_result := {
			"target_id": target.get("id", ""),
			"target_name": target.get("name", "Unknown"),
			"hit": true,  # Area weapons automatically hit targets in range
			"damage_roll": shared_damage_roll,
			"raw_damage": raw_damage,
			"armor_saved": false,
			"wounds_inflicted": 0,
			"target_eliminated": false,
			"effects": []
		}
		
		# Check protective devices (shields can still block area damage)
		var battle_state: Dictionary = target.get("battle_state", {})
		var protective_check := check_protective_devices(target, 0, dice_roller)
		target_result["protective_devices"] = protective_check
		
		if protective_check["blocked"]:
			target_result["shield_blocked"] = true
			target_result["armor_saved"] = true
			target_result["effects"].append("shield_blocked")
			secondary_results.append(target_result)
			continue
		
		# Each target gets own armor save (Five Parsecs rule)
		var target_armor: String = target.get("armor", "none")
		var target_species: String = target.get("species", "")
		var armor_roll: int = dice_roller.call()
		target_result["armor_roll"] = armor_roll
		
		# Check for piercing weapon (ignores armor but not screens)
		var piercing_weapon := has_trait(weapon_traits, "piercing")
		var armor_save_succeeded := false
		
		# Check screen saves first (never ignored by piercing)
		var has_screen: bool = target.get("has_screen", false)
		var screen_save: int = target.get("screen_save", 0)
		
		if has_screen and screen_save > 0:
			if armor_roll >= screen_save:
				armor_save_succeeded = true
				target_result["screen_saved"] = true
				target_result["save_type"] = "screen"
				target_result["effects"].append("screen_deflected")
		
		# Check armor saves if not piercing and screen didn't save
		if not armor_save_succeeded and not piercing_weapon:
			var target_armor_mods := check_armor_modifications(target, "defense", battle_state)
			var armor_save_bonus: int = target_armor_mods.get("armor_save_bonus", 0)
			var modified_armor_roll: int = armor_roll + armor_save_bonus
			
			armor_save_succeeded = check_armor_save(modified_armor_roll, target_armor, raw_damage, target_species)
			
			if armor_save_bonus > 0:
				target_result["reinforced_plating_bonus"] = armor_save_bonus
				target_result["modified_armor_roll"] = modified_armor_roll
			
			# Reactive plating reroll check
			if not armor_save_succeeded and protective_check["reroll_available"]:
				var reroll: int = dice_roller.call()
				target_result["armor_reroll"] = reroll
				var modified_reroll: int = reroll + armor_save_bonus
				armor_save_succeeded = check_armor_save(modified_reroll, target_armor, raw_damage, target_species)
				if armor_save_succeeded:
					target_result["effects"].append("reactive_plating_save")
		
		if piercing_weapon:
			target_result["effects"].append("armor_pierced")
		
		target_result["armor_saved"] = armor_save_succeeded
		
		if armor_save_succeeded:
			secondary_results.append(target_result)
			continue
		
		# Apply elimination check (same as primary target)
		var target_toughness: int = target.get("toughness", 3)
		var modified_damage := shared_damage_roll + raw_damage
		var target_eliminated := shared_damage_roll == 6 or modified_damage >= target_toughness
		target_result["target_eliminated"] = target_eliminated
		
		if target_eliminated:
			target_result["damage"] = target_toughness
			target_result["wounds_inflicted"] = target_toughness
			target_result["effects"].append("eliminated")
			result["total_eliminations"] += 1
		else:
			target_result["damage"] = 1
			target_result["wounds_inflicted"] = 1
			target_result["effects"].append("push_back")
			target_result["effects"].append("stunned")
		
		# Check auto-medicator for secondary targets
		if target_result["wounds_inflicted"] > 0 and not target_eliminated:
			var auto_med_check := check_auto_medicator(target, battle_state, dice_roller)
			target_result["auto_medicator_check"] = auto_med_check
			
			if auto_med_check.get("can_use", false) and auto_med_check.get("check_passed", false):
				target_result["wounds_inflicted"] = 0
				target_result["damage"] = 0
				target_result["effects"].append("auto_medicator_negated_wound")
				var effects_copy: Array = target_result["effects"].duplicate()
				effects_copy.erase("stunned")
				effects_copy.erase("push_back")
				target_result["effects"] = effects_copy
		
		# Apply weapon trait effects
		if has_trait(weapon_traits, "impact") and "stunned" in target_result["effects"]:
			target_result["effects"].append("double_stun")
		if has_trait(weapon_traits, "terrifying") and target_result["hit"]:
			target_result["effects"].append("forced_retreat")
		if has_trait(weapon_traits, "suppressive") and target_result["hit"]:
			target_result["effects"].append("suppressed")
		
		secondary_results.append(target_result)
		result["total_hits"] += 1
	
	result["secondary_targets"] = secondary_results
	
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

## Roll to seize initiative (2d6 + highest savvy >= 10, Core Rules p.117)
static func check_seize_initiative(
	die1: int,
	die2: int,
	highest_savvy: int
) -> Dictionary:
	var total := die1 + die2 + highest_savvy
	var seized := total >= 10

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

#region Species Ability Utilities

## Get all combat-relevant abilities for a species
## Returns a dictionary of ability flags and modifiers
static func get_species_combat_abilities(species: String) -> Dictionary:
	var species_lower := species.to_lower() if species else ""
	var abilities := {
		"brawl_bonus": 0,
		"melee_damage_bonus": 0,
		"ranged_defense_bonus": 0,
		"ambush_hit_bonus": 0,
		"ambush_damage_bonus": 0,
		"initiative_bonus": false,
		"natural_armor_save": 7,  # 7 = no natural armor
		"no_consumables": false,
		"bot_injury_table": false,
		"auto_tech_success": false,
		"tech_bonus": 0,
		"repair_bonus": 0
	}

	# Check for species modifiers
	if species_lower in SPECIES_MODIFIERS:
		var mods: Dictionary = SPECIES_MODIFIERS[species_lower]
		abilities["brawl_bonus"] = mods.get("brawl_bonus", 0)
		abilities["melee_damage_bonus"] = mods.get("melee_damage_bonus", 0)
		abilities["ranged_defense_bonus"] = mods.get("ranged_defense_bonus", 0)
		abilities["ambush_hit_bonus"] = mods.get("ambush_hit_bonus", 0)
		abilities["ambush_damage_bonus"] = mods.get("ambush_damage_bonus", 0)
		abilities["initiative_bonus"] = mods.get("initiative_bonus", false)
		abilities["no_consumables"] = mods.get("no_consumables", false)
		abilities["bot_injury_table"] = mods.get("bot_injury_table", false)
		abilities["auto_tech_success"] = mods.get("auto_tech_success", false)
		abilities["tech_bonus"] = mods.get("tech_bonus", 0)
		abilities["repair_bonus"] = mods.get("repair_bonus", 0)

	# Check for natural armor
	if species_lower in SPECIES_NATURAL_ARMOR:
		abilities["natural_armor_save"] = SPECIES_NATURAL_ARMOR[species_lower]

	return abilities

## Check if species has a specific combat ability
static func species_has_ability(species: String, ability_name: String) -> bool:
	var abilities := get_species_combat_abilities(species)
	return abilities.has(ability_name) and (
		(abilities[ability_name] is bool and abilities[ability_name]) or
		(abilities[ability_name] is int and abilities[ability_name] != 0) or
		(ability_name == "natural_armor_save" and abilities[ability_name] < 7)
	)

## Check if species uses Bot injury table (Soulless, Bot types)
static func uses_bot_injury_table(species: String) -> bool:
	var species_lower := species.to_lower() if species else ""
	if species_lower in SPECIES_MODIFIERS:
		return SPECIES_MODIFIERS[species_lower].get("bot_injury_table", false)
	return false

## Check if species can use consumable items (returns false for Soulless, Bots)
static func can_use_consumables(species: String) -> bool:
	var species_lower := species.to_lower() if species else ""
	if species_lower in SPECIES_MODIFIERS:
		return not SPECIES_MODIFIERS[species_lower].get("no_consumables", false)
	return true

## Check if species has Lightning Reflexes (Felinoid - acts first in battle)
static func has_initiative_bonus(species: String) -> bool:
	var species_lower := species.to_lower() if species else ""
	if species_lower in SPECIES_MODIFIERS:
		return SPECIES_MODIFIERS[species_lower].get("initiative_bonus", false)
	return false

## Get Stalker ambush bonuses for combat from hiding
static func get_ambush_bonuses(species: String) -> Dictionary:
	var species_lower := species.to_lower() if species else ""
	if species_lower in SPECIES_MODIFIERS:
		var mods: Dictionary = SPECIES_MODIFIERS[species_lower]
		return {
			"hit_bonus": mods.get("ambush_hit_bonus", 0),
			"damage_bonus": mods.get("ambush_damage_bonus", 0)
		}
	return {"hit_bonus": 0, "damage_bonus": 0}

#endregion

#region Weapon Trait Combat Effects

## Get all combat effects for a weapon based on its traits
## Returns a dictionary describing all active effects for UI/battle logging
## Five Parsecs Core Rules p.77
static func get_weapon_combat_effects(weapon_traits: Array, context: Dictionary = {}) -> Dictionary:
	var effects := {
		"hit_modifiers": [],       # Things that modify hit chance
		"damage_modifiers": [],    # Things that modify damage
		"armor_effects": [],       # Things that affect armor saves
		"status_effects": [],      # Effects applied on hit
		"special_effects": [],     # Other special behaviors
		"restrictions": []         # Usage restrictions
	}

	var moved: bool = context.get("moved_this_turn", false)
	var range_inches: float = context.get("range_inches", 12.0)
	var target_speed: int = context.get("target_speed", 4)
	var attacker_speed: int = context.get("attacker_speed", 4)

	for trait_name in weapon_traits:
		var trait_lower = trait_name.to_lower() if trait_name is String else ""
		match trait_lower:
			# Hit Modifiers
			"accurate":
				effects["hit_modifiers"].append({
					"name": "Accurate", "modifier": 1, "condition": "always"
				})
			"slow":
				effects["hit_modifiers"].append({
					"name": "Slow", "modifier": -1, "condition": "close range"
				})
			"heavy":
				if moved:
					effects["hit_modifiers"].append({
						"name": "Heavy (Moved)", "modifier": -1, "condition": "moved this turn"
					})
			"snap_shot":
				if range_inches <= 6.0:
					effects["hit_modifiers"].append({
						"name": "Snap Shot", "modifier": 1, "condition": "within 6\""
					})
			"focused":
				if not moved:
					effects["hit_modifiers"].append({
						"name": "Focused", "modifier": 1, "condition": "didn't move"
					})
			"rapid_fire":
				effects["hit_modifiers"].append({
					"name": "Rapid Fire", "modifier": 1, "condition": "volume of fire"
				})

			# Damage Modifiers
			"devastating":
				effects["damage_modifiers"].append({
					"name": "Devastating", "modifier": 1
				})
			"powered":
				effects["damage_modifiers"].append({
					"name": "Powered", "modifier": 1
				})

			# Armor Effects
			"piercing":
				effects["armor_effects"].append({
					"name": "Piercing", "effect": "Ignores armor saves"
				})

			# Status Effects
			"terrifying":
				effects["status_effects"].append({
					"name": "Terrifying", "effect": "Target retreats full move on hit"
				})
			"impact":
				effects["status_effects"].append({
					"name": "Impact", "effect": "Double Stun if target already Stunned"
				})
			"stun":
				effects["status_effects"].append({
					"name": "Stun", "effect": "Target is Stunned on hit"
				})
			"suppressive":
				effects["status_effects"].append({
					"name": "Suppressive", "effect": "Target is Suppressed on hit"
				})
			"knockback":
				effects["status_effects"].append({
					"name": "Knockback", "effect": "Target is pushed back"
				})

			# Special Effects
			"critical":
				effects["special_effects"].append({
					"name": "Critical", "effect": "Natural 6 inflicts 2 Hits"
				})
			"area", "template", "explosive", "spread":
				effects["special_effects"].append({
					"name": "Area Effect", "effect": "Hits multiple targets in range"
				})
			"reliable":
				effects["special_effects"].append({
					"name": "Reliable", "effect": "Re-roll damage 1s"
				})
			"unstable":
				effects["special_effects"].append({
					"name": "Unstable", "effect": "10% chance of malfunction"
				})
			"silent":
				effects["special_effects"].append({
					"name": "Silent", "effect": "Does not alert enemies"
				})
			"loud":
				effects["special_effects"].append({
					"name": "Loud", "effect": "Alerts nearby enemies"
				})

			# Brawling Effects (Melee)
			"melee":
				effects["special_effects"].append({
					"name": "Melee Weapon", "effect": "+2 in Brawling"
				})
			"pistol":
				effects["special_effects"].append({
					"name": "Pistol", "effect": "+1 in Brawling"
				})
			"elegant":
				effects["special_effects"].append({
					"name": "Elegant", "effect": "Re-roll one die in Brawling"
				})
			"clumsy":
				if target_speed > attacker_speed:
					effects["special_effects"].append({
						"name": "Clumsy", "effect": "-1 Brawling vs faster opponent"
					})

			# Restrictions
			"two_handed":
				effects["restrictions"].append({
					"name": "Two-handed", "effect": "Cannot use shield"
				})
			"single_shot":
				effects["restrictions"].append({
					"name": "Single Shot", "effect": "One use per battle"
				})
			"one_use", "thrown":
				effects["restrictions"].append({
					"name": "Consumable", "effect": "Removed after use"
				})
			"limited_ammo":
				effects["restrictions"].append({
					"name": "Limited Ammo", "effect": "Low ammunition supply"
				})
			"hot":
				effects["restrictions"].append({
					"name": "Hot", "effect": "Risk of overheating"
				})
			"psionic":
				effects["restrictions"].append({
					"name": "Psionic", "effect": "Requires psyker to use"
				})

	return effects

## Get a human-readable summary of weapon trait effects
static func get_trait_effects_summary(weapon_traits: Array, context: Dictionary = {}) -> String:
	var effects := get_weapon_combat_effects(weapon_traits, context)
	var summary_parts := []

	# Hit modifiers
	for mod in effects["hit_modifiers"]:
		var sign := "+" if mod["modifier"] > 0 else ""
		summary_parts.append("%s%d Hit (%s)" % [sign, mod["modifier"], mod["name"]])

	# Damage modifiers
	for mod in effects["damage_modifiers"]:
		summary_parts.append("+%d Damage (%s)" % [mod["modifier"], mod["name"]])

	# Armor effects
	for eff in effects["armor_effects"]:
		summary_parts.append(eff["effect"])

	# Status effects
	for eff in effects["status_effects"]:
		summary_parts.append(eff["effect"])

	# Special effects
	for eff in effects["special_effects"]:
		summary_parts.append(eff["name"] + ": " + eff["effect"])

	if summary_parts.is_empty():
		return "No special effects"

	return ", ".join(summary_parts)

#endregion

#region Utility Device Effects

## Check for utility device bonuses based on action type
## Args:
##   character: Character data dictionary
##   action_type: "attack", "move", "detect", "coordination"
## Returns: Dictionary of bonuses {reroll_ones: bool, can_jump: bool, jump_distance: int, etc.}
static func check_utility_device_effects(character: Dictionary, action_type: String) -> Dictionary:
	var bonuses: Dictionary = {}
	
	# Get equipped devices - check for utility device fields
	var equipment: Array = character.get("equipment", [])
	var utility_devices: Array = character.get("utility_devices", [])
	
	# Battle Visor - reroll 1s on attacks
	if action_type == "attack":
		if _has_device(equipment, utility_devices, "battle_visor"):
			bonuses["reroll_ones"] = true
	
	# Jump Belt - allow jump movement
	if action_type == "move":
		if _has_device(equipment, utility_devices, "jump_belt"):
			bonuses["can_jump"] = true
			bonuses["jump_distance"] = 9
		if _has_device(equipment, utility_devices, "grapple_launcher"):
			bonuses["can_climb"] = true
			bonuses["climb_distance"] = 12
	
	# Motion Tracker - detect hidden enemies
	if action_type == "detect":
		if _has_device(equipment, utility_devices, "motion_tracker"):
			bonuses["detection_range"] = 12
	
	# Communicator - reaction dice bonus for crew
	if action_type == "coordination":
		if _has_device(equipment, utility_devices, "communicator"):
			bonuses["reaction_dice_bonus"] = 1
	
	return bonuses

## Check Jump Belt effects on movement
## Returns: {active: bool, effect: String, movement_bonus: int, can_jump_gaps: bool}
static func check_jump_belt(character: Dictionary) -> Dictionary:
	var equipment: Array = character.get("equipment", [])
	var utility_devices: Array = character.get("utility_devices", [])
	
	var has_belt: bool = _has_device(equipment, utility_devices, "jump_belt")
	
	return {
		"active": has_belt,
		"effect": "Can jump up to 9\" ignoring terrain" if has_belt else "",
		"movement_bonus": 2 if has_belt else 0,  # +2" base movement
		"can_jump_gaps": has_belt,
		"jump_distance": 9 if has_belt else 0
	}

## Check Motion Tracker effects on detection
## Returns: {active: bool, effect: String, revealed_enemies: Array[Enemy]}
static func check_motion_tracker(character: Dictionary, enemies: Array) -> Array:
	var equipment: Array = character.get("equipment", [])
	var utility_devices: Array = character.get("utility_devices", [])
	
	if not _has_device(equipment, utility_devices, "motion_tracker"):
		return []
	
	var revealed_enemies: Array = []
	var char_pos: Vector2 = character.get("position", Vector2.ZERO)
	var detection_range: float = 12.0  # 12" detection range
	
	for enemy in enemies:
		if enemy is Dictionary:
			var enemy_pos: Vector2 = enemy.get("position", Vector2.ZERO)
			var distance: float = char_pos.distance_to(enemy_pos)
			var is_hidden: bool = enemy.get("is_hidden", false)
			
			if is_hidden and distance <= detection_range:
				revealed_enemies.append(enemy)
	
	return revealed_enemies

## Check Grapple Launcher effects on movement
## Returns: {active: bool, effect: String, climb_free: bool, climb_distance: int}
static func check_grapple_launcher(character: Dictionary) -> Dictionary:
	var equipment: Array = character.get("equipment", [])
	var utility_devices: Array = character.get("utility_devices", [])
	
	var has_launcher: bool = _has_device(equipment, utility_devices, "grapple_launcher")
	
	return {
		"active": has_launcher,
		"effect": "Can climb up to 12\" vertically without movement cost" if has_launcher else "",
		"climb_free": has_launcher,
		"climb_distance": 12 if has_launcher else 0
	}

## Check Communicator effects on coordination
## Returns: {active: bool, effect: String, affected_allies: Array, bonus: int}
static func check_communicator(character: Dictionary, allies: Array) -> Dictionary:
	var equipment: Array = character.get("equipment", [])
	var utility_devices: Array = character.get("utility_devices", [])
	
	var has_comm: bool = _has_device(equipment, utility_devices, "communicator")
	
	if not has_comm:
		return {
			"active": false,
			"effect": "",
			"affected_allies": [],
			"bonus": 0
		}
	
	var affected_allies: Array = []
	var char_pos: Vector2 = character.get("position", Vector2.ZERO)
	var comm_range: float = 24.0  # 12" range = 24 game units (assuming 2 units = 1")
	
	for ally in allies:
		if ally is Dictionary:
			var ally_pos: Vector2 = ally.get("position", Vector2.ZERO)
			var distance: float = char_pos.distance_to(ally_pos)
			
			if distance <= comm_range:
				affected_allies.append(ally)
	
	return {
		"active": has_comm,
		"effect": "+1 reaction die for all crew within 12\"",
		"affected_allies": affected_allies,
		"bonus": 1
	}

## Helper: Check if character has a specific utility device
static func _has_device(equipment: Array, utility_devices: Array, device_id: String) -> bool:
	for item in equipment:
		if item is Dictionary and item.get("id", "") == device_id:
			return true
		elif item is String and item == device_id:
			return true
	for device in utility_devices:
		if device is Dictionary and device.get("id", "") == device_id:
			return true
		elif device is String and device == device_id:
			return true
	return false

#endregion

#region Armor Modification Effects

## Check armor modification effects on combat
## Args:
##   character: Character data dictionary with equipped_armor_mods
##   context: "attack", "defense", "movement", "environment"
##   battle_state: Battle-wide state for tracking one-time effects (auto_medicator usage)
## Returns: Dictionary of modifiers and flags
## 
## Complete implementation of all 10 armor mods from data/armor.json:
##   1. reinforced_plating - +1 to armor save
##   2. lightweight_materials - No movement penalty flag
##   3. auto_medicator - Negate first wound per battle (requires tracking)
##   4. stealth_coating - -1 to enemy hit rolls
##   5. enhanced_power_cells - Powered armor lasts longer (flag)
##   6. integrated_jetpack - Alternative movement mode (flag)
##   7. enhanced_targeting - +1 to hit rolls
##   8. environmental_seals - Immune to environmental hazards (flag)
##   9. camouflage_system - Already implemented in apply_camouflage_modifier()
##   10. reactive_plating - Already implemented in check_protective_devices()
static func check_armor_modifications(
	character: Dictionary,
	context: String,
	battle_state: Dictionary = {}
) -> Dictionary:
	var modifiers := {
		"armor_save_bonus": 0,
		"hit_bonus": 0,
		"hit_penalty_vs_me": 0,
		"stealth_bonus": 0,
		"lightweight": false,
		"auto_medicator_available": false,
		"enhanced_power_cells": false,
		"jetpack_available": false,
		"environmental_immunity": false
	}
	
	var equipped_mods: Array = character.get("equipped_armor_mods", [])
	if equipped_mods.is_empty():
		return modifiers
	
	var character_id: String = character.get("id", "")
	
	# Check each armor modification
	for mod_id in equipped_mods:
		var mod_name: String = str(mod_id) if mod_id else ""
		
		match mod_name:
			"reinforced_plating":
				# +1 to armor save (improves save by 1, e.g., 4+ becomes 3+)
				if context == "defense":
					modifiers["armor_save_bonus"] += 1
			
			"lightweight_materials":
				# No movement penalty from armor encumbrance
				modifiers["lightweight"] = true
			
			"auto_medicator":
				# Once per battle, negate first wound (requires Toughness check 7+)
				if context == "defense":
					var auto_med_key := "auto_medicator_used_" + character_id
					var already_used: bool = battle_state.get(auto_med_key, false)
					if not already_used:
						modifiers["auto_medicator_available"] = true
			
			"stealth_coating":
				# +1 to Stealth checks (stored for movement system)
				# -1 to enemy hit rolls (applied as penalty to attacker)
				if context == "defense":
					modifiers["hit_penalty_vs_me"] += 1
				if context == "movement":
					modifiers["stealth_bonus"] += 1
			
			"enhanced_power_cells":
				# Doubles operational duration of powered armor/shields
				modifiers["enhanced_power_cells"] = true
			
			"integrated_jetpack":
				# Move additional 6" in any direction once per turn
				if context == "movement":
					modifiers["jetpack_available"] = true
			
			"enhanced_targeting":
				# +1 to hit with ranged attacks
				if context == "attack":
					modifiers["hit_bonus"] += 1
			
			"environmental_seals":
				# Immunity to airborne toxins, can breathe in vacuum
				modifiers["environmental_immunity"] = true
			
			"camouflage_system":
				# +2 to Stealth, -2 to enemy hit when stationary
				# Already implemented in apply_camouflage_modifier()
				# This case ensures it's documented but uses existing function
				pass
			
			"reactive_plating":
				# Reroll failed armor saves once per turn
				# Already implemented in check_protective_devices()
				# This case ensures it's documented but uses existing function
				pass
	
	return modifiers

## Mark auto-medicator as used for a character in battle state
## Call this after successfully negating a wound with auto-medicator
static func mark_auto_medicator_used(battle_state: Dictionary, character_id: String) -> void:
	var auto_med_key := "auto_medicator_used_" + character_id
	battle_state[auto_med_key] = true

## Check if auto-medicator can negate a wound
## Returns: {can_use: bool, requires_check: bool, check_threshold: int}
static func check_auto_medicator(
	character: Dictionary,
	battle_state: Dictionary,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"can_use": false,
		"check_passed": false,
		"roll": 0,
		"threshold": 7
	}
	
	var armor_mods := check_armor_modifications(character, "defense", battle_state)
	if not armor_mods.get("auto_medicator_available", false):
		return result
	
	result["can_use"] = true
	
	# Make Toughness check (7+)
	var roll: int = dice_roller.call()
	result["roll"] = roll
	result["check_passed"] = roll >= 7
	
	if result["check_passed"]:
		# Mark as used in battle state
		var character_id: String = character.get("id", "")
		mark_auto_medicator_used(battle_state, character_id)
	
	return result

#endregion

#region Armor Trait Effects

## Get human-readable description of armor trait combat effects
## Returns summary of what traits do in combat
static func get_armor_trait_description(trait_name: String) -> String:
	var trait_lower := trait_name.to_lower()
	
	var descriptions := {
		"impact_resistant": "+2 to armor save vs melee attacks",
		"durable": "+1 to armor save vs high damage (3+)",
		"heavy": "+1 to armor save vs explosive weapons",
		"ablative": "Absorb one extra hit, then lose 1 save value",
		"regenerating": "Recharges after being depleted",
		"lightweight": "No movement penalty from encumbrance",
		"flexible": "Does not restrict movement",
		"sealed": "Immunity to airborne hazards, vacuum",
		"powered": "Requires power cells to operate",
		"modular": "Can attach armor modifications",
		"environmental": "Protection against environmental hazards",
		"strength_enhancing": "Provides bonus to Strength checks",
		"enhanced_mobility": "Increases movement speed",
		"intimidating": "Bonus to Intimidation checks"
	}
	
	return descriptions.get(trait_lower, trait_name.capitalize())

## Get all combat-relevant armor traits for display
## Returns array of {name: String, description: String, active: bool}
static func get_armor_combat_traits(armor_traits: Array, attack_type: String = "ranged") -> Array:
	var relevant_traits: Array = []
	
	for trait in armor_traits:
		var trait_lower := str(trait).to_lower() if trait else ""
		var trait_info := {
			"name": str(trait).capitalize() if trait else "",
			"description": get_armor_trait_description(str(trait)),
			"active": false
		}
		
		# Determine if trait is active for current attack type
		match trait_lower:
			"impact_resistant":
				trait_info["active"] = (attack_type == "melee")
			"heavy":
				trait_info["active"] = (attack_type == "explosive")
			"durable", "ablative", "regenerating":
				trait_info["active"] = true  # Always relevant in combat
			_:
				trait_info["active"] = false  # Non-combat trait
		
		if trait_info["active"] or attack_type == "all":
			relevant_traits.append(trait_info)
	
	return relevant_traits

#endregion
