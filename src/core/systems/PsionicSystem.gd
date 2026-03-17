@tool
extends RefCounted
class_name PsionicSystem

## Five Parsecs Psionic System Implementation
##
## Handles psionic powers, projection mechanics, and character abilities
## following Five Parsecs From Home Core Rules.

# DataManager accessed via autoload singleton (not preload)
const DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

signal psionic_power_used(character: Character, power: Dictionary, result: bool)

## Psionic Power Types enum
enum PsionicPowerType {
	UPLIFT,
	LIFT,
	BARRIER,
	GUIDANCE,
	FORCE,
	DISTRACTION,
	STUN,
	PRECOGNITION,
	TELEPATHY,
	KINETIC_BOLT
}

## Power enum values for D10 generation
var power_enum_values: Array[PsionicPowerType] = [
	PsionicPowerType.UPLIFT,
	PsionicPowerType.LIFT,
	PsionicPowerType.BARRIER,
	PsionicPowerType.GUIDANCE,
	PsionicPowerType.FORCE,
	PsionicPowerType.DISTRACTION,
	PsionicPowerType.STUN,
	PsionicPowerType.PRECOGNITION,
	PsionicPowerType.TELEPATHY,
	PsionicPowerType.KINETIC_BOLT
]

## Psionic Power class
class PsionicPower:
	var power_type: PsionicPowerType
	var name: String
	var description: String
	var enhanced: bool = false
	
	func _init(type: PsionicPowerType) -> void:
		power_type = type
		name = _get_power_name(type)
		description = _get_power_description(type)
	
	func _get_power_name(type: PsionicPowerType) -> String:
		match type:
			PsionicPowerType.UPLIFT: return "Uplift"
			PsionicPowerType.LIFT: return "Lift"
			PsionicPowerType.BARRIER: return "Barrier"
			PsionicPowerType.GUIDANCE: return "Guidance"
			PsionicPowerType.FORCE: return "Force"
			PsionicPowerType.DISTRACTION: return "Distraction"
			PsionicPowerType.STUN: return "Stun"
			PsionicPowerType.PRECOGNITION: return "Precognition"
			PsionicPowerType.TELEPATHY: return "Telepathy"
			PsionicPowerType.KINETIC_BOLT: return "Kinetic Bolt"
			_: return "Unknown"
	
	func _get_power_description(type: PsionicPowerType) -> String:
		match type:
			PsionicPowerType.UPLIFT: return "Helps allies move through difficult terrain"
			PsionicPowerType.LIFT: return "Lift objects or characters"
			PsionicPowerType.BARRIER: return "Create protective barriers"
			PsionicPowerType.GUIDANCE: return "Provide tactical guidance"
			PsionicPowerType.FORCE: return "Apply telekinetic force"
			PsionicPowerType.DISTRACTION: return "Distract enemies"
			PsionicPowerType.STUN: return "Stun target characters"
			PsionicPowerType.PRECOGNITION: return "See future events"
			PsionicPowerType.TELEPATHY: return "Communicate telepathically"
			PsionicPowerType.KINETIC_BOLT: return "Launch kinetic projectiles"
			_: return "Unknown power"

## Psionic Character class
class PsionicCharacter:
	var character: Character
	var psionic_powers: Array[PsionicPower] = []
	var stun_markers: int = 0
	var global_position: Vector2 = Vector2.ZERO
	
	func _init(base_character: Character) -> void:
		character = base_character
	
	func can_use_power(power: PsionicPower, target: Character = null) -> bool:
		return stun_markers == 0 and psionic_powers.has(power)
	
	func add_stun_marker() -> void:
		stun_markers += 1
	
	func remove_stun_marker() -> void:
		if stun_markers > 0:
			stun_markers -= 1
	
	func add_power(power: PsionicPower) -> void:
		if not psionic_powers.has(power):
			psionic_powers.append(power)

