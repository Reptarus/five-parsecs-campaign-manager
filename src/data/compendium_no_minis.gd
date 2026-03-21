class_name CompendiumNoMinisCombat
extends RefCounted
## No-Minis Combat Resolution - Compendium pp.68-75 (book pp.66-73)
##
## Abstract battle resolution without miniatures. Allows campaign
## progression without a physical table. Can be mixed with tabletop battles.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.NO_MINIS_COMBAT.
##
## Book structure:
##   - Round phases: (1) Battle Flow Events (optional), (2) Initiative, (3) Firefight
##   - Locations: Suspected → Known via Scout action. 1 character per Location.
##   - Initiative: Roll one die LESS than normal. Captain + those ≤ Reactions get actions.
##   - Firefight: Randomly select 3 enemies (4 if 7+ total). Resolve one at a time.
##   - NOT compatible with: AI Variations, Escalating Battles, Deployment Variables


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.NO_MINIS_COMBAT)


## ============================================================================
## INITIATIVE ACTIONS (Compendium p.70)
## Characters with die ≤ Reactions + Captain each get 1 Initiative Action.
## 2D6 Battlefield Tests where indicated. +1 bonus if character has a
## logically applicable ability/item.
## ============================================================================

const INITIATIVE_ACTIONS: Array[Dictionary] = [
	{"id": "scout_for_locations", "name": "Scout for Locations",
	 "test": "6+", "speed_bonus": true, "not_round_1": true,
	 "description": "Select a suspected Location — it becomes known.",
	 "instruction": "ACTION: Scout for Locations. Select a suspected Location to discover. 2D6 Battlefield Test: 6+ required. +1 if Speed 5\"+. Cannot be used in Round 1."},
	{"id": "move_up", "name": "Move Up",
	 "test": "none", "speed_bonus": false, "not_round_1": false,
	 "description": "Move to any known Location (no character already there), or leave a Location to general battle space.",
	 "instruction": "ACTION: Move Up. Move to any known Location (must be unoccupied). Or leave current Location to general battle space. No roll required."},
	{"id": "carry_out_task", "name": "Carry Out Task",
	 "test": "scenario", "speed_bonus": false, "not_round_1": false,
	 "description": "Achieve objectives. Must be at correct Location. Character may still fight if engaged later.",
	 "instruction": "ACTION: Carry Out Task. Must be at the correct Location. Perform scenario objective action. Character may still fight normally if engaged this round."},
	{"id": "charge", "name": "Charge",
	 "test": "6+", "speed_bonus": true, "not_round_1": false,
	 "description": "Select random enemy. May engage in immediate Brawl. If D6 > your Speed, enemy fires first at 6\" (Cover).",
	 "instruction": "ACTION: Charge. Select a random enemy. 2D6 Battlefield Test: 6+ (+1 if Speed 5\"+, +1 for special movement). If you pass, you may Brawl. Roll 1D6: if > your Speed, enemy fires at 6\" range (Cover) before Brawl."},
	{"id": "optimal_shot", "name": "Optimal Shot",
	 "test": "7+", "speed_bonus": false, "not_round_1": false,
	 "description": "Select random enemy. Fire at chosen range (up to max). Crew fires first. Enemy returns fire if alive.",
	 "instruction": "ACTION: Optimal Shot. Select random enemy. 2D6 Battlefield Test: 7+ (-1 for Heavy weapon). Choose range up to weapon max. Crew member fires first; if target survives, they return fire. If enemy fires here, they skip the Firefight phase."},
	{"id": "support", "name": "Support",
	 "test": "none", "speed_bonus": false, "not_round_1": false,
	 "description": "Select a crew member. If they are engaged, the Supporter takes their place. Lasts until Supporter is engaged.",
	 "instruction": "ACTION: Support. Select a crew member. If that ally is engaged in combat this round, you take their place instead. Lasts until you are engaged for any reason. Can support multiple allies simultaneously."},
	{"id": "take_cover", "name": "Take Cover",
	 "test": "6+", "speed_bonus": false, "not_round_1": false,
	 "description": "All shots by/against this character hit only on natural 6. Lost when using Move Up or engaging in Brawl.",
	 "instruction": "ACTION: Take Cover. 2D6 Battlefield Test: 6+ (-1 if at a Location). All shots by and against you hit only on natural 6. Brawl enemies still engage you. Status lost when you Move Up or Brawl."},
	{"id": "keep_distance", "name": "Keep Distance",
	 "test": "6+", "speed_bonus": true, "not_round_1": false,
	 "description": "Can only be targeted by weapons with range >12\". If engaged, both sides limited to >12\" weapons only.",
	 "instruction": "ACTION: Keep Distance. 2D6 Battlefield Test: 6+ (+1 if Speed 5\"+). This round, you can only be targeted by enemies with weapon range >12\". If targeted, both sides can only use weapons with range >12\"."},
]


