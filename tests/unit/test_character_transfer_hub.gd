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
const BugHuntCampaignCore := preload("res://src/game/campaign/BugHuntCampaignCore.gd")

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
	#
	# The SIBLINGS matter too: SaveFileWriter leaves a .bak (and briefly a .tmp) beside
	# every save it writes, so removing only the registered path left two .bak files in
	# user://transfers/ after every run. Harmless today - load_pending_transfers scans
	# ends_with(".json") - but litter in the directory the pickup reads is exactly what a
	# later reader has to rule out by hand.
	for path in _written_files:
		for candidate in [path, path + ".bak", path + ".tmp"]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(candidate)
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
# apply_transfer_rewards — patron grant + deferred file delete
#
# CONTRACT CHANGE: this used to delete the transfer file inline and the assertion
# below checked for that. It no longer does. A transfer file is the ONLY copy of
# the character, and the receiving campaign is not written to disk until after the
# caller's loop finishes — so deleting inline destroyed the source while the
# destination existed only in memory. The path is now returned as `consumed_file`
# and CampaignScreenBase._apply_pending_transfers deletes it only after a verified
# save; a failed save leaves the file for retry.
# ============================================================================

func test_apply_transfer_rewards_adds_patron_and_defers_file_delete() -> void:
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
	# The file SURVIVES this call and is reported back for the caller to delete once
	# the campaign has actually been saved. Deleting here would destroy the only copy
	# of the character before it is persisted anywhere.
	assert_that(str(res.get("consumed_file", ""))).is_equal(path)
	assert_that(FileAccess.file_exists(path)).is_true()
	DirAccess.remove_absolute(path)  # the caller's job in production


# ----------------------------------------------------------------------------
# Summary honesty - a reward line must never outlive the grant it describes
# ----------------------------------------------------------------------------
#
# apply_transfer_rewards() guards each grant on the receiving campaign actually having
# the field, then appends a line to the muster-out summary the player is shown. Four of
# those lines sat OUTSIDE their guard, so a campaign that could not hold a reward was
# still told it had received one.
#
# COVERAGE NOTE, so the next reader does not assume more than is here: this pair covers
# the patron and the ship, whose guards are campaign-field tests a suite can falsify by
# choosing the campaign. The credits and Story Point lines take the identical fix and are
# NOT covered - their guard is `gsm and gsm.has_method(...)` against the GameStateManager
# AUTOLOAD, which a test cannot remove without breaking every other suite in the process.
# Their correctness rests on the shared shape, not on a case.

func test_the_summary_omits_rewards_the_campaign_cannot_hold() -> void:
	# A BugHuntCampaignCore declares neither `patrons` nor `has_ship`. It is the real
	# object the mode-generic pickup (CampaignScreenBase._apply_pending_transfers) can
	# hand in, not a stub written to fail.
	var campaign := BugHuntCampaignCore.new()

	# Premise instruments. If either field existed the grant would run, and this case
	# would pass while asserting nothing at all about the guard.
	assert_bool("patrons" in campaign).override_failure_message(
		"fixture premise: BugHuntCampaignCore must NOT declare `patrons`, or this case is"
		+ " measuring a campaign that can hold the reward"
	).is_false()
	assert_bool("has_ship" in campaign).override_failure_message(
		"fixture premise: BugHuntCampaignCore must NOT declare `has_ship`"
	).is_false()

	var character := _make_full_character()
	character["bonus_ship"] = true
	var transfer := {
		"character": character,
		# Zero deliberately: those two grants reach the live GameStateManager autoload,
		# and this case must not mutate whatever campaign the process has loaded.
		"mustering_credits": 0, "bonus_story_points": 0,
		"add_sector_government_patron": true
	}

	var res: Dictionary = CharacterTransferService.apply_transfer_rewards(campaign, transfer)
	var summary := str(res.get("summary", ""))

	# The transfer itself is not a failure - the character still arrives. Only the
	# announcement of a reward that was never granted is wrong.
	assert_bool(res.get("success", false)).is_true()
	assert_str(summary).override_failure_message(
		"the summary announced a Sector Government Patron to a campaign with no patron"
		+ " list to put one in: '%s'" % summary
	).not_contains("Sector Government Patron")
	assert_str(summary).override_failure_message(
		"the summary announced a ship to a campaign that has no ship: '%s'" % summary
	).not_contains("+Ship")


