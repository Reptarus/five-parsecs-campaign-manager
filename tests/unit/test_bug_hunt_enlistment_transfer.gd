extends GdUnitTestSuite
## When a 5PFH veteran enlists into Bug Hunt, do they LEAVE the campaign they came from?
##
## Bug Hunt Sprint 1, Phase 2 step 4. HEAD appended the veteran to
## _campaign.main_characters and stopped: the character then existed in BOTH campaigns,
## and the source save still offered them, so the same veteran could be enlisted again
## and again. That is the "one item, one home" breach
## CharacterTransferService.remove_character_from_save() (:617) was written to close for
## the Planetfall and Tactics pull-imports; Bug Hunt was the leg nobody wired.
##
## WHERE THE DAMAGE LANDS, AND THEREFORE WHERE THIS ASSERTS. Not on a return value and
## not on a signal: on the SOURCE SAVE FILE. Cases 3 and 5 re-read that file's bytes off
## disk after the enlistment, because a removal that reports success and writes nothing
## is indistinguishable from the defect at every other vantage point.
##
## TWO HALVES, PROVED SEPARATELY. The panel must STAMP where the veteran came from
## (cases 1-2) and the dashboard must ACT on the stamp (cases 3-5). Either half alone
## changes nothing a player can see, so each is asserted on its own — the shape the
## house-rules fix needed when two independent causes were each individually fatal.
##
## WHY _selected_character AND NOT result.transferred_character. The id
## remove_character_from_save() matches is the one in the SOURCE file. The conversion
## may rewrite fields, so stamping the post-conversion id would match nothing, the
## removal would silently no-op, and the duplicate would survive. Case 1 asserts the
## stamped id equals the source row's id, which is what makes that concrete.
##
## SIDE EFFECTS. The dashboard cases drive the real BugHuntDashboard scene, so
## _apply_enlistment()'s own _on_save() runs: GameState.save_campaign() writes
## user://saves/<campaign_id>.save through SaveFileWriter (leaving .tmp and .bak
## siblings), sets last_campaign and rewrites ALL of user://settings.cfg, which
## _try_auto_load_last_campaign() reads at every launch — the documented cross-suite
## bleed. So the core carries a fixed id, both probe saves and all their siblings are
## removed before and after every case, GameState.current_campaign is snapshotted, and
## the settings are restored as the dictionary AND the file's exact bytes (save_settings()
## re-serialises every key, so a key-level restore would still rewrite the file).

const DASHBOARD_SCENE := "res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn"
const PanelScript := preload(
		"res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const BugHuntCoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")

const BH_ID := "zz_enlist_transfer_bug_hunt_probe"
const FP_ID := "zz_enlist_transfer_five_parsecs_probe"
const BH_SAVE := "user://saves/zz_enlist_transfer_bug_hunt_probe.save"
const FP_SAVE := "user://saves/zz_enlist_transfer_five_parsecs_probe.save"
const SETTINGS_PATH := "user://settings.cfg"

## The veteran who enlists, and the two who must stay behind. Ids are explicit so the
## assertions name a character rather than an index — a removal that takes the wrong row
## would otherwise read as a pass.
const VET_ID := "zz_vet_enlisting"
const STAY_A_ID := "zz_vet_stays_a"
const STAY_B_ID := "zz_vet_stays_b"

var _saved_campaign: Variant = null
var _saved_settings: Dictionary = {}
var _settings_existed := false
var _settings_bytes := PackedByteArray()


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func before_test() -> void:
	var gs := _gs()
	if gs:
		_saved_campaign = gs.current_campaign
		_saved_settings = (gs.game_settings as Dictionary).duplicate(true)
	_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	_settings_bytes = PackedByteArray()
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	# A run aborted mid-case leaves probe saves behind, and read_json_with_fallback()
	# would then serve a previous case's .bak to this one.
	_remove_probe_saves()


