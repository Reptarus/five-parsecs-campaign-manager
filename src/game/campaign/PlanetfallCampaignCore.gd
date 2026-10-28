class_name PlanetfallCampaignCore
extends Resource

## Atomic save writer. All four cores share ONE implementation so the write path
## cannot drift between gamemodes again - see src/core/state/SaveFileWriter.gd.
const SaveFileWriterRef = preload("res://src/core/state/SaveFileWriter.gd")
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")

## Planetfall Campaign Core Resource
## Stores complete Planetfall colony campaign data for save/load operations.
## Follows the same to_dictionary/from_dictionary/save_to_file/load_from_file
## pattern as FiveParsecsCampaignCore and BugHuntCampaignCore.
##
## Key differences from other campaign types:
## - Colony management: Integrity, Morale, Buildings, Research, Tech Tree
## - 18-step campaign turn (vs 9 in 5PFH, 3 in Bug Hunt)
## - 3 character classes (Scientist/Scout/Trooper) + Grunts + Bot
## - Central equipment store (characters don't own items)
## - Grid map with sector states (6x6 to 10x10)
## - Procedural lifeform generation + evolution
## - 7 milestones → 4 campaign endings
## - No ship, no patrons/rivals, no credits, no Luck stat

@export var schema_version: int = 2
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "planetfall"

## QoL data captured during from_dictionary, applied to autoloads later.
## See apply_pending_qol_data() — called by GameState after the campaign is
## set as current. Mirrors FiveParsecsCampaignCore's pattern.
var _pending_qol_data: Dictionary = {}

## Colony info
@export var colony_name: String = ""
@export var expedition_type: String = ""

## Difficulty
@export var difficulty: String = "normal"

## Campaign state
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"  # "creation", "tutorial", "active", "endgame", "completed"
@export var campaign_turn: int = 0

## Where the 18-step turn (Planetfall p.58) stands, so a resume lands on the step the
## player left instead of replaying Recovery onward and re-applying every completed
## step. -1 is the phase manager's NONE (between turns); PHASE_UNRECORDED marks a save
## written before this field existed, which resumes as it always did.
const PHASE_UNRECORDED := -2
var turn_phase: int = PHASE_UNRECORDED
## Turn-scoped facts the steps hand forward and nothing else keeps: the casualties and
## colony damage Morale reads (p.68), the Story Point block a Colony Event sets, and
## the battle result the post-battle steps (pp.66-68) roll from.
var turn_state: Dictionary = {}


func record_turn_phase(phase: int, state: Dictionary) -> void:
	turn_phase = phase
	turn_state = state.duplicate(true)


func has_recorded_turn_phase() -> bool:
	return turn_phase != PHASE_UNRECORDED

## Colony Statistics (Planetfall p.55, Colony Tracking Sheet p.190)
@export var colony_morale: int = 0
@export var colony_integrity: int = 0
## p.87: the score repairs restore Integrity up to. 0 for a new colony; each
## Integrity bonus raises it together with the current score (raise_integrity).
@export var max_colony_integrity: int = 0
@export var build_points_per_turn: int = 1
@export var research_points_per_turn: int = 1
@export var repair_capacity: int = 1
@export var colony_defenses: int = 0
@export var raw_materials: int = 0
@export var story_points: int = 5
@export var augmentation_points: int = 0

## Grunt count (not individual tracking — Planetfall p.16)
@export var grunts: int = 12

## Milestone progression (7 required for End Game — Planetfall p.156)
@export var milestones_completed: int = 0
@export var calamity_points: int = 0
## The sources that have granted a milestone, as "category:id" (p.156: each Building,
## Application, Augmentation or Artifact on the list grants ONE). Nothing recorded this
## before 2026-10-27, so one granting building granted again at every later Research
## and Building step until the End Game launched by itself.
@export var milestone_sources: Array = []
## A save from before milestone_sources existed: the next check claims what is already
## owned WITHOUT granting, because that save has already been paid for it (and more).
var milestone_sources_unseeded: bool = false
## Lasting milestone effects (pp.157-158): "tactical_panic_reduction" and
## "tactical_specialist_kp" (3rd), "tactical_extra_specialists" and
## "enemy_activity_every_enemy" (6th), "slyn_tracking" (4th), "calamities_ended" (7th).
@export var milestone_flags: Dictionary = {}
## Extra rolls a milestone owes "in addition to the normal event" (pp.156-157), by kind:
## "character_event", "colony_event", "enemy_activity". Each step reads its count and
## the phase manager clears it when that step completes.
@export var pending_extra_rolls: Dictionary = {}
## 4th milestone (p.157): conditions the player still has to choose to erase and replace.
@export var pending_condition_replacements: int = 0

## Mission Data counter (4 breakthroughs — Planetfall p.169)
@export var mission_data: int = 0
@export var mission_data_breakthroughs: int = 0

## Slyn tracking (from 4th Milestone onward — Planetfall p.158)
@export var slyn_victories: int = 0
@export var slyn_departed: bool = false

## End Game path selected (Planetfall pp.160-164)
@export var endgame_path: String = ""

## The Fourth Mission Data Breakthrough rolled on the p.169 table (an id from
## mission_data_breakthroughs.json, "" until rolled). Only a COUNT was kept before
## 2026-10-27, so no End Game bonus that names a Breakthrough (pp.161-163) could apply.
@export var final_breakthrough: String = ""

## Final Breakthrough rows that name characters of the player's choice (p.169 21-30 "add 2
## XP to three characters of your choice", 51-60 "Select three characters on your roster
## and raise their Reaction scores by +1"). Queued here so the screen that is up when the
## roll lands can ask, and a save in between keeps them. Each {stat, amount, picks, source}.
var pending_character_awards: Array = []

## End Game progress (pp.160-163): {stage, summit, result}. The Summit votes and the
## stage were held on the panel, so a relaunch re-held the Summit with fresh dice.
var endgame_state: Dictionary = {}

## Bot state (1 per campaign — Planetfall p.17)
@export var bot_operational: bool = true
## p.59: a Broken bot "is repaired at this stage but cannot be deployed into combat
## this turn" -- the turn it was repaired on, or -1.
@export var bot_repaired_turn: int = -1
## p.61 Disruption, see disrupt_enemy().
var disrupted_enemies: Dictionary = {}