func test_the_summary_still_announces_rewards_the_campaign_did_receive() -> void:
	# The anti-over-correction arm. Deleting the two summary lines outright would make the
	# case above pass and leave a player who DID receive both rewards told about neither.
	var campaign := FiveParsecsCampaignCore.new()
	campaign.patrons = []
	# has_ship defaults to TRUE, so a fixture that left it alone could not tell the grant
	# apart from the default - the assertion below would pass with the write deleted.
	campaign.has_ship = false

	var character := _make_full_character()
	character["bonus_ship"] = true
	var transfer := {
		"character": character,
		"mustering_credits": 0, "bonus_story_points": 0,
		"add_sector_government_patron": true
	}

	var res: Dictionary = CharacterTransferService.apply_transfer_rewards(campaign, transfer)
	var summary := str(res.get("summary", ""))

	# Granted for real...
	assert_int(campaign.patrons.size()).is_equal(1)
	assert_bool(campaign.has_ship).is_true()
	# ...and therefore announced.
	assert_str(summary).contains("Sector Government Patron")
	assert_str(summary).contains("+Ship")


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

# ---------------------------------------------------------------------------
# Group E — transfer-integrity regressions
# ---------------------------------------------------------------------------

func test_muster_out_honours_the_lossless_snapshot() -> void:
	# muster_out() called _convert_to_standard() DIRECTLY, bypassing
	# export_to_canonical() and therefore the snapshot. A 5PFH veteran who
	# enlisted and later mustered out came back as a reconstruction from Bug Hunt
	# stats, silently losing everything Bug Hunt does not model.
	var original := {
		"character_id": "vet_1", "character_name": "Vasquez",
		"combat": 3, "reactions": 4, "toughness": 5, "savvy": 2, "luck": 2,
		"species_id": "kerin", "traits": ["Veteran"],
	}
	var bug_hunt_char: Dictionary = _svc.import_from_canonical(original, "bug_hunt")
	bug_hunt_char["completed_missions_count"] = 6
	var res: Dictionary = _svc.muster_out(bug_hunt_char)
	assert_bool(res.get("success", false)).is_true()
	var out: Dictionary = res["transferred_character"]
	# Restored verbatim from the snapshot, not rebuilt.
	assert_int(int(out.get("combat", -1))).is_equal(3)
	assert_int(int(out.get("toughness", -1))).is_equal(5)
	assert_str(str(out.get("species_id", ""))).is_equal("kerin")

func test_muster_out_rewards_survive_the_snapshot_path() -> void:
	# The snapshot branch of export_to_canonical returned the bare snapshot, so a
	# snapshot-carrying veteran got NO mustering credits, Story Point or patron.
	var original := {"character_id": "vet_2", "character_name": "Drake", "combat": 1}
	var bh: Dictionary = _svc.import_from_canonical(original, "bug_hunt")
	bh["completed_missions_count"] = 6
	var out: Dictionary = _svc.muster_out(bh)["transferred_character"]
	assert_int(int(out.get("mustering_credits", -1))).is_equal(3)  # 6 / 2
	assert_int(int(out.get("bonus_story_points", 0))).is_equal(1)
	assert_bool(bool(out.get("add_sector_government_patron", false))).is_true()

func test_planetfall_independence_story_points_reach_the_envelope() -> void:
	# transfer_character read bonus_story_points off the CANONICAL, but
	# _layer_planetfall_ending writes it on the DOWN-converted character, so the
	# p.164 "+2 additional Story Points (win or lose)" always resolved to 0.
	var colonist := {
		"character_id": "col_1", "character_name": "Rhea", "combat": 1,
		"planetfall_ending": "independence_won",
	}
	var env: Dictionary = _svc.transfer_character(colonist, "planetfall", "five_parsecs")
	assert_int(int(env.get("bonus_story_points", 0))).is_equal(2)

func test_ascension_grants_real_psionic_powers() -> void:
	# `gains_psionic` only ever appended "+Psionic" to a summary STRING; the
	# character arrived with no powers. Planetfall p.164 -> Compendium p.17.
	var out: Dictionary = _svc.convert_from_planetfall(
		{"id": "asc_1", "name": "Kell"}, "ascension")
	assert_bool(out.get("gains_psionic", false)).is_true()
	var powers: Array = out.get("psionic_powers", [])
	assert_int(powers.size()).is_equal(2)
	assert_str(str(powers[0])).is_not_equal(str(powers[1]))  # p.22 duplicate shift

func test_isolation_marks_the_character_for_the_one_per_campaign_cap() -> void:
	var out: Dictionary = _svc.convert_from_planetfall(
		{"id": "iso_1", "name": "Wen", "luck": 1}, "isolation")
	assert_bool(out.get("from_isolation_victory", false)).is_true()

