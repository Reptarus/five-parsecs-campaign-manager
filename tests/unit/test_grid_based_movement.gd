extends GdUnitTestSuite
## Grid-Based Movement — Compendium pp.90-93.
##
## Two jobs. (1) Pin the book: the grids, the square-size guidance, the
## deployment half-square limit, the Open/Close Quarters distinction, the
## diagonal-counts-as-Dash rule, and the p.91 flanking scope. (2) Keep the
## FABRICATED rules that shipped here from ever coming back — a "1 square = 2
## inches" conversion, a range-to-squares table, "1 square per activation", and
## "enter occupied square = automatic Brawl" all appeared in the cheat sheet and
## none of them exist in the Compendium.
##
## The DLC flag is OFF under test (no DLCManager autoload in a bare suite), so
## every gated accessor must return empty. That is asserted rather than worked
## around: an off option contributing nothing is the rule, not a test artifact.

const GridRef = preload("res://src/data/compendium_grid_movement.gd")

const CHEAT_SHEET_PATH := "res://src/ui/components/battle/CheatSheetPanel.gd"
const BATTLE_UI_PATH := "res://src/ui/screens/battle/TacticalBattleUI.gd"
const CHECKLIST_PATH := "res://src/ui/components/battle/PreBattleChecklist.gd"
const GRID_MODULE_PATH := "res://src/data/compendium_grid_movement.gd"


## Strip whole-line comments before grepping source. Without this, a docblock
## that EXPLAINS a fabrication reads as the fabrication still being present.
func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var out: PackedStringArray = []
	for line in f.get_as_text().split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	f.close()
	return "\n".join(out)


## ============================================================================
## THE BOOK — p.90 battle space
## ============================================================================

func test_grids_are_the_three_the_book_prints() -> void:
	# p.90: "a grid with 3 or 4 squares along each side (for a total of 9, 12 or
	# 16 sectors depending on whether your grid is 3x3, 3x4, or 4x4)".
	assert_int(GridRef.GRIDS.size()).is_equal(3)
	var ids: Array = []
	var sectors: Array = []
	for g in GridRef.GRIDS:
		ids.append(str(g.get("id", "")))
		sectors.append(int(g.get("sectors", 0)))
		# Never more than 4 or fewer than 3 squares per side.
		assert_int(int(g.get("cols", 0))).is_between(3, 4)
		assert_int(int(g.get("rows", 0))).is_between(3, 4)
	assert_array(ids).contains_exactly(["3x3", "3x4", "4x4"])
	assert_array(sectors).contains_exactly([9, 12, 16])


func test_sector_count_is_cols_times_rows() -> void:
	for g in GridRef.GRIDS:
		assert_int(int(g.get("sectors", 0))).is_equal(
			int(g.get("cols", 0)) * int(g.get("rows", 0)))


func test_target_square_band_is_eight_to_nine_inches() -> void:
	# p.90: "Typically, you want the squares to be 8-9\" across."
	assert_float(GridRef.TARGET_SQUARE_MIN).is_equal(8.0)
	assert_float(GridRef.TARGET_SQUARE_MAX).is_equal(9.0)


func test_book_example_three_foot_table_four_by_four_is_nine_inches() -> void:
	# p.90 caption: "3x3' table, 4x4 grid = 9\" square".
	assert_float(GridRef.square_size_inches(3.0, 4)).is_equal(9.0)


func test_square_size_is_table_width_over_count() -> void:
	assert_float(GridRef.square_size_inches(2.0, 3)).is_equal(8.0)
	assert_float(GridRef.square_size_inches(2.5, 4)).is_equal(7.5)
	assert_float(GridRef.square_size_inches(3.0, 3)).is_equal(12.0)


func test_unknown_table_size_yields_no_measurement() -> void:
	# Better to print no number than a fabricated one.
	assert_float(GridRef.square_size_inches(0.0, 4)).is_equal(0.0)
	assert_float(GridRef.square_size_inches(3.0, 0)).is_equal(0.0)
	assert_dict(GridRef.recommended_grid(0.0)).is_empty()


## ============================================================================
## DERIVED GRID RECOMMENDATION (arithmetic on book values, not invention)
## ============================================================================

