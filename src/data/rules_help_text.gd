class_name RulesHelpText
extends RefCounted

## Rules Help Text Constants for Five Parsecs Campaign Manager
## Extracted from Five Parsecs from Home Core Rulebook
## Used by UI tooltips to provide contextual rule references

# ============================================================================
# CAMPAIGN TURN OVERVIEW (Core Rules p.68)
# ============================================================================

const CAMPAIGN_TURN_OVERVIEW := """[b]Campaign Turn Structure[/b]
Each campaign turn consists of:
[b]Step 1:[/b] Travel Steps (p.69)
[b]Step 2:[/b] World Steps (p.76)
[b]Step 3:[/b] Tabletop Battle (p.87)
[b]Step 4:[/b] Post-Battle Sequence (p.119)"""

# ============================================================================
# TRAVEL PHASE (Core Rules p.69-75)
# ============================================================================

const TRAVEL_PHASE_OVERVIEW := """[b]Travel Phase[/b]
Decide whether to stay on the current world or travel to a new planet.
Ship travel costs [color=#F59E0B]5 credits[/color]. Commercial passage costs [color=#F59E0B]1 credit per crew member[/color].
[i](Rules p.69)[/i]"""

const TRAVEL_DECISION := """[b]Decide Whether to Travel[/b]
Each campaign turn takes place in a single star system. You may leave the current planet for a fresh start.
• Ship travel: [color=#F59E0B]5 credits[/color] (fuel and costs)
• Commercial passage: [color=#F59E0B]1 credit per crew member[/color]
• If traveling by ship, roll on the Starship Travel Events Table
[i](Rules p.69)[/i]"""

const STAY_DECISION := """[b]Stay in Current Location[/b]
Remain on the current world to continue operations.
• All existing Patrons and Rivals remain active
• No travel costs or events
• Proceed directly to World Steps
[i](Rules p.69)[/i]"""

const FLEE_INVASION := """[b]Flee Invasion[/b]
If the world is being Invaded, you must attempt to flee.
Roll [color=#4FC3F7]2D6[/color] - an [color=#10B981]8+[/color] is required to escape safely.
Failure means you must fight an Invasion Battle.
[i](Rules p.69)[/i]"""

const STARSHIP_TRAVEL_EVENTS := """[b]Starship Travel Events[/b]
When traveling by ship, roll [color=#4FC3F7]D100[/color] on the Travel Events Table.
Events range from beneficial encounters to dangerous situations.
Some events can damage your ship's Hull Points.
[i](Rules p.70-71)[/i]"""

const TRAVEL_DAMAGED_SHIP := """[b]Traveling in a Damaged Ship[/b]
If your ship has Hull damage, leaving is dangerous.
Consult the Starship chapter (p.59) for emergency takeoff rules.
[i](Rules p.70)[/i]"""

# ============================================================================
# WORLD STEPS (Core Rules p.76-86)
# ============================================================================

const WORLD_STEPS_OVERVIEW := """[b]World Steps[/b]
1. Upkeep and Ship Repairs
2. Assign and Resolve Crew Tasks
3. Determine Job Offers
4. Assign Equipment
5. Resolve any Rumors
6. Choose your Battle
[i](Rules p.76)[/i]"""

# ============================================================================
# UPKEEP (Core Rules p.76)
# ============================================================================

const UPKEEP_PHASE := """[b]Upkeep Phase[/b]
Pay crew wages and ship maintenance each campaign turn.
• [color=#F59E0B]1 credit[/color] for 4-6 crew members
• [color=#F59E0B]+1 credit[/color] per crew member past 6
• Crew in Sick Bay don't count toward Upkeep
[i](Rules p.76)[/i]"""

const UPKEEP_CREW := """[b]Crew Upkeep[/b]
Covers paychecks, food, booze, and routine expenses.
• 4-6 crew: [color=#F59E0B]1 credit[/color]
• 7+ crew: [color=#F59E0B]+1 credit per extra member[/color]
• Can sell equipment (1 credit per item) to pay Upkeep
• Unpaid crew refuse to work this turn
[i](Rules p.76)[/i]"""