## Colony stability (pp.87-90). Political Upheaval rises once per Morale Incident; a
## Crisis fixes Morale at 0 and costs 1 point from every RP/BP/RM source.
@export var political_upheaval: int = 0
@export var in_crisis: bool = false
## p.90 Colonist demands (Morale Incident 56-75): lasts until a supervisor rolls 5+.
@export var colonist_demands: bool = false
## p.90 Protests (Morale Incident 11-25): {character_id, turn} of the trooper sitting
## out; protest_pending until the player has chosen one.
var protest_sitout: Dictionary = {}
var protest_pending: bool = false
## p.87 mitigation per instance of Colony Damage (Colony Shield Network grants 1).
@export var colony_damage_mitigation: int = 0
## {"<turn>": {bp, rp}}: earned-income penalties (pp.88, 90).
var income_penalties: Dictionary = {}
## {"bp": turn, "rp": turn}: the turn each per-turn income was last credited.
var income_credited: Dictionary = {}
## p.63 Scientific dead end: "Your next 3 Research Points earned are wasted." Taken off
## every RP gain by earn_research_points() until it is used up.
@export var research_points_wasted: int = 0
## p.63 Public relations demand: {character_id, turn} of the character who "will not be
## able to participate in a mission this campaign turn" (no Pitched Battle exception,
## unlike p.90 Protests).
var event_sitout: Dictionary = {}
## p.63 Hostile wildlife: the turn whose Colony Morale -2 is owed "unless you play a
## Patrol Mission this turn", or -1. Settled at Mission Determination.
@export var patrol_required_turn: int = -1
## Missions a pre-battle step offers "this campaign turn", {mission_id: {turn, ...}}:
##   rescue          p.59 SOS signal: Colony Morale -3 if another mission is chosen
##   scout_down      p.59 Scout Down!: scout_id (the assigned scout, "" when none)
##   strike          p.62 Patrol: enemy_index, patrol (normal numbers, one Leader, p.128)
##   pitched_battle  p.62 Attack: enemy_index, forced; a loss takes Raid damage
## An offer from an earlier turn is stale and reads as absent (get_mission_offer).
var mission_offers: Dictionary = {}
## pp.70-71 Character Events that outlast Step 17, {character_id: {key: value}}:
##   away_until (int)       R&R: "gone for 2 campaign turns" (no missions, no events)
##   calibrated (bool)      Personal calibrations: +1 hit with one weapon, next mission
##   double_xp (bool)       Personal reflection: double XP on the next mission
##   saved_health (bool)    Excellent health, saved for the next injury
##   xp_forfeit_turn (int)  Personal tragedy: no XP that turn
var character_notes: Dictionary = {}
## p.70 Dispute: [{a, b, turn}], the pair who "cannot both be assigned to the mission
## next campaign turn unless you are fighting a Pitched Battle".
var disputes: Array = []

## Character roster (Array of Dictionaries — lightweight, like Bug Hunt)
## Dict keys: id, name, class, subspecies, reactions, speed, combat_skill,
## toughness, savvy, xp, kp, loyalty, motivation, prior_experience,
## notable_event, abilities, is_imported, source_campaign
var roster: Array = []

## There is no equipment pool to store. p.23's "central equipment store" is assigned at
## Lock and Load, and p.76 makes it available "in any quantity needed", so the store is
## the Armory's availability rule (PlanetfallArmorySystem), not a list. An
## `equipment_pool` array stood here until 2026-10-27, written once as [] and never read.

## Grunt upgrades unlocked (Array of upgrade IDs — Planetfall p.79)
var grunt_upgrades: Array = []

## Colony map (Dictionary — grid sectors with states)
## Structure: {grid_size: [rows, cols], home_sector: [r, c], sectors: {}}
var map_data: Dictionary = {}

## Research state (Dictionary — theories/applications unlocked)
## Structure: {unlocked_theories: [], unlocked_applications: [], current_research: {}}
var research_data: Dictionary = {}

## Buildings (Dictionary — constructed + in-progress)
## Structure: {constructed: [], in_progress: {building_id: bp_remaining}}
var buildings_data: Dictionary = {}

## Lifeform Encounter Table (10-slot, persists permanently — Planetfall p.146)
## Each slot: Dictionary with generated lifeform profile
var lifeform_table: Array = []

## Lifeform evolutions applied (Array of evolution IDs)
var lifeform_evolutions: Array = []

## Battlefield Condition Table (10-slot, persists — Planetfall p.110)
var condition_table: Array = []

## Tactical Enemies: three in total, one emerging at each of the first three Milestones
## (p.50). Each: {type, grunt/specialist/leader weapons, defeated, occupied_sectors
## ["r,c" map keys], strongpoint_located, strongpoint_sector, boss_located (tracked THIS
## turn, p.61), boss_sector}. PlanetfallMap is the one writer of the map keys.
var tactical_enemies: Array = []

## Enemy Information per enemy (keyed by enemy index)
var enemy_info: Dictionary = {}

## Ancient Signs held and not yet spent (p.61): each is {turn}. A successful 1D6 against
## the count locates an Ancient Site on the map and discards them all.
var ancient_signs: Array = []

## Active calamities (Array of Dictionaries)
var active_calamities: Array = []

## Alien Artifacts found (unique per campaign — Planetfall pp.135-136)
var artifacts_found: Array = []

## Defeated Tactical Enemy indices (eliminated via Assault missions)
var defeated_enemies: Array = []

## Tutorial missions completed (Planetfall pp.44-45)
var tutorial_missions: Dictionary = {
	"beacons": false,
	"analysis": false,
	"perimeter": false
}

## Tutorial mission bonuses earned
var tutorial_bonuses: Dictionary = {}

## Sick Bay (character_id → turns_remaining)
var sick_bay: Dictionary = {}

## DLC flags snapshot
var dlc_flags: Dictionary = {}

## Stashed equipment from imported characters (for export back)
var stashed_equipment: Dictionary = {}

## Original character snapshots from import (for lossless export)
var original_character_snapshots: Dictionary = {}


func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at


func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts := str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_pf_" + ts
	elif campaign_id.is_empty():
		campaign_id = "planetfall_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id


## ============================================================================
## DATA INITIALIZATION (used during campaign creation)
## ============================================================================

func set_config(data: Dictionary) -> void:
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	elif data.has("name"):
		campaign_name = data.name
	if data.has("colony_name"):
		colony_name = data.colony_name
	if data.has("expedition_type"):
		expedition_type = data.expedition_type
	if data.has("difficulty"):
		difficulty = data.difficulty
	_update_modified_time()


func initialize_roster(characters: Array) -> void:
	roster = characters.duplicate(true)
	_update_modified_time()


func add_roster_character(char_dict: Dictionary) -> void:
	roster.append(char_dict.duplicate(true))
	_update_modified_time()


func remove_roster_character(character_id: String) -> void:
	for i in range(roster.size() - 1, -1, -1):
		if roster[i].get("id", "") == character_id:
			roster.remove_at(i)
			break
	_update_modified_time()


func get_roster_character_by_id(character_id: String) -> Variant:
	for char_dict in roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				return char_dict
	return null


func get_active_roster() -> Array:
	## Returns roster characters not in sick bay or dead
	var active: Array = []
	for char_dict in roster:
		var cid: String = char_dict.get("id", "")
		if not sick_bay.has(cid) or sick_bay[cid] <= 0:
			active.append(char_dict)
	return active


