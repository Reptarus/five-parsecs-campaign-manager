extends GdUnitTestSuite

## Pins the Modiphius review-build flag (Sprint 0 §0.2): ReviewBuild.evaluate(), the
## DLCManager grant, the save refusal that keeps a review build's ownership off disk, and
## MainMenu.is_a1_build() staying TRUE in every non-review run.
##
## ReviewBuild.is_active() itself cannot be driven from here. An export preset's custom
## feature tags are not applied to editor or gdUnit4 runs (godot-docs feature_tags), and a
## test cannot inject a user argument into its own process. So the logic lives in the pure
## evaluate(), DLCManager's boot is split into _boot(review), and these cases drive both.
##
## The grant cases run on a DETACHED DLCManager, never the live autoload:
## set_dlc_owned(id, false) disables every flag of a pack, which on a dev machine that
## genuinely owns the packs would switch real entitlements off for the rest of the process.
##
## user://dlc_ownership.cfg is the developer's REAL ownership record, and the save-refusal
## case would write it if the guard regressed. Every case therefore snapshots it -- with the
## atomic writer's .tmp and .bak siblings -- and restores it byte-for-byte afterwards.

const ReviewBuild := preload("res://src/core/systems/ReviewBuild.gd")
const DLCManagerScript := preload("res://src/core/systems/DLCManager.gd")
const MainMenuScript := preload("res://src/ui/screens/mainmenu/MainMenu.gd")

const PREFS := "user://dlc_ownership.cfg"
const SIBLINGS: Array[String] = [PREFS, PREFS + ".tmp", PREFS + ".bak"]
## A key no real record carries, so a write is visible even when the record on this
## machine already owns every pack (an identical rewrite would otherwise hide it).
const PROBE_KEY := "zz_review_build_probe"

var _snapshot: Dictionary = {}  # path -> PackedByteArray, or null when absent
var _mgr: Node


func before_test() -> void:
	_snapshot.clear()
	for p: String in SIBLINGS:
		_snapshot[p] = _bytes_or_null(p)
	_mgr = DLCManagerScript.new()


func after_test() -> void:
	if is_instance_valid(_mgr):
		_mgr.free()
	for p: String in SIBLINGS:
		var before: Variant = _snapshot.get(p)
		if _bytes_or_null(p) == before:
			continue
		if before == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(before)
			f.close()


func _bytes_or_null(path: String) -> Variant:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null


# --- ReviewBuild.evaluate() -------------------------------------------------------------

func test_the_export_tag_turns_it_on_in_any_build() -> void:
	assert_bool(ReviewBuild.evaluate(true, PackedStringArray(), false)).is_true()
	assert_bool(ReviewBuild.evaluate(true, PackedStringArray(), true)).is_true()


func test_the_desk_argument_turns_it_on_in_a_debug_build() -> void:
	var args := PackedStringArray([ReviewBuild.DEBUG_ARG])
	assert_bool(ReviewBuild.evaluate(false, args, true)).is_true()


func test_a_release_build_ignores_the_command_line_argument() -> void:
	# A shipped alpha must not be talkable into review mode from its command line.
	var args := PackedStringArray([ReviewBuild.DEBUG_ARG])
	assert_bool(ReviewBuild.evaluate(false, args, false)).is_false()


func test_nothing_and_an_unrelated_argument_leave_it_off() -> void:
	assert_bool(ReviewBuild.evaluate(false, PackedStringArray(), true)).is_false()
	assert_bool(ReviewBuild.evaluate(false, PackedStringArray(["--server"]), true)).is_false()


func test_the_qa_tools_open_in_a_debug_or_review_build_and_never_in_an_alpha_release() -> void:
	# Plan "Product calls": reviewers reach Scenarios and "Force the next roll"; an
	# Alpha-1 release export stays unable to reach either.
	assert_bool(ReviewBuild.qa_tools_allowed(false, false)).is_false()
	assert_bool(ReviewBuild.qa_tools_allowed(true, false)).is_true()
	assert_bool(ReviewBuild.qa_tools_allowed(false, true)).is_true()
	assert_bool(ReviewBuild.qa_tools_allowed(true, true)).is_true()


