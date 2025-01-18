extends "res://tests/fixtures/game_test.gd"

# This is the main test base class that all test files should extend from.
# It provides access to both the base test functionality and game-specific test functionality.

var _logger = null
var _was_ready_called := false

# Required by GUT framework
func set_logger(logger):
	_logger = logger

func _ready():
	_was_ready_called = true

func should_skip_script() -> bool:
	return false

func get_skip_message() -> String:
	return ""
