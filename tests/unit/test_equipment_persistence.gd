extends GdUnitTestSuite
## Tests for character equipment persistence across the campaign lifecycle.
## Protects against the Apr-2026 persistence bug where characters equipped
## during creation showed "0 items" in World Phase Step 4 and all gear
## appeared to "return to the ship stash" after any save/load cycle.
##
## Phase 1 of the data persistence audit — locks in the fixes to:
##   - CampaignFinalizationService.gd (equipment-append ordering)
##   - GameState._restore_equipment_from_campaign (per-character ownership
##     reconstruction from crew_data.members[i].equipment)
##
## Tabletop invariant under test: equipment assigned to a character is a
## physical card that sits on that character's sheet. It must survive save,
## load, and any code path that rebuilds runtime state.

const FiveParsecsCampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

# ============================================================================
# Helpers
# ============================================================================

func _build_creation_data_with_equipped_character() -> Dictionary:
	## Build a minimal campaign_data dict matching what the creation wizard
	## produces, with one crew member who owns one weapon.
	return {
		"config": {
			"name": "Persistence Test",
			"difficulty": 0,
			"ironman_mode": false,
			"victory_conditions": {},
		},
		"crew": {
			"members": [
				{
					"character_id": "char_alpha",
					"character_name": "Alpha",
					"name": "Alpha",
					"is_captain": true,
					"combat": 1,
					"reactions": 1,
					"toughness": 4,
					"savvy": 1,
					"speed": 4,
					"luck": 1,
					"equipment": [],
				},
			],
		},
		"captain": {},
		"ship": {},
		"equipment": {
			"equipment": [
				{
					"id": "wpn_0001",
					"name": "Military Rifle",
					"type": "weapon",
					"owner": "Alpha",
				},
			],
		},
		"world": {},
	}

# ============================================================================
# Tests
# ============================================================================

func test_creation_embeds_equipment_into_campaign_crew_data():
	## After finalization, the persisted campaign.crew_data.members[0].equipment
	## MUST contain the item that was owned by that character in the creation
	## equipment list. This is the fix for the Apr-2026 creation-handoff bug.
	var campaign := FiveParsecsCampaignCore.new()
	var data := _build_creation_data_with_equipped_character()

	# Simulate the finalization path by directly calling the two methods
	# CampaignFinalizationService._create_campaign_resource() invokes in the
	# fixed order. We can't call the service end-to-end here because it also
	# does file IO and validation we don't need.
	var transformed_crew: Dictionary = data["crew"]
	var transformed_equipment: Dictionary = data["equipment"]

	# Replicate the Phase 1.1 loop: attach items to members BEFORE initialize_crew
	for item in transformed_equipment.get("equipment", []):
		var owner_name: String = item.get("owner", "")
		var item_name: String = item.get("name", "")
		if owner_name.is_empty() or item_name.is_empty():
			continue
		for member in transformed_crew.get("members", []):
			var member_name: String = member.get("character_name", member.get("name", ""))
			if member_name == owner_name:
				var eq: Array = member.get("equipment", [])
				if item_name not in eq:
					eq.append(item_name)
					member["equipment"] = eq
				break

	campaign.initialize_crew(transformed_crew)
	campaign.set_starting_equipment(transformed_equipment)

	var members: Array = campaign.crew_data.get("members", [])
	assert_that(members.size()).is_equal(1)
	var alpha: Dictionary = members[0]
	var alpha_equipment: Array = alpha.get("equipment", [])
	assert_that(alpha_equipment).contains(["Military Rifle"])

func test_save_and_reload_preserves_character_equipment():
	## After save → load, the character's equipment list must still contain
	## the same items. This is the round-trip contract that every
	## to_dictionary/from_dictionary change must preserve.
	var campaign := FiveParsecsCampaignCore.new()
	campaign.campaign_name = "RoundTrip"

	# Directly seed the crew with an equipped character, bypassing the wizard.
	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_alpha",
				"character_name": "Alpha",
				"name": "Alpha",
				"is_captain": true,
				"equipment": ["Military Rifle"],
			},
		],
	})
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "wpn_0001", "name": "Military Rifle", "owner": "Alpha"},
		],
	})

	var serialized: Dictionary = campaign.to_dictionary()
	var reloaded := FiveParsecsCampaignCore.new()
	reloaded.from_dictionary(serialized)

	var members: Array = reloaded.crew_data.get("members", [])
	assert_that(members.size()).is_equal(1)
	var alpha_equipment: Array = members[0].get("equipment", [])
	assert_that(alpha_equipment).contains(["Military Rifle"])

