class_name CompendiumGridMovement
extends RefCounted
## Grid-Based Movement — Compendium pp.90-93 (Freelancer's Handbook).
##
## "Grid-based movement allows more freeform movement by dividing the battlefield
##  into several Grid spaces, simplifying movement and positioning in combat while
##  maintaining the normal movement system for close-quarters fighting."
##
## This chapter has NO tables, NO dice and NO campaign state — it is a procedure
## the player performs at the physical table. So the implementation for a
## companion app IS the instruction text, and there is deliberately no
## data/compendium/*.json for it: there is nothing tabular to store.
##
## WHY THIS FILE EXISTS. The chapter was not merely unwired — it was wired to
## FABRICATED rules. `CheatSheetPanel._grid_movement_text()` shipped a
## "1 square = 2 inches" conversion, a range-to-squares table, "1 square per
## activation (+1 if Speed > 4\")" and "enter occupied square = automatic Brawl".
## None of that is in the Compendium; a full-text search for a square/inch
## conversion returns nothing, and the book says the OPPOSITE for two of them:
## ranged combat and proximity are both resolved with the core rules, in inches.
## Only the Flanking paragraph was correct. A dead rule does nothing; a
## fabricated rule misinforms play, which is worse.
##
## Everything below is the book. The only derived numbers are square sizes,
## which are table width divided by the grid count — arithmetic on the book's own
## values, labelled as derived where shown to the player.

const FLAG := "GRID_BASED_MOVEMENT"

## p.90: "The play area is divided into a grid with 3 or 4 squares along each
## side (for a total of 9, 12 or 16 sectors depending on whether your grid is
## 3x3, 3x4, or 4x4)."
const GRIDS: Array = [
	{"id": "3x3", "cols": 3, "rows": 3, "sectors": 9},
	{"id": "3x4", "cols": 3, "rows": 4, "sectors": 12},
	{"id": "4x4", "cols": 4, "rows": 4, "sectors": 16},
]

## p.90: "Typically, you want the squares to be 8-9\" across."
const TARGET_SQUARE_MIN := 8.0
const TARGET_SQUARE_MAX := 9.0

## p.91 flanking applies to exactly these two p.45 deployment variables.
const FLANKING_DEPLOYMENTS: Array = ["half_flank", "bolstered_flank"]


## ============================================================================
## DLC GATING
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func is_enabled() -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)


## ============================================================================
## GRID GEOMETRY (derived: table width / grid count)
## ============================================================================

## Square size along one axis, in inches. Returns 0.0 when the table size is
## unknown, so callers can fall back to the un-numbered instructions rather than
## print a fabricated measurement.
static func square_size_inches(table_size_ft: float, count: int) -> float:
	if table_size_ft <= 0.0 or count <= 0:
		return 0.0
	return (table_size_ft * 12.0) / float(count)


## Every grid option with its computed square size for this table.
## `square` is true when both axes land within an inch of each other — the book
## asks for spaces that are "roughly square", which 3x4 is not on a square table.
static func grid_options(table_size_ft: float) -> Array:
	var out: Array = []
	for grid: Variant in GRIDS:
		var g: Dictionary = (grid as Dictionary).duplicate(true)
		var w: float = square_size_inches(table_size_ft, int(g.get("cols", 0)))
		var h: float = square_size_inches(table_size_ft, int(g.get("rows", 0)))
		g["width_in"] = w
		g["height_in"] = h
		g["square"] = (w > 0.0 and absf(w - h) < 1.0)
		g["in_target_band"] = (
			w >= TARGET_SQUARE_MIN and w <= TARGET_SQUARE_MAX
			and h >= TARGET_SQUARE_MIN and h <= TARGET_SQUARE_MAX)
		out.append(g)
	return out


