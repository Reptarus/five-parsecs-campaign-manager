extends GdUnitTestSuite
## F10 regression — BattleResultsInputForm now carries the mission objective and
## lets the player DECLARE whether it was achieved on the table. For an objective
## battle (Deliver, Access, Patrol, ...) that declaration — not the Won/Lost
## proxy — is authoritative for mission success (Core Rules p.90). Before this
## fix the form hardcoded success = victory and had no objective field, so a
## LOG_ONLY player could never mark their specific objective met.

const FormClass = preload("res://src/ui/components/battle/BattleResultsInputForm.gd")

func _make_form(objective_prefill: Dictionary) -> Control:
	var form = FormClass.new()
	add_child(form)          # enters tree so setup() builds the UI
	auto_free(form)
	var crew: Array = [{"character_name": "Alpha", "combat": 1, "reactions": 1,
		"toughness": 3, "speed": 4}]
	form.setup(crew, 5, {}, objective_prefill)
	return form

func _submit(form: Control) -> Dictionary:
	var captured: Array = []
	form.results_submitted.connect(func(r: Dictionary) -> void: captured.append(r))
	form._on_submit()
	assert_int(captured.size()).is_equal(1)
	return captured[0]

# --- Objective battle: the DECLARED objective drives success ----------------

func test_objective_achieved_marks_success_and_id() -> void:
	var form = _make_form({"objective_id": "DELIVER",
		"objective_name": "Deliver", "objective_met": false})
	form._outcome_btn.selected = 0             # Won
	form._objective_met_check.button_pressed = true
	var r: Dictionary = _submit(form)
	assert_bool(r["objective_met"]).is_true()
	assert_str(r["objective_id"]).is_equal("DELIVER")
	assert_bool(r["success"]).is_true()

func test_won_fight_but_objective_failed_is_not_success() -> void:
	# Held the field yet did NOT deliver → mission FAILED (p.90). This is the
	# case the old "success = victory" proxy got wrong.
	var form = _make_form({"objective_id": "DELIVER",
		"objective_name": "Deliver", "objective_met": false})
	form._outcome_btn.selected = 0             # Won the fight
	form._objective_met_check.button_pressed = false
	var r: Dictionary = _submit(form)
	assert_bool(r["objective_met"]).is_false()
	assert_bool(r["success"]).is_false()

func test_lost_fight_but_objective_met_is_success() -> void:
	# Delivered the package then the crew got wiped → mission SUCCEEDED even
	# though the fight was lost. Objective is authoritative.
	var form = _make_form({"objective_id": "DELIVER",
		"objective_name": "Deliver", "objective_met": false})
	form._outcome_btn.selected = 1             # Lost
	form._objective_met_check.button_pressed = true
	var r: Dictionary = _submit(form)
	assert_bool(r["objective_met"]).is_true()
	assert_bool(r["success"]).is_true()

func test_objective_prefill_seeds_checkbox() -> void:
	var form = _make_form({"objective_id": "PATROL",
		"objective_name": "Patrol", "objective_met": true})
	assert_bool(form._objective_met_check.button_pressed).is_true()

func test_objective_from_mission_data_when_prefill_empty() -> void:
	# On-device F10 regression: a campaign LOG_ONLY battle has a NULL objective
	# tracker (its init reads different keys), so prefill is empty. The objective
	# lives on mission_data under "objective" (a String, e.g. "Deliver") — the
	# same key the battle's objective panel reads. Without this fallback the whole
	# MISSION OBJECTIVE section vanished and success fell back to the Won/Lost
	# proxy. Verify the section renders from mission_data and drives success.
	var form = FormClass.new()
	add_child(form)              # enters tree so setup() builds the UI
	auto_free(form)
	var crew: Array = [{"character_name": "Alpha", "combat": 1, "reactions": 1,
		"toughness": 3, "speed": 4}]
	form.setup(crew, 5, {"objective": "Deliver"}, {})   # mission_data only, empty prefill
	assert_object(form._objective_met_check).is_not_null()   # section rendered
	form._outcome_btn.selected = 1                       # LOST the fight
	form._objective_met_check.button_pressed = true      # but delivered the package
	var r: Dictionary = _submit(form)
	assert_str(r["objective_id"]).is_equal("DELIVER")    # normalized to canonical id
	assert_bool(r["success"]).is_true()                  # objective, not Won/Lost, drives it

# --- Non-objective battle: success falls back to Won/Lost -------------------

func test_no_objective_falls_back_to_victory() -> void:
	var form = _make_form({})                  # no objective_name → no section
	assert_object(form._objective_met_check).is_null()
	form._outcome_btn.selected = 0             # Won
	var r_won: Dictionary = _submit(form)
	assert_bool(r_won["success"]).is_true()

func test_no_objective_lost_is_not_success() -> void:
	var form = _make_form({})
	form._outcome_btn.selected = 1             # Lost
	var r_lost: Dictionary = _submit(form)
	assert_bool(r_lost["success"]).is_false()
	assert_bool(r_lost["objective_met"]).is_false()