## ============================================================================
## FIREFIGHT RULES (Compendium pp.71-72)
## Main phase: randomly select 3 enemies (4 if 7+ total). Resolve one at a time.
## ============================================================================

const FIREFIGHT_RULES: Dictionary = {
	"selection": "Randomly select 3 enemies to fight (4 if 7+ total enemies). Resolve one at a time. Player chooses order.",
	"ranged_vs_ranged": "Both have ranged weapons: Longer range fires first. If tied, crew fires first. Stationary, max range, Cover, max Shots.",
	"melee_only": "One is melee-only: Opponent shoots first at 6\" (Cover, no Heavy/Area weapons). If target survives, resolve Brawl. If defender fired, no Melee weapon bonus (Pistol bonus OK).",
	"melee_and_guns": "Enemy has melee + is out-ranged: Enemy chooses Brawl instead. Crew may also choose this. Pistol-only combatants cannot use this rule.",
	"taking_cover": "Character Taking Cover: All shots by/against hit only on natural 6. If enemy has Brawl weapon, they engage in Brawl (no fire). Covering character may use any weapon in Brawl.",
	"multiple_attacks": "A character may fire only once per round. Crew may choose not to fire. Enemies always fire if able.",
	"ignored_traits": "Area and Terrifying weapon traits are ignored in no-minis combat.",
	"stun": "All Stun markers removed at end of round. Stunned characters cannot attempt Brawling.",
	"support": "If targeted character is Supported, the Supporter may take their place. Does not affect Locations.",
}

const FIREFIGHT_INSTRUCTION: String = (
	"[b]FIREFIGHT PHASE[/b]\n" +
	"Randomly select 3 enemies (4 if 7+ total). Resolve one at a time (player chooses order).\n" +
	"Each enemy targets a random crew member.\n\n" +
	"[b]Both Ranged:[/b] Longer range fires first (crew first if tied). Stationary, max range, Cover, max Shots.\n" +
	"[b]One Melee-Only:[/b] Opponent shoots at 6\" (Cover) first. Survivor resolves Brawl.\n" +
	"[b]Melee + Guns (out-ranged):[/b] Enemy may choose Brawl instead. Crew can too. Not for Pistol-only.\n" +
	"[b]Taking Cover:[/b] All shots hit only on natural 6. Brawl enemies still engage.\n" +
	"[b]Notes:[/b] Max 1 fire per character/round. Area & Terrifying ignored. Stun clears at round end."
)


## ============================================================================
## BATTLE FLOW EVENTS — D100 table (Compendium p.73, optional)
## Roll at beginning of each round. Actions do not prevent normal activation.
## ============================================================================

const BATTLE_FLOW_EVENTS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 6, "id": "fleeting_shot",
	 "instruction": "FLOW: Fleeting Shot. A random crew member may immediately shoot a target of your choice. Max weapon range, firer counts as moving (Heavy penalty), target in Cover. No return fire."},
	{"roll_min": 7, "roll_max": 14, "id": "running_firefight",
	 "instruction": "FLOW: Running Firefight. Random character from each side fires at each other simultaneously. Range = shortest weapon. Both in Cover, both count as moving. Melee-only cannot fire."},
	{"roll_min": 15, "roll_max": 22, "id": "stumble_into_each_other",
	 "instruction": "FLOW: Stumble Into Each Other. Random character from each side. Resolve a Brawl immediately."},
	{"roll_min": 23, "roll_max": 29, "id": "exposed",
	 "instruction": "FLOW: Exposed! A random enemy immediately fires on a random crew member. Max weapon range, stationary shooter, target in Cover. No return fire."},
	{"roll_min": 30, "roll_max": 35, "id": "spot_firing_position",
	 "instruction": "FLOW: Spot Firing Position. Add a known Firing Position Location. A character there counts all ranged targets as being in the open."},
	{"roll_min": 36, "roll_max": 43, "id": "find_shortcut",
	 "instruction": "FLOW: Find Shortcut. A random crew member may move to any known Location, if desired."},
	{"roll_min": 44, "roll_max": 50, "id": "discover_location",
	 "instruction": "FLOW: Discover Location. If any suspected Locations remain, randomly discover one (it becomes known)."},
	{"roll_min": 51, "roll_max": 58, "id": "difficult_sight_lines",
	 "instruction": "FLOW: Difficult Sight-lines. During the Firefight phase this round, select one FEWER enemy figure."},
	{"roll_min": 59, "roll_max": 65, "id": "kill_zone",
	 "instruction": "FLOW: Kill Zone. Roll 1D6+10. ALL gunfire this round takes place at that range (inches). Weapons unable to reach cannot fire."},
	{"roll_min": 66, "roll_max": 72, "id": "open_ground",
	 "instruction": "FLOW: Open Ground. All characters attempting to enter Brawling combat count as being in the open if fired upon."},
	{"roll_min": 73, "roll_max": 80, "id": "intense_fight",
	 "instruction": "FLOW: Intense Fight. During the Firefight phase this round, select one MORE enemy figure."},
	{"roll_min": 81, "roll_max": 86, "id": "careful_maneuvering",
	 "instruction": "FLOW: Careful Maneuvering. Choose an enemy figure. This figure cannot attack in the Firefight phase this round."},
	{"roll_min": 87, "roll_max": 94, "id": "covered_retreat",
	 "instruction": "FLOW: Covered Retreat. You may immediately retreat any number of crew members, if desired."},
	{"roll_min": 95, "roll_max": 100, "id": "separated",
	 "instruction": "FLOW: Separated. No Brawling combat can be attempted this round. Melee-only enemies will not attack."},
]


