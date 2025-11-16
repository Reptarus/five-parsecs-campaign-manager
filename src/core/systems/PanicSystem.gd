class_name PanicSystem
extends Node

## PanicSystem
##
## Manages panic, morale, and fear mechanics for Bug Hunt DLC.
## Soldiers can panic when confronted by bugs, causing various negative effects.
##
## Usage:
##   PanicSystem.set_squad_morale(75)
##   PanicSystem.check_panic(soldier, "bug_appeared")
##   PanicSystem.process_panic_effects(soldier)

signal panic_triggered(soldier, trigger: String, effect: String)
signal morale_changed(old_morale: int, new_morale: int)
signal soldier_rallied(soldier)
signal soldier_broken(soldier)

## Panic triggers and their severity
enum PanicTrigger {
	BUG_APPEARED,      # First bug sighting
	CLOSE_ENCOUNTER,   # Bug within 4"
	ALLY_KILLED,       # Witness crew death
	SWARM,             # 3+ bugs visible
	QUEEN_SIGHTED,     # Bug Queen present
	SURROUNDED,        # 2+ bugs within 4"
	INFESTED_HUMAN,    # See infested human
	ISOLATED           # More than 8" from allies
}

## Panic effects
enum PanicEffect {
	NONE,             # Passed check
	SHAKEN,           # -1 to all rolls this round
	FROZEN,           # Cannot act this turn
	FLEE,             # Must move away from bugs
	WILD_FIRE,        # Shoots randomly (may hit allies)
	BROKEN            # Drops weapon, flees to extraction
}

## Current squad morale (0-100)
var squad_morale: int = 100

## Active panic effects on soldiers
var active_panic_effects: Dictionary = {}

## Panic check history (for reducing repeated checks)
var panic_check_history: Dictionary = {}

## Content filter
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()

## Set squad morale level
func set_squad_morale(morale: int) -> void:
	var old_morale := squad_morale
	squad_morale = clampi(morale, 0, 100)

	if squad_morale != old_morale:
		print("PanicSystem: Squad morale: %d → %d" % [old_morale, squad_morale])
		morale_changed.emit(old_morale, squad_morale)

## Adjust squad morale
func adjust_morale(delta: int) -> void:
	set_squad_morale(squad_morale + delta)

## Check if soldier panics from trigger
func check_panic(soldier: Dictionary, trigger_name: String) -> bool:
	if not _should_check_panic(soldier, trigger_name):
		return false

	var trigger_severity := _get_trigger_severity(trigger_name)
	var morale_modifier := _get_morale_modifier()
	var rank_bonus := _get_rank_bonus(soldier)

	# Panic check: Roll 2D6 + Savvy + Rank Bonus + Morale Modifier vs Trigger Severity
	var roll := (randi() % 6 + 1) + (randi() % 6 + 1)
	var savvy := soldier.get("savvy", 0)
	var total := roll + savvy + rank_bonus + morale_modifier

	var passed := total >= trigger_severity

	print("PanicSystem: %s panic check (trigger: %s): 2D6(%d) + Savvy(%d) + Rank(%d) + Morale(%d) = %d vs %d = %s" % [
		soldier.get("name", "Unknown"),
		trigger_name,
		roll,
		savvy,
		rank_bonus,
		morale_modifier,
		total,
		trigger_severity,
		"PASSED" if passed else "FAILED"
	])

	if not passed:
		_apply_panic_effect(soldier, trigger_name)
		_record_panic_check(soldier, trigger_name)
		return true

	_record_panic_check(soldier, trigger_name)
	return false