func determine_starting_powers(dice_system = null) -> Array[PsionicPower]:
	var powers: Array[PsionicPower] = []
	
	# Use provided dice system or DiceManager autoload
	var dice_mgr = dice_system
	if not dice_mgr:
		# Access DiceManager autoload - RefCounted can't use get_node_or_null()
		if Engine.has_singleton("DiceManager"):
			dice_mgr = Engine.get_singleton("DiceManager")
		else:
			dice_mgr = null
	
	for i in range(2):
		var roll: int = 0
		if dice_mgr and dice_mgr.has_method("roll_dice"):
			roll = dice_mgr.roll_dice(1, 10)
		else:
			roll = randi_range(1, 10)
		
		var power_type = power_enum_values[roll - 1] # D10 roll is 1-10, array is 0-9
		var new_power = PsionicPower.new(power_type)
		
		# Handle rolling the same power twice
		var duplicate = false
		for existing_power in powers:
			if existing_power.power_type == new_power.power_type:
				duplicate = true
				break
		
		if duplicate:
			var original_index = power_enum_values.find(power_type)
			if original_index + 1 < power_enum_values.size():
				power_type = power_enum_values[original_index + 1]
			elif original_index - 1 >= 0:
				power_type = power_enum_values[original_index - 1]
			new_power = PsionicPower.new(power_type)
		
		powers.append(new_power)
	
	return powers

func resolve_psionic_projection(psionic_character: PsionicCharacter, power: PsionicPower, target_position: Vector2, target_character: Character = null, dice_system = null) -> bool:
	if not psionic_character.can_use_power(power, target_character):
		return false
	
	# Use provided dice system or DiceManager autoload
	var dice_mgr = dice_system
	if not dice_mgr:
		# Access DiceManager autoload - RefCounted can't use get_node_or_null()
		if Engine.has_singleton("DiceManager"):
			dice_mgr = Engine.get_singleton("DiceManager")
		else:
			dice_mgr = null
	
	var projection_roll: int = 0
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		projection_roll = dice_mgr.roll_dice(2, 6)
	else:
		projection_roll = randi_range(2, 12)
	
	var range_needed = psionic_character.global_position.distance_to(target_position)
	var total_range = projection_roll
	var strained = false
	
	if total_range < range_needed:
		# Attempt strain to extend range
		var strain_roll: int = 0
		if dice_mgr and dice_mgr.has_method("roll_dice"):
			strain_roll = dice_mgr.roll_dice(1, 6)
		else:
			strain_roll = randi_range(1, 6)
		
		total_range += strain_roll
		strained = true
		
		# Resolve strain effects
		if strain_roll == 4 or strain_roll == 5:
			psionic_character.add_stun_marker()
		elif strain_roll == 6:
			psionic_character.add_stun_marker()
			var power_dict = {"type": power.power_type, "name": power.name}
			psionic_power_used.emit(psionic_character.character, power_dict, false)
			return false
	
	var success = total_range >= range_needed
	if success:
		pass
	else:
		pass
	
	var power_dict = {"type": power.power_type, "name": power.name}
	psionic_power_used.emit(psionic_character.character, power_dict, success)
	return success

func acquire_psionic_power(psionic_character: PsionicCharacter, dice_system = null) -> bool:
	## Acquire new psionic power with experience points (XP)
	# Use provided dice system or DiceManager autoload
	var dice_mgr = dice_system
	if not dice_mgr:
		# Access DiceManager autoload - RefCounted can't use get_node_or_null()
		if Engine.has_singleton("DiceManager"):
			dice_mgr = Engine.get_singleton("DiceManager")
		else:
			dice_mgr = null
	
	var roll: int = 0
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		roll = dice_mgr.roll_dice(1, 10)
	else:
		roll = randi_range(1, 10)
	
	var power_type = power_enum_values[roll - 1] # D10 roll is 1-10, array is 0-9
	var new_power = PsionicPower.new(power_type)
	
	# Check for duplicates and handle them
	var has_duplicate = false
	for existing_power in psionic_character.psionic_powers:
		if existing_power.power_type == new_power.power_type:
			has_duplicate = true
			break
	
	if has_duplicate:
		# If duplicate, try adjacent power types
		var original_index = power_enum_values.find(power_type)
		if original_index + 1 < power_enum_values.size():
			power_type = power_enum_values[original_index + 1]
		elif original_index - 1 >= 0:
			power_type = power_enum_values[original_index - 1]
		else:
			# All powers acquired, enhance existing power instead
			return enhance_psionic_power(psionic_character, psionic_character.psionic_powers[0])
		
		new_power = PsionicPower.new(power_type)
	
	psionic_character.add_power(new_power)
	return true

func enhance_psionic_power(psionic_character: PsionicCharacter, power: PsionicPower) -> bool:
	## Enhance existing psionic power with experience points (XP)
	if power in psionic_character.psionic_powers:
		power.enhanced = true
		return true
	
	return false

func create_psionic_character(base_character: Character) -> PsionicCharacter:
	## Create a new psionic character with starting powers
	var psionic_char = PsionicCharacter.new(base_character)
	var starting_powers = determine_starting_powers()
	
	for power in starting_powers:
		psionic_char.add_power(power)
	
	return psionic_char