## ============================================================================
## MORALE & RETREAT (Compendium p.74)
## ============================================================================

const MORALE_RULES: String = (
	"MORALE: Enemies take morale tests as normal at end of round. " +
	"Morale failures remove regular foes first, then Specialists."
)

const RETREAT_RULES: String = (
	"RETREAT: At end of each round, you may retreat up to 2 crew. " +
	"Roll 1D6 per figure: if roll <= their movement Speed, they escape " +
	"(as if leaving the battlefield edge). Characters with special " +
	"movement (Jump Belt, etc.) leave automatically and do not count " +
	"toward the 2-figure limit."
)


## ============================================================================
## MISSION-SPECIFIC NOTES (Compendium pp.74-75)
## ============================================================================

const MISSION_NOTES: Array[Dictionary] = [
	{"id": "access", "name": "Access",
	 "instruction": "MISSION (Access): The console is a suspected Location. Soulless receive +1 bonus to locating it."},
	{"id": "acquire", "name": "Acquire",
	 "instruction": "MISSION (Acquire): The item is in a suspected Location. Pick up by moving there. Character must exit via Retreat rules. If character becomes casualty, item becomes a new known Location."},
	{"id": "defend", "name": "Defend",
	 "instruction": "MISSION (Defend): No additional notes required."},
	{"id": "deliver", "name": "Deliver",
	 "instruction": "MISSION (Deliver): The delivery point is a suspected Location. If the item is dropped, it becomes a new known Location."},
	{"id": "eliminate", "name": "Eliminate",
	 "instruction": "MISSION (Eliminate): The target is not removed due to morale failures unless it is the last enemy on the table."},
	{"id": "fight_off", "name": "Fight Off",
	 "instruction": "MISSION (Fight Off): No additional notes required."},
	{"id": "move_through", "name": "Move Through",
	 "instruction": "MISSION (Move Through): The exit is a suspected Location. Once known, a crew member who moves there can exit the battlefield, fulfilling the condition."},
	{"id": "patrol", "name": "Patrol",
	 "instruction": "MISSION (Patrol): Each objective is a suspected Location. Check an objective by moving a crew member there."},
	{"id": "protect", "name": "Protect",
	 "instruction": "MISSION (Protect): The VIP is attached to a crew member and always accompanies them. While the crew member is on the field, the VIP cannot be attacked directly. If the crew member is a casualty, the VIP acts as a regular character. The objective is a suspected Location."},
	{"id": "secure", "name": "Secure",
	 "instruction": "MISSION (Secure): The center of the battlefield is a suspected Location. Any crew figure at the Location AND not attacked in Brawling combat for 2 consecutive rounds achieves the objective."},
	{"id": "search", "name": "Search",
	 "instruction": "MISSION (Search): Assume there are 5 suspected Locations capable of holding the item."},
]


## ============================================================================
## OPTIONAL VARIANTS (Compendium p.72)
## ============================================================================

const HECTIC_COMBAT: Dictionary = {
	"id": "hectic_combat",
	"name": "Hectic Combat",
	"instruction": "HECTIC COMBAT VARIANT (optional):\n" +
		"Allow characters to shoot EACH TIME they are engaged by an enemy.\n" +
		"After the initial exchange, any subsequent attacks by that character\n" +
		"during the same round will hit only on natural 6s.",
}

