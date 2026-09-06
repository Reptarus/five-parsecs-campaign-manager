class_name CampaignEventEffects
extends RefCounted

## Campaign Event processing and effect application for Post-Battle Phase.
## Handles Step 12: Campaign Events (Core Rules p.126-128)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func process_campaign_event(_ctx: PostBattleContextClass) -> Dictionary:
	## Roll for a campaign event (Core Rules p.125, step 12). Returns the event dict.
	##
	## THERE IS NO PRECURSOR DOUBLE-ROLL ON THIS STEP. p.125 step 12 is one line:
	## "Roll D100 on the Campaign Event Table. Apply the result immediately."
	##
	## The Precursor "roll twice and pick either" is a CHARACTER Event rule and
	## belongs to step 13. Both of the book's statements of it name the Character
	## Event and nothing else — p.126: "If the selected character is a Precursor,
	## you may roll twice and pick either score"; p.17 (the species entry): "if a
	## Precursor is the subject of a Character Event, you may roll for 2 events
	## and pick which one you prefer." A whole-book sweep for "Precursor" turns up
	## no third statement.
	##
	## This file used to implement the rule HERE, and triggered it whenever ANY
	## crew member was a Precursor rather than when the selected one was. That was
	## a fabricated rule on the wrong step, and it starved the real one: the
	## correct producer in CharacterEventEffects had no consumer, so a Precursor
	## selected for step 13 lost the event entirely. See that file for the fix.
	var event_roll: int = _roll_campaign_d100()
	var campaign_event: Dictionary = _get_campaign_event(event_roll)
	# finalize_event() journals event.get("roll", 0) and nothing ever wrote the
	# key, so every campaign-event journal entry recorded a roll of 0.
	campaign_event["roll"] = event_roll
	return campaign_event


## T11-19b - route the p.125 step-12 D100 through DiceManager so the debug
## forced-roll seam reaches it.
##
## THE DEFECT. T11-19 fixed exactly this shape one file over, in
## CharacterEventEffects._roll_event_d100(), and stopped there. This sibling kept
## a bare randi_range(1, 100), so QAScenarioDialog could not force a CAMPAIGN
## event - which left T11-25 (Old Nemesis, rolls 21-23) and T11-35 (Got Noticed,
## 89-91) unreachable on device at 3-in-100 per battle. A seam that reaches one of
## two sibling rolls is not a seam.
##
## roll_campaign_event() had ZERO callers repo-wide before this - a dead provider,
## not dead code. It is the semantically correct API for this step, so it is wired
## rather than routed around; it prefixes "Event: ", giving the context
## "Event: Campaign Event", which the seam's case-insensitive SUBSTRING match
## reaches with the key "Campaign Event". Checked for collisions: the only other
## contexts carrying the word are "Character Event: <name>" and "Faction Event",
## and neither contains "campaign event".
##
## WARNING: this class is RefCounted, so it must reach the autoload through
## Engine.get_main_loop().root. A bare get_node_or_null("/root/...") from a
## RefCounted does not return null - it ERRORS and ABORTS the enclosing function,
## which would silently kill the whole Campaign Event step (the MissionTableManager
## trap). The randi_range fallback covers a genuinely absent autoload, which is the
## case for unit tests that construct this class outside a tree.
func _roll_campaign_d100() -> int:
	var dice: Node = null
	if Engine.get_main_loop():
		dice = Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")
	if dice and dice.has_method("roll_campaign_event"):
		return int(dice.roll_campaign_event("Campaign Event"))
	return randi_range(1, 100)


func finalize_event(event: Dictionary, ctx: PostBattleContextClass) -> void:
	## Apply the event effects after selection.
	if event.has("type") and event.type != "none":
		var event_name: String = event.get("name", event.get("title", "Unknown"))
		apply_effect(event_name, ctx)
		# Journal: log campaign event result
		if ctx.campaign_journal \
				and ctx.campaign_journal.has_method("create_entry"):
			ctx.campaign_journal.create_entry({
				"type": "campaign_event",
				"auto_generated": true,
				"title": "Campaign Event: %s" % event_name,
				"description": event.get("description", ""),
				"tags": ["campaign_event", "d100"],
				"stats": {"roll": event.get("roll", 0)},
			})

