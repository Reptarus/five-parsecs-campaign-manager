class_name CheatSheetSections
extends RefCounted
## Battle Cheat Sheet — the Compendium sections, RENDERED FROM THE DATA FILES.
##
## WHY THIS FILE EXISTS. `CheatSheetPanel` built every DLC section from a
## hand-written string literal, and four of them printed rules that are in
## NEITHER rulebook. Diffed against the PDFs on Sep 3 2026:
##
##   Casualty tables   printed a D6 "1 Instantly Killed / 2 Dead / 3 Permanent
##                     Injury / 4 Serious Wound / 5 Minor Wound / 6 Lucky
##                     Escape" table and a 2D6 "Lost Limb / Head Trauma / Nerve
##                     Damage..." injury table, both invented, both cited to
##                     pages ("p.86", "p.87") that hold neither. The real
##                     pp.99-100 tables are three D6 tables with regular/boss
##                     COLUMNS, and p.102 is a D100.
##   Salvage           printed a "1-3 units = 2 cr | 4-6 = 5 cr" conversion
##                     scale that does not exist — p.147's Scrapper is three
##                     Loot rolls at 1D6 units each — and shipped a literal
##                     `pass` line in the middle of the player-facing text.
##   Street fights     printed "1-2 Civilian / 3-4 Armed thug / 5 Target / 6
##                     Trap" at 4"; p.125 is "1 Nothing / 2 Possible enemy / 3-5
##                     Enemy / 6 Ambush" at 4+Savvy inches.
##   Stealth           printed "+D6 reinforcements Round 2"; p.122 is 2D6 every
##                     round, one basic enemy per 6 rolled.
##
## A dead rule does nothing. A FABRICATED rule misinforms play — and this panel
## is the surface a player consults mid-battle, so it is the worst place in the
## app to be wrong. The fix is structural rather than textual: every section now
## renders from the same JSON the MECHANIC reads, so the two cannot drift again.
##
## Each builder returns BBCode, or "" when its data is missing (the panel then
## omits the section rather than printing an empty box).

const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const StealthRef = preload("res://src/data/compendium_stealth_missions.gd")
const StreetFightRef = preload("res://src/data/compendium_street_fights.gd")
const SalvageRef = preload("res://src/data/compendium_salvage_jobs.gd")
const NoMinisRef = preload("res://src/data/compendium_no_minis.gd")
const GridMovementRef = preload("res://src/data/compendium_grid_movement.gd")
const MissionsExpandedRef = preload("res://src/data/compendium_missions_expanded.gd")
const ProblemSolvingRef = preload("res://src/core/battle/ProblemSolvingTests.gd")

## Core Rules Appendix VIII, pp.172-173.
const NEUTRAL_CHARACTERS_PATH := "res://data/RulesReference/NeutralCharacters.json"

const COLOR_HEAD := "#4FC3F7"
const COLOR_WARN := "#D97706"
const COLOR_BAD := "#DC2626"
const COLOR_MUTED := UIColors.HEX_TEXT_SECONDARY


## ============================================================================
## SHARED HELPERS
## ============================================================================

static func _head(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]\n" % [COLOR_HEAD, text]


static func _span(entry: Dictionary) -> String:
	## "3-5" or "6" from a roll_min/roll_max row. int() because JSON numerics
	## arrive as float.
	var lo: int = int(entry.get("roll_min", 0))
	var hi: int = int(entry.get("roll_max", lo))
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


## Render a list of {roll_min, roll_max, instruction} rows as a table.
static func _roll_rows(rows: Array, strip_prefix: String = "") -> String:
	var out := ""
	for entry in rows:
		if not (entry is Dictionary):
			continue
		var text: String = str(entry.get("instruction", entry.get("effect", "")))
		if strip_prefix != "" and text.begins_with(strip_prefix):
			text = text.substr(strip_prefix.length()).strip_edges()
		out += "  [b]%s[/b]  %s\n" % [_span(entry), text]
	return out


## ============================================================================
## CASUALTIES & INJURIES (Compendium pp.99-102)
## ============================================================================

