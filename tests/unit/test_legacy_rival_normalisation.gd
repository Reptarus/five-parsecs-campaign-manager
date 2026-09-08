extends GdUnitTestSuite
## T11-25's legacy half — repairing Rival records whose NAME is an effect string.
##
## The producer was fixed and is PASS on hardware, but nothing repaired the records it
## had already written, and `CampaignDashboard.gd:1468` renders `rival.get("name",
## "Unknown")` raw. So the dashboard RIVALS panel, the Patrons & Rivals screen and the
## printed World Record Sheet all showed `Old nemesis (persistent, +1 enemies)` where a
## name belongs — including on the tester's live save.
##
## ⭐ THE FIXTURES BELOW ARE REAL. Every record is copied verbatim out of a pulled
## device save, and the four shapes are the four a census of 27 saves actually found
## (153 rival records). That census is what makes the signature safe: the malformed
## shape is the ONLY one carrying both `resources` and `source`, and all 24 malformed
## records shared it. Hand-built fixtures would have proved nothing about which shapes
## exist in the wild — this project has been caught by exactly that before, when the
## documented crew `origin` shape turned out to be the rarest one on disk.
##
## ⚠ The original rival name is unrecoverable; the producer overwrote it. The repair
## invents nothing — the display name comes from the record's own `type`, and both flags
## are parsed from the very string being replaced.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

## Verbatim from a pulled save (`resources.rivals`, deploy #24-#27 era campaign).
const MALFORMED := {
	"hostility": 4,
	"id": "rival_879341_156",
	"name": "Old nemesis (persistent, +1 enemies)",
	"resources": 1,
	"source": "event",
	"type": "Corporate",
}

## The three healthy shapes the census found, also verbatim.
const HEALTHY_STARTING := {
	"hostility": 3, "id": "rival_001", "is_starting_rival": true,
	"name": "Iron Bandits", "source_character": "", "strength": 2, "type": "Gang",
}
const HEALTHY_EVENT := {
	"created_turn": 6, "enemy_count_bonus": 1, "id": "rival_002",
	"name": "Feral Jackals", "origin": "", "planet_id": "", "source_event": "campaign",
	"threat_level": 2, "type": "Mercenary Band",
}
const HEALTHY_PERSISTENT := {
	"enemy_count_bonus": 1, "hostility": 5, "id": "rival_003",
	"is_starting_rival": false, "name": "Unwanted attention", "persistent": true,
	"source_character": "", "source_event": "event", "strength": 3,
	"type": "Black Dragons",
}


func _load_with(rival_list: Array):
	var c = CampaignCore.new()
	c.initialize_resources({"credits": 10, "rivals": rival_list.duplicate(true)})
	return c


# MARK: - The repair

func test_the_effect_string_name_is_replaced_by_the_records_own_type() -> void:
	var c = _load_with([MALFORMED])
	var r: Dictionary = c.rivals[0]
	assert_str(str(r.get("name", ""))) \
		.override_failure_message(
			"the display name must become the record's own `type`, which is what the "
			+ "fixed producer emits and what the rows lead with") \
		.is_equal("Corporate")


func test_the_flags_are_recovered_from_the_string_being_replaced() -> void:
	var c = _load_with([MALFORMED])
	var r: Dictionary = c.rivals[0]
	assert_bool(bool(r.get("persistent", false))) \
		.override_failure_message("'persistent' is stated in the effect text") \
		.is_true()
	assert_int(int(r.get("enemy_count_bonus", 0))) \
		.override_failure_message("'+1 enemies' is stated in the effect text") \
		.is_equal(1)


func test_the_two_dead_keys_are_dropped() -> void:
	var c = _load_with([MALFORMED])
	var r: Dictionary = c.rivals[0]
	assert_bool(r.has("resources")).is_false()
	assert_bool(r.has("source")).is_false()


func test_the_original_string_is_kept_so_the_repair_is_auditable() -> void:
	## A silent rewrite of player-visible data is worse than the defect. Keeping what
	## was displayed means a later reader can see what happened, and it is the only
	## record of the name the producer destroyed.
	var c = _load_with([MALFORMED])
	assert_str(str((c.rivals[0] as Dictionary).get("legacy_name", ""))) \
		.is_equal("Old nemesis (persistent, +1 enemies)")


# MARK: - What it must NOT touch

func test_all_three_healthy_shapes_are_left_byte_identical() -> void:
	## ⭐ The discriminating half. A normalisation that over-matches is worse than the
	## cosmetic defect it fixes, and this is the case that would catch it.
	var healthy: Array = [HEALTHY_STARTING, HEALTHY_EVENT, HEALTHY_PERSISTENT]
	var c = _load_with(healthy)
	for i in range(healthy.size()):
		var before: Dictionary = healthy[i]
		var after: Dictionary = c.rivals[i]
		assert_int(after.size()) \
			.override_failure_message(
				"healthy shape " + str(i) + " gained or lost a key: "
				+ str(after.keys())) \
			.is_equal(before.size())
		for k in before:
			assert_str(str(after.get(k))) \
				.override_failure_message(
					"healthy shape " + str(i) + " had key '" + str(k) + "' rewritten") \
				.is_equal(str(before[k]))


func test_a_parenthesised_name_without_the_key_pair_is_left_alone() -> void:
	## Both halves of the signature are required. A legitimately parenthesised rival
	## name — which the book's own faction names could produce — must survive.
	var legit := {
		"hostility": 3, "id": "rival_004", "is_starting_rival": false,
		"name": "The Syndicate (Red Branch)", "source_character": "",
		"strength": 2, "type": "Corporate",
	}
	var c = _load_with([legit])
	assert_str(str((c.rivals[0] as Dictionary).get("name", ""))) \
		.override_failure_message(
			"this record lacks the resources/source pair, so it is not the legacy "
			+ "shape and its name must not be replaced by its type") \
		.is_equal("The Syndicate (Red Branch)")


func test_a_legacy_shape_with_no_type_is_left_alone() -> void:
	## Nothing in the record to build a name from. A blank name is a worse outcome than
	## a wrong one, so the repair declines rather than inventing.
	var no_type := {
		"hostility": 4, "id": "rival_005", "name": "Old nemesis (persistent)",
		"resources": 1, "source": "event", "type": "",
	}
	var c = _load_with([no_type])
	assert_str(str((c.rivals[0] as Dictionary).get("name", ""))) \
		.is_equal("Old nemesis (persistent)")


# MARK: - Idempotence

func test_running_twice_changes_nothing_the_second_time() -> void:
	## The repair runs on EVERY load, so a second pass over an already-repaired record
	## must be a no-op — otherwise a save loaded twice would compound.
	var c = _load_with([MALFORMED])
	var first: Dictionary = (c.rivals[0] as Dictionary).duplicate(true)
	c.initialize_resources({"credits": 10, "rivals": c.rivals.duplicate(true)})
	var second: Dictionary = c.rivals[0]
	assert_int(second.size()).is_equal(first.size())
	assert_str(str(second.get("name", ""))).is_equal(str(first.get("name", "")))
	assert_str(str(second.get("legacy_name", ""))) \
		.is_equal(str(first.get("legacy_name", "")))


func test_an_empty_rival_list_does_not_error() -> void:
	var c = _load_with([])
	assert_int((c.rivals as Array).size()).is_equal(0)