const SHIP_DEBT := """[b]Ship Debt[/b]
If you owe money on your ship:
• Debt increases by [color=#EF4444]1 credit[/color] ([color=#EF4444]2 credits[/color] if debt ≥31)
• At [color=#EF4444]75+ credits[/color] debt, roll 2D6
• On 2-6, your ship is seized!
[i](Rules p.76)[/i]"""

const SHIP_REPAIRS := """[b]Ship Repairs[/b]
• [color=#10B981]1 Hull Point[/color] repaired automatically each turn
• Additional repairs: [color=#F59E0B]1 credit per Hull Point[/color]
• No limit on credits spent
[i](Rules p.76)[/i]"""

const MEDICAL_CARE := """[b]Medical Care[/b]
Speed up recovery for crew in Sick Bay:
• Pay [color=#F59E0B]4 credits[/color] to reduce recovery by 1 turn
• Can be done multiple times
• Also works for Bot repairs
[i](Rules p.76)[/i]"""

# ============================================================================
# CREW TASKS (Core Rules p.77-81)
# ============================================================================

const CREW_TASKS_OVERVIEW := """[b]Crew Tasks[/b]
Each crew member (not in Sick Bay) can perform one task:
• [color=#4FC3F7]Find a Patron[/color] - Search for job offers
• [color=#4FC3F7]Train[/color] - Earn +1 XP
• [color=#4FC3F7]Trade[/color] - Roll on Trade Table
• [color=#4FC3F7]Recruit[/color] - Find new crew
• [color=#4FC3F7]Explore[/color] - Random encounters
• [color=#4FC3F7]Track[/color] - Hunt down Rivals
• [color=#4FC3F7]Repair[/color] - Fix damaged items
• [color=#4FC3F7]Decoy[/color] - Help avoid Rivals
[i](Rules p.77)[/i]"""

const TASK_FIND_PATRON := """[b]Find a Patron[/b]
Roll [color=#4FC3F7]1D6[/color] + number of crew searching + bonuses.
• [color=#10B981]5+[/color]: Found one Patron job
• [color=#10B981]6+[/color]: Found two jobs (choose one)
• Can spend credits for +1 each
[i](Rules p.77)[/i]"""

const TASK_TRAIN := """[b]Train[/b]
Characters earn [color=#8B5CF6]+1 XP[/color] from training.
If this triggers a Character Upgrade, resolve immediately.
[i](Rules p.78)[/i]"""

const TASK_TRADE := """[b]Trade[/b]
Roll once on the Trade Table (p.79) per crew member trading.
• Can get extra rolls by spending [color=#F59E0B]3 credits[/color] each
• Results available immediately
[i](Rules p.79)[/i]"""

const TASK_RECRUIT := """[b]Recruit[/b]
• If crew < 6: Automatically recruit one per searcher
• If crew ≥ 6: Roll [color=#4FC3F7]1D6[/color] + searchers, need [color=#10B981]6+[/color]
• New recruits come with only a Handgun
[i](Rules p.78)[/i]"""

const TASK_EXPLORE := """[b]Explore[/b]
Roll on the Exploration Table (p.80).
Results range from trade opportunities to dangerous encounters.
[i](Rules p.80)[/i]"""

const TASK_TRACK := """[b]Track Rivals[/b]
Roll [color=#4FC3F7]1D6[/color] + number of crew tracking.
• [color=#10B981]6+[/color]: Located a Rival of your choice
• Can fight them this campaign turn
• Spend credits for +1 each
[i](Rules p.78)[/i]"""

const TASK_REPAIR := """[b]Repair Your Kit[/b]
Roll [color=#4FC3F7]1D6[/color] + Savvy (+1 if Engineer).
• [color=#10B981]6+[/color]: Item repaired!
• Natural 1: Item beyond repair
• Spend credits for +1 each
[i](Rules p.78)[/i]"""

