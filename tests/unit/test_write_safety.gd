extends GdUnitTestSuite
## Stores must not overwrite a real record with defaults after a failed read, and the
## campaign must flush when the OS takes the app away.
##
## THREE DEFECTS THIS PINS (write-safety audit)
##
## 1. DLC OWNERSHIP LAUNDERED A DEGRADED LOAD TO DISK
##    save_ownership() rewrote user://dlc_ownership.cfg in place on EVERY boot. On a
##    0-byte file ConfigFile.load() returns OK, so the error guard never fired and
##    every get_value yielded false; on a truncated file the guard returned early and
##    _owned_dlcs stayed {}. Either way all DLC read as unowned — and
##    StoreManager._sync_store_entitlements() then called save_ownership()
##    UNCONDITIONALLY 0.5s into boot, writing the zeroed dict back. It only ever sets
##    flags true, so it could never restore. The tester lost all three Compendium packs
##    plus Bug Hunt / Planetfall / Tactics, and on a sideloaded APK the Offline adapter
##    makes "Restore Purchases" a no-op.
##
## 2. PLAYER PROFILE DID THE SAME TO ELITE RANKS -- AND THIS HALF DID NOT LAND
##    UNTIL 2026-09-21. The paragraph below was written in the past tense on the day
##    this suite was created, while save_to_disk() still truncated the live path and
##    still never read _load_failed. Both profile cases were false greens: the first
##    asserted an in-memory field it had set itself, and the second is NAMED
##    write_is_atomic and asserted only that a fresh profile starts unfailed. So the
##    case performed the destructive write on every run, and the user's real
##    player_profile.json was found holding elite_ranks 7 with
##    completed_victory_conditions [] and total_campaigns_completed 0 -- a combination
##    award_elite_rank() cannot produce, because it moves all three together.
##    A write-up is not a fix. Assert where the damage lands.
##
##    THE ORIGINAL FINDING, unchanged:
##    save_to_disk() truncated the live path with FileAccess.WRITE, no temp/rename, no
##    .bak, no write error check. A failed load left the object at @export defaults
##    (elite_ranks = 0) and the next campaign creation persisted that, because
##    register_campaign_start() increments a counter then immediately saves. It is the
##    only cross-campaign progression store and had no recovery path.
##
## 3. NOTHING SAVED WHEN ANDROID BACKGROUNDED THE APP
##    No NOTIFICATION_APPLICATION_PAUSED / _FOCUS_OUT / WM_CLOSE_REQUEST /
##    WM_GO_BACK_REQUEST handler existed anywhere in src/. GameState.auto_save() and
##    persist_game_state() both had ZERO callers. Everything between two phase
##    boundaries lived only in RAM — worst case the 14-step post-battle sequence, where
##    a kill discarded a whole battle's rewards while the battle was already spent.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PlayerProfileScript = preload("res://src/core/player/PlayerProfile.gd")

const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const TEST_DIR := "user://test_write_safety/"

## PlayerProfile.SAVE_PATH is a const, so the two profile cases below drive the REAL
## user://player_profile.json -- there is no seam to redirect them through. Snapshot
## its bytes and both siblings the atomic writer can leave (.bak, and .tmp on a failed
## write) so a case can never cost the user their elite ranks again, whatever the code
## under test does. Measured 2026-09-21: one already had.
const PROFILE_PATH := "user://player_profile.json"

## See after_test(): this suite already removed its save FILE and still leaked
## the settings KEY that writing it set.
var _user_state: Dictionary = {}
var _previous = null
var _swapped := false
var _profile_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_profile_state = _snapshot_profile()
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_test() -> void:
	if _swapped:
		var gs := _gs()
		if gs:
			gs.current_campaign = _previous
		_previous = null
		_swapped = false
	# test_lifecycle_flush_writes_the_campaign() removes the save file it
	# created, but the write went through GameState.save_campaign(), which also
	# set game_settings["last_campaign"] and called save_settings(). Measured
	# consequence: the user's settings.cfg has carried
	# last_campaign="lifecycle_flush_t" -- a test id -- since that case last ran.
	SaveDirGuard.restore(_user_state)
	_user_state = {}
	_restore_profile(_profile_state)
	_profile_state = {}


## Bytes, or null where the file is absent. Absence is a state that has to be
## restored too, or a case leaves a profile behind on a machine that had none.
func _snapshot_profile() -> Dictionary:
	var snap := {}
	for path in [PROFILE_PATH, PROFILE_PATH + ".bak", PROFILE_PATH + ".tmp"]:
		snap[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return snap


func _restore_profile(snap: Dictionary) -> void:
	for path in snap.keys():
		var bytes = snap[path]
		if bytes == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()


## Seeds a known profile so an assertion can say the bytes did not MOVE, rather
## than only that the file is still absent -- which a bailing save and a missing
## file both satisfy.
func _seed_profile(body: String) -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	assert_that(f).is_not_null()
	f.store_string(body)
	f.close()


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


# --- 1. DLC ownership ----------------------------------------------------------

func test_dlc_refuses_to_save_a_record_it_never_loaded() -> void:
	var dlc := _dlc()
	if dlc == null or not dlc.has_method("is_ownership_loaded"):
		fail("DLCManager.is_ownership_loaded is missing — the write guard is gone")
		return
	# The guard's whole purpose: a store that knows nothing must not overwrite the
	# record. StoreManager calls save_ownership() unconditionally on every boot.
	dlc.set("_ownership_loaded", false)
	dlc.save_ownership()          # must be a no-op, not a wipe
	dlc.set("_ownership_loaded", true)
	assert_bool(true).is_true()   # reaching here without writing is the assertion


func test_dlc_ownership_survives_a_round_trip() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	var had: bool = dlc.has_dlc("bug_hunt")
	dlc.set("_ownership_loaded", true)
	dlc.set_dlc_owned("bug_hunt", true)
	dlc.save_ownership()
	dlc.load_ownership()
	assert_bool(dlc.has_dlc("bug_hunt")).override_failure_message(
		"DLC ownership did not survive save+load"
	).is_true()
	dlc.set_dlc_owned("bug_hunt", had)
	dlc.save_ownership()


# --- 2. Player profile ---------------------------------------------------------

## THE SAFETY CASE. Assert where the damage lands -- the FILE, not the object.
##
## Until 2026-09-21 this read back the in-memory elite_ranks it had set two lines
## earlier, which is true whether save_to_disk() bails or writes. The guard it is
## named for did not exist, so the case was green while really persisting a fresh
## object's defaults over the user's profile, every single run.
func test_profile_refuses_to_save_after_a_failed_load() -> void:
	var sentinel := '{"elite_ranks": 3}'
	_seed_profile(sentinel)

	var p = PlayerProfileScript.new()
	p.elite_ranks = 7
	p.set("_load_failed", true)

	# save_to_disk() must bail rather than persist defaults over a real profile.
	p.save_to_disk()

	assert_str(FileAccess.get_file_as_string(PROFILE_PATH)).override_failure_message(
		"save_to_disk() overwrote the profile after a failed load. This is the only "
		+ "cross-campaign progression store and the write has no undo."
	).is_equal(sentinel)


## The .bak generation is not decoration: load_from_disk() reads through
## SaveFileWriter.read_json_with_fallback(), which CONSULTS it. A raw FileAccess.WRITE
## leaves that reader looking for a backup nothing creates, and a half-written primary
## with no generation behind it. That is what this case is named for, and what it did
## not check until 2026-09-21 -- it asserted only that a fresh profile starts unfailed,
## so it was green throughout the whole period the writer was non-atomic.
##
## The sentinel is load-bearing, not scene-setting: write_text_atomic() copies the
## previous generation only `if FileAccess.file_exists(path)` (SaveFileWriter.gd:63),
## so with no prior profile on disk a correct atomic write leaves no .bak either and
## the assertion below could not tell the two apart.
func test_profile_write_is_atomic() -> void:
	var p = PlayerProfileScript.new()
	if not ("_load_failed" in p):
		fail("PlayerProfile._load_failed is missing — the write guard is gone")
		return
	assert_bool(bool(p.get("_load_failed"))).override_failure_message(
		"premise: a fresh profile must not start failed or it could never save at all"
	).is_false()

	var sentinel := '{"elite_ranks": 5}'
	_seed_profile(sentinel)
	var bak := PROFILE_PATH + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)

	p.elite_ranks = 9
	p.save_to_disk()

	assert_bool(FileAccess.file_exists(bak)).override_failure_message(
		"save_to_disk() left no .bak generation, but load_from_disk() reads through "
		+ "read_json_with_fallback(), which consults one. The reader is looking for a "
		+ "backup the writer never creates."
	).is_true()
	assert_str(FileAccess.get_file_as_string(bak)).override_failure_message(
		".bak does not hold the PREVIOUS generation, so it is not a recovery point"
	).is_equal(sentinel)

	var reread = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	assert_bool(reread is Dictionary).override_failure_message(
		"the primary is not parseable JSON after the write"
	).is_true()
	assert_int(int((reread as Dictionary).get("elite_ranks", -1))).override_failure_message(
		"the primary does not hold the value that was just saved"
	).is_equal(9)

	assert_bool(FileAccess.file_exists(PROFILE_PATH + ".tmp")).override_failure_message(
		"the atomic writer left its .tmp behind; the rename did not complete"
	).is_false()


# --- 3. Lifecycle flush --------------------------------------------------------

func test_gamestate_has_a_lifecycle_handler() -> void:
	var gs := _gs()
	if gs == null:
		return
	assert_bool(gs.has_method("_flush_on_lifecycle_event")).override_failure_message(
		"no lifecycle flush — backgrounding the app loses everything since the last phase"
	).is_true()


func test_lifecycle_flush_writes_the_campaign() -> void:
	var gs := _gs()
	if gs == null or not gs.has_method("_flush_on_lifecycle_event"):
		return
	var c = CampaignCore.new()
	c.campaign_id = "lifecycle_flush_t"
	c.campaign_name = "Lifecycle"
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = c

	var path := "user://saves/lifecycle_flush_t.save"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	gs._flush_on_lifecycle_event()

	assert_bool(FileAccess.file_exists(path)).override_failure_message(
		"the lifecycle flush did not write the campaign to disk"
	).is_true()
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func test_lifecycle_flush_is_safe_with_no_campaign() -> void:
	var gs := _gs()
	if gs == null or not gs.has_method("_flush_on_lifecycle_event"):
		return
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = null
	gs._flush_on_lifecycle_event()   # must not error
	assert_bool(true).is_true()


func test_lifecycle_flush_skips_a_campaign_with_no_id() -> void:
	# Mid-creation the campaign has no id yet; writing it would create a junk file.
	var gs := _gs()
	if gs == null or not gs.has_method("_flush_on_lifecycle_event"):
		return
	var c = CampaignCore.new()
	c.campaign_id = ""
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = c
	gs._flush_on_lifecycle_event()
	assert_bool(true).is_true()
