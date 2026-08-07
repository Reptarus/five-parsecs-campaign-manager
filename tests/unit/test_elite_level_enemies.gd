extends GdUnitTestSuite
## Elite-level Enemies — Compendium pp.48-65.
##
## p.48: "These updated enemy tables TAKE THE PLACE OF the regular encounter
## tables in the core rulebook."
##
## `compendium_elite_enemies.gd` implemented SIX entry points, correctly and
## book-exactly. Exactly ONE had a caller:
##
##   roll_enemy_in_category()        EnemyGenerator._roll_enemy_in_category  ← live
##   enforce_minimum_size()          zero callers
##   get_composition()               zero callers
##   unique_individual_threshold()   zero callers
##   modified_panic_range()          zero callers
##   rival_follows_to_new_world()    zero callers
##
## So a player who turned the option on faced elite PROFILES arranged by the Core
## Rules p.93 thresholds: no Captain could ever appear (the rank does not exist in
## the Core Rules at all), squads could be smaller than the p.49 minimum of 4, the
## Leadership morale table never applied, the Unique Individual roll stayed at 9+,
## and an "Elite Rival" shook off exactly as easily as an ordinary one. The 'Elite
## Enemies' toggle was a placebo switch beyond the enemy names.
##
## ⚠ THE DLC GATE IS TWO-LEVEL — owned AND toggled, and `_enabled_flags` defaults
## FALSE. A test that does not enable the flag measures the gate, not the rule.
##
## gdUnit4 v6.0.3 compatible.

const EliteRef := preload("res://src/data/compendium_elite_enemies.gd")
const NewWorldArrivalRef := preload("res://src/core/campaign/NewWorldArrival.gd")
const GEN_SRC := "res://src/core/systems/EnemyGenerator.gd"

var _dlc: Node = null
var _saved_flag: bool = false


func before_test() -> void:
	_dlc = get_node_or_null("/root/DLCManager")
	if _dlc:
		_saved_flag = _dlc.is_feature_enabled(_dlc.ContentFlag.ELITE_ENEMIES)
		_dlc.set_feature_enabled(_dlc.ContentFlag.ELITE_ENEMIES, true)


func after_test() -> void:
	if _dlc:
		_dlc.set_feature_enabled(_dlc.ContentFlag.ELITE_ENEMIES, _saved_flag)


func _src() -> String:
	var f := FileAccess.open(GEN_SRC, FileAccess.READ)
	assert_object(f).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped source — a scan that forbids or requires a string must ignore
## the comment that explains it.
func _code_only() -> String:
	var out: PackedStringArray = []
	for line: String in _src().split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ── 0. The gate is really open (or these tests prove nothing) ──────────────

func test_the_dlc_flag_is_actually_enabled_for_this_suite() -> void:
	if _dlc == null:
		return
	assert_bool(EliteRef.is_enabled()).override_failure_message(
		"ELITE_ENEMIES is off despite before_test enabling it — every assertion"
		+ " below would then be measuring the DLC gate rather than the rule"
	).is_true()


# ── 1. p.49 Elite Composition ──────────────────────────────────────────────

## Book table, p.49:
##   SIZE  BASIC  SPECIALISTS  LIEUTENANTS  CAPTAIN
##     4     3         1            -          -
##     5     2         2            1          -
##     6     3         2            1          -
##    7+     3+        2            1          1
func test_the_composition_table_matches_the_book_row_for_row() -> void:
	var expected := {
		4: {"basic": 3, "specialists": 1, "lieutenants": 0, "captain": 0},
		5: {"basic": 2, "specialists": 2, "lieutenants": 1, "captain": 0},
		6: {"basic": 3, "specialists": 2, "lieutenants": 1, "captain": 0},
		7: {"basic": 3, "specialists": 2, "lieutenants": 1, "captain": 1},
	}
	for size: int in expected:
		var got: Dictionary = EliteRef.get_composition(size)
		var want: Dictionary = expected[size]
		for key: String in want:
			assert_int(int(got.get(key, -1))).override_failure_message(
				"p.49 row for squad size %d: %s should be %d, got %d"
				% [size, key, int(want[key]), int(got.get(key, -1))]
			).is_equal(int(want[key]))


