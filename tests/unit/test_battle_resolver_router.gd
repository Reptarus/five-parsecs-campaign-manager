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