func _get_campaign_event(roll: int) -> Dictionary:
	## Get campaign event based on D100 roll from JSON data file (Core Rules p.126-128)
	var json_path: String = "res://data/campaign_tables/campaign_events.json"
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}
	var data: Dictionary = json.data
	var entries: Array = data.get("entries", [])
	for entry in entries:
		var roll_range: Array = entry.get("roll_range", [0, 0])
		if roll >= roll_range[0] and roll <= roll_range[1]:
			var result: Dictionary = entry.get("result", {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}).duplicate()
			if entry.has("species_exceptions"):
				result["species_exceptions"] = entry["species_exceptions"]
			return result
	return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}

## T11-25 - set by the "Old Nemesis" branch when the campaign already has Rivals,
## because Core Rules p.126 gives the PLAYER the choice: "Select a prior Rival, or
## roll up a new one." Read and cleared by PostBattlePhase, which owns the signal
## (subsystems here are RefCounted and never emit - see the architecture note in
## CLAUDE.md). Modelled on `PostBattlePhase.pending_illegal_salvage`, the existing
## post-battle pick pattern.
var pending_nemesis_choice: Dictionary = {}


## Rivals the campaign already has, in a shape the chooser can label.
func _prior_rivals(ctx: PostBattleContextClass) -> Array:
	var campaign: Variant = ctx.campaign
	if campaign == null and ctx.game_state:
		campaign = ctx.game_state.current_campaign
	if campaign == null:
		return []
	var raw: Variant = []
	if campaign is Dictionary:
		raw = (campaign as Dictionary).get("rivals", [])
	elif "rivals" in campaign:
		raw = campaign.rivals
	if not (raw is Array):
		return []
	var out: Array = []
	for r in (raw as Array):
		if r is Dictionary:
			out.append(r)
	return out


## Apply the p.126 Old Nemesis riders to a Rival the player already had.
##
## "They will follow you from planet to planet until resolved and receive +1 when
## rolling for the number of enemies in a battle" - both riders attach to the
## SELECTED Rival, so picking a prior one must not also create a new one.
func resolve_nemesis_choice(
	option_id: String, ctx: PostBattleContextClass
) -> Dictionary:
	var result: Dictionary = {"option": option_id, "applied": false, "detail": ""}
	if pending_nemesis_choice.is_empty():
		result["detail"] = "No nemesis choice is pending."
		return result
	pending_nemesis_choice = {}
	if option_id == "roll_new" or option_id.is_empty():
		var new_id: String = ctx.add_rival(NEMESIS_LABEL, _nemesis_opts())
		result["applied"] = not new_id.is_empty()
		result["rival_id"] = new_id
		result["detail"] = "Old nemesis: rolled up a new persistent Rival (+1 to enemy numbers)."
		return result
	for rival in _prior_rivals(ctx):
		if str(rival.get("id", "")) != option_id:
			continue
		rival["persistent"] = true
		rival["enemy_count_bonus"] = int(rival.get("enemy_count_bonus", 0)) + 1
		rival["source_event"] = "Old Nemesis"
		result["applied"] = true
		result["rival_id"] = option_id
		result["detail"] = ("%s is now an old nemesis: they follow the crew from "
			% str(rival.get("name", "That Rival"))
			+ "planet to planet and add +1 to enemy numbers.")
		return result
	result["detail"] = "That Rival no longer exists."
	return result


## The name and riders a NEW old-nemesis Rival is created with. Kept in one place
## so the chooser's two branches cannot drift.
const NEMESIS_LABEL := "Old nemesis"


func _nemesis_opts() -> Dictionary:
	return {
		"persistent": true,
		"enemy_count_bonus": 1,
		"origin": "campaign_event",
		"source_event": "Old Nemesis",
	}


