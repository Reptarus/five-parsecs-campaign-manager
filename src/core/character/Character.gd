@tool
extends "res://src/game/character/Character.gd"
class_name Character

## Character alias for backward compatibility
##
## This class provides a clean "Character" type name that scripts can reference
## while maintaining the existing FPCM_Character implementation.
## All functionality is inherited from FPCM_Character.

func _init() -> void:
	super._init()