func after_test() -> void:
	var gs := _gs()
	if gs:
		gs.current_campaign = _saved_campaign
		gs.game_settings = _saved_settings.duplicate(true)
	_restore_settings_file()
	_remove_probe_saves()


func _restore_settings_file() -> void:
	# Same shape as test_bug_hunt_turn_completion.gd, written only on a change.
	if _settings_existed:
		if FileAccess.get_file_as_bytes(SETTINGS_PATH) != _settings_bytes:
			var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
			if f:
				f.store_buffer(_settings_bytes)
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _remove_probe_saves() -> void:
	# SaveFileWriter.write_text_atomic() writes path + ".tmp" and keeps path + ".bak".
	for base in [BH_SAVE, FP_SAVE]:
		for suffix in ["", ".tmp", ".bak"]:
			var path: String = base + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


## A 5PFH crew member in the shape to_dictionary() persists: both id spellings, because
## remove_character_from_save() reads character_id then id and a fixture that carries
## only one of them would not prove the other resolves.
func _member(char_id: String, char_name: String) -> Dictionary:
	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_name,
		"character_name": char_name,
		"combat": 1,
		"reaction": 2,
		"speed": 4,
		"savvy": 0,
		"toughness": 3,
		"luck": 1,
	}


## The source campaign on disk: three crew, the enlisting veteran in the MIDDLE so a
## removal that takes the first or last row is caught.
func _write_source_save() -> void:
	var core := FiveParsecsCampaignCore.new()
	core.campaign_name = "Enlist transfer — 5PFH probe"
	core.campaign_id = FP_ID
	core.add_crew_member(_member(STAY_A_ID, "Stays Behind A"))
	core.add_crew_member(_member(VET_ID, "Enlisting Veteran"))
	core.add_crew_member(_member(STAY_B_ID, "Stays Behind B"))
	core.save_to_file(FP_SAVE)


func _make_bug_hunt_core() -> Resource:
	var core: Resource = BugHuntCoreScript.new()
	core.campaign_name = "Enlist transfer — Bug Hunt probe"
	# Fixed, so the save _on_save() writes has a name this suite can remove.
	core.campaign_id = BH_ID
	return core


## The crew ids the SOURCE SAVE still holds, read from the file's own bytes. Deliberately
## not load_from_file(): that runs apply_pending_qol_data(), which resets the
## PlanetDataManager autoload for every suite that runs afterwards.
func _source_crew_ids() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(FP_SAVE):
		return out
	var f := FileAccess.open(FP_SAVE, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return out
	var data: Dictionary = parsed
	var crew: Variant = data.get("crew", {})
	if not (crew is Dictionary):
		return out
	var members: Variant = (crew as Dictionary).get("members", [])
	if not (members is Array):
		return out
	for m_v in (members as Array):
		if m_v is Dictionary:
			out.append(str((m_v as Dictionary).get("character_id",
				(m_v as Dictionary).get("id", ""))))
	return out


## A real transfer panel in the tree — _ready() builds its UI and _scaled_font() reaches
## the ResponsiveManager autoload, neither of which works on a detached node.
func _build_panel() -> Control:
	var panel: Control = PanelScript.new()
	add_child(panel)
	auto_free(panel)
	return panel


## A successful enlistment result in the shape _show_enlistment_result() consumes. The
## roll is fixed rather than rolled: this suite is about what happens AFTER acceptance,
## and a real 2D6+CS would reject the veteran on roughly a third of runs.
func _accepted_result(transferred: Dictionary) -> Dictionary:
	return {
		"success": true,
		"dice": [5, 5],
		"combat_bonus": 1,
		"roll": 11,
		"transferred_character": transferred,
	}


## Commit an accepted enlistment the way Confirm does, and return what it emitted.
##
## REPOINTED 2026-09-22 (W-N24). This helper used to press the result screen's
## "Welcome Aboard!" control, because that button WAS the commit -- which is the defect:
## backing out of the result screen discarded an accepted roll. The commit now happens in
## _commit_enlistment(), called from _execute_transfer() before the screen is built, and
## the dismiss button only closes. test_the_result_screens_dismiss_control_commits_nothing
## pins that the button no longer emits.
##
## ⚠ The emitted dict is COLLECTED INTO AN ARRAY, not assigned to a captured variable.
## GDScript lambdas capture by value: `emitted = char_data` inside the handler rebinds the
## lambda's own copy and the outer name keeps its old value, so every assertion here would
## read an empty dict and report the production code as unstamped. Mutating a captured
## container (append) reaches the outer scope; rebinding a captured name does not. The
## size check below is therefore also the premise instrument — and asserting EXACTLY one
## entry additionally catches a double-fire, which the pointer-family traps make cheap.
func _commit_via_panel(panel: Control, result: Dictionary) -> Dictionary:
	var emits: Array = []
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String):
			emits.append(char_data))
	panel._commit_enlistment(result)
	assert_int(emits.size()).override_failure_message(
		"fixture premise: committing an accepted enlistment must emit character_transferred"
		+ " exactly once — 0 means this case never reached the stamp site, more than 1"
		+ " means the emit double-fired"
	).is_equal(1)
	return emits[0] if emits.size() == 1 else {}