func apply_effect(event_title: String, ctx: PostBattleContextClass) -> String:
	## Apply campaign event effects based on event title (Core Rules p.126-128)
	## All 28 events from the D100 Campaign Events Table
	var gsm = ctx.game_state_manager
	match event_title:
		"Friendly Doc":
			ctx.reduce_recovery_time(2)
			return "Friendly doc: Reduced recovery by 1 turn (up to 2 crew)"

		"Life Support Upgrade":
			var cost: int = randi_range(1, 6)
			var engineer_present: bool = ctx.has_crew_with_class("Engineer")
			if engineer_present:
				cost = maxi(1, cost - 1)
			if gsm:
				# modify_credits clamps at 0 — credits must never go negative
				# (Core Rules: you pay what you can; ship stays grounded on debt).
				# add_credits() is unclamped and drove the balance to -N once the
				# 1de89630 bridge made this effect actually apply.
				gsm.modify_credits(-cost)
			return "Life support upgrade: Paid %d credits (ship grounded until paid)" % cost

		"New Ally":
			# Choice: new crew member OR +1 story point
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "New ally: +1 Story Point (or roll new crew member)"

		"Local Friends":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "Local friends: +1 Story Point"

		"Mouthed Off":
			ctx.add_rival("Offended locals")
			return "Mouthed off: +1 Rival"

		"Old Nemesis":
			## Core Rules p.126, rolls 21-23, verbatim: "An old nemesis has tracked
			## you down. Select a prior Rival, or roll up a new one. They will follow
			## you from planet to planet until resolved and receive +1 when rolling
			## for the number of enemies in a battle."
			##
			## T11-25. This used to pass the EFFECT STRING as the Rival's NAME -
			## the device walk found a Rival literally called "Old nemesis
			## (persistent, +1 enemies)" on the World Record Sheet - and applied
			## neither of the two riders anywhere. The "select a prior Rival" half
			## of the rule was not modelled at all.
			var priors: Array = _prior_rivals(ctx)
			if priors.is_empty():
				# Nothing to select FROM, so the book's other branch is the only one
				# available - roll up a new one, no prompt.
				ctx.add_rival(NEMESIS_LABEL, _nemesis_opts())
				return "Old nemesis: rolled up a new persistent Rival (+1 to enemy numbers)"
			var options: Array = []
			for rival in priors:
				var rtype: String = str(rival.get("type", ""))
				var rname: String = str(rival.get("name", "Rival"))
				var label: String = rname if rtype.is_empty() else "%s (%s)" % [rname, rtype]
				options.append({"id": str(rival.get("id", "")), "label": label})
			options.append({"id": "roll_new", "label": "Roll up a new Rival"})
			pending_nemesis_choice = {
				"event": "Old Nemesis",
				"prompt": ("An old nemesis has tracked you down (Core Rules p.126). "
					+ "Select a prior Rival, or roll up a new one. They follow you from "
					+ "planet to planet until resolved and add +1 to enemy numbers."),
				"options": options,
			}
			return "Old nemesis: select a prior Rival, or roll up a new one"

		"Shady Deal":
			return "Shady deal: Give 1 item, roll on Trade Table"

		"Cargo Sale":
			var credits_val: int = randi_range(1, 6)
			if gsm:
				gsm.add_credits(credits_val)
			return "Cargo sale: +%d Credits" % credits_val

		"Overheard Something":
			ctx.add_quest_rumor()
			return "Overheard something: +1 Rumor"

		"Settle Old Business":
			# Choice: remove rival OR captain +1 XP
			var has_rivals: bool = false
			if gsm and gsm.has_method("get_rivals"):
				has_rivals = gsm.get_rivals().size() > 0
			if has_rivals:
				return "Settle old business: Remove 1 Rival of your choice"
			else:
				ctx.award_xp_to_captain(1)
				return "Settle old business: Captain +1 XP (no rivals to remove)"

		"Admirer":
			return "Admirer: Gain base-profile crew member (no equipment, Feral if crew has Feral)"

		"Alien Merchant":
			return "Alien merchant: Pay 4 credits to roll on Loot Table"

		"Equipment Malfunction":
			ctx.damage_random_equipment()
			return "Equipment malfunction: Random stash item damaged"

		"Bad Reputation":
			ctx.remove_random_patron()
			return "Bad reputation: Lost 1 Patron on current world"

		"Tax Man":
			var die1: int = randi_range(1, 6)
			var die2: int = randi_range(1, 6)
			var tax: int = maxi(die1, die2)
			if gsm:
				var available: int = 0
				if gsm.has_method("get_credits"):
					available = gsm.get_credits()
				if available >= tax:
					gsm.add_credits(-tax)
					return "Tax man: Paid %d Credits (rolled %d, %d)" % [tax, die1, die2]
				else:
					return "Tax man: Ship impounded! Pay %d Credits to retrieve" % tax
			return "Tax man demands %d Credits" % tax

		"New Captain":
			## p.127, 57-59: "Select a crew member to be the new captain. They
			## immediately receive 3 XP. Roll 1D6. On a 1, the old captain leaves
			## the campaign permanently, taking any items carried with them. If
			## your crew has any K'Erin, one of them must be selected."
			##
			## The D6 was rolled and discarded and no captain ever changed: the
			## `is_captain` flag never moved, the 3 XP were never paid, and the old
			## captain never left. A whole leadership-change event was two return
			## strings.
			var successor: Variant = _pick_new_captain(ctx)
			if successor == null:
				return "The crew wanted a new captain, but there is nobody else aboard"
			var old_captain: Variant = _current_captain(ctx)
			_set_captain(old_captain, false)
			_set_captain(successor, true)
			ctx.add_character_xp(successor, 3)
			var successor_name: String = ctx.get_char_name(successor)

			var roll: int = ctx.roll_d6("Old captain's fate")
			if roll != 1 or old_captain == null:
				return "%s is the crew's new captain (+3 XP); the old captain stays on" % 					successor_name
			# "taking any items carried with them" — the gear leaves with them, so
			# it is NOT returned to the stash.
			var old_name: String = ctx.get_char_name(old_captain)
			_mark_departed(old_captain)
			if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
				ctx.campaign_journal.create_entry({
					"type": "character_event",
					"auto_generated": true,
					"title": "New Captain",
					"description": "%s took command; %s left the campaign with their gear (Core Rules p.127)" % [
						successor_name, old_name],
					"tags": ["departure", "captain", "campaign_event"],
				})
			return "%s is the crew's new captain (+3 XP); %s leaves the campaign with their gear" % [
				successor_name, old_name]

		"Business Contacts":
			ctx.add_patron()
			return "Business contacts: +1 Patron"

		"Learning Opportunity":
			ctx.award_xp_to_all_crew(1)
			return "Learning opportunity: All crew +1 XP"

		"Gravitational Adjuster":
			var hull_dmg: int = randi_range(1, 6)
			# `damage_hull` has ZERO definitions repo-wide, so this guard was
			# permanently false and the event reported damage it never dealt.
			# The real API is apply_ship_damage() (GameStateManager:496), which
			# also applies ship traits (Armored -1, Improved Shielding -1,
			# Dodgy Drive +2) and returns the damage actually taken.
			if gsm and gsm.has_method("apply_ship_damage"):
				hull_dmg = int(gsm.apply_ship_damage(hull_dmg))
			return "Gravitational adjuster misaligned: Ship takes %d Hull damage" % hull_dmg

		"Crew Bonding":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "Crew bonding: +1 Story Point"

		"Arms Dealer Contact":
			return "Arms dealer: Add 3 weapons (choose from Hand Cannon, Military Rifle, Shotgun, Machine Pistol)"

		"Renegotiate Debts":
			## p.127, 79-81: "If you currently owe money, reduce your debt by
			## 1D6+1 credits. If you owe nothing, earn 2 credits for being prudent."
			##
			## It rolled the relief, ignored it, and paid the 2 credits
			## UNCONDITIONALLY — so a crew carrying ship debt got the consolation
			## prize meant for the debt-free and their loan never moved.
			var debt: int = _ship_debt(ctx)
			if debt <= 0:
				_grant_credits(ctx, 2)
				return "Renegotiated nothing — debt-free, so +2 credits for prudence"
			var relief: int = ctx.roll_d6("Debt renegotiation") + 1
			var new_debt: int = maxi(0, debt - relief)
			_set_ship_debt(ctx, new_debt)
			return "Renegotiated old debts: ship debt %d -> %d credits (-%d)" % [
				debt, new_debt, debt - new_debt]

		"Rumors of War":
			## p.127, 82-84: "While you remain on this planet, any roll for
			## Invasion is at +2." Was a bare sentence with no producer, so the
			## most dangerous campaign event on the table changed nothing.
			##
			## Scoped to the CURRENT planet id, not a global flag, because "while
			## you remain on this planet" ends the moment the crew travels.
			## PaymentProcessor.process_invasion_check reads it back.
			var campaign: Variant = ctx.campaign
			if campaign == null or not ("progress_data" in campaign):
				return "Rumors of war spread, but no campaign is loaded to record them"
			var planet_id: String = _current_planet_key(ctx)
			campaign.progress_data["rumors_of_war_planet"] = planet_id
			return "Rumors of war: +2 to all Invasion rolls while the crew stays here"

		"Time on Your Hands":
			return "Time on your hands: 2 random crew roll on Exploration Table"

		"Got Noticed":
			## Core Rules p.128, rolls 89-91, verbatim: "You got noticed by someone
			## you'd rather avoid. Add a Rival. If you currently are on a Quest, the
			## next campaign turn is automatically a battle against the new Rival,
			## and they will add +1 to the number of enemies."
			##
			## T11-35. Both riders were named in the returned STRING and applied
			## nowhere. Note the scope: the conditional governs the whole second
			## sentence, so the forced battle AND the +1 enemies are BOTH
			## Quest-only - which is also how the shipped table encodes it
			## (campaign_events.json: quest_forced_battle / enemy_bonus_if_quest).
			## Off-Quest the event is a plain "Add a Rival".
			var on_quest: bool = (
				ctx.game_state != null
				and ctx.game_state.has_method("has_active_quest")
				and bool(ctx.game_state.has_active_quest())
			)
			var notice_opts: Dictionary = {"origin": "campaign_event",
				"source_event": "Got Noticed"}
			if on_quest:
				notice_opts["enemy_count_bonus"] = 1
			var notice_id: String = ctx.add_rival("Unwanted attention", notice_opts)
			if not on_quest:
				return "Got noticed: +1 Rival"
			# Next-turn flag on progress_data, the same home "Rumors of War" uses
			# above - it rides the existing campaign serialization, so the forced
			# battle survives a save between the two turns.
			var camp: Variant = ctx.campaign
			if camp == null and ctx.game_state:
				camp = ctx.game_state.current_campaign
			if camp != null and "progress_data" in camp and not notice_id.is_empty():
				camp.progress_data["forced_rival_battle"] = notice_id
			return ("Got noticed: +1 Rival - on a Quest, so next campaign turn is "
				+ "automatically a battle against them, and they add +1 to enemy numbers")

		"Time to Go":
			return "Time to go! +1 Rival each turn you stay on this planet"

		"No Ships Authorized":
			return "No ships authorized: Cannot leave planet for 2 turns"

		"Great Story":
			## p.127, 98-100: "Select a crew member who was a casualty last battle.
			## They receive +1 LUCK. If nobody got hurt, receive +1 story point
			## instead."
			##
			## The story point was paid every time and the Luck never was — so the
			## branch the book puts FIRST, and the only one that rewards having
			## taken casualties, did nothing.
			var casualty: Variant = _last_battle_casualty(ctx)
			if casualty != null and ctx.apply_luck_increase(casualty, 1):
				return "In hindsight it made a great story: %s earns +1 Luck" % 					ctx.get_char_name(casualty)
			ctx.add_story_points(1)
			if casualty != null:
				# Luck is capped (1, or 3 for Humans — p.123), so a maxed survivor
				# cannot take it. The book gives no fallback; the story point is
				# the nearest thing to it and is reported honestly.
				return "A great story, but %s cannot hold more Luck — +1 Story Point instead" % 					ctx.get_char_name(casualty)
			return "Nobody got hurt, so it is just a great story: +1 Story Point"

		_:
			return "Campaign event: %s (manual resolution)" % event_title

	return "Event resolved"


