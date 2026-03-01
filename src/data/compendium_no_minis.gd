class_name CompendiumNoMinisCombat
extends RefCounted
## No-Minis Combat - Abstract battle resolution without miniatures
##
## Allows campaign progression without a physical table (Compendium pp.86-100).
## Battlefield = abstract space with Locations (3-5 per battle).
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.NO_MINIS_COMBAT.
##
## Key mechanics:
##   - Locations replace positioning (FAR / MEDIUM / CLOSE / COVER)
##   - Initiative: Roll one die LESS than normal
##   - Initiative Actions: Engage, Fire, Take Cover, Sprint
##   - Enemy Actions: D6 per enemy determines behavior
##   - Firefight resolution: simultaneous fire, then movement
##   - Optional variants: Hectic Combat, Faster Combat, Battle Flow Events
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
## LOCATION TYPES
## ============================================================================

enum LocationZone { FAR, MEDIUM, CLOSE, COVER }

const LOCATION_TYPES: Array[Dictionary] = [
	{"id": "open_ground", "name": "Open Ground", "zone": LocationZone.FAR,
	 "cover": false, "elevated": false,
	 "instruction": "LOCATION: Open Ground. No cover. Full visibility. Ranged attacks at normal accuracy."},
	{"id": "light_cover", "name": "Light Cover", "zone": LocationZone.MEDIUM,
	 "cover": true, "elevated": false,
	 "instruction": "LOCATION: Light Cover. Partial cover (-1 to hit). Standard engagement range."},
	{"id": "heavy_cover", "name": "Heavy Cover", "zone": LocationZone.COVER,
	 "cover": true, "elevated": false,
	 "instruction": "LOCATION: Heavy Cover. Full cover (-2 to hit). Must leave cover to fire (except if elevated)."},
	{"id": "elevated", "name": "Elevated Position", "zone": LocationZone.FAR,
	 "cover": true, "elevated": true,
	 "instruction": "LOCATION: Elevated Position. Cover (-1 to hit). +1 to ranged attacks from here. Can fire while in cover."},
	{"id": "objective", "name": "Objective Site", "zone": LocationZone.MEDIUM,
	 "cover": false, "elevated": false,
	 "instruction": "LOCATION: Objective Site. Mission-critical location. Interact with 1 action while here."},
	{"id": "hazard", "name": "Hazardous Area", "zone": LocationZone.CLOSE,
	 "cover": false, "elevated": false,
	 "instruction": "LOCATION: Hazardous Area. Entering: D6 1-2 = D6 damage. Enemies avoid unless forced."},
]


## ============================================================================
## INITIATIVE ACTIONS (player choices per activated figure)
## ============================================================================

const INITIATIVE_ACTIONS: Array[Dictionary] = [
	{"id": "fire", "name": "Fire",
	 "instruction": "ACTION: Fire. Roll to hit using weapon profile. Target must be in LoS (not behind Heavy Cover unless you're elevated). -1 die from normal (no-minis penalty)."},
	{"id": "engage", "name": "Engage (Brawl)",
	 "instruction": "ACTION: Engage. Move to target's Location and initiate Brawl. Both roll D6 + Combat Skill. Higher wins. Loser takes 1 wound. Ties = both take 1 wound."},
	{"id": "take_cover", "name": "Take Cover",
	 "instruction": "ACTION: Take Cover. Move to nearest Cover location (or hunker down if already in cover). Gain -1 to be hit until next activation. Cannot fire this activation."},
	{"id": "sprint", "name": "Sprint",
	 "instruction": "ACTION: Sprint. Move up to 2 Locations (normally 1). Cannot fire or engage. D6: 1 = stumble (stay at current location)."},
	{"id": "search", "name": "Search/Interact",
	 "instruction": "ACTION: Search/Interact. Must be at Objective location. Spend 1 action. Roll D6+Savvy: 6+ = success. Some objectives require multiple successes."},
	{"id": "first_aid", "name": "First Aid",
	 "instruction": "ACTION: First Aid. Target ally at same Location. Roll D6: 4+ = remove 1 wound (or remove Stunned). Requires medical supplies for bonus (+1)."},
]


## ============================================================================
## ENEMY ACTION TABLE (D6 per enemy each round)
## ============================================================================