const FASTER_COMBAT: Dictionary = {
	"id": "faster_combat",
	"name": "Faster Combat",
	"instruction": "FASTER COMBAT VARIANT (optional):\n" +
		"The first exchange of fire each Firefight phase counts both\n" +
		"combatants as being in the open (no Cover). Subsequent\n" +
		"exchanges assume Cover as normal.",
}


## ============================================================================
## INCOMPATIBLE FLAGS (cannot combine with no-minis)
## ============================================================================

const INCOMPATIBLE_FLAGS: Array[String] = [
	"AI_VARIATIONS",
	"ESCALATING_BATTLES",
	"DEPLOYMENT_VARIABLES",
]


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Generate a no-minis battle setup. Returns empty if disabled.
static func generate_battle_setup(crew_size: int, enemy_count: int) -> Dictionary:
	if not _is_enabled():
		return {}

	# Firefight selects 3 enemies normally, 4 if 7+ total
	var firefight_count := 4 if enemy_count >= 7 else 3

	return {
		"type": "no_minis",
		"crew_size": crew_size,
		"enemy_count": enemy_count,
		"firefight_selection_count": firefight_count,
		"current_round": 0,
		"suspected_locations": [], # Filled by scenario
		"known_locations": [],
	}


## Generate setup instruction text.
static func generate_setup_text(battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var crew_size: int = battle.get("crew_size", 4)
	var enemy_count: int = battle.get("enemy_count", 6)
	var ff_count: int = battle.get("firefight_selection_count", 3)

	var lines: Array[String] = [
		"[b]NO-MINIS COMBAT SETUP[/b] (Compendium pp.68-75)",
		"",
		"[b]Crew:[/b] %d figures." % crew_size,
		"[b]Enemies:[/b] %d figures." % enemy_count,
		"",
		"[b]Round Phases:[/b]",
		"  1. Battle Flow Events (optional — roll D100)",
		"  2. Initiative (roll one die LESS than normal)",
		"  3. Firefight (select %d random enemies)" % ff_count,
		"",
		"[b]Initiative:[/b] Captain + characters with die <= Reactions each get 1 Initiative Action.",
		"  Characters above their Reactions are in the general firefight (no specific actions).",
		"  Available actions: Scout / Move Up / Carry Out Task / Charge / Optimal Shot / Support / Take Cover / Keep Distance",
		"",
		FIREFIGHT_INSTRUCTION,
		"",
		MORALE_RULES,
		"",
		RETREAT_RULES,
	]

	return "\n".join(lines)


## Generate round instruction text.
static func generate_round_text(round_num: int, _battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var ff_count: int = _battle.get("firefight_selection_count", 3)

	var lines: Array[String] = [
		"[b]NO-MINIS ROUND %d[/b]" % round_num,
		"",
	]

	lines.append("[b]1. Battle Flow Event (optional):[/b] Roll D100 on Battle Flow Events table.")
	lines.append("")
	lines.append("[b]2. Initiative:[/b] Roll initiative (one die LESS than normal).")
	lines.append("   Captain + characters with die <= Reactions get 1 Initiative Action each.")
	lines.append("")
	lines.append("[b]3. Firefight:[/b] Randomly select %d enemies. Resolve one at a time." % ff_count)
	lines.append("   Each targets a random crew member. Player chooses resolution order.")
	lines.append("")
	lines.append("[b]4. End of Round:[/b] Remove casualties. Enemy morale test (regulars removed first). May retreat up to 2 crew (1D6 <= Speed = escape).")

	return "\n".join(lines)


## Roll a D100 battle flow event.
static func roll_battle_flow_event() -> Dictionary:
	if not _is_enabled():
		return {}
	var roll := randi_range(1, 100)
	for event in BATTLE_FLOW_EVENTS:
		if roll >= event.roll_min and roll <= event.roll_max:
			var result: Dictionary = event.duplicate()
			result["roll"] = roll
			return result
	return BATTLE_FLOW_EVENTS[0]


## Get mission-specific notes for a mission type.
static func get_mission_notes(mission_id: String) -> String:
	for note in MISSION_NOTES:
		if note.id == mission_id:
			return note.instruction
	return ""


## Check if a flag is incompatible with no-minis mode.
static func is_incompatible(flag_name: String) -> bool:
	return flag_name in INCOMPATIBLE_FLAGS


## Get hectic combat variant text.
static func get_hectic_combat_text() -> String:
	if not _is_enabled():
		return ""
	return HECTIC_COMBAT.instruction


## Get faster combat variant text.
static func get_faster_combat_text() -> String:
	if not _is_enabled():
		return ""
	return FASTER_COMBAT.instruction


## Get firefight rules instruction text.
static func get_firefight_rules() -> String:
	if not _is_enabled():
		return ""
	return FIREFIGHT_INSTRUCTION