static func casualty_tables() -> String:
	var tables: Dictionary = CompendiumTogglesRef.CASUALTY_TABLES
	if tables.is_empty():
		return ""
	var out := "[b]Casualty Tables (Compendium pp.99-100) — roll D6:[/b]\n"
	out += "[color=%s]Regular = crew and normal enemies (specialists included).\n" % COLOR_MUTED
	out += "Boss = your captain, enemy leaders and unique personalities.[/color]\n"
	for key in ["humanoid", "cybernetic", "beast"]:
		var table: Variant = tables.get(key, {})
		if not (table is Dictionary):
			continue
		var entries: Array = (table as Dictionary).get("entries", [])
		if entries.is_empty():
			continue
		out += "\n%s" % _head(str((table as Dictionary).get("name", key)))
		out += "[color=%s]  REG   BOSS  OUTCOME[/color]\n" % COLOR_MUTED
		for entry in entries:
			if not (entry is Dictionary):
				continue
			out += "  %-5s %-5s %s\n" % [
				_column_span(entry, "regular"), _column_span(entry, "boss"),
				str(entry.get("outcome", ""))]
	# p.99, verbatim, and the reason the tables are not simply "roll once".
	out += ("\n[color=%s]Multiple hits: make all Toughness rolls first, then roll"
		+ " once per hit that beat Toughness. ONLY the single highest result is"
		+ " applied.[/color]\n") % COLOR_WARN
	out += ("[color=%s]Bleeding / Damaged / Wounded end with the battle and have"
		+ " no long-term effects (p.100).[/color]\n") % COLOR_MUTED
	out += ("[color=%s]A figure removed WITHOUT a Toughness roll does not use"
		+ " these tables at all (p.99).[/color]") % COLOR_MUTED
	return out


static func _column_span(entry: Dictionary, column: String) -> String:
	var span: Variant = entry.get(column, [])
	if not (span is Array) or (span as Array).size() != 2:
		return "-"
	var lo: int = int((span as Array)[0])
	var hi: int = int((span as Array)[1])
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


static func detailed_injuries() -> String:
	var rows: Array = CompendiumTogglesRef.DETAILED_INJURY_TABLE
	if rows.is_empty():
		return ""
	var out := ("[b]Detailed Post-Battle Injuries (Compendium p.102) —"
		+ " roll D100:[/b]\n")
	out += ("[color=%s]Used IN PLACE of the Core Rules p.122 table. Bots and"
		+ " Soulless stay on the Bot Injury table (p.101).[/color]\n") % COLOR_MUTED
	for entry in rows:
		if not (entry is Dictionary):
			continue
		var sick: String = str(entry.get("sick_bay_roll", ""))
		if sick.is_empty():
			var turns: int = int(entry.get("sick_bay", 0))
			sick = "NA" if turns < 0 else str(turns)
		out += "  [b]%s[/b]  %s [color=%s](Sick Bay %s)[/color]\n" % [
			_span(entry), str(entry.get("name", "")), COLOR_MUTED, sick]
	out += ("\n[color=%s]Injured arm / leg / torso last until 3 Credits of"
		+ " medical treatment. A Lingering injury is rolled 1D6 before every"
		+ " mission: 1 cannot fight, 6 fully recovered.[/color]") % COLOR_WARN
	return out


## ============================================================================
## STEALTH MISSIONS (Compendium pp.117-122)
## ============================================================================

static func stealth_missions() -> String:
	var out := ""
	var round_rules: String = StealthRef.STEALTH_ROUND_RULES
	if round_rules != "":
		out += round_rules.strip_edges() + "\n\n"
	var detection: String = StealthRef.DETECTION_RULES
	if detection != "":
		out += detection.strip_edges() + "\n\n"
	var tools: Array = StealthRef.STEALTH_TOOLS
	if not tools.is_empty():
		out += _head("Tools (each needs the crew member to stay still)")
		for tool in tools:
			if tool is Dictionary:
				out += "  %s\n" % str(tool.get("instruction", ""))
		out += "\n"
	var alarm: String = StealthRef.ALARM_RULES
	if alarm != "":
		out += "[color=%s]%s[/color]" % [COLOR_BAD, alarm.strip_edges()]
	return out.strip_edges()


## ============================================================================
## STREET FIGHTS (Compendium pp.123-136)
## ============================================================================

