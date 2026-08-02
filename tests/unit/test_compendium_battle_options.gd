extends GdUnitTestSuite
## Compendium GAME OPTIONS that were switched on and did nothing.
##
## THE GAP THESE PIN: three battle-setup blocks in TacticalBattleUI read
## mission_dict keys — "dlc_difficulty_instructions", "dlc_ai_type" and
## "dramatic_combat_effects" — that NO producer anywhere ever wrote. Worse,
## _dlc_ai_type was assigned INSIDE the guard on dlc_difficulty_instructions, so
## even a correct AI-type producer would have been swallowed by a DIFFERENT
## missing key: _check_escalating_battles() returns early while _dlc_ai_type is
## empty, and the p.46 D100 was never rolled once in any battle of any campaign.
##
## The tables themselves were book-exact the whole time. These tests pin the
## VALUES (so a future edit cannot drift them) and the SHAPE of the setup text
## (so it cannot regress to BBCode in a plain Label, or to printing internal
## slugs at the player).

const ESC = preload("res://src/core/managers/EscalatingBattlesManager.gd")
const PROG = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
const GEN = preload("res://src/core/systems/EnemyGenerator.gd")

const AI_COLUMNS: Array[String] = [
	"aggressive", "cautious", "defensive", "rampage", "tactical", "beast",
]


## Compendium p.46 — every AI column must resolve a result for all 100 rolls,
## with no gap (a roll that silently does nothing) and no overlap (two results
## claiming the same roll).
func test_escalation_table_covers_every_roll_for_every_ai_column() -> void:
	for ai: String in AI_COLUMNS:
		var seen: Dictionary = {}
		for effect: Dictionary in ESC.ESCALATION_EFFECTS:
			var ranges: Dictionary = effect.get("ranges", {})
			if not ranges.has(ai):
				continue
			var span: Array = ranges[ai]
			for roll: int in range(int(span[0]), int(span[1]) + 1):
				assert_bool(seen.has(roll)).override_failure_message(
					"%s: roll %d claimed twice (%s)" % [ai, roll, effect.get("id")]
				).is_false()
				seen[roll] = effect.get("id")
		for roll: int in range(1, 101):
			assert_bool(seen.has(roll)).override_failure_message(
				"%s: roll %d falls through the p.46 table" % [ai, roll]
			).is_true()


## Compendium p.46 spot-values, straight off the printed table.
func test_escalation_table_matches_the_book() -> void:
	var expected: Dictionary = {
		"morale_increase": {"aggressive": [1, 15], "defensive": [1, 20]},
		"fighting_intensifies": {"tactical": [11, 25], "beast": [11, 15]},
		"reinforcements": {"cautious": [16, 40], "tactical": [26, 30]},
		"rush_attack": {"aggressive": [81, 100], "rampage": [66, 100]},
		"ambush": {"beast": [36, 80]},
	}
	for effect: Dictionary in ESC.ESCALATION_EFFECTS:
		var id: String = str(effect.get("id", ""))
		if not expected.has(id):
			continue
		var ranges: Dictionary = effect.get("ranges", {})
		for ai: String in expected[id]:
			assert_array(ranges.get(ai, [])).override_failure_message(
				"%s / %s drifted from Compendium p.46" % [id, ai]
			).is_equal(expected[id][ai])


## Guardian is a real Core Rules AI type with NO column on the p.46 table. It
## must resolve to nothing rather than silently borrowing another column.
func test_guardian_ai_has_no_escalation_column() -> void:
	for effect: Dictionary in ESC.ESCALATION_EFFECTS:
		var ranges: Dictionary = effect.get("ranges", {})
		assert_bool(ranges.has("guardian")).override_failure_message(
			"Guardian gained a column the Compendium p.46 table does not have"
		).is_false()