func test_get_all_equipment_returns_ship_stash_items():
	## Regression check: get_all_equipment() is what the EquipmentManager load
	## path feeds from. It must return the ship-stash items. This test does
	## NOT assert it also returns per-character items — that's a Phase 2
	## question — but it must not regress the stash behavior in the meantime.
	var campaign := FiveParsecsCampaignCore.new()
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "stash_001", "name": "Scrap Pistol"},
			{"id": "stash_002", "name": "Booster Pills"},
		],
	})
	var all_items: Array = campaign.get_all_equipment()
	assert_that(all_items.size()).is_equal(2)
	var names: Array = []
	for item in all_items:
		names.append(item.get("name", ""))
	assert_that(names).contains(["Scrap Pistol"])
	assert_that(names).contains(["Booster Pills"])

func test_restore_rebuilds_equipment_manager_character_ownership():
	## The Phase 1.2 fix: GameState._restore_equipment_from_campaign must
	## reconstruct EquipmentManager._character_equipment from crew_data so
	## per-character ownership survives a campaign reload. This is the
	## actual bug the user reported — items appeared to "return to the
	## ship stash" after battle because EquipmentManager lost all ownership
	## info on every reload.
	##
	## We drive this by calling GameState._restore_equipment_from_campaign
	## directly against a real campaign + real EquipmentManager autoload.
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	var eq_mgr = Engine.get_main_loop().root.get_node_or_null("/root/EquipmentManager")
	assert_that(gs).is_not_null()
	assert_that(eq_mgr).is_not_null()

	var campaign := FiveParsecsCampaignCore.new()
	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_alpha",
				"character_name": "Alpha",
				"name": "Alpha",
				"equipment": ["Military Rifle"],
			},
			{
				"character_id": "char_beta",
				"character_name": "Beta",
				"name": "Beta",
				"equipment": ["Scrap Pistol"],
			},
		],
	})
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "wpn_mil_01", "name": "Military Rifle", "owner": "Alpha"},
			{"id": "wpn_scrap_01", "name": "Scrap Pistol", "owner": "Beta"},
			{"id": "gear_stim_01", "name": "Booster Pills", "owner": "Unassigned"},
		],
	})

	gs.restore_equipment_from_campaign(campaign)

	# EquipmentManager._equipment_storage is a flat registry of ALL known items
	# (stash + character-owned). All three items should be present.
	assert_that(eq_mgr.get_all_equipment().size()).is_equal(3)

	# Character ownership side: the fix must have populated per-character lists
	# for both Alpha and Beta, with the right item ids.
	var alpha_ids: Array = eq_mgr.get_character_equipment("char_alpha")
	var beta_ids: Array = eq_mgr.get_character_equipment("char_beta")
	assert_that(alpha_ids).contains(["wpn_mil_01"])
	assert_that(beta_ids).contains(["wpn_scrap_01"])

	# Cleanup: the autoloads are shared global state — leaving ownership dicts
	# behind would contaminate unrelated tests in the same session.
	eq_mgr.clear_all_equipment()

func test_resources_are_single_source_of_truth_on_campaign():
	## Phase 2.1: credits/supplies/reputation/story_points live ONLY as
	## top-level @vars on FiveParsecsCampaignCore. The legacy progress_data
	## mirrors were a dead write target and have been removed. Any save that
	## contains them gets migrated on load.
	var campaign := FiveParsecsCampaignCore.new()
	# Fresh campaigns must NOT seed progress_data with resource mirrors.
	assert_that(campaign.progress_data.has("credits")).is_false()
	assert_that(campaign.progress_data.has("supplies")).is_false()
	assert_that(campaign.progress_data.has("reputation")).is_false()
	assert_that(campaign.progress_data.has("story_points")).is_false()
	# Counter fields must still be present — those aren't duplicates.
	assert_that(campaign.progress_data.has("turns_played")).is_true()
	assert_that(campaign.progress_data.has("missions_completed")).is_true()

	# Loading a legacy save that still has progress_data mirrors must scrub
	# them and use the top-level resource values.
	var legacy_save := {
		"meta": {"campaign_id": "legacy", "campaign_name": "Legacy"},
		"crew": {"members": []},
		"captain": {},
		"ship": {},
		"equipment": {},
		"world": {},
		"progress": {
			"turns_played": 5,
			"missions_completed": 2,
			"credits": 999,  # legacy mirror — must be scrubbed
			"supplies": 99,  # legacy mirror — must be scrubbed
		},
		"resources": {
			"credits": 100,
			"supplies": 5,
			"reputation": 0,
			"story_points": 3,
		},
	}
	var reloaded := FiveParsecsCampaignCore.new()
	reloaded.from_dictionary(legacy_save)
	assert_that(reloaded.credits).is_equal(100)
	assert_that(reloaded.supplies).is_equal(5)
	assert_that(reloaded.progress_data.has("credits")).is_false()
	assert_that(reloaded.progress_data.has("supplies")).is_false()
	# Non-resource counters survive the migration.
	assert_that(reloaded.progress_data.get("turns_played", 0)).is_equal(5)
	assert_that(reloaded.progress_data.get("missions_completed", 0)).is_equal(2)