const TASK_DECOY := """[b]Decoy[/b]
When rolling to avoid Rivals tracking you:
• [color=#10B981]+1[/color] to roll per crew member acting as Decoy
[i](Rules p.78)[/i]"""

# ============================================================================
# JOB OFFERS / PATRONS (Core Rules p.77, 83-84)
# ============================================================================

const JOB_OFFERS := """[b]Job Offers[/b]
Patrons offer missions with better pay but higher demands.
• Government organizations
• Mega-corporations
• Secretive individuals
Roll for available contracts from your Patron contacts.
[i](Rules p.77)[/i]"""

const PATRON_BENEFITS := """[b]Patron Benefits[/b]
Patron jobs offer additional rewards:
• Higher credit payouts
• Bonus loot and items
• Story progression opportunities
• Building reputation
[i](Rules p.83)[/i]"""

# ============================================================================
# EQUIPMENT (Core Rules p.85)
# ============================================================================

const ASSIGN_EQUIPMENT := """[b]Assign Equipment[/b]
Distribute weapons and gear before battle.
• Each character may carry [color=#4FC3F7]2 weapons[/color]
• Plus a [color=#4FC3F7]Pistol-class weapon or Blade[/color]
• Equipment in Stash is available to all
[i](Rules p.85)[/i]"""

const WEAPON_LIMITS := """[b]Weapon Limits[/b]
A character may carry:
• [color=#4FC3F7]2 weapons[/color] (any type)
• Plus [color=#4FC3F7]1 Pistol[/color] OR [color=#4FC3F7]1 Blade[/color]
[i](Rules p.50)[/i]"""

# ============================================================================
# RUMORS & QUESTS (Core Rules p.86)
# ============================================================================

const RESOLVE_RUMORS := """[b]Resolve Rumors[/b]
Quest Rumors may lead to Quests with greater rewards.
• Track Rumors as a single pool
• Roll each turn to see if Rumors become a Quest
• Active Quests grant new Rumors toward completion
[i](Rules p.86)[/i]"""

const QUEST_PROGRESS := """[b]Quest Progress[/b]
When on an active Quest:
• New Rumors advance Quest progress
• Completing Quests grants major rewards
• Victory Conditions may require Quest completions
[i](Rules p.86)[/i]"""

# ============================================================================
# BATTLE SELECTION (Core Rules p.86)
# ============================================================================

const CHOOSE_BATTLE := """[b]Choose Your Battle[/b]
Select from available mission types:
• [color=#3B82F6]Patron Jobs[/color] - Contracted missions
• [color=#EF4444]Rival Confrontations[/color] - Settle scores
• [color=#F59E0B]Opportunity Missions[/color] - Random encounters
• [color=#6B7280]Roving Threats[/color] - Area dangers
[i](Rules p.86)[/i]"""

const PATRON_MISSION := """[b]Patron Mission[/b]
Accept a job from a Patron contact.
• Specific objectives and requirements
• Higher pay on success
• Reputation consequences on failure
[i](Rules p.83)[/i]"""

const RIVAL_BATTLE := """[b]Rival Confrontation[/b]
Fight a tracked Rival to settle the score.
• Can eliminate Rival permanently
• No pay, but removes ongoing threat
• Gaining reputation in the process
[i](Rules p.77)[/i]"""

const OPPORTUNITY_MISSION := """[b]Opportunity Mission[/b]
Take on a random job or encounter.
• Lower risk, lower reward
• Good for new crews
• No Patron consequences
[i](Rules p.86)[/i]"""

# ============================================================================
# CAMPAIGN EVENTS (Core Rules p.126)
# ============================================================================

const CAMPAIGN_EVENT := """[b]Campaign Event[/b]
Random events that affect your entire crew.
Roll on the Campaign Event Table each turn.
Events can be beneficial, harmful, or narrative.
[i](Rules p.126)[/i]"""

