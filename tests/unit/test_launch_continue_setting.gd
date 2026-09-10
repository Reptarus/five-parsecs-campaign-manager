extends GdUnitTestSuite

## The launch-continue setting — a preference that is READ, not merely declared.
##
## ── THE DEFECT ───────────────────────────────────────────────────────────────
## `GameState.default_settings` declared `auto_load_last_campaign` (default false),
## `save_settings()` wrote it into user://settings.cfg on every save, and
## `_try_auto_load_last_campaign()` loaded a campaign at EVERY launch gating only on
## `last_campaign` being non-empty. The setting had **zero readers repo-wide**.
##
## That is not a cosmetic dead key. It is the root enabler of two measured defects:
##
##   * **T11-49** — `TacticalBattleUI` answered "is this campaign mine?" from the
##     ABSENCE of a campaign. Because one was always auto-loaded, the answer was
##     always yes, so opening the Battle Simulator and pressing Return ERASED the
##     campaign's in-progress battle (on device: `active_battle` True -> False,
##     81,221 -> 63,641 bytes).
##   * The cross-suite bleed that made `test_touch_scroll_sweep` fail only when it ran
##     AFTER the Tactics suites — those save a Tactics campaign, which sets
##     `last_campaign`, which the next process auto-loads, against which 5PFH-only
##     screens abort.
##
## ── WHAT THIS SUITE PINS ─────────────────────────────────────────────────────
## The two arms differ in EXACTLY ONE variable: the setting. Same save on disk, same
## `last_campaign`, same starting null campaign. A suite that only ran the "off" arm
## would pass against the broken code too (nothing to load), which is why the "on"
## arm is here — it proves the gate is a gate and not a wall.
##
## Detection proof, one arm at a time:
##   * delete the `continue_last_campaign_on_launch` guard at the top of
##     `_try_auto_load_last_campaign()` -> `test_off_leaves_no_campaign_loaded` FAILS
##   * delete the `LEGACY_SETTINGS_KEYS` erase in `load_settings()` ->
##     `test_the_retired_key_does_not_survive_a_load` FAILS
##
## ⚠ THIS SUITE TOUCHES REAL GLOBAL STATE — `user://settings.cfg`, `user://saves/`
## and `GameState.current_campaign`. Everything is captured in `before_test()` and put
## back in `after_test()`. A test that measures an autoload must pin its
## configuration, not inherit it; the `user://window.ini` bleed is the same lesson.

const CoreScript := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const PROBE_ID := "zz_launch_continue_probe"
const PROBE_PATH := "user://saves/zz_launch_continue_probe.save"

var _gs: Node = null
var _saved_settings: Dictionary = {}
var _saved_campaign: Variant = null


func before_test() -> void:
	_gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if _gs == null:
		return
	_saved_settings = (_gs.game_settings as Dictionary).duplicate(true)
	_saved_campaign = _gs.current_campaign

	# A real, loadable 5PFH save — `_try_auto_load_last_campaign()` routes through
	# `load_campaign_typed()`, so a hand-written fixture in a shape the app cannot
	# produce would prove nothing about the live path.
	var c = CoreScript.new()
	c.campaign_id = PROBE_ID
	c.campaign_name = "Launch Continue Probe"
	c.save_to_file(PROBE_PATH)


func after_test() -> void:
	if _gs == null:
		return
	_gs.current_campaign = _saved_campaign
	_gs.game_settings = _saved_settings.duplicate(true)
	_gs.save_settings()
	if FileAccess.file_exists(PROBE_PATH):
		DirAccess.remove_absolute(PROBE_PATH)


func _arm(enabled: bool) -> void:
	_gs.current_campaign = null
	_gs.game_settings["last_campaign"] = PROBE_ID
	_gs.game_settings["continue_last_campaign_on_launch"] = enabled


# ═════════════════════════════════ the gate, both arms

func test_on_restores_the_last_campaign() -> void:
	## THE PREMISE ARM. Without it, the "off" case below passes against a build that
	## cannot load anything at all, and the suite would be measuring nothing.
	if _gs == null:
		return
	_arm(true)

	_gs._try_auto_load_last_campaign()

	assert_object(_gs.current_campaign).override_failure_message(
		"With the setting ON and a real save at %s, launch restored nothing. "
		% PROBE_PATH
		+ "The off-arm below is only meaningful if this arm loads."
	).is_not_null()


func test_off_leaves_no_campaign_loaded() -> void:
	## ⭐ THE FIX. Everything is identical to the arm above except the setting.
	if _gs == null:
		return
	_arm(false)

	_gs._try_auto_load_last_campaign()

	assert_object(_gs.current_campaign).override_failure_message(
		"The setting was OFF and a campaign was loaded anyway. "
		+ "That is the state T11-49 mistook for 'this campaign is mine' and used to "
		+ "erase an in-progress battle from a standalone Battle Simulator session."
	).is_null()


func test_the_default_preserves_the_shipped_behaviour() -> void:
	## The key is new only in the sense that it is now read. Defaulting it to false
	## would have hidden Continue on every device that has ever run this app.
	if _gs == null:
		return
	assert_bool(bool(_gs.default_settings.get(
		"continue_last_campaign_on_launch", false))).override_failure_message(
		"continue_last_campaign_on_launch must default TRUE. MainMenu shows Continue "
		+ "only when GameState.has_active_campaign(), so a false default silently "
		+ "removes the main menu's primary action for every existing player."
	).is_true()


# ═════════════════════════════════ the retired key must not rot

func test_the_retired_key_does_not_survive_a_load() -> void:
	## ⚠ `load_settings()` copies EVERY key it finds in the file, and `save_settings()`
	## writes the whole dict straight back — so a key that reaches disk once is
	## immortal unless something erases it. That is exactly how
	## `auto_load_last_campaign` survived months with no reader.
	if _gs == null:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("settings", "auto_load_last_campaign", false)
	cfg.save("user://settings.cfg")

	_gs.load_settings()

	assert_bool(_gs.game_settings.has("auto_load_last_campaign")).override_failure_message(
		"A retired key survived load_settings(). save_settings() will now write it "
		+ "back out, and it will outlive everyone who remembers what it meant."
	).is_false()


func test_the_retired_key_is_not_written_back_out() -> void:
	if _gs == null:
		return
	_gs.game_settings["auto_load_last_campaign"] = false
	_gs.load_settings()
	_gs.save_settings()

	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	assert_bool(cfg.has_section_key("settings", "auto_load_last_campaign")) \
		.override_failure_message(
			"settings.cfg still carries the retired key after a load+save cycle."
		).is_false()


# ═════════════════════════════════ the accessors the Settings row uses

func test_the_accessors_round_trip() -> void:
	## `SettingsScreen` writes through these rather than poking `game_settings`,
	## because this one row does NOT live in SettingsManager's options.cfg — the value
	## must be readable from `GameState._init()`, before any autoload lookup is legal.
	if _gs == null:
		return
	_gs.set_continue_on_launch(false)
	assert_bool(_gs.is_continue_on_launch_enabled()).is_false()

	_gs.set_continue_on_launch(true)
	assert_bool(_gs.is_continue_on_launch_enabled()).is_true()

	# ...and it reached disk, not just memory. A preference that does not survive a
	# relaunch is the same as no preference for a setting consumed AT launch.
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	assert_bool(bool(cfg.get_value(
		"settings", "continue_last_campaign_on_launch", false))).override_failure_message(
		"set_continue_on_launch() did not persist. This setting is only ever read "
		+ "during boot, so an in-memory-only write can never be observed by anyone."
	).is_true()
