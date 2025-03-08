@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends BaseStrangeCharacters

const Self = preload("res://src/game/campaign/crew/FiveParsecsStrangeCharacters.gd")
const BaseStrangeCharacters = preload("res://src/base/campaign/crew/BaseStrangeCharacters.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

enum StrangeCharacterType {
	ROBOT = 0,
	ALIEN = 1,
	UPLIFTED_ANIMAL = 2,
	PSIONICIST = 3,
	MYSTIC = 4,
	GENETICALLY_MODIFIED = 5
}

func _init(_type: int = StrangeCharacterType.ROBOT):
	super(_type)
	# GameStateManager will be accessed when needed instead of storing a reference

func _set_special_abilities() -> void:
	special_abilities.clear()
	
	match type:
		StrangeCharacterType.ROBOT:
			special_abilities.append("Mechanical Body")
			special_abilities.append("Logic Circuits")
			saving_throw = 4
		StrangeCharacterType.ALIEN:
			special_abilities.append("Alien Physiology")
			special_abilities.append("Strange Senses")
			saving_throw = 3
		StrangeCharacterType.UPLIFTED_ANIMAL:
			special_abilities.append("Enhanced Instincts")
			special_abilities.append("Natural Weapons")
			saving_throw = 3
		StrangeCharacterType.PSIONICIST:
			special_abilities.append("Mental Powers")
			special_abilities.append("Sixth Sense")
			saving_throw = 2
		StrangeCharacterType.MYSTIC:
			special_abilities.append("Mystical Knowledge")
			special_abilities.append("Arcane Insight")
			saving_throw = 2
		StrangeCharacterType.GENETICALLY_MODIFIED:
			special_abilities.append("Enhanced Genetics")
			special_abilities.append("Adaptive Biology")
			saving_throw = 3

func _apply_type_specific_abilities(character) -> void:
	if not character:
		push_error("Cannot apply type-specific abilities to null character")
		return
		
	match type:
		StrangeCharacterType.ROBOT:
			_apply_robot_abilities(character)
		StrangeCharacterType.ALIEN:
			_apply_alien_abilities(character)
		StrangeCharacterType.UPLIFTED_ANIMAL:
			_apply_uplifted_animal_abilities(character)
		StrangeCharacterType.PSIONICIST:
			_apply_psionicist_abilities(character)
		StrangeCharacterType.MYSTIC:
			_apply_mystic_abilities(character)
		StrangeCharacterType.GENETICALLY_MODIFIED:
			_apply_genetically_modified_abilities(character)

func _apply_robot_abilities(character) -> void:
	# Robots are immune to poison and disease
	_set_character_property(character, "toughness", _get_character_property(character, "toughness", 3) + 1)
	
	# Robots have reduced savvy for social interactions
	_set_character_property(character, "savvy", _get_character_property(character, "savvy", 0) - 1)
	
	# Add robot-specific traits
	var traits = _get_character_property(character, "traits", [])
	traits.append("Immune to Poison")
	traits.append("Immune to Disease")
	traits.append("Requires Maintenance")
	_set_character_property(character, "traits", traits)

func _apply_alien_abilities(character) -> void:
	# Aliens have enhanced reactions
	_set_character_property(character, "reactions", _get_character_property(character, "reactions", 1) + 1)
	
	# Aliens may have special movement abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for special movement type
	var movement_roll = randi() % 6 + 1
	if movement_roll <= 2:
		traits.append("Climber")
	elif movement_roll <= 4:
		traits.append("Jumper")
	else:
		traits.append("Swimmer")
		
	_set_character_property(character, "traits", traits)

func _apply_uplifted_animal_abilities(character) -> void:
	# Uplifted animals have enhanced speed
	_set_character_property(character, "speed", _get_character_property(character, "speed", 4) + 1)
	
	# Uplifted animals have natural weapons
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for natural weapon type
	var weapon_roll = randi() % 6 + 1
	if weapon_roll <= 2:
		traits.append("Claws")
	elif weapon_roll <= 4:
		traits.append("Fangs")
	else:
		traits.append("Horns")
		
	_set_character_property(character, "traits", traits)

func _apply_psionicist_abilities(character) -> void:
	# Psionicists have enhanced savvy
	_set_character_property(character, "savvy", _get_character_property(character, "savvy", 0) + 1)
	
	# Psionicists have mental powers
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for psionic ability
	var psi_roll = randi() % 6 + 1
	if psi_roll <= 2:
		traits.append("Telekinesis")
	elif psi_roll <= 4:
		traits.append("Mind Reading")
	else:
		traits.append("Mental Blast")
		
	_set_character_property(character, "traits", traits)

func _apply_mystic_abilities(character) -> void:
	# Mystics have enhanced luck
	_set_character_property(character, "luck", _get_character_property(character, "luck", 0) + 1)
	
	# Mystics have mystical abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for mystical ability
	var mystic_roll = randi() % 6 + 1
	if mystic_roll <= 2:
		traits.append("Foresight")
	elif mystic_roll <= 4:
		traits.append("Healing Touch")
	else:
		traits.append("Arcane Knowledge")
		
	_set_character_property(character, "traits", traits)

func _apply_genetically_modified_abilities(character) -> void:
	# Genetically modified characters have enhanced toughness
	_set_character_property(character, "toughness", _get_character_property(character, "toughness", 3) + 1)
	
	# Genetically modified characters have adaptive abilities
	var traits = _get_character_property(character, "traits", [])
	
	# Roll for genetic modification
	var gene_roll = randi() % 6 + 1
	if gene_roll <= 2:
		traits.append("Regeneration")
	elif gene_roll <= 4:
		traits.append("Enhanced Senses")
	else:
		traits.append("Adaptive Skin")
		
	_set_character_property(character, "traits", traits)

func get_type_name() -> String:
	match type:
		StrangeCharacterType.ROBOT:
			return "Robot"
		StrangeCharacterType.ALIEN:
			return "Alien"
		StrangeCharacterType.UPLIFTED_ANIMAL:
			return "Uplifted Animal"
		StrangeCharacterType.PSIONICIST:
			return "Psionicist"
		StrangeCharacterType.MYSTIC:
			return "Mystic"
		StrangeCharacterType.GENETICALLY_MODIFIED:
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