func initialize_map(data: Dictionary) -> void:
	map_data = data.duplicate(true)
	_update_modified_time()


## ============================================================================
## COLONY MANAGEMENT
## ============================================================================

## p.90: "While in Crisis, Colony Morale is fixed at 0 and cannot be changed for any
## reason. All modifiers are ignored." Every Morale change goes through here.
func adjust_morale(amount: int) -> void:
	if in_crisis:
		return
	colony_morale += amount
	_update_modified_time()


## A Morale RESET, not a modifier: p.89 "Morale is set back to 0" after an Incident,
## and p.90 "Political upheaval and Morale are set to 0" when a Crisis ends.
func set_morale(value: int) -> void:
	colony_morale = value
	_update_modified_time()


## Changes to the CURRENT score only. Colony Damage is take_colony_damage(), an
## Integrity bonus is raise_integrity(), a repair is repair_colony().
func adjust_integrity(amount: int) -> void:
	colony_integrity += amount
	_update_modified_time()


## One instance of Colony Damage (p.87). Buildings mitigate it unless the source says
## it cannot be mitigated (Colony Shield Network: "Mitigate 1 Colony Damage each time
## you receive Colony Damage"). Only the damage TAKEN lowers Morale: "Any time
## Integrity drops for any reason, Colony Morale drops by the same amount ... Damage
## that is mitigated ... does not affect Morale." Returns {taken, mitigated}.
func take_colony_damage(amount: int, mitigable: bool = true) -> Dictionary:
	if amount <= 0:
		return {"taken": 0, "mitigated": 0}
	var mitigated: int = mini(amount, maxi(colony_damage_mitigation, 0)) if mitigable else 0
	var taken: int = amount - mitigated
	colony_integrity -= taken
	adjust_morale(-taken)
	_update_modified_time()
	return {"taken": taken, "mitigated": mitigated}


## p.87: "If you get a bonus to Integrity during the campaign, you increase both the
## maximum Integrity score and the current value." Buildings, research and milestone
## bonuses all went through adjust_integrity() until 2026-10-27, so no maximum was
## ever recorded and repairs stopped at 0 however much the colony had built.
func raise_integrity(amount: int) -> void:
	max_colony_integrity += amount
	colony_integrity += amount
	_update_modified_time()


## How far Integrity is below its maximum: the damage a repair may restore (p.87).
func integrity_damage() -> int:
	return maxi(0, max_colony_integrity - colony_integrity)


func spend_raw_materials(amount: int) -> bool:
	if raw_materials < amount:
		return false
	raw_materials -= amount
	_update_modified_time()
	return true


func add_raw_materials(amount: int) -> void:
	raw_materials += crisis_adjusted_gain(amount)
	_update_modified_time()


## p.90: "All sources of Research Points, Build Points, or Raw Materials provide 1 point
## less than usual during a Crisis." Applied once per source, where it is credited.
func crisis_adjusted_gain(amount: int) -> int:
	if in_crisis and amount > 0:
		return amount - 1
	return amount


## ============================================================================
## PER-TURN INCOME (Steps 14 and 15)
## ============================================================================

## Credit this turn's Build ("bp") or Research ("rp") Points ONCE. The panels credited
## income in refresh(), which runs again on a resume, so a reload paid the turn twice.
## A penalty "only affects points earned, not any stored or already spent" (p.88), so
## it reduces this income and never the pool. Returns {gross, penalty, crisis, net,
## already}.
func claim_turn_income(kind: String) -> Dictionary:
	var gross: int = build_points_per_turn if kind == "bp" else research_points_per_turn
	var receipt := {"gross": gross, "penalty": 0, "crisis": 0, "net": 0, "already": false}
	if int(income_credited.get(kind, -1)) == campaign_turn:
		receipt.already = true
		return receipt
	var pen: Dictionary = income_penalties.get(str(campaign_turn), {})
	receipt.penalty = mini(int(pen.get(kind, 0)), gross)
	var after_penalty: int = gross - int(receipt.penalty)
	receipt.net = crisis_adjusted_gain(after_penalty)
	receipt.crisis = after_penalty - int(receipt.net)
	income_credited[kind] = campaign_turn
	if kind == "bp":
		buildings_data["current_bp"] = int(buildings_data.get("current_bp", 0)) + int(receipt.net)
	else:
		var credited: int = earn_research_points(int(receipt.net))
		receipt["wasted"] = int(receipt.net) - credited
		receipt.net = credited
	_update_modified_time()
	return receipt


## Every Research Point the colony EARNS goes through here, so p.63's Scientific dead end
## ("Your next 3 Research Points earned are wasted") comes off whichever source pays
## next. Spending never comes here. Returns the points actually credited.
func earn_research_points(amount: int) -> int:
	var wasted: int = mini(maxi(amount, 0), research_points_wasted)
	research_points_wasted -= wasted
	var credited: int = amount - wasted
	research_data["current_rp"] = int(research_data.get("current_rp", 0)) + credited
	_update_modified_time()
	return credited


## p.63 Public relations demand: the character sits out every mission this turn.
func assign_event_sitout(character_id: String) -> void:
	event_sitout = {"character_id": character_id, "turn": campaign_turn}
	_update_modified_time()


## p.63 Experimental local medicine: "reduce their recovery time by 2 turns. If the
## character is completely recovered, they can act normally this campaign turn."
## Returns the turns left (0 = out of Sick Bay).
func reduce_recovery(character_id: String, turns: int) -> int:
	if not sick_bay.has(character_id):
		return 0
	var left: int = int(sick_bay[character_id]) - maxi(turns, 0)
	if left <= 0:
		sick_bay.erase(character_id)
		left = 0
	else:
		sick_bay[character_id] = left
	_update_modified_time()
	return left


## pp.88/90: Integrity Failure 6/11/12 hit NEXT turn's income, Work stoppage this one.
func add_income_penalty(turn: int, bp: int, rp: int) -> void:
	var key: String = str(turn)
	var pen: Dictionary = income_penalties.get(key, {"bp": 0, "rp": 0})
	pen["bp"] = int(pen.get("bp", 0)) + maxi(bp, 0)
	pen["rp"] = int(pen.get("rp", 0)) + maxi(rp, 0)
	income_penalties[key] = pen
	for k in income_penalties.keys():
		if int(k) < campaign_turn:
			income_penalties.erase(k)
	_update_modified_time()


## ============================================================================
## MORALE INCIDENT STATE (p.90)
## ============================================================================

