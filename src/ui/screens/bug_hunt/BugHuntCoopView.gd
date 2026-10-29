extends RefCounted

## Bug Hunt Co-op campaign (Compendium pp.209-211): what the screens SHOW of it.
##
## Presentation only. Every rule is BugHuntCoopCampaign's (pure, static) and every write
## goes through BugHuntCampaignCore's co-op wrappers, so nothing here decides what a rule
## decides -- it asks. Five places show the campaign (the creation wizard, the mission
## panel, the post-battle panel, the map panel and the battle card), and they all read
## these helpers, so a sector cannot read one way on the map and another on the mission.
##
## Every number a player reads comes from the data or from the campaign: a Factor's text
## is its row's `effect`, a threshold is bug_hunt_missions.json's, a Priority is the
## sector's. The two p.209 quotes below are the only book text held here, and they are
## quotations of prose, not mechanics.
##
## No class_name: preload it by path (docs/sop/component-patterns.md).

const CoopRef := preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"

const CITE_PREP := "Compendium p.209"
const CO_OP_PREFIX := "Bug Hunt Co-op "

## Compendium p.209, Preparatory Steps, "Enemies" -- VERBATIM (PyPDF2 pages[210]).
## The app has no Bug Hunt enemy-type setting to pick from: the Enemy table (pp.194-5) is
## rolled at the physical table for every mission, which IS the book's default ("roll
## each time as you normally would"). The quote is shown so the players make the choice
## the book asks them to make, rather than the app silently making it for them.
const PREP_ENEMIES := ("You will need to decide if you want to play against a single "
	+ "enemy type, or if you want to roll each time as you normally would. If you want a "
	+ "theme to the campaign, you might opt to pick 2-3 enemies from the Enemy table (see "
	+ "pp.194-5) and randomize between them each time.")

## Compendium p.209, Preparatory Steps, "Difficulty setting" -- VERBATIM. The campaign
## carries ONE difficulty (the wizard's Mission Difficulty), so on this device every
## player's mission is already at the same setting; players on other devices match it.
const PREP_DIFFICULTY := "All players should be using the same difficulty setting."

static var _missions_cache: Dictionary = {}


# ──────────────────────────────────────────────────────────────────────────────
# Reading the campaign
# ──────────────────────────────────────────────────────────────────────────────

## The campaign's co-op Dictionary, or {} for a campaign that is not co-op (or is not a
## Bug Hunt campaign at all -- the 5PFH core has no `coop` field).
static func coop_of(campaign: Variant) -> Dictionary:
	if not (campaign is Object) or not ("coop" in campaign):
		return {}
	var c: Variant = campaign.coop
	return c if CoopRef.is_enabled(c) else {}


static func sectors(coop: Dictionary) -> Array:
	var out: Array = []
	for s in coop.get("sectors", []):
		if s is Dictionary:
			out.append(s)
	return out


static func sector(coop: Dictionary, sector_id: String) -> Dictionary:
	for s in sectors(coop):
		if str(s.get("id", "")) == sector_id:
			return s
	return {}


static func sector_name(coop: Dictionary, sector_id: String) -> String:
	var s: Dictionary = sector(coop, sector_id)
	return str(s.get("name", sector_id)) if not s.is_empty() else sector_id


static func cleared_count(coop: Dictionary) -> int:
	var n := 0
	for s in sectors(coop):
		if bool(s.get("cleared", false)):
			n += 1
	return n


## p.211: "Each player may attack one sector of their choice." The players who have not
## yet attacked this operational turn, in the order the campaign lists them.
static func players_to_fight(coop: Dictionary) -> Array:
	var attacked: Array = coop.get("attacked_this_turn", []) \
		if coop.get("attacked_this_turn", []) is Array else []
	var out: Array = []
	for p in coop.get("players", []):
		if not attacked.has(str(p)):
			out.append(str(p))
	return out


## The sectors `player` may attack, by the rules module's own test.
static func attackable_sector_ids(coop: Dictionary, player: String) -> Array:
	var out: Array = []
	for s in sectors(coop):
		var sid: String = str(s.get("id", ""))
		if bool(CoopRef.can_attack(coop, sid, player).get("ok", false)):
			out.append(sid)
	return out


