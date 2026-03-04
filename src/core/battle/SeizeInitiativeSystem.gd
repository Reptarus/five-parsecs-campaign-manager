class_name FPCM_SeizeInitiativeSystem
extends Resource

## Seize the Initiative System implementing Five Parsecs Core Rules
##
## Calculates the initiative roll with all applicable modifiers.
## Formula: 2D6 + highest Savvy + modifiers >= 10
##
## Reference: Core Rules p.117 "Seizing the Initiative"

# Signals
signal initiative_rolled(result: InitiativeResult)
signal modifiers_changed()

# Difficulty modes
enum DifficultyMode {
	NORMAL,
	CHALLENGING,
	HARDCORE,
	INSANITY
}

# Initiative Result Resource
class InitiativeResult extends Resource:
	var roll_total: int = 0
	var dice_values: Array[int] = []
	var base_roll: int = 0
	var savvy_bonus: int = 0
	var total_modifiers: int = 0
	var modifiers_breakdown: Array[Dictionary] = []
	var success: bool = false
	var target_number: int = 10

	func get_summary() -> String:
		var parts: Array[String] = []
		parts.append("Roll: %d + %d = %d" % [dice_values[0], dice_values[1], base_roll])
		parts.append("Savvy: +%d" % savvy_bonus)
		if total_modifiers != 0:
			var sign_str := "+" if total_modifiers > 0 else ""
			parts.append("Modifiers: %s%d" % [sign_str, total_modifiers])
		parts.append("Total: %d vs %d" % [roll_total, target_number])
		parts.append("Result: %s" % ("SUCCESS!" if success else "Failed"))
		return "\n".join(parts)

# Modifier tracking
var active_modifiers: Dictionary = {}
var highest_savvy: int = 0
var has_feral: bool = false
var difficulty_mode: DifficultyMode = DifficultyMode.NORMAL

# Sprint 26.5: Debug logging for initiative rolls
var DEBUG_INITIATIVE := false

## Enable debug logging for initiative rolls
func enable_debug_logging() -> void:
	DEBUG_INITIATIVE = true

## Disable debug logging for initiative rolls
func disable_debug_logging() -> void:
	DEBUG_INITIATIVE = false

## Debug log for initiative roll - shows complete calculation breakdown
func _debug_log_initiative_roll(result: InitiativeResult) -> void:
	if not DEBUG_INITIATIVE:
		return

	print("│ SAVVY BONUS: +%d (highest in crew)" % result.savvy_bonus)
	if result.modifiers_breakdown.is_empty():
		print("│   (none)")
	else:
		for mod in result.modifiers_breakdown:
			var sign_str := "+" if mod.value > 0 else ""
			var applied_str := "" if mod.applied else " [NOT APPLIED]"
	print("│ CALCULATION: %d (roll) + %d (savvy) + %d (mods) = %d" % [
		result.base_roll, result.savvy_bonus, result.total_modifiers, result.roll_total])
	if result.success:
		print("│ Crew may move OR fire (hits on natural 6 only)")
	else:
		pass

func _init() -> void:
	_reset_modifiers()

## Set crew data for savvy bonus and Feral detection (Sprint 26.3: Character-Everywhere)
func set_crew_data(crew: Array) -> void:
	highest_savvy = 0
	has_feral = false

	for member in crew:
		# Sprint 26.3: Crew members are now always Character objects
		if not member:
			continue

		# Get savvy from Character property
		var savvy: int = member.savvy if "savvy" in member else 0
		if savvy > highest_savvy:
			highest_savvy = savvy

		# Check for Feral species (origin property on Character)
		var species: String = member.origin if "origin" in member else ""
		if species.to_lower() == "feral":
			has_feral = true

## Set difficulty mode modifier
func set_difficulty_mode(mode: DifficultyMode) -> void:
	difficulty_mode = mode

	match mode:
		DifficultyMode.NORMAL, DifficultyMode.CHALLENGING:
			_remove_modifier("difficulty")
		DifficultyMode.HARDCORE:
			_add_modifier("difficulty", "Hardcore Mode", -2)
		DifficultyMode.INSANITY:
			_add_modifier("difficulty", "Insanity Mode", -3)

