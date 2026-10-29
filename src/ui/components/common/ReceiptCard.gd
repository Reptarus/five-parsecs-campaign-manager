extends RefCounted
## One post-battle receipt step, rendered the same way in every mode (UX-6).
##
## Bug Hunt (BugHuntPostBattlePanel), Tactics (TacticsOperationalMapPanel) and Planetfall
## (PlanetfallPostBattlePanel) each record what a post-battle step rolled and decided, and
## until 2026-10-28 each had its own renderer for it. Three renderers drift: a roll printed
## with its modifier in one mode and without it in the next, a skipped step announced in
## one and silent in another. This file owns the CONTENT of a receipt card (the cite, the
## dice, the result lines, the skipped notice). Each panel keeps its own card chrome, and
## Bug Hunt keeps its choice widgets, which no other mode has.
##
## A step: {step?, title?, cite?, rolls?: [{die, value, subject?, modifier?, total?,
## column?}], lines?: [String], skipped?: bool, bbcode?: bool}
##
## ⚠ Assert a step's RESULT line, never only its heading. A heading renders for a step the
## rule skipped: the Bug Hunt Phase 7 Court Martial detector returned the same answer in
## both arms because the heading was on screen either way.


## "Step N: Title", or the bare title for an unnumbered step.
static func heading(step: Dictionary) -> String:
	var index: int = int(step.get("step", 0))
	var title: String = str(step.get("title", ""))
	return title if index <= 0 else "Step %d: %s" % [index, title]


## A roll as "D6 -> 4 +1 = 5  (Ash) [Column]". Showing the die and the number is what lets
## a player check a result against the printed table. `name_of` turns a subject id into a
## name; a resolver that returns the id unchanged for no match suits subjects such as
## "objective 2".
static func roll_text(roll: Dictionary, name_of: Callable = Callable()) -> String:
	var txt: String = "%s -> %s" % [str(roll.get("die", "")), str(roll.get("value", ""))]
	if roll.has("modifier") and int(roll["modifier"]) != 0:
		txt += " %+d = %s" % [int(roll["modifier"]),
			str(roll.get("total", roll.get("value", "")))]
	var subj: String = str(roll.get("subject", ""))
	if not subj.is_empty():
		txt += "  (%s)" % (str(name_of.call(subj)) if name_of.is_valid() else subj)
	var col: String = str(roll.get("column", ""))
	if not col.is_empty():
		txt += " [%s]" % col
	return txt


## The cite, the dice and the result lines of `step`, added to `body`. A skipped step with
## nothing to say is announced as such rather than left as a bare heading.
static func fill(body: Control, step: Dictionary, name_of: Callable = Callable(),
		size: int = 13) -> void:
	var cite: String = str(step.get("cite", ""))
	if not cite.is_empty():
		_muted(body, cite, 11)
	for roll in step.get("rolls", []):
		if roll is Dictionary:
			_muted(body, roll_text(roll, name_of), 11)
	var lines: Array = step.get("lines", [])
	if lines.is_empty() and bool(step.get("skipped", false)):
		_muted(body, "Not applicable this turn.", 12)
	var bbcode: bool = bool(step.get("bbcode", false))
	for line in lines:
		add_line(body, str(line), bbcode, size)


## One result line. BBCode only when the caller's lines carry it (Planetfall's do); a plain
## Label otherwise, so a roll column such as "[Grunt]" can never be parsed as a tag.
static func add_line(body: Control, text: String, bbcode: bool = false,
		size: int = 13) -> Control:
	if bbcode:
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.text = UIColors.bbcode(text)
		ScreenChrome.size_rich_text(rich, ScreenChrome.font_size(size))
		rich.add_theme_color_override("default_color", UIColors.COLOR_TEXT_PRIMARY)
		body.add_child(rich)
		return rich
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	body.add_child(lbl)
	return lbl


static func _muted(body: Control, text: String, size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	body.add_child(lbl)
