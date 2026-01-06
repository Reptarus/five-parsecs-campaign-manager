class_name MockDiceSystem
extends RefCounted

## Mock Dice System for Deterministic Testing
## Allows tests to queue specific dice roll values for predictable outcomes
##
## Usage:
##   var mock_dice = MockDiceSystem.new()
##   mock_dice.queue_rolls([3, 4, 5, 2, 6, 1])  # Queue specific values
##   var result = mock_dice.roll(6)  # Returns 3 (first queued value)
##   var result2 = mock_dice.roll(6)  # Returns 4 (second queued value)
##
## When queue is exhausted, returns default_value (3 by default)

## Queued roll values - consumed in order
var _queued_rolls: Array[int] = []

## Current position in queue
var _position: int = 0

## Default value when queue is exhausted (middle value for d6)
var _default_value: int = 3

## Track all rolls made for debugging
var _roll_history: Array[Dictionary] = []

## Whether to use random fallback when queue exhausted (vs default)
var use_random_fallback: bool = false

## Signal emitted when a roll is made (useful for debugging)
signal roll_made(sides: int, result: int, from_queue: bool)

## Queue a sequence of roll values to return
func queue_rolls(values: Array) -> void:
	_queued_rolls.clear()
	for value in values:
		if value is int:
			_queued_rolls.append(value)
		else:
			push_warning("MockDiceSystem: Non-integer value in queue: %s" % str(value))
	_position = 0

## Queue a single roll value
func queue_roll(value: int) -> void:
	_queued_rolls.append(value)

## Roll a die with specified sides, returning queued value if available
func roll(sides: int = 6) -> int:
	var result: int
	var from_queue: bool = false

	if _position < _queued_rolls.size():
		result = clampi(_queued_rolls[_position], 1, sides)
		_position += 1
		from_queue = true
	elif use_random_fallback:
		result = randi_range(1, sides)
	else:
		result = clampi(_default_value, 1, sides)

	_roll_history.append({
		"sides": sides,
		"result": result,
		"from_queue": from_queue,
		"timestamp": Time.get_ticks_msec()
	})

	roll_made.emit(sides, result, from_queue)
	return result

## Roll multiple dice and return the sum
func roll_multiple(count: int, sides: int = 6) -> int:
	var total := 0
	for i in range(count):
		total += roll(sides)
	return total

## Roll multiple dice and return array of individual results
func roll_multiple_array(count: int, sides: int = 6) -> Array[int]:
	var results: Array[int] = []
	for i in range(count):
		results.append(roll(sides))
	return results

## Get a d100 roll (1-100)
func roll_d100() -> int:
	return roll(100)

## Get a d20 roll (1-20)
func roll_d20() -> int:
	return roll(20)

## Get a d6 roll (1-6)
func roll_d6() -> int:
	return roll(6)

## Set the default value used when queue is exhausted
func set_default_value(value: int) -> void:
	_default_value = value

## Get remaining queued rolls count
func get_queue_remaining() -> int:
	return max(0, _queued_rolls.size() - _position)

## Check if queue is exhausted
func is_queue_exhausted() -> bool:
	return _position >= _queued_rolls.size()

## Reset queue position to start (reuse queued values)
func reset_queue() -> void:
	_position = 0

## Clear all queued values and history
func reset() -> void:
	_position = 0
	_queued_rolls.clear()
	_roll_history.clear()

## Get roll history for debugging
func get_roll_history() -> Array[Dictionary]:
	return _roll_history.duplicate()

## Get total number of rolls made
func get_total_rolls() -> int:
	return _roll_history.size()

## Create a preset for standard Five Parsecs crew size roll (1d6)
static func create_with_crew_roll(crew_bonus: int) -> MockDiceSystem:
	var mock := MockDiceSystem.new()
	mock.queue_roll(crew_bonus)
	return mock

## Create a preset for enemy count (crew size + 1d6)
static func create_for_enemy_count(enemy_bonus: int) -> MockDiceSystem:
	var mock := MockDiceSystem.new()
	mock.queue_roll(enemy_bonus)
	return mock

## Create a preset for initiative (4+ = crew first)
static func create_for_initiative(crew_wins: bool) -> MockDiceSystem:
	var mock := MockDiceSystem.new()
	mock.queue_roll(5 if crew_wins else 2)
	return mock

## Create a preset for victory outcome
static func create_for_victory(victory: bool) -> MockDiceSystem:
	var mock := MockDiceSystem.new()
	mock.queue_roll(6 if victory else 1)
	return mock
