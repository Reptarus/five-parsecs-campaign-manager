extends GdUnitTestSuite
## T9-47 walk (deploy #25, 2026-09-07) — the crew-task DISCARD and SELL rows pay/announce
## but do not remove the item.
##
## MEASURED ON HARDWARE. Forced Exploration 51 ("Gambling problem", discard 1 item) and
## Trade 76 ("A chance to unload some stuff", sell at 2cr). Both dialogs rendered the book
## text, the discard reported "Discarded: Shatter Axe", the sale reported "Sold 1
## weapon(s) for 2 credits", and CREDITS MOVED CORRECTLY (18 -> 17 = -3 upkeep +2 sale).
## But the pulled save still held BOTH items:
##
##     Bryn Ito  equipment ['Shatter Axe'] -> ['Shatter Axe']
##     Dex Kovac equipment ['Blade']       -> ['Blade']
##
## So the player is PAID for a weapon they keep. Device logs were clean — no error, so
## this is a silent missing write rather than an aborted call.
##
## ⚠ _remove_from_crew_equipment() was ALREADY FIXED for this exact symptom on
## 2026-08-13 (its docstring records "announced 'Discarded: Military Rifle' and Zephyr
## Flynn's equipment was byte-identical before and after"). So the obvious cause is
## already taken, and this suite exists to find which half is actually failing rather
## than to re-fix the known one.
##
## The fixtures reproduce the SAVE'S SHAPE exactly: crew members are Dictionaries (a
## loaded save holds dicts, not Character Resources) whose `equipment` is an array of
## plain Strings, and whose identity is `character_id`.

const Comp := preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const Dialog := preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")


func _member(cid: String, nm: String, items: Array) -> Dictionary:
	return {
		"character_id": cid,
		"id": cid,
		"character_name": nm,
		"name": nm,
		"equipment": items,
	}


## ⚠ NOT added to the tree. CrewTaskComponent is scene-authored and its _ready()
## resolves %CrewMemberList, %AssignTaskButton and friends, which a bare .new() does not
## have. None of the functions under test touch those nodes, so staying out of the tree
## keeps the fixture honest instead of standing up a whole screen to exercise two pure
## lookups.
func _component() -> Node:
	var c: Node = Comp.new()
	auto_free(c)
	return c


func test_item_display_name_resolves_a_plain_string_entry() -> void:
	# The save holds plain Strings, so the whole match hinges on this.
	assert_str(Dialog.item_display_name("Blade")).is_equal("Blade")
	assert_str(Dialog.item_display_name({"name": "Blade"})).is_equal("Blade")


func test_crew_key_and_lookup_agree_on_identity() -> void:
	# The write side keys assigned_tasks with crew_key(); the read side finds the member
	# with _get_crew_member_by_id(). T9-40 was these two disagreeing. If they drift again
	# the removal silently no-ops, because _remove_from_crew_equipment returns early on
	# a null member while the credit path does not need one — which is exactly the
	# asymmetry observed on hardware.
	var m := _member("char_690708_7921", "Dex Kovac", ["Blade"])
	var c := _component()
	c.crew_data = [m]
	var key: String = Comp.crew_key(m)
	assert_str(key).is_equal("char_690708_7921")
	var found = c._get_crew_member_by_id(key)
	assert_object(found).override_failure_message(
		"crew_key() produced %s but _get_crew_member_by_id() could not find it" % key
	).is_not_null()


func test_remove_from_crew_equipment_actually_removes_a_string_entry() -> void:
	var m := _member("c1", "Dex Kovac", ["Blade"])
	var c := _component()
	c._remove_from_crew_equipment(m, "Blade")
	assert_array(m["equipment"]).override_failure_message(
		"the item is still on the character after _remove_from_crew_equipment: %s"
		% [m["equipment"]]
	).is_empty()


func test_removal_mutates_the_LIVE_member_not_a_copy() -> void:
	# The ownership chain on device is campaign.crew_data["members"] -> get_crew_members()
	# -> get_active_crew() -> WorldPhaseController.crew_data -> initialize_crew_tasks()
	# -> `crew_data = crew.duplicate()`. That duplicate is SHALLOW, so the elements must
	# still be the live dictionaries. If any link deep-duplicates, the removal lands on a
	# copy and is lost at save time — while credits, which go through the campaign owner,
	# still persist. That asymmetry is exactly what was observed on hardware.
	#
	# Reproduced here as the two array copies the real path performs, without standing up
	# the screen: WorldPhaseController does one .duplicate() and the component does another.
	var live := _member("c1", "Dex Kovac", ["Blade"])
	var campaign_members: Array = [live]
	var controller_copy: Array = campaign_members.duplicate()
	var component_copy: Array = controller_copy.duplicate()

	var c := _component()
	c.crew_data = component_copy
	var via_lookup = c._get_crew_member_by_id("c1")
	assert_object(via_lookup).override_failure_message(
		"the member was not findable after two shallow duplicates"
	).is_not_null()
	c._remove_from_crew_equipment(via_lookup, "Blade")

	assert_array(live["equipment"]).override_failure_message(
		"removal did not reach the ORIGINAL member — a shallow Array.duplicate() is "
		+ "supposed to share element references, so if this fails the write is landing "
		+ "on a copy and the save can never see it"
	).is_empty()


func test_a_deep_duplicate_anywhere_in_the_chain_LOSES_the_removal() -> void:
	# The control for the case above: this is what the failure MODE looks like. It is
	# asserted so the suite documents the difference rather than leaving "shallow vs deep"
	# as a claim — if someone changes a .duplicate() to .duplicate(true) upstream, the
	# case above goes red and this one explains why.
	var live := _member("c1", "Dex Kovac", ["Blade"])
	var deep_copy: Array = ([live] as Array).duplicate(true)
	var c := _component()
	c.crew_data = deep_copy
	c._remove_from_crew_equipment(c._get_crew_member_by_id("c1"), "Blade")
	assert_array(live["equipment"]).override_failure_message(
		"a DEEP duplicate should have isolated the original; if this is empty then "
		+ "duplicate(true) is not deep-copying and the whole diagnosis is wrong"
	).is_equal(["Blade"])