## The player whose mission was launched on this device and has not yet been recorded on
## the map: the stamp carries `coop` from launch, and `coop_receipt` from the moment the
## post-battle panel recorded it. "" when nothing is in flight.
static func in_flight_player(campaign: Variant) -> String:
	if not (campaign is Object) or not ("current_mission" in campaign):
		return ""
	var stamp: Variant = campaign.current_mission
	if not (stamp is Dictionary):
		return ""
	var info: Variant = (stamp as Dictionary).get("coop", {})
	if not (info is Dictionary) or (info as Dictionary).is_empty():
		return ""
	if (stamp as Dictionary).has("coop_receipt"):
		return ""
	var coop: Dictionary = coop_of(campaign)
	# A stamp from an earlier operational turn cannot be in flight in this one.
	if int((info as Dictionary).get("op_turn", 0)) != int(coop.get("op_turn", 0)):
		return ""
	return str((info as Dictionary).get("player", ""))


## p.210: "During an operational turn, each player will carry out a mission, followed by
## a roll for Enemy Moves." The end phase is offered once every player has fought -- or
## has no sector left that the rules let them attack, which would otherwise leave a
## Sheltered-only map unable to move on. {ok, reason}.
static func can_end_turn(coop: Dictionary) -> Dictionary:
	if not CoopRef.is_enabled(coop):
		return {"ok": false, "reason": "This is not a co-op campaign."}
	if CoopRef.is_campaign_won(coop):
		return {"ok": false, "reason": "Every sector is cleared -- the co-op campaign is won (%s)."
			% CoopRef.CITE_MAP}
	var waiting: Array = []
	for p in players_to_fight(coop):
		if not attackable_sector_ids(coop, str(p)).is_empty():
			waiting.append(str(p))
	if not waiting.is_empty():
		return {"ok": false, "reason": ("Still to fight this operational turn: %s. Each player "
			+ "carries out a mission before the Enemy Moves roll (%s).") % [
				", ".join(waiting), CoopRef.CITE_MAP]}
	return {"ok": true, "reason": ""}


## End the operational turn through the core's ONE writer, then save. Refuses (and writes
## nothing) unless can_end_turn() allows it, so no screen can roll Enemy Moves early.
static func end_turn(campaign: Variant) -> Dictionary:
	var coop: Dictionary = coop_of(campaign)
	var check: Dictionary = can_end_turn(coop)
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": str(check.get("reason", "")), "lines": [], "rolls": []}
	if not campaign.has_method("end_coop_operational_turn"):
		return {"ok": false, "error": "This campaign cannot end a co-op turn.", "lines": [],
			"rolls": []}
	var receipt: Dictionary = campaign.end_coop_operational_turn()
	if bool(receipt.get("ok", false)) and campaign.has_method("persist"):
		campaign.persist()
	return receipt


# ──────────────────────────────────────────────────────────────────────────────
# Text
# ──────────────────────────────────────────────────────────────────────────────

## One sector, as every screen describes it. Factor and condition text is the data's own
## `effect`, read through battle_modifiers(), never restated here.
static func sector_lines(coop: Dictionary, sector_id: String) -> Array:
	var s: Dictionary = sector(coop, sector_id)
	if s.is_empty():
		return []
	var lines: Array = []
	var cleared: bool = bool(s.get("cleared", false))
	lines.append("Cleared" if cleared else "Enemy-held, Priority %d" % int(s.get("priority", 0)))
	var mods: Dictionary = CoopRef.battle_modifiers(coop, sector_id)
	for f in mods.get("factors", []):
		if f is Dictionary:
			lines.append("%s: %s" % [str(f.get("name", "")), str(f.get("effect", ""))])
	for c in mods.get("conditions", []):
		if c is Dictionary:
			lines.append("%s: %s" % [str(c.get("name", "")), str(c.get("effect", ""))])
	var stash: int = int(s.get("stash", 0))
	if stash > 0:
		lines.append("Resource stash: %d Support point%s, claimed when the sector is cleared"
			% [stash, "" if stash == 1 else "s"])
	var adjacent: Array = []
	for aid in s.get("adjacent", []):
		adjacent.append(sector_name(coop, str(aid)))
	if not adjacent.is_empty():
		lines.append("Adjacent: %s" % ", ".join(adjacent))
	return lines


