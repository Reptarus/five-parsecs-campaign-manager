extends GdUnitTestSuite
## T9-39 / T9-40 / T9-41 (tablet, Aug 13 2026) — the World Phase was unadvanceable
## by touch on a legacy save.
##
## THE CREW SHAPE BELOW IS NOT INVENTED. It is the exact key set of the campaign
## loaded on the test tablet (`22222222`, created 2026-04-03), read back off the
## device with `adb run-as ... cat files/saves/*.save`. That save carries `id` and
## `character_name` but NO `character_id`, no `equipment` and no `status` — it
## predates those keys and was migrated in (it still carries the
## `species_backfilled` marker).
##
## This matters because `Character.to_dictionary()` DOES emit `character_id` and
## says so in its docblock, so reasoning from the producer says the defect is
## impossible. Only the real artifact shows otherwise. Building this fixture by
## hand from to_dictionary()'s key list would reproduce the blindness that let
## these three ship.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const CrewTaskComponentScript = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")
const AssignEquipmentComponentScript = preload(
	"res://src/ui/screens/world/components/AssignEquipmentComponent.gd")


## One crew member in the shape the April save actually stores.
func _legacy_member(id: String, name: String) -> Dictionary:
	return {
		"id": id,
		"character_name": name,
		"name": name,
		"is_captain": false,
		"species_id": "human",
		"combat": 1, "reaction": 1, "toughness": 3, "speed": 5,
		"savvy": 0, "luck": 0, "experience": 0,
		"species_backfilled": true,
	}


## And one in the modern shape, so a fix cannot regress current campaigns.
func _modern_member(id: String, name: String) -> Dictionary:
	var m: Dictionary = _legacy_member(id, name)
	m["character_id"] = id
	m["equipment"] = []
	m["status"] = "ACTIVE"
	m.erase("species_backfilled")
	return m


# ── T9-40: one key, whatever the save's vintage ───────────────────────────────

## The defect: assign keyed `assigned_tasks` by `character_id` else a POSITIONAL
## `"crew_%d"`, while the stranded check keyed it by `id`. On a legacy member the
## two never matched, so an assigned crew member was still reported as stranded.
##
## Asserting the two agree is the whole rule — it is what makes a write findable
## by a read.
func test_a_legacy_member_gets_one_stable_key() -> void:
	var m: Dictionary = _legacy_member("2873092675", "Zephyr Flynn")
	var key: String = CrewTaskComponentScript.crew_key(m)
	assert_str(key).override_failure_message(
		"a legacy member carries `id` and no `character_id`; the key must fall "
		+ "back to it, not to a positional slot").is_equal("2873092675")


func test_a_modern_member_keys_on_character_id() -> void:
	var m: Dictionary = _modern_member("char_498964_9495", "Bryn Ito")
	assert_str(CrewTaskComponentScript.crew_key(m)).is_equal("char_498964_9495")


## THE REGRESSION THAT WAS SHIPPING. The positional fallback did not merely
## disagree with `id` — it meant DIFFERENT PEOPLE in different lists.
## `_get_eligible_crew()` is a filtered subset of `crew_data`, so with one member
## in Sick Bay, `crew_data[2]` and `eligible[2]` are two different characters and
## `"crew_2"` silently addresses whichever list the caller happened to hold.
##
## A key into a shared Dictionary must never depend on position, so the same
## member must key identically no matter where it is found.
func test_the_key_does_not_depend_on_position_in_the_list() -> void:
	var zephyr: Dictionary = _legacy_member("2873092675", "Zephyr Flynn")
	var full_roster: Array = [
		_legacy_member("111", "Sick Bay Sam"), zephyr,
		_legacy_member("222", "Drew Thorne")]
	var eligible_subset: Array = [zephyr, _legacy_member("222", "Drew Thorne")]

	var from_roster: String = CrewTaskComponentScript.crew_key(full_roster[1])
	var from_subset: String = CrewTaskComponentScript.crew_key(eligible_subset[0])
	assert_str(from_roster).override_failure_message(
		"the same crew member keyed differently depending on which list it came "
		+ "from — that is the positional-fallback bug").is_equal(from_subset)