func get_power_by_type(power_type: PsionicPowerType) -> PsionicPower:
	## Get a power instance by its type
	return PsionicPower.new(power_type)

func get_all_power_types() -> Array[PsionicPowerType]:
	## Get all available power types
	return power_enum_values.duplicate()


## ============================================================================
## PSIONIC LEGALITY SYSTEM (Compendium DLC)
## ============================================================================

enum PsionicLegality { OUTLAWED, HIGHLY_UNUSUAL, WHO_CARES }

## D100 table for world arrival legality roll
static func roll_psionic_legality() -> PsionicLegality:
	var roll := randi_range(1, 100)
	if roll <= 25:
		return PsionicLegality.OUTLAWED
	elif roll <= 55:
		return PsionicLegality.HIGHLY_UNUSUAL
	else:
		return PsionicLegality.WHO_CARES

static func get_legality_name(legality: PsionicLegality) -> String:
	match legality:
		PsionicLegality.OUTLAWED: return "Outlawed"
		PsionicLegality.HIGHLY_UNUSUAL: return "Highly Unusual"
		PsionicLegality.WHO_CARES: return "Who Cares"
		_: return "Unknown"

static func get_legality_description(legality: PsionicLegality) -> String:
	match legality:
		PsionicLegality.OUTLAWED:
			return "Psionic usage risks detection. Post-battle: D6 roll to check if detected. If detected, enforcement encounter next battle."
		PsionicLegality.HIGHLY_UNUSUAL:
			return "If 2+ projection dice show 6, reinforcements arrive end of next round (3D6: 1=none, 2-5=basic, 6=specialist per die)."
		PsionicLegality.WHO_CARES:
			return "No restrictions on psionic usage this world."
		_: return ""

## Post-battle detection check when psionics are OUTLAWED
static func check_outlawed_detection(times_used: int) -> Dictionary:
	var roll := randi_range(1, 6)
	var detected := false
	if times_used == 1:
		detected = (roll == 1)
	elif times_used >= 2:
		detected = (roll <= 2)

	var result := {"detected": detected, "roll": roll, "times_used": times_used}
	if detected:
		result["enforcement"] = _roll_enforcement_type()
	return result

## D6 table for enforcement encounter type
static func _roll_enforcement_type() -> Dictionary:
	var roll := randi_range(1, 6)
	var etype: String
	match roll:
		1, 2: etype = "Bounty Hunters"
		3: etype = "Vigilantes"
		4, 5: etype = "Enforcers"
		6: etype = "Colonial Militia"
		_: etype = "Enforcers"
	return {
		"type": etype,
		"roll": roll,
		"modifiers": {
			"seize_initiative": -2,
			"specialist_bonus": 1,
			"attack_vs_psionics": 1,
		},
		"description": "Psi-Hunters (%s): -2 Seize Initiative, +1 Specialist, +1 attack vs Psionics user" % etype,
	}

## Check if highly unusual reinforcements trigger (2+ projection dice showing 6)
static func check_highly_unusual_reinforcements(projection_dice_results: Array[int]) -> Dictionary:
	var sixes := 0
	for die in projection_dice_results:
		if die == 6:
			sixes += 1
	var triggered := sixes >= 2
	var result := {"triggered": triggered, "sixes": sixes}
	if triggered:
		result["reinforcements"] = _roll_highly_unusual_reinforcements()
	return result

static func _roll_highly_unusual_reinforcements() -> Array[String]:
	var reinforcements: Array[String] = []
	for i in range(3):
		var roll := randi_range(1, 6)
		match roll:
			1: reinforcements.append("none")
			6: reinforcements.append("specialist")
			_: reinforcements.append("basic")
	return reinforcements

static func get_reinforcement_text(reinforcements: Array[String]) -> String:
	var basics := reinforcements.count("basic")
	var specialists := reinforcements.count("specialist")
	var parts: Array[String] = []
	if basics > 0:
		parts.append("%d basic" % basics)
	if specialists > 0:
		parts.append("%d specialist" % specialists)
	if parts.is_empty():
		return "No reinforcements arrive."
	return "Reinforcements arrive at center of enemy edge: %s." % ", ".join(parts)


## ============================================================================
## ENEMY PSIONICS (Compendium DLC)
## ============================================================================

enum EnemyPsionicPower {
	ASSAIL, REFLECT, BOLSTER, SLOW, DIRECT,
	OBSCURE, DOMINATE, CRUSH, PARALYZE, PSIONIC_RAGE
}

