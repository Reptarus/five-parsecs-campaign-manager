class_name CharacterEventEffects
extends RefCounted

## Character Event processing and effect application for Post-Battle Phase.
## Handles Step 13: Character Events (Core Rules p.128-130)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
## Core Rules p.131 Loot Table — the "Gift" event (72-75) rolls on it directly.
const LootTableResolver = preload("res://src/core/equipment/LootTableResolver.gd")
const EquipmentTransferServiceClass = preload("res://src/core/equipment/EquipmentTransferService.gd")

# Precursor event state (Core Rules p.128: Precursors roll twice, pick either)
var _pending_event1: Dictionary = {}
var _pending_event2: Dictionary = {}
var waiting_for_precursor_choice: bool = false

func process_character_event(ctx: PostBattleContextClass) -> Dictionary:
	## Roll for a character event. Returns the event dict with crew_id and roll.
	## Core Rules p.128: Roll on random non-Bot, non-Soulless crew member.
	## If the selected character is Precursor, roll twice and pick either.

	# Core Rules p.126, verbatim: "Select a random non-Bot, non-Soulless
	# character ... Any character is eligible, as long as they are part of your
	# crew, EVEN IF THEY ARE IN SICK BAY."
	#
	# This drew from ctx.crew_participants — the crew who FOUGHT the battle.
	# Injured crew are filtered out before deployment, so they were absent from
	# that list and could never be selected. That is precisely backwards for the
	# several table entries written for them: "You are starting to wonder if it
	# is time to move on" (11-12), "The local food is sitting well with you"
	# (24-26, which REDUCES recovery time) and "You've had a lot of time to burn"
	# (98-100, which explicitly acts even in Sick Bay) were unreachable by design.
	var eligible: Array = []
	var roster: Array = ctx.get_crew_members()
	for member in roster:
		var crew_id: String = ""
		if member is Dictionary:
			crew_id = str(member.get("character_id", member.get("id", "")))
		elif member != null and "character_id" in member:
			crew_id = str(member.character_id)
		if crew_id.is_empty():
			continue
		if not ctx.is_character_bot_or_soulless(crew_id):
			eligible.append(crew_id)
	# Defensive: if the roster could not be read, fall back to the battle's
	# participants rather than skipping the step entirely.
	if eligible.is_empty():
		for crew_id_fallback in ctx.crew_participants:
			if not ctx.is_character_bot_or_soulless(crew_id_fallback):
				eligible.append(crew_id_fallback)
	if eligible.is_empty():
		return {"type": "none", "name": "No Event"}

	var random_crew = eligible[randi() % eligible.size()]
	var event_roll: int = randi_range(1, 100)
	var character_event: Dictionary = _get_character_event(event_roll)
	character_event["crew_id"] = random_crew
	character_event["roll"] = event_roll

	# Precursor double-roll (Core Rules p.128)
	var origin: String = ctx.get_character_origin(random_crew).to_lower()
	if origin == "precursor":
		var second_roll: int = randi_range(1, 100)
		var second_event: Dictionary = _get_character_event(second_roll)
		second_event["crew_id"] = random_crew
		second_event["roll"] = second_roll

		_pending_event1 = character_event
		_pending_event2 = second_event
		waiting_for_precursor_choice = true
		return {"precursor_choice": true, "event1": character_event, "event2": second_event, "crew_id": random_crew}

	# Add species_exceptions from JSON entry for downstream handling
	character_event["character_origin"] = ctx.get_character_origin(
		random_crew)

	# Emo-suppressed: may ignore events requiring fights (Core Rules p.22)
	var crew_sid: String = ""
	if random_crew is Dictionary:
		crew_sid = random_crew.get("species_id", "").to_lower()
	elif random_crew is String and ctx.has_method("get_crew_member"):
		var member = ctx.get_crew_member(random_crew)
		if member:
			if member is Dictionary:
				crew_sid = member.get("species_id", "").to_lower()
			elif "species_id" in member:
				crew_sid = str(member.species_id).to_lower()
	if crew_sid == "emo_suppressed":
		character_event["can_ignore_fight"] = true

	return character_event

