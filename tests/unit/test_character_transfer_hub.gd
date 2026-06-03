extends GdUnitTestSuite
## Tests for the CharacterTransferService canonical-hub router — the chokepoint
## for any-to-any character transfer between the four persistent game modes.
##
## The safety net is the lossless round-trip: a full character converted OUT of
## a mode and restored from its embedded snapshot must equal the original. The
## composition tests prove the book-faithful behaviour for routes no rulebook
## defines directly (e.g. Planetfall -> Bug Hunt), including reward-suppression.

const CharacterTransferService := preload("res://src/core/character/CharacterTransferService.gd")
const FiveParsecsCampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const TRANSFER_DIR := "user://transfers/"

var _svc
var _written_files: Array[String] = []


func before_test() -> void:
	_svc = CharacterTransferService.new()
	_written_files.clear()
	if not DirAccess.dir_exists_absolute(TRANSFER_DIR):
		DirAccess.make_dir_recursive_absolute(TRANSFER_DIR)


func after_test() -> void:
	# Remove only files this suite created — never touch real transfers.
	for path in _written_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_written_files.clear()


# ============================================================================
# Helpers
# ============================================================================

func _make_full_character() -> Dictionary:
	## A representative 5PFH-standard (canonical) character dict.
	return {
		"id": "char_test_1", "character_id": "char_test_1",
		"name": "Vera Kade", "character_name": "Vera Kade",
		"game_mode": "standard", "status": "active",
		"combat": 2, "reactions": 3, "toughness": 4, "speed": 5,
		"savvy": 1, "tech": 0, "luck": 3,
		"experience": 12, "xp": 12,
		"equipment": [
			{"id": "hand_laser", "name": "Hand Laser"},
			{"id": "blade", "name": "Blade"}
		],
		"background": "Soldier",
		"is_captain": false
	}


func _write_transfer_file(name: String, data: Dictionary) -> String:
	var path := TRANSFER_DIR + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_written_files.append(path)
	return path


# ============================================================================
# Lossless round-trip (the core safety net)
# ============================================================================

func test_round_trip_lossless_via_snapshot() -> void:
	var original := _make_full_character()
	var envelope: Dictionary = _svc.transfer_character(original, "five_parsecs", "bug_hunt")
	var down: Dictionary = envelope["character"]

	# Down-converted Bug Hunt form differs (Luck zeroed per the entry rules).
	assert_that(int(down.get("luck", -1))).is_equal(0)

	# But the embedded snapshot restores the canonical original verbatim.
	var restored: Dictionary = _svc.export_to_canonical(down, "bug_hunt")
	assert_that(int(restored.get("luck", -1))).is_equal(3)
	assert_that(int(restored.get("combat", -1))).is_equal(2)
	assert_that(str(restored.get("name", ""))).is_equal("Vera Kade")
	assert_that(int(restored.get("experience", -1))).is_equal(12)


# ============================================================================
# Composition + reward suppression (the 3 book-undefined routes)
# ============================================================================

func test_composition_suppresses_5pfh_rewards() -> void:
	# Planetfall -> Bug Hunt routes through canonical; no 5PFH exit rewards leak.
	var pf_char := {
		"id": "pf_1", "name": "Colonist Ro",
		"combat_skill": 1, "reactions": 2, "toughness": 4, "speed": 4, "savvy": 2,
		"xp": 5, "kp": 2, "loyalty": "loyal", "game_mode": "planetfall",
		"planetfall_ending": "independence_won"
	}
	var env: Dictionary = _svc.transfer_character(pf_char, "planetfall", "bug_hunt")

	assert_that(str(env.get("target_mode", ""))).is_equal("bug_hunt")
	# Reward-suppression: target is not 5PFH, so no mustering rewards attach.
	assert_that(int(env.get("mustering_credits", -1))).is_equal(0)
	assert_that(bool(env.get("add_sector_government_patron", true))).is_false()

	# Bug Hunt entry rules applied (Luck zeroed) and the Planetfall ending bonus
	# (bonus_ship) does NOT leak onto the down-converted character.
	var down: Dictionary = env["character"]
	assert_that(int(down.get("luck", -1))).is_equal(0)
	assert_that(down.has("bonus_ship")).is_false()