func test_recommendation_hits_the_book_band_on_book_table_sizes() -> void:
	# p.108 table sizes. 3ft -> 4x4 = 9" (the book's own example);
	# 2ft -> 3x3 = 8" (the other end of the band).
	assert_str(str(GridRef.recommended_grid(3.0).get("id", ""))).is_equal("4x4")
	assert_float(float(GridRef.recommended_grid(3.0).get("width_in", 0.0))).is_equal(9.0)
	assert_str(str(GridRef.recommended_grid(2.0).get("id", ""))).is_equal("3x3")
	assert_float(float(GridRef.recommended_grid(2.0).get("width_in", 0.0))).is_equal(8.0)


func test_recommendation_never_returns_a_non_square_grid() -> void:
	# p.90: "The grid spaces should be roughly square." On a SQUARE table 3x4
	# gives 12"x9" cells, so it must never be recommended.
	for ft: float in [2.0, 2.5, 3.0]:
		var rec: Dictionary = GridRef.recommended_grid(ft)
		assert_bool(rec.is_empty()).is_false()
		assert_str(str(rec.get("id", ""))).is_not_equal("3x4")
		assert_bool(bool(rec.get("square", false))).is_true()


func test_grid_options_flag_three_by_four_as_not_square_on_a_square_table() -> void:
	var non_square_found: bool = false
	for opt in GridRef.grid_options(3.0):
		if str(opt.get("id", "")) == "3x4":
			non_square_found = true
			assert_bool(bool(opt.get("square", false))).is_false()
	assert_bool(non_square_found).is_true()


func test_grid_options_reports_every_grid_for_any_table() -> void:
	assert_int(GridRef.grid_options(3.0).size()).is_equal(3)
	assert_int(GridRef.grid_options(0.0).size()).is_equal(3)


## ============================================================================
## p.91 FLANKING — scope is exactly the two named deployments
## ============================================================================

func test_flanking_applies_to_exactly_half_and_bolstered_flank() -> void:
	# p.91: "If setting up enemies using the Half Flank or Bolstered Flank
	# deployment variables from page 45 of this book..."
	assert_array(GridRef.FLANKING_DEPLOYMENTS).contains_exactly(
		["half_flank", "bolstered_flank"])


func test_flanking_instruction_is_empty_for_other_deployments() -> void:
	# Gate is off in this suite, but the id filter must hold regardless — these
	# ids must never produce the note even when the option is on.
	for other in ["line", "improved_positions", "forward_positions",
			"bolstered_line", "infiltration", "reinforced", "concealed", ""]:
		assert_str(GridRef.get_flanking_instruction(other)).is_empty()


## ============================================================================
## DLC GATE — an off option contributes nothing
## ============================================================================

func test_option_is_off_without_dlc_manager() -> void:
	assert_bool(GridRef.is_enabled()).is_false()


func test_setup_instructions_empty_while_disabled() -> void:
	assert_array(GridRef.get_setup_instructions(3.0)).is_empty()
	assert_array(GridRef.get_setup_instructions(0.0)).is_empty()


func test_flanking_instruction_empty_while_disabled() -> void:
	assert_str(GridRef.get_flanking_instruction("half_flank")).is_empty()


## ============================================================================
## ANTI-REGRESSION — the fabricated rules must not come back
## ============================================================================

func test_no_square_to_inch_conversion_anywhere() -> void:
	# Nothing in the Compendium converts squares to inches. Verified by a
	# full-text search of the PDF: every "convert" hit is the Converted species.
	var module: String = _code_only(GRID_MODULE_PATH)
	var sheet: String = _code_only(CHEAT_SHEET_PATH)
	for banned in ["1 square = 2", "squares = ", "Conversion Table"]:
		assert_str(module).not_contains(banned)
		assert_str(sheet).not_contains(banned)


func test_no_one_square_per_activation_rule() -> void:
	# p.92 gives adjacent-square OR within-square movement, never a per-
	# activation square allowance, and no Speed>4" bonus square.
	var module: String = _code_only(GRID_MODULE_PATH)
	assert_str(module).not_contains("square per activation")
	assert_str(module).not_contains("Speed > 4")
	assert_str(_code_only(CHEAT_SHEET_PATH)).not_contains("square per activation")


func test_no_automatic_brawl_on_square_entry() -> void:
	# p.93: "Brawling combat is initiated when a figure moves into CONTACT with
	# an opponent" — contact, not square entry.
	var module: String = _code_only(GRID_MODULE_PATH)
	assert_str(module).not_contains("automatic Brawl")
	assert_str(module).not_contains("auto-Brawl")
	var sheet: String = _code_only(CHEAT_SHEET_PATH)
	assert_str(sheet).not_contains("automatic Brawl")
	assert_str(sheet).not_contains("auto-Brawl")