## Every Button under the panel whose text is `label`. Walked by class, because the
## result screen is code-built and its node names are not stable.
func _buttons_labelled(panel: Control, label: String) -> Array:
	var out: Array = []
	for node in panel.find_children("*", "Button", true, false):
		if (node as Button).text == label:
			out.append(node)
	return out


## A real dashboard bound to our Bug Hunt core, via GameState as the screen resolves it.
func _build_dashboard(core: Resource) -> Control:
	var gs := _gs()
	assert_object(gs).override_failure_message(
		"fixture premise: this case needs the GameState autoload"
	).is_not_null()
	gs.current_campaign = core
	var dash: Control = load(DASHBOARD_SCENE).instantiate()
	add_child(dash)
	auto_free(dash)
	await get_tree().process_frame
	assert_object(dash._campaign).override_failure_message(
		"fixture premise: the dashboard must have resolved OUR core, or _apply_enlistment"
		+ " returns early and every assertion below passes vacuously"
	).is_same(core)
	return dash


func test_the_panel_stamps_where_the_veteran_came_from() -> void:
	# The producing half. Without this the dashboard has no source to remove from, and
	# its fix is unreachable however correct it is.
	_write_source_save()
	var panel := _build_panel()
	panel.set_direction("enlist")
	panel.load_characters_from_save(FP_SAVE)

	var source_row: Dictionary = {}
	for row_v in panel._source_characters:
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == VET_ID:
			source_row = row_v
			break
	assert_dict(source_row).override_failure_message(
		"fixture premise: the panel must have read the veteran out of the source save,"
		+ " or the stamp has nothing to name"
	).is_not_empty()

	panel._selected_character = source_row
	# The conversion rewrites fields, so the transferred shape deliberately carries a
	# DIFFERENT id here. That is the whole point of stamping from _selected_character.
	var converted := {"id": "post_conversion_id", "name": "Enlisting Veteran"}
	var emitted := _commit_via_panel(panel, _accepted_result(converted))

	assert_str(str(emitted.get("_source_path", ""))).override_failure_message(
		"the enlist emit must name the save the veteran was read from, or the dashboard"
		+ " cannot remove them and they exist in both campaigns"
	).is_equal(FP_SAVE)
	assert_str(str(emitted.get("_source_character_id", ""))).override_failure_message(
		"the stamped id must be the SOURCE row's id, not the converted one:"
		+ " remove_character_from_save matches the id in the source file, so a converted"
		+ " id matches nothing and the removal silently no-ops"
	).is_equal(VET_ID)


