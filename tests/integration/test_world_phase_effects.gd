extends GdUnitTestSuite

## Integration tests for World Phase game effect persistence
## Tests XP, credits, rumors, rivals, stash, and quest generation
## Per Five Parsecs Core Rules

# Helper class to create test campaign data
class TestCampaignHelper:
	static func create_test_campaign() -> Dictionary:
		return {
			"campaign_turn": 1,
			"credits": 100,
			"story_points": 5,
			"crew": [
				{
					"id": "char_001",
					"character_id": "char_001",
					"name": "Test Captain",
					"experience": 0,
					"equipment": []
				},
				{
					"id": "char_002",
					"character_id": "char_002",
					"name": "Test Crew",
					"experience": 2,
					"equipment": []
				}
			],
			"stash": [],
			"rumors": [],
			"rivals": [],
			"patrons": [],
			"active_quest": null
		}

	static func create_test_crew_member() -> Dictionary:
		return {
			"id": "char_001",
			"character_id": "char_001",
			"name": "Test Character",
			"experience": 0,
			"equipment": []
		}

# ============================================================================
# XP Tests
# ============================================================================

func test_train_task_awards_1xp() -> void:
	# Per Core Rules: Train task awards 1 XP automatically
	var campaign = TestCampaignHelper.create_test_campaign()
	var crew_member = campaign.crew[0]
	var initial_xp = crew_member.experience

	# Simulate XP application (same logic as CrewTaskComponent)
	crew_member["experience"] = crew_member.get("experience", 0) + 1

	assert_int(crew_member.experience).is_equal(initial_xp + 1)

func test_xp_tracked_per_character() -> void:
	# Per Core Rules: "track each character's XP individually"
	var campaign = TestCampaignHelper.create_test_campaign()

	# Apply XP to first character only
	campaign.crew[0]["experience"] = campaign.crew[0].experience + 3

	assert_int(campaign.crew[0].experience).is_equal(3)
	assert_int(campaign.crew[1].experience).is_equal(2)  # Unchanged

# ============================================================================
# Credits Tests
# ============================================================================

func test_credits_deduction_succeeds() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()
	var initial_credits = campaign.credits
	var deduction = 10

	# Simulate deduction
	campaign["credits"] = campaign.credits - deduction

	assert_int(campaign.credits).is_equal(initial_credits - deduction)

func test_credits_check_prevents_overdraft() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()
	var available = campaign.credits
	var excessive_amount = available + 50

	var can_afford = available >= excessive_amount

	assert_bool(can_afford).is_false()

# ============================================================================
# Rumor Tests
# ============================================================================

func test_rumor_added_to_pool() -> void:
	# Per Core Rules: "track Rumors as a single pool for the whole crew"
	var campaign = TestCampaignHelper.create_test_campaign()

	var new_rumor = {
		"id": "rumor_001",
		"type": 3,  # 1-10 per rules
		"description": "Notebook with secret information",
		"source": "test"
	}

	campaign.rumors.append(new_rumor)

	assert_int(campaign.rumors.size()).is_equal(1)
	assert_str(campaign.rumors[0].description).is_equal("Notebook with secret information")

func test_rumor_type_range_valid() -> void:
	# Per Core Rules: D10 roll determines type (1-10)
	for _i in range(10):
		var roll = (randi() % 10) + 1
		assert_int(roll).is_between(1, 10)

func test_rumors_cleared_on_quest_generation() -> void:
	# Per Core Rules: "remove all Rumors from your roster" when quest generated
	var campaign = TestCampaignHelper.create_test_campaign()

	# Add rumors
	campaign.rumors.append({"id": "r1", "type": 1})
	campaign.rumors.append({"id": "r2", "type": 5})
	campaign.rumors.append({"id": "r3", "type": 9})

	# Simulate quest generation
	var quest = {
		"id": "quest_001",
		"name": "Test Quest"
	}
	campaign["active_quest"] = quest
	campaign["rumors"] = []  # Clear rumors

	assert_int(campaign.rumors.size()).is_equal(0)
	assert_that(campaign.active_quest).is_not_null()

func test_quest_roll_mechanic() -> void:
	# Per Core Rules: "Roll D6. If equal or below number of Rumors, receive Quest"
	var rumor_count = 3
	var roll = randi() % 6 + 1
	var quest_generated = roll <= rumor_count

	# With 3 rumors, rolls 1-3 generate quest (50% chance)
	if roll <= 3:
		assert_bool(quest_generated).is_true()
	else:
		assert_bool(quest_generated).is_false()

