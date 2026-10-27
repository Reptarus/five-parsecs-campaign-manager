extends RefCounted

## Snapshot-and-restore guard for the two pieces of user:// state a test run can
## silently pollute: the save DIRECTORY and the settings FILE.
##
## WHY SNAPSHOT-AND-DIFF RATHER THAN "DELETE THE FILE I WROTE"
##
## The obvious shape -- record the path in the test, delete it in after_test() --
## is what tests/unit/test_bug_hunt_mode_predicates.gd does, and it works there
## because that suite chooses its own filenames. It cannot work for the Tactics
## suites: TacticsPhaseManager._complete_turn() (:193-201) calls
## GameState.save_campaign(), which derives the path from
## TacticsCampaignCore.get_campaign_id() (:106) -- an id auto-generated from
## Time.get_unix_time_from_system() that the test never sees. Measured result:
## 105 anonymous tactics_<unix>.save files plus 52 .bak siblings in the user's
## save directory, all with campaign_name "" and zero units.
##
## So the guard does not predict what will be written. It observes what APPEARED,
## which also gives it the property this repo requires: it removes ONLY files that
## did not exist when the test began, so a pre-existing QA artefact cited as
## device-deploy evidence is never touched.
##
## WHY THE SETTINGS FILE IS PART OF THE SAME GUARD
##
## save_campaign() does two things, not one (GameState.gd:641-651): it writes the
## save, and then it writes game_settings["last_campaign"] and calls
## save_settings(). _try_auto_load_last_campaign() (:188) reads that key at every
## launch. That is the documented cross-suite bleed vector -- a suite that runs
## later inherits whichever campaign a previous PROCESS last saved.
##
## Measured before this guard existed: settings.cfg held
## last_campaign="lifecycle_flush_t" (from tests/unit/test_write_safety.gd:133)
## and a recently_used_campaigns list of ten entries, every one of them a test or
## probe artefact. Deleting the save alone would not have cleared either key.
##
## ORDER ON RESTORE: the in-memory dict first, then the file bytes. GameState is
## an autoload, so restoring only the file leaves the polluted dict live in the
## process and the next save_settings() call writes it straight back.
##
## AN UNREADABLE DIRECTORY IS NOT AN EMPTY ONE (added 2026-09-21)
##
## The whole guard rests on one inference: a file that is here now and was not
## here at snapshot() time appeared during the test, so it is the test's to
## remove. That inference is only as good as the before-set, and _list_saves()
## used to return {} for two unrelated states -- the directory holds nothing, and
## DirAccess.open() returned null. With an empty before-set every surviving file
## looks new, so ONE transient open failure at snapshot() time turns the cleanup
## into a wipe of the user's entire save directory.
##
## That is not hypothetical and it needs no bug to reach: on 2026-09-21 a
## detection harness reverted the `before.has(name)` test out of this function
## and the loop deleted 238 real save files. An unreadable listing produces the
## same empty before-set from ordinary operation -- a permissions blip, or the
## Synology client holding the handle while it syncs, which this project runs
## inside.
##
## Hardening restore() cannot fix it, because on a genuinely fresh user:// an
## empty before-set is CORRECT and the cleanup must still run. So the fix is in
## the sensor: _list_saves() returns null when the directory exists and cannot be
## read, {} only when it is really empty, and snapshot() records which it got.
## _deletable() then answers "what may I remove" in one place, and its answer
## whenever it cannot be sure is NOTHING -- refusing to delete is recoverable and
## deleting is not.

const SAVES_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.cfg"


## Capture the pre-test state. Hand the result back to restore() unchanged.
static func snapshot() -> Dictionary:
	# null means the directory exists and could NOT be read -- see the header. It is
	# carried as a separate flag rather than a null `files` so restore() never has to
	# call .has() on a non-Dictionary, which aborts the function rather than failing.
	var listing = _list_saves()
	var snap := {
		"files": listing if listing is Dictionary else {},
		"files_listed": listing is Dictionary,
		"settings_bytes": null,
		"game_settings": null,
	}

	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			snap["settings_bytes"] = f.get_buffer(f.get_length())
			f.close()

	var gs: Node = _game_state()
	if gs and gs.get("game_settings") is Dictionary:
		snap["game_settings"] = (gs.get("game_settings") as Dictionary).duplicate(true)

	return snap


## Undo everything that appeared since snapshot(). Returns the number of files
## removed, so a caller can assert on it when that is the thing under test.
static func restore(snap: Dictionary) -> int:
	if snap == null or snap.is_empty():
		return 0

	# 1. In-memory settings first -- see the ORDER note above.
	var gs: Node = _game_state()
	if gs and snap.get("game_settings") != null:
		gs.set("game_settings", (snap["game_settings"] as Dictionary).duplicate(true))

	# 2. Files that were not there before.
	var removed := 0
	for name in _deletable(snap):
		if DirAccess.remove_absolute(SAVES_DIR + str(name)) == OK:
			removed += 1

	# 3. Settings file bytes, last, so nothing can re-pollute it.
	var bytes = snap.get("settings_bytes")
	if bytes == null:
		if FileAccess.file_exists(SETTINGS_PATH):
			DirAccess.remove_absolute(SETTINGS_PATH)
	else:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()

	return removed


## The files restore() is allowed to remove: what is here now, minus what was here
## before. Every path that cannot answer honestly returns an EMPTY list, because
## the two failure modes are not symmetrical -- leaving a test's litter behind is
## noticed and fixed, deleting a save the user made is not recoverable at all.
static func _deletable(snap: Dictionary) -> Array:
	if not bool(snap.get("files_listed", false)):
		# Either the snapshot could not read the directory, or it was hand-built
		# without saying whether it could. Both mean the before-set is unreliable,
		# and an unreliable before-set makes every file on disk look new.
		push_warning("SaveDirGuard: the pre-test listing of " + SAVES_DIR
			+ " is missing or was unreadable, so nothing can be shown to have appeared"
			+ " during the test. Removing nothing. Test litter may be left behind --"
			+ " that is the intended trade against deleting a real save.")
		return []

	var now = _list_saves()
	if not (now is Dictionary):
		return []  # unreadable NOW; nothing can be enumerated to delete anyway

	var before: Dictionary = snap.get("files", {})
	var out: Array = []
	for name in (now as Dictionary):
		if not before.has(name):
			out.append(name)
	return out


## Names present in user://saves/, as a Dictionary used as a set -- or NULL when the
## directory exists and could not be opened. The null is the whole point: returning
## {} there is indistinguishable from an empty directory, and that ambiguity is what
## lets a cleanup helper delete a save it never saw appear. A Dictionary rather than
## an Array because _deletable() does one lookup per surviving file and the
## directory holds a few hundred entries.
static func _list_saves() -> Variant:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return {}  # nothing there yet is a real, knowable empty
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return null
	var out := {}
	for name in dir.get_files():
		out[name] = true
	return out


## GameState is an autoload, so it is a tree node at an absolute path, NOT an
## Engine singleton. A RefCounted cannot call get_node_or_null() on itself --
## that errors and aborts the enclosing function rather than returning null --
## so reach the tree through the main loop, the pattern used at five sites in src/.
static func _game_state() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var root := (loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("/root/GameState")