const ENEMY_ACTION_TABLE: Array[Dictionary] = [
	{"roll": 1, "id": "advance_fire",
	 "instruction": "ENEMY: Advance and Fire. Enemy moves 1 Location closer, then fires at nearest crew."},
	{"roll": 2, "id": "advance_fire_2",
	 "instruction": "ENEMY: Advance and Fire. Enemy moves 1 Location closer, then fires at nearest crew."},
	{"roll": 3, "id": "hold_fire",
	 "instruction": "ENEMY: Hold and Fire. Enemy stays at current Location and fires at nearest visible crew. +1 to hit (steady aim)."},
	{"roll": 4, "id": "hold_fire_2",
	 "instruction": "ENEMY: Hold and Fire. Enemy stays at current Location and fires at nearest visible crew. +1 to hit (steady aim)."},
	{"roll": 5, "id": "advance_engage",
	 "instruction": "ENEMY: Advance and Engage. Enemy sprints toward nearest crew. If at same Location, initiates Brawl."},
	{"roll": 6, "id": "special",
	 "instruction": "ENEMY: Special Action. Roll D6:\n  1-2: Retreat to Cover\n  3-4: Coordinate (next enemy ally gets +1 to hit)\n  5-6: Aggressive Rush (move 2 Locations toward objective, fire if able)"},
]


## ============================================================================
## BATTLE FLOW EVENTS (optional, D6 per round)
## ============================================================================

const BATTLE_FLOW_EVENTS: Array[Dictionary] = [
	{"roll": 1, "id": "quiet",
	 "instruction": "FLOW EVENT: Quiet Round. No special effects. Fight proceeds normally."},
	{"roll": 2, "id": "dust_storm",
	 "instruction": "FLOW EVENT: Dust Storm. All ranged attacks -1 to hit this round. Sprint actions auto-succeed (no stumble check)."},
	{"roll": 3, "id": "power_fluctuation",
	 "instruction": "FLOW EVENT: Power Fluctuation. Energy weapons malfunction on natural 1 (cannot fire next round). Ballistic weapons unaffected."},
	{"roll": 4, "id": "reinforcements_possible",
	 "instruction": "FLOW EVENT: Reinforcements Inbound. Roll D6: 5-6 = D3 basic enemies arrive at FAR location next round."},
	{"roll": 5, "id": "morale_shift",
	 "instruction": "FLOW EVENT: Morale Shift. If crew has more casualties than enemies: -1 to crew hit rolls. If enemies have more: enemies retreat 1 Location."},
	{"roll": 6, "id": "opportunity",
	 "instruction": "FLOW EVENT: Opportunity! One crew member may take a free action (any type) in addition to normal activation this round."},
]


## ============================================================================
## INCOMPATIBLE FLAGS (cannot combine with no-minis)
## ============================================================================

const INCOMPATIBLE_FLAGS: Array[String] = [
	"AI_VARIATIONS",
	"ESCALATING_BATTLES",
	"DEPLOYMENT_VARIABLES",
]


## ============================================================================
## HECTIC COMBAT VARIANT (optional)
## ============================================================================

const HECTIC_COMBAT: Dictionary = {
	"instruction": "HECTIC COMBAT VARIANT:\n" +
		"  - Simultaneous activation: ALL crew act, THEN all enemies act\n" +
		"  - No initiative roll (crew always goes first)\n" +
		"  - All attacks resolve simultaneously (casualties removed after all fire)\n" +
		"  - Brawls resolved immediately when both in same Location\n" +
		"  - Faster pace: reduce battle to 5 rounds max\n" +
		"  - Recommended for: quick sessions, simple battles",
}


## ============================================================================
## FASTER COMBAT VARIANT (optional)
## ============================================================================

const FASTER_COMBAT: Dictionary = {
	"instruction": "FASTER COMBAT VARIANT:\n" +
		"  - Reduce enemy count by 25% (round down, min 3)\n" +
		"  - Reduce Locations to 3 (FAR, MEDIUM, CLOSE)\n" +
		"  - Battle ends after 4 rounds (whoever holds objective wins)\n" +
		"  - No reinforcements or flow events\n" +
		"  - Recommended for: campaign marathons, multiple battles per session",
}


## ============================================================================
## BATTLE GENERATION
## ============================================================================