func test_an_in_memory_source_stamps_nothing() -> void:
	# The guard. load_characters_from_array() is muster-out's loader (BugHuntDashboard
	# :317) and has no file behind it; a path left over from a previous load would aim
	# the removal at a save the player never picked from.
	var panel := _build_panel()
	panel.set_direction("enlist")
	panel.load_characters_from_save(FP_SAVE)  # no file on disk yet: sets nothing
	panel.load_characters_from_array([_member(VET_ID, "In Memory Veteran")])
	panel._selected_character = panel._source_characters[0]
	var emitted := _commit_via_panel(panel,
		_accepted_result({"id": VET_ID, "name": "In Memory Veteran"}))

	assert_bool(emitted.has("_source_path")).override_failure_message(
		"an in-memory source has no file to remove from; stamping one would point the"
		+ " removal at whatever save was loaded last"
	).is_false()
	assert_bool(emitted.has("_source_character_id")).override_failure_message(
		"the two coordinates are written together or not at all"
	).is_false()


func test_enlisting_removes_the_veteran_from_the_source_campaign() -> void:
	# THE case. The damage lands in the source save, so that is what is read back.
	_write_source_save()
	assert_array(_source_crew_ids()).override_failure_message(
		"fixture premise: all three crew must be in the source save before the"
		+ " enlistment, or a removal has nothing to prove"
	).contains([STAY_A_ID, VET_ID, STAY_B_ID])

	var core := _make_bug_hunt_core()
	var dash: Control = await _build_dashboard(core)

	var enlisted := _member(VET_ID, "Enlisting Veteran")
	enlisted["_source_path"] = FP_SAVE
	enlisted["_source_character_id"] = VET_ID
	dash._apply_enlistment(enlisted)

	var names: Array = []
	for mc_v in core.main_characters:
		if mc_v is Dictionary:
			names.append(str((mc_v as Dictionary).get("name", "")))
	assert_array(names).override_failure_message(
		"the veteran must arrive in the Bug Hunt squad"
	).contains(["Enlisting Veteran"])

	var remaining := _source_crew_ids()
	assert_array(remaining).override_failure_message(
		"the veteran is still in the source save: they now exist in BOTH campaigns and"
		+ " can be enlisted again off the same save"
	).not_contains([VET_ID])
	assert_array(remaining).override_failure_message(
		"only the enlisting veteran leaves — a removal that took the wrong row, or the"
		+ " whole roster, would still satisfy the assertion above"
	).contains_exactly_in_any_order([STAY_A_ID, STAY_B_ID])


func test_the_source_coordinates_do_not_persist_into_the_bug_hunt_save() -> void:
	# The two underscore keys are wiring between the panel and the dashboard. Leaving
	# them on the character would persist a path to another campaign's save file into
	# this one's roster, and it would survive every later export of that character.
	_write_source_save()
	var core := _make_bug_hunt_core()
	var dash: Control = await _build_dashboard(core)

	var enlisted := _member(VET_ID, "Enlisting Veteran")
	enlisted["_source_path"] = FP_SAVE
	enlisted["_source_character_id"] = VET_ID
	dash._apply_enlistment(enlisted)

	var landed: Dictionary = {}
	for mc_v in core.main_characters:
		if mc_v is Dictionary and str((mc_v as Dictionary).get("id", "")) == VET_ID:
			landed = mc_v
			break
	assert_dict(landed).override_failure_message(
		"fixture premise: the veteran must be in the squad before asking what they carry"
	).is_not_empty()
	assert_bool(landed.has("_source_path")).override_failure_message(
		"_source_path is panel-to-dashboard wiring and must not reach the roster"
	).is_false()
	assert_bool(landed.has("_source_character_id")).override_failure_message(
		"_source_character_id is panel-to-dashboard wiring and must not reach the roster"
	).is_false()


