extends GdUnitTestSuite

## Pins tests/fixtures/helpers/save_dir_guard.gd.
##
## The guard exists to stop test suites polluting user:// state, so the case that
## matters most is NOT "it deletes what the test wrote" -- it is
## test_a_file_that_existed_before_the_snapshot_survives. The user's save
## directory holds QA artefacts cited as device-deploy evidence in
## docs/qa/TABLET_QA_SPRINT_2026-08.md. A cleanup helper that reached one of
## those would be far worse than the litter it was written to remove, so the
## boundary is asserted directly rather than trusted.
##
## Every case cleans up after ITSELF as well, using explicit paths it chose --
## the guard is the thing under test here, so it cannot also be the thing relied
## on to leave the directory tidy.

const Guard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const SAVES_DIR := "user://saves/"
const POLLUTION := "zz_guard_pollution"
const PRE := "user://saves/zz_guard_pre_existing.probe"
const NEW := "user://saves/zz_guard_appeared.probe"
const NEW_BAK := "user://saves/zz_guard_appeared.probe.bak"


func before_test() -> void:
	_scrub()


func after_test() -> void:
	_scrub()


func _scrub() -> void:
	for p in [PRE, NEW, NEW_BAK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _touch(path: String, body: String = "probe") -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_that(f).is_not_null()
	f.store_string(body)
	f.close()


## THE SAFETY CASE. A file present at snapshot() time is not the test's to delete.
func test_a_file_that_existed_before_the_snapshot_survives() -> void:
	_touch(PRE)
	assert_bool(FileAccess.file_exists(PRE)).is_true() \
		.override_failure_message("premise: the pre-existing probe was not created")

	var snap := Guard.snapshot()

	# PREMISE, and the counterweight to the unreadable-listing case below. A real
	# snapshot of a readable directory must report files_listed TRUE -- otherwise the
	# hand-built false shape down there describes a state snapshot() never emits, and
	# the deletion this case asserts would be refused for the wrong reason. Together
	# the two cases bracket the refusal: it must fire on an unreadable listing and it
	# must NOT fire on a readable one.
	assert_bool(bool(snap.get("files_listed", false))).override_failure_message(
		"snapshot() did not record a successful listing of a readable directory"
	).is_true()

	_touch(NEW)

	var removed := Guard.restore(snap)

	assert_bool(FileAccess.file_exists(PRE)).is_true() \
		.override_failure_message(
			"restore() deleted a file that existed BEFORE the snapshot. "
			+ "The user's save directory holds QA evidence; the guard must never reach it.")
	assert_bool(FileAccess.file_exists(NEW)).is_false() \
		.override_failure_message("restore() left behind a file the test created")
	assert_int(removed).is_equal(1)


## Godot's atomic writer leaves a .bak sibling, so a single save_campaign() call
## can add two files. The guard counts what appeared, not what it expected.
func test_every_file_that_appeared_is_removed_including_siblings() -> void:
	var snap := Guard.snapshot()
	_touch(NEW)
	_touch(NEW_BAK)

	var removed := Guard.restore(snap)

	assert_int(removed).is_equal(2)
	assert_bool(FileAccess.file_exists(NEW)).is_false()
	assert_bool(FileAccess.file_exists(NEW_BAK)).is_false()


## The settings file is half the bleed vector: save_campaign() writes
## last_campaign into it, and _try_auto_load_last_campaign() reads that at every
## launch. Restoring the save directory alone would leave the key behind.
func test_settings_file_bytes_are_restored_exactly() -> void:
	var path: String = Guard.SETTINGS_PATH
	if not FileAccess.file_exists(path):
		return  # nothing to protect on a fresh user:// -- see the absent-file case below

	var before := FileAccess.get_file_as_bytes(path)
	var snap := Guard.snapshot()

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[settings]\n\nlast_campaign=\"" + POLLUTION + "\"\n")
	f.close()
	assert_bool(FileAccess.get_file_as_bytes(path) == before).is_false() \
		.override_failure_message("premise: the pollution write did not change the file")

	Guard.restore(snap)

	assert_bool(FileAccess.get_file_as_bytes(path) == before).is_true() \
		.override_failure_message("restore() did not put settings.cfg back byte for byte")


## GameState is an autoload holding game_settings in memory. Restoring only the
## file would leave the polluted dict live, and the next save_settings() call
## would write it straight back -- so the guard restores the dict too, first.
func test_the_in_memory_settings_dict_is_restored() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not (gs.get("game_settings") is Dictionary):
		return  # no autoload in this process; the file half is covered above

	var original: Dictionary = (gs.get("game_settings") as Dictionary).duplicate(true)
	var snap := Guard.snapshot()

	# PREMISE: the pollution has to be a CHANGE. If the ambient last_campaign
	# already equals it, the final assertion below is true whether restore() ran
	# or not -- measured: a detection arm that reverted the dict restore came back
	# GREEN, because an EARLIER arm had left exactly this value in settings.cfg and
	# GameState had booted with it. Case 3 has the equivalent guard (it asserts the
	# file bytes moved); this one did not.
	assert_str(str(original.get("last_campaign", ""))).is_not_equal(POLLUTION) \
		.override_failure_message(
			"premise: the ambient last_campaign is ALREADY the pollution value, so this "
			+ "case cannot discriminate. Something left it behind -- clear it first.")

	var polluted: Dictionary = original.duplicate(true)
	polluted["last_campaign"] = POLLUTION
	gs.set("game_settings", polluted)
	assert_str(str(gs.get("game_settings").get("last_campaign"))) \
		.is_equal(POLLUTION) \
		.override_failure_message("premise: the in-memory dict was not polluted")

	Guard.restore(snap)

	assert_str(str(gs.get("game_settings").get("last_campaign"))) \
		.is_equal(str(original.get("last_campaign", ""))) \
		.override_failure_message(
			"restore() left the polluted campaign id in GameState.game_settings. "
			+ "The file was restored but the live dict was not, so the next "
			+ "save_settings() call writes the pollution back.")


