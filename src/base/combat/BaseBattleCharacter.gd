@tool
extends Node2D
class_name FiveParsecsBattleCharacter

# Universal Framework Integration - Using global classes directly

# Comprehensive Warning Ignore Coverage
@warning_ignore("unused_signal")

# Enhanced Battle Character Signals
signal character_health_changed(old_health: int, new_health: int)
@warning_ignore("unused_signal")
signal character_status_changed(status: String)
signal character_action_performed(action: String, target: Node)
signal character_defeated()
@warning_ignore("unused_signal")
signal character_revived()

# This is an abstract base class for battle characters
# Game-specific implementations should extend this class

# Reference to the character data
# This should be overridden in derived classes with the appropriate type
var character_data: Resource

func _init(data: Resource = null) -> void:
	if data:
		character_data = data

func _ready() -> void:
	# Enhanced initialization
	_setup_universal_framework()
	_connect_character_signals()

func _setup_universal_framework() -> void:
	# Universal Framework setup - using static methods
	# Base implementation does nothing, derived classes can override
	pass

func _connect_character_signals() -> void:
	# Connect internal signals
	if not character_health_changed.is_connected(_on_health_changed):
		var _connection_result: int = character_health_changed.connect(_on_health_changed)

func _on_health_changed(old_health: int, new_health: int) -> void:
	# Handle health changes - base implementation does nothing
	# Derived classes can override for custom behavior
	pass

func get_character_data() -> Resource:
	return character_data

# Enhanced character data access - same as get_character_data for base class
func get_character_data_safe() -> Resource:
	# Safely return character_data with null check
	if character_data and character_data is Resource:
		return character_data
	return null

# Delegate common properties to character_data
# These should be overridden in derived classes with appropriate getters/setters
var _character_name: String:
	get: return _get_character_name()
	set(value): _set_character_name(value)

var _health: int:
	get: return _get_health()
	set(value): _set_health(value)

var _max_health: int:
	get: return _get_max_health()
	set(value): _set_max_health(value)

# Enhanced getters and setters with Godot-recommended safe property access
func _get_character_name() -> String:
	if character_data and character_data.has_method("get"):
		var name_value: Variant = safe_get_property(character_data, "name")
		if name_value is String:
			# Direct return after type confirmation - no 'as' needed
			return name_value
	return ""

func _set_character_name(value: String) -> void:
	if character_data and character_data and character_data.has_method("set"):
		character_data.set("name", value)

func _get_health() -> int:
	if character_data and character_data.has_method("get"):
		var health_value: Variant = safe_get_property(character_data, "health")
		if health_value is int:
			# Direct return after type confirmation - no 'as' needed
			return health_value
	return 0

func _set_health(value: int) -> void:
	var old_health: int = _get_health()
	if character_data and character_data and character_data.has_method("set"):
		character_data.set("health", value)
		# Only emit signal if health actually changed
		if old_health != value:
			character_health_changed.emit(old_health, value)

func _get_max_health() -> int:
	if character_data and character_data.has_method("get"):
		var max_health_value: Variant = safe_get_property(character_data, "max_health")
		if max_health_value is int:
			# Direct return after type confirmation - no 'as' needed
			return max_health_value
	return 0

func _set_max_health(value: int) -> void:
	if character_data and character_data and character_data.has_method("set"):
		character_data.set("max_health", value)

# Battle-specific properties
var is_active: bool = false
var current_action: int = 0 # Should use appropriate enum in derived classes
var available_actions: Array[int] = []

# Enhanced battle management
func initialize_for_battle() -> void:
	# Initialize battle state
	is_active = true
	current_action = 0
	available_actions.clear() # Clear any existing actions first
	# available_actions will be populated by derived classes

func cleanup_battle() -> void:
	is_active = false
	current_action = 0
	available_actions.clear()
	# Clear battle state

# Enhanced action management
func can_perform_action(action_type: int) -> bool:
	return action_type in available_actions

func perform_action(action_type: int, target: Node = null) -> void:
	# Emit action signal
	character_action_performed.emit(str(action_type), target)

	# To be implemented by derived classes
	# Base implementation handles signal emission only

func take_damage(amount: int) -> void:
	# Enhanced damage handling
	var old_health: int = _get_health()
	var new_health: int = max(0, old_health - amount)

	_set_health(new_health)

	# Check for defeat
	if new_health <= 0:
		character_defeated.emit()

func heal(amount: int) -> void:
	# Enhanced healing
	var old_health: int = _get_health()
	var max_health: int = _get_max_health()
	var new_health: int = min(max_health, old_health + amount)

	_set_health(new_health)

# Enhanced status getters
func get_current_action() -> int:
	return current_action

func get_available_actions() -> Array[int]:
	return available_actions

func get_is_active() -> bool:
	return is_active

func get_character_name() -> String:
	return _character_name

func get_health() -> int:
	return _health

func get_max_health() -> int:
	return _max_health

func get_is_defeated() -> bool:
	return get_health() <= 0

func get_is_wounded() -> bool:
	return get_health() <= get_max_health() / 3.0

func get_is_dead() -> bool:
	return get_health() <= 0

func get_is_alive() -> bool:
	return get_health() > 0

# Enhanced utility methods
func get_battle_statistics() -> Dictionary:
	# Base implementation returns empty dictionary
	# Derived classes can override to provide actual statistics
	return {}

func reset_battle_statistics() -> void:
	# Base implementation does nothing
	# Derived classes can override to reset their statistics
	pass

func validate_character_state() -> bool:
	# Validate that character_data exists and is properly typed
	return character_data != null and character_data is Resource

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(obj):
		return default_value

	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null