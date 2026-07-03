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

	# Conditions with no per-round effect produce NO prompt
	for quiet in ["", "NO_CONDITION", "GLOOMY", "BITTER_STRUGGLE",
			"TOXIC_ENVIRONMENT", "SLIPPERY_GROUND"]:
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
