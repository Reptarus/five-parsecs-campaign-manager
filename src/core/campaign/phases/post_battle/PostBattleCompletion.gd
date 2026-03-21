class_name PostBattleCompletion
extends RefCounted

## Completion, statistics, journal entries, and morale for Post-Battle Phase.
## Handles Step 14b: finalization after all 14 steps complete.
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const MoraleSystemRef = preload("res://src/core/systems/MoraleSystem.gd")

func update_character_lifetime_statistics(ctx: PostBattleContextClass) -> void:
	## Update character lifetime statistics from battle results (kills, damage, participation)
	var crew: Array = ctx.get_participating_crew()
	if crew.is_empty():
		return

	var kills_by_character: Dictionary = ctx.battle_result.get("kills_by_character", {})
	var damage_dealt_per_unit: Dictionary = ctx.battle_result.get("damage_dealt_per_unit", {})
	var damage_taken_per_unit: Dictionary = ctx.battle_result.get("damage_taken_per_unit", {})
	var units_downed: Array = ctx.battle_result.get("units_downed", [])

	for member in crew:
		if not member:
			continue

		var char_id: String = ""
		if member is Object and member.has_method("get"):
			char_id = member.get("character_id") if member.get("character_id") else ""
		elif member is Dictionary:
			char_id = member.get("character_id", "")

		if char_id.is_empty():
			continue

		if member is Object and "battles_participated" in member:
			member.battles_participated += 1
			if char_id not in units_downed:
				member.battles_survived += 1
			var kills: Array = kills_by_character.get(char_id, [])
			member.lifetime_kills += kills.size()
			member.lifetime_damage_dealt += damage_dealt_per_unit.get(char_id, 0)
			member.lifetime_damage_taken += damage_taken_per_unit.get(char_id, 0)
			_create_character_battle_journal_event(ctx, member, char_id, kills.size())

func create_battle_journal_entry(ctx: PostBattleContextClass) -> void:
	## Create a journal entry for the completed battle
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("auto_create_battle_entry"):
		return
	var crew_ids: Array = []
	for participant in ctx.crew_participants:
		if participant is String:
			crew_ids.append(participant)
	ctx.campaign_journal.auto_create_battle_entry({
		"turn": ctx.battle_result.get("turn", 0),
		"location": ctx.battle_result.get("location", "Unknown"),
		"outcome": "victory" if ctx.mission_successful else "defeat",
		"casualties": ctx.injuries_sustained.size(),
		"loot": ctx.loot_earned.size(),
		"xp": ctx.battle_result.get("xp_earned", 0),
		"crew_ids": crew_ids,
		"enemy_type": ctx.battle_result.get("enemy_type", "Unknown")
	})

func apply_post_battle_morale(ctx: PostBattleContextClass) -> void:
	## Apply crew morale adjustments after battle using MoraleSystem.
	var campaign = ctx.campaign
	if not campaign and ctx.game_state:
		campaign = ctx.game_state.current_campaign if "current_campaign" in ctx.game_state else null
	if not campaign or not "crew_morale" in campaign:
		return

	var crew_deaths := 0
	var crew_injuries := ctx.injuries_sustained.size()
	for injury in ctx.injuries_sustained:
		if injury is Dictionary and injury.get("is_fatal", false):
			crew_deaths += 1
	crew_injuries = maxi(0, crew_injuries - crew_deaths)

	var held := ctx.battle_result.get("held_field", false) if ctx.battle_result is Dictionary else false

	MoraleSystemRef.apply_post_battle_morale(
		campaign, ctx.mission_successful, crew_deaths, crew_injuries, held
	)

func _create_character_battle_journal_event(ctx: PostBattleContextClass, member: Variant, char_id: String, kills: int) -> void:
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("auto_create_character_event"):
		return

	var outcome: String = "survived"
	if member is Object and member.has_method("get"):
		var status: String = member.get("status") if member.get("status") else "ACTIVE"
		if status == "DEAD":
			outcome = "killed"
		elif status == "INJURED" or status == "RECOVERING":
			outcome = "injured"
		elif status == "MISSING":
			outcome = "missing"

	ctx.campaign_journal.auto_create_character_event(char_id, "battle", {
		"kills": kills,
		"outcome": outcome,
		"mission_success": ctx.mission_successful,
		"turn": ctx.battle_result.get("turn", 0)
	})