## Columns for a grid of sector cards: ONE in portrait (phone-first policy, the same
## ResponsiveManager answer every screen uses -- never the viewport rect, which under the
## square design base cannot tell portrait from landscape), otherwise no more than the
## map's own near-square layout and no more than three, so a card keeps room for its
## Factor text. Each card names its neighbours, so a narrower grid loses no adjacency.
static func card_columns(count: int) -> int:
	var loop := Engine.get_main_loop()
	var rm: Node = (loop as SceneTree).root.get_node_or_null("/root/ResponsiveManager") \
		if loop is SceneTree else null
	var cols: int = 1
	if rm != null and rm.has_method("get_effective_columns"):
		cols = int(rm.get_effective_columns())
	return clampi(mini(cols, CoopRef.grid_columns(count)), 1, 3)


## A one-line state of the whole map, for the dashboard card.
static func dashboard_summary(coop: Dictionary) -> String:
	if not CoopRef.is_enabled(coop):
		return ""
	var total: int = sectors(coop).size()
	if CoopRef.is_campaign_won(coop):
		return "All %d sectors cleared -- the campaign is won." % total
	var pool: int = int(coop.get("support_pool", 0))
	return "Operational turn %d · %d of %d sectors cleared · %d Support point%s in the common pool" % [
		int(coop.get("op_turn", 1)), cleared_count(coop), total, pool, "" if pool == 1 else "s"]


## The p.211 victory test in the words of the data that scores it: the weighted Objective
## count and the success threshold are bug_hunt_missions.json's.
static func objectives_rule_text() -> String:
	var scoring: Dictionary = _scoring()
	var weights: Dictionary = scoring.get("weights", {}) if scoring.get("weights", {}) is Dictionary else {}
	# No fallback numbers: a missing data row prints nothing rather than a guess.
	if success_threshold() <= 0 or not (weights.has("normal") and weights.has("vital")
			and weights.has("critical")):
		return ""
	return ("A victory is %d or more Objectives, counted the way the debrief counts them "
		+ "(normal %d, Vital %d, Critical %d) -- %s.") % [
		success_threshold(), int(weights["normal"]), int(weights["vital"]),
		int(weights["critical"]), CoopRef.CITE_BATTLES]


static func success_threshold() -> int:
	return int(_scoring().get("success_threshold", 0))


## The name of the Enemy Moves row that sets the next turn's Support penalty, read from
## the data so the battle card names the result the player rolled.
static func sabotage_name() -> String:
	var moves: Variant = CoopRef.rules().get("enemy_moves", {})
	var rows: Variant = (moves as Dictionary).get("entries", []) if moves is Dictionary else []
	for row in (rows if rows is Array else []):
		if row is Dictionary and row.has("next_turn_support_penalty"):
			return str(row.get("name", ""))
	return ""


# ──────────────────────────────────────────────────────────────────────────────
# Receipts
# ──────────────────────────────────────────────────────────────────────────────

## A rules receipt as a ReceiptCard step: the cite, every die with what it was for, and
## the result lines. A refused receipt shows its reason as its only line, so a refusal is
## never mistaken for a step that ran and said nothing.
static func receipt_step(receipt: Dictionary, title: String, cite: String) -> Dictionary:
	var rolls: Array = []
	for r in receipt.get("rolls", []):
		if r is Dictionary:
			var subject: String = str(r.get("context", ""))
			if subject.begins_with(CO_OP_PREFIX):
				subject = subject.substr(CO_OP_PREFIX.length())
			rolls.append({"die": str(r.get("die", "")), "value": int(r.get("value", 0)),
				"subject": subject})
	var lines: Array = []
	if bool(receipt.get("ok", false)):
		lines = (receipt.get("lines", []) as Array).duplicate() \
			if receipt.get("lines", []) is Array else []
	else:
		lines = [str(receipt.get("error", ""))]
	return {"title": title, "cite": cite, "rolls": rolls, "lines": lines,
		"skipped": lines.is_empty()}


# ──────────────────────────────────────────────────────────────────────────────
# The battle card (TacticalBattleUI's Bug Hunt branch)
# ──────────────────────────────────────────────────────────────────────────────