static func street_fights() -> String:
	var out := ""
	var setup: String = StreetFightRef.TABLE_SETUP_RULES
	if setup != "":
		out += setup.strip_edges() + "\n\n"
	var actions: Array = StreetFightRef.SUSPECT_ACTIONS
	if not actions.is_empty():
		out += _head("Suspect marker acts (D6, Enemy Phase)")
		out += _roll_rows(actions, "SUSPECT:")
		out += "\n"
	var ident: Array = StreetFightRef.SUSPECT_IDENTIFICATION
	if not ident.is_empty():
		out += _head("Identified within 4+Savvy inches (D6)")
		out += _roll_rows(ident, "SUSPECT REVEAL:")
		out += "\n"
	var evasion: String = StreetFightRef.EVASION_RULES
	if evasion != "":
		out += evasion.strip_edges() + "\n\n"
	var law: String = StreetFightRef.LAW_RULES
	if law != "":
		out += "[color=%s]%s[/color]\n\n" % [COLOR_WARN, law.strip_edges()]
	var end_game: String = StreetFightRef.END_GAME_RULES
	if end_game != "":
		out += end_game.strip_edges()
	return out.strip_edges()


## ============================================================================
## SALVAGE JOBS (Compendium pp.137-147)
## ============================================================================

static func salvage_jobs() -> String:
	var out := ""
	var tension: String = SalvageRef.TENSION_RULES
	if tension != "":
		out += tension.strip_edges() + "\n\n"
	var contacts: Array = SalvageRef.CONTACT_RESULTS
	if not contacts.is_empty():
		out += _head("Contact marker resolves (D6)")
		out += _roll_rows(contacts, "CONTACT:")
		out += "\n"
	var value: String = SalvageRef.SALVAGE_VALUE_RULES
	if value != "":
		out += value.strip_edges() + "\n\n"
	# p.147, verbatim — and the ONLY three things Salvage may pay for.
	out += ("[color=%s]1 Salvage unit = 1 Credit ONLY for ship repairs, ship"
		+ " modules and bot upgrades. Credits cannot be converted back to"
		+ " Salvage. The Scrapper may be visited once per campaign turn."
		+ "[/color]\n") % COLOR_WARN
	out += ("[color=%s]There are no Invasion checks after a Salvage battle."
		+ "[/color]") % COLOR_MUTED
	return out.strip_edges()


## ============================================================================
## NO-MINIS COMBAT (Compendium pp.66-73)
## ============================================================================

static func no_minis_combat() -> String:
	var out := ""
	var instruction: String = NoMinisRef.FIREFIGHT_INSTRUCTION
	if instruction != "":
		out += instruction.strip_edges() + "\n\n"
	var actions: Array = NoMinisRef.INITIATIVE_ACTIONS
	if not actions.is_empty():
		out += _head("Initiative actions (one per figure)")
		for action in actions:
			if action is Dictionary:
				out += "  [b]%s[/b] — %s\n" % [
					str(action.get("name", "")),
					str(action.get("description", action.get("instruction", "")))]
		out += "\n"
	var morale: String = NoMinisRef.MORALE_RULES
	if morale != "":
		out += morale.strip_edges() + "\n\n"
	var incompatible: Array = NoMinisRef.INCOMPATIBLE_FLAGS
	if not incompatible.is_empty():
		var names: Array = []
		for flag in incompatible:
			names.append(str(flag).capitalize())
		out += "[color=%s]Not compatible with: %s[/color]" % [
			COLOR_WARN, ", ".join(PackedStringArray(names))]
	return out.strip_edges()


## ============================================================================
## DIFFICULTY TOGGLES (Compendium pp.32-34)
## ============================================================================

static func difficulty_toggles() -> String:
	var toggles: Array = CompendiumTogglesRef.DIFFICULTY_TOGGLES
	if toggles.is_empty():
		return ""
	# The literal this replaces listed EIGHT of the twelve options and dropped
	# Better Leadership's second bullet entirely, so a player reading it could
	# not know which switches they had turned on.
	var out := "[b]Difficulty Toggles (Compendium pp.32-34):[/b]\n"
	var by_category: Dictionary = {}
	for toggle in toggles:
		if not (toggle is Dictionary):
			continue
		var cat: String = str(toggle.get("category", "other"))
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(toggle)
	for cat in by_category:
		out += "\n[color=%s]%s[/color]\n" % [
			COLOR_HEAD, str(cat).replace("_", " ").capitalize()]
		for toggle in by_category[cat]:
			var active: bool = CompendiumTogglesRef.is_toggle_active(
				str(toggle.get("id", "")))
			var mark: String = "[color=%s]ON[/color]" % "#10B981" if active \
				else "[color=%s]off[/color]" % COLOR_MUTED
			out += "  %s %s\n" % [mark, str(toggle.get("name", ""))]
			out += "     [color=%s]%s[/color]\n" % [
				COLOR_MUTED, str(toggle.get("description", ""))]
	return out.strip_edges()