func select_precursor_event(choice: int) -> Dictionary:
	## Select which precursor event to use (1 or 2).
	if not waiting_for_precursor_choice:
		push_warning("CharacterEventEffects: select_precursor_event called but not waiting for choice")
		return {}
	waiting_for_precursor_choice = false
	var chosen: Dictionary = _pending_event2 if choice == 2 else _pending_event1
	_pending_event1 = {}
	_pending_event2 = {}
	return chosen

func _get_character_event(roll: int) -> Dictionary:
	## Get character event based on D100 roll from JSON data file (Core Rules p.128-130)
	var json_path: String = "res://data/campaign_tables/character_events.json"
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return {"type": "none", "name": "No Event"}
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return {"type": "none", "name": "No Event"}
	var data: Dictionary = json.data
	var entries: Array = data.get("entries", [])
	for entry in entries:
		var roll_range: Array = entry.get("roll_range", [0, 0])
		if roll >= roll_range[0] and roll <= roll_range[1]:
			var result: Dictionary = entry.get("result", {"type": "none", "name": "No Event"}).duplicate()
			# Attach species_exceptions from JSON for downstream use
			if entry.has("species_exceptions"):
				result["species_exceptions"] = entry["species_exceptions"]
			return result
	return {"type": "none", "name": "No Event"}

func finalize_event(event: Dictionary, ctx: PostBattleContextClass) -> void:
	## Apply the character event effects after rolling.
	if event.has("type") and event.type != "none":
		var crew: Variant = event.get("crew_id", ctx.get_random_crew_member())
		var event_name: String = event.get("name", event.get("title", "Unknown"))
		var origin: String = event.get("character_origin", "")
		if origin.is_empty() and crew:
			origin = ctx.get_character_origin(crew)
		var species_exceptions: Dictionary = event.get("species_exceptions", {})
		if crew:
			apply_effect(event_name, crew, ctx, origin, species_exceptions)
			# Journal: log character event
			if ctx.campaign_journal \
					and ctx.campaign_journal.has_method("auto_create_character_event"):
				var crew_id: String = crew if crew is String else str(crew)
				ctx.campaign_journal.auto_create_character_event(
					crew_id, "character_event", {
						"turn": ctx.battle_result.get("turn", 0),
						"event_name": event_name,
						"description": event.get("description", ""),
					})

