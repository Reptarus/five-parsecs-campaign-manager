extends GdUnitTestSuite
## Downstream of T9-47: the SAME String-vs-Dictionary trap, found by sweeping for
## the class rather than waiting for it on hardware.
##
## `CharacterEventEffects._get_character_equipment()` returns two element shapes.
## A Character Resource holds `Array[String]` (Character.gd:129), but a crew
## member that has been through save/load is a Dictionary whose `equipment` holds
## full item Dictionaries — verified in a save pulled off the tablet Aug 13 2026 —
## and crew members are canonically Dictionaries, so that is the COMMON case.
##
## Two p.130 Character Events assigned such an element straight into a `: String`
## variable:
##     var damaged_item: String = equip_list[dmg_idx]          (:614)
##     lost_item_name       = equip_for_loss[loss_idx]         (:635)
## In Godot that is a runtime type error, which ABORTS the enclosing function.
## Silently: the app keeps running, the event simply never happens — no status
## effect, no item removed, no return text. For "Where Did It Go" the abort lands
## BEFORE the removal on the following lines, so the item is neither lost nor
## recoverable.
##
## These tests drive the real effect dispatcher with the real device item shape.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const CharacterEventEffectsScript = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const PostBattleContextScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")


## The exact entry pulled from the tablet save, verbatim.
func _device_item() -> Dictionary:
	return {
		"condition": "damaged",
		"id": "military_rifle_3495_8386",
		"name": "Military Rifle",
		"owner": "Zephyr Flynn",
		"quality_modifier": -1.0,
		"source": "shared_pool",
		"source_table": "crew_base",
		"type": "Weapon",
	}


func _dict_crew_member() -> Dictionary:
	return {
		"character_name": "Zephyr Flynn",
		"name": "Zephyr Flynn",
		"equipment": [_device_item()],
		"status_effects": [],
	}


func _effects() -> RefCounted:
	return CharacterEventEffectsScript.new()


func _ctx() -> RefCounted:
	return PostBattleContextScript.new()


# ── the name resolver itself ─────────────────────────────────────────────────

func test_a_dictionary_entry_resolves_to_its_name() -> void:
	assert_str(_effects()._equipment_entry_name(_device_item())).is_equal(
		"Military Rifle")


func test_a_plain_string_entry_is_unchanged() -> void:
	# The Character Resource shape must keep working — regression guard.
	assert_str(_effects()._equipment_entry_name("Scrap Pistol")).is_equal(
		"Scrap Pistol")


func test_a_nameless_entry_falls_back_to_its_id_not_the_dict() -> void:
	var name: String = _effects()._equipment_entry_name({"id": "odd_widget_1"})
	assert_str(name).is_equal("odd_widget_1")
	assert_bool(name.contains("{")).override_failure_message(
		"a serialized Dictionary would reach the event's description text"
		).is_false()


# ── and the two p.130 events actually run to completion ──────────────────────
#
# The handlers return a non-empty summary string on success. An aborted GDScript
# function yields null, so a null/empty return IS the abort — that is what these
# assert, on the dictionary-shaped crew member that triggers it.

func test_the_item_damaged_event_completes_on_a_saved_crew_member() -> void:
	var member: Dictionary = _dict_crew_member()
	var result: Variant = _effects().apply_effect(
		"Don't Make Them Like They Used To", member, _ctx())
	assert_that(result).override_failure_message(
		"a null return means the handler ABORTED — `var damaged_item: String = "
		+ "equip_list[i]` against a Dictionary element. The p.130 event then "
		+ "applies no status effect at all.").is_not_null()
	assert_str(str(result)).is_not_empty()
	assert_str(str(result)).override_failure_message(
		"the description must name the item, not serialize it").contains(
		"Military Rifle")
	assert_bool(str(result).contains("quality_modifier")).is_false()


func test_the_item_lost_event_completes_and_removes_the_item() -> void:
	var member: Dictionary = _dict_crew_member()
	var result: Variant = _effects().apply_effect(
		"Where Did It Go", member, _ctx())
	assert_that(result).override_failure_message(
		"a null return means the handler ABORTED at the String assignment — and "
		+ "that abort lands BEFORE the removal, so the item is neither lost nor "
		+ "recoverable").is_not_null()
	assert_str(str(result)).contains("Military Rifle")
	assert_int((member["equipment"] as Array).size()).override_failure_message(
		"p.130 'Where Did It Go' loses a random item — the removal is on the "
		+ "lines after the assignment that used to abort").is_equal(0)


func test_both_events_still_work_on_the_resource_string_shape() -> void:
	# A fresh campaign holds Array[String]; neither event may regress there.
	var member: Dictionary = {
		"character_name": "Dex Jones", "name": "Dex Jones",
		"equipment": ["Scrap Pistol"], "status_effects": [],
	}
	var damaged: Variant = _effects().apply_effect(
		"Don't Make Them Like They Used To", member, _ctx())
	assert_str(str(damaged)).contains("Scrap Pistol")

	var member2: Dictionary = {
		"character_name": "Dex Jones", "name": "Dex Jones",
		"equipment": ["Scrap Pistol"], "status_effects": [],
	}
	var lost: Variant = _effects().apply_effect("Where Did It Go", member2, _ctx())
	assert_str(str(lost)).contains("Scrap Pistol")
	assert_int((member2["equipment"] as Array).size()).is_equal(0)


func test_a_crew_member_with_no_equipment_is_handled() -> void:
	var member: Dictionary = {
		"character_name": "Drew Thorne", "name": "Drew Thorne",
		"equipment": [], "status_effects": [],
	}
	assert_that(_effects().apply_effect(
		"Don't Make Them Like They Used To", member, _ctx())).is_not_null()
	assert_that(_effects().apply_effect(
		"Where Did It Go", member, _ctx())).is_not_null()