## An empty or absent snapshot must be a no-op, not a directory wipe. This is the
## emptiest legal input, which is exactly the shape that turned a guard into a
## destructive reset elsewhere in this project.
func test_an_empty_snapshot_removes_nothing() -> void:
	_touch(PRE)

	# THE FILE HALF IS ONLY HALF OF "INERT", and the other half was unasserted
	# until 2026-09-21. Without the early return, execution reaches
	# `bytes = snap.get("settings_bytes")`, reads null, and takes the null branch --
	# which DELETES the live settings.cfg. Meanwhile _deletable() refuses the empty
	# snapshot, so the save files survive and both original assertions pass. The
	# detection arm for this guard could therefore destroy settings.cfg and report
	# green. "No bytes to put back" is not the same claim as "there was no file".
	var settings_before := FileAccess.file_exists(Guard.SETTINGS_PATH)

	assert_int(Guard.restore({})).is_equal(0)

	assert_bool(FileAccess.file_exists(PRE)).override_failure_message(
		"restore({}) deleted files; an empty snapshot must be inert"
	).is_true()
	assert_bool(FileAccess.file_exists(Guard.SETTINGS_PATH)).override_failure_message(
		"restore({}) deleted user://settings.cfg. An empty snapshot carries no bytes "
		+ "to put back, and that is not the same claim as 'there was no file'."
	).is_equal(settings_before)


## THE SECOND SAFETY CASE, and the one the 2026-09-21 incident argues for.
##
## A save directory that cannot be READ used to be indistinguishable from one that
## is EMPTY: _list_saves() returned {} for both. With an empty before-set every
## surviving file looks like it appeared during the test, so a single transient
## DirAccess.open() failure -- a permissions blip, or the Synology client holding
## the handle, which this project runs inside -- turned cleanup into a wipe. That is
## the same shape as the harness revert that deleted 238 real saves, reachable with
## no revert and no bug.
##
## LIMITATION, stated rather than papered over: an open failure cannot be induced
## from inside the engine, so this case builds the snapshot the producer emits in
## that state instead of provoking the state. Case 1 instruments the premise -- it
## asserts a REAL snapshot reports files_listed true -- so the shape here is one
## snapshot() can actually produce and not a fiction.
##
## THE MIRROR OF THIS CASE MUST NOT BE WRITTEN. "An honest empty before-set still
## cleans up" would mean handing restore() {"files": {}, "files_listed": true}
## against the live user://saves/ -- which is the incident itself: every real save
## is absent from that before-set, so the case would delete the directory on its way
## to passing. Case 1 covers that direction safely, because its snapshot is real.
func test_an_unreadable_listing_is_not_treated_as_an_empty_directory() -> void:
	_touch(PRE)

	# What snapshot() returns when DirAccess.open() failed: no before-set, and an
	# explicit admission that it has none.
	var blind := {
		"files": {},
		"files_listed": false,
		"settings_bytes": null,
		"game_settings": null,
	}

	var removed := Guard.restore(blind)

	assert_bool(FileAccess.file_exists(PRE)).override_failure_message(
		"restore() deleted a save after a snapshot that could not read the directory. "
		+ "An unreadable listing is not an empty one -- with no before-set, every file "
		+ "on disk looks new, and this is the 238-file deletion reachable without a revert."
	).is_true()
	assert_int(removed).override_failure_message(
		"restore() reported deletions it could not possibly have justified"
	).is_equal(0)


## THE SAME REFUSAL, PROVEN WITHOUT RISKING ANYTHING -- and the only case here a
## detection arm may safely target.
##
## Every other safety case in this suite can be disproven only by a revert that
## DELETES, because restore() is the actuator: strip a guard from it and the call
## that was inert becomes a wipe of the real user://saves/. That is exactly the
## shape that destroyed 238 files on 2026-09-21 -- the proof and the disaster were
## the same event.
##
## _deletable() is the decision, separated from the act. It returns a LIST and
## deletes nothing, so reverting its refusal turns this case red while no file is
## touched. It is the first assertion about this guard's safety property that is
## safe to disprove.
##
## It calls an underscore method on purpose. The refusal is not observable through
## restore() without letting restore() act, which is the whole problem.
##
## The refused path emits push_warning(); gdUnit4 does not fail a case on a warning
## (only push_error is monitored). If that ever changes, this case goes red for a
## reason that has nothing to do with the guard -- check the report text first.
func test_deletable_returns_nothing_when_the_listing_could_not_be_read() -> void:
	var blind := {
		"files": {},
		"files_listed": false,
		"settings_bytes": null,
		"game_settings": null,
	}

	var deletable = Guard._deletable(blind)

	assert_bool(deletable is Array).override_failure_message(
		"_deletable() must return an Array; restore() iterates whatever it hands back"
	).is_true()
	assert_int((deletable as Array).size()).override_failure_message(
		"_deletable() nominated files for deletion from a snapshot that admits it "
		+ "could not read the directory. With no before-set, nothing can be SHOWN to "
		+ "have appeared during the test, so the only honest answer is an empty list."
	).is_equal(0)
