@tool
extends BaseBattleCharacter
class_name FiveParsecsBattleCharacter

const FiveParsecsCharacter = preload("res://src/game/character/Character.gd")
# We'll assume GameEnums is defined elsewhere and accessible globally
# If not, you'll need to create or locate the actual GameEnums file

# Override the character_data with the specific type
# We can't use property overrides with getters/setters in GDScript 2.0
# so we'll use a different approach
var _character_data: FiveParsecsCharacter

# Override the get_character_data method
func get_character_data() -> FiveParsecsCharacter:
	return _character_data

func _init(data: FiveParsecsCharacter = null) -> void:
	if data:
		_character_data = data
	else:
		_character_data = FiveParsecsCharacter.new()

# We need to override these properties from the base class
# by using different internal implementation
func _get_character_name() -> String:
	return _character_data.character_name if _character_data else ""

func _set_character_name(value: String) -> void:
	if _character_data:
		_character_data.character_name = value

func _get_health() -> int:
	return _character_data.health if _character_data else 0

func _set_health(value: int) -> void:
	if _character_data:
		_character_data.health = value

func _get_max_health() -> int:
	return _character_data.max_health if _character_data else 0

func _set_max_health(value: int) -> void:
	if _character_data:
		_character_data.max_health = value

# Override the virtual methods with game-specific implementations
func initialize_for_battle() -> void:
	super.initialize_for_battle()
	# Use a constant for NONE if GameEnums is not available
	current_action = 0 # Replace with GameEnums.UnitAction.NONE when available
	# Additional game-specific initialization

func cleanup_battle() -> void:
	super.cleanup_battle()
	# Use a constant for NONE if GameEnums is not available
	current_action = 0 # Replace with GameEnums.UnitAction.NONE when available
	# Additional game-specific cleanup

# Implement the virtual methods from the base class
func can_perform_action(action_type: int) -> bool:
	return action_type in available_actions and is_active

func perform_action(action_type: int, target = null) -> void:
	if can_perform_action(action_type):
		current_action = action_type
		# Implement game-specific action logic

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	# Additional game-specific damage logic

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	# Additional game-specific healing logic