func test_dice_forcing_reads_the_qa_gate_at_both_ends() -> void:
	var dm: Node = load("res://src/core/managers/DiceManager.gd").new()
	# Premise: this gdUnit4 process is a debug build, so the gate starts open.
	assert_bool(dm._forcing_allowed).is_true()
	assert_bool(dm.queue_forced_result("Gate Probe", 4)).is_true()
	dm._forcing_allowed = false
	assert_int(dm._take_forced("Gate Probe roll", 1, 6)).override_failure_message(
		"a closed gate still consumed a queued value").is_equal(-1)
	assert_bool(dm.queue_forced_result("Gate Probe", 5)).override_failure_message(
		"a closed gate still queued a value").is_false()
	dm.free()


func test_this_process_is_the_alpha_build() -> void:
	# The premise every other Alpha-1 suite relies on: no tag in an editor or gdUnit4 run,
	# so the menu keeps its Alpha-1 scope (pinned behaviourally by
	# test_main_menu_coming_soon.gd).
	assert_bool(ReviewBuild.is_active()).is_false()
	assert_bool(MainMenuScript.is_a1_build()).is_true()


# --- DLCManager boot ---------------------------------------------------------------------

func test_the_alpha_boot_owns_only_what_it_loaded() -> void:
	_mgr._boot(false)
	assert_bool(_mgr._review_ownership).is_false()
	var plain: Node = DLCManagerScript.new()
	plain.load_ownership()
	assert_dict(_mgr._owned_dlcs).is_equal(plain._owned_dlcs)
	plain.free()


func test_the_review_boot_owns_every_pack_and_offers_every_feature() -> void:
	_mgr._boot(true)
	for dlc_id: String in DLCManagerScript.DLC_IDS:
		assert_bool(_mgr.has_dlc(dlc_id)) \
			.override_failure_message("review build does not own %s" % dlc_id).is_true()
	# Every Compendium feature is then AVAILABLE, so the creation wizard offers it.
	# Whether it is ENABLED stays a per-campaign opt-in (see _apply_review_grants()).
	for dlc_id: String in DLCManagerScript.DLC_CONTENT_MAP:
		for flag: int in DLCManagerScript.DLC_CONTENT_MAP[dlc_id]:
			assert_bool(_mgr.is_feature_available(flag)) \
				.override_failure_message("flag %d of %s unavailable" % [flag, dlc_id]).is_true()


func test_a_review_build_never_writes_its_ownership_to_disk() -> void:
	_mgr._boot(true)
	# Premise: the record WAS loaded. Otherwise the older "never loaded" refusal is what
	# stops the write, and this case would stay green with the review guard deleted.
	assert_bool(_mgr.is_ownership_loaded()) \
		.override_failure_message("premise: load_ownership() did not mark the record "
			+ "loaded, so this case would pass for the wrong reason").is_true()
	_mgr._owned_dlcs[PROBE_KEY] = true
	_mgr.save_ownership()
	for p: String in SIBLINGS:
		assert_that(_bytes_or_null(p)) \
			.override_failure_message("%s changed: a review build wrote its granted "
				% p + "ownership to disk, which the alpha would then boot owning") \
			.is_equal(_snapshot[p])


func test_the_guard_is_up_before_the_first_ownership_signal() -> void:
	# A listener that saves while set_dlc_owned() emits must be refused too.
	var seen: Array = []
	_mgr.dlc_ownership_changed.connect(func(_id: String, _owned: bool) -> void:
		seen.append(_mgr._review_ownership))
	_mgr._apply_review_grants()
	assert_int(seen.size()).is_equal(DLCManagerScript.DLC_IDS.size())
	assert_bool(false in seen).is_false()