## The sole consumer renders through _add_setup_text() into a plain Label, so
## BBCode would show the player literal "[b]" tags. Nobody caught this because
## the section was unreachable until the AI type was wired up.
func test_setup_text_is_plain_and_quotes_the_rule_not_the_slug() -> void:
	# Precondition the slug bug depended on, and assertable with the DLC flag OFF:
	# every effect must carry a real instruction distinct from its internal id.
	for effect: Dictionary in ESC.ESCALATION_EFFECTS:
		var id: String = str(effect.get("id", ""))
		var instruction: String = str(effect.get("instruction", ""))
		assert_str(instruction).override_failure_message(
			"%s has no player-facing instruction" % id
		).is_not_empty()
		assert_bool(instruction == id).override_failure_message(
			"%s: instruction is the internal slug" % id
		).is_false()

	var text: String = ESC.generate_setup_text("aggressive")
	if text.is_empty():
		# DLC flag off in this environment; the rest needs the generated text.
		return
	assert_str(text).not_contains("[b]")
	assert_str(text).not_contains("[/b]")
	# Regression guard: this line used to append effect.id, so the player read
	# "Morale Increase (01-15): morale_increase".
	assert_str(text).not_contains("morale_increase")
	assert_str(text).contains("Compendium p.46")


## Compendium p.30, Option 1 "Strength" column. Add 1 basic enemy from turn 5,
## 2 from turn 10, "2 basic enemies and 1 Lieutenant" from 15, and "2 basic
## enemies, 1 specialist, 1 Lieutenant" from 20 — 0/1/2/3/4 extra figures.
func test_progressive_strength_matches_the_book() -> void:
	var basic: int = PROG.ProgressionType.BASIC
	assert_int(PROG.get_enemy_count_bonus(1, basic)).is_equal(0)
	assert_int(PROG.get_enemy_count_bonus(4, basic)).is_equal(0)
	assert_int(PROG.get_enemy_count_bonus(5, basic)).is_equal(1)
	assert_int(PROG.get_enemy_count_bonus(9, basic)).is_equal(1)
	assert_int(PROG.get_enemy_count_bonus(10, basic)).is_equal(2)
	assert_int(PROG.get_enemy_count_bonus(15, basic)).is_equal(3)
	assert_int(PROG.get_enemy_count_bonus(20, basic)).is_equal(4)


## Compendium p.30 Respawn column: turns 4/8/12/16/20 -> 1/2/3/4/5.
func test_progressive_respawn_matches_the_book() -> void:
	var basic: int = PROG.ProgressionType.BASIC
	assert_int(PROG.get_respawn_count(3, basic)).is_equal(0)
	assert_int(PROG.get_respawn_count(4, basic)).is_equal(1)
	assert_int(PROG.get_respawn_count(8, basic)).is_equal(2)
	assert_int(PROG.get_respawn_count(12, basic)).is_equal(3)
	assert_int(PROG.get_respawn_count(16, basic)).is_equal(4)
	assert_int(PROG.get_respawn_count(20, basic)).is_equal(5)


## Option 2 (ADVANCED) unlocks difficulty toggles; it does NOT add figures. The
## generator combines the two options with max(), so a non-zero here would
## double-count against Option 1.
func test_advanced_progression_adds_no_figures() -> void:
	var advanced: int = PROG.ProgressionType.ADVANCED
	for turn: int in [1, 5, 10, 15, 20, 30]:
		assert_int(PROG.get_enemy_count_bonus(turn, advanced)).is_equal(0)
		assert_int(PROG.get_respawn_count(turn, advanced)).is_equal(0)


## THE WIRING, not just the table: the generator must actually consume the
## option. Before this, progressive_difficulty_options was persisted at campaign
## creation and read by nobody, so every encounter was the same size forever.
##
## Reads mission_data directly (no GameState needed), which is the stamped path.
func test_generator_consumes_the_progressive_option() -> void:
	var gen: Object = auto_free(GEN.new())
	var basic: int = PROG.ProgressionType.BASIC

	# Option off -> no bonus, whatever the turn.
	assert_int(gen._progressive_strength_bonus({
		"campaign_turn": 20, "progressive_difficulty_options": [],
	})).is_equal(0)

	# Option on -> the p.30 Strength column, by turn.
	for pair: Array in [[4, 0], [5, 1], [10, 2], [15, 3], [20, 4]]:
		assert_int(gen._progressive_strength_bonus({
			"campaign_turn": pair[0], "progressive_difficulty_options": [basic],
		})).override_failure_message(
			"turn %d should add %d figures" % [pair[0], pair[1]]
		).is_equal(pair[1])

	# Both options ticked combine with max(), never a sum.
	assert_int(gen._progressive_strength_bonus({
		"campaign_turn": 20,
		"progressive_difficulty_options": [basic, PROG.ProgressionType.ADVANCED],
	})).is_equal(4)
