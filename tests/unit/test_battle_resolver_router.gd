extends GdUnitTestSuite
## Wave 1.2 — BattleResolverRouter.use_no_minis() decision-logic tests.
##
## The router is the single chokepoint both auto-resolve call sites
## (CampaignTurnController, TacticalBattleUI) share, so the No-Minis / Standard /
## Salvage-fallback decision can't drift between them. Before consolidation,
## TacticalBattleUI was MISSING the Salvage fallback that CampaignTurnController
## had — test_salvage_* below pins that fix.

const Router = preload("res://src/core/battle/BattleResolverRouter.gd")


## Minimal DLCManager stand-in: exposes ContentFlag.NO_MINIS_COMBAT and a
## configurable is_feature_enabled(), mirroring the real autoload's surface that
## use_no_minis() touches. RefCounted (not Node) so it auto-frees at scope exit
## with no orphan leaks — use_no_minis only needs has_method/is_feature_enabled/enum.
func _mock_dlc(no_minis_on: bool) -> Object:
	var s := GDScript.new()
	s.source_code = "extends RefCounted\n" \
		+ "enum ContentFlag { NO_MINIS_COMBAT }\n" \
		+ "var enabled := %s\n" % ("true" if no_minis_on else "false") \
		+ "func is_feature_enabled(_flag) -> bool:\n\treturn enabled\n"
	@warning_ignore("return_value_discarded")
	s.reload()
	return s.new()


func test_null_dlc_is_never_no_minis() -> void:
	# Headless/test contexts with no DLCManager must fall back to the standard resolver.
	assert_bool(Router.use_no_minis(null, "", "")).is_false()


func test_dlc_off_is_never_no_minis() -> void:
	assert_bool(Router.use_no_minis(_mock_dlc(false), "", "")).is_false()


func test_dlc_on_standard_nonsalvage_is_no_minis() -> void:
	assert_bool(Router.use_no_minis(_mock_dlc(true), "", "patrol")).is_true()
	# "standard" is treated identically to "".
	assert_bool(Router.use_no_minis(_mock_dlc(true), "standard", "patrol")).is_true()


func test_non_standard_battle_mode_is_never_no_minis() -> void:
	# Shared UI: Bug Hunt / Planetfall / Tactics keep the generic resolver.
	assert_bool(Router.use_no_minis(_mock_dlc(true), "bug_hunt", "patrol")).is_false()
	assert_bool(Router.use_no_minis(_mock_dlc(true), "planetfall", "patrol")).is_false()
	assert_bool(Router.use_no_minis(_mock_dlc(true), "tactics", "patrol")).is_false()


func test_salvage_mission_falls_back_to_standard() -> void:
	# Compendium p.116: No-Minis "is not easily usable with the Salvage mission type".
	# Bug-pin: TacticalBattleUI's auto-resolve previously lacked this fallback.
	assert_bool(Router.use_no_minis(_mock_dlc(true), "", "salvage")).is_false()
	# Case-insensitive substring match (mission types vary in casing/wording).
	assert_bool(Router.use_no_minis(_mock_dlc(true), "", "Salvage Operation")).is_false()
	assert_bool(Router.use_no_minis(_mock_dlc(true), "standard", "DERELICT_SALVAGE")).is_false()

# ---------------------------------------------------------------------------
# defeated_enemies derivation.
#
# Every resolver reports `enemies_defeated` as a COUNT and returns
# `enemy_units_final`, but NONE produced `defeated_enemies` — the LIST that
# PostBattlePhase:151 reads and RivalPatronResolver iterates for `is_rival`.
# Empty list => the Core Rules p.86 rival-removal roll never ran (a beaten Rival
# survived and returned next turn) AND `fought_existing_rival` stayed false, so
# the "gain a new rival on a 1" branch fired for the battle you just won against
# your existing rival. Derived at the routing chokepoint so both auto-resolve
# callers get it.
# ---------------------------------------------------------------------------

const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")

func _crew(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"character_id": "c%d" % i, "character_name": "Crew %d" % i,
			"combat": 1, "reactions": 2, "toughness": 4, "speed": 4,
			"weapons": [{"name": "Handgun", "range": 12, "shots": 1, "damage": 0}]})
	return out

func _enemies(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"name": "Raider %d" % i, "type": "Pirates", "combat": 0,
			"toughness": 3, "speed": 4, "special_rules": [],
			"weapons": [{"name": "Scrap Pistol", "range": 9, "shots": 1, "damage": 0}]})
	return out

func test_router_derives_defeated_enemies_from_unit_end_state() -> void:
	var result: Dictionary = Router.resolve(
		_crew(4), _enemies(3), {}, {}, func() -> int: return randi_range(1, 6), null)
	assert_bool(result.has("defeated_enemies")).is_true()
	assert_bool(result["defeated_enemies"] is Array).is_true()
	# The derived list must agree with the count the resolver reported.
	assert_int((result["defeated_enemies"] as Array).size()).is_equal(
		int(result.get("enemies_defeated", -1)))

func test_derived_list_only_contains_dead_units() -> void:
	var result: Dictionary = Router.resolve(
		_crew(4), _enemies(3), {}, {}, func() -> int: return randi_range(1, 6), null)
	for unit in result["defeated_enemies"]:
		assert_bool(bool(unit.get("is_alive", true))).is_false()

func test_add_only_never_overwrites_a_producer_list() -> void:
	var pre := {"enemy_units_final": [{"is_alive": false}], "defeated_enemies": [{"name": "Kept"}]}
	var out: Dictionary = Router._with_defeated_enemies(pre)
	assert_int((out["defeated_enemies"] as Array).size()).is_equal(1)
	assert_str(str(out["defeated_enemies"][0]["name"])).is_equal("Kept")

func test_rival_removal_roll_can_now_be_reached() -> void:
	# THE JOIN: router derives the list, normalizer stamps is_rival onto it from
	# the mission's rival_id, RivalPatronResolver's loop finally has something to
	# iterate. Any empty link here restores the silent no-op.
	var resolved: Dictionary = Router.resolve(
		_crew(5), _enemies(2), {}, {}, func() -> int: return 6, null)
	var normalized: Dictionary = Normalizer.normalize(resolved, {"rival_id": "riv_1"}, 3)
	var saw_rival := false
	for enemy in normalized.get("defeated_enemies", []):
		if enemy.get("is_rival", false) and str(enemy.get("rival_id", "")) == "riv_1":
			saw_rival = true
	assert_bool(saw_rival).is_true()
