class_name CharacterEventEffects
extends RefCounted

## Character Event processing and effect application for Post-Battle Phase.
## Handles Step 13: Character Events (Core Rules p.128-130)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func process_character_event(ctx: PostBattleContextClass) -> Dictionary:
	## Roll for a character event. Returns the event dict with crew_id and roll.
	var crew_size: int = ctx.crew_participants.size()
	if crew_size == 0:
		return {"type": "none", "name": "No Event"}
	var random_crew = ctx.crew_participants[randi() % crew_size]
	var event_roll: int = randi_range(1, 100)
	var json_path: String = "res://data/campaign_tables/character_events.json"
	if not FileAccess.file_exists(json_path):
		return {"type": "none", "name": "No Event"}
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
		if event_roll >= roll_range[0] and event_roll <= roll_range[1]:
			var result: Dictionary = entry.get("result", {"type": "none", "name": "No Event"}).duplicate()
			result["crew_id"] = random_crew
			result["roll"] = event_roll
			return result
	return {"type": "none", "name": "No Event"}

func finalize_event(event: Dictionary, ctx: PostBattleContextClass) -> void:
	## Apply the character event effects after rolling.
	if event.has("type") and event.type != "none":
		var crew: Variant = ctx.get_random_crew_member()
		var event_name: String = event.get("name", event.get("title", "Unknown"))
		if crew:
			apply_effect(event_name, crew, ctx)

