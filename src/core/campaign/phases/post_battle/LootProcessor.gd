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

	return gathered_loot

func _roll_enemy_loot(enemy: Dictionary) -> Array[Dictionary]:
	## Roll for loot from a single defeated enemy.
	var loot: Array[Dictionary] = []
	var enemy_type: String = enemy.get("type", "basic")

	match enemy_type:
		"elite":
			if randi_range(1, 6) >= 4:
				loot.append({"type": "weapon", "quality": "advanced", "description": "Elite weapon"})
		"boss":
			if randi_range(1, 6) >= 3:
				loot.append({"type": "special", "quality": "rare", "description": "Boss loot"})
		_:
			if randi_range(1, 6) >= 5:
				loot.append({"type": "equipment", "quality": "basic", "description": "Standard gear"})

	return loot

func _add_loot_to_inventory(ctx: PostBattleContextClass, loot_item: Dictionary) -> void:
	## Add loot to inventory. Attempts implant installation first.
	var loot_name: String = loot_item.get("name", loot_item.get("description", ""))
	if CharacterRef.LOOT_TO_IMPLANT_MAP.has(loot_name):
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

func _try_install_implant_from_loot(_loot_name: String) -> bool:
	## Attempt to install an implant from loot on an eligible crew member.
	return false