## Process active panic effects at start of soldier's turn
func process_panic_effects(soldier: Dictionary) -> void:
	var soldier_id := _get_soldier_id(soldier)

	if not active_panic_effects.has(soldier_id):
		return

	var effect_data: Dictionary = active_panic_effects[soldier_id]
	var effect: PanicEffect = effect_data.effect

	match effect:
		PanicEffect.SHAKEN:
			print("PanicSystem: %s is SHAKEN (-1 to all rolls)" % soldier.get("name", "Unknown"))

		PanicEffect.FROZEN:
			print("PanicSystem: %s is FROZEN (cannot act)" % soldier.get("name", "Unknown"))
			# Soldier loses turn

		PanicEffect.FLEE:
			print("PanicSystem: %s FLEES (must move away from bugs)" % soldier.get("name", "Unknown"))
			# AI override: Move maximum distance away from nearest bug

		PanicEffect.WILD_FIRE:
			print("PanicSystem: %s fires WILDLY (random target)" % soldier.get("name", "Unknown"))
			# Fire at random target in range (may hit allies!)

		PanicEffect.BROKEN:
			print("PanicSystem: %s is BROKEN (drops weapon, flees)" % soldier.get("name", "Unknown"))
			soldier_broken.emit(soldier)
			# Drop weapon, flee to extraction at max speed

	# Decrease duration
	effect_data.duration -= 1
	if effect_data.duration <= 0:
		active_panic_effects.erase(soldier_id)
		print("PanicSystem: %s recovered from panic" % soldier.get("name", "Unknown"))

## Attempt to rally a panicked soldier
func rally_soldier(soldier: Dictionary, leader: Dictionary = {}) -> bool:
	var soldier_id := _get_soldier_id(soldier)

	if not active_panic_effects.has(soldier_id):
		return true # Not panicked

	var effect_data: Dictionary = active_panic_effects[soldier_id]

	# Rally check: 2D6 + Leader's Savvy vs Effect Severity
	var roll := (randi() % 6 + 1) + (randi() % 6 + 1)
	var leader_savvy := leader.get("savvy", 0) if not leader.is_empty() else 0
	var total := roll + leader_savvy

	var severity := _get_effect_severity(effect_data.effect)
	var success := total >= severity

	print("PanicSystem: Rally check for %s: 2D6(%d) + Leader Savvy(%d) = %d vs %d = %s" % [
		soldier.get("name", "Unknown"),
		roll,
		leader_savvy,
		total,
		severity,
		"SUCCESS" if success else "FAILED"
	])

	if success:
		active_panic_effects.erase(soldier_id)
		soldier_rallied.emit(soldier)
		print("PanicSystem: %s rallied!" % soldier.get("name", "Unknown"))
		return true

	return false

## Check if soldier has active panic effect
func has_panic_effect(soldier: Dictionary) -> bool:
	var soldier_id := _get_soldier_id(soldier)
	return active_panic_effects.has(soldier_id)

## Get soldier's current panic effect
func get_panic_effect(soldier: Dictionary) -> PanicEffect:
	var soldier_id := _get_soldier_id(soldier)
	if active_panic_effects.has(soldier_id):
		return active_panic_effects[soldier_id].effect
	return PanicEffect.NONE

## Get panic modifier for soldier (for applying to rolls)
func get_panic_modifier(soldier: Dictionary) -> int:
	var effect := get_panic_effect(soldier)

	match effect:
		PanicEffect.SHAKEN:
			return -1
		PanicEffect.FROZEN:
			return -999 # Effectively cannot act
		_:
			return 0

## Clear all panic effects (e.g., mission end)
func clear_all_panic_effects() -> void:
	active_panic_effects.clear()
	panic_check_history.clear()
	print("PanicSystem: All panic effects cleared")

## Get statistics about panic in current battle
func get_panic_stats() -> Dictionary:
	var stats := {
		"squad_morale": squad_morale,
		"soldiers_panicked": active_panic_effects.size(),
		"total_panic_checks": 0,
		"panic_effects_by_type": {}
	}

	# Count panic checks
	for soldier_id in panic_check_history.keys():
		stats.total_panic_checks += panic_check_history[soldier_id].size()

	# Count effects by type
	for soldier_id in active_panic_effects.keys():
		var effect: PanicEffect = active_panic_effects[soldier_id].effect
		var effect_name := PanicEffect.keys()[effect]
		if not stats.panic_effects_by_type.has(effect_name):
			stats.panic_effects_by_type[effect_name] = 0
		stats.panic_effects_by_type[effect_name] += 1

	return stats

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _should_check_panic(soldier: Dictionary, trigger_name: String) -> bool:
	# Don't check if soldier already broken
	var current_effect := get_panic_effect(soldier)
	if current_effect == PanicEffect.BROKEN:
		return false

	# Don't check same trigger multiple times in short period
	var soldier_id := _get_soldier_id(soldier)
	if panic_check_history.has(soldier_id):
		var history: Array = panic_check_history[soldier_id]
		# Check if same trigger in last 3 checks
		var recent_count := 0
		for i in range(max(0, history.size() - 3), history.size()):
			if history[i] == trigger_name:
				recent_count += 1

		# Don't check if same trigger appeared 2+ times recently
		if recent_count >= 2:
			return false

	return true