func test_compose_to_5pfh_keeps_rewards() -> void:
	# Bug Hunt -> 5PFH keeps mustering rewards (target IS 5PFH).
	var bh_char := {
		"id": "bh_1", "name": "Trooper Vance", "game_mode": "bug_hunt",
		"combat_skill": 1, "reactions": 2, "toughness": 4, "speed": 4, "savvy": 0,
		"completed_missions_count": 12, "xp": 4, "is_grunt": false, "status": "active"
	}
	var env: Dictionary = _svc.transfer_character(bh_char, "bug_hunt", "five_parsecs")

	assert_that(str(env.get("target_mode", ""))).is_equal("five_parsecs")
	# 12 completed missions -> 6 credits (1 per 2 missions, Compendium p.213).
	assert_that(int(env.get("mustering_credits", -1))).is_equal(6)
	assert_that(int(env.get("bonus_story_points", -1))).is_equal(1)
	assert_that(bool(env.get("add_sector_government_patron", false))).is_true()


# ============================================================================
# Pending-transfer loader (target_mode filter + v1 back-compat)
# ============================================================================

func test_loader_filters_by_target_mode() -> void:
	var v2 := {
		"schema_version": 2, "direction": "bug_hunt_to_five_parsecs",
		"source_mode": "bug_hunt", "target_mode": "five_parsecs",
		"character": _make_full_character(),
		"mustering_credits": 6, "bonus_story_points": 1
	}
	var v1_legacy := {
		"schema_version": 1, "direction": "muster_out",
		"character": _make_full_character(),
		"mustering_credits": 2, "bonus_story_points": 1
	}
	var p2 := _write_transfer_file("test_hub_v2.json", v2)
	var p1 := _write_transfer_file("test_hub_v1.json", v1_legacy)

	# Both target 5PFH (v2 explicitly; v1 muster_out implicitly).
	var for_5pfh: Array = CharacterTransferService.load_pending_transfers("five_parsecs")
	assert_that(_paths_in(for_5pfh)).contains([p2])
	assert_that(_paths_in(for_5pfh)).contains([p1])

	# Neither targets Bug Hunt.
	var for_bh: Array = CharacterTransferService.load_pending_transfers("bug_hunt")
	assert_that(_paths_in(for_bh)).not_contains([p2])
	assert_that(_paths_in(for_bh)).not_contains([p1])


func _paths_in(transfers: Array) -> Array:
	var out: Array = []
	for t in transfers:
		out.append(str(t.get("_file_path", "")))
	return out


# ============================================================================
# apply_transfer_rewards — patron grant + atomic file delete
# ============================================================================

func test_apply_transfer_rewards_adds_patron_and_deletes_file() -> void:
	var path := _write_transfer_file("test_hub_apply.json", {
		"schema_version": 2, "target_mode": "five_parsecs",
		"character": _make_full_character(),
		"mustering_credits": 0, "bonus_story_points": 0,
		"add_sector_government_patron": true
	})
	var transfer := {
		"character": _make_full_character(),
		"mustering_credits": 0, "bonus_story_points": 0,
		"add_sector_government_patron": true,
		"_file_path": path
	}
	var campaign := FiveParsecsCampaignCore.new()
	campaign.patrons = []

	var res: Dictionary = CharacterTransferService.apply_transfer_rewards(campaign, transfer)

	assert_that(res.get("success", false)).is_true()
	assert_that(campaign.patrons.size()).is_equal(1)
	assert_that(str(campaign.patrons[0].get("type", ""))).is_equal("sector_government")
	# File is deleted on success (prevents double-import).
	assert_that(FileAccess.file_exists(path)).is_false()


# ============================================================================
# add_crew_member — lands a non-captain, index-resolvable member
# ============================================================================

func test_add_crew_member_lands_non_captain() -> void:
	var campaign := FiveParsecsCampaignCore.new()
	campaign.initialize_crew({"members": []})

	var imported := _make_full_character()
	imported["is_captain"] = true  # must be forced false on import
	campaign.add_crew_member(imported)

	var members: Array = campaign.crew_data["members"]
	assert_that(members.size()).is_equal(1)
	assert_that(bool(members[0].get("is_captain", true))).is_false()

	# The cached index resolves the new member by id.
	var found = campaign.get_crew_member_by_id("char_test_1")
	assert_that(found is Dictionary).is_true()