## Rows for the battle card, from the co-op block BugHuntMissionPanel stamps onto the
## mission before launch: which sector, the Factors and conditions in force (each in its
## data row's own words), this turn's Sabotage and the common-pool draw. [] for a mission
## that is not part of a co-op campaign.
static func battle_card_rows(coop_stamp: Variant) -> Array:
	if not (coop_stamp is Dictionary) or (coop_stamp as Dictionary).is_empty():
		return []
	var info: Dictionary = coop_stamp
	var mods: Dictionary = info.get("modifiers", {}) if info.get("modifiers", {}) is Dictionary else {}
	var rows: Array = []
	rows.append({"head": "Co-op: %s" % str(info.get("sector_name", info.get("sector_id", ""))),
		"detail": "%s's mission, operational turn %d. Sector Priority %d (%s)." % [
			str(info.get("player", "")), int(info.get("op_turn", 1)),
			int(info.get("priority", 0)), CoopRef.CITE_BATTLES]})
	for f in mods.get("factors", []):
		if f is Dictionary:
			rows.append({"head": str(f.get("name", "")),
				"detail": "%s (%s)" % [str(f.get("effect", "")), CoopRef.CITE_MAP]})
	for c in mods.get("conditions", []):
		if c is Dictionary:
			rows.append({"head": str(c.get("name", "")),
				"detail": "%s (%s)" % [str(c.get("effect", "")), CoopRef.CITE_BATTLES]})
	var penalty: int = int(info.get("support_penalty", 0))
	if penalty > 0:
		rows.append({"head": sabotage_name(),
			"detail": "-%d Support point for every battle this operational turn (%s)."
				% [penalty, CoopRef.CITE_BATTLES]})
	var drawn: int = int(info.get("pool_drawn", 0))
	if drawn > 0:
		rows.append({"head": "Common pool",
			"detail": "%d Support point%s drawn from the common pool (%s)." % [
				drawn, "" if drawn == 1 else "s", CoopRef.CITE_BATTLES]})
	return rows


# ──────────────────────────────────────────────────────────────────────────────
# Creation
# ──────────────────────────────────────────────────────────────────────────────

## p.210: "try 3 sectors per player for a shorter campaign, up to 5 for a longer
## campaign." The range as the data states it.
static func sectors_per_player_range() -> Vector2i:
	var per: Dictionary = CoopRef.rules().get("sectors_per_player", {}) \
		if CoopRef.rules().get("sectors_per_player", {}) is Dictionary else {}
	return Vector2i(int(per.get("shorter", 0)), int(per.get("longer", 0)))


## The player names as they will be stored: trimmed, blanks dropped.
static func clean_players(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for p in raw:
			var n: String = str(p).strip_edges()
			if not n.is_empty():
				out.append(n)
	return out


## What stops the wizard creating this co-op campaign, or "" when nothing does. The model
## would merge a duplicate name silently and drop a blank one; the wizard says so instead,
## so no player is lost from the map without being told.
static func coop_config_error(config: Dictionary) -> String:
	if not bool(config.get("coop_enabled", false)):
		return ""
	var raw: Array = config.get("coop_players", []) if config.get("coop_players", []) is Array else []
	var names: Array = clean_players(raw)
	if names.is_empty():
		return "Name at least one player to start a co-op campaign."
	if names.size() != raw.size():
		return "Every player row needs a name -- remove the blank one or fill it in."
	var seen: Dictionary = {}
	for n in names:
		var key: String = str(n).to_lower()
		if seen.has(key):
			return "Two players are both named \"%s\" -- each player needs a different name." % n
		seen[key] = true
	var span: Vector2i = sectors_per_player_range()
	var per: int = int(config.get("coop_sectors_per_player", 0))
	if span.x <= 0 or per < span.x or per > span.y:
		return "Pick %d-%d sectors per player (%s)." % [span.x, span.y, CoopRef.CITE_MAP]
	return ""


# ──────────────────────────────────────────────────────────────────────────────

static func _scoring() -> Dictionary:
	if _missions_cache.is_empty():
		var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_missions_cache = parsed
	var objectives: Variant = _missions_cache.get("objectives", {})
	if not (objectives is Dictionary):
		return {}
	var scoring: Variant = (objectives as Dictionary).get("scoring", {})
	return scoring if scoring is Dictionary else {}
