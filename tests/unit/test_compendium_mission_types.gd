extends GdUnitTestSuite
## Fixer's Guidebook mission types reach the table — Stealth, Street Fight, Salvage.
##
## THE DEFECT THIS PINS. Every layer of these three features already existed and
## already agreed with every other layer: the data files, the loaders in
## src/data/compendium_*.gd, the three generators, StealthResolver and
## SalvageResolver behind BattleResolverRouter, and the three battle panels that
## TacticalBattleUI instantiates and signal-wires. The generators stamp `type` as
## "stealth" / "street_fight" / "salvage" and TacticalBattleUI branches on
## exactly those strings.
##
## The chain was severed at ONE point: the only caller of all three generators
## was src/core/campaign/phases/WorldPhase.gd, a file with zero instantiations
## (WorldPhaseController preloads it and never uses it). Nothing produced a
## mission of those types, so the dispatch never matched, the panels never
## opened, and three purchasable features were unreachable in every campaign.
##
## That is the THIRD rule that same dead file has held hostage — CLAUDE.md
## records it holding the only callers of record_invaded_planet(), repair_hull()
## and the fuel-credits consumer.
##
## The chain has FOUR links and breaking any one of them re-silences all three
## features without failing anything else, so all four are pinned here:
##   1. the generator stamps `type`
##   2. the live World Phase calls the generator          (JobOfferComponent)
##   3. the campaign hand-off carries `type` through      (WorldPhaseController)
##   4. the battle UI dispatches on that exact string     (TacticalBattleUI)
##
## Links 2-4 are asserted against the SOURCE because they are wiring, not
## behaviour: there is no return value to check, only whether the call exists.
## A source assertion is the honest instrument for "is this still connected".
##
## gdUnit4 v6.0.3 compatible.

const StealthGen = preload("res://src/core/mission/StealthMissionGenerator.gd")
const StreetGen = preload("res://src/core/mission/StreetFightGenerator.gd")
const SalvageGen = preload("res://src/core/mission/SalvageJobGenerator.gd")

const TYPES := ["stealth", "street_fight", "salvage"]

const JOB_OFFER_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const WORLD_CTRL_SRC := "res://src/ui/screens/world/WorldPhaseController.gd"
const BATTLE_UI_SRC := "res://src/ui/screens/battle/TacticalBattleUI.gd"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


const _FLAGS := ["STEALTH_MISSIONS", "STREET_FIGHTS", "SALVAGE_JOBS"]
var _saved_flags: Dictionary = {}


## DLCManager is an AUTOLOAD, so a flag flipped here stays flipped for every
## suite that runs after this one in the same process. Leaving them on made
## test_job_offer_component fail four cases that pass in isolation — a test
## polluting a sibling suite is worse than the bug it was written to catch.
func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_flags.clear()
	for name in _FLAGS:
		_saved_flags[name] = dlc.is_feature_enabled(dlc.ContentFlag.get(name))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	for name in _saved_flags:
		dlc.set_feature_enabled(dlc.ContentFlag.get(name), bool(_saved_flags[name]))


# --- Link 1: the generators stamp the dispatch key ----------------------------

func test_each_generator_stamps_its_dispatch_type() -> void:
	var dlc := _dlc()
	if dlc == null:
		return  # no autoload in this context; links 2-4 still cover the wiring
	for flag_name in ["STEALTH_MISSIONS", "STREET_FIGHTS", "SALVAGE_JOBS"]:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), true)

	var stealth: Dictionary = StealthGen.generate_stealth_mission(6)
	var street: Dictionary = StreetGen.generate_street_fight()
	var salvage: Dictionary = SalvageGen.generate_salvage_job(6)

	# A generator returns {} when its pack is not owned. If the flag is on and it
	# still returns nothing, the feature is broken upstream of the wiring.
	assert_bool(stealth.is_empty()).override_failure_message(
		"STEALTH_MISSIONS is enabled and the generator produced nothing").is_false()
	assert_str(str(stealth.get("type", ""))).is_equal("stealth")
	assert_str(str(street.get("type", ""))).is_equal("street_fight")
	assert_str(str(salvage.get("type", ""))).is_equal("salvage")

	# The panels read `objective` as a DICTIONARY. This is why the campaign
	# hand-off cannot merge the generator payload into its Patron-shaped literal,
	# where `objective` is a plain String.
	assert_bool(stealth.get("objective", null) is Dictionary).override_failure_message(
		"stealth objective must stay a Dictionary — the panel reads sub-keys off it"
	).is_true()
	# Compendium p.124: initial sentries = campaign_crew_size + 1.
	assert_int(int(stealth.get("sentry_count", 0))).is_equal(7)


