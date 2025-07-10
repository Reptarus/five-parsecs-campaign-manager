extends BaseBattleCharacter
class_name FPCM_BattleCharacter

const FiveParsecsCharacter = preload("res://src/game/character/Character.gd")
# We'll assume GlobalEnums is defined elsewhere and accessible globally
# If not, you'll need to create or locate the actual GlobalEnums file

# Override the character_data with the specific type
# We can't use property overrides with getters/setters in GDScript 2.0
# so we'll use a different approach
var _character_data: FiveParsecsCharacter

# Override the get_character_data method
func get_character_data() -> FiveParsecsCharacter:
	return _character_data

func _init(data: FiveParsecsCharacter = null) -> void:
	super (data)
	if data:
		_character_data = data
	else:
		_character_data = FiveParsecsCharacter.new()

# Override the virtual methods with game-specific implementations

func initialize_for_battle() -> void:
	super.initialize_for_battle()
	# Use a constant for NONE if GlobalEnums is not available
	current_action = 0 # Replace with GlobalEnums.UnitAction.NONE when available
	# Additional game-specific initialization

func cleanup_battle() -> void:
	super.cleanup_battle()
	# Use a constant for NONE if GlobalEnums is not available
	current_action = 0 # Replace with GlobalEnums.UnitAction.NONE when available
	# Additional game-specific cleanup

# Implement the virtual methods from the base class

func can_perform_action(action_type: int) -> bool:
	return action_type in available_actions and is_active

func perform_action(action_type: int, target = null) -> void:
	if can_perform_action(action_type):
		current_action = action_type
		# Implement game-specific action logic

func take_damage(amount: int) -> void:
	_character_data.health = max(0, _character_data.health - amount)
	# Additional game-specific damage logic

func heal(amount: int) -> void:
	_character_data.health = min(_character_data.max_health, _character_data.health + amount)
	# Additional game-specific healing logic

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null