func apply_effect(event_title: String, character: Variant, ctx: PostBattleContextClass, character_origin: String = "", species_exceptions: Dictionary = {}) -> String:
	## Apply character event effects based on event title (Core Rules p.128-130)
	## All 30 events from the D100 Character Events Table.
	## Species exceptions are checked here — if a species is "unaffected", the event is skipped.
	var char_name: String = ctx.get_char_name(character)
	var gsm = ctx.game_state_manager
	var origin: String = character_origin if not character_origin.is_empty() else ctx.get_character_origin(character)
	var origin_lower: String = origin.to_lower()

	# Check if this species is completely unaffected by this event
	if not species_exceptions.is_empty():
		for species_key in species_exceptions:
			if origin_lower == species_key.to_lower():
				var exception_text: String = species_exceptions[species_key]
				if "unaffected" in exception_text.to_lower() or "not affected" in exception_text.to_lower() or "no benefit" in exception_text.to_lower() or "cannot benefit" in exception_text.to_lower():
					# p.126, verbatim: "If an event is completely inapplicable,
					# simply add +1 XP to the character." A species that is
					# immune to the event IS that case — a K'Erin drawing "All
					# this endless violence is depressing you" used to receive
					# nothing at all instead of the book's fallback.
					ctx.add_character_xp(character, 1)
					return "%s (%s): Unaffected by '%s' — +1 XP instead (p.126)" % [
						char_name, origin, event_title]

	match event_title:
		"Violence is Depressing":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			ctx.apply_character_status_effect(character, {
				"type": "skip_next_battle",
				"name": "Violence is Depressing",
				"description": "Refuses battle next turn (except Invasion)",
				"duration": 1,
				"invasion_exception": true,
				"source_event": "Violence is Depressing"
			})
			return "%s refuses battle next turn (except Invasion). +1 Story Point" % char_name

		"Business Elsewhere":
			var xp_gain: int = randi_range(1, 6)
			if origin_lower == "swift":
				# Swift characters never return — mark as departed (Core Rules p.128)
				# Set status to DEPARTED so dashboard/upkeep/battle all exclude them
				if character is Resource and "status" in character:
					character.status = "DEPARTED"
				elif character is Dictionary:
					character["status"] = "DEPARTED"
				ctx.apply_character_status_effect(character, {
					"type": "departed",
					"name": "Business Elsewhere (Swift)",
					"description": "Swift character departed permanently. Replace with new Swift character.",
					"duration": -1,
					"source_event": "Business Elsewhere"
				})
				# Journal entry for departure
				if ctx.campaign_journal \
						and ctx.campaign_journal.has_method("create_entry"):
					var cid: String = ""
					if character is Resource and "character_id" in character:
						cid = str(character.character_id)
					elif character is Dictionary:
						cid = str(character.get("character_id", character.get("id", "")))
					ctx.campaign_journal.create_entry({
						"type": "character_event",
						"title": "%s Has Left the Crew" % char_name,
						"description": "%s (Swift) departed on business and will not return. Roll up a replacement Swift character." % char_name,
						"characters_involved": [cid] if cid != "" else [],
						"tags": ["character_event", "departure", "swift"],
						"auto_generated": true,
						"mood": "negative",
					})
				return "%s (Swift) has business elsewhere: Never returns. Replaced with new Swift character." % char_name
			ctx.apply_character_status_effect(character, {
				"type": "unavailable",
				"name": "Business Elsewhere",
				"description": "Unavailable for 2 turns. No Upkeep. Returns with %d XP + Loot roll." % xp_gain,
				"duration": 2,
				"no_upkeep": true,
				"return_xp": xp_gain,
				"return_loot_roll": 1,
				"source_event": "Business Elsewhere"
			})
			return "%s unavailable 2 turns (no Upkeep). Returns with %d XP + Loot roll" % [char_name, xp_gain]

		"Local Friends":
			ctx.add_character_xp(character, 1)
			return "%s made local friends: +1 XP" % char_name

		"Time to Move On":
			## p.128, 11-12: "If the character is currently in Sick Bay, roll 1D6.
			## If the roll is equal or below the number of campaign turns of
			## recovery left, they will decide to leave the crew."
			##
			## Was a bare description. The roll never happened, so nobody ever left
			## — and the rule is self-limiting by design: the longer the stay, the
			## likelier the departure, which is the whole point of the row.
			var remaining: int = ctx.get_member_recovery_turns(character)
			if remaining <= 0:
				return "%s thought about moving on, but is not in Sick Bay — no effect" % char_name
			var leave_roll: int = ctx.roll_d6("Time to Move On (%s)" % char_name)
			if leave_roll > remaining:
				return "%s considered leaving: rolled %d vs %d turns left — they stay" % [
					char_name, leave_roll, remaining]
			_mark_departed(character)
			if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
				ctx.campaign_journal.create_entry({
					"type": "character_departure",
					"auto_generated": true,
					"title": "Time to Move On",
					"description": "%s left the crew from Sick Bay (rolled %d vs %d turns remaining, Core Rules p.128)" % [
						char_name, leave_roll, remaining],
					"tags": ["departure", "character_event"],
				})
			return "%s LEAVES the crew: rolled %d vs %d turns of recovery left" % [
				char_name, leave_roll, remaining]

		"Letter from Home":
			ctx.add_character_xp(character, 1)
			var quest_roll: int = randi_range(1, 6)
			if quest_roll >= 5:
				ctx.add_quest_rumor()
				return "%s got letter from home: +1 XP, +1 Quest" % char_name
			return "%s got letter from home: +1 XP" % char_name

		"Argue with Crew":
			ctx.apply_character_status_effect(character, {
				"type": "skip_tasks",
				"name": "Argue with Crew",
				"description": "Refuses tasks next turn (battles OK)",
				"duration": 1,
				"source_event": "Argue with Crew"
			})
			return "%s argues with crew: Refuses tasks next turn (battles OK)" % char_name

		"Scrap with Crewmate":
			# Feeler: mental breakdown if involved in crew fight (Core Rules p.22)
			# "If the character ever ends up in a fight with another crew member,
			#  they have a mental breakdown, and will leave the crew immediately"
			var feeler_sid: String = _get_species_id(character, ctx)
			if feeler_sid == "feeler":
				# Log departure to journal
				if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
					ctx.campaign_journal.create_entry({
						"type": "character_departure",
						"auto_generated": true,
						"title": "Feeler Mental Breakdown",
						"description": "%s suffered a mental breakdown from a crew fight and left permanently (Core Rules p.22)" % char_name,
						"tags": ["feeler", "species_ability", "departure"],
					})
				# Mark character for removal — orchestrator handles actual crew removal
				if character is Resource and "status" in character:
					character.status = "departed"
				elif character is Dictionary:
					character["status"] = "departed"
				return "%s (Feeler) has a mental breakdown from crew fight and leaves permanently" % char_name
			## p.129, 20-23: "Randomly select another crew member and roll
			## 1D6+Combat Skill for each. The LOWER score must spend one campaign
			## turn in Sick Bay. On a draw, BOTH go to Sick Bay. If a K'Erin is in
			## the crew, you must fight them."
			##
			## The Feeler and K'Erin special cases above were both wired; the fight
			## itself was not. Both branches returned a description of a contest
			## that never happened, so nobody ever went to Sick Bay from it.
			var opponent: Variant = null
			if ctx.has_crew_with_origin("K'Erin") and origin_lower != "k'erin":
				opponent = _find_crew_with_origin(ctx, character, "k'erin")
			if opponent == null:
				opponent = _other_crew_member(ctx, character)
			if opponent == null:
				return "%s wanted a scrap but has no crewmates to fight" % char_name

			var opp_name: String = ctx.get_char_name(opponent)
			var a_score: int = ctx.roll_d6("Scrap: %s" % char_name) 				+ int(_member_field(character, "combat", 0))
			var b_score: int = ctx.roll_d6("Scrap: %s" % opp_name) 				+ int(_member_field(opponent, "combat", 0))

			if a_score == b_score:
				ctx.injure_specific_crew(character, 1)
				ctx.injure_specific_crew(opponent, 1)
				return "%s and %s brawled to a draw (%d each) — BOTH spend 1 turn in Sick Bay" % [
					char_name, opp_name, a_score]
			var loser: Variant = character if a_score < b_score else opponent
			var loser_name: String = char_name if a_score < b_score else opp_name
			ctx.injure_specific_crew(loser, 1)
			return "%s scrapped with %s (%d vs %d) — %s spends 1 turn in Sick Bay" % [
				char_name, opp_name, a_score, b_score, loser_name]
			return "%s in scrap: D6+Combat vs random crewmate. Loser to Sick Bay 1 turn (draw = both)" % char_name

		"Good Food":
			## p.129, 24-26: "If in Sick Bay, reduce your recovery time by one
			## campaign turn. If not, earn +1 XP. Engineers receive no benefit."
			##
			## Was an unconditional +1 XP: a character IN Sick Bay got the XP they
			## are not owed and kept the recovery turn they should have lost, and
			## Engineers got a benefit the book denies them.
			if origin_lower == "engineer":
				return "%s (Engineer) gains nothing from the local food (Core Rules p.129)" % char_name
			var sick_turns: int = ctx.get_member_recovery_turns(character)
			if sick_turns > 0:
				ctx.reduce_member_recovery(character, 1)
				return "%s: good food in Sick Bay — recovery %d -> %d turns" % [
					char_name, sick_turns, maxi(0, sick_turns - 1)]
			ctx.add_character_xp(character, 1)
			return "%s: the local food agrees with them — +1 XP" % char_name

		"Not the Same Person":
			return "%s rerolls Motivation (p.26). +1 XP per ability bonus. Same motivation = +1 Story Point" % char_name

		"Make-over":
			return "%s changes appearance (cosmetic only)" % char_name

		"Overhear Something Useful":
			ctx.add_quest_rumor()
			return "%s overheard something: +1 Quest Rumor" % char_name

		"Earn on the Side":
			if gsm:
				gsm.add_credits(2)
			return "%s earned on the side: +2 Credits" % char_name

		"Heart to Heart":
			## p.129, 42-45: "Select a random crew member. BOTH earn +1 XP."
			## Only the event's own character was paid; the crewmate the rule
			## exists to include got nothing.
			ctx.add_character_xp(character, 1)
			var confidant: Variant = _other_crew_member(ctx, character)
			if confidant == null:
				return "%s had a heart to heart with nobody aboard: +1 XP" % char_name
			ctx.add_character_xp(confidant, 1)
			return "%s and %s had a heart to heart: +1 XP each" % [
				char_name, ctx.get_char_name(confidant)]

		"Exercise":
			ctx.add_character_xp(character, 2)
			return "%s exercised: +2 XP" % char_name

		"Unusual Hobby":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			if origin_lower == "swift" or origin_lower == "precursor":
				ctx.add_character_xp(character, 2)
				return "%s (%s) picked up unusual hobby: +1 Story Point, +2 XP" % [char_name, origin]
			return "%s picked up unusual hobby: +1 Story Point" % char_name

		"Scars Tell the Story":
			## p.129, 52-55: "IF the character was injured in any way last or this
			## campaign turn, they earn +2 XP." The condition was printed and never
			## applied — an uninjured character collected 2 free XP, which is the
			## single largest unconditional XP source on the whole table.
			if not _was_injured_recently(character, ctx):
				return "%s has no fresh scars to tell of — no XP (Core Rules p.129)" % char_name
			ctx.add_character_xp(character, 2)
			return "%s: the scars tell the story — +2 XP" % char_name

		"Time to Reflect":
			var xp_roll: int = randi_range(1, 3)
			ctx.add_character_xp(character, xp_roll)
			return "%s reflected on adventures: +%d XP" % [char_name, xp_roll]

		"Personal Breakthrough":
			# Core Rules p.129: +1 to one non-increased ability.
			var raised: String = ctx.apply_random_ability_increase(character)
			if raised.is_empty():
				return "%s: Personal breakthrough, but all abilities are already at maximum" % char_name
			return "%s: Personal breakthrough. +1 %s" % [char_name, raised.capitalize()]

		"Hurt Working on Ship":
			ctx.injure_specific_crew(character, 1)
			if gsm and gsm.has_method("damage_hull"):
				gsm.damage_hull(1)
			return "%s hurt working on ship: 1 turn Sick Bay, ship -1 Hull" % char_name

		"Found True Love":
			## p.129, 67-68: "If the character's motivation was True Love, they earn
			## +1D6 XP. REGARDLESS, get +1 story point." The story point landed; the
			## motivation payout never did, so the one row on the table that rewards
			## a specific Motivation rewarded nothing.
			ctx.add_story_points(1)
			var motivation: String = str(_member_field(character, "motivation", "")).to_lower()
			if motivation.replace("_", " ") == "true love":
				var love_xp: int = ctx.roll_d6("True Love XP (%s)" % char_name)
				ctx.add_character_xp(character, love_xp)
				return "%s found true love — their Motivation: +%d XP and +1 Story Point" % [
					char_name, love_xp]
			return "%s found true love: +1 Story Point" % char_name

		"Personal Enemy":
			ctx.add_rival("%s's personal enemy" % char_name)
			return "%s: Personal enemy. +1 Rival (leaves if %s leaves crew)" % [char_name, char_name]

		"Gift":
			## p.129, 72-75: "Someone has sent you a gift. Roll once on the Loot
			## Table (p.131)." Was a bare description — the loot roll never
			## happened and the crew received nothing.
			var gift_items: Array = LootTableResolver.roll_loot()
			if gift_items.is_empty():
				return "%s received a gift, but the Loot Table yielded nothing" % char_name
			var names: Array[String] = []
			var campaign_ref: Variant = ctx.campaign
			var transfer = EquipmentTransferServiceClass.new(campaign_ref) if campaign_ref else null
			for item in gift_items:
				if not (item is Dictionary):
					continue
				names.append(str(item.get("name", "an item")))
				if transfer:
					transfer.add_loot_to_stash(item)
			return "%s received a gift: %s (added to the stash)" % [
				char_name, ", ".join(names)]

		"Feel Great":
			ctx.apply_character_status_effect(character, {
				"type": "ignore_next_injury",
				"name": "Feel Great",
				"description": "Next Injury Table roll is ignored",
				"duration": 1,
				"source_event": "Feel Great"
			})
			return "%s feels great: Next Injury Table roll is ignored" % char_name

		"Someone Who Knows Someone":
			ctx.add_patron()
			return "%s knows someone: +1 Patron" % char_name

		"Charmed Existence":
			# Core Rules p.129: +1 Luck (max 1, or 3 for Humans).
			if ctx.apply_luck_increase(character, 1):
				return "%s: Charmed existence. +1 Luck" % char_name
			return "%s: Charmed existence, but Luck is already at maximum" % char_name

		"Hard Work":
			if origin_lower == "engineer":
				return "%s (Engineer) put in hard work: Repair 2 Hull AND 1 damaged item" % char_name
			return "%s put in hard work: Repair 2 Hull OR 1 damaged item" % char_name

		"Don't Make Them Like They Used To":
			# Core Rules p.130: Random carried item damaged, must be Repaired.
			# Engineers are not affected (checked via species_exceptions upstream).
			var equip_list: Array = _get_character_equipment(character)
			if equip_list.size() > 0:
				var dmg_idx: int = randi() % equip_list.size()
				var damaged_item: String = equip_list[dmg_idx]
				ctx.apply_character_status_effect(character, {
					"type": "item_damaged",
					"name": "Don't Make Them Like They Used To",
					"description": "%s is damaged. Must be Repaired before use." % damaged_item,
					"duration": 0,
					"damaged_item": damaged_item,
					"source_event": "Don't Make Them Like They Used To"
				})
				return "%s: '%s' is damaged (must be Repaired)" % [char_name, damaged_item]
			return "%s: No items to damage" % char_name

		"Where Did It Go":
			# Core Rules p.130: Random item lost. Next turn D6+Savvy 5+ = returns.
			var equip_for_loss: Array = _get_character_equipment(character)
			var lost_item_name: String = "unknown item"
			if equip_for_loss.size() > 0:
				var loss_idx: int = randi() % equip_for_loss.size()
				lost_item_name = equip_for_loss[loss_idx]
				# Remove the item from equipment
				if character is Resource and "equipment" in character:
					var eq: Array = character.equipment
					if loss_idx < eq.size():
						eq.remove_at(loss_idx)
				elif character is Dictionary:
					var eq: Array = character.get("equipment", [])
					if loss_idx < eq.size():
						eq.remove_at(loss_idx)
			ctx.apply_character_status_effect(character, {
				"type": "item_lost_recovery",
				"name": "Where Did It Go",
				"description": "'%s' lost. Next turn: D6+Savvy, 5+ = returns." % lost_item_name,
				"duration": 1,
				"savvy_check_target": 5,
				"lost_item": lost_item_name,
				"source_event": "Where Did It Go"
			})
			return "%s lost '%s'. Next turn: D6+Savvy, 5+ = item returns" % [char_name, lost_item_name]

		"Melancholy":
			ctx.apply_character_status_effect(character, {
				"type": "no_xp",
				"name": "Melancholy",
				"description": "No XP next campaign turn",
				"duration": 1,
				"source_event": "Melancholy"
			})
			return "%s: Melancholy. No XP next campaign turn" % char_name

		"Time to Burn":
			ctx.apply_character_status_effect(character, {
				"type": "extra_action",
				"name": "Time to Burn",
				"description": "Extra action next turn (even in Sick Bay)",
				"duration": 1,
				"works_in_sick_bay": true,
				"source_event": "Time to Burn"
			})
			return "%s has time to burn: Extra action next turn (even in Sick Bay)" % char_name

		_:
			# p.126, verbatim: "In some cases, an event may end up not making any
			# sense. If so, tweak or ignore it, as necessary. If an event is
			# completely inapplicable, simply add +1 XP to the character."
			# An event title with no handler is exactly that case, and the
			# character used to walk away with nothing.
			ctx.add_character_xp(character, 1)
			return "%s: '%s' did not apply — +1 XP instead (Core Rules p.126)" % [
				char_name, event_title]


