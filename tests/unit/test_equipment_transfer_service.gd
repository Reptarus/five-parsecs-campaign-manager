extends GdUnitTestSuite
## Tests for EquipmentTransferService — the Phase 2.2 chokepoint for all
## equipment movement between the ship stash and character sheets.
##
## Every test is an assertion about the tabletop "one card, one home"
## invariant: items exist in exactly one place at any time, transfers are
## atomic, and ids are stable.

const FiveParsecsCampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const EquipmentTransferService := preload("res://src/core/equipment/EquipmentTransferService.gd")

# ============================================================================
# Helpers
# ============================================================================

func _make_campaign_with_crew_and_stash() -> FiveParsecsCampaignCore:
	var campaign := FiveParsecsCampaignCore.new()
	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_alpha",
				"character_name": "Alpha",
				"name": "Alpha",
				"equipment": [],
			},
			{
				"character_id": "char_beta",
				"character_name": "Beta",
				"name": "Beta",
				"equipment": [],
			},
		],
	})
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "rifle_01", "name": "Military Rifle"},
			{"id": "pistol_01", "name": "Scrap Pistol"},
			{"id": "pills_01", "name": "Booster Pills"},
		],
	})
	return campaign

# ============================================================================
# transfer_to_character
# ============================================================================

func test_transfer_to_character_moves_item_from_stash_to_sheet():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)

	assert_that(svc.transfer_to_character("rifle_01", "char_alpha")).is_true()

	# Stash should now contain 2 items, not 3.
	var stash: Array = campaign.equipment_data["equipment"]
	assert_that(stash.size()).is_equal(2)
	var stash_ids: Array = []
	for item in stash:
		stash_ids.append(item.get("id", ""))
	assert_that(stash_ids).contains(["pistol_01"])
	assert_that(stash_ids).contains(["pills_01"])
	assert_that(stash_ids.has("rifle_01")).is_false()

	# Alpha should now own the rifle.
	var alpha: Dictionary = campaign.crew_data["members"][0]
	assert_that(alpha["equipment"].size()).is_equal(1)
	assert_that(alpha["equipment"][0].get("id", "")).is_equal("rifle_01")

func test_transfer_to_missing_character_rolls_back():
	## Invariant: if the target character doesn't exist, the item MUST still
	## be in the stash after the failed transfer (no lost cards).
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)

	assert_that(svc.transfer_to_character("rifle_01", "char_nonexistent")).is_false()

	var stash: Array = campaign.equipment_data["equipment"]
	assert_that(stash.size()).is_equal(3)
	var still_has_rifle := false
	for item in stash:
		if item.get("id", "") == "rifle_01":
			still_has_rifle = true
			break
	assert_that(still_has_rifle).is_true()

func test_transfer_unknown_item_id_fails_cleanly():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)
	assert_that(svc.transfer_to_character("no_such_id", "char_alpha")).is_false()
	# Stash and Alpha's sheet both unchanged.
	assert_that(campaign.equipment_data["equipment"].size()).is_equal(3)
	assert_that(campaign.crew_data["members"][0]["equipment"].size()).is_equal(0)

# ============================================================================
# transfer_to_stash
# ============================================================================

func test_transfer_to_stash_moves_item_from_character_back_to_pool():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)
	# Seed Alpha with an item first
	svc.transfer_to_character("rifle_01", "char_alpha")
	assert_that(campaign.equipment_data["equipment"].size()).is_equal(2)

	assert_that(svc.transfer_to_stash("rifle_01", "char_alpha")).is_true()
	assert_that(campaign.equipment_data["equipment"].size()).is_equal(3)
	assert_that(campaign.crew_data["members"][0]["equipment"].size()).is_equal(0)

# ============================================================================
# transfer_between_characters
# ============================================================================