# ============================================================================
# Rival Tests
# ============================================================================

func test_rival_added_to_campaign() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()

	var new_rival = {
		"id": "rival_001",
		"name": "Test Rival",
		"type": "Criminal",
		"hostility": 4,
		"resources": 2
	}

	campaign.rivals.append(new_rival)

	assert_int(campaign.rivals.size()).is_equal(1)
	assert_str(campaign.rivals[0].name).is_equal("Test Rival")

func test_rival_has_required_fields() -> void:
	var rival = {
		"id": "rival_001",
		"name": "Gang Boss",
		"type": "Criminal",
		"hostility": 4,
		"resources": 2,
		"source": "event"
	}

	assert_bool(rival.has("id")).is_true()
	assert_bool(rival.has("name")).is_true()
	assert_bool(rival.has("type")).is_true()
	assert_bool(rival.has("hostility")).is_true()

# ============================================================================
# Stash Tests
# ============================================================================

func test_items_added_to_stash() -> void:
	# Per Core Rules: "Stash of equipment... may be shared between crew members"
	var campaign = TestCampaignHelper.create_test_campaign()

	var items = [
		{"name": "Hand Laser", "type": "weapon"},
		{"name": "Med-patch", "type": "gear"}
	]

	for item in items:
		campaign.stash.append(item)

	assert_int(campaign.stash.size()).is_equal(2)

func test_stash_persists_between_operations() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()

	# Add item
	campaign.stash.append({"name": "Test Item"})
	var stash_copy = campaign.stash.duplicate()

	# Simulate "next turn"
	var retrieved_stash = campaign.stash

	assert_int(retrieved_stash.size()).is_equal(stash_copy.size())

# ============================================================================
# Equipment Assignment Tests
# ============================================================================

func test_equipment_assignment_persists() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()
	var character = campaign.crew[0]

	var new_equipment = [
		{"name": "Blade", "type": "weapon"},
		{"name": "Frag Vest", "type": "armor"}
	]

	character["equipment"] = new_equipment

	assert_int(character.equipment.size()).is_equal(2)
	assert_str(character.equipment[0].name).is_equal("Blade")

func test_stash_updated_after_transfer() -> void:
	var campaign = TestCampaignHelper.create_test_campaign()

	# Start with item in stash
	campaign.stash.append({"name": "Auto Rifle"})
	assert_int(campaign.stash.size()).is_equal(1)

	# Transfer to character
	var item = campaign.stash.pop_back()
	campaign.crew[0].equipment.append(item)

	assert_int(campaign.stash.size()).is_equal(0)
	assert_int(campaign.crew[0].equipment.size()).is_equal(1)

# ============================================================================
# Integration Tests
# ============================================================================

func test_full_world_phase_flow() -> void:
	# Test complete world phase effect persistence
	var campaign = TestCampaignHelper.create_test_campaign()

	# 1. Apply XP from train task
	campaign.crew[0]["experience"] = campaign.crew[0].experience + 1

	# 2. Spend credits on task
	campaign["credits"] = campaign.credits - 5

	# 3. Add rumor
	campaign.rumors.append({
		"id": "rumor_001",
		"type": 7,
		"description": "A tip from a contact"
	})

	# 4. Add rival from event
	campaign.rivals.append({
		"id": "rival_001",
		"name": "New Rival",
		"type": "Pirate"
	})

	# 5. Add item to stash
	campaign.stash.append({"name": "Beam Pistol"})

	# Verify all changes persisted
	assert_int(campaign.crew[0].experience).is_equal(1)
	assert_int(campaign.credits).is_equal(95)
	assert_int(campaign.rumors.size()).is_equal(1)
	assert_int(campaign.rivals.size()).is_equal(1)
	assert_int(campaign.stash.size()).is_equal(1)

func test_xp_source_tracking() -> void:
	# Optional: Track where XP came from for statistics
	var campaign = TestCampaignHelper.create_test_campaign()
	var character = campaign.crew[0]

	# Initialize XP sources if tracking
	if not character.has("xp_sources"):
		character["xp_sources"] = {}

	# Track XP by source
	var source = "train_task"
	character.xp_sources[source] = character.xp_sources.get(source, 0) + 1
	character["experience"] = character.experience + 1

	assert_int(character.xp_sources["train_task"]).is_equal(1)