func _get_species_id(character: Variant, ctx: PostBattleContextClass) -> String:
	## Get species_id for a character (Resource, Dictionary, or crew_id String).
	if character is String:
		# It's a crew_id — look up the member
		if ctx.has_method("get_crew_member"):
			var member = ctx.get_crew_member(character)
			if member:
				return _get_species_id(member, ctx)
		return ""
	if character is Resource and "species_id" in character:
		return str(character.species_id).to_lower()
	elif character is Dictionary:
		return character.get("species_id", "").to_lower()
	return ""

func _get_character_equipment(character: Variant) -> Array:
	## Get the equipment array from a character (Resource or Dictionary).
	if character is Resource and "equipment" in character:
		return character.equipment
	elif character is Dictionary:
		return character.get("equipment", [])
	return []


## ── Helpers for the pp.128-130 events wired above ─────────────────────────────

func _member_field(character: Variant, key: String, default_value: Variant) -> Variant:
	## Crew members are canonically Dictionaries but a Character Resource still
	## reaches here on a fresh campaign. Dictionary.get takes 2 args and
	## Object.get takes 1, so the wrong form ABORTS the whole handler.
	if character is Dictionary:
		return character.get(key, default_value)
	if character != null and key in character:
		return character.get(key)
	return default_value


func _mark_departed(character: Variant) -> void:
	## Same shape the Feeler breakdown above already writes — the orchestrator
	## does the actual crew removal off `status`.
	if character is Dictionary:
		character["status"] = "departed"
	elif character != null and "status" in character:
		character.status = "departed"