## ── Helpers for the pp.126-128 events wired above ─────────────────────────────

func _member_field(member: Variant, key: String, default_value: Variant) -> Variant:
	## Dictionary.get takes 2 args and Object.get takes 1, so the wrong form
	## ABORTS the whole handler. Crew members are canonically Dictionaries but a
	## Character Resource still reaches here on a fresh campaign.
	if member is Dictionary:
		return member.get(key, default_value)
	if member != null and key in member:
		return member.get(key)
	return default_value


func _set_captain(member: Variant, value: bool) -> void:
	if member == null:
		return
	if member is Dictionary:
		member["is_captain"] = value
	elif "is_captain" in member:
		member.is_captain = value


func _mark_departed(member: Variant) -> void:
	if member is Dictionary:
		member["status"] = "departed"
	elif member != null and "status" in member:
		member.status = "departed"


func _is_available(member: Variant) -> bool:
	var status: String = str(_member_field(member, "status", "")).to_lower()
	return status not in ["dead", "departed", "retired", "missing"]


func _current_captain(ctx: PostBattleContextClass) -> Variant:
	for member in ctx.get_crew_members():
		if bool(_member_field(member, "is_captain", false)):
			return member
	return null


func _pick_new_captain(ctx: PostBattleContextClass) -> Variant:
	## p.127: "If your crew has any K'Erin, one of them MUST be selected."
	## Their pride is the whole reason the clause exists, so they take priority
	## over a random pick rather than merely being eligible for one.
	var candidates: Array = []
	for member in ctx.get_crew_members():
		if bool(_member_field(member, "is_captain", false)) or not _is_available(member):
			continue
		var sid: String = str(_member_field(
			member, "species_id", _member_field(member, "origin", ""))).to_lower()
		if sid == "k'erin" or sid == "kerin" or sid == "k_erin":
			return member
		candidates.append(member)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _last_battle_casualty(ctx: PostBattleContextClass) -> Variant:
	## p.127 Great Story wants "a crew member who was a casualty last battle".
	## Both shapes the funnel produces are accepted: the casualties list, and the
	## processed-injury list the played path fills instead (BattleResultNormalizer
	## routes downed crew to the Injury Table, leaving `casualties` empty).
	var ids: Array = []
	for entry in ctx.battle_result.get("casualties", []):
		if entry is Dictionary:
			ids.append(str(entry.get("crew_id", "")))
		else:
			ids.append(str(entry))
	for entry in ctx.battle_result.get("injuries_sustained", []):
		if entry is Dictionary:
			ids.append(str(entry.get("crew_id", "")))
	for entry in ctx.battle_result.get("units_downed", []):
		ids.append(str(entry))
	for cid in ids:
		if cid.is_empty():
			continue
		var member: Variant = ctx.get_crew_member(cid)
		if member != null and _is_available(member):
			return member
	return null


