extends GdUnitTestSuite
## FPCM_BattleFlowGuide — the battle-journey guidance text source.
## Pins the p.110 deployment procedure, the p.88 end-of-round condition
## prompts, the p.90 win-condition summaries, and the Notable Sight
## placement geometry (p.89: 2D6+2" from the table center).

const Guide = preload("res://src/core/battle/BattleFlowGuide.gd")
const GeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")
const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")


func test_deployment_steps_structure() -> void:
	var steps: Array = Guide.deployment_steps("", "A")
	assert_int(steps.size()).is_equal(3)
	for step: Dictionary in steps:
		assert_str(str(step.get("page_cite", ""))).contains("p.110")
	assert_str(str(steps[0].get("text", ""))).contains("edge")
	assert_str(str(steps[1].get("text", ""))).contains("enemy FIRST")
	assert_str(str(steps[2].get("text", ""))).contains("18\"")


func test_deployment_ai_spacing_is_book_exact() -> void:
	# p.110 spacing per AI type (F3/F4-corrected groupings)
	assert_str(Guide.ai_setup_text("A")).contains("one cluster")
	assert_str(Guide.ai_setup_text("R")).contains("one cluster")
	assert_str(Guide.ai_setup_text("T")).contains("3 teams, 8\"")
	assert_str(Guide.ai_setup_text("D")).contains("3 teams, 8\"")
	assert_str(Guide.ai_setup_text("C")).contains("2 groups, 6\"")
	assert_str(Guide.ai_setup_text("B")).contains("pairs")
	assert_str(Guide.ai_setup_text("B")).contains("table third")
	assert_str(Guide.ai_setup_text("G")).contains("guards")


func test_deployment_condition_modifiers_fold_into_step_3() -> void:
	var delayed: Array = Guide.deployment_steps("DELAYED", "A")
	assert_str(str(delayed[2].get("text", ""))).contains("2 random crew")
	var small: Array = Guide.deployment_steps("SMALL_ENCOUNTER", "A")
	assert_str(str(small[2].get("text", ""))).contains("sits this battle out")
	var caught: Array = Guide.deployment_steps("caught_off_guard", "A")
	assert_str(str(caught[2].get("text", ""))).contains("Slow")
	var none: Array = Guide.deployment_steps("NO_CONDITION", "A")
	assert_bool("Note:" in str(none[2].get("text", ""))).is_false()


func test_round_end_prompts_per_condition() -> void:
	var brief: Array = Guide.build_round_end_prompts("BRIEF_ENGAGEMENT")
	assert_int(brief.size()).is_equal(1)
	assert_str(str(brief[0].get("roll", ""))).is_equal("2D6")
	assert_str(str(brief[0].get("page_cite", ""))).contains("p.88")

	var delayed: Array = Guide.build_round_end_prompts("delayed")
	assert_int(delayed.size()).is_equal(1)
	assert_str(str(delayed[0].get("roll", ""))).is_equal("1D6")

	var vis: Array = Guide.build_round_end_prompts("POOR_VISIBILITY")
	assert_int(vis.size()).is_equal(1)
	assert_str(str(vis[0].get("text", ""))).contains("1D6+8")

	# Conditions with no per-round-END effect produce NO prompt. All 11 p.88
	# conditions are accounted for: 3 above have a round-end roll; these 8 do not
	# (Small/Surprise/CaughtOffGuard are setup-only; Toxic is a per-Stun roll;
	# Slippery/Bitter/Gloomy are passive).
	for quiet in ["", "NO_CONDITION", "GLOOMY", "BITTER_STRUGGLE",
			"TOXIC_ENVIRONMENT", "SLIPPERY_GROUND",
			"SMALL_ENCOUNTER", "SURPRISE_ENCOUNTER", "CAUGHT_OFF_GUARD"]:
		assert_int(Guide.build_round_end_prompts(quiet).size()).is_equal(0)


func test_objective_win_text_coverage() -> void:
	# p.90 win conditions — every objective type the tables can roll
	# (Opportunity/Patron/Quest, p.89) has a non-empty summary.
	for obj in ["access", "acquire", "deliver", "defend", "eliminate",
			"fight_off", "move_through", "patrol", "protect", "secure",
			"search"]:
		assert_bool(Guide.objective_win_text(obj).is_empty()).is_false()
	assert_str(Guide.objective_win_text("patrol")).contains("3")
	assert_str(Guide.objective_win_text("secure")).contains("2 consecutive")
	assert_str(Guide.objective_win_text("move_through")).contains("2 crew")
	assert_str(Guide.objective_win_text("unknown_thing")).is_equal("")


