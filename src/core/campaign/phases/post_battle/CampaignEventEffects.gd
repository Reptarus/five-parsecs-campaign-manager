class_name CampaignEventEffects
extends RefCounted

## Campaign Event processing and effect application for Post-Battle Phase.
## Handles Step 12: Campaign Events (Core Rules p.126-128)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

# Precursor event state
var _pending_event1: Dictionary = {}
var _pending_event2: Dictionary = {}
var waiting_for_precursor_choice: bool = false

func process_campaign_event(ctx: PostBattleContextClass) -> Dictionary:
	## Roll for a campaign event. Returns the event dict.
	## If crew has Precursor members, rolls twice and returns both for UI choice.
	var event_roll: int = randi_range(1, 100)
	var campaign_event: Dictionary = _get_campaign_event(event_roll)

	if _has_precursor_crew(ctx):
		var second_roll: int = randi_range(1, 100)
		var second_event: Dictionary = _get_campaign_event(second_roll)

		_pending_event1 = campaign_event
		_pending_event2 = second_event
		waiting_for_precursor_choice = true
		return {"precursor_choice": true, "event1": campaign_event, "event2": second_event}

	return campaign_event

func select_precursor_event(choice: int) -> Dictionary:
	## Select which precursor event to use (1 or 2).
	if not waiting_for_precursor_choice:
		push_warning("CampaignEventEffects: select_precursor_event called but not waiting for choice")
		return {}
	waiting_for_precursor_choice = false
	var chosen: Dictionary = _pending_event2 if choice == 2 else _pending_event1
	_pending_event1 = {}
	_pending_event2 = {}
	return chosen

func finalize_event(event: Dictionary, ctx: PostBattleContextClass) -> void:
	## Apply the event effects after selection.
	if event.has("type") and event.type != "none":
		var event_name: String = event.get("name", event.get("title", "Unknown"))
		apply_effect(event_name, ctx)

func _get_campaign_event(roll: int) -> Dictionary:
	## Get campaign event based on D100 roll from JSON data file (Core Rules p.126-128)
	var json_path: String = "res://data/campaign_tables/campaign_events.json"
	if not FileAccess.file_exists(json_path):
		return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}
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
			return entry.get("result", {"type": "none", "name": "No Event", "description": "Nothing significant occurs"})
	return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}

func _has_precursor_crew(ctx: PostBattleContextClass) -> bool:
	if not ctx.game_state_manager:
		return false
	if not ctx.game_state_manager.has_method("get_crew_members"):
		return false
	var crew: Array = ctx.game_state_manager.get_crew_members()
	for member in crew:
		if not member:
			continue
		var origin: String = member.origin.to_lower() if "origin" in member else ""
		if origin == "precursor":
			return true
	return false