func test_the_generators_self_gate_so_callers_need_no_flag_check() -> void:
	# The wiring calls all three unconditionally. That is only correct because
	# each returns {} when its own ContentFlag is off — if that stopped being
	# true, unowned content would appear in the job list.
	var dlc := _dlc()
	if dlc == null:
		return
	for flag_name in ["STEALTH_MISSIONS", "STREET_FIGHTS", "SALVAGE_JOBS"]:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), false)

	assert_bool(StealthGen.generate_stealth_mission(6).is_empty()).override_failure_message(
		"stealth mission generated without the pack — unowned content is leaking"
	).is_true()
	assert_bool(StreetGen.generate_street_fight().is_empty()).is_true()
	assert_bool(SalvageGen.generate_salvage_job(6).is_empty()).is_true()
	# after_test() restores the original flag values.


# --- Link 2: the LIVE World Phase calls them ----------------------------------

func test_the_live_job_offer_component_calls_all_three_generators() -> void:
	# Before the fix the only caller was phases/WorldPhase.gd, which nothing
	# instantiates. JobOfferComponent is the component the live World Phase
	# actually builds, so the call has to be here.
	var src: String = _src(JOB_OFFER_SRC)
	for gen in ["StealthMissionGenerator", "StreetFightGenerator", "SalvageJobGenerator"]:
		assert_bool(src.contains(gen)).override_failure_message(
			("%s is not referenced by the LIVE JobOfferComponent — if its only "
			+ "caller is phases/WorldPhase.gd again, the feature is dead") % gen
		).is_true()
	assert_bool(src.contains("_generate_compendium_missions")).is_true()


func test_compendium_missions_are_not_written_into_the_persisted_offer_store() -> void:
	# They are derived fresh each turn like the Quest option. Persisting them
	# would duplicate the option on every revisit and give them a p.83 Time
	# Frame they do not have.
	var src: String = _src(JOB_OFFER_SRC)
	var store_idx: int = src.find("_store_offers(patron_offers)")
	var gen_idx: int = src.find("all_jobs.append_array(_generate_compendium_missions())")
	assert_int(store_idx).override_failure_message("_store_offers call not found").is_greater(0)
	assert_int(gen_idx).override_failure_message(
		"compendium missions are not appended to the display list").is_greater(0)
	assert_int(gen_idx).override_failure_message(
		"compendium missions must be generated AFTER the offers are persisted, "
		+ "or they end up in the store"
	).is_greater(store_idx)


# --- Link 3: the campaign hand-off carries the key through --------------------

func test_the_handoff_carries_type_and_the_generator_payload() -> void:
	# WorldPhaseController flattens an accepted job into a Patron-shaped literal
	# of ~20 named keys. `type` was not one of them, so the dispatch could never
	# match even once the missions were offered — the same omission this hand-off
	# already made for `conditions`.
	var src: String = _src(WORLD_CTRL_SRC)
	assert_bool(src.contains("mission_dict[\"type\"] = compendium_type")).override_failure_message(
		"the hand-off drops `type`; TacticalBattleUI will never open the panel"
	).is_true()
	assert_bool(src.contains("mission_dict[\"compendium_mission\"]")).override_failure_message(
		"the hand-off drops the generator payload; the panel gets a String "
		+ "`objective` where it expects a Dictionary"
	).is_true()
	for t in TYPES:
		assert_bool(src.contains("\"%s\"" % t)).override_failure_message(
			"hand-off does not list mission type '%s'" % t).is_true()


# --- Link 4: the battle UI dispatches on exactly those strings ----------------

func test_the_battle_ui_dispatches_on_the_generator_type_strings() -> void:
	var src: String = _src(BATTLE_UI_SRC)
	for t in TYPES:
		assert_bool(src.contains("mission_type == \"%s\"" % t)).override_failure_message(
			("TacticalBattleUI does not dispatch on '%s' — the generator stamps it, "
			+ "so a rename on either side silently disables the feature") % t
		).is_true()
	assert_bool(src.contains("compendium_mission")).override_failure_message(
		"the battle UI passes the flattened literal to the panels instead of the "
		+ "generator payload"
	).is_true()