## ============================================================================
## AI VARIATIONS (Compendium pp.42-43)
## ============================================================================

static func ai_variations() -> String:
	## Only meaningful while the option is ON — the CORE AI is diceless
	## (Core Rules p.42), and printing dice tables to a player without the DLC is
	## the defect this whole sweep exists to stop.
	if not CompendiumTogglesRef.ai_variations_enabled():
		return ""
	var rules: Dictionary = CompendiumTogglesRef.AI_VARIATION_RULES
	var out := "[b]AI Variations (Compendium pp.42-43):[/b]\n"
	var intro: String = str(rules.get("intro", ""))
	if intro != "":
		out += "[color=%s]%s[/color]\n" % [COLOR_MUTED, intro]
	for step in rules.get("how_to_use", []):
		out += "  - %s\n" % str(step)
	var unchanged: String = str(rules.get("unchanged_types", ""))
	if unchanged != "":
		out += "\n[color=%s]%s[/color]\n" % [COLOR_WARN, unchanged]
	for key in ["aggressive", "cautious", "tactical", "defensive"]:
		var variation: Dictionary = CompendiumTogglesRef.ai_variation_for(key)
		if variation.is_empty():
			continue
		out += "\n%s" % _head(key.capitalize())
		out += "  [color=%s]Base: %s[/color]\n" % [
			COLOR_MUTED, str(variation.get("base_condition", ""))]
		for entry in variation.get("actions", []):
			if entry is Dictionary:
				out += "  [b]%d[/b]  %s\n" % [
					int(entry.get("roll", 0)), str(entry.get("action", ""))]
	return out.strip_edges()


## ============================================================================
## GRID-BASED MOVEMENT (Compendium pp.90-93)
## ============================================================================

static func grid_movement() -> String:
	## Already data-backed since Aug 6 2026, when the same fabrication class was
	## found here ("1 square = 2 inches", a range-to-squares table, "enter
	## occupied square = automatic Brawl" — none of it in the book).
	return GridMovementRef.get_reference_text()


## ============================================================================
## CORE RULES APPENDICES — no DLC gate, these are in the base book
## ============================================================================
##
## All three had ZERO code presence before Sep 3 2026: not dead implementations,
## absent ones. They are reference material for a tabletop companion, so the
## delivery IS the text.

## Appendix II, p.147. Note what it does NOT say: there is no inch-to-square
## CONVERSION. One space is one inch of movement, full stop — the fabricated
## "1 square = 2 inches" that CheatSheetPanel used to print for the COMPENDIUM
## grid chapter was inventing a rule this appendix already answers differently.
static func playing_on_a_grid() -> String:
	return """[b]Playing on a Grid (Core Rules Appendix II, p.147)[/b]
For gridded maps, floor plans and battle mats. You may also ignore
the grid entirely and measure normally — the tiles are then just
terrain, and no adjustment is needed.

[b]Placing miniatures[/b]
Each space holds only one figure. You may move THROUGH spaces with
friendly figures, but cannot END with two figures in one space.
(A slight change from the standard rules, which do not allow figures
to overlap or move through each other at all.)

[b]Moving and measuring[/b]
Moving one space uses [color=#4FC3F7]1\" of movement[/color], so a figure with Speed 5\"
moves 5 spaces. Orthogonal and diagonal moves count the same: each
is 1\". Figures can move diagonally BETWEEN two spaces occupied by
terrain. All measurements count the shortest possible route, up to
and including the target space."""


static func problem_solving() -> String:
	return ProblemSolvingRef.get_reference_text()