func test_transfer_between_characters_atomic():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)
	svc.transfer_to_character("rifle_01", "char_alpha")

	assert_that(svc.transfer_between_characters("rifle_01", "char_alpha", "char_beta")).is_true()
	var alpha_eq: Array = campaign.crew_data["members"][0]["equipment"]
	var beta_eq: Array = campaign.crew_data["members"][1]["equipment"]
	assert_that(alpha_eq.size()).is_equal(0)
	assert_that(beta_eq.size()).is_equal(1)
	assert_that(beta_eq[0].get("id", "")).is_equal("rifle_01")

func test_transfer_between_characters_rolls_back_on_missing_target():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)
	svc.transfer_to_character("rifle_01", "char_alpha")

	assert_that(svc.transfer_between_characters("rifle_01", "char_alpha", "ghost")).is_false()
	# Alpha must still have the rifle — it was never allowed to leave until
	# the target was confirmed.
	var alpha_eq: Array = campaign.crew_data["members"][0]["equipment"]
	assert_that(alpha_eq.size()).is_equal(1)
	assert_that(alpha_eq[0].get("id", "")).is_equal("rifle_01")

# ============================================================================
# add_loot_to_stash
# ============================================================================

func test_add_loot_to_stash_assigns_id_when_missing():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)

	var assigned_id: String = svc.add_loot_to_stash({"name": "Frag Grenade"})
	assert_that(assigned_id).is_not_empty()

	var stash: Array = campaign.equipment_data["equipment"]
	assert_that(stash.size()).is_equal(4)
	var found := false
	for item in stash:
		if item.get("id", "") == assigned_id:
			assert_that(item.get("name", "")).is_equal("Frag Grenade")
			found = true
			break
	assert_that(found).is_true()

func test_add_loot_to_stash_preserves_caller_id():
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)
	var returned: String = svc.add_loot_to_stash({"id": "loot_fixed", "name": "Shard"})
	assert_that(returned).is_equal("loot_fixed")

# ============================================================================
# generate_starting_loadout
# ============================================================================

func test_generate_starting_loadout_seeds_character_without_stash_round_trip():
	## Campaign creation path: items go directly on the character, NOT
	## through the ship stash. This is what CampaignFinalizationService will
	## call in Phase 2.4.
	var campaign := FiveParsecsCampaignCore.new()
	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_alpha",
				"character_name": "Alpha",
				"name": "Alpha",
				"equipment": [],
			},
		],
	})
	# NOTE: no starting_equipment set — the service should not touch the stash.
	var svc := EquipmentTransferService.new(campaign)
	var count: int = svc.generate_starting_loadout("char_alpha", [
		{"name": "Colony Rifle"},
		{"name": "Blade"},
	])
	assert_that(count).is_equal(2)

	var alpha: Dictionary = campaign.crew_data["members"][0]
	var alpha_eq: Array = alpha["equipment"]
	assert_that(alpha_eq.size()).is_equal(2)
	# Each item should have received an auto-generated id.
	for item in alpha_eq:
		assert_that(str(item.get("id", ""))).is_not_empty()
		assert_that(str(item.get("name", ""))).is_not_empty()

	# The stash should not have been touched.
	var stash = campaign.equipment_data.get("equipment", [])
	assert_that(stash.size()).is_equal(0)

# ============================================================================
# Tabletop "one card, one home" invariant
# ============================================================================

func test_invariant_item_never_exists_in_two_places():
	## After any sequence of valid transfers, an item must appear on exactly
	## one character OR in the ship stash — never both.
	var campaign := _make_campaign_with_crew_and_stash()
	var svc := EquipmentTransferService.new(campaign)

	svc.transfer_to_character("rifle_01", "char_alpha")
	svc.transfer_between_characters("rifle_01", "char_alpha", "char_beta")
	svc.transfer_to_stash("rifle_01", "char_beta")
	svc.transfer_to_character("rifle_01", "char_alpha")

	var locations: int = 0
	for item in campaign.equipment_data["equipment"]:
		if item.get("id", "") == "rifle_01":
			locations += 1
	for member in campaign.crew_data["members"]:
		for item in member.get("equipment", []):
			if item is Dictionary and item.get("id", "") == "rifle_01":
				locations += 1
	assert_that(locations).is_equal(1)