## The grid whose spaces come closest to the book's 8-9" guidance while staying
## roughly square. Returns {} when the table size is unknown.
static func recommended_grid(table_size_ft: float) -> Dictionary:
	if table_size_ft <= 0.0:
		return {}
	var best: Dictionary = {}
	var best_miss: float = -1.0
	for opt: Variant in grid_options(table_size_ft):
		var o: Dictionary = opt as Dictionary
		if not bool(o.get("square", false)):
			continue
		var w: float = float(o.get("width_in", 0.0))
		var miss: float = 0.0
		if w < TARGET_SQUARE_MIN:
			miss = TARGET_SQUARE_MIN - w
		elif w > TARGET_SQUARE_MAX:
			miss = w - TARGET_SQUARE_MAX
		if best_miss < 0.0 or miss < best_miss:
			best_miss = miss
			best = o
	return best


static func _fmt(inches: float) -> String:
	if is_equal_approx(inches, roundf(inches)):
		return "%d\"" % int(roundf(inches))
	return "%.1f\"" % inches


static func _fmt_feet(feet: float) -> String:
	if is_equal_approx(feet, roundf(feet)):
		return "%dx%dft" % [int(roundf(feet)), int(roundf(feet))]
	return "%.1fx%.1fft" % [feet, feet]


## ============================================================================
## THE INSTRUCTIONS (battle setup panel)
## ============================================================================

## Book procedure for laying out and using the grid, as instruction lines.
## UNGATED — answers "what does the grid procedure say", not "is it in use". See
## the build_*/get_* note above build_checklist_step(): the DLC flag and the
## per-battle choice are two different questions, and p.90 makes the second one
## the player's to answer every battle.
static func build_setup_instructions(table_size_ft: float = 0.0) -> Array[String]:
	var out: Array[String] = []

	var rec: Dictionary = recommended_grid(table_size_ft)
	if rec.is_empty():
		out.append("THE BATTLE SPACE — divide the play area into a grid of 3 or 4 "
			+ "squares along each side (3x3, 3x4 or 4x4 = 9, 12 or 16 sectors). "
			+ "Aim for spaces roughly 8-9\" across (Compendium p.90).")
	else:
		out.append(("THE BATTLE SPACE — on your %s table, a %s grid gives %s squares "
			+ "(%d sectors), which the book asks to be roughly 8-9\" across "
			+ "(Compendium p.90). Mark them with beads, markers or scatter terrain, "
			+ "or just eyeball it.") % [
				_fmt_feet(table_size_ft),
				str(rec.get("id", "")),
				_fmt(float(rec.get("width_in", 0.0))),
				int(rec.get("sectors", 0)),
			])
	out.append("Terrain does NOT have to respect the grid — place it in any manner "
		+ "that looks natural, and let it cross boundaries freely (p.90).")

	# p.90 Initial Deployment
	var half_text: String = "halfway into your edge square"
	if not rec.is_empty():
		half_text = "%s of your table edge" % _fmt(float(rec.get("width_in", 0.0)) / 2.0)
	out.append("DEPLOYMENT — every figure sets up in a square touching its own table "
		+ "edge, and no more than halfway into that square (so within %s). " % half_text
		+ "Otherwise placement is free; figures need not share a square (p.90).")

	# p.91 Figure Status
	out.append("SQUARE STATUS — when a figure is selected to act, its square is OPEN "
		+ "(only one side's figures present) or CLOSE QUARTERS (any enemy figure in "
		+ "it, whatever the range). Neutral third parties do not affect this while "
		+ "neutral. Status is judged at the moment of activation and can change "
		+ "during the round (p.91).")

	# p.92 Open Movement + Deploying
	out.append("OPEN MOVEMENT — move to an adjacent square (or accessible sub-square): "
		+ "straight up/down/left/right counts as moving normally and the figure may "
		+ "still act; a DIAGONAL move counts as having Dashed. Or move anywhere "
		+ "within the current square, normally, and still act (p.92).")
	out.append("DEPLOYING — a figure entering another square by Open movement may be "
		+ "placed anywhere within its base move of the edge it came from (the corner "
		+ "for a diagonal, the entry point for a sub-square). A Speed 4\" figure "
		+ "deploys within 4\". Figures may Deploy directly into a Brawl (p.92).")

	# p.92 Close Quarters
	out.append("CLOSE QUARTERS — movement uses the core rules in full, whether or not "
		+ "a border is crossed. A figure moving from a Close Quarters square to an "
		+ "Open one runs its ENTIRE activation on Close Quarters rules (p.92).")

	# p.93 — what does NOT change
	out.append("UNCHANGED BY THE GRID — ranged combat (range, Line of Sight) and every "
		+ "proximity question use the core rules in inches, and proximity reaches "
		+ "across squares: 5\" away in the next sector still counts as within 6\". "
		+ "Positioning inside a square therefore still matters (p.93).")
	out.append("BRAWLING — begins when a figure moves into contact with an opponent, "
		+ "by any movement method; typically during Close Quarters movement (p.93).")
	out.append("UNUSUAL MOVEMENT — Jump, Teleport and the like work as normal movement "
		+ "under the core rules. Items and abilities that adjust movement speed apply "
		+ "to Deployment ranges and Close Quarters movement, but do not otherwise "
		+ "affect grid movement (p.93).")

	out.append("MULTI-SQUARES (optional) — a building interior, or each usable height "
		+ "level, is its own sub-square reached through a designated entry point "
		+ "(door, ladder, elevator). Each sub-square counts as its own square for all "
		+ "game purposes unless stated otherwise (p.91).")
	out.append("You are not committed: the movement system may change from battle to "
		+ "battle within the same campaign (p.90).")
	return out