## Appendix VIII, pp.172-173, rendered from the data file so the profiles and
## the reference cannot drift.
static func neutral_characters() -> String:
	var f := FileAccess.open(NEUTRAL_CHARACTERS_PATH, FileAccess.READ)
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return ""
	var data: Dictionary = (parsed as Dictionary).get("NeutralCharacters", {})
	var profiles: Array = data.get("profiles", [])
	if profiles.is_empty():
		return ""

	var out := "[b]Neutral Characters (Core Rules Appendix VIII, pp.172-173)[/b]\n"
	out += "[color=%s]%s[/color]\n\n" % [COLOR_MUTED, str(data.get("text", ""))]
	out += "[color=%s]  REA SPD  CS TGH SAV[/color]\n" % COLOR_MUTED
	for profile in profiles:
		if not (profile is Dictionary):
			continue
		out += "[b]%s[/b]\n" % str(profile.get("name", ""))
		out += "  %3d %2d\" %+3d %3d %+3d\n" % [
			int(profile.get("reactions", 0)), int(profile.get("speed", 0)),
			int(profile.get("combat_skill", 0)), int(profile.get("toughness", 0)),
			int(profile.get("savvy", 0))]
		out += "  [color=%s]%s[/color]\n" % [
			COLOR_MUTED, str(profile.get("weapon", ""))]
		var savvy_note: String = str(profile.get("savvy_note", ""))
		if savvy_note != "":
			out += "  [color=%s]%s[/color]\n" % [COLOR_WARN, savvy_note]
	out += "\n[color=%s]%s[/color]\n" % [COLOR_HEAD, str(data.get("request_help", ""))]
	out += "[color=%s]%s[/color]" % [COLOR_MUTED, str(data.get("phase_rule", ""))]
	return out


## ============================================================================
## MULTIPLAYER — reference text only (user decision, Sep 3 2026)
## ============================================================================
##
## PvP (Compendium pp.35-38) and Expanded Co-op (pp.39-41) are the two chapters
## docs/COMPENDIUM_CHAPTER_TRACE_2026-08.md still lists as DEAD, and the reason
## is not a wiring gap: both need a second player this app has no surface for.
## The rules text has been complete in compendium_missions_expanded since it was
## written and had zero callers, so a player who bought the Freelancer\'s
## Handbook could not read the chapters they paid for. These are those first
## callers. Both builders gate themselves, so an unowned pack renders nothing.

static func pvp_battles() -> String:
	var setup: String = MissionsExpandedRef.get_pvp_setup()
	if setup.strip_edges().is_empty():
		return ""
	var out := "[b]Player vs Player (Compendium pp.35-38)[/b]\n"
	out += "[color=%s]Two crews, one table. The app does not run the second\n" % COLOR_MUTED
	out += "crew — this is the procedure to run it yourself.[/color]\n\n"
	out += setup.strip_edges() + "\n"
	for aspect in ["initiative", "power_rating", "fight", "ending", "aftermath",
			"three_way", "instruction"]:
		var text: String = MissionsExpandedRef.get_pvp_rules(aspect)
		if text.strip_edges().is_empty():
			continue
		if out.contains(text.strip_edges()):
			continue
		out += "\n" + text.strip_edges() + "\n"
	return out.strip_edges()


static func coop_battles() -> String:
	var setup: String = MissionsExpandedRef.get_coop_setup()
	var out := ""
	if not setup.strip_edges().is_empty():
		out += setup.strip_edges() + "\n"
	for aspect in ["the_job", "location", "rivals", "objectives",
			"enemy_generation", "deployment", "fighting", "tough_fight",
			"aftermath", "notes", "instruction"]:
		var text: String = MissionsExpandedRef.get_coop_rules(aspect)
		if text.strip_edges().is_empty():
			continue
		if out.contains(text.strip_edges()):
			continue
		out += "\n" + text.strip_edges() + "\n"
	if out.strip_edges().is_empty():
		return ""
	return ("[b]Expanded Co-op Battles (Compendium pp.39-41)[/b]\n"
		+ out.strip_edges())


## Core Rules Appendix VI, p.161. In the BASE book, so no gate.
static func cooperative_play() -> String:
	return """[b]Cooperative Play (Core Rules Appendix VI, p.161)[/b]
Two or more players on the same team. Divide the crew figures
between them — in a starting campaign each player takes three.
Nothing prevents trading crew later.

  - Campaign decisions (travel, purchases) are decided mutually.
    If you cannot agree, roll 1D6: [color=#4FC3F7]1-3[/color] Player A decides,
    [color=#4FC3F7]4-6[/color] Player B decides.
  - Each player decides their own figures\' campaign actions.
    Alternate declaring and resolving.
  - A new recruit goes to whoever controls the FEWEST crew. On a
    tie, to whoever has the most crew in Sick Bay. Still tied:
    agree, or assign at random.
  - In battle each player makes their OWN Reaction Roll and can
    only assign dice to their own crew.
  - Loot rolls alternate, first one assigned at random. A player
    may forego an item or give it to the Stash, where it becomes
    commonly available.

[color=#9ca3af]These are suggestions. If the players are in tune with each other,
omit anything that gets in the way — though each player should stay
responsible for their own crew figures.[/color]"""


