extends GdUnitTestSuite
## Seize the Initiative modifier coverage — Core Rules p.112 ("Seizing the Initiative").
##
## Locks the seize formula + every modifier the companion exposes:
##   2D6 + highest Savvy + modifiers >= 10 (BattleCalculations.SEIZE_INITIATIVE_TARGET).
##   +1 outnumbered · -1 vs Hired Muscle · Hardcore -2 · Insanity -3 ·
##   per-opponent-type (Careless +1 / Alert -1, via set_enemy_modifier) ·
##   Motion Tracker +1 / Multi-wave scanner +1 (Compendium p.26, cumulative).
##
## F2 (verified NOT a bug): Feral ignores only PER-OPPONENT-TYPE penalties (the p.112
## clause follows "Many opponent types will add a bonus or penalty"), NOT the
## category-level -1 Hired Muscle. This suite pins that reading.
## F3 (verified valid): motion_tracker / scanner_bot are real Compendium p.26 items.
##
## Threshold logic delegates to BattleCalculations.check_seize_initiative (the SSOT
## shared with the auto-resolve path); modifier SUM is deterministic regardless of dice,
## so we read it via calculate_required_roll() = 10 - savvy - modifiers.

const SeizeSystem = preload("res://src/core/battle/SeizeInitiativeSystem.gd")

var _s

func before_test() -> void:
	_s = SeizeSystem.new()  # Resource — no tree needed
	_s.highest_savvy = 0

## required_roll = TARGET(10) - savvy - modifiers, so modifiers = 10 - savvy - required.
func _modifiers() -> int:
	return 10 - _s.highest_savvy - _s.calculate_required_roll()

func test_target_is_ten() -> void:
	assert_int(_s.calculate_required_roll()).is_equal(10)  # 10 - 0 savvy - 0 mods

func test_savvy_lowers_required_roll() -> void:
	_s.highest_savvy = 3
	assert_int(_s.calculate_required_roll()).is_equal(7)

func test_outnumbered_plus_one() -> void:
	_s.set_outnumbered(true)
	assert_int(_modifiers()).is_equal(1)

func test_hired_muscle_minus_one() -> void:
	_s.set_hired_muscle(true)
	assert_int(_modifiers()).is_equal(-1)

func test_hardcore_minus_two() -> void:
	_s.set_difficulty_mode(SeizeSystem.DifficultyMode.HARDCORE)
	assert_int(_modifiers()).is_equal(-2)

func test_insanity_minus_three() -> void:
	_s.set_difficulty_mode(SeizeSystem.DifficultyMode.INSANITY)
	assert_int(_modifiers()).is_equal(-3)

func test_motion_tracker_and_scanner_bot_are_cumulative_plus_one_each() -> void:
	# Compendium p.26: Multi-wave scanner +1, cumulative with party Motion Tracker +1.
	_s.set_motion_tracker(true)
	_s.set_scanner_bot(true)
	assert_int(_modifiers()).is_equal(2)

func test_enemy_type_penalty_applies_without_feral() -> void:
	_s.set_enemy_modifier(-1, "Alert")  # per-opponent-type penalty
	assert_int(_modifiers()).is_equal(-1)

func test_feral_ignores_per_opponent_type_penalty() -> void:
	# F2: Feral ignores the per-type Alert -1 (p.112 clause context).
	_s.has_feral = true
	_s.set_enemy_modifier(-1, "Alert")
	assert_int(_modifiers()).is_equal(0)

func test_feral_does_not_ignore_hired_muscle_category_penalty() -> void:
	# F2 (verified): the -1 Hired Muscle is a CATEGORY modifier, not a per-opponent-type
	# penalty, so Feral does NOT ignore it. Code is correct; lock it.
	_s.has_feral = true
	_s.set_hired_muscle(true)
	assert_int(_modifiers()).is_equal(-1)

func test_feral_does_not_ignore_positive_enemy_modifier() -> void:
	# Feral only ignores PENALTIES; a Careless +1 bonus still applies.
	_s.has_feral = true
	_s.set_enemy_modifier(1, "Careless")
	assert_int(_modifiers()).is_equal(1)

func test_modifiers_stack_net() -> void:
	_s.highest_savvy = 2
	_s.set_outnumbered(true)      # +1
	_s.set_hired_muscle(true)     # -1
	_s.set_motion_tracker(true)   # +1
	assert_int(_modifiers()).is_equal(1)
	# required = 10 - 2 savvy - 1 mods = 7
	assert_int(_s.calculate_required_roll()).is_equal(7)

func test_seized_threshold_via_ssot() -> void:
	# roll_initiative() folds the summed modifiers into check_seize_initiative;
	# total_modifiers is deterministic even though the 2D6 are random.
	_s.highest_savvy = 4
	_s.set_outnumbered(true)
	var result = _s.roll_initiative()
	assert_int(result.target_number).is_equal(10)
	assert_int(result.savvy_bonus).is_equal(4)
	assert_int(result.total_modifiers).is_equal(1)


func test_the_two_threshold_framings_are_the_same_test() -> void:
	## T11-02 (tablet deploy #16): InitiativeCalculator states the seize threshold TWO
	## ways in one frame. Before the roll it shows the RAW die against a reduced
	## threshold ("Need 8+ on 2D6", from calculate_required_roll()); after the roll it
	## shows the MODIFIED total against the fixed target ("Total: 7 vs 10").
	##
	## Those are the same test only because
	##     roll >= TARGET - savvy - mods   <=>   roll + savvy + mods >= TARGET
	## and the panel now prints both numbers side by side, so if that identity ever
	## stopped holding a player would see two thresholds that genuinely disagree —
	## which is worse than the presentation inconsistency it replaced.
	##
	## Asserted over the whole 2D6 range and a spread of savvy/modifier combinations
	## rather than one example: a single case would pass for any formula that happens
	## to agree at that point.
	var target: int = BattleCalculations.SEIZE_INITIATIVE_TARGET
	for savvy in [0, 1, 2, 3]:
		for mods in [-3, -2, -1, 0, 1, 2]:
			_s.highest_savvy = savvy
			_s.set_enemy_modifier(mods)
			var needed: int = _s.calculate_required_roll()
			assert_int(needed).override_failure_message(
				"required roll must be TARGET - savvy - mods (savvy=%d mods=%d)"
				% [savvy, mods]
			).is_equal(target - savvy - mods)
			for roll in range(2, 13):
				var raw_framing: bool = roll >= needed
				var total_framing: bool = (roll + savvy + mods) >= target
				assert_bool(raw_framing).override_failure_message(
					"the two displays disagree at savvy=%d mods=%d roll=%d: "
					% [savvy, mods, roll]
					+ "'need %d+' says %s, 'total %d vs %d' says %s"
					% [needed, str(raw_framing), roll + savvy + mods, target,
						str(total_framing)]
				).is_equal(total_framing)
