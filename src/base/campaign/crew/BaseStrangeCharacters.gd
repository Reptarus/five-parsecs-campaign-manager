@tool
extends Resource
class_name BaseStrangeCharacters

var type: int # Will be defined by game-specific enums
var special_abilities: Array[String] = []
var saving_throw: int = 0

var _game_state_manager: Variant = null

func _init(_type: int = 0) -> void:
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

	return character.get(property) if character and character.has_method("get") else default_value

func _set_character_property(character, property: String, _value: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing property: %s" % property)
		return
	if character and character.has_method("set"):
		character.set(property, _value)

func apply_special_abilities(character: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not character:
		push_error("Cannot apply special abilities to null character")
		return

	for ability in special_abilities:
		var typed_ability: Variant = ability
		if not "traits" in character:
			push_error("Character missing traits array")
			return
		safe_call_method(character.traits, "append", [ability])

	# Game-specific implementation should be handled by derived classes
	_apply_type_specific_abilities(character)

func _apply_type_specific_abilities(character: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
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

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null