## Flag-gated wrapper. Empty when the option is off — an off option must
## contribute nothing.
static func get_setup_instructions(table_size_ft: float = 0.0) -> Array[String]:
	var out: Array[String] = []
	if not is_enabled():
		return out
	return build_setup_instructions(table_size_ft)


## ============================================================================
## PRE-BATTLE CHECKLIST (the moment the player lays out the table)
## ============================================================================
##
## The setup drawer is not enough. Grid movement changes the PHYSICAL setup —
## the table is divided into zones, and crew deploy in an edge square rather
## than a core-rules deployment zone — and the checklist is where the player
## actually performs that. Rule text generated into a closed drawer is not a
## delivered rule.

## p.90: "You do not have to commit to using this system for every battle of a
## given campaign. The movement system used can be changed as often as you want."
##
## So the DLC flag ("this content is active in my game") and the choice for THIS
## battle are two different questions. The `build_*` functions below are UNGATED
## and answer the second; the `get_*` wrappers gate on the flag and answer the
## first. The pre-battle checklist owns the per-battle choice and calls the
## builders directly; everything else keeps the flag-gated form.
static func build_checklist_step(table_size_ft: float = 0.0) -> Dictionary:
	var hint: String = ("Divide the play area into a grid of 3 or 4 squares per "
		+ "side, roughly 8-9\" across (Compendium p.90).")
	var rec: Dictionary = recommended_grid(table_size_ft)
	if not rec.is_empty():
		hint = ("Divide the play area into a %s grid — %s squares, %d sectors "
			+ "on your %s table. Beads, markers or scatter terrain, or just "
			+ "eyeball it. Terrain may cross the boundaries (Compendium p.90).") % [
				str(rec.get("id", "")),
				_fmt(float(rec.get("width_in", 0.0))),
				int(rec.get("sectors", 0)),
				_fmt_feet(table_size_ft),
			]
	return {
		"id": "grid_zones",
		"label": "Mark the movement grid",
		"hint": hint,
		"tier": 0,
	}


## p.90 replaces the core-rules deployment zone with an edge square.
static func build_deploy_crew_hint(table_size_ft: float = 0.0) -> String:
	var limit: String = "no more than halfway into it"
	var rec: Dictionary = recommended_grid(table_size_ft)
	if not rec.is_empty():
		limit = "within %s of the edge" % _fmt(
			float(rec.get("width_in", 0.0)) / 2.0)
	return ("Place each figure in a grid square TOUCHING your table edge, and "
		+ "%s. Otherwise placement is free and figures need not share a square "
		+ "(Compendium p.90).") % limit