## "loses one level of Loyalty": Loyal -> Committed -> Disloyal, never below Disloyal
## (p.24 lists the three stages; the p.71 Disputes event says it "cannot drop below
## Disloyal"). Returns {name, from, to}; from == to when already Disloyal.
func lower_loyalty(character_id: String) -> Dictionary:
	var c: Variant = get_roster_character_by_id(character_id)
	if not c is Dictionary:
		return {}
	var from: String = str(c.get("loyalty", "committed")).to_lower()
	var to: String = "committed" if from == "loyal" else "disloyal"
	c["loyalty"] = to
	_update_modified_time()
	return {"name": str(c.get("name", character_id)), "from": from, "to": to}


## The other direction (p.24 stages): Disloyal -> Committed -> Loyal, never above Loyal.
func raise_loyalty(character_id: String) -> Dictionary:
	var c: Variant = get_roster_character_by_id(character_id)
	if not c is Dictionary:
		return {}
	var from: String = str(c.get("loyalty", "committed")).to_lower()
	var to: String = "committed" if from == "disloyal" else "loyal"
	c["loyalty"] = to
	_update_modified_time()
	return {"name": str(c.get("name", character_id)), "from": from, "to": to}


## The ending a mustered-out veteran carries into another mode (pp.164-166), in the
## transfer matrix's vocabulary: "independence_won" / "independence_lost" / "loyalty" /
## "isolation" / "ascension". "" until the End Game is RESOLVED: a chosen path is not an
## ending, and the dashboard stamped endgame_path ("independence", which matches no
## matrix row) before 2026-10-27.
func get_planetfall_ending() -> String:
	if str(game_phase) != "completed":
		return ""
	var result: Variant = endgame_state.get("result", {})
	if result is Dictionary and str(result.get("ending_id", "")) != "":
		return str(result.get("ending_id", ""))
	# A save resolved before the result was recorded: the path id IS the ending for
	# every path but Independence, whose won/lost split it cannot tell.
	return "" if endgame_path == "independence" else endgame_path


## p.164: after a lost War only "characters that escaped captivity" go on to another
## campaign, so an arrested colonist cannot muster out.
func get_musterable_roster() -> Array:
	var out: Array = []
	for c in roster:
		if c is Dictionary and not bool(c.get("arrested", false)):
			out.append(c)
	return out


## p.69 Step 13: "Dismissed characters cannot be returned to the campaign later." They
## leave the roster and the turn records exactly as a death does.
func dismiss_character(character_id: String) -> void:
	slay_character(character_id)


## A character who dies leaves the roster and every turn record that names them.
func slay_character(character_id: String) -> void:
	remove_roster_character(character_id)
	sick_bay.erase(character_id)
	if str(protest_sitout.get("character_id", "")) == character_id:
		protest_sitout = {}
	if str(event_sitout.get("character_id", "")) == character_id:
		event_sitout = {}
	character_notes.erase(character_id)
	_update_modified_time()


## Queue a Final Breakthrough award the player assigns (see pending_character_awards).
func queue_character_award(stat: String, amount: int, picks: int, source: String) -> void:
	pending_character_awards.append({"stat": stat, "amount": amount, "picks": picks,
			"source": source})
	_update_modified_time()


## Drop the first queued award: the roster has no one left to give it to.
func discard_character_award() -> void:
	if not pending_character_awards.is_empty():
		pending_character_awards.remove_at(0)
		_update_modified_time()


## Give the first queued award to one character and spend one of its picks. Returns the
## line to show, or "" when nothing is queued or the character is not on the roster.
func grant_character_award(character_id: String) -> String:
	if pending_character_awards.is_empty():
		return ""
	var award: Dictionary = pending_character_awards[0]
	var c: Variant = get_roster_character_by_id(character_id)
	# "three characters": three different ones.
	var chosen: Array = award.get("chosen", []) if award.get("chosen") is Array else []
	if not c is Dictionary or chosen.has(character_id):
		return ""
	chosen.append(character_id)
	award["chosen"] = chosen
	var amount: int = int(award.get("amount", 0))
	var line: String = ""
	match str(award.get("stat", "")):
		"xp":
			line = "%s gains %d XP (%s)." % [str(c.get("name", character_id)),
					award_xp(character_id, amount), str(award.get("source", ""))]
		"reactions":
			c["reactions"] = int(c.get("reactions", 0)) + amount
			line = "%s's Reactions rise by %d to %d (%s)." % [str(c.get("name", character_id)),
					amount, int(c["reactions"]), str(award.get("source", ""))]
	award["picks"] = int(award.get("picks", 0)) - 1
	if int(award["picks"]) <= 0:
		pending_character_awards.remove_at(0)
	_update_modified_time()
	return line


## Every XP gain in a turn comes through here, so p.71 Personal tragedy ("Next campaign
## turn they forfeit all XP they would have earned that turn") holds for every source.
## Returns the XP actually awarded.
func award_xp(character_id: String, amount: int) -> int:
	var c: Variant = get_roster_character_by_id(character_id)
	if not c is Dictionary:
		return 0
	if amount > 0 and int(get_character_note(character_id, "xp_forfeit_turn", -1)) == campaign_turn:
		return 0
	c["xp"] = int(c.get("xp", 0)) + amount
	_update_modified_time()
	return amount


## p.89: +1 per roll on the Morale Incident table; p.90 Crisis Outcomes move it both ways.
func change_political_upheaval(amount: int) -> void:
	political_upheaval = maxi(0, political_upheaval + amount)
	_update_modified_time()


func set_political_upheaval(value: int) -> void:
	political_upheaval = maxi(0, value)
	_update_modified_time()


## Entering a Crisis fixes Morale at 0 (p.90); leaving one leaves it where it was set.
func set_crisis(active: bool) -> void:
	in_crisis = active
	if active:
		colony_morale = 0
	_update_modified_time()


func set_colonist_demands(active: bool) -> void:
	colonist_demands = active
	_update_modified_time()


func mark_protest_pending() -> void:
	protest_pending = true
	_update_modified_time()


## p.90 Protests: "Select a trooper that is unable to undertake any missions next
## campaign turn. If you have to fight a Pitched Battle ... the trooper can take part".
func assign_protest(character_id: String) -> void:
	protest_pending = false
	protest_sitout = {"character_id": character_id, "turn": campaign_turn + 1}
	_update_modified_time()


## p.68 Step 12: a Tactical Enemy beaten in battle "cannot take an action next
## campaign turn", which p.61 Disruption enforces at Enemy Activity (except the
## Converted). Tactical enemy index (as a String key: JSON) -> the turn it sits out.
func disrupt_enemy(enemy_index: int) -> void:
	disrupted_enemies[str(enemy_index)] = campaign_turn + 1
	_update_modified_time()


func is_enemy_disrupted(enemy_index: int) -> bool:
	return int(disrupted_enemies.get(str(enemy_index), -1)) == campaign_turn


## p.66: "any bot that became a casualty is marked 'Broken' on your campaign roster
## and cannot be used until repaired."
func break_bot() -> void:
	bot_operational = false
	_update_modified_time()