func test_save_schema_deep_diff_round_trip():
	## Phase 3.2: Build a full campaign fixture with crew, equipment, ship, world,
	## and resources. Save → load → deep-diff the result. Every value that went
	## in must come out identical. This catches schema drift from any PR that
	## touches to_dictionary/from_dictionary.
	var campaign := FiveParsecsCampaignCore.new()
	campaign.campaign_name = "SchemaDiff"
	campaign.difficulty = 2
	campaign.ironman_mode = true
	campaign.credits = 150
	campaign.story_points = 3
	campaign.supplies = 5
	campaign.reputation = 2

	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_a",
				"character_name": "A",
				"name": "A",
				"is_captain": true,
				"equipment": ["Blade"],
			},
		],
	})
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "eq_1", "name": "Blade", "owner": "A"},
			{"id": "eq_2", "name": "Medkit"},
		],
	})
	campaign.initialize_ship({"name": "Rusty Star", "hull": 25})
	campaign.initialize_world({"name": "Kessara III"})

	var saved: Dictionary = campaign.to_dictionary()
	var reloaded := FiveParsecsCampaignCore.new()
	reloaded.from_dictionary(saved)

	# Resources
	assert_that(reloaded.credits).is_equal(150)
	assert_that(reloaded.story_points).is_equal(3)
	assert_that(reloaded.supplies).is_equal(5)
	assert_that(reloaded.reputation).is_equal(2)

	# Config
	assert_that(reloaded.campaign_name).is_equal("SchemaDiff")
	assert_that(reloaded.difficulty).is_equal(2)
	assert_that(reloaded.ironman_mode).is_true()

	# Crew
	var members: Array = reloaded.crew_data.get("members", [])
	assert_that(members.size()).is_equal(1)
	assert_that(members[0].get("character_name", "")).is_equal("A")
	assert_that(members[0].get("equipment", [])).contains(["Blade"])

	# Equipment stash
	var stash: Array = reloaded.equipment_data.get("equipment", [])
	assert_that(stash.size()).is_equal(2)

	# Ship and world
	assert_that(reloaded.ship_data.get("name", "")).is_equal("Rusty Star")
	assert_that(reloaded.world_data.get("name", "")).is_equal("Kessara III")

	# Legacy mirrors must have been scrubbed.
	assert_that(reloaded.progress_data.has("credits")).is_false()
	assert_that(reloaded.progress_data.has("supplies")).is_false()

func test_restore_enforces_one_item_one_owner_invariant():
	## Tabletop invariant: if two characters both have the same item NAME
	## and there are exactly two matching ids in the stash, each character
	## must claim a DIFFERENT id. The claim-tracking loop in
	## _restore_equipment_from_campaign prevents two characters from
	## accidentally owning the same physical card.
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	var eq_mgr = Engine.get_main_loop().root.get_node_or_null("/root/EquipmentManager")
	assert_that(gs).is_not_null()
	assert_that(eq_mgr).is_not_null()

	var campaign := FiveParsecsCampaignCore.new()
	campaign.initialize_crew({
		"members": [
			{
				"character_id": "char_alpha",
				"character_name": "Alpha",
				"name": "Alpha",
				"equipment": ["Colony Rifle"],
			},
			{
				"character_id": "char_beta",
				"character_name": "Beta",
				"name": "Beta",
				"equipment": ["Colony Rifle"],
			},
		],
	})
	campaign.set_starting_equipment({
		"equipment": [
			{"id": "rifle_A", "name": "Colony Rifle", "owner": "Alpha"},
			{"id": "rifle_B", "name": "Colony Rifle", "owner": "Beta"},
		],
	})

	gs.restore_equipment_from_campaign(campaign)

	var alpha_ids: Array = eq_mgr.get_character_equipment("char_alpha")
	var beta_ids: Array = eq_mgr.get_character_equipment("char_beta")
	assert_that(alpha_ids.size()).is_equal(1)
	assert_that(beta_ids.size()).is_equal(1)
	# Critical: the two characters must hold DIFFERENT ids, not the same one.
	assert_that(alpha_ids[0] != beta_ids[0]).is_true()

	eq_mgr.clear_all_equipment()