func test_notable_sight_geometry() -> void:
	# p.89: placed 2D6+2" (4-14") from the table center
	for ft in [2.0, 2.5, 3.0]:
		var dims: Dictionary = Grid.dims_for_table(ft)
		var center: Vector2 = Grid.center_cell(dims)
		var sight := {
			"type": "LOOT_CACHE", "name": "Loot cache",
			"distance_inches": 9.0, "angle": 0.0,
		}
		var pos: Vector2 = GeneratorClass.notable_sight_grid_pos(sight, dims)
		# Angle 0 -> straight +x from center by 9" = 6 cells (unless clamped)
		var expected_x: float = minf(
			center.x + Grid.inches_to_cells(9.0), float(dims["cols"]) - 1.0)
		assert_float(pos.x).is_equal_approx(expected_x, 0.001)
		assert_float(pos.y).is_equal_approx(center.y, 0.001)
		# Any rolled distance/angle stays inside the grid
		for dist in [4.0, 14.0]:
			for angle in [0.0, PI / 3.0, PI, 4.7]:
				var p: Vector2 = GeneratorClass.notable_sight_grid_pos(
					{"distance_inches": dist, "angle": angle}, dims)
				assert_bool(p.x >= 0.0 and p.x <= float(dims["cols"]) - 1.0) \
					.is_true()
				assert_bool(p.y >= 0.0 and p.y <= float(dims["rows"]) - 1.0) \
					.is_true()


func test_append_notable_sight_marker() -> void:
	var dims: Dictionary = Grid.dims_for_table(3.0)
	# "Nothing special" and empty sights add nothing
	assert_int(GeneratorClass.append_notable_sight_marker(
		[], {}, dims).size()).is_equal(0)
	assert_int(GeneratorClass.append_notable_sight_marker(
		[], {"type": "NOTHING"}, dims).size()).is_equal(0)
	# A real sight appends one objective-style marker
	var out: Array = GeneratorClass.append_notable_sight_marker(
		[{"type": "center"}],
		{"type": "LOOT_CACHE", "name": "Loot cache",
			"distance_inches": 9.0, "angle": 0.0}, dims)
	assert_int(out.size()).is_equal(2)
	assert_str(str(out[1].get("type", ""))).is_equal("notable_sight")
	assert_bool(out[1].get("grid_pos") is Vector2).is_true()
	assert_str(str(out[1].get("label", ""))).contains("Loot cache")
	assert_str(str(out[1].get("rule", ""))).contains("p.89")


# ── Win-condition lookup accepts the names the data actually ships ────────
#
# Found by a desktop runtime walk. The Battle Card's objective row exists to
# tell the player how they WIN, and it was printing a blank one.
#
# Two compounding causes:
#   1. The card read mission_data["objective"] — the JOB name from the world
#      phase — while the glance chip, battle log and results form all read the
#      objective the tracker resolved from the p.89 D10 table. The card said
#      "Objective: Fight Off" while the chip said "Deliver: open".
#   2. This table is keyed by snake_case ("fight_off"), but every objective in
#      data/patron_generation.json is stored as a DISPLAY name ("Fight Off").
#      Eight of the ten matched by luck because they are single words; the two
#      multi-word ones fell through to "" and rendered an empty row.

## Every objective on the Core Rules p.89 D10 tables, spelled as the data file
## spells it.
const BOOK_OBJECTIVES := [
	"Move Through", "Deliver", "Access", "Patrol", "Fight Off",
	"Eliminate", "Secure", "Protect", "Search", "Defend", "Acquire",
]

func test_every_book_objective_has_a_win_condition() -> void:
	for objective in BOOK_OBJECTIVES:
		assert_str(Guide.objective_win_text(objective)) \
			.override_failure_message(
				"Objective '%s' has no win-condition text — the Battle Card row would be blank"
				% objective).is_not_empty()

func test_multi_word_objectives_resolve_from_their_display_name() -> void:
	# The exact two that were silently blank.
	assert_str(Guide.objective_win_text("Fight Off")).is_not_empty()
	assert_str(Guide.objective_win_text("Move Through")).is_not_empty()

func test_display_name_and_snake_case_id_agree() -> void:
	# The card looks up by tracker ID, other callers by name; both must land on
	# the same text so the player never sees two different win conditions.
	assert_str(Guide.objective_win_text("Fight Off")) \
		.is_equal(Guide.objective_win_text("fight_off"))
	assert_str(Guide.objective_win_text("Move Through")) \
		.is_equal(Guide.objective_win_text("move_through"))

func test_win_text_states_the_book_condition_not_a_paraphrase() -> void:
	# Spot-check the two whose conditions are easiest to get subtly wrong.
	# p.91 Secure: "end 2 consecutive rounds with crew within 2\" of the center.
	# A crew member with an enemy within 6\" of them does not count."
	var secure: String = Guide.objective_win_text("Secure").to_lower()
	assert_str(secure).contains("2 consecutive rounds")
	assert_str(secure).contains("6\"")
	# p.91 Search: "A 5+ finds what you were looking for, and you Win."
	assert_str(Guide.objective_win_text("Search")).contains("5+")

func test_an_unknown_objective_still_returns_empty() -> void:
	# The fallback must stay empty rather than inventing a condition.
	assert_str(Guide.objective_win_text("Nonexistent Objective")).is_empty()
	assert_str(Guide.objective_win_text("")).is_empty()