func test_an_enlistment_without_coordinates_still_adds_the_veteran() -> void:
	# Tolerance, and a guard against over-correcting. An unstamped enlistment is a real
	# shape — the in-memory loader produces one — and it must still recruit rather than
	# fail closed. Nothing is removed, because nothing named a source.
	_write_source_save()
	var core := _make_bug_hunt_core()
	var dash: Control = await _build_dashboard(core)

	dash._apply_enlistment(_member("zz_unstamped", "Unstamped Veteran"))

	assert_int(core.main_characters.size()).override_failure_message(
		"an enlistment with no source coordinates must still add the veteran"
	).is_equal(1)
	assert_array(_source_crew_ids()).override_failure_message(
		"with no source named, the source campaign must be left exactly as it was"
	).contains_exactly_in_any_order([STAY_A_ID, VET_ID, STAY_B_ID])
func test_a_rebuild_during_the_reveal_does_not_fade_a_freed_card() -> void:
	# Lives in THIS suite because it is the only Bug Hunt suite that builds the real
	# dashboard, and because this is the suite the defect surfaced in: it passes 5/5 ALONE
	# and errored in a full tests/unit batch run at BugHuntDashboard.gd:215 with
	# "Invalid type in function 'fade_in' ... argument 1 (previously freed)".
	#
	# The race: _stagger_reveal() fades card 0 with no await, then suspends 0.04s before
	# each of the rest, holding an array captured before the first await. Three callers
	# (:29, :329, :426) free the whole subtree and rebuild, and queue_free() lands at the
	# end of the frame -- well inside 0.04s -- so the suspended coroutine wakes up holding
	# freed nodes.
	#
	# ⚠ The DISCRIMINATOR is gdUnit4's Godot-runtime-error capture, NOT the assertion at
	# the bottom: pre-fix this case ERRORS, post-fix it passes. The alpha assertion is the
	# anti-over-correction arm -- it passes pre-fix too, and is here so that a guard which
	# also bails out of the NEW reveal (leaving the rebuilt cards dark) cannot slip through
	# green. Detection-proven both ways.
	_write_source_save()
	var core := _make_bug_hunt_core()
	var dash: Control = await _build_dashboard(core)

	var first_content: Node = dash._content
	assert_int(first_content.get_child_count()).override_failure_message(
		"fixture premise: the reveal needs at least two cards, or it never awaits at all"
		+ " and there is no window for the race to land in"
	).is_greater(1)

	# Exactly what :29, :329 and :426 do, with nothing else in the way.
	for child in dash.get_children():
		child.queue_free()
	dash._build_dashboard()

	assert_object(dash._content).override_failure_message(
		"fixture premise: the rebuild must have rebound _content, or the stale coroutine has"
		+ " nothing to notice and this case cannot reproduce the race"
	).is_not_same(first_content)

	# Long enough for BOTH reveals to run their staggers out and their fades to settle:
	# ~7 cards x 0.04s stagger + a 0.2s fade lands under 0.5s.
	await get_tree().create_timer(0.9).timeout

	for child in dash._content.get_children():
		if child is Control:
			assert_float(child.modulate.a).override_failure_message(
				"the rebuilt dashboard must end fully revealed; '%s' is still at alpha %f"
				% [child.name, child.modulate.a]
			).is_equal_approx(1.0, 0.01)


## Every Label text under the panel, joined. Absence assertions read this, so a string
## that exists only on a screen this case never built cannot satisfy them by accident.
func _label_text(panel: Control) -> String:
	var parts: PackedStringArray = []
	for node in panel.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


## A listener that behaves like BugHuntDashboard when _apply_* returns an error: it
## reports it DURING the emit, which is the only window the panel reads it in.
func _fail_every_commit(panel: Control, message: String) -> void:
	panel.character_transferred.connect(
		func(_char_data: Dictionary, _dir: String):
			panel.report_commit_error(message))