func test_the_seven_plus_row_absorbs_the_remainder_into_basics() -> void:
	# "3+" — the basic count grows with the squad while the special ranks do not.
	for size: int in [8, 10, 14]:
		var c: Dictionary = EliteRef.get_composition(size)
		assert_int(int(c["specialists"])).is_equal(2)
		assert_int(int(c["lieutenants"])).is_equal(1)
		assert_int(int(c["captain"])).is_equal(1)
		assert_int(int(c["basic"])).override_failure_message(
			"basics must absorb the remainder at size %d" % size
		).is_equal(size - 4)


func test_the_minimum_squad_size_is_four() -> void:
	# p.49: "roll up their size as normal. If the size would be less than 4
	# figures, increase it to 4."
	for rolled: int in [1, 2, 3]:
		assert_int(EliteRef.enforce_minimum_size(rolled)).override_failure_message(
			"a rolled size of %d must be raised to 4" % rolled).is_equal(4)
	# ...and it is a floor, never a cap.
	assert_int(EliteRef.enforce_minimum_size(9)).is_equal(9)


func test_the_generator_consults_the_composition_and_the_minimum() -> void:
	var src: String = _code_only()
	assert_bool(src.contains("enforce_minimum_size")).override_failure_message(
		"EnemyGenerator no longer applies the p.49 minimum squad size").is_true()
	assert_bool(src.contains("get_composition")).override_failure_message(
		"EnemyGenerator is back on the Core Rules p.93 thresholds for elite"
		+ " forces, so a Captain can never appear again").is_true()
	assert_bool(src.contains("\"captain\"")).override_failure_message(
		"the captain role is gone from the squad build loop").is_true()


# ── 2. p.49 Unique Individuals ─────────────────────────────────────────────

func test_outnumbering_the_enemy_guarantees_a_unique_individual() -> void:
	# "If you outnumber the enemy, they are automatically accompanied by a Unique
	# Individual." 0 is the sentinel for "no roll needed".
	assert_int(EliteRef.unique_individual_threshold(true)).is_equal(0)


func test_not_outnumbering_lowers_the_threshold_to_seven() -> void:
	# "If you do not outnumber them, roll normally, but a 7+ is required instead
	# of the usual 9+."
	assert_int(EliteRef.unique_individual_threshold(false)).is_equal(7)


func test_the_generator_passes_elite_context_to_the_unique_roll() -> void:
	var src: String = _code_only()
	assert_bool(src.contains("unique_individual_threshold")).override_failure_message(
		"roll_unique_individuals() no longer consults the p.49 threshold, so an"
		+ " elite force uses the ordinary 9+").is_true()
	assert_bool(src.contains("crew_outnumbers")).override_failure_message(
		"the caller no longer computes whether the crew outnumbers the enemy, so"
		+ " the automatic branch is unreachable").is_true()


## The Invasion prohibition (Core Rules p.93) is not something the elite chapter
## relaxes: it modifies the Unique Individual ROLL, not the rule that there is no
## Unique in an Invasion battle.
func test_the_invasion_prohibition_survives_the_elite_auto_branch() -> void:
	assert_bool(_code_only().contains("elite_auto and not is_invasion")) \
		.override_failure_message(
			"the p.49 automatic Unique Individual now fires in Invasion battles,"
			+ " which Core Rules p.93 forbids outright").is_true()


# ── 3. p.49 Leadership morale ──────────────────────────────────────────────

## Book table, p.49. The Panic RANGE goes DOWN — a smaller range panics less
## often — and 0 means Fearless.
func test_the_leadership_table_matches_the_book() -> void:
	var rows := [
		["Lieutenant", "1-3", "1-2"],
		["Lieutenant", "1-2", "1"],
		["Lieutenant", "1", "1"],
		["Captain", "1-3", "1"],
		["Captain", "1-2", "1"],
		["Captain", "1", "0"],
	]
	for row: Array in rows:
		assert_str(EliteRef.modified_panic_range(str(row[1]), str(row[0]))) \
			.override_failure_message(
				"p.49 Leadership: %s with a normal panic range of %s should give"
				% [row[0], row[1]] + " %s" % row[2]).is_equal(str(row[2]))


func test_an_unknown_panic_range_is_left_alone() -> void:
	# Never invent a row the book does not print.
	assert_str(EliteRef.modified_panic_range("1-4", "Captain")).is_equal("1-4")
	assert_str(EliteRef.modified_panic_range("1-2", "Sergeant")).is_equal("1-2")