# --- Layout regression (F10 on-device): form must NOT collapse in the drawer --

func test_form_reports_real_height_not_collapsed() -> void:
	# The host SlideOverDrawer sizes its panel to hug the content's height. A
	# prior build wrapped the ENTIRE form in its own SIZE_EXPAND_FILL
	# ScrollContainer, which reports a ~0 minimum height — so the drawer
	# collapsed to its 200px MIN_PANEL_H floor and clipped the whole form
	# on-device (objective section + Submit were invisible). Guard that the
	# form reports its natural (tall) minimum height so the drawer fits it.
	# A re-introduced expand-fill ScrollContainer would drop this back to ~64px.
	var form = _make_form({"objective_id": "DELIVER",
		"objective_name": "Deliver", "objective_met": false})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(form.get_combined_minimum_size().y).is_greater(400.0)


# --- Core Rules p.123 XP credit pickers (2026-09-03 desktop MCP walk) -------

func _make_form_with_crew(crew: Array, prefill: Dictionary) -> Control:
	var form = FormClass.new()
	add_child(form)
	auto_free(form)
	form.setup(crew, 5, {}, prefill)
	return form

func _xp_crew() -> Array:
	return [
		{"character_name": "Alpha", "character_id": "id_alpha", "combat": 1,
			"reactions": 1, "toughness": 3, "speed": 4},
		{"character_name": "Beta", "character_id": "id_beta", "combat": 1,
			"reactions": 1, "toughness": 3, "speed": 4},
	]

func test_nobody_selection_credits_nobody_not_the_first_crew_member() -> void:
	## picker.add_item("Nobody", -1) does NOT store -1: Godot treats -1 as
	## auto-assign and uses the item INDEX, so "Nobody" took id 0, the same id
	## as crew[0]. _picked_crew_id() resolves the selection through
	## get_item_id(), so choosing "Nobody" returned crew[0]'s character_id and
	## silently awarded that member the p.123 +1 XP for the first casualty and
	## for a Unique Individual kill. Proven live on the desktop MCP walk.
	var form = _make_form_with_crew(_xp_crew(), {})
	assert_str(form._first_casualty_btn.get_item_text(0)).is_equal("Nobody")
	assert_int(form._first_casualty_btn.get_item_id(0)).is_equal(-1)
	form._first_casualty_btn.select(0)
	form._unique_kill_btn.select(0)
	var r: Dictionary = _submit(form)
	assert_str(r["first_casualty_by"]).is_equal("")
	assert_int((r["unique_kills"] as Array).size()).is_equal(0)

func test_xp_pickers_seed_from_the_attribution_prefill() -> void:
	## The battle screen records who scored each casualty (TacticalUnit.killed_by
	## -> _attribution_prefill) and the prefill carries first_casualty_by /
	## unique_kills as crew_ids. _apply_prefill() read neither, so both pickers
	## opened on "Nobody" and the player had to re-enter what the app had just
	## written down -- which is the whole reason the attribution was added.
	var form = _make_form_with_crew(_xp_crew(),
		{"first_casualty_by": "id_beta", "unique_kills": ["id_alpha"]})
	assert_str(form._first_casualty_btn.get_item_text(
		form._first_casualty_btn.selected)).is_equal("Beta")
	assert_str(form._unique_kill_btn.get_item_text(
		form._unique_kill_btn.selected)).is_equal("Alpha")
	var r: Dictionary = _submit(form)
	assert_str(r["first_casualty_by"]).is_equal("id_beta")
	assert_int((r["unique_kills"] as Array).size()).is_equal(1)
	assert_str((r["unique_kills"] as Array)[0]).is_equal("id_alpha")

func test_submit_forwards_kills_by_character_from_the_prefill() -> void:
	## The form has no per-kill control: the battle screen records the credit
	## figure by figure through the p.46 Hit sheet and hands it over in the
	## prefill, so forwarding it IS the whole wire. Without it
	## PostBattleCompletion read an absent key, Character.lifetime_kills never
	## moved (its only other writer, Character.add_kill(), has ZERO callers) and
	## the "Kills" figure on CharacterDetailsScreen / CharacterHistoryPanel read
	## 0 for every campaign ever played.
	var form = _make_form_with_crew(_xp_crew(),
		{"kills_by_character": {"id_alpha": ["Pirate", "Pirates Lieutenant"]}})
	var r: Dictionary = _submit(form)
	assert_bool(r.has("kills_by_character")).is_true()
	var kbc: Dictionary = r["kills_by_character"]
	assert_bool(kbc.has("id_alpha")).is_true()
	# A LIST, never a count: PostBattleCompletion assigns it to a typed Array
	# and calls .size(). An int there aborts that whole function.
	assert_bool(kbc["id_alpha"] is Array).is_true()
	assert_int((kbc["id_alpha"] as Array).size()).is_equal(2)