func test_bug_hunt_origin_uses_species_id_not_the_dead_species_key() -> void:
	# _convert_to_bug_hunt read "species", which Character.to_dictionary() never
	# emits, so EVERY enlistee was "Transfer from Unknown".
	var out: Dictionary = _svc.import_from_canonical(
		{"character_id": "s1", "character_name": "Ket", "species_id": "kerin"}, "bug_hunt")
	assert_str(str(out.get("origin", ""))).contains("kerin")
	assert_str(str(out.get("origin", ""))).not_contains("Unknown")

func test_transferred_character_carries_both_reaction_keys() -> void:
	# Battle reads "reactions"; the crew UI reads "reaction". Emitting one side
	# only meant a transferred veteran fought at Reactions 1, or displayed as 0.
	var out: Dictionary = _svc.import_from_canonical(
		{"character_id": "r1", "character_name": "Tam", "reactions": 4}, "five_parsecs")
	var bh: Dictionary = _svc.import_from_canonical(
		{"character_id": "r2", "character_name": "Ada", "reactions": 4}, "bug_hunt")
	assert_int(int(bh.get("reactions", -1))).is_equal(4)
	assert_int(int(bh.get("reaction", -1))).is_equal(4)
	assert_bool(out.has("character_name")).is_true()

func test_remove_character_from_save_handles_both_roster_shapes() -> void:
	# The pull-import direction never removed the original, so one character
	# existed in two campaigns at once.
	for shape in [
		{"path": "user://transfers/t_5pfh.save",
		 "data": {"crew": {"members": [{"character_id": "a"}, {"character_id": "b"}]}},
		 "container": "crew", "key": "members"},
		{"path": "user://transfers/t_bh.save",
		 "data": {"squad": {"main_characters": [{"character_id": "a"}, {"character_id": "b"}]}},
		 "container": "squad", "key": "main_characters"},
	]:
		var f := FileAccess.open(shape["path"], FileAccess.WRITE)
		f.store_string(JSON.stringify(shape["data"]))
		f.close()
		_written_files.append(shape["path"])
		assert_bool(CharacterTransferService.remove_character_from_save(
			shape["path"], "a")).is_true()
		var reread: Dictionary = JSON.parse_string(
			FileAccess.open(shape["path"], FileAccess.READ).get_as_text())
		var roster: Array = reread[shape["container"]][shape["key"]]
		assert_int(roster.size()).is_equal(1)
		assert_str(str(roster[0]["character_id"])).is_equal("b")
	# A miss must NOT rewrite the file.
	assert_bool(CharacterTransferService.remove_character_from_save(
		"user://transfers/t_5pfh.save", "nobody")).is_false()
# ============================================================================
# The mode boundary: 5PFH's REAL producer vs this hub's own vocabulary
# ============================================================================
#
# The 15 cases above could not catch what these four pin, and the reason is in
# _make_full_character(): it hand-writes "status": "active", which is the
# eligibility gate's own DEFAULT. Character.to_dictionary() writes "ACTIVE"
# (Character.gd:135/:1401) and the gates compared against a lowercase literal,
# so EVERY healthy 5PFH crew member was rejected as inactive and
# attempt_enlistment returned before rolling. Measured on the tablet
# 2026-09-22 as "Dice: [0] + [0] + Combat Skill 0 = 0".
#
# A hand-built fixture cannot test a producer's vocabulary. These build the
# character with the real producer.

const RealCharacter := preload("res://src/core/character/Character.gd")

const _FORCE_D1 := "Enlistment: die 1"
const _FORCE_D2 := "Enlistment: die 2"


func _real_5pfh_character(combat: int, status: String = "") -> Dictionary:
	## A dict from Character.to_dictionary(), not from this suite's imagination.
	var character := RealCharacter.new()
	character.combat = combat
	if not status.is_empty():
		character.status = status
	return character.to_dictionary()


func _dice_manager():
	return get_tree().root.get_node_or_null("/root/DiceManager") if get_tree() else null