func test_the_generator_applies_the_leadership_table() -> void:
	var src: String = _code_only()
	assert_bool(src.contains("modified_panic_range")).override_failure_message(
		"the p.49 Leadership morale improvement is no longer applied, so a"
		+ " Captain on the table changes nothing about enemy Morale").is_true()
	assert_bool(src.contains("highest_rank")).override_failure_message(
		"p.49 says 'use the highest rank present' — that selection is gone"
	).is_true()


# ── 4. p.49 Elite-level Rivals ─────────────────────────────────────────────

func test_an_elite_rival_follows_on_four_not_five() -> void:
	# Core Rules p.72 baseline is 5+; Compendium p.49 lowers it to 4+.
	assert_int(NewWorldArrivalRef.FOLLOW_TARGET).is_equal(5)
	assert_int(NewWorldArrivalRef.ELITE_FOLLOW_TARGET).override_failure_message(
		"p.49: 'roll 1D6 for each Elite Rival you have: On a 4+ they opt to"
		+ " follow you to the new world'").is_equal(4)


func test_only_a_tagged_rival_counts_as_elite() -> void:
	assert_bool(NewWorldArrivalRef.is_elite_rival({"is_elite": true})).is_true()
	assert_bool(NewWorldArrivalRef.is_elite_rival({"name": "Thugs"})).is_false()
	# A legacy String rival predates the tag and must stay ordinary rather than
	# being granted persistence it never earned.
	assert_bool(NewWorldArrivalRef.is_elite_rival("Old Vendetta")).is_false()


## Behavioural: over many trials an Elite Rival must survive travel more often
## than an ordinary one. 4+ is 1/2, 5+ is 1/3 — a gap far outside the noise at
## this sample size, so this fails loudly if the branch is dropped.
func test_elite_rivals_survive_travel_more_often() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260806
	var trials: int = 600
	var elite_kept: int = 0
	var plain_kept: int = 0
	for i in range(trials):
		var camp := FiveParsecsCampaignCore.new()
		camp.rivals = [{"name": "Elite Gang", "is_elite": true}]
		NewWorldArrivalRef.apply(camp, rng)
		elite_kept += camp.rivals.size()
		var camp2 := FiveParsecsCampaignCore.new()
		camp2.rivals = [{"name": "Plain Gang"}]
		NewWorldArrivalRef.apply(camp2, rng)
		plain_kept += camp2.rivals.size()
	assert_int(elite_kept).override_failure_message(
		"Elite Rivals (%d/%d kept) are no more persistent than ordinary ones"
		% [elite_kept, plain_kept]
		+ " (%d/%d) — the p.49 4+ target is not being used" % [plain_kept, trials]
	).is_greater(plain_kept)
	# Sanity-check both are in the right ballpark rather than pinned to a seed:
	# 4+ ≈ 300/600, 5+ ≈ 200/600. Wide margins, ~6σ from each other.
	assert_int(elite_kept).is_between(240, 360)
	assert_int(plain_kept).is_between(145, 265)


func test_the_rival_is_tagged_at_birth_and_carried_by_the_normalizer() -> void:
	var f := FileAccess.open(
		"res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd",
		FileAccess.READ)
	assert_object(f).is_not_null()
	var resolver: String = f.get_as_text()
	f.close()
	assert_bool(resolver.contains("new_rival[\"is_elite\"] = true")) \
		.override_failure_message(
			"Rivals are no longer tagged elite at creation. The p.49 travel roll"
			+ " happens turns later, by which point nothing can tell where the"
			+ " Rival came from — so the tag must be written here or the rule dies"
		).is_true()

	var n := FileAccess.open("res://src/core/battle/BattleResultNormalizer.gd",
		FileAccess.READ)
	assert_object(n).is_not_null()
	var norm: String = n.get_as_text()
	n.close()
	assert_bool(norm.contains("\"enemy_is_elite\"")).override_failure_message(
		"enemy_is_elite is not in the normalizer passthrough list, so it never"
		+ " reaches battle_result and the tag above can never be set — a consumer"
		+ " reading a key no producer delivers, which is the exact defect shape"
		+ " this whole audit exists to remove").is_true()