func _get_trigger_severity(trigger_name: String) -> int:
	# Higher severity = harder to resist panic
	match trigger_name:
		"bug_appeared":
			return 7
		"close_encounter":
			return 8
		"ally_killed":
			return 9
		"swarm":
			return 9
		"queen_sighted":
			return 11
		"surrounded":
			return 10
		"infested_human":
			return 10
		"isolated":
			return 8
		_:
			return 8

func _get_morale_modifier() -> int:
	# Convert squad morale to modifier
	if squad_morale >= 80:
		return 2
	elif squad_morale >= 60:
		return 1
	elif squad_morale >= 40:
		return 0
	elif squad_morale >= 20:
		return -1
	else:
		return -2

func _get_rank_bonus(soldier: Dictionary) -> int:
	# Higher ranks resist panic better
	var rank: String = soldier.get("rank", "Private")

	match rank:
		"Private":
			return 0
		"Corporal":
			return 1
		"Sergeant":
			return 2
		"Lieutenant":
			return 3
		"Captain":
			return 4
		_:
			return 0

func _apply_panic_effect(soldier: Dictionary, trigger_name: String) -> void:
	var soldier_id := _get_soldier_id(soldier)

	# Determine panic effect based on how badly they failed
	var effect := _roll_panic_effect(trigger_name)
	var duration := _get_effect_duration(effect)

	active_panic_effects[soldier_id] = {
		"effect": effect,
		"trigger": trigger_name,
		"duration": duration
	}

	var effect_name := PanicEffect.keys()[effect]
	print("PanicSystem: %s panics! Effect: %s (duration: %d)" % [
		soldier.get("name", "Unknown"),
		effect_name,
		duration
	])

	panic_triggered.emit(soldier, trigger_name, effect_name)

func _roll_panic_effect(trigger_name: String) -> PanicEffect:
	# More severe triggers have worse effects
	var severity := _get_trigger_severity(trigger_name)
	var roll := randi() % 6 + 1

	# Adjust roll based on severity
	if severity >= 10:
		roll += 2
	elif severity >= 9:
		roll += 1

	# Determine effect
	if roll <= 2:
		return PanicEffect.SHAKEN
	elif roll <= 4:
		return PanicEffect.FROZEN
	elif roll <= 5:
		return PanicEffect.FLEE
	elif roll <= 6:
		return PanicEffect.WILD_FIRE
	else:
		return PanicEffect.BROKEN

func _get_effect_duration(effect: PanicEffect) -> int:
	match effect:
		PanicEffect.SHAKEN:
			return 1 # 1 round
		PanicEffect.FROZEN:
			return 1 # 1 round
		PanicEffect.FLEE:
			return 2 # 2 rounds
		PanicEffect.WILD_FIRE:
			return 1 # 1 round
		PanicEffect.BROKEN:
			return 999 # Until rallied or mission ends
		_:
			return 0

func _get_effect_severity(effect: PanicEffect) -> int:
	# For rally checks
	match effect:
		PanicEffect.SHAKEN:
			return 6
		PanicEffect.FROZEN:
			return 7
		PanicEffect.FLEE:
			return 8
		PanicEffect.WILD_FIRE:
			return 9
		PanicEffect.BROKEN:
			return 11
		_:
			return 6

func _record_panic_check(soldier: Dictionary, trigger_name: String) -> void:
	var soldier_id := _get_soldier_id(soldier)

	if not panic_check_history.has(soldier_id):
		panic_check_history[soldier_id] = []

	panic_check_history[soldier_id].append(trigger_name)

func _get_soldier_id(soldier: Dictionary) -> String:
	return soldier.get("id", "soldier_unknown")