## p.59 Repairs: a Broken bot "is repaired at this stage but cannot be deployed into
## combat this turn". Returns whether there was anything to repair.
func repair_bot() -> bool:
	if bot_operational:
		return false
	bot_operational = true
	bot_repaired_turn = campaign_turn
	_update_modified_time()
	return true


## Why this character may not deploy on this mission, or "" if they may.
func deployment_block_reason(character_id: String, mission_id: String) -> String:
	var who: Variant = get_roster_character_by_id(character_id)
	if who is Dictionary and str(who.get("class", "")) == "bot":
		if not bot_operational:
			return "BROKEN"
		if bot_repaired_turn == campaign_turn:
			return "REPAIRED THIS TURN"
	if is_away(character_id):
		return "R&R"
	if str(event_sitout.get("character_id", "")) == character_id \
			and int(event_sitout.get("turn", -1)) == campaign_turn:
		return "PUBLIC RELATIONS"
	if protest_sitout.is_empty() or mission_id == "pitched_battle":
		return ""
	if str(protest_sitout.get("character_id", "")) == character_id \
			and int(protest_sitout.get("turn", -1)) == campaign_turn:
		return "PROTESTS"
	return ""


## p.70 Dispute: why `character_id` cannot join `deployed` on this mission, or "".
func deployment_conflict(character_id: String, deployed: Array, mission_id: String) -> String:
	if mission_id == "pitched_battle":
		return ""
	for d in disputes:
		if not d is Dictionary or int(d.get("turn", -1)) != campaign_turn:
			continue
		var a: String = str(d.get("a", ""))
		var b: String = str(d.get("b", ""))
		var other: String = b if a == character_id else (a if b == character_id else "")
		if other != "" and deployed.has(other):
			var who: Variant = get_roster_character_by_id(other)
			return "In a dispute with %s (p.70)" % (str(who.get("name", other))
					if who is Dictionary else other)
	return ""


func add_dispute(a: String, b: String, turn: int) -> void:
	disputes = disputes.filter(func(d): return d is Dictionary and int(d.get("turn", -1)) >= campaign_turn)
	disputes.append({"a": a, "b": b, "turn": turn})
	_update_modified_time()


## p.70 R&R: off world, so no mission and no event can reach them.
func is_away(character_id: String) -> bool:
	return campaign_turn <= int(get_character_note(character_id, "away_until", -1))


func get_character_note(character_id: String, key: String, default: Variant = null) -> Variant:
	return (character_notes.get(character_id, {}) as Dictionary).get(key, default)


func set_character_note(character_id: String, key: String, value: Variant) -> void:
	var notes: Dictionary = character_notes.get(character_id, {})
	notes[key] = value
	character_notes[character_id] = notes
	_update_modified_time()


func clear_character_note(character_id: String, key: String) -> void:
	var notes: Dictionary = character_notes.get(character_id, {})
	notes.erase(key)
	if notes.is_empty():
		character_notes.erase(character_id)
	else:
		character_notes[character_id] = notes
	_update_modified_time()


## p.70 Something in the water: "increase their recovery time by 1 turn".
func extend_recovery(character_id: String, turns: int) -> void:
	if sick_bay.has(character_id):
		sick_bay[character_id] = int(sick_bay[character_id]) + maxi(turns, 0)
		_update_modified_time()


## p.90: "Unity forces move in to secure the site and take over control."
func fail_campaign() -> void:
	game_phase = "failed"
	_update_modified_time()


func is_failed() -> bool:
	return game_phase == "failed"


func spend_story_point() -> bool:
	if story_points <= 0:
		return false
	story_points -= 1
	_update_modified_time()
	return true


func add_story_points(amount: int) -> void:
	story_points += amount
	_update_modified_time()


## ============================================================================
## SICK BAY
## ============================================================================

func add_to_sick_bay(character_id: String, turns: int) -> void:
	sick_bay[character_id] = turns
	_update_modified_time()


func tick_sick_bay() -> Array[String]:
	var recovered: Array[String] = []
	var to_remove: Array[String] = []
	for cid in sick_bay:
		sick_bay[cid] -= 1
		if sick_bay[cid] <= 0:
			recovered.append(cid)
			to_remove.append(cid)
	for cid in to_remove:
		sick_bay.erase(cid)
	if not recovered.is_empty():
		_update_modified_time()
	return recovered


## ============================================================================
## GRUNT MANAGEMENT
## ============================================================================

func lose_grunt() -> void:
	if grunts > 0:
		grunts -= 1
		_update_modified_time()


func gain_grunts(amount: int) -> void:
	grunts += amount
	_update_modified_time()


## ============================================================================
## MILESTONE & PROGRESSION
## ============================================================================

func add_milestone() -> void:
	milestones_completed += 1
	_update_modified_time()


func get_milestone_flag(key: String, default: Variant = null) -> Variant:
	return milestone_flags.get(key, default)


func set_milestone_flag(key: String, value: Variant) -> void:
	milestone_flags[key] = value
	_update_modified_time()


func queue_extra_roll(kind: String, count: int = 1) -> void:
	if count <= 0:
		return
	pending_extra_rolls[kind] = int(pending_extra_rolls.get(kind, 0)) + count
	_update_modified_time()


func get_extra_rolls(kind: String) -> int:
	return int(pending_extra_rolls.get(kind, 0))


func clear_extra_rolls(kind: String) -> void:
	if pending_extra_rolls.erase(kind):
		_update_modified_time()


func is_endgame_eligible() -> bool:
	return milestones_completed >= 7


## ============================================================================
## SECTION 3+4 HELPERS (Conditions, Lifeforms, Enemies, Artifacts)
## ============================================================================

func add_condition(slot: int, condition: Dictionary) -> void:
	while condition_table.size() < 10:
		condition_table.append({})
	if slot >= 0 and slot < 10:
		condition_table[slot] = condition.duplicate(true)
		_update_modified_time()


func get_lifeform_at_slot(slot: int) -> Dictionary:
	if slot >= 0 and slot < lifeform_table.size():
		var entry: Variant = lifeform_table[slot]
		if entry is Dictionary:
			return entry
	return {}


func add_tactical_enemy(enemy: Dictionary) -> void:
	tactical_enemies.append(enemy.duplicate(true))
	_update_modified_time()


func mark_enemy_defeated(enemy_index: int) -> void:
	if enemy_index >= 0 and enemy_index < tactical_enemies.size():
		var enemy: Variant = tactical_enemies[enemy_index]
		if enemy is Dictionary:
			enemy["defeated"] = true
			# p.51: "all occupied sectors are abandoned immediately."
			enemy["occupied_sectors"] = []
		if enemy_index not in defeated_enemies:
			defeated_enemies.append(enemy_index)
		_update_modified_time()