## Generate a no-minis battle setup. Returns empty if disabled.
static func generate_battle_setup(crew_size: int, enemy_count: int) -> Dictionary:
	if not _is_enabled():
		return {}

	var location_count := clampi(3 + ceili(crew_size / 3.0), 3, 5)
	var locations: Array[Dictionary] = []
	var available := LOCATION_TYPES.duplicate()

	# Always include at least 1 cover and 1 objective
	for loc in available:
		if loc.id == "light_cover":
			locations.append(loc.duplicate())
			break
	for loc in available:
		if loc.id == "objective":
			locations.append(loc.duplicate())
			break

	# Fill remaining randomly
	while locations.size() < location_count:
		var pick: Dictionary = available[randi() % available.size()]
		locations.append(pick.duplicate())

	return {
		"type": "no_minis",
		"locations": locations,
		"crew_size": crew_size,
		"enemy_count": enemy_count,
		"current_round": 0,
		"max_rounds": 6,
	}


## Generate setup instruction text.
static func generate_setup_text(battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var lines: Array[String] = [
		"[b]NO-MINIS COMBAT SETUP[/b]",
		"",
		"[b]Battlefield:[/b] %d abstract Locations" % battle.get("locations", []).size(),
		"",
	]

	var locs: Array = battle.get("locations", [])
	for i in locs.size():
		var loc: Dictionary = locs[i]
		lines.append("  Location %d: %s" % [i + 1, loc.get("instruction", "")])

	lines.append_array([
		"",
		"[b]Crew:[/b] %d figures. Deploy at FAR or MEDIUM locations." % battle.get("crew_size", 4),
		"[b]Enemies:[/b] %d figures. Deploy at FAR locations (opposite side)." % battle.get("enemy_count", 6),
		"",
		"[b]Initiative:[/b] Roll 1D6 + highest crew Savvy. On 4+: crew acts first.",
		"  (Note: Roll ONE DIE LESS than normal rules for initiative)",
		"",
		"[b]Each Activation:[/b] Choose 1 Initiative Action per figure:",
		"  Fire | Engage | Take Cover | Sprint | Search | First Aid",
		"",
		"[b]Enemy Turn:[/b] Roll D6 per enemy for behavior.",
		"",
		"[b]Movement:[/b] 1 Location per activation (Sprint = 2 Locations).",
		"[b]Cover:[/b] Light = -1 to hit. Heavy = -2 to hit.",
		"[b]Brawl:[/b] Same Location required. D6 + Combat Skill, highest wins.",
		"",
		"[b]Victory:[/b] Complete objective OR eliminate all enemies.",
		"[b]Max Rounds:[/b] %d (draw if neither side wins)." % battle.get("max_rounds", 6),
	])

	return "\n".join(lines)


## Generate round instruction text.
static func generate_round_text(round_num: int, _battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var lines: Array[String] = [
		"[b]NO-MINIS ROUND %d[/b]" % round_num,
		"",
		"[b]1. Initiative Phase:[/b]",
		"  Roll 1D6 + Savvy. 4+ = crew acts first.",
		"",
		"[b]2. Crew Activation:[/b]",
		"  Each crew member chooses 1 action: Fire / Engage / Take Cover / Sprint / Search / First Aid",
		"",
		"[b]3. Enemy Phase:[/b]",
		"  Roll D6 per enemy:",
		"  1-2: Advance + Fire | 3-4: Hold + Fire (+1 aim) | 5: Advance + Engage | 6: Special",
		"",
		"[b]4. Resolve:[/b]",
		"  Remove casualties. Check morale (3+ crew down = test). Update positions.",
		"",
	]

	if round_num > 1:
		lines.append("[b]Optional: Battle Flow Event[/b] - Roll D6 for round event.")
		lines.append("")

	return "\n".join(lines)


## Roll a battle flow event.
static func roll_battle_flow_event() -> Dictionary:
	if not _is_enabled():
		return {}
	var roll := randi_range(1, 6)
	for event in BATTLE_FLOW_EVENTS:
		if event.roll == roll:
			return event
	return BATTLE_FLOW_EVENTS[0]


## Roll enemy action for one enemy figure.
static func roll_enemy_action() -> Dictionary:
	var roll := randi_range(1, 6)
	for action in ENEMY_ACTION_TABLE:
		if action.roll == roll:
			return action
	return ENEMY_ACTION_TABLE[0]


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
