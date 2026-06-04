extends GdUnitTestSuite
## Tests for the Planetfall transfer leg (P1) of the cross-mode framework.
##
## Covers the book-faithful import conversions (Planetfall pp.26-27), the
## corrected end-of-campaign export matrix (pp.165-166), the lossless import->
## muster-out round-trip via the embedded snapshot, and reward-suppression when
## a colonist is routed to a non-5PFH mode.

const CharacterTransferService := preload("res://src/core/character/CharacterTransferService.gd")

var _svc


func before_test() -> void:
	_svc = CharacterTransferService.new()


func _make_5pfh_char() -> Dictionary:
	return {
		"id": "char_pf_1", "character_id": "char_pf_1",
		"name": "Vera Kade", "character_name": "Vera Kade",
		"game_mode": "standard", "status": "active",
		"combat": 2, "reactions": 3, "toughness": 4, "speed": 5,
		"savvy": 1, "tech": 0, "luck": 3, "xp": 12,
		"background": "Soldier", "is_captain": false,
		"equipment": [{"id": "hand_laser", "name": "Hand Laser"}]
	}


func _make_planetfall_native() -> Dictionary:
	# A colonist born in Planetfall (no embedded snapshot).
	return {
		"id": "pf_native_1", "name": "Colonist Bram", "class": "trooper",
		"combat_skill": 1, "reactions": 2, "toughness": 4, "speed": 4,
		"savvy": 2, "xp": 6, "kp": 1, "loyalty": "loyal"
	}


# ============================================================================
# Import conversions (Planetfall pp.26-27)
# ============================================================================

func test_import_5pfh_luck_becomes_kill_points() -> void:
	var pf: Dictionary = _svc.convert_to_planetfall(_make_5pfh_char(), "5pfh")
	# 3 Luck -> 3 Kill Points (1 KP per Luck point).
	assert_that(int(pf.get("kp", -1))).is_equal(3)
	assert_that(int(pf.get("combat_skill", -1))).is_equal(2)
	assert_that(str(pf.get("loyalty", ""))).is_equal("loyal")


func test_import_bug_hunt_tech_becomes_savvy() -> void:
	var bh := {
		"id": "bh_1", "name": "Trooper Vance",
		"combat_skill": 1, "reactions": 2, "toughness": 4, "speed": 4,
		"savvy": 1, "tech": 4, "kp": 0
	}
	var pf: Dictionary = _svc.convert_to_planetfall(bh, "bug_hunt")
	# Tech (4) is converted to Savvy.
	assert_that(int(pf.get("savvy", -1))).is_equal(4)


# ============================================================================
# Corrected export ending matrix (Planetfall pp.165-166)
# ============================================================================

func test_export_loyalty_grants_ship_and_no_debt() -> void:
	var r: Dictionary = _svc.convert_from_planetfall(_make_planetfall_native(), "loyalty")
	assert_that(bool(r.get("bonus_ship", false))).is_true()
	assert_that(int(r.get("ship_debt", -1))).is_equal(0)
	# Loyalty does NOT grant the +2 Story Points (that's the Independence clause).
	assert_that(r.has("bonus_story_points")).is_false()


func test_export_independence_won_prepays_debt_not_zeroes_it() -> void:
	var r: Dictionary = _svc.convert_from_planetfall(_make_planetfall_native(), "independence_won")
	assert_that(bool(r.get("bonus_ship", false))).is_true()
	# 2D6 of debt prepaid (a partial prepayment), NOT full debt forgiveness.
	assert_that(int(r.get("ship_debt_prepaid", 0))).is_between(2, 12)
	assert_that(r.has("ship_debt")).is_false()  # the old bug set ship_debt = 0
	assert_that(int(r.get("bonus_story_points", -1))).is_equal(2)


func test_export_independence_lost_grants_rival_and_story_points() -> void:
	var r: Dictionary = _svc.convert_from_planetfall(_make_planetfall_native(), "independence_lost")
	assert_that(str(r.get("add_rival", "")) in ["Enforcers", "Bounty Hunters"]).is_true()
	assert_that(int(r.get("bonus_story_points", -1))).is_equal(2)


func test_export_isolation_adds_luck_and_single_char_flag() -> void:
	var r: Dictionary = _svc.convert_from_planetfall(_make_planetfall_native(), "isolation")
	# Base Luck 1 + 1 from Isolation.
	assert_that(int(r.get("luck", -1))).is_equal(2)
	assert_that(bool(r.get("isolation_single_char", false))).is_true()


func test_export_ascension_grants_psionic() -> void:
	var r: Dictionary = _svc.convert_from_planetfall(_make_planetfall_native(), "ascension")
	assert_that(bool(r.get("gains_psionic", false))).is_true()


# ============================================================================
# Lossless import -> muster-out round-trip (via embedded snapshot)
# ============================================================================

func test_import_then_muster_out_restores_original() -> void:
	var original := _make_5pfh_char()
	# Import: convert + embed the canonical 5PFH-standard snapshot (as the panel does).
	var pf: Dictionary = _svc.convert_to_planetfall(original, "5pfh")
	var canonical: Dictionary = _svc.export_to_canonical(original, "five_parsecs")
	var clean: Dictionary = canonical.duplicate(true)
	clean.erase("snapshot")
	pf["snapshot"] = clean
	# 3 Luck became 3 KP on the way in.
	assert_that(int(pf.get("kp", -1))).is_equal(3)

	# Muster out mid-campaign (no ending) -> snapshot restores the original verbatim.
	var env: Dictionary = _svc.transfer_character(pf, "planetfall", "five_parsecs")
	var down: Dictionary = env["character"]
	assert_that(int(down.get("luck", -1))).is_equal(3)
	assert_that(int(down.get("combat", -1))).is_equal(2)
	assert_that(str(down.get("name", ""))).is_equal("Vera Kade")


# ============================================================================
# Reward suppression to a non-5PFH destination
# ============================================================================

func test_planetfall_to_bug_hunt_suppresses_ending_rewards() -> void:
	var pf := _make_planetfall_native()
	pf["planetfall_ending"] = "independence_won"  # would grant +2 SP toward 5PFH
	var env: Dictionary = _svc.transfer_character(pf, "planetfall", "bug_hunt")
	assert_that(str(env.get("target_mode", ""))).is_equal("bug_hunt")
	# Not a 5PFH destination -> no story points / credits attach.
	assert_that(int(env.get("bonus_story_points", -1))).is_equal(0)
	assert_that(int(env.get("mustering_credits", -1))).is_equal(0)
	# Bug Hunt entry shape (Luck zeroed); no ship bonus leaks onto the character.
	var down: Dictionary = env["character"]
	assert_that(int(down.get("luck", -1))).is_equal(0)
	assert_that(down.has("bonus_ship")).is_false()