## p.91: with Half Flank or Bolstered Flank the enemy starts a square in. The
## deployment type is not rolled until Seize the Initiative, so this is the
## general form shown at setup; the exact note fires later.
static func build_deploy_enemy_hint() -> String:
	return ("Place enemy figures in a grid square touching THEIR table edge, "
		+ "same halfway limit. If the mission uses Half Flank or Bolstered "
		+ "Flank, the flanking force starts in the SECOND square from that "
		+ "edge instead (Compendium pp.90-91).")


## Flag-gated wrappers — "is this content active in my game at all".
static func get_checklist_step(table_size_ft: float = 0.0) -> Dictionary:
	return build_checklist_step(table_size_ft) if is_enabled() else {}


static func get_deploy_crew_hint(table_size_ft: float = 0.0) -> String:
	return build_deploy_crew_hint(table_size_ft) if is_enabled() else ""


static func get_deploy_enemy_hint() -> String:
	return build_deploy_enemy_hint() if is_enabled() else ""


## p.91 Flanking. Returns "" for any deployment that is not one of the two the
## rule names, so the note never appears where the book does not put it.
## UNGATED — the caller decides whether the grid is in use THIS battle.
static func build_flanking_instruction(deployment_id: String) -> String:
	if not (deployment_id.strip_edges().to_lower() in FLANKING_DEPLOYMENTS):
		return ""
	return ("GRID FLANKING — the flanking force sets up in the SECOND square counting "
		+ "from the enemy table edge. Any figure a scenario requires to arrive from "
		+ "the flank is placed the same way (Compendium p.91).")


static func get_flanking_instruction(deployment_id: String) -> String:
	return build_flanking_instruction(deployment_id) if is_enabled() else ""


## ============================================================================
## REFERENCE TEXT (cheat sheet / rules drawer)
## ============================================================================

## BBCode summary for the in-battle reference drawer. Replaces the fabricated
## conversion table that shipped here previously — see the file docblock.
static func get_reference_text() -> String:
	return """[b]Grid-Based Movement (Compendium pp.90-93)[/b]
Optional. Can be switched on or off battle by battle.

[b]The Battle Space (p.90):[/b]
  Grid of 3 or 4 squares per side — 3x3, 3x4 or 4x4
  (9, 12 or 16 sectors). Aim for squares 8-9" across.
  Terrain may be placed freely and cross boundaries.

[b]Deployment (p.90):[/b]
  Set up in a square touching your table edge, and
  no more than [color=#4FC3F7]halfway into it[/color] (8" square → within 4").
  Placement otherwise free; figures may split squares.

[b]Square Status (p.91) — judged at activation:[/b]
  [color=#10B981]Open[/color] — only one side's figures in the square
  [color=#DC2626]Close Quarters[/color] — any enemy in it, at any range
  Neutral figures do not change the status while neutral.

[b]Open Movement (p.92):[/b]
  Adjacent square, straight — moves normally, [color=#10B981]may still act[/color]
  Adjacent square, [color=#D97706]diagonal[/color] — counts as having Dashed
  Or move anywhere within your current square and act

[b]Deploying (p.92):[/b]
  Entering a new square, place within your base move of
  the edge you came from (corner if diagonal). Speed 4"
  → within 4". [color=#4FC3F7]May Deploy directly into a Brawl.[/color]

[b]Close Quarters (p.92):[/b]
  Use the core movement rules in full, border or not.
  Closed → Open runs the [color=#DC2626]whole activation[/color] on Closed rules.

[b]Unchanged by the grid (p.93):[/b]
  Ranged combat, range and Line of Sight — core rules
  Proximity — core rules, and it reaches across squares
  (5" away in the next sector is still within 6")
  Brawling begins on contact, by any movement method
  Jump / Teleport work as normal core-rules movement

[b]Flanking (p.91) — deployment, not a combat bonus:[/b]
  With Half Flank or Bolstered Flank (p.45), the flanking
  force sets up in the [color=#4FC3F7]second square[/color] from the enemy
  table edge. No flanking to-hit bonus exists.

[b]Multi-squares (p.91, optional):[/b]
  Building interiors and each usable height level are
  sub-squares, joined by designated entry points."""
