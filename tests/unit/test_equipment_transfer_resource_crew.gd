extends GdUnitTestSuite
## EquipmentTransferService against a RESOURCE-shaped crew (fresh campaign).
##
## Crew members are Dictionaries on a loaded save but Character RESOURCES on a
## freshly-created campaign — and a Character's `equipment` is a typed
## Array[String]. The service moves Dictionary-shaped items. Appending a
## Dictionary to an Array[String], or assigning an untyped Array to one, is a
## runtime error in Godot 4 that aborts the enclosing function.
##
## These cases exist to establish, empirically, what the service actually does
## with the fresh-campaign shape before the Assign Equipment step is wired to
## call it for the first time.

const TransferService = preload("res://src/core/equipment/EquipmentTransferService.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

func _campaign_with_resource_crew() -> Resource:
	var core: Resource = CampaignCoreScript.new()
	var c: Resource = CharacterScript.new()
	c.character_id = "crew_1"
	c.character_name = "Vex"
	core.crew_data = {"members": [c]}
	core.equipment_data = {"equipment": [
		{"id": "itm_1", "name": "Rattle Gun", "type": "weapon"},
	]}
	return core

func _campaign_with_dict_crew() -> Resource:
	var core: Resource = CampaignCoreScript.new()
	core.crew_data = {"members": [
		{"character_id": "crew_1", "character_name": "Vex", "equipment": []},
	]}
	core.equipment_data = {"equipment": [
		{"id": "itm_1", "name": "Rattle Gun", "type": "weapon"},
	]}
	return core

# ── The shape that already worked ────────────────────────────────────────

func test_dict_crew_receives_the_item_as_a_card() -> void:
	var core: Resource = _campaign_with_dict_crew()
	var svc = TransferService.new(core)
	assert_bool(svc.transfer_to_character("itm_1", "crew_1")).is_true()
	var eq: Array = core.crew_data["members"][0]["equipment"]
	assert_int(eq.size()).is_equal(1)
	assert_str(str((eq[0] as Dictionary).get("name", ""))).is_equal("Rattle Gun")
	assert_int((core.equipment_data["equipment"] as Array).size()).override_failure_message(
		"one item, one home: it must have left the stash").is_equal(0)

# ── The fresh-campaign shape ─────────────────────────────────────────────

func test_resource_crew_receives_the_item_at_all() -> void:
	# The tabletop invariant is "one item, one home". Whatever representation the
	# typed array forces, the item must end up ON the character and OUT of the
	# stash — never vanish, never sit in both places.
	var core: Resource = _campaign_with_resource_crew()
	var svc = TransferService.new(core)
	var ok: bool = svc.transfer_to_character("itm_1", "crew_1")
	var member: Resource = core.crew_data["members"][0]
	var eq: Array = member.equipment
	var stash: Array = core.equipment_data["equipment"]

	assert_bool(ok).override_failure_message(
		"transfer_to_character must succeed for a fresh-campaign Resource crew").is_true()
	assert_int(eq.size()).override_failure_message(
		"the item must land on the character's sheet").is_equal(1)
	assert_int(stash.size()).override_failure_message(
		"the item must leave the stash — one item, one home").is_equal(0)

func test_resource_crew_round_trips_the_item_back_to_the_stash() -> void:
	var core: Resource = _campaign_with_resource_crew()
	var svc = TransferService.new(core)
	assert_bool(svc.transfer_to_character("itm_1", "crew_1")).is_true()
	assert_bool(svc.transfer_to_stash("itm_1", "crew_1")).override_failure_message(
		"an item put on a Resource-shaped character must be removable again").is_true()

	var member: Resource = core.crew_data["members"][0]
	assert_int((member.equipment as Array).size()).is_equal(0)
	var stash: Array = core.equipment_data["equipment"]
	assert_int(stash.size()).is_equal(1)
	# IDENTITY, not full fidelity. A typed Array[String] physically cannot hold
	# the rest of the card, so the round trip preserves the item's ID and the app
	# re-resolves the rest through EquipmentManager. Asserting the id is the
	# honest contract here; asserting the full record would be asserting
	# something the names model cannot deliver without new storage.
	assert_str(str((stash[0] as Dictionary).get("id", ""))).override_failure_message(
		"the card's identity must survive a Resource-crew round trip").is_equal("itm_1")

func test_no_duplicate_home_after_a_resource_transfer() -> void:
	# GameState.verify_consistency CHECK 4 enforces this globally; assert it
	# locally so a regression names the transfer as the culprit.
	var core: Resource = _campaign_with_resource_crew()
	var svc = TransferService.new(core)
	svc.transfer_to_character("itm_1", "crew_1")
	var member: Resource = core.crew_data["members"][0]
	var on_char: int = (member.equipment as Array).size()
	var in_stash: int = (core.equipment_data["equipment"] as Array).size()
	assert_int(on_char + in_stash).override_failure_message(
		"the item exists in exactly one place, never zero and never two").is_equal(1)
