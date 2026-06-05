extends GdUnitTestSuite
## Tests for the Tactics transfer leg (P2) of the cross-mode framework.
##
## Verifies the book-faithful conversions (Tactics p.184 "Converting Characters"),
## the named-veteran model (imports land in veteran_characters[], NOT campaign_units[],
## so army points are never affected), the playability KP floor, the lossless
## commission->retire round-trip via the snapshot, and serialization.

const CharacterTransferService := preload("res://src/core/character/CharacterTransferService.gd")
const TacticsCampaignCore := preload("res://src/game/campaign/TacticsCampaignCore.gd")

var _svc


func before_test() -> void:
	_svc = CharacterTransferService.new()


func _make_5pfh_char() -> Dictionary:
	return {
		"id": "char_tac_1", "character_id": "char_tac_1",
		"name": "Sgt. Cor", "character_name": "Sgt. Cor",
		"game_mode": "standard", "status": "active",
		"combat": 2, "reactions": 3, "toughness": 4, "speed": 5,
		"savvy": 1, "luck": 3, "xp": 10, "background": "Mining Colony",
		"equipment": [{"id": "blade", "name": "Blade"}]
	}


# ============================================================================
# Book-faithful conversion INTO Tactics (Tactics p.184)
# ============================================================================

func test_into_tactics_caps_combat_and_toughness() -> void:
	var c := {
		"id": "c1", "name": "Big", "combat": 4, "toughness": 7,
		"reactions": 2, "speed": 4, "savvy": 1, "luck": 1, "background": "Mining Colony"
	}
	var v: Dictionary = _svc.convert_to_tactics(c, "5pfh")
	assert_that(int(v.get("combat_skill", -1))).is_equal(2)   # capped at +2
	assert_that(int(v.get("toughness", -1))).is_equal(5)      # capped at 5
	assert_that(int(v.get("kill_points", -1))).is_equal(1)    # 1 KP per Luck point
	assert_that(int(v.get("training", -1))).is_equal(1)       # non-military background


func test_kill_points_equal_luck_no_floor_in_conversion() -> void:
	var v: Dictionary = _svc.convert_to_tactics(_make_5pfh_char(), "5pfh")
	# 3 Luck -> 3 KP exactly (the conversion stays book-exact; no max(...,1) floor).
	assert_that(int(v.get("kill_points", -1))).is_equal(3)


func test_military_type_background_grants_training_2() -> void:
	for bg in ["Military Brat", "Military Outpost", "War-Torn Hell-Hole"]:
		var v: Dictionary = _svc.convert_to_tactics(
			{"id": "x", "name": "M", "combat": 1, "luck": 2, "background": bg}, "5pfh")
		assert_that(int(v.get("training", -1))).is_equal(2)
	var v2: Dictionary = _svc.convert_to_tactics(
		{"id": "y", "name": "N", "combat": 1, "luck": 2, "background": "Tech Guild"}, "5pfh")
	assert_that(int(v2.get("training", -1))).is_equal(1)


func test_from_tactics_kp_after_first_becomes_luck() -> void:
	var tac := {
		"id": "t1", "name": "Born", "combat_skill": 1, "toughness": 4,
		"reactions": 2, "speed": 4, "savvy": 1, "kill_points": 3
	}
	var r: Dictionary = _svc.convert_from_tactics(tac)
	# 3 KP -> 2 Luck (each Kill Point AFTER the first becomes 1 Luck).
	assert_that(int(r.get("luck", -1))).is_equal(2)
	assert_that(int(r.get("combat", -1))).is_equal(1)


# ============================================================================
# Named-veteran model — veterans never touch campaign_units[] (no points impact)
# ============================================================================

func test_veteran_lands_outside_campaign_units() -> void:
	var campaign := TacticsCampaignCore.new()
	campaign.initialize_campaign_units([
		{"unit_id": "u1", "base_unit_id": "trooper_squad", "current_models": 5}
	])
	campaign.add_veteran_character({"id": "vet1", "name": "Hero", "kill_points": 2})
	assert_that(campaign.veteran_characters.size()).is_equal(1)
	# The army's points-bearing units are untouched by the veteran attachment.
	assert_that(campaign.campaign_units.size()).is_equal(1)


func test_veteran_kp_floored_to_one() -> void:
	var campaign := TacticsCampaignCore.new()
	# A 0-Luck character converts to 0 KP (book-exact); the veteran layer floors it
	# to 1 so the figure can take the field.
	campaign.add_veteran_character({"id": "vetz", "name": "Zero", "kill_points": 0})
	assert_that(int(campaign.veteran_characters[0].get("kill_points", -1))).is_equal(1)


func test_remove_veteran_character() -> void:
	var campaign := TacticsCampaignCore.new()
	campaign.add_veteran_character({"id": "vetA", "name": "A", "kill_points": 2})
	assert_that(campaign.remove_veteran_character("vetA")).is_true()
	assert_that(campaign.veteran_characters.size()).is_equal(0)


# ============================================================================
# Lossless commission -> retire round-trip (via embedded snapshot)
# ============================================================================

func test_commission_then_retire_restores_original() -> void:
	var original := _make_5pfh_char()
	var canonical: Dictionary = _svc.export_to_canonical(original, "five_parsecs")
	var vet: Dictionary = _svc.convert_to_tactics(canonical, "5pfh")
	var clean: Dictionary = canonical.duplicate(true)
	clean.erase("snapshot")
	vet["snapshot"] = clean

	var env: Dictionary = _svc.transfer_character(vet, "tactics", "five_parsecs")
	var down: Dictionary = env["character"]
	assert_that(int(down.get("luck", -1))).is_equal(3)
	assert_that(int(down.get("combat", -1))).is_equal(2)
	assert_that(str(down.get("name", ""))).is_equal("Sgt. Cor")


# ============================================================================
# Serialization round-trip of veteran_characters[]
# ============================================================================

func test_veteran_characters_serialize_round_trip() -> void:
	var campaign := TacticsCampaignCore.new()
	campaign.campaign_name = "Op Test"
	campaign.add_veteran_character({"id": "v1", "name": "Vet", "kill_points": 2, "combat_skill": 2})
	var data: Dictionary = campaign.to_dictionary()
	assert_that(data.has("veteran_characters")).is_true()
	assert_that((data["veteran_characters"] as Array).size()).is_equal(1)

	var restored := TacticsCampaignCore.new()
	restored.from_dictionary(data)
	assert_that(restored.veteran_characters.size()).is_equal(1)
	assert_that(str(restored.veteran_characters[0].get("name", ""))).is_equal("Vet")