const ENEMY_PSIONIC_DATA: Dictionary = {
	EnemyPsionicPower.ASSAIL: {
		"name": "Assail", "description": "Hurl objects at target. Hit: D6 damage, Toughness save applies.",
	},
	EnemyPsionicPower.REFLECT: {
		"name": "Reflect", "description": "Deflect one ranged attack back at attacker this round.",
	},
	EnemyPsionicPower.BOLSTER: {
		"name": "Bolster", "description": "Allied figure within 8\" gets +1 Combat Skill this round.",
	},
	EnemyPsionicPower.SLOW: {
		"name": "Slow", "description": "Target within 12\" halves Speed (round down) this round.",
	},
	EnemyPsionicPower.DIRECT: {
		"name": "Direct", "description": "One ally within 8\" immediately takes a bonus move action.",
	},
	EnemyPsionicPower.OBSCURE: {
		"name": "Obscure", "description": "All ranged attacks against allies within 6\" are at -1 this round.",
	},
	EnemyPsionicPower.DOMINATE: {
		"name": "Dominate", "description": "Target crew member within 12\" must pass D6 vs Savvy or lose next activation.",
	},
	EnemyPsionicPower.CRUSH: {
		"name": "Crush", "description": "Target within 8\" takes D6+2 damage. Armor saves at -1.",
	},
	EnemyPsionicPower.PARALYZE: {
		"name": "Paralyze", "description": "Target within 10\" cannot act next round unless D6 >= 4.",
	},
	EnemyPsionicPower.PSIONIC_RAGE: {
		"name": "Psionic Rage", "description": "Psionic gains +2 Combat Skill and +1 Toughness for rest of battle. One use only.",
	},
}

## Determine if enemy group has a psionic and which powers
static func determine_enemy_psionics(enemy_type: String) -> Dictionary:
	var result := {"has_psionic": false, "powers": [], "profile_text": ""}
	var type_lower := enemy_type.to_lower()

	# Rogue Psionic (Unique Individual) always gets 2 powers
	if type_lower.contains("rogue psionic") or type_lower.contains("psionic"):
		result["has_psionic"] = true
		result["powers"] = _roll_enemy_powers(2)
		result["profile_text"] = "Psionic: Hand Gun + Blade, Toughness 4 (min)"
		return result

	# Swift/Precursors: 1 random figure gets 1 power
	if type_lower.contains("swift") or type_lower.contains("precursor"):
		result["has_psionic"] = true
		result["powers"] = _roll_enemy_powers(1)
		result["profile_text"] = "One random figure is psionic: Hand Gun + Blade, Toughness 4 (min)"
		return result

	# Hulkers/robots/Roving Threats: No psionics, +1 basic instead
	if type_lower.contains("hulker") or type_lower.contains("robot") or type_lower.contains("roving"):
		result["has_psionic"] = false
		result["substitute_text"] = "No psionic capability. Add +1 basic enemy instead."
		return result

	# All others: D6 4+ for 1 power
	var roll := randi_range(1, 6)
	if roll >= 4:
		result["has_psionic"] = true
		result["powers"] = _roll_enemy_powers(1)
		result["profile_text"] = "One enemy is psionic (rolled %d): Hand Gun + Blade, Toughness 4 (min)" % roll
	else:
		result["roll"] = roll
		result["profile_text"] = "No psionic in this group (rolled %d, needed 4+)" % roll

	return result

static func _roll_enemy_powers(count: int) -> Array[Dictionary]:
	var powers: Array[Dictionary] = []
	var all_types := EnemyPsionicPower.values()
	for i in range(count):
		var roll := randi_range(0, all_types.size() - 1)
		var power_type: EnemyPsionicPower = all_types[roll] as EnemyPsionicPower
		var data: Dictionary = ENEMY_PSIONIC_DATA.get(power_type, {})
		powers.append({"type": power_type, "name": data.get("name", "Unknown"), "description": data.get("description", "")})
	return powers

static func get_enemy_psionic_text(psionic_data: Dictionary) -> String:
	if not psionic_data.get("has_psionic", false):
		return psionic_data.get("substitute_text", psionic_data.get("profile_text", "No enemy psionics."))
	var lines: Array[String] = [psionic_data.get("profile_text", "")]
	var powers: Array = psionic_data.get("powers", [])
	for p in powers:
		lines.append("  - %s: %s" % [p.get("name", "?"), p.get("description", "")])
	return "\n".join(lines)