func _current_planet_key(ctx: PostBattleContextClass) -> String:
	## The id the invasion check will compare against. Falls back to the planet
	## NAME so the modifier still scopes correctly on saves that predate ids.
	var pdm: Node = ctx.planet_data_manager
	if pdm == null:
		return ""
	if "current_planet_id" in pdm and str(pdm.current_planet_id) != "":
		return str(pdm.current_planet_id)
	if pdm.has_method("get_current_planet"):
		var planet: Variant = pdm.get_current_planet()
		if planet is Dictionary:
			return str(planet.get("name", ""))
		if planet != null and "name" in planet:
			return str(planet.name)
	return ""


## Debt and credits are read and written on ctx.campaign FIRST.
##
## That is deliberate and it is the opposite of the obvious ordering. ctx.campaign
## is the campaign this post-battle phase was handed, and FiveParsecsCampaignCore
## owns both values per the data-ownership table. Preferring the GameStateManager
## autoload looked tidier and was WRONG: the autoload resolves in any context
## where the engine is running, but it answers for ITS OWN current_campaign — so
## a phase operating on any other campaign object read a debt that was not the
## one it was renegotiating and wrote credits that never reached it. The write
## vanished with no error, which is the same fail-closed shape this whole audit
## keeps turning up.
##
## The manager is still used when there is no campaign on the context, since it
## is then the only route to one.

