extends GdUnitTestSuite
## Pins the canonical LootTableResolver (Core Rules p.130-133): one roll resolves
## category -> subtable -> EXACT item. DAMAGED categories yield 2 repair-flagged items;
## rewards grant resources; no fabricated credit-pouch items. Canonical data:
## data/loot_tables.json (verified against the rulebook).
##
## (2026-06-01: retargeted from the now-removed EquipmentManager.generate_battle_loot —
## the loot resolver was consolidated into LootTableResolver, used by the live LootProcessor.)

const LootTableResolver = preload("res://src/core/equipment/LootTableResolver.gd")


func test_loot_resolves_all_categories_structurally() -> void:
	var saw_reward := false
	var saw_damaged := false
	for i in range(800):
		var loot: Array = LootTableResolver.roll_loot()
		assert_bool(loot.size() >= 1).is_true()
		for item in loot:
			assert_bool(item is Dictionary).is_true()
			if item.get("is_reward", false):
				saw_reward = true
				assert_bool(
					item.has("credits") or item.has("rumors")
					or item.has("story_points") or item.has("ship_component_discount")
				).is_true()
			else:
				assert_str(str(item.get("name", ""))).is_not_empty()
			if item.get("needs_repair", false):
				saw_damaged = true
	assert_bool(saw_reward).is_true()
	assert_bool(saw_damaged).is_true()


func test_damaged_results_come_in_pairs() -> void:
	for i in range(600):
		var loot: Array = LootTableResolver.roll_loot()
		if not loot.is_empty() and loot[0] is Dictionary and loot[0].get("needs_repair", false):
			assert_int(loot.size()).is_equal(2)


func test_no_fabricated_credit_pouch_loot() -> void:
	for i in range(300):
		for item in LootTableResolver.roll_loot():
			var nm := str(item.get("name", ""))
			assert_bool(nm.contains("Credit Pouch")).is_false()
			assert_bool(nm.contains("Credit Stick")).is_false()