const CHARACTER_EVENT := """[b]Character Event[/b]
Personal events affecting individual crew members.
May change relationships, grant bonuses, or cause problems.
[i](Rules p.126)[/i]"""

# ============================================================================
# PURCHASE / SHOP (Core Rules p.125)
# ============================================================================

const PURCHASE_ITEMS := """[b]Purchase Items[/b]
Buy equipment between missions.
• Weapons, gear, and gadgets available
• Prices vary by world traits
• Some items require licenses
[i](Rules p.125)[/i]"""

# ============================================================================
# HELPER METHODS
# ============================================================================

## Get tooltip text for a specific phase or action
static func get_tooltip(key: String) -> String:
	match key:
		# Campaign Overview
		"campaign_turn": return CAMPAIGN_TURN_OVERVIEW
		
		# Travel Phase
		"travel_phase": return TRAVEL_PHASE_OVERVIEW
		"travel_decision": return TRAVEL_DECISION
		"stay_decision": return STAY_DECISION
		"flee_invasion": return FLEE_INVASION
		"starship_events": return STARSHIP_TRAVEL_EVENTS
		"travel_damaged": return TRAVEL_DAMAGED_SHIP
		
		# World Steps
		"world_steps": return WORLD_STEPS_OVERVIEW
		
		# Upkeep
		"upkeep_phase": return UPKEEP_PHASE
		"upkeep_crew": return UPKEEP_CREW
		"ship_debt": return SHIP_DEBT
		"ship_repairs": return SHIP_REPAIRS
		"medical_care": return MEDICAL_CARE
		
		# Crew Tasks
		"crew_tasks": return CREW_TASKS_OVERVIEW
		"task_patron": return TASK_FIND_PATRON
		"task_train": return TASK_TRAIN
		"task_trade": return TASK_TRADE
		"task_recruit": return TASK_RECRUIT
		"task_explore": return TASK_EXPLORE
		"task_track": return TASK_TRACK
		"task_repair": return TASK_REPAIR
		"task_decoy": return TASK_DECOY
		
		# Job Offers
		"job_offers": return JOB_OFFERS
		"patron_benefits": return PATRON_BENEFITS
		
		# Equipment
		"assign_equipment": return ASSIGN_EQUIPMENT
		"weapon_limits": return WEAPON_LIMITS
		
		# Rumors
		"resolve_rumors": return RESOLVE_RUMORS
		"quest_progress": return QUEST_PROGRESS
		
		# Battle Selection
		"choose_battle": return CHOOSE_BATTLE
		"patron_mission": return PATRON_MISSION
		"rival_battle": return RIVAL_BATTLE
		"opportunity_mission": return OPPORTUNITY_MISSION
		
		# Events
		"campaign_event": return CAMPAIGN_EVENT
		"character_event": return CHARACTER_EVENT
		
		# Purchase
		"purchase_items": return PURCHASE_ITEMS
		
		_:
			push_warning("RulesHelpText: Unknown tooltip key '%s'" % key)
			return "[i]No help text available[/i]"

## Get a short one-line hint (for compact tooltips)
static func get_short_hint(key: String) -> String:
	match key:
		"travel_decision": return "Ship: 5 credits | Commercial: 1 credit/crew (p.69)"
		"stay_decision": return "Remain here - no travel costs (p.69)"
		"upkeep_phase": return "4-6 crew: 1 credit | +1 per extra crew (p.76)"
		"ship_repairs": return "1 free repair/turn | 1 credit per additional (p.76)"
		"crew_tasks": return "Each crew member can do one task (p.77)"
		"assign_equipment": return "2 weapons + 1 pistol/blade per character (p.85)"
		"resolve_rumors": return "Rumors may lead to valuable Quests (p.86)"
		"choose_battle": return "Patron jobs, Rival fights, or Opportunity missions (p.86)"
		_: return ""