func _gsm_or_autoload(ctx: PostBattleContextClass) -> Variant:
	if ctx.game_state_manager:
		return ctx.game_state_manager
	if Engine.get_main_loop():
		return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	return null


func _ship_debt(ctx: PostBattleContextClass) -> int:
	if ctx.campaign and "ship_debt" in ctx.campaign:
		return int(ctx.campaign.ship_debt)
	var gsm: Variant = _gsm_or_autoload(ctx)
	if gsm and gsm.has_method("get_ship_debt"):
		return int(gsm.get_ship_debt())
	return 0


func _set_ship_debt(ctx: PostBattleContextClass, amount: int) -> void:
	var clamped: int = maxi(0, amount)
	if ctx.campaign and "ship_debt" in ctx.campaign:
		ctx.campaign.ship_debt = clamped
		return
	var gsm: Variant = _gsm_or_autoload(ctx)
	if gsm and gsm.has_method("set_ship_debt"):
		gsm.set_ship_debt(clamped)


func _grant_credits(ctx: PostBattleContextClass, amount: int) -> void:
	## Ownership order was INVERTED here (fixed Aug 6 2026): the direct write came
	## first and RETURNED, so `gsm.add_credits()` below was reachable only when the
	## campaign had no `credits` field at all — i.e. never. GameStateManager's
	## cached mirror and its credits_changed signal therefore never fired for a
	## p.126 campaign-event credit grant, leaving the dashboard badge stale until
	## something else happened to resync it. Flagged by lint_data_ownership.py.
	if amount == 0:
		return
	var gsm: Variant = _gsm_or_autoload(ctx)
	if gsm and gsm.has_method("add_credits") \
			and gsm.game_state != null \
			and gsm.game_state.current_campaign == ctx.campaign:
		gsm.add_credits(amount)
		return
	# Fallback: the context may hold a campaign the manager does not own (tests,
	# and the Campaign Editor's detached preview). Delegating anyway would apply
	# the grant to the WRONG campaign, which is worse than bypassing the mirror.
	if ctx.campaign and "credits" in ctx.campaign:
		ctx.campaign.credits = maxi(0, int(ctx.campaign.credits) + amount) # lint:ignore
		return
	if gsm and gsm.has_method("add_credits"):
		gsm.add_credits(amount)