func apply_effect(event_title: String, character: Variant, ctx: PostBattleContextClass) -> String:
	## Apply character event effects based on event title (Core Rules p.128-130)
	var char_name: String = ctx.get_char_name(character)
	var gsm = ctx.game_state_manager

	match event_title:
		# XP Gain Events
		"Focused Training":
			ctx.add_character_xp(character, 1)
			return "%s gained +1 Combat Skill XP" % char_name

		"Technical Study":
			ctx.add_character_xp(character, 1)
			return "%s gained +1 Savvy XP" % char_name

		"Physical Training":
			ctx.add_character_xp(character, 1)
			return "%s gained +1 Toughness XP" % char_name

		"Personal Growth":
			ctx.add_character_xp(character, 2)
			return "%s gained +2 XP" % char_name

		"Moment of Glory":
			ctx.add_character_xp(character, 1)
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s gained +1 XP and +1 Story Point" % char_name

		# Story Point Events
		"Old Friend":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s reconnects with old friend (+1 Story Point)" % char_name

		# Credits Events
		"Side Job":
			var credits_val: int = randi_range(1, 6)
			if gsm:
				gsm.add_credits(credits_val)
			return "%s earned %d Credits" % [char_name, credits_val]

		"Unexpected Windfall":
			var credits_val: int = randi_range(1, 6) + randi_range(1, 6)
			if gsm:
				gsm.add_credits(credits_val)
			return "%s received %d Credits" % [char_name, credits_val]

		"Gambling":
			var roll_val: int = randi_range(1, 6)
			var bet: int = randi_range(1, 6)
			if roll_val <= 2:
				if gsm:
					gsm.add_credits(-bet)
				return "%s lost %d Credits gambling" % [char_name, bet]
			elif roll_val >= 5:
				if gsm:
					gsm.add_credits(bet)
				return "%s won %d Credits gambling" % [char_name, bet]
			else:
				return "%s broke even gambling" % char_name

		# Equipment Events
		"Found Item":
			ctx.add_random_equipment_to_stash()
			return "%s found random gear item" % char_name

		"Equipment Care":
			return "%s repaired one damaged item" % char_name

		"Equipment Lost":
			return "%s lost random equipment" % char_name

		# Injury/Medical Events
		"Bad Dreams":
			return "%s suffers -1 to next combat roll (nightmares)" % char_name

		"Bar Fight":
			var roll_val: int = randi_range(1, 6)
			if roll_val <= 3:
				ctx.injure_specific_crew(character, 1)
				return "%s injured in bar fight (1 turn recovery)" % char_name
			else:
				return "%s gained respect in bar fight" % char_name

		"Wound Heals":
			ctx.reduce_character_recovery(character, 1)
			return "%s recovers faster (-1 turn recovery)" % char_name

		# Relationship Events
		"Made Contact":
			return "%s made useful contact (+1 to next Patron search)" % char_name

		"Made Enemy":
			ctx.add_rival("%s's enemy" % char_name)
			return "%s made an enemy (+1 Rival)" % char_name

		"Valuable Intel":
			ctx.add_quest_rumor()
			return "%s discovered valuable intel (+1 Rumor)" % char_name

		# Trait Events
		"Trait Development":
			return "%s develops positive trait (roll on trait table)" % char_name

		"Life-Changing Event":
			return "%s experiences life-changing event (reroll Motivation)" % char_name

		"Quiet Day":
			ctx.add_character_xp(character, 1)
			return "%s had a quiet day (+1 XP)" % char_name

		# Priority Events
		"Business Elsewhere":
			var xp_gain: int = ctx.roll_d6("Business elsewhere XP")
			return "%s has business elsewhere: Unavailable 2 turns, will return with %d XP + loot item" % [char_name, xp_gain]

		"In a Scrap":
			var combat_roll: int = ctx.roll_d6("Scrap combat")
			if combat_roll <= 3:
				ctx.injure_specific_crew(character, 2)
				return "%s lost a scrap with crewmate: 2 turns in Sick Bay" % char_name
			else:
				return "%s won a scrap with crewmate: Other crew member in Sick Bay" % char_name

		"Letter from Home":
			ctx.add_character_xp(character, 1)
			var quest_roll: int = ctx.roll_d6("Letter from home quest")
			if quest_roll >= 5:
				ctx.add_quest_rumor()
				return "%s received letter from home (+1 XP, +1 Quest Rumor)" % char_name
			return "%s received letter from home (+1 XP)" % char_name

		"Scars Tell Story":
			ctx.add_character_xp(character, 2)
			return "%s earned respect from past battle (+2 XP from scars)" % char_name

		# Additional XP Events
		"Combat Drill":
			ctx.add_character_xp(character, 1)
			return "%s participated in combat drill (+1 XP)" % char_name

		"Mentor":
			ctx.add_character_xp(character, 2)
			return "%s learned from experienced mentor (+2 XP)" % char_name

		"Hard Lessons":
			ctx.add_character_xp(character, 1)
			return "%s learned from a painful failure (+1 XP)" % char_name

		"Combat Veteran":
			ctx.add_character_xp(character, 3)
			return "%s reflects on long career (+3 XP)" % char_name

		# Additional Credit Events
		"Inheritance":
			var inheritance: int = ctx.roll_d6("Inheritance") + ctx.roll_d6("Inheritance bonus")
			if gsm:
				gsm.add_credits(inheritance)
			return "%s received %d Credit inheritance" % [char_name, inheritance]

		"Lost Bet":
			var loss: int = ctx.roll_d6("Lost bet")
			if gsm:
				gsm.add_credits(-loss)
			return "%s lost %d Credits on a bet" % [char_name, loss]

		"Collected Debt":
			var debt: int = ctx.roll_d6("Collected debt")
			if gsm:
				gsm.add_credits(debt)
			return "%s collected %d Credits owed" % [char_name, debt]

		"Bribery":
			var bribe: int = ctx.roll_d6("Bribery")
			if gsm:
				gsm.add_credits(-bribe)
			return "%s paid %d Credit bribe" % [char_name, bribe]

		# Injury/Medical Events (extended)
		"Recurring Injury":
			ctx.injure_specific_crew(character, 1)
			return "%s suffers from recurring injury (1 turn recovery)" % char_name

		"Close Call":
			return "%s had a close call: -1 to next combat roll (shaken)" % char_name

		"Miraculous Recovery":
			ctx.reduce_character_recovery(character, 2)
			return "%s makes miraculous recovery (-2 turns recovery)" % char_name

		"Sick":
			ctx.injure_specific_crew(character, 1)
			return "%s falls ill (1 turn unavailable)" % char_name

		"Accident":
			var severity: int = ctx.roll_d6("Accident severity")
			if severity <= 2:
				ctx.injure_specific_crew(character, 1)
				return "%s had minor accident (1 turn recovery)" % char_name
			elif severity <= 4:
				ctx.injure_specific_crew(character, 2)
				return "%s had moderate accident (2 turns recovery)" % char_name
			else:
				return "%s narrowly avoided serious accident" % char_name

		# Relationship Events (extended)
		"Made Friend":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s made valuable friend (+1 Story Point)" % char_name

		"Romantic Entanglement":
			var romance_roll: int = ctx.roll_d6("Romance outcome")
			if romance_roll <= 2:
				return "%s's romance causes complications (-1 to next mission)" % char_name
			elif romance_roll >= 5:
				return "%s's romance provides benefits (+1 to next Patron search)" % char_name
			return "%s has romantic entanglement (no effect this turn)" % char_name

		"Family Trouble":
			var trouble_roll: int = ctx.roll_d6("Family trouble")
			if trouble_roll <= 3:
				if gsm:
					gsm.add_credits(-ctx.roll_d6("Family credits"))
				return "%s must help family (sent D6 Credits)" % char_name
			return "%s resolved family trouble" % char_name

		"Old Comrade":
			ctx.add_character_xp(character, 1)
			return "%s met old comrade (+1 XP from reminiscing)" % char_name

		# Equipment Events (extended)
		"Weapon Upgrade":
			return "%s upgraded weapon (+1 to damage)" % char_name

		"Personal Item":
			return "%s acquired personal item (sentimental value)" % char_name

		"Equipment Breakdown":
			return "%s's equipment malfunctioned (repair needed)" % char_name

		"Lucky Find":
			ctx.add_random_equipment_to_stash()
			return "%s found valuable item (added to stash)" % char_name

		# Morale/Mental Events
		"Homesick":
			return "%s is homesick (-1 morale this turn)" % char_name

		"Inspired":
			ctx.add_character_xp(character, 1)
			return "%s feels inspired (+1 XP, +1 morale)" % char_name

		"Doubt":
			return "%s experiences self-doubt (-1 to first combat roll next battle)" % char_name

		"Confidence":
			return "%s gains confidence (+1 to first combat roll next battle)" % char_name

		"Nightmare":
			return "%s has recurring nightmares (-1 to Savvy this turn)" % char_name

		# Special Events
		"Spiritual Experience":
			ctx.add_character_xp(character, 1)
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "%s had spiritual experience (+1 XP, +1 Story Point)" % char_name

		"Prophetic Dream":
			ctx.add_quest_rumor()
			return "%s had prophetic dream (+1 Quest Rumor)" % char_name

		"Strange Encounter":
			var encounter_roll: int = ctx.roll_d6("Strange encounter")
			if encounter_roll <= 2:
				ctx.add_rival("%s's strange encounter" % char_name)
				return "%s had strange encounter (+1 Rival)" % char_name
			elif encounter_roll >= 5:
				ctx.add_patron()
				return "%s had strange encounter (+1 Patron contact)" % char_name
			return "%s had strange encounter (no lasting effect)" % char_name

		"Psych Eval Required":
			return "%s requires psych eval (unavailable 1 turn)" % char_name

		"On Leave":
			return "%s takes personal leave (unavailable 1 turn, +1 morale)" % char_name

		_:
			return "%s: Event requires manual resolution" % char_name

	return "Character event resolved"