func test_reference_text_keeps_ranged_and_proximity_on_core_rules() -> void:
	# p.93 is explicit that these do NOT change under the grid. This is the
	# positive half of the anti-fabrication check.
	var text: String = GridRef.get_reference_text()
	assert_str(text).contains("core rules")
	assert_str(text).contains("Line of Sight")
	assert_str(text).contains("Proximity")


func test_reference_text_carries_the_book_mechanics() -> void:
	var text: String = GridRef.get_reference_text()
	assert_str(text).contains("3x3, 3x4 or 4x4")
	assert_str(text).contains("8-9\"")
	assert_str(text).contains("halfway")       # p.90 deployment limit
	assert_str(text).contains("Dashed")        # p.92 diagonal move
	assert_str(text).contains("second square") # p.91 flanking
	assert_str(text).contains("Close Quarters")


func test_reference_text_is_sourced_from_the_module_not_inlined() -> void:
	# The fabricated block lived inline in CheatSheetPanel. Keep exactly one
	# source of truth so a future edit cannot fork the rules again.
	var sheet: String = _code_only(CHEAT_SHEET_PATH)
	assert_str(sheet).contains("CompendiumGridMovementRef.get_reference_text()")


## ============================================================================
## WIRING — the consumer must have a producer
## ============================================================================

func test_battle_ui_generates_instructions_when_the_mission_carries_none() -> void:
	# `grid_movement_instructions` had ZERO producers repo-wide, so the setup
	# section never rendered. The consumer now falls back to the module.
	var ui: String = _code_only(BATTLE_UI_PATH)
	assert_str(ui).contains("grid_movement_instructions")
	# build_* since the per-battle choice landed: the caller owns the gate now.
	assert_str(ui).contains("CompendiumGridMovementRef.build_setup_instructions")


func test_battle_ui_wires_flanking_to_the_deployment_roll() -> void:
	# p.91 flanking depends on the p.44 deployment roll, which does not happen
	# until Seize the Initiative — after the setup tab is built.
	var ui: String = _code_only(BATTLE_UI_PATH)
	assert_str(ui).contains("CompendiumGridMovementRef.build_flanking_instruction")


## ============================================================================
## THE PRE-BATTLE CHECKLIST — the moment the player lays out the table
## ============================================================================
##
## Generating instructions into the setup DRAWER was not enough: the drawer is
## closed by default, and the checklist meanwhile told the player to "Place your
## crew within your deployment zone" — the NON-grid procedure. Verified live in
## a Battle Simulator run before this was wired.

func test_checklist_step_and_hints_are_empty_while_disabled() -> void:
	assert_dict(GridRef.get_checklist_step(3.0)).is_empty()
	assert_str(GridRef.get_deploy_crew_hint(3.0)).is_empty()
	assert_str(GridRef.get_deploy_enemy_hint()).is_empty()


func test_checklist_loops_go_through_the_runtime_builder() -> void:
	# Every loop must use _items(); a step appearing in the render pass but not
	# the progress-count pass would make the checklist uncompletable. Exactly one
	# CHECKLIST_ITEMS loop may remain — the one inside _items() itself.
	var code: String = _code_only(CHECKLIST_PATH)
	assert_int(code.count("in CHECKLIST_ITEMS:")).is_equal(1)
	assert_bool(code.count("in _items():") >= 5).is_true()


func test_checklist_builder_is_not_self_recursive() -> void:
	# The regex that repointed the loops also rewrote the one INSIDE _items(),
	# which recursed forever. Pin it: the builder iterates the const, not itself.
	var code: String = _code_only(CHECKLIST_PATH)
	var start: int = code.find("func _items()")
	assert_int(start).is_greater(-1)
	var body: String = code.substr(start, code.find("func _table_size_ft") - start)
	assert_str(body).contains("in CHECKLIST_ITEMS:")
	assert_str(body).not_contains("in _items():")


func test_checklist_marks_the_grid_before_anything_deploys() -> void:
	# Order matters physically: you cannot deploy into squares you have not
	# marked. The builder inserts the grid step right after setup_terrain.
	var code: String = _code_only(CHECKLIST_PATH)
	assert_str(code).contains("setup_terrain")
	assert_str(code).contains("build_checklist_step")
	assert_str(code).contains("build_deploy_crew_hint")
	assert_str(code).contains("build_deploy_enemy_hint")


## ============================================================================
## THE PER-BATTLE CHOICE — p.90
## ============================================================================
##
## "You do not have to commit to using this system for every battle of a given
## campaign. The movement system used can be changed as often as you want, with
## different battles using different movement systems."
##
## THE BUG THESE PIN (Aug 6 battle-phase audit): every consumer gated on the DLC
## FLAG, which makes the option all-or-nothing for the whole campaign — the one
## thing the book explicitly says it is not. The three ungated build_* functions
## existed for exactly this and had ZERO callers repo-wide, the fifth instance
## that day of "the rule is implemented, the call is what went missing".

func test_builders_answer_the_procedure_while_the_flag_is_off() -> void:
	# The flag is OFF under test. The build_* family must STILL produce the
	# procedure: they answer "what does the grid say", not "is it switched on".
	# Without the split a per-battle choice is impossible — nothing could
	# describe a system the campaign has enabled but this battle is not using.
	assert_array(GridRef.build_setup_instructions(3.0)).is_not_empty()
	assert_dict(GridRef.build_checklist_step(3.0)).is_not_empty()
	assert_str(GridRef.build_deploy_crew_hint(3.0)).is_not_empty()
	assert_str(GridRef.build_deploy_enemy_hint()).is_not_empty()
	assert_str(GridRef.build_flanking_instruction("half_flank")).is_not_empty()


func test_gated_wrappers_still_contribute_nothing_while_disabled() -> void:
	# The other half of the split: adding build_* must not have opened a path
	# for an unowned option to reach the player.
	assert_array(GridRef.get_setup_instructions(3.0)).is_empty()
	assert_str(GridRef.get_flanking_instruction("half_flank")).is_empty()


func test_flanking_scope_survives_the_ungating() -> void:
	# p.91 names exactly two p.45 deployment variables. Ungating must not widen
	# the note to deployments the book does not put it on.
	assert_str(GridRef.build_flanking_instruction("line")).is_empty()
	assert_str(GridRef.build_flanking_instruction("bolstered_flank")).is_not_empty()


func test_checklist_offers_the_choice_and_gates_the_offer_on_the_flag() -> void:
	# The selector is what makes the choice reachable; is_enabled() decides
	# whether the QUESTION applies, never what the answer is.
	var code: String = _code_only(CHECKLIST_PATH)
	assert_str(code).contains("_build_movement_selector")
	assert_str(code).contains("movement_system_changed")
	assert_str(code).contains("set_grid_movement")
	assert_str(code).contains("CompendiumGridMovementRef.is_enabled()")
	# The checklist must NOT reach for the flag-gated wrappers again — that is
	# the regression that would silently restore all-or-nothing behaviour.
	assert_str(code).not_contains("get_checklist_step")
	assert_str(code).not_contains("get_deploy_crew_hint")
	assert_str(code).not_contains("get_deploy_enemy_hint")


func test_battle_ui_surfaces_follow_the_per_battle_choice() -> void:
	# Three surfaces have to agree, or the player picks Standard and the setup
	# drawer still tells them to divide the table into squares.
	var ui: String = _code_only(BATTLE_UI_PATH)
	assert_str(ui).contains("_use_grid_movement")
	assert_str(ui).contains("_resolve_grid_movement_choice")
	assert_str(ui).contains("_on_movement_system_changed")
	assert_str(ui).contains("CompendiumGridMovementRef.build_setup_instructions")
	assert_str(ui).contains("CompendiumGridMovementRef.build_flanking_instruction")


func test_grid_section_rebuilds_alone_never_the_whole_setup_tab() -> void:
	# _populate_setup_tab re-enters terrain generation, and in the standalone
	# modes that REGENERATES the map the player has already laid out on their
	# physical table. The switch must rebuild only its own container.
	var ui: String = _code_only(BATTLE_UI_PATH)
	assert_str(ui).contains("_rebuild_grid_setup_section")
	var start: int = ui.find("func _on_movement_system_changed")
	assert_int(start).is_greater(-1)
	var body: String = ui.substr(start, 900)
	assert_str(body).not_contains("_populate_setup_tab")