func apply_effect(event_title: String, ctx: PostBattleContextClass) -> String:
	## Apply campaign event effects based on event title (Core Rules p.126-128)
	var gsm = ctx.game_state_manager
	match event_title:
		# Story Point Events
		"Local Friends", "Lucky Break", "New Ally":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "+1 Story Point"

		# Credit Events
		"Valuable Find":
			var credits_val: int = randi_range(1, 6)
			if gsm:
				gsm.add_credits(credits_val)
			return "+%d Credits" % credits_val

		"Windfall":
			var credits_val: int = randi_range(1, 6) + randi_range(1, 6)
			if gsm:
				gsm.add_credits(credits_val)
			return "+%d Credits (windfall)" % credits_val

		"Life Support Issues":
			var cost: int = randi_range(1, 6)
			var engineer_present: bool = ctx.has_crew_with_class("Engineer")
			if engineer_present:
				cost = max(1, cost - 1)
			if gsm:
				gsm.add_credits(-cost)
			return "Paid %d Credits (Life Support)" % cost

		"Odd Job":
			var credits_val: int = randi_range(1, 6) + 1
			if gsm:
				gsm.add_credits(credits_val)
			return "+%d Credits (Odd Job)" % credits_val

		"Unexpected Bill":
			var cost: int = randi_range(1, 6)
			if gsm:
				var current_credits: int = 0
				if gsm.has_method("get_credits"):
					current_credits = gsm.get_credits()
				if current_credits >= cost:
					gsm.add_credits(-cost)
					return "Paid %d Credits" % cost
				else:
					if gsm.has_method("add_story_points"):
						gsm.add_story_points(-1)
					return "Lost 1 Story Point (couldn't pay %d Credits)" % cost
			return "Unexpected bill of %d Credits" % cost

		# Rumor Events
		"Old Contact", "Valuable Intel":
			ctx.add_quest_rumor()
			return "+1 Quest Rumor"

		"Information Broker":
			return "Information Broker available (2 credits per rumor)"

		"Dangerous Information":
			ctx.add_quest_rumor()
			ctx.add_quest_rumor()
			ctx.add_rival("Information leak")
			return "+2 Quest Rumors, +1 Rival"

		# Rival Events
		"Mouthed Off", "Made Enemy":
			ctx.add_rival("Offended party")
			return "+1 Rival"

		"Suspicious Activity":
			var gc = ctx._get_current_campaign()
			if gc is Dictionary:
				var rivals: Array = gc.get("rivals", [])
				if rivals.size() > 0:
					return "Rival tracks you down this turn"
			return "No rivals to track you"

		# Patron Events
		"Reputation Grows":
			return "+1 to next Patron search roll"

		# Market Events
		"Market Surplus":
			return "All purchases -1 credit (min 1) this turn"

		"Trade Opportunity":
			return "Roll twice on Trade Table this turn"

		# Equipment/Ship Events
		"Equipment Malfunction":
			ctx.damage_random_equipment()
			return "Random item damaged"

		"Ship Parts":
			if gsm and gsm.has_method("repair_hull"):
				gsm.repair_hull(1)
			return "Repaired 1 Hull Point"

		# Medical Events
		"Friendly Doc":
			ctx.reduce_recovery_time(2)
			return "Reduced recovery time by 1 turn (up to 2 crew)"

		"Medical Supplies":
			ctx.heal_crew_in_sickbay()
			return "One crew in Sick Bay recovers immediately"

		# XP/Training Events
		"Skill Training":
			ctx.award_xp_to_random_crew(1)
			return "+1 XP to random crew member"

		"Crew Bonding":
			ctx.award_xp_to_all_crew(1)
			return "+1 XP to all crew"

		# Injury Events
		"Bar Brawl":
			ctx.injure_random_crew(1)
			return "Random crew member injured (1 turn recovery)"

		# Gambling Events
		"Gambling Opportunity":
			return "Gambling opportunity (bet 1-6 credits)"

		# Cargo Events
		"Cargo Opportunity":
			return "Cargo job: +3 credits but cannot travel this turn"

		# Tax/Government Events
		"Tax Collection":
			var die1: int = ctx.roll_d6("Tax collection die 1")
			var die2: int = ctx.roll_d6("Tax collection die 2")
			var tax: int = max(die1, die2)
			if gsm:
				var available: int = 0
				if gsm.has_method("get_credits"):
					available = gsm.get_credits()
				if available >= tax:
					gsm.add_credits(-tax)
					return "Paid %d Credits in taxes (rolled %d, %d)" % [tax, die1, die2]
				else:
					return "Ship impounded! Pay %d Credits to retrieve" % (tax + 5)
			return "Tax collector demands %d Credits" % tax

		"Government Inspection":
			var fine: int = ctx.roll_d6("Inspection fine")
			return "Government inspection: Discard illegal goods or pay %d credit fine" % fine

		"Bureaucratic Delay":
			return "Bureaucratic delay: Cannot depart this turn"

		# Leadership Events
		"New Captain":
			var roll: int = ctx.roll_d6("Captain transition")
			if roll == 1:
				return "Select new captain (+3 XP), old captain departs with D6 credits"
			return "Select new captain (+3 XP)"

		"Crew Dispute":
			return "Crew dispute: Captain must mediate or -1 morale"

		"Leadership Challenge":
			return "Leadership challenged: Captain must win combat roll or -2 morale"

		# Invasion/War Events
		"War Rumors":
			return "War rumors: +2 to invasion check while on this planet"

		"Invasion Warning":
			var invasion_roll: int = ctx.roll_2d6("Invasion warning")
			if invasion_roll >= 9:
				if gsm and gsm.has_method("set_invasion_pending"):
					gsm.set_invasion_pending(true)
				return "Invasion imminent! (rolled %d) Invasion begins next turn" % invasion_roll
			return "Invasion warning subsides (rolled %d)" % invasion_roll

		"Refugee Crisis":
			if gsm:
				gsm.add_credits(-1)
			ctx.add_quest_rumor()
			return "Helped refugees (-1 Credit, +1 Rumor)"

		# Reputation Events
		"Bad Reputation":
			ctx.remove_random_patron()
			return "Bad reputation spreads: Lost 1 Patron"

		"Reputation Boost":
			if gsm and gsm.has_method("add_reputation"):
				gsm.add_reputation(1)
			return "+1 Reputation"

		"Reputation Damaged":
			if gsm and gsm.has_method("add_reputation"):
				gsm.add_reputation(-1)
			return "-1 Reputation"

		# Rival Events (extended)
		"Settled Business":
			return "Settled business: Remove 1 Rival OR Captain gains +1 XP"

		"Rival Ambush":
			return "Rival ambush! Fight immediately (no deployment phase)"

		"Rival Truce":
			var truce_cost: int = ctx.roll_d6("Truce cost")
			return "Rival offers truce: Pay %d Credits to remove them" % truce_cost

		"Rival Alliance":
			return "Two rivals have allied! Face combined forces next battle"

		# Patron Events (extended)
		"Patron Request":
			return "Patron requests urgent mission: +2 Credits if completed this turn"

		"Patron Fallout":
			return "Patron relationship strained: -1 to next Patron roll"

		"New Patron":
			ctx.add_patron()
			return "Gained new Patron contact"

		# Supply/Resource Events
		"Supply Shortage":
			if gsm and gsm.has_method("remove_supplies"):
				gsm.remove_supplies(1)
			return "Supply shortage: -1 Supplies"

		"Supply Cache":
			if gsm and gsm.has_method("add_supplies"):
				gsm.add_supplies(2)
			return "Found supply cache: +2 Supplies"

		"Fuel Price Surge":
			return "Fuel prices surge: Travel costs +1 Credit this turn"

		"Fuel Discount":
			return "Fuel discount: Travel costs -1 Credit this turn"

		# Ship Events (extended)
		"Hull Damage":
			if gsm and gsm.has_method("damage_hull"):
				gsm.damage_hull(1)
			return "Ship hull damaged: -1 Hull Point"

		"System Failure":
			return "Ship system failure: Pay D6 Credits or cannot travel"

		"Free Repairs":
			if gsm and gsm.has_method("repair_hull"):
				gsm.repair_hull(2)
			return "Free repair services: +2 Hull Points"

		"Stowaway":
			var stowaway_roll: int = ctx.roll_d6("Stowaway")
			if stowaway_roll <= 2:
				if gsm:
					gsm.add_credits(-randi_range(1, 6))
				return "Stowaway was a thief! Lost D6 Credits"
			elif stowaway_roll <= 4:
				return "Stowaway is refugee seeking passage"
			else:
				return "Stowaway offers to join crew (roll on character table)"

		# Quest Events (extended)
		"Quest Lead":
			ctx.add_quest_rumor()
			ctx.add_quest_rumor()
			return "Major quest lead: +2 Quest Rumors"

		"Quest Setback":
			ctx.remove_quest_rumor()
			return "Quest setback: -1 Quest Rumor"

		"False Lead":
			return "Quest lead was false: No progress this turn"

		# Market Events (extended)
		"Black Market":
			return "Black market access: Rare items available (illegal)"

		"Merchant Guild":
			return "Merchant guild membership offered: 10 Credits for permanent -1 cost"

		"Trade War":
			return "Local trade war: All buying/selling suspended this turn"

		# Crime Events
		"Pickpocketed":
			var loss: int = ctx.roll_d6("Pickpocket loss")
			if gsm:
				gsm.add_credits(-loss)
			return "Crew member pickpocketed: -%d Credits" % loss

		"Bounty Posted":
			return "Bounty posted on crew: +1 Rival (bounty hunter)"

		"Crime Syndicate":
			return "Crime syndicate offers job: High pay but +1 Rival if accepted"

		# Special Events
		"Alien Artifact":
			return "Alien artifact discovered: Roll on artifact table"

		"Psychic Disturbance":
			return "Psychic disturbance: -1 to all Savvy rolls this battle"

		"Strange Signal":
			ctx.add_quest_rumor()
			return "Strange signal detected: +1 Quest Rumor"

		"Local Festival":
			return "Local festival: +1 morale, trade prices +1 Credit"

		_:
			return "Event requires manual resolution"

	return "Event resolved"