func get_active_tactical_enemies() -> Array:
	var active: Array = []
	for i in range(tactical_enemies.size()):
		var te: Variant = tactical_enemies[i]
		if te is Dictionary and not te.get("defeated", false):
			var entry: Dictionary = te.duplicate(true)
			entry["index"] = i
			active.append(entry)
	return active


func add_artifact(artifact: Dictionary) -> bool:
	## Returns false if artifact already found (unique per campaign).
	var artifact_id: String = artifact.get("id", "")
	for existing in artifacts_found:
		if existing is Dictionary and existing.get("id", "") == artifact_id:
			return false
	artifacts_found.append(artifact.duplicate(true))
	_update_modified_time()
	return true


func has_artifact(artifact_id: String) -> bool:
	for existing in artifacts_found:
		if existing is Dictionary and existing.get("id", "") == artifact_id:
			return true
	return false


## p.51: "Once you have obtained 6 Enemy Information, there is no need to get any more"
## and p.61: "Excess Enemy Information is ignored."
const ENEMY_INFO_MAX := 6


## The ONE store of Enemy Information, keyed by enemy index. Each enemy record also
## carried an `enemy_info` field that nothing wrote; readers use get_enemy_info_count().
func increment_enemy_info(enemy_index: int, amount: int) -> void:
	var key: String = str(enemy_index)
	var current: int = int(enemy_info.get(key, 0))
	enemy_info[key] = clampi(current + amount, 0, ENEMY_INFO_MAX)
	_update_modified_time()


func get_enemy_info_count(enemy_index: int) -> int:
	return int(enemy_info.get(str(enemy_index), 0))


## Record a mission a pre-battle step offers for THIS turn (see mission_offers).
func offer_mission(mission_id: String, details: Dictionary = {}) -> void:
	var offer: Dictionary = details.duplicate(true)
	offer["turn"] = campaign_turn
	mission_offers[mission_id] = offer
	_update_modified_time()


## This turn's offer for a mission, or {} (none, or one left over from an earlier turn).
func get_mission_offer(mission_id: String) -> Dictionary:
	var offer: Variant = mission_offers.get(mission_id, {})
	if offer is Dictionary and int((offer as Dictionary).get("turn", -1)) == campaign_turn:
		return offer
	return {}


func clear_mission_offer(mission_id: String) -> void:
	mission_offers.erase(mission_id)
	_update_modified_time()


func is_slyn_active() -> bool:
	## Slyn attacks begin from 4th milestone and end when slyn_departed is true.
	return milestones_completed >= 4 and not slyn_departed


func add_mission_data_points(amount: int) -> void:
	mission_data += amount
	_update_modified_time()


## ============================================================================
## TURN-STEP HELPERS (used by PlanetfallPhaseManager + panels)
## ============================================================================

## Step 11 and Step 16 are resolved by PlanetfallColonyCrisis and applied by
## PlanetfallPhaseManager.resolve_morale_step() / resolve_integrity_step().


func apply_colony_event(event_data: Dictionary) -> Array:
	## Apply the effects of a colony event (Step 5). Planetfall pp.63-64.
	## Panels will call specific mutation methods; this is a convenience stub
	## for events that only need simple stat changes. Returns the lines only the
	## application knows (an Ancient Sign's Site roll).
	var lines: Array = []
	if event_data.has("colony_morale"):
		adjust_morale(int(event_data.get("colony_morale", 0)))
	if event_data.has("research_points"):
		earn_research_points(crisis_adjusted_gain(int(event_data.get("research_points", 0))))
	if event_data.has("build_points"):
		var bp: int = crisis_adjusted_gain(int(event_data.get("build_points", 0)))
		buildings_data["current_bp"] = int(buildings_data.get("current_bp", 0)) + bp
	if event_data.has("ancient_signs"):
		# p.61: each Sign obtained is tested for an Ancient Site as it arrives.
		lines.append_array(MapScript.obtain_ancient_signs(self,
				int(event_data.get("ancient_signs", 0))))
	if event_data.has("grunts"):
		grunts += event_data.get("grunts", 0)
	_update_modified_time()
	return lines


func repair_colony(points: int) -> int:
	## Step 2: Restore colony integrity. Planetfall p.59. Returns the points restored:
	## p.87 "Repairs can never increase Integrity above the maximum value".
	var repaired: int = mini(maxi(points, 0), integrity_damage())
	colony_integrity += repaired
	_update_modified_time()
	return repaired


## ============================================================================
## RESEARCH & BUILDING STATE (Sprint 2)
## ============================================================================

func get_research_summary() -> Dictionary:
	var rd: Dictionary = research_data
	return {
		"current_rp": rd.get("current_rp", 0),
		"completed_theories": rd.get("completed_theories", []).size(),
		"unlocked_applications": rd.get("unlocked_applications", []).size()
	}


func get_building_summary() -> Dictionary:
	var bd: Dictionary = buildings_data
	return {
		"current_bp": bd.get("current_bp", 0),
		"constructed": bd.get("constructed", []).size(),
		"in_progress": bd.get("in_progress", {}).size()
	}


func get_augmentation_count() -> int:
	return research_data.get("augmentations_owned", []).size()


## ============================================================================
## VALIDATION
## ============================================================================

func validate() -> bool:
	if campaign_name.is_empty():
		return false
	if roster.size() < 3:
		return false
	return true


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if campaign_name.is_empty():
		errors.append("Pick a name for your campaign. Anything memorable works.")
	if roster.size() < 3:
		errors.append("Planetfall needs at least 3 roster characters. Add a few in the Roster step.")
	if roster.size() > 10:
		errors.append("Planetfall caps at 10 roster characters. Remove someone to continue.")
	# Check class minimums
	var class_counts := {"scientist": 0, "scout": 0, "trooper": 0}
	for char_dict in roster:
		var cls: String = char_dict.get("class", "")
		if class_counts.has(cls):
			class_counts[cls] += 1
	for cls in class_counts:
		if class_counts[cls] < 1:
			errors.append("Roster must include at least one %s" % cls)
	return errors


## ============================================================================
## CAMPAIGN SUMMARY
## ============================================================================

func get_campaign_summary() -> Dictionary:
	return {
		"name": campaign_name,
		"type": "planetfall",
		"colony": colony_name,
		"expedition": expedition_type,
		"difficulty": difficulty,
		"roster_size": roster.size(),
		"grunts": grunts,
		"campaign_turn": campaign_turn,
		"milestones": milestones_completed,
		"morale": colony_morale,
		"integrity": colony_integrity,
		"story_points": story_points,
		"created": created_at,
		"status": game_phase
	}


func start_campaign() -> void:
	game_phase = "active"
	_update_modified_time()


func advance_turn() -> void:
	campaign_turn += 1
	_update_modified_time()


## ============================================================================
## SERIALIZATION
## ============================================================================

