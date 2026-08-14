extends GdUnitTestSuite
## T9-47 (tablet, Aug 13 2026) — a crew-task event announced
## "Discarded: Military Rifle" and removed nothing.
##
## The Explore result "Get in a bad fight - 2 turns in Sick Bay, lose one item"
## opened the discard dialog, whose button was labelled with a whole serialized
## Dictionary:
##     { "condition": "damaged", "id": "military_rifle_3495_8386",
##       "name": "Military Rifle", "owner": "Zephyr Flynn", ... }
## That looked like a display bug. It was not.
##
## The label IS the identifier: it is bound into the button's callback, becomes
## `_outcome["discarded_item"]`, and is handed to
## `CrewTaskComponent._remove_from_crew_equipment()`, which matched with
## `if item_name in equip` — a String tested against Dictionaries. Never equal,
## so the erase never ran.
##
## PROVEN AGAINST THE DEVICE SAVE, not inferred: Zephyr Flynn's `equipment` array
## is byte-identical before and after the event. Every p.82 item loss routed
## through this dialog was unenforceable.
##
## An equipment array legitimately holds EITHER shape — plain names (what
## `Character.to_dictionary()` emits) or full item Dictionaries (what the live
## save carries) — so both are covered here.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const CrewTaskEventDialogScript = preload(
	"res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
const CrewTaskComponentScript = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")


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


func _component() -> Node:
	var c: Node = auto_free(CrewTaskComponentScript.new())
	return c


# ── the label the player reads is the identifier the code matches ────────────

func test_a_dictionary_item_shows_its_name_not_its_serialization() -> void:
	var label: String = CrewTaskEventDialogScript.item_display_name(_device_item())
	assert_str(label).override_failure_message(
		"the discard/sell/trade lists label their controls with this; a raw "
		+ "Dictionary renders the whole item into the button").is_equal(
		"Military Rifle")
	assert_bool(label.contains("{")).override_failure_message(
		"a serialized Dictionary reached a user-facing label").is_false()
	assert_bool(label.contains("quality_modifier")).is_false()


func test_a_plain_string_item_is_unchanged() -> void:
	# The other legal shape must keep working — this is the regression guard.
	assert_str(CrewTaskEventDialogScript.item_display_name("Scrap Pistol")).is_equal(
		"Scrap Pistol")


func test_an_item_with_no_name_falls_back_to_its_id_not_the_dict() -> void:
	var label: String = CrewTaskEventDialogScript.item_display_name(
		{"id": "odd_widget_1", "type": "Gear"})
	assert_str(label).is_equal("odd_widget_1")
	assert_bool(label.contains("{")).is_false()


# ── and the removal actually happens ─────────────────────────────────────────

func test_the_p82_item_loss_is_actually_applied_to_a_dictionary_shaped_item() -> void:
	var crew: Dictionary = {"equipment": [_device_item()]}
	var comp: Node = _component()
	comp._remove_from_crew_equipment(
		crew, CrewTaskEventDialogScript.item_display_name(_device_item()))
	assert_int((crew["equipment"] as Array).size()).override_failure_message(
		"the dialog said 'Discarded: Military Rifle' and the crew member kept it "
		+ "— measured on the tablet, this array was byte-identical before and "
		+ "after the event").is_equal(0)


func test_the_item_loss_still_works_on_a_plain_string_array() -> void:
	var crew: Dictionary = {"equipment": ["Scrap Pistol", "Blade"]}
	var comp: Node = _component()
	comp._remove_from_crew_equipment(crew, "Scrap Pistol")
	assert_array(crew["equipment"]).is_equal(["Blade"])


func test_only_one_copy_is_removed() -> void:
	# "lose one item" means one, even when the crew member carries duplicates.
	var crew: Dictionary = {"equipment": [_device_item(), _device_item()]}
	var comp: Node = _component()
	comp._remove_from_crew_equipment(crew, "Military Rifle")
	assert_int((crew["equipment"] as Array).size()).is_equal(1)


func test_removing_something_not_carried_changes_nothing() -> void:
	var crew: Dictionary = {"equipment": [_device_item()]}
	var comp: Node = _component()
	comp._remove_from_crew_equipment(crew, "Auto Rifle")
	assert_int((crew["equipment"] as Array).size()).is_equal(1)
	comp._remove_from_crew_equipment(crew, "")
	assert_int((crew["equipment"] as Array).size()).override_failure_message(
		"an empty name must not remove an arbitrary item").is_equal(1)


func test_the_mixed_shape_array_resolves_both_entries() -> void:
	# Nothing guarantees an array is homogeneous — a save migrated mid-campaign
	# can hold both, and the matcher must not abort on the shape it did not expect.
	var crew: Dictionary = {"equipment": ["Blade", _device_item()]}
	var comp: Node = _component()
	comp._remove_from_crew_equipment(crew, "Military Rifle")
	assert_array(crew["equipment"]).is_equal(["Blade"])
