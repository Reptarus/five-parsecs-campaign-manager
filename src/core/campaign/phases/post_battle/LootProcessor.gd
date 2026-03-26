class_name PostBattleLootProcessor
extends RefCounted

## Loot gathering and inventory management for Post-Battle Phase.
## Handles Step 7: Gather the Loot (Core Rules p.85)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterRef = preload("res://src/core/character/Character.gd")

func process_loot_gathering(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Roll on loot tables for each defeated enemy. Returns gathered loot array.
	var gathered_loot: Array[Dictionary] = []

	for enemy in ctx.defeated_enemies:
		var enemy_loot: Array[Dictionary] = _roll_enemy_loot(enemy)
		if enemy_loot.size() > 0:
			gathered_loot.append_array(enemy_loot)

	for loot_item in gathered_loot:
		_add_loot_to_inventory(ctx, loot_item)

	# Journal: log loot gathered
	if gathered_loot.size() > 0 and ctx.campaign_journal \
			and ctx.campaign_journal.has_method("create_entry"):
		var item_names: Array = []
		for item in gathered_loot:
			item_names.append(item.get("description", item.get("type", "item")))
		ctx.campaign_journal.create_entry({
			"type": "loot",
			"auto_generated": true,
			"title": "Loot: %d items gathered" % gathered_loot.size(),
			"description": ", ".join(item_names),
			"tags": ["loot", "post_battle"],
			"stats": {"item_count": gathered_loot.size()},
		})

	return gathered_loot

func _roll_enemy_loot(enemy: Dictionary) -> Array[Dictionary]:
	## Roll for loot from a single defeated enemy
	## using Core Rules Loot Table (D100, pp.131-134).
	var loot: Array[Dictionary] = []
	var enemy_type: String = enemy.get("type", "basic")

	# Higher-tier enemies have better loot chance
	var loot_chance: int = 5  # D6 threshold
	match enemy_type:
		"elite":
			loot_chance = 4
		"boss":
			loot_chance = 3

	if randi_range(1, 6) < loot_chance:
		return loot

	# Roll on Core Rules D100 Loot Table (pp.131-134)
	var table_mgr := MissionTableManager.new()
	var category: Dictionary = table_mgr.roll_loot_category()
	var cat_type: String = category.get("category", "REWARDS")

	match cat_type:
		"WEAPON":
			loot.append({"type": "weapon",
				"quality": "standard",
				"description": "Weapon (Loot Table)",
				"loot_roll": category.get("roll", 0)})
		"DAMAGED_WEAPONS":
			loot.append({"type": "weapon",
				"quality": "damaged",
				"description": "Damaged weapon (needs Repair)",
				"needs_repair": true,
				"loot_roll": category.get("roll", 0)})
		"DAMAGED_GEAR":
			loot.append({"type": "gear",
				"quality": "damaged",
				"description": "Damaged gear (needs Repair)",
				"needs_repair": true,
				"loot_roll": category.get("roll", 0)})
		"GEAR":
			loot.append({"type": "gear",
				"quality": "standard",
				"description": "Gear (Loot Table)",
				"loot_roll": category.get("roll", 0)})
		"ODDS_AND_ENDS":
			loot.append({"type": "odds_and_ends",
				"quality": "basic",
				"description": "Odds and Ends",
				"loot_roll": category.get("roll", 0)})
		"REWARDS":
			var reward: Dictionary = table_mgr.roll_rewards_subtable()
			loot.append({"type": "reward",
				"reward_type": reward.get("type", "SCRAP"),
				"description": reward.get("effect", ""),
				"loot_roll": category.get("roll", 0),
				"reward_roll": reward.get("roll", 0)})

	return loot

func _add_loot_to_inventory(ctx: PostBattleContextClass, loot_item: Dictionary) -> void:
	## Add loot to inventory. Attempts implant installation first.
	var loot_name: String = loot_item.get("name", loot_item.get("description", ""))
	# Check if loot is an implant (uses JSON-loaded data via Character.create_implant_from_loot)
	var implant_check: Dictionary = CharacterRef.create_implant_from_loot(loot_name)
	if not implant_check.is_empty():
		if _try_install_implant_from_loot(loot_name):
			return

	var equipment_data = loot_item.duplicate()
	if not equipment_data.has("id"):
		equipment_data["id"] = "loot_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	if not equipment_data.has("name"):
		equipment_data["name"] = equipment_data.get("description", "Unknown Loot")
	if not equipment_data.has("location"):
		equipment_data["location"] = "ship_stash"

	if ctx.game_state_manager and ctx.game_state_manager.has_method("add_to_ship_inventory"):
		ctx.game_state_manager.add_to_ship_inventory(equipment_data)
		return

	if ctx.game_state and ctx.game_state.has_method("add_inventory_item"):
		ctx.game_state.add_inventory_item(equipment_data)

func _try_install_implant_from_loot(loot_name: String) -> bool:
	## Attempt to install an implant from loot on an eligible crew member.
	## Uses Character.create_implant_from_loot() + add_implant() pipeline.
	## Returns true if installed, false if no eligible crew member found.
	var implant: Dictionary = CharacterRef.create_implant_from_loot(loot_name)
	if implant.is_empty():
		return false

	# Find an eligible crew member (under MAX_IMPLANTS limit, not a bot)
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	if not gs or not gs.current_campaign:
		return false

	var crew_members: Array = []
	if "crew_data" in gs.current_campaign:
		crew_members = gs.current_campaign.crew_data.get("members", [])

	for member in crew_members:
		if member is CharacterRef:
			if member.is_bot:
				continue  # Bots cannot receive implants
			if member.add_implant(implant):
				return true

	return false  # No eligible crew member found