func to_dictionary() -> Dictionary:
	return {
		"campaign_id": get_campaign_id(),
		"campaign_type": "planetfall",
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"campaign_type": "planetfall",
			"schema_version": schema_version,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase
		},
		"config": {
			"name": campaign_name,
			"colony_name": colony_name,
			"expedition_type": expedition_type,
			"difficulty": difficulty
		},
		"roster": roster.duplicate(true),
		"colony": {
			"colony_morale": colony_morale,
			"colony_integrity": colony_integrity,
			"max_colony_integrity": max_colony_integrity,
			"build_points_per_turn": build_points_per_turn,
			"research_points_per_turn": research_points_per_turn,
			"repair_capacity": repair_capacity,
			"colony_defenses": colony_defenses,
			"raw_materials": raw_materials,
			"story_points": story_points,
			"augmentation_points": augmentation_points,
			"grunts": grunts,
			"bot_operational": bot_operational,
			"bot_repaired_turn": bot_repaired_turn,
			"disrupted_enemies": disrupted_enemies.duplicate(),
			"political_upheaval": political_upheaval,
			"in_crisis": in_crisis,
			"colonist_demands": colonist_demands,
			"protest_sitout": protest_sitout.duplicate(),
			"protest_pending": protest_pending,
			"colony_damage_mitigation": colony_damage_mitigation,
			"income_penalties": income_penalties.duplicate(true),
			"income_credited": income_credited.duplicate(),
			"research_points_wasted": research_points_wasted,
			"event_sitout": event_sitout.duplicate(),
			"patrol_required_turn": patrol_required_turn,
			"mission_offers": mission_offers.duplicate(true),
			"character_notes": character_notes.duplicate(true),
			"disputes": disputes.duplicate(true),
		},
		"progression": {
			"campaign_turn": campaign_turn,
			"turn_phase": turn_phase,
			"turn_state": turn_state.duplicate(true),
			"milestones_completed": milestones_completed,
			"calamity_points": calamity_points,
			"milestone_sources": milestone_sources.duplicate(),
			"milestone_flags": milestone_flags.duplicate(true),
			"pending_extra_rolls": pending_extra_rolls.duplicate(true),
			"pending_condition_replacements": pending_condition_replacements,
			"mission_data": mission_data,
			"mission_data_breakthroughs": mission_data_breakthroughs,
			"slyn_victories": slyn_victories,
			"slyn_departed": slyn_departed,
			"endgame_path": endgame_path,
			"final_breakthrough": final_breakthrough,
			"pending_character_awards": pending_character_awards.duplicate(true),
			"endgame_state": endgame_state.duplicate(true)
		},
		"map_data": map_data.duplicate(true),
		"research_data": research_data.duplicate(true),
		"buildings_data": buildings_data.duplicate(true),
		"grunt_upgrades": grunt_upgrades.duplicate(),
		"lifeform_table": lifeform_table.duplicate(true),
		"lifeform_evolutions": lifeform_evolutions.duplicate(),
		"condition_table": condition_table.duplicate(true),
		"tactical_enemies": tactical_enemies.duplicate(true),
		"enemy_info": enemy_info.duplicate(),
		"ancient_signs": ancient_signs.duplicate(true),
		"active_calamities": active_calamities.duplicate(true),
		"artifacts_found": artifacts_found.duplicate(true),
		"defeated_enemies": defeated_enemies.duplicate(),
		"tutorial_missions": tutorial_missions.duplicate(),
		"tutorial_bonuses": tutorial_bonuses.duplicate(),
		"sick_bay": sick_bay.duplicate(),
		"dlc_flags": dlc_flags.duplicate(),
		"stashed_equipment": stashed_equipment.duplicate(true),
		"original_character_snapshots": original_character_snapshots.duplicate(true),
		"qol_data": _build_qol_data(),
	}


