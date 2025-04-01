@tool
extends "res://src/core/enemy/base/Enemy.gd"

# This file exists to maintain compatibility with existing references
# while using the base Enemy class implementation

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Additional method that isn't in the base class
func heal(amount: int) -> int:
	var old_health = health
	health = min(health + amount, max_health)
	health_changed.emit(health, old_health)
	return health - old_health