func test_a_real_5pfh_character_is_eligible_and_actually_rolls() -> void:
	var data := _real_5pfh_character(2)

	# Premise first. If Character ever stops emitting the uppercase form, this
	# case must SAY so rather than quietly stop testing the case-folding gate.
	assert_str(str(data.get("status", ""))).override_failure_message(
		"PREMISE: Character.to_dictionary() no longer writes ACTIVE in uppercase, "
		+ "so _status_is_active may now be untested. Re-read it before trusting this suite."
	).is_equal("ACTIVE")
	assert_bool(data.has("combat")).is_true()

	var validation: Dictionary = _svc.validate_enlistment(data)
	assert_bool(validation.get("eligible", false)).override_failure_message(
		"A healthy 5PFH character must be eligible to enlist. Reason given: "
		+ str(validation.get("reason", ""))
	).is_true()
	assert_int(int(validation.get("combat_bonus", -1))).is_equal(2)

	var result: Dictionary = _svc.attempt_enlistment(data)

	# `dice` is the discriminator CharacterTransferPanel now reads: the service
	# writes it ONLY when a roll actually happened.
	assert_bool(result.has("dice")).override_failure_message(
		"attempt_enlistment returned WITHOUT rolling for an eligible character."
	).is_true()
	var dice: Array = result["dice"]
	assert_int(dice.size()).is_equal(2)
	assert_int(int(result.get("combat_bonus", -1))).is_equal(2)

	# Self-consistent, not absolute: _sector_government_patron_bonus() reads
	# GameState.current_campaign, which an earlier suite in the batch may have
	# left populated, so the patron term is read back rather than assumed zero.
	assert_int(int(result.get("roll", -1))).override_failure_message(
		"The printed total must equal the terms it is made of, or the panel's "
		+ "on-screen sum does not add up."
	).is_equal(
		int(dice[0]) + int(dice[1]) + int(result.get("combat_bonus", 0))
		+ int(result.get("patron_bonus", 0)))


func test_an_injured_5pfh_character_is_rejected_without_a_roll() -> void:
	# The gate's actual purpose still holds after the case-folding fix, and the
	# rejection must carry NO dice — that absence is what lets the panel say
	# "cannot enlist" instead of fabricating a failed roll.
	var data := _real_5pfh_character(2, "INJURED")
	assert_str(str(data.get("status", ""))).is_equal("INJURED")

	var result: Dictionary = _svc.attempt_enlistment(data)
	assert_bool(result.get("success", true)).is_false()
	assert_bool(result.has("dice")).override_failure_message(
		"An ineligible character must not carry dice, or the panel cannot tell a "
		+ "refusal apart from a failed roll."
	).is_false()
	assert_str(str(result.get("reason", ""))).is_not_empty()


func test_a_forced_enlistment_roll_lands_on_the_book_target() -> void:
	# Compendium p.212: 2D6 + Combat Skill, 7+ enlists.
	var dm = _dice_manager()
	assert_object(dm).is_not_null()
	dm.clear_forced_results(_FORCE_D1)
	dm.clear_forced_results(_FORCE_D2)

	# queue_forced_result returns false when forcing is unavailable, so the
	# premise is asserted rather than inferred from a mismatched total.
	assert_bool(dm.queue_forced_result(_FORCE_D1, 1)).override_failure_message(
		"PREMISE: the QA forcing seam refused the queue, so this case cannot "
		+ "discriminate. OS.is_debug_build() is the usual cause."
	).is_true()
	assert_bool(dm.queue_forced_result(_FORCE_D2, 1)).is_true()

	var low: Dictionary = _svc.attempt_enlistment(_real_5pfh_character(2))
	assert_array(low.get("dice", [])).is_equal([1, 1])
	assert_bool(low.get("success", true)).is_false()

	dm.queue_forced_result(_FORCE_D1, 6)
	dm.queue_forced_result(_FORCE_D2, 6)
	var high: Dictionary = _svc.attempt_enlistment(_real_5pfh_character(2))
	assert_array(high.get("dice", [])).is_equal([6, 6])
	assert_bool(high.get("success", false)).is_true()
	assert_bool(high.has("transferred_character")).is_true()

	dm.clear_forced_results(_FORCE_D1)
	dm.clear_forced_results(_FORCE_D2)


func test_a_real_5pfh_character_is_eligible_for_tactics_too() -> void:
	# The same lowercase literal guarded validate_tactics_enlistment, so one
	# case mismatch closed TWO of the three 5PFH-outbound routes. Pinned here
	# because a fix applied to one call site is not a fix.
	var ok: Dictionary = _svc.validate_tactics_enlistment(_real_5pfh_character(3))
	assert_bool(ok.get("eligible", false)).override_failure_message(
		"A healthy 5PFH character must be eligible for Tactics. Reason given: "
		+ str(ok.get("reason", ""))
	).is_true()

	var dead: Dictionary = _svc.validate_tactics_enlistment(
		_real_5pfh_character(3, "DEAD"))
	assert_bool(dead.get("eligible", true)).is_false()
