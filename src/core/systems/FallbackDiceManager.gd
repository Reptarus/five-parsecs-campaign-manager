extends Node
class_name FallbackDiceManager

## Fallback Dice Manager
## Minimal implementation for systems that need DiceManager fallback
## Delegates to actual DiceManager autoload when available

signal dice_rolled(result: int, sides: int)

func roll_dice(sides: int = 6) -> int:
	## Roll a single die
	var result = randi() % sides + 1
	dice_rolled.emit(result, sides)
	return result

func roll_multiple_dice(count: int, sides: int = 6) -> Array[int]:
	## Roll multiple dice
	var results: Array[int] = []
	for i in range(count):
		results.append(roll_dice(sides))
	return results

func roll_sum(count: int, sides: int = 6) -> int:
	## Roll multiple dice and return sum
	var results = roll_multiple_dice(count, sides)
	var sum = 0
	for result in results:
		sum += result
	return sum

func roll_d6() -> int:
	## Roll 1D6
	return roll_dice(6)

func roll_2d6() -> int:
	## Roll 2D6
	return roll_sum(2, 6)

func roll_d100() -> int:
	## Roll 1D100
	return roll_dice(100)