## A member with neither id must still be assignable, or the panel would silently
## drop them. Prefixed so it can never be mistaken for a real id.
func test_a_member_with_no_id_at_all_still_gets_a_usable_key() -> void:
	var key: String = CrewTaskComponentScript.crew_key(
		{"character_name": "Nameless Ned"})
	assert_str(key).is_not_empty()
	assert_str(key).is_equal("name:Nameless Ned")


## Distinct members must never collide — a shared key would let one assignment
## satisfy two people.
func test_distinct_members_never_share_a_key() -> void:
	var keys: Array[String] = []
	for m: Dictionary in [
		_legacy_member("2873092675", "Zephyr Flynn"),
		_legacy_member("888575640", "Lieutenant Casey Flynn"),
		_modern_member("char_1", "Bryn Ito"),
		{"character_name": "Nameless Ned"},
	]:
		var k: String = CrewTaskComponentScript.crew_key(m)
		assert_array(keys).override_failure_message(
			"key %s was already used by another crew member" % k).not_contains([k])
		keys.append(k)


# ── T9-39: the dialog has to fit on the screen ────────────────────────────────

## The blocker. The confirm dialog was built with a bare autowrapping Label and
## `popup_centered()` with no size, so it grew to its content: measured on the
## tablet at taller than the whole 1600px screen with BOTH buttons off the bottom
## edge. There is no keyboard on a tablet, so the World Phase could not be
## advanced at all — the campaign turn was unfinishable.
func test_the_confirm_dialog_always_fits_inside_the_viewport() -> void:
	var viewports: Array = [
		Vector2(2560, 1600),   # the test tablet, landscape
		Vector2(1600, 2560),   # the same tablet, portrait
		Vector2(1080, 1080),   # the project's square design base
		Vector2(640, 360),     # a small phone in landscape
	]
	for vp: Vector2 in viewports:
		var size: Vector2i = CrewTaskComponentScript.confirm_dialog_size(vp)
		assert_bool(size.x <= int(vp.x)).override_failure_message(
			"dialog width %d exceeds the %d-wide viewport" % [size.x, int(vp.x)]).is_true()
		assert_bool(size.y <= int(vp.y)).override_failure_message(
			"dialog height %d exceeds the %d-tall viewport — this is exactly how "
			% [size.y, int(vp.y)]
			+ "the buttons ended up off-screen and blocked the turn").is_true()


## A viewport reported as tiny must not collapse the dialog to nothing, or the
## buttons become untappable a different way.
func test_the_confirm_dialog_keeps_a_usable_floor() -> void:
	var size: Vector2i = CrewTaskComponentScript.confirm_dialog_size(Vector2(10, 10))
	assert_int(size.x).is_greater_equal(280)
	assert_int(size.y).is_greater_equal(200)


# ── T9-41: the equipment id the transfer service can actually match ───────────

## The silent one. Both transfer paths read `member.character_id`, which is absent
## on a legacy save, so `_persist_to_character("")` failed on its own empty-id
## guard — and the panel then removed the item from the stash and showed it on the
## character anyway. The screen reported a transfer the campaign never recorded.
##
## `EquipmentTransferService._find_crew_member()` matches on `character_id` OR
## `id`, so the service could always have found these members; the caller never
## handed it anything to look up.
func test_the_equipment_transfer_resolves_a_legacy_members_id() -> void:
	var key: String = AssignEquipmentComponentScript._character_key(
		_legacy_member("2873092675", "Zephyr Flynn"))
	assert_str(key).override_failure_message(
		"an empty id here is what made _persist_to_character() fail its own "
		+ "guard, while the UI moved the item regardless").is_equal("2873092675")


func test_the_equipment_transfer_still_prefers_character_id_when_present() -> void:
	var m: Dictionary = _modern_member("char_498964_9495", "Bryn Ito")
	assert_str(AssignEquipmentComponentScript._character_key(m)) \
		.is_equal("char_498964_9495")


## The id both components resolve must be the SAME one, or an item could be
## assigned to a member the task panel considers someone else.
func test_both_components_resolve_the_same_member_to_the_same_id() -> void:
	for m: Dictionary in [
		_legacy_member("2873092675", "Zephyr Flynn"),
		_modern_member("char_1", "Bryn Ito"),
	]:
		assert_str(AssignEquipmentComponentScript._character_key(m)) \
			.override_failure_message(
				"the two panels disagree about which id identifies this member") \
			.is_equal(CrewTaskComponentScript.crew_key(m))
