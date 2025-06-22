@tool
extends "res://src/base/campaign/crew/BaseStrangeCharacters.gd"
class_name FiveParsecsStrangeCharacters

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

enum FPStrangeCharacterType {
	ROBOT = 0,
	ALIEN = 1,
	UPLIFTED_ANIMAL = 2,
	PSIONICIST = 3,
	MYSTIC = 4,
	GENETICALLY_MODIFIED = 5
}

func _init(_type: int = FPStrangeCharacterType.ROBOT) -> void:
	super (_type)
	# GameStateManager will be accessed when needed instead of storing a reference

func _set_special_abilities() -> void:
	special_abilities.clear()
	
	match type:
		FPStrangeCharacterType.ROBOT:
			special_abilities.append("Mechanical Body") # warning: return value discarded (intentional)
			special_abilities.append("Logic Circuits") # warning: return value discarded (intentional)
			saving_throw = 4
		FPStrangeCharacterType.ALIEN:
			special_abilities.append("Alien Physiology") # warning: return value discarded (intentional)
			special_abilities.append("Strange Senses") # warning: return value discarded (intentional)
			saving_throw = 3
		FPStrangeCharacterType.UPLIFTED_ANIMAL:
			special_abilities.append("Enhanced Instincts") # warning: return value discarded (intentional)
			special_abilities.append("Natural Weapons") # warning: return value discarded (intentional)
			saving_throw = 3
		FPStrangeCharacterType.PSIONICIST:
			special_abilities.append("Mental Powers") # warning: return value discarded (intentional)
			special_abilities.append("Sixth Sense") # warning: return value discarded (intentional)
			saving_throw = 2
		FPStrangeCharacterType.MYSTIC:
			special_abilities.append("Mystical Knowledge") # warning: return value discarded (intentional)
			special_abilities.append("Arcane Insight") # warning: return value discarded (intentional)
			saving_throw = 2
		FPStrangeCharacterType.GENETICALLY_MODIFIED:
			special_abilities.append("Enhanced Genetics") # warning: return value discarded (intentional)
			special_abilities.append("Adaptive Biology") # warning: return value discarded (intentional)
			saving_throw = 3

func _apply_type_specific_abilities(character: Variant) -> void:
	if not character:
		push_error("Cannot apply type-specific abilities to null character")
		return
		
	match type:
		FPStrangeCharacterType.ROBOT:
			_apply_robot_abilities(character)
		FPStrangeCharacterType.ALIEN:
			_apply_alien_abilities(character)
		FPStrangeCharacterType.UPLIFTED_ANIMAL:
			_apply_uplifted_animal_abilities(character)
		FPStrangeCharacterType.PSIONICIST:
			_apply_psionicist_abilities(character)
		FPStrangeCharacterType.MYSTIC:
			_apply_mystic_abilities(character)
		FPStrangeCharacterType.GENETICALLY_MODIFIED:
			_apply_genetically_modified_abilities(character)

func _apply_robot_abilities(character: Variant) -> void:
	# Robots are immune to poison and disease
	_set_character_property(character, "toughness", _get_character_property(character, "toughness", 3) + 1)
	
	# Robots have reduced savvy for social interactions
	_set_character_property(character, "savvy", _get_character_property(character, "savvy", 0) - 1)
	
	# Add robot-specific traits
	var traits = _get_character_property(character, "traits", [])
	traits.append("Immune to Poison") # warning: return value discarded (intentional)
	traits.append("Immune to Disease") # warning: return value discarded (intentional)
	traits.append("Requires Maintenance") # warning: return value discarded (intentional)
	_set_character_property(character, "traits", traits)

func _apply_alien_abilities(character: Variant) -> void:
	# Aliens have enhanced reactions
	_set_character_property(character, "reactions", _get_character_property(character, "reactions", 1) + 1)
	
	# Aliens may have special movement abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for special movement type
	var movement_roll = randi() % 6 + 1
	if movement_roll <= 2:
		traits.append("Climber") # warning: return value discarded (intentional)
	elif movement_roll <= 4:
		traits.append("Jumper") # warning: return value discarded (intentional)
	else:
		traits.append("Swimmer") # warning: return value discarded (intentional)
		
	_set_character_property(character, "traits", traits)

func _apply_uplifted_animal_abilities(character: Variant) -> void:
	# Uplifted animals have enhanced speed
	_set_character_property(character, "speed", _get_character_property(character, "speed", 4) + 1)
	
	# Uplifted animals have natural weapons
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for natural weapon type
	var weapon_roll = randi() % 6 + 1
	if weapon_roll <= 2:
		traits.append("Claws") # warning: return value discarded (intentional)
	elif weapon_roll <= 4:
		traits.append("Fangs") # warning: return value discarded (intentional)
	else:
		traits.append("Horns") # warning: return value discarded (intentional)
		
	_set_character_property(character, "traits", traits)

func _apply_psionicist_abilities(character: Variant) -> void:
	# Psionicists have enhanced savvy
	_set_character_property(character, "savvy", _get_character_property(character, "savvy", 0) + 1)
	
	# Psionicists have mental powers
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for psionic ability
	var psi_roll = randi() % 6 + 1
	if psi_roll <= 2:
		traits.append("Telekinesis") # warning: return value discarded (intentional)
	elif psi_roll <= 4:
		traits.append("Mind Reading") # warning: return value discarded (intentional)
	else:
		traits.append("Mental Blast") # warning: return value discarded (intentional)
		
	_set_character_property(character, "traits", traits)

func _apply_mystic_abilities(character: Variant) -> void:
	# Mystics have enhanced luck
	_set_character_property(character, "luck", _get_character_property(character, "luck", 0) + 1)
	
	# Mystics have mystical abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for mystical ability
	var mystic_roll = randi() % 6 + 1
	if mystic_roll <= 2:
		traits.append("Foresight") # warning: return value discarded (intentional)
	elif mystic_roll <= 4:
		traits.append("Healing Touch") # warning: return value discarded (intentional)
	else:
		traits.append("Arcane Knowledge") # warning: return value discarded (intentional)
		
	_set_character_property(character, "traits", traits)

func _apply_genetically_modified_abilities(character: Variant) -> void:
	# Genetically modified characters have enhanced toughness
	_set_character_property(character, "toughness", _get_character_property(character, "toughness", 3) + 1)
	
	# Genetically modified characters have adaptive abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for genetic modification
	var gene_roll = randi() % 6 + 1
	if gene_roll <= 2:
		traits.append("Regeneration") # warning: return value discarded (intentional)
	elif gene_roll <= 4:
		traits.append("Enhanced Senses") # warning: return value discarded (intentional)
	else:
		traits.append("Adaptive Skin") # warning: return value discarded (intentional)
		
	_set_character_property(character, "traits", traits)

func get_type_name() -> String:
	match type:
		FPStrangeCharacterType.ROBOT:
			return "Robot"
		FPStrangeCharacterType.ALIEN:
			return "Alien"
		FPStrangeCharacterType.UPLIFTED_ANIMAL:
			return "Uplifted Animal"
		FPStrangeCharacterType.PSIONICIST:
			return "Psionicist"
		FPStrangeCharacterType.MYSTIC:
			return "Mystic"
		FPStrangeCharacterType.GENETICALLY_MODIFIED:
			return "Genetically Modified"
		_:
			return "Unknown"

func roll_random_type() -> int:
	return randi() % 6

func serialize() -> Dictionary:
	var data = super.serialize()
	# Add any additional Five Parsecs specific data here
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	# Process any additional Five Parsecs specific data here
	_set_special_abilities()