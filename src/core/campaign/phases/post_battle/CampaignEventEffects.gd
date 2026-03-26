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
				gsm.add_credits(-cost)
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
			ctx.add_rival("Old nemesis (persistent, +1 enemies)")
			return "Old nemesis: +1 persistent Rival (+1 to enemy numbers)"

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
			var roll: int = randi_range(1, 6)
			if roll == 1:
				return "New captain: Select new captain (+3 XP). Old captain leaves permanently with gear. K'Erin priority."
			return "New captain: Select new captain (+3 XP). K'Erin must be selected or they leave."

		"Business Contacts":
			ctx.add_patron()
			return "Business contacts: +1 Patron"

		"Learning Opportunity":
			ctx.award_xp_to_all_crew(1)
			return "Learning opportunity: All crew +1 XP"

		"Gravitational Adjuster":
			var hull_dmg: int = randi_range(1, 6)
			if gsm and gsm.has_method("damage_hull"):
				gsm.damage_hull(hull_dmg)
			return "Gravitational adjuster misaligned: Ship takes %d Hull damage" % hull_dmg

		"Crew Bonding":
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "Crew bonding: +1 Story Point"

		"Arms Dealer Contact":
			return "Arms dealer: Add 3 weapons (choose from Hand Cannon, Military Rifle, Shotgun, Machine Pistol)"

		"Renegotiate Debts":
			var debt_relief: int = randi_range(1, 6) + 1
			if gsm:
				# If no debt, earn 2 credits instead
				gsm.add_credits(2)
			return "Renegotiate debts: Reduce debt by %d, or +2 Credits if debt-free" % debt_relief

		"Rumors of War":
			return "Rumors of war: +2 to Invasion rolls while on this planet"

		"Time on Your Hands":
			return "Time on your hands: 2 random crew roll on Exploration Table"

		"Got Noticed":
			ctx.add_rival("Unwanted attention")
			return "Got noticed: +1 Rival (forced battle next turn if on Quest, +1 enemies)"

		"Time to Go":
			return "Time to go! +1 Rival each turn you stay on this planet"

		"No Ships Authorized":
			return "No ships authorized: Cannot leave planet for 2 turns"

		"Great Story":
			# Casualty gets +1 Luck, else +1 story point
			if gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(1)
			return "Great story: Casualty +1 Luck, or +1 Story Point if no casualties"

		_:
			return "Campaign event: %s (manual resolution)" % event_title

	return "Event resolved"
