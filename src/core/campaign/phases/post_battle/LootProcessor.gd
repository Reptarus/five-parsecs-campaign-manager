class_name PostBattleLootProcessor
extends RefCounted

## Loot gathering and inventory management for Post-Battle Phase.
## Handles Step 7: Gather the Loot (Core Rules p.85)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterRef = preload("res://src/core/character/Character.gd")
const LootTableResolver = preload("res://src/core/equipment/LootTableResolver.gd")

func process_loot_gathering(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Step 7 "Gather the Loot" (Core Rules p.120): roll ONCE on the Loot Table per battle.
	## Invasion battles grant no loot; finishing a Quest's final stage grants 3 rolls.
	##
	## 2026-06-01 rules-accuracy fix: the previous implementation rolled loot PER DEFEATED
	## ENEMY behind a fabricated D6 "loot_chance" tier gate (5/4/3 for basic/elite/boss).
	## That is not in the rulebook — loot is one roll per battle, not per kill.
	var gathered_loot: Array[Dictionary] = []

	var roll_count: int = 1
	if ctx.battle_result.get("is_invasion", false):
		roll_count = 0  # Core Rules p.120: "If you just played an Invasion Battle, you receive no Loot."
	elif ctx.battle_result.get("quest_final_stage", ctx.battle_result.get("is_quest_final", false)):
		roll_count = 3  # Core Rules p.120: final stage of a Quest -> roll three times, claim all.

	for _i in range(roll_count):
		gathered_loot.append_array(_roll_loot_table())

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

## Roll once on the canonical Core Rules Loot Table (p.130-134) via LootTableResolver,
## which resolves the EXACT item from data/loot_tables.json (category -> subtable -> item;
## DAMAGED categories yield two repair-flagged items; rewards grant resources).
## 2026-06-01: replaced the prior MissionTableManager category-only placeholders ("Weapon
## (Loot Table)") with specific named items from the single canonical loot resolver.
func _roll_loot_table() -> Array[Dictionary]:
	return LootTableResolver.roll_loot()

func _add_loot_to_inventory(ctx: PostBattleContextClass, loot_item: Dictionary) -> void:
	## Add loot to inventory. Rewards grant resources (not items); implants try to install first.
	# Rewards Subtable results (Core Rules p.133) grant credits/rumors/story points, not
	# carried items — apply them to the campaign instead of adding a junk "Reward" item.
	if loot_item.get("is_reward", false):
		_apply_loot_reward(ctx, loot_item)
		return

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

func _apply_loot_reward(ctx: PostBattleContextClass, reward: Dictionary) -> void:
	## Apply a Rewards-Subtable result (Core Rules p.133): credits / rumors / story points.
	## (ship_component_discount has no purchase-discount system yet — recorded via journal only.)
	var credits: int = int(reward.get("credits", 0))
	if credits > 0:
		if ctx.game_state and ctx.game_state.has_method("add_credits"):
			ctx.game_state.add_credits(credits)
		elif ctx.game_state_manager and ctx.game_state_manager.has_method("add_credits"):
			ctx.game_state_manager.add_credits(credits)
	var story_points: int = int(reward.get("story_points", 0))
	if story_points > 0:
		ctx.add_story_points(story_points)
	var rumors: int = int(reward.get("rumors", 0))
	for _r in range(rumors):
		ctx.add_quest_rumor()


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