func from_dictionary(data: Dictionary) -> void:
	# Meta
	if data.has("meta"):
		var meta: Dictionary = data.meta
		campaign_id = meta.get("campaign_id", "")
		campaign_name = meta.get("campaign_name", "")
		schema_version = meta.get("schema_version", 1)
		created_at = meta.get("created_at", "")
		last_modified = meta.get("last_modified", "")
		version = meta.get("version", "1.0")
		game_phase = meta.get("game_phase", "creation")

	if campaign_id.is_empty() and data.has("campaign_id"):
		campaign_id = data.get("campaign_id", "")

	# Config
	if data.has("config"):
		var config: Dictionary = data.config
		if campaign_name.is_empty():
			campaign_name = config.get("name", "")
		colony_name = config.get("colony_name", "")
		expedition_type = config.get("expedition_type", "")
		difficulty = config.get("difficulty", "normal")

	# Roster
	roster = data.get("roster", []).duplicate(true)

	# Colony stats
	if data.has("colony"):
		var colony: Dictionary = data.colony
		colony_morale = colony.get("colony_morale", 0)
		colony_integrity = colony.get("colony_integrity", 0)
		# A save older than the field cannot say how much was built, but a positive
		# score can only have come from bonuses, so the maximum is at least that.
		max_colony_integrity = maxi(int(colony.get("max_colony_integrity", 0)),
				int(colony_integrity))
		build_points_per_turn = colony.get("build_points_per_turn", 1)
		research_points_per_turn = colony.get("research_points_per_turn", 1)
		repair_capacity = colony.get("repair_capacity", 1)
		colony_defenses = colony.get("colony_defenses", 0)
		raw_materials = colony.get("raw_materials", 0)
		story_points = colony.get("story_points", 5)
		augmentation_points = colony.get("augmentation_points", 0)
		grunts = colony.get("grunts", 12)
		bot_operational = colony.get("bot_operational", true)
		bot_repaired_turn = int(colony.get("bot_repaired_turn", -1))
		var dis: Variant = colony.get("disrupted_enemies", {})
		disrupted_enemies = (dis as Dictionary).duplicate() if dis is Dictionary else {}
		# int(): JSON hands every number back as a float.
		political_upheaval = int(colony.get("political_upheaval", 0))
		in_crisis = bool(colony.get("in_crisis", false))
		colonist_demands = bool(colony.get("colonist_demands", false))
		var ps: Variant = colony.get("protest_sitout", {})
		protest_sitout = (ps as Dictionary).duplicate() if ps is Dictionary else {}
		protest_pending = bool(colony.get("protest_pending", false))
		colony_damage_mitigation = int(colony.get("colony_damage_mitigation", 0))
		var ip: Variant = colony.get("income_penalties", {})
		income_penalties = (ip as Dictionary).duplicate(true) if ip is Dictionary else {}
		var ic: Variant = colony.get("income_credited", {})
		income_credited = (ic as Dictionary).duplicate() if ic is Dictionary else {}
		research_points_wasted = int(colony.get("research_points_wasted", 0))
		var es: Variant = colony.get("event_sitout", {})
		event_sitout = (es as Dictionary).duplicate() if es is Dictionary else {}
		patrol_required_turn = int(colony.get("patrol_required_turn", -1))
		var mo: Variant = colony.get("mission_offers", {})
		mission_offers = (mo as Dictionary).duplicate(true) if mo is Dictionary else {}
		var cn: Variant = colony.get("character_notes", {})
		character_notes = (cn as Dictionary).duplicate(true) if cn is Dictionary else {}
		var dp: Variant = colony.get("disputes", [])
		disputes = (dp as Array).duplicate(true) if dp is Array else []

	# Progression
	if data.has("progression"):
		var prog: Dictionary = data.progression
		campaign_turn = prog.get("campaign_turn", 0)
		# int(): JSON hands every number back as a float.
		turn_phase = int(prog.get("turn_phase", PHASE_UNRECORDED))
		var ts: Variant = prog.get("turn_state", {})
		turn_state = (ts as Dictionary).duplicate(true) if ts is Dictionary else {}
		milestones_completed = prog.get("milestones_completed", 0)
		calamity_points = prog.get("calamity_points", 0)
		var ms: Variant = prog.get("milestone_sources", null)
		milestone_sources = (ms as Array).duplicate() if ms is Array else []
		milestone_sources_unseeded = not prog.has("milestone_sources")
		var mf: Variant = prog.get("milestone_flags", {})
		milestone_flags = (mf as Dictionary).duplicate(true) if mf is Dictionary else {}
		var per: Variant = prog.get("pending_extra_rolls", {})
		pending_extra_rolls = (per as Dictionary).duplicate(true) if per is Dictionary else {}
		pending_condition_replacements = int(prog.get("pending_condition_replacements", 0))
		mission_data = prog.get("mission_data", 0)
		mission_data_breakthroughs = prog.get("mission_data_breakthroughs", 0)
		slyn_victories = prog.get("slyn_victories", 0)
		slyn_departed = prog.get("slyn_departed", false)
		endgame_path = prog.get("endgame_path", "")
		final_breakthrough = str(prog.get("final_breakthrough", ""))
		var pca: Variant = prog.get("pending_character_awards", [])
		pending_character_awards = (pca as Array).duplicate(true) if pca is Array else []
		var es: Variant = prog.get("endgame_state", {})
		endgame_state = (es as Dictionary).duplicate(true) if es is Dictionary else {}

	# Complex data
	map_data = data.get("map_data", {}).duplicate(true)
	research_data = data.get("research_data", {}).duplicate(true)
	buildings_data = data.get("buildings_data", {}).duplicate(true)
	grunt_upgrades = data.get("grunt_upgrades", []).duplicate()
	lifeform_table = data.get("lifeform_table", []).duplicate(true)
	lifeform_evolutions = data.get("lifeform_evolutions", []).duplicate()
	condition_table = data.get("condition_table", []).duplicate(true)
	tactical_enemies = data.get("tactical_enemies", []).duplicate(true)
	enemy_info = data.get("enemy_info", {}).duplicate()
	ancient_signs = data.get("ancient_signs", []).duplicate(true)
	active_calamities = data.get("active_calamities", []).duplicate(true)
	artifacts_found = data.get("artifacts_found", []).duplicate(true)
	defeated_enemies = data.get("defeated_enemies", []).duplicate()
	tutorial_missions = data.get("tutorial_missions", {"beacons": false, "analysis": false, "perimeter": false}).duplicate()
	tutorial_bonuses = data.get("tutorial_bonuses", {}).duplicate()
	sick_bay = data.get("sick_bay", {}).duplicate()
	dlc_flags = data.get("dlc_flags", {}).duplicate()
	stashed_equipment = data.get("stashed_equipment", {}).duplicate(true)
	original_character_snapshots = data.get("original_character_snapshots", {}).duplicate(true)

	# Capture qol_data for deferred apply (after autoloads are reachable).
	if data.has("qol_data"):
		_pending_qol_data = {"qol_data": data.get("qol_data", {}).duplicate(true)}


## ============================================================================
## QOL DATA (cross-mode journal persistence)
## ============================================================================

func _build_qol_data() -> Dictionary:
	## Collect QoL system data for save. Currently only the CampaignJournal —
	## other 5PFH-specific autoloads (NPCTracker, WorldEconomyManager, etc.)
	## are not populated in Planetfall mode.
	var qol: Dictionary = {}
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return qol
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("save_to_dict"):
		qol["journal"] = journal.save_to_dict()
	return qol


func apply_pending_qol_data() -> void:
	## Called after scene tree is ready (boot auto-load) OR after mid-session
	## load (via GameState.load_campaign). Restores journal entries that the
	## campaign accumulated before save, AND clears any leftover planet state
	## from a previous 5PFH session (Planetfall uses its own colony state, not
	## the shared PlanetDataManager autoload).
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return
	# Planetfall uses its own colony state; ALWAYS clear PlanetDataManager so
	# stale 5PFH visited_planets / travel_history can't bleed into this mode
	# via the shared autoload (Opus 4.8 audit B3 — Galaxy Log plan, 2026-06-01).
	var planet_mgr = root.get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("deserialize_all"):
		planet_mgr.deserialize_all({})
	if _pending_qol_data.is_empty():
		return
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("load_from_save"):
		journal.load_from_save(_pending_qol_data)
	_pending_qol_data = {}


func save_to_file(path: String) -> Error:
	# ATOMIC write — see src/core/state/SaveFileWriter.gd. Opening the live path with
	# FileAccess.WRITE truncates it to 0 bytes immediately, so a kill mid-write
	# destroyed the campaign. Shared with the other three cores so the four write
	# paths cannot drift apart again.
	#
	# This one also silently returned the OPEN error only; a failed WRITE still
	# reported OK. write_text_atomic checks the write and leaves the previous save
	# intact on failure.
	var write_err: Error = SaveFileWriterRef.write_text_atomic(
		path, JSON.stringify(to_dictionary()))
	if write_err != OK:
		push_error("PlanetfallCampaignCore: Failed to save: %s (error: %d)" % [path, write_err])
	return write_err


static func load_from_file(path: String) -> PlanetfallCampaignCore:
	## Reads through SaveFileWriter so the .bak generation written by save_to_file()
	## is actually consulted when the primary is truncated or unparseable.
	var data := SaveFileWriterRef.read_json_with_fallback(path)
	if data.is_empty():
		return null
	var _Self = load("res://src/game/campaign/PlanetfallCampaignCore.gd")
	var campaign = _Self.new()
	campaign.from_dictionary(data)
	return campaign


## ============================================================================
## INTERNAL
## ============================================================================

func _update_modified_time() -> void:
	last_modified = Time.get_datetime_string_from_system()