## Add modifier for being outnumbered
func set_outnumbered(is_outnumbered: bool) -> void:
	if is_outnumbered:
		_add_modifier("outnumbered", "Outnumbered", 1)
	else:
		_remove_modifier("outnumbered")

## Add modifier for fighting Hired Muscle
func set_hired_muscle(is_hired_muscle: bool) -> void:
	if is_hired_muscle:
		_add_modifier("hired_muscle", "vs Hired Muscle", -1)
	else:
		_remove_modifier("hired_muscle")

## Add modifier for Motion Tracker equipment
func set_motion_tracker(has_tracker: bool) -> void:
	if has_tracker:
		_add_modifier("motion_tracker", "Motion Tracker", 1)
	else:
		_remove_modifier("motion_tracker")

## Add modifier for Scanner Bot
func set_scanner_bot(has_bot: bool) -> void:
	if has_bot:
		_add_modifier("scanner_bot", "Scanner Bot", 1)
	else:
		_remove_modifier("scanner_bot")

## Add enemy-specific modifier (ignored if Feral present)
func set_enemy_modifier(modifier_value: int, enemy_name: String = "Enemy Type") -> void:
	if modifier_value != 0:
		_add_modifier("enemy_type", enemy_name, modifier_value)
	else:
		_remove_modifier("enemy_type")

## Roll for Seize the Initiative
func roll_initiative() -> InitiativeResult:
	var result := InitiativeResult.new()

	# Roll 2D6
	var die1 := randi_range(1, 6)
	var die2 := randi_range(1, 6)
	result.dice_values = [die1, die2]
	result.base_roll = die1 + die2

	# Add savvy
	result.savvy_bonus = highest_savvy

	# Calculate modifiers
	result.total_modifiers = _calculate_total_modifiers()
	result.modifiers_breakdown = _get_modifiers_breakdown()

	# Calculate total
	result.roll_total = result.base_roll + result.savvy_bonus + result.total_modifiers
	result.target_number = 10
	result.success = result.roll_total >= result.target_number

	# Sprint 26.5: Debug log the initiative roll
	_debug_log_initiative_roll(result)

	initiative_rolled.emit(result)
	return result

## Calculate what total we need to roll
func calculate_required_roll() -> int:
	var modifiers := _calculate_total_modifiers()
	# Target is 10, so we need: 2D6 >= 10 - savvy - modifiers
	return 10 - highest_savvy - modifiers

## Get current modifiers breakdown for UI display
func get_current_modifiers() -> Array[Dictionary]:
	return _get_modifiers_breakdown()

## Get success probability (rough estimate)
func get_success_probability() -> float:
	var required: int = calculate_required_roll()

	# 2D6 probability distribution
	var success_count := 0
	for d1 in range(1, 7):
		for d2 in range(1, 7):
			if d1 + d2 >= required:
				success_count += 1

	return float(success_count) / 36.0 * 100.0

func _add_modifier(key: String, name: String, value: int) -> void:
	active_modifiers[key] = {"name": name, "value": value}
	modifiers_changed.emit()

func _remove_modifier(key: String) -> void:
	active_modifiers.erase(key)
	modifiers_changed.emit()

func _reset_modifiers() -> void:
	active_modifiers.clear()

func _calculate_total_modifiers() -> int:
	var total := 0

	for key in active_modifiers:
		var modifier: Dictionary = active_modifiers[key]

		# Skip enemy penalties if Feral present
		if key == "enemy_type" and has_feral and modifier.value < 0:
			continue

		total += modifier.value

	return total

func _get_modifiers_breakdown() -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []

	for key in active_modifiers:
		var modifier: Dictionary = active_modifiers[key]

		var entry := {
			"key": key,
			"name": modifier.name,
			"value": modifier.value,
			"applied": true
		}

		# Mark enemy penalties as not applied if Feral present
		if key == "enemy_type" and has_feral and modifier.value < 0:
			entry["applied"] = false
			entry["name"] += " (ignored - Feral)"

		breakdown.append(entry)

	return breakdown

## Get help text describing success effects
func get_success_effects() -> String:
	return "On success, every crew member may either:\n• Take a normal Move, OR\n• Fire a weapon (hits only on natural 6)"
