class_name CharacterEventEffects
extends RefCounted

## Character Event processing and effect application for Post-Battle Phase.
## Handles Step 13: Character Events (Core Rules p.128-130)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

# Precursor event state (Core Rules p.128: Precursors roll twice, pick either)
var _pending_event1: Dictionary = {}
var _pending_event2: Dictionary = {}
var waiting_for_precursor_choice: bool = false

func process_character_event(ctx: PostBattleContextClass) -> Dictionary:
	## Roll for a character event. Returns the event dict with crew_id and roll.
	## Core Rules p.128: Roll on random non-Bot, non-Soulless crew member.
	## If the selected character is Precursor, roll twice and pick either.

	# Filter eligible crew (exclude Bots and Soulless per Core Rules p.128)
	var eligible: Array = []
	for crew_id in ctx.crew_participants:
		if not ctx.is_character_bot_or_soulless(crew_id):
			eligible.append(crew_id)
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
	character_event["character_origin"] = ctx.get_character_origin(random_crew)
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
					return "%s (%s): Unaffected by '%s'" % [char_name, origin, event_title]

	match event_title:
		"Violence is Depressing":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s refuses battle next turn (except Invasion). +1 Story Point" % char_name

		"Business Elsewhere":
			var xp_gain: int = randi_range(1, 6)
			if origin_lower == "swift":
				return "%s (Swift) has business elsewhere: Never returns. Replaced with new Swift character." % char_name
			return "%s unavailable 2 turns (no Upkeep). Returns with %d XP + Loot roll" % [char_name, xp_gain]

		"Local Friends":
			ctx.add_character_xp(character, 1)
			return "%s made local friends: +1 XP" % char_name

		"Time to Move On":
			return "%s considers moving on (if in Sick Bay: D6 <= recovery turns = leaves)" % char_name

		"Letter from Home":
			ctx.add_character_xp(character, 1)
			var quest_roll: int = randi_range(1, 6)
			if quest_roll >= 5:
				ctx.add_quest_rumor()
				return "%s got letter from home: +1 XP, +1 Quest" % char_name
			return "%s got letter from home: +1 XP" % char_name

		"Argue with Crew":
			return "%s argues with crew: Refuses tasks next turn (battles OK)" % char_name

		"Scrap with Crewmate":
			if ctx.has_crew_with_origin("K'Erin") and origin_lower != "k'erin":
				return "%s must scrap with K'Erin crewmate: D6+Combat each. Loser 1 turn Sick Bay (draw = both)" % char_name
			return "%s in scrap: D6+Combat vs random crewmate. Loser to Sick Bay 1 turn (draw = both)" % char_name

		"Good Food":
			ctx.add_character_xp(character, 1)
			return "%s: Good food. If Sick Bay: -1 recovery. If not: +1 XP" % char_name

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
			ctx.add_character_xp(character, 1)
			return "%s had heart to heart: Both characters +1 XP (select random crewmate)" % char_name

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
			ctx.add_character_xp(character, 2)
			return "%s: Scars tell the story. +2 XP if injured last/this turn" % char_name

		"Time to Reflect":
			var xp_roll: int = randi_range(1, 3)
			ctx.add_character_xp(character, xp_roll)
			return "%s reflected on adventures: +%d XP" % [char_name, xp_roll]

		"Personal Breakthrough":
			return "%s: Personal breakthrough. +1 to one non-increased ability" % char_name

		"Hurt Working on Ship":
			ctx.injure_specific_crew(character, 1)
			if gsm and gsm.has_method("damage_hull"):
				gsm.damage_hull(1)
			return "%s hurt working on ship: 1 turn Sick Bay, ship -1 Hull" % char_name

		"Found True Love":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s found true love: +1 Story Point (if motivation=True Love: also +1D6 XP)" % char_name

		"Personal Enemy":
			ctx.add_rival("%s's personal enemy" % char_name)
			return "%s: Personal enemy. +1 Rival (leaves if %s leaves crew)" % [char_name, char_name]

		"Gift":
			return "%s received a gift: Roll once on Loot Table" % char_name

		"Feel Great":
			return "%s feels great: Next Injury Table roll is ignored" % char_name

		"Someone Who Knows Someone":
			ctx.add_patron()
			return "%s knows someone: +1 Patron" % char_name

		"Charmed Existence":
			return "%s: Charmed existence. +1 Luck" % char_name

		"Hard Work":
			if origin_lower == "engineer":
				return "%s (Engineer) put in hard work: Repair 2 Hull AND 1 damaged item" % char_name
			return "%s put in hard work: Repair 2 Hull OR 1 damaged item" % char_name

		"Don't Make Them Like They Used To":
			return "%s: Random carried item damaged" % char_name

		"Where Did It Go":
			return "%s lost random item. Next turn: D6+Savvy, 5+ = item returns" % char_name

		"Melancholy":
			return "%s: Melancholy. No XP next campaign turn" % char_name

		"Time to Burn":
			return "%s has time to burn: Extra action next turn (even in Sick Bay)" % char_name

		_:
			return "%s: Character event '%s' (manual resolution)" % [char_name, event_title]