func _other_crew_member(ctx: PostBattleContextClass, exclude: Variant) -> Variant:
	## A random crew member who is NOT the event's own character and is still
	## with the crew. Returns null on a one-person crew.
	var candidates: Array = []
	for member in ctx.get_crew_members():
		if member == exclude:
			continue
		var status: String = str(_member_field(member, "status", "")).to_lower()
		if status in ["dead", "departed", "retired", "missing"]:
			continue
		candidates.append(member)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _find_crew_with_origin(
		ctx: PostBattleContextClass, exclude: Variant, origin: String) -> Variant:
	var wanted: String = origin.to_lower()
	for member in ctx.get_crew_members():
		if member == exclude:
			continue
		var sid: String = str(_member_field(
			member, "species_id", _member_field(member, "origin", ""))).to_lower()
		if sid == wanted:
			return member
	return null


func _was_injured_recently(character: Variant, ctx: PostBattleContextClass) -> bool:
	## p.129 "injured in any way last or THIS campaign turn". Outstanding Sick Bay
	## time covers both windows: an injury taken this turn is still counting down,
	## and one taken last turn has at most been decremented once. An injuries[]
	## entry stamped with the current or previous turn also counts, which catches
	## a 0-turn injury (Knocked out, Equipment loss) that leaves no recovery time.
	if ctx.get_member_recovery_turns(character) > 0:
		return true
	var current_turn: int = int(ctx.battle_result.get("turn", 0))
	var injuries: Variant = _member_field(character, "injuries", [])
	if injuries is Array:
		for inj in injuries:
			if inj is Dictionary and int(inj.get("turn_sustained", -99)) >= current_turn - 1:
				return true
	return false
