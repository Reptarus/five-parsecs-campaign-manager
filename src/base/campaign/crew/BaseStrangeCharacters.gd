class_name BaseStrangeCharacters
extends Resource

var type: int # Will be defined by game-specific enums
var special_abilities: Array[String] = []
var saving_throw: int = 0

var game_state_manager = null

func _init(_type: int = 0):
	type = _type
	_set_special_abilities()

func _set_special_abilities() -> void:
	# To be implemented by derived classes
	push_error("_set_special_abilities must be implemented by derived classes")

## Safe Property Access Methods
func _get_character_property(character, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		return default_value
	return character.get(property)

func _set_character_property(character, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing property: %s" % property)
		return
	character.set(property, value)

func apply_special_abilities(character) -> void:
	if not character:
		push_error("Cannot apply special abilities to null character")
		return
		
	for ability in special_abilities:
		if not "traits" in character:
			push_error("Character missing traits array")
			return
		character.traits.append(ability)

	# Game-specific implementation should be handled by derived classes
	_apply_type_specific_abilities(character)

func _apply_type_specific_abilities(character) -> void:
	# To be implemented by derived classes
	push_error("_apply_type_specific_abilities must be implemented by derived classes")

func serialize() -> Dictionary:
	return {
		"type": type,
		"special_abilities": special_abilities,
		"saving_throw": saving_throw
	}

func deserialize(data: Dictionary) -> void:
	if data.has("type"):
		type = data.type
	
	if data.has("special_abilities"):
		special_abilities = data.special_abilities
	
	if data.has("saving_throw"):
		saving_throw = data.saving_throw