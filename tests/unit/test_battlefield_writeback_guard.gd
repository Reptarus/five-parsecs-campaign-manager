extends GdUnitTestSuite
## T11-17, second half — the WRITE-BACK must refuse to clobber a saved table.
##
## GameState.get_battlefield_data()'s owner fallback (test_battlefield_persistence.gd)
## stops the cache going empty. This is the belt to that braces: even if something
## does empty it, _persist_battlefield_contract() must not persist a freshly-generated
## table over one the campaign already holds. Either guard alone would have saved the
## player's terrain on device; both are cheap.
##
## The full .tscn is instantiated because the guard lives inside an 8,000-line method
## on that screen — the same thing tests/tools/verify_battle_ui.gd does. A stub would
## test a reimplementation of the guard rather than the guard.
##
## ⚠ EXPECTED: gdUnit reports "3 possible orphan nodes" per case. MEASURED as
## pre-existing, not introduced here — a bare instantiate + free of
## TacticalBattleUI.tscn with no guard code involved at all leaks exactly the same 3.
## They are warnings, not failures. Do not "fix" this suite to silence them; if the
## screen is ever cleaned up, the number here drops on its own.

const CampaignCoreClass = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")
const UI_PATH := "res://src/ui/screens/battle/TacticalBattleUI.tscn"

var _prior_campaign: Resource = null
var _prior_bf: Dictionary = {}


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	_prior_bf = GameState.get_battlefield_data()
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.clear_battlefield_data()


func after_test() -> void:
	GameState.current_campaign = _prior_campaign
	if _prior_bf.is_empty():
		GameState.clear_battlefield_data()
	else:
		GameState.set_battlefield_data(_prior_bf)


func _saved_table() -> Dictionary:
	return {
		"schema_version": 1,
		"seed": 4055150519,          # the seed the device walk recorded BEFORE
		"theme": "wilderness",
		"table_size_ft": 3.0,
		"world_traits": [],
		"deployment_condition": {},
		"sectors": [
			{"label": "A1", "features": ["LARGE: Rocky outcrop"]},
			{"label": "C3", "features": ["SMALL: Scrub"]},
		],
	}


func _regenerated() -> Dictionary:
	return {
		"seed": 341922859,           # ...and the seed it came back with AFTER
		"theme_name": "Wilderness",
		"sectors": [{"label": "B2", "features": ["SMALL: Different"]}],
		"combat_notes": [],
	}


func _make_ui() -> Node:
	var packed: PackedScene = load(UI_PATH)
	assert_object(packed).override_failure_message(
		"TacticalBattleUI.tscn failed to load — this suite cannot run."
	).is_not_null()
	var ui: Node = auto_free(packed.instantiate())
	add_child(ui)
	await await_idle_frame()
	# Campaign path, not standalone: _is_standalone_battle() early-returns before the
	# guard this suite exists to test, so every ownership signal must be cleared or the
	# suite is vacuously green.
	#
	# ⚠ THERE ARE NOW THREE SIGNALS (T11-49, 2026-09-08). This block used to clear
	# only `_battle_mode_id` and rely on before_test() installing a campaign for the
	# second. The third is `_standalone_declared`, and a bare instantiate SETS IT: the
	# screen is not under a `PhaseContainer` ancestor and initialize_battle() is never
	# called here, so the deferred `_check_standalone_mode()` correctly concludes this
	# instance is standalone and says so. That is right for production and wrong for
	# this fixture, which is modelling the campaign path.
	ui._battle_mode_id = ""
	ui._standalone_declared = false
	# INSTRUMENT THE PREMISE. Clearing the signals by hand is only correct while the
	# list is complete; a fourth signal would silently reintroduce the early return and
	# this suite would report a guard regression that is really a fixture gap. Assert
	# the state the cases actually depend on, once, here.
	assert_bool(ui._is_standalone_battle()).override_failure_message(
		"Fixture premise broken: this screen still reports STANDALONE after clearing "
		+ "every known ownership signal, so _persist_battlefield_contract() will "
		+ "early-return and every case below would be testing nothing. A new signal "
		+ "was probably added to _is_standalone_battle() - clear it here too."
	).is_false()
	return ui


func _persist(ui: Node, data: Dictionary) -> void:
	ui._persist_battlefield_contract(data, [], [], {}, [], 3.0, "", "", 0)


func test_a_resume_regeneration_does_not_overwrite_the_saved_table() -> void:
	var ui := await _make_ui()
	GameState.set_battlefield_data(_saved_table())

	_persist(ui, _regenerated())

	var owned: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_int(int(owned.get("seed", 0))).override_failure_message(
		"The saved table (seed 4055150519) was replaced by a regenerated one. This "
		+ "is the device defect: the terrain the player physically laid out was "
		+ "overwritten by the resume-time fallback and then saved."
	).is_equal(4055150519)
	assert_int((owned.get("sectors", []) as Array).size()).is_equal(2)


## The player pressing "Regenerate Terrain Layout" must still work — a guard that
## also blocks the deliberate path trades one bug for another.
func test_an_explicit_regenerate_still_replaces_the_table() -> void:
	var ui := await _make_ui()
	GameState.set_battlefield_data(_saved_table())
	ui._regenerate_requested = true

	_persist(ui, _regenerated())

	var owned: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_int(int(owned.get("seed", 0))).override_failure_message(
		"Regenerate Terrain Layout no longer replaces the table."
	).is_equal(341922859)


## One-shot: the flag must not stay armed and wave through the NEXT unrequested write.
func test_the_regenerate_permission_is_consumed_once() -> void:
	var ui := await _make_ui()
	GameState.set_battlefield_data(_saved_table())
	ui._regenerate_requested = true
	_persist(ui, _regenerated())          # allowed, consumes the flag

	var second := _regenerated()
	second["seed"] = 777000111
	_persist(ui, second)                   # must be refused

	var owned: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_int(int(owned.get("seed", 0))).override_failure_message(
		"A single Regenerate press permitted a SECOND unrequested overwrite."
	).is_equal(341922859)


## First write of a battle: nothing saved yet, so there is nothing to protect and the
## contract must be stored. A guard that also blocked this would leave every battle
## with no persisted table at all.
func test_the_first_write_of_a_battle_is_stored_normally() -> void:
	var ui := await _make_ui()
	_persist(ui, _regenerated())

	var owned: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_int(int(owned.get("seed", 0))).override_failure_message(
		"The first persist of a battle was refused — no table would ever be saved."
	).is_equal(341922859)


## Re-persisting the SAME seed (marker moves, sector re-rolls) must go through: that
## is the normal in-battle update path and the guard keys on a seed CHANGE.
func test_re_persisting_the_same_seed_is_allowed() -> void:
	var ui := await _make_ui()
	GameState.set_battlefield_data(_saved_table())

	var same := _saved_table()
	same["combat_notes"] = ["updated in battle"]
	_persist(ui, same)

	var owned: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_int(int(owned.get("seed", 0))).is_equal(4055150519)
	assert_array(owned.get("combat_notes", [])).override_failure_message(
		"An in-battle update carrying the SAME seed was refused, so marker moves "
		+ "and sector re-rolls would stop persisting."
	).contains(["updated in battle"])


## The Regenerate permission is a ONE-SHOT, and it used to leak past two exits.
##
## `_persist_battlefield_contract()` consumes `_regenerate_requested`, but the
## standalone guard returns ABOVE that line, and `_reset_battle_state()` never cleared
## it either. This screen is REUSED between battles, so a Regenerate pressed during a
## standalone battle stayed armed into the next one — and that flag is the single thing
## that lets a differently-seeded table overwrite a saved one, which is the T11-17
## defect this whole suite exists to prevent.
func test_a_standalone_regenerate_does_not_stay_armed_for_the_next_battle() -> void:
	var ui := await _make_ui()

	# Arm the permission, then take the STANDALONE exit, which returns before the
	# consume. A non-empty _battle_mode_id is what makes _is_standalone_battle() true.
	ui._regenerate_requested = true
	ui._battle_mode_id = "bug_hunt"
	_persist(ui, _regenerated())

	assert_bool(ui._regenerate_requested).override_failure_message(
		"The Regenerate permission survived the standalone early-return, so the NEXT "
		+ "battle on this reused screen would be allowed to overwrite a saved table."
	).is_false()


## The other exit: a new battle must never inherit the previous battle's permission.
func test_resetting_the_screen_disarms_the_regenerate_permission() -> void:
	var ui := await _make_ui()
	ui._regenerate_requested = true

	ui._reset_battle_state()

	assert_bool(ui._regenerate_requested).override_failure_message(
		"_reset_battle_state() runs on every new battle and must disarm the one-shot; "
		+ "otherwise battle 2 inherits battle 1's permission to regenerate."
	).is_false()
