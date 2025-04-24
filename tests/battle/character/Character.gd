@tool
extends Node2D

## Test Character
## This is a testing fixture for character integration tests
## It provides signal connection and basic functionality

# Character resource reference 
var _character = null

# Signal handlers for tracking
signal character_health_changed(old_value, new_value)
signal character_died()
signal character_status_changed(status)

func _ready() -> void:
	pass

# Initialize with a character resource
func initialize(character_resource) -> void:
	_character = character_resource
	_connect_signals()

# Connect to character signals
func _connect_signals() -> void:
	if not _character:
		return
	
	if _character.has_signal("health_changed"):
		if _character.is_connected("health_changed", Callable(self, "_on_character_health_changed")):
			_character.disconnect("health_changed", Callable(self, "_on_character_health_changed"))
		_character.connect("health_changed", Callable(self, "_on_character_health_changed"))
	
	if _character.has_signal("died"):
		if _character.is_connected("died", Callable(self, "_on_character_died")):
			_character.disconnect("died", Callable(self, "_on_character_died"))
		_character.connect("died", Callable(self, "_on_character_died"))
	
	if _character.has_signal("status_changed"):
		if _character.is_connected("status_changed", Callable(self, "_on_character_status_changed")):
			_character.disconnect("status_changed", Callable(self, "_on_character_status_changed"))
		_character.connect("status_changed", Callable(self, "_on_character_status_changed"))

# Signal handlers
func _on_character_health_changed(old_value, new_value) -> void:
	character_health_changed.emit(old_value, new_value)

func _on_character_died() -> void:
	character_died.emit()

func _on_character_status_changed(status) -> void:
	character_status_changed.emit(status)

# Override _exit_tree to clean up
func _exit_tree() -> void:
	# Disconnect signals
	if _character:
		if _character.has_signal("health_changed") and _character.is_connected("health_changed", Callable(self, "_on_character_health_changed")):
			_character.disconnect("health_changed", Callable(self, "_on_character_health_changed"))
		
		if _character.has_signal("died") and _character.is_connected("died", Callable(self, "_on_character_died")):
			_character.disconnect("died", Callable(self, "_on_character_died"))
		
		if _character.has_signal("status_changed") and _character.is_connected("status_changed", Callable(self, "_on_character_status_changed")):
			_character.disconnect("status_changed", Callable(self, "_on_character_status_changed"))