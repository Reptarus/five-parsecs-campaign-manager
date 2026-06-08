extends GdUnitTestSuite
## Post-Battle responsive / clarity contract (battle-flow UX pass, Jun 2026)
##
## Instantiates the REAL PostBattleSequence + PostBattleSummarySheet (catching
## runtime errors from the Phase-3 row-fit / chrome changes) and locks in:
##   1. _make_name_label wraps + ellipsizes + drops its fixed min-width helper
##   2. The StepsList nav PanelContainer resolves (so it can hide in portrait)
##   3. The summary sheet sets up + exposes responsive stats columns without error
##
## gdUnit4 v6.0.3. Run with -c, never --headless (project rule).

const PostBattleScene := preload("res://src/ui/screens/postbattle/PostBattleSequence.tscn")
const SummarySheetScene := preload("res://src/ui/components/postbattle/PostBattleSummarySheet.tscn")


func test_make_name_label_wraps_and_ellipsizes() -> void:
	var ui: Control = auto_free(PostBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	var lbl: Label = ui._make_name_label("A Very Long Crew Member Name Indeed", 120)
	assert_bool(lbl.autowrap_mode != TextServer.AUTOWRAP_OFF).is_true()
	assert_bool(lbl.clip_text).is_true()
	assert_int(lbl.text_overrun_behavior).is_equal(TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_int(lbl.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)


func test_steps_panel_resolved() -> void:
	var ui: Control = auto_free(PostBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	assert_object(ui._steps_panel).override_failure_message(
		"StepsList PanelContainer must resolve so it can hide in portrait").is_not_null()
	assert_bool(ui._steps_panel is PanelContainer).is_true()


func test_summary_sheet_setup_and_columns() -> void:
	var sheet: Control = auto_free(SummarySheetScene.instantiate())
	add_child(sheet)
	await get_tree().process_frame
	sheet.setup({
		"mission_title": "Test Mission",
		"victory": true,
		"rounds": 3,
		"enemies_defeated": 2,
		"casualties": 0,
		"credits_earned": 5,
		"loot": [{"item_name": "Boarding Saber", "type": "weapon", "value": 1}],
	})
	# Built without error; stats grid has a valid (responsive) column count.
	assert_int(sheet.stats_section.columns).is_greater_equal(1)
	assert_int(sheet.stats_section.columns).is_less_equal(2)
