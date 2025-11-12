extends Node
class_name FallbackDiceManager

## Fallback Dice Manager for Equipment Generation
## Provides essential dice rolling functionality when DiceManager autoload is missing
## Ensures StartingEquipmentGenerator can function correctly

signal dice_rolled(result: int, sides: int, reason: String)

var _rng: RandomNumberGenerator
var _roll_history: Array[Dictionary] = []

func _init():
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	name = "FallbackDiceManager"
	print("FallbackDiceManager: Initialized with basic dice functionality")

## Roll a standard 6-sided die
func roll_d6(reason: String = "Generic D6") -> int:
	var result = _rng.randi_range(1, 6)
	_record_roll(result, 6, reason)
	dice_rolled.emit(result, 6, reason)
	return result

## Roll a 10-sided die (for credits calculation)
func roll_d10(reason: String = "Generic D10") -> int:
	var result = _rng.randi_range(1, 10)
	_record_roll(result, 10, reason)
	dice_rolled.emit(result, 10, reason)
	return result

## Roll a D66 (two D6s treated as tens and ones)
func roll_d66(reason: String = "Generic D66") -> int:
	var tens = roll_d6("D66 Tens")
	var ones = roll_d6("D66 Ones") 
	var result = (tens * 10) + ones
	_record_roll(result, 66, reason)
	return result

## Roll multiple dice and sum
func roll_multiple(sides: int, count: int, reason: String = "Multiple Dice") -> int:
	var total = 0
	for i in count:
		total += _rng.randi_range(1, sides)
	
	_record_roll(total, sides, "%s (%dx)" % [reason, count])
	dice_rolled.emit(total, sides, reason)
	return total

## Roll with modifier
func roll_with_modifier(sides: int, modifier: int, reason: String = "Modified Roll") -> int:
	var base = _rng.randi_range(1, sides)
	var result = base + modifier
	_record_roll(result, sides, "%s (+%d)" % [reason, modifier])
	dice_rolled.emit(result, sides, reason)
	return result

## Record roll in history for debugging
func _record_roll(result: int, sides: int, reason: String) -> void:
	_roll_history.append({
		"result": result,
		"sides": sides, 
		"reason": reason,
		"timestamp": Time.get_ticks_msec()
	})
	
	# Keep history manageable
	if _roll_history.size() > 100:
		_roll_history = _roll_history.slice(-50)  # Keep last 50

## Get roll history for debugging
func get_roll_history() -> Array[Dictionary]:
	return _roll_history.duplicate()

## Clear roll history
func clear_history() -> void:
	_roll_history.clear()

## Seed the RNG for reproducible results (testing)
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	print("FallbackDiceManager: Seed set to %d" % seed_value)

## Get random value in range (utility method)
func get_random_int(min_val: int, max_val: int) -> int:
	return _rng.randi_range(min_val, max_val)

## Get random float in range (utility method)  
func get_random_float(min_val: float = 0.0, max_val: float = 1.0) -> float:
	return _rng.randf_range(min_val, max_val)

## Check if this is a fallback instance
func is_fallback() -> bool:
	return true

## Get statistics about dice usage
func get_statistics() -> Dictionary:
	var stats = {
		"total_rolls": _roll_history.size(),
		"roll_types": {},
		"recent_activity": _roll_history.slice(-10) if _roll_history.size() > 0 else []
	}
	
	# Count roll types
	for roll in _roll_history:
		var key = "D%d" % roll.sides
		stats.roll_types[key] = stats.roll_types.get(key, 0) + 1
	
	return stats