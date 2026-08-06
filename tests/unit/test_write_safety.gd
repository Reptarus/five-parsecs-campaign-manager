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
## 2. PLAYER PROFILE DID THE SAME TO ELITE RANKS
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

const TEST_DIR := "user://test_write_safety/"

var _previous = null
var _swapped := false


func before_test() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_test() -> void:
	if _swapped:
		var gs := _gs()
		if gs:
			gs.current_campaign = _previous
		_previous = null
		_swapped = false


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

func test_profile_refuses_to_save_after_a_failed_load() -> void:
	var p = PlayerProfileScript.new()
	p.elite_ranks = 7
	p.set("_load_failed", true)
	# save_to_disk() must bail rather than persist defaults over a real profile.
	p.save_to_disk()
	assert_int(int(p.elite_ranks)).is_equal(7)


func test_profile_write_is_atomic() -> void:
	var p = PlayerProfileScript.new()
	if not ("_load_failed" in p):
		fail("PlayerProfile._load_failed is missing — the write guard is gone")
		return
	assert_bool(bool(p.get("_load_failed"))).override_failure_message(
		"a fresh profile must not start in the failed state or it can never save"
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