func test_the_result_screens_dismiss_control_commits_nothing() -> void:
	# W-N24. The dismiss button WAS the commit, so backing out of the result screen lost an
	# accepted roll -- and p.212 gates the retry on the next mission. It now only closes.
	var panel := _build_panel()
	panel.set_direction("enlist")
	var emits: Array = []
	var closes: Array = []
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String): emits.append(char_data))
	panel.transfer_closed.connect(func(): closes.append(true))

	panel._show_enlistment_result(
		_accepted_result({"id": VET_ID, "name": "Enlisting Veteran"}))
	var buttons := _buttons_labelled(panel, "Welcome Aboard!")
	assert_int(buttons.size()).override_failure_message(
		"fixture premise: the accepted-enlistment screen must offer exactly one"
		+ " Welcome Aboard! control, or this case is not pressing the dismiss button"
	).is_equal(1)
	(buttons[0] as Button).emit_signal("pressed")

	assert_int(emits.size()).override_failure_message(
		"the result screen's dismiss control must NOT commit: the enlistment was committed"
		+ " by _commit_enlistment() before this screen was built, so an emit here would"
		+ " apply it twice"
	).is_equal(0)
	assert_int(closes.size()).override_failure_message(
		"dismissing must emit transfer_closed exactly once -- the dashboard rebuilds on it,"
		+ " and the rebuild can no longer run inside _apply_enlistment()"
	).is_equal(1)


func test_a_failed_enlist_commit_is_not_announced_as_an_ineligibility() -> void:
	# The failure dict carries no `dice`, and the enlist screen reads a missing `dice` as
	# "never rolled". Without commit_failed, an accepted roll whose SAVE failed was told
	# "This character is not eligible for Bug Hunt service" -- false twice over.
	var panel := _build_panel()
	panel.set_direction("enlist")
	panel.load_characters_from_array([_member(VET_ID, "Enlisting Veteran")])
	panel._selected_character = panel._source_characters[0]
	_fail_every_commit(panel, "zz probe: the campaign could not be written")

	var shown: Dictionary = panel._commit_enlistment(
		_accepted_result({"id": VET_ID, "name": "Enlisting Veteran"}))
	assert_bool(shown.get("success", true)).override_failure_message(
		"a commit the listener reported as failed must not be shown as a success"
	).is_false()

	panel._show_enlistment_result(shown)
	var text := _label_text(panel)
	assert_bool(text.contains("NOT SAVED")).override_failure_message(
		"a failed commit must say the enlistment was not saved; the screen read:\n" + text
	).is_true()
	assert_bool(text.contains("zz probe: the campaign could not be written")).override_failure_message(
		"the screen must show the listener's reason, or the player cannot act on it"
	).is_true()
	assert_bool(text.contains("CANNOT ENLIST")
		or text.contains("This character is not eligible")).override_failure_message(
		"the roll was ACCEPTED; announcing an ineligibility sends the player hunting for a"
		+ " rules problem that does not exist. The screen read:\n" + text
	).is_false()


func test_the_muster_screen_never_claims_success_before_the_commit() -> void:
	# W-N24, muster side. CharacterTransferService.muster_out() writes nothing, so the
	# "MUSTERED OUT!" breakdown used to render over a transfer file nobody had written.
	var panel := _build_panel()
	panel.set_direction("muster_out")
	_fail_every_commit(panel, "zz probe: the transfer file could not be written")

	var shown: Dictionary = panel._commit_muster_out({
		"success": true,
		"transferred_character": {"id": VET_ID, "name": "Mustering Marine"},
	})
	panel._show_muster_result(shown)
	var text := _label_text(panel)
	assert_bool(text.contains("MUSTERED OUT!")).override_failure_message(
		"a muster-out whose commit failed must not announce success; the screen read:\n"
		+ text
	).is_false()
	assert_bool(text.contains("TRANSFER FAILED")).override_failure_message(
		"a failed muster commit must say so; the screen read:\n" + text
	).is_true()