## Core Rules Appendix VII, pp.162-171. The GM toolkit, which the book itself
## says a solo player can use ("Solo players can still take advantage of this
## chapter by essentially GM\'ing themselves", p.162).
##
## REFERENCE ONLY, and deliberately so. Plot Points, Mass Battle and War
## Exhaustion are campaign subsystems in their own right — building them is
## net-new scope, not a gap-close — while Booby Traps, Intrusion, Searching and
## Turrets are scenario tools the player applies at the table with the Problem
## Solving tests above. What was missing was the TEXT: the appendix had no code
## presence at all, so none of it reached the player.
static func game_mastering_tools() -> String:
	return """[b]Game Mastering Tools (Core Rules Appendix VII, pp.162-171)[/b]
Solo players can use this chapter by GM\'ing themselves.

[b]Advancing Plot Points (p.163)[/b]
Write each plot down and put a [color=#4FC3F7]2[/color] next to it.
  - Each campaign turn, roll [color=#4FC3F7]4D6[/color]; advance the plot one
    point for every [color=#4FC3F7]6[/color] rolled.
  - Actions that would benefit a plot advance it one more.
  - Actions that would hinder it reduce it by 1, and no roll is made.
  - Below 0 the plot is [color=#DC2626]Foiled[/color] and cannot be completed.
  - At [color=#10B981]6[/color] it comes to fruition and takes effect.

[b]Booby Traps (p.164)[/b]
Searching for a suspected trap is a Wits roll (D6+Savvy, [color=#10B981]5+[/color]),
made secretly. A discovered trap is always disarmed automatically.
If one is set off, roll D6: on a [color=#4FC3F7]1[/color] it fails to trigger;
otherwise a Damage [color=#DC2626]+1[/color] Hit ignoring Armor Saving Throws.
Area traps strike every figure within 2\", both sides.

[b]Bystanders (p.164)[/b]
They act at the end of each round, moving 3\" ahead if no fight has
broken out. Within 6\" of a Brawl, or of a shooter, target or 2\" of
the line of fire, they move [color=#4FC3F7]1D6\"[/color] directly away. Once shots
are fired all bystanders Bail toward the nearest edge.
[color=#DC2626]Deliberately firing on bystanders earns an Enforcer Rival.[/color]

[b]Connections (p.164)[/b]
On an Opportunity mission you may roll [color=#4FC3F7]1D6[/color]: on a 5-6 the
mission links back to a prior event. If in doubt, roll 1D6 for what:
  [b]1-2[/b] a person you have met   [b]3[/b] a place you have been
  [b]4[/b] a job you have done      [b]5[/b] a faction or group
  [b]6[/b] a personal Connection for a random crew member
Playing solo, a battle with a Connection always has a Notable Sight
AND a Deployment Condition.

[b]Intrusion (p.166)[/b]
A non-Combat Action and a 1D6+Savvy test against a security rating
of [color=#4FC3F7]2-7[/color] (roll 1D6+1 if in doubt). Low-security systems may be
retried unless a natural [color=#DC2626]1[/color] jams them; high-security twice only.

[b]Searching (p.167)[/b]
A non-Combat Action and an Easy Task roll ([color=#10B981]3+[/color]), rolled
concealed. On a natural [color=#4FC3F7]6[/color] the searcher knows the feature
was searched thoroughly.

[b]Revelations (p.167)[/b]
After a battle you Held the Field, roll [color=#4FC3F7]D6[/color] ONCE: a 6 means a
Revelation. Solo players may take [color=#10B981]+1 story point[/color] and then
acquire a new [color=#DC2626]Rival[/color], with a D10 for what was revealed.

[b]Time Limits (p.168)[/b]
Set a number of rounds, or a Count (10/20/30/40) reduced [color=#4FC3F7]1D6[/color]
per round, [color=#10B981]+1[/color] on rounds where no fighting happened.

[b]Turrets (p.168)[/b]
Act at the end of each round. Toughness 4, [color=#10B981]6+[/color] Armor Saving
Throw, immune to Morale. Linked weapons count as one with +1 Shot.
  Defensive Fire: nearest target within 12\", +1 Shot
  Point Fire: nearest target in sight
  Priority Fire: a specific target type, +1 to Hit

[color=#9ca3af]Rewards guidance (pp.170-171): up to 3 extra credits without
worrying, no more than 1 bonus XP for surviving, and 1-3 Quest
Rumors is fine. These are the book\'s own ceilings.[/color]"""
