@tool
extends RefCounted
class_name PsionicSystem

## Five Parsecs Psionic System Implementation
##
## Handles psionic powers, projection mechanics, and character abilities
## following Five Parsecs From Home Core Rules.

const Character = preload("res://src/core/character/Character.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")
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
			print("Psionic strained and is Stunned.")
		elif strain_roll == 6:
			psionic_character.add_stun_marker()
			print("Psionic strained, is Stunned, and power failed.")
			var power_dict = {"type": power.power_type, "name": power.name}
			psionic_power_used.emit(psionic_character.character, power_dict, false)
			return false
	
	var success = total_range >= range_needed
	if success:
		print("Psionic power %s used successfully!" % power.name)
	else:
		print("Psionic power %s failed to reach target." % power.name)
	
	var power_dict = {"type": power.power_type, "name": power.name}
	psionic_power_used.emit(psionic_character.character, power_dict, success)
	return success

func acquire_psionic_power(psionic_character: PsionicCharacter, dice_system = null) -> bool:
	"""Acquire new psionic power with experience points (XP)"""
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
	print("Acquired new psionic power: %s" % new_power.name)
	return true

func enhance_psionic_power(psionic_character: PsionicCharacter, power: PsionicPower) -> bool:
	"""Enhance existing psionic power with experience points (XP)"""
	if power in psionic_character.psionic_powers:
		power.enhanced = true
		print("Enhanced psionic power: %s" % power.name)
		return true
	
	print("Character does not possess the power to enhance: %s" % power.name)
	return false

func create_psionic_character(base_character: Character) -> PsionicCharacter:
	"""Create a new psionic character with starting powers"""
	var psionic_char = PsionicCharacter.new(base_character)
	var starting_powers = determine_starting_powers()
	
	for power in starting_powers:
		psionic_char.add_power(power)
	
	return psionic_char

func get_power_by_type(power_type: PsionicPowerType) -> PsionicPower:
	"""Get a power instance by its type"""
	return PsionicPower.new(power_type)

func get_all_power_types() -> Array[PsionicPowerType]:
	"""Get all available power types"""
	return power_enum_values.duplicate()
