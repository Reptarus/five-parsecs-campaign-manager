extends Control

## Bug Hunt Post-Battle Panel — Turn Stage 3 of 3
## Handles: Casualties, XP Awards, Reputation, Mustering Out,
## Operational Progress, Military Life events, and R&R.

signal phase_completed(result_data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING
const COLOR_DANGER := _UC.COLOR_DANGER

const POST_BATTLE_PATH := "res://data/bug_hunt/bug_hunt_post_battle.json"

var _campaign: Resource
var _phase_manager = null
var _post_battle_data: Dictionary = {}
var _battle_results: Dictionary = {}  # From TacticalBattleUI
var _results: Dictionary = {}
var _processed: bool = false
var _completed: bool = false

var _content_container: VBoxContainer

## Debrief widgets (Compendium pp.201-204). The battle screen cannot report a Bug
## Hunt objective -- the objectives are dice on a physical table -- so the player
## declares the outcome here and BugHuntBattleResultNormalizer scores it against
## the mission stamped before the battle.
const BugHuntResultNormalizer = preload(
	"res://src/core/battle/BugHuntBattleResultNormalizer.gd")

var _debrief_objective_checks: Array = []  # index-aligned with the stamp's objectives
var _debrief_signals_spin: SpinBox = null
var _debrief_lost_checks: Dictionary = {}  # character_id -> CheckBox
var _debrief_mvp_option: OptionButton = null
var _debrief_mvp_ids: Array = []

## The receipt this panel renders, and the widgets the player answers it with.
## BugHuntPostBattleResolver has no class_name, so it is preloaded by path.
const PostBattleResolver = preload(
	"res://src/core/campaign/BugHuntPostBattleResolver.gd")

var _receipt: Dictionary = {}
var _choice_nodes: Dictionary = {}  # choice id -> {"choice": Dictionary, "node": Control}


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_load_data()
	_build_ui()


func set_campaign(c: Resource) -> void:
	_campaign = c


func set_phase_manager(pm) -> void:
	_phase_manager = pm


func set_battle_results(results: Dictionary) -> void:
	## Receive real battle results from TacticalBattleUI via TurnController.
	_battle_results = results


func refresh() -> void:
	_processed = false
	_completed = false
	_results.clear()
	## Reopening a save mid-turn lands here with no battle result in memory. The
	## mission panel persisted the stamp and the turn controller wrote the battle
	## result onto it, so the debrief can be resumed instead of manufactured --
	## which is what the panel's deleted random-casualty fallback used to do.
	if _battle_results.is_empty():
		var stamp: Dictionary = _stamped_mission()
		var stored: Variant = stamp.get("battle_result", null)
		if stored is Dictionary and not (stored as Dictionary).is_empty():
			_battle_results = (stored as Dictionary).duplicate(true)
	_populate_post_battle()


func complete() -> void:
	## Belt-and-braces re-entry guard, mirroring SpecialAssignmentsPanel.complete()
	## (:56-59). _processed already stops the WORK being redone, but not the EMIT -- and
	## the emit is what reaches BugHuntPhaseManager.complete_current_phase() and
	## re-applies the whole turn's XP, tally, Reputation and Operational Progress.
	##
	## With the turn now ending at Phase.NONE the manager (:67-68) refuses a second call
	## anyway. This guard is what makes a regression there fail for ONE reason instead of
	## two, which is the difference between a test that names a cause and one that does not.
	if _completed:
		return
	if not _processed:
		_process_post_battle()
	_completed = true
	## What travels to the ONE mutator: the receipt the resolver produced, and the
	## answers the player gave. No decision is made here and no state is written --
	## BugHuntPhaseManager._apply_post_battle_results turns these two into effects.
	_results = {"receipt": _receipt, "answers": _collect_answers()}
	phase_completed.emit({"post_battle_result": _results})


func _load_data() -> void:
	var file := FileAccess.open(POST_BATTLE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_post_battle_data = json.data
	file.close()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", 16)
	scroll.add_child(_content_container)


func _populate_post_battle() -> void:
	for child in _content_container.get_children():
		child.queue_free()

	if not _campaign:
		var lbl := Label.new()
		lbl.text = "No campaign data available."
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_content_container.add_child(lbl)
		return

	_build_debrief_card()

	# Process button
	var process_btn := Button.new()
	process_btn.text = "Process Post-Battle"
	process_btn.custom_minimum_size = Vector2(0, 48)
	process_btn.pressed.connect(_process_post_battle)
	_content_container.add_child(process_btn)


func _process_post_battle() -> void:
	if _processed:
		return
	_processed = true

	## Score the debrief BEFORE resolving. Everything below reads
	## objectives_completed, priority, casualty_ids and lost_marine_ids, and this
	## is the only producer of the first and the last of those.
	_battle_results = BugHuntResultNormalizer.normalize(
		_battle_results, _stamped_mission(), _collect_debrief())
	_persist_battle_result()

	for child in _content_container.get_children():
		child.queue_free()

	## ONE resolve for the whole p.201-206 sequence. Every roll happens here, once,
	## and nothing is applied: the receipt is a description of what WILL happen.
	## HEAD rolled inside eight separate _process_* functions that each mutated the
	## campaign as they went, which is why a second press re-applied the turn.
	_receipt = PostBattleResolver.new().resolve(_build_snapshot())
	_choice_nodes.clear()
	_render_receipt()

	var complete_btn := Button.new()
	complete_btn.text = "Complete Post-Battle"
	complete_btn.custom_minimum_size = Vector2(0, 48)
	complete_btn.pressed.connect(func(): complete())
	_content_container.add_child(complete_btn)


func _stamped_mission() -> Dictionary:
	## The mission as it was stamped before the battle (BugHuntMissionPanel).
	if _campaign == null or not ("current_mission" in _campaign):
		return {}
	var cm: Variant = _campaign.current_mission
	return cm if cm is Dictionary else {}


func _persist_battle_result() -> void:
	## Keep the scored result with the mission it belongs to, so a reload during
	## Post-Battle resumes the debrief rather than starting one from nothing.
	if _campaign == null or not ("current_mission" in _campaign):
		return
	var cm: Variant = _campaign.current_mission
	if not (cm is Dictionary):
		return
	var stamp: Dictionary = cm
	stamp["battle_result"] = _battle_results.duplicate(true)
	_campaign.current_mission = stamp
	if _campaign.has_method("persist"):
		_campaign.persist()


func _build_debrief_card() -> void:
	## The DEBRIEF. Four facts the app cannot observe and the player can:
	## which Objectives were completed (p.187 puts them on the table as dice
	## results, so nothing in the app tracks them), how many Signals were
	## investigated (p.201), who walked off a battlefield edge rather than
	## through Evac (p.202), and who the MVP was (p.204, "one character of
	## choice"). Everything else is derived.
	_debrief_objective_checks.clear()
	_debrief_lost_checks.clear()
	_debrief_signals_spin = null
	_debrief_mvp_option = null
	_debrief_mvp_ids.clear()

	var stamp: Dictionary = _stamped_mission()
	var card := _create_card("Debrief", _content_container)

	var objectives: Array = stamp.get("objectives", []) if stamp.get("objectives", []) is Array else []
	if objectives.is_empty():
		var none := Label.new()
		none.text = "No mission was stamped for this turn, so Objectives cannot be scored here."
		none.add_theme_color_override("font_color", COLOR_WARNING)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(none)
	else:
		var hint := Label.new()
		hint.text = "Tick every Objective the squad completed. A Vital Objective counts as 2 and a Critical as 3 (Compendium pp.185, 201)."
		hint.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		hint.add_theme_font_size_override("font_size", _scaled_font(12))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(hint)
		for i in objectives.size():
			var obj: Dictionary = objectives[i] if objectives[i] is Dictionary else {}
			var type_data: Dictionary = obj.get("type", {}) if obj.get("type", {}) is Dictionary else {}
			var weight: int = int(obj.get("weight", 1))
			var rating: String = str(obj.get("rating", "normal"))
			var suffix: String = "" if rating == "normal" else " — %s, counts as %d" % [
				rating.capitalize(), weight]
			var check := CheckBox.new()
			check.text = "%s%s" % [str(type_data.get("name", "Objective %d" % (i + 1))), suffix]
			check.custom_minimum_size = Vector2(0, 40)
			card.add_child(check)
			_debrief_objective_checks.append(check)

	if bool(stamp.get("use_signals", false)):
		var total: int = int(stamp.get("signals_total", 0))
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Signals investigated (of %d):" % total
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		_debrief_signals_spin = SpinBox.new()
		_debrief_signals_spin.min_value = 0
		_debrief_signals_spin.max_value = maxi(total, 0)
		_debrief_signals_spin.value = 0
		row.add_child(_debrief_signals_spin)
		card.add_child(row)
		var note := Label.new()
		note.text = "With 4 or more Signals, fewer than 2 investigated costs 1 Objective (p.201)."
		note.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		note.add_theme_font_size_override("font_size", _scaled_font(12))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(note)

	var casualty_ids: Array = _battle_results.get("casualty_ids", []) \
		if _battle_results.get("casualty_ids", []) is Array else []
	if not casualty_ids.is_empty():
		var lost_lbl := Label.new()
		lost_lbl.text = "Left the table by a battlefield edge rather than through Evac (p.202):"
		lost_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		lost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(lost_lbl)
		for cid in casualty_ids:
			var check2 := CheckBox.new()
			check2.text = _character_name(str(cid))
			check2.custom_minimum_size = Vector2(0, 40)
			card.add_child(check2)
			_debrief_lost_checks[str(cid)] = check2

	var participants: Array = _battle_results.get("participant_ids", []) \
		if _battle_results.get("participant_ids", []) is Array else []
	if not participants.is_empty():
		var mvp_row := HBoxContainer.new()
		var mvp_lbl := Label.new()
		mvp_lbl.text = "MVP (+1 XP, p.204):"
		mvp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mvp_row.add_child(mvp_lbl)
		_debrief_mvp_option = OptionButton.new()
		for pid in participants:
			_debrief_mvp_ids.append(str(pid))
			_debrief_mvp_option.add_item(_character_name(str(pid)))
		# p.204 awards the MVP outright, so the first name is preselected rather
		# than leaving the award unclaimed by default. "No MVP" is last so the
		# player can still decline it.
		_debrief_mvp_ids.append("")
		_debrief_mvp_option.add_item("— no MVP —")
		_debrief_mvp_option.select(0)
		mvp_row.add_child(_debrief_mvp_option)
		card.add_child(mvp_row)


func _character_name(char_id: String) -> String:
	if _campaign and "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is Dictionary and str(mc.get("id", mc.get("character_id", ""))) == char_id:
				return str(mc.get("name", mc.get("character_name", char_id)))
	return char_id


func _collect_debrief() -> Dictionary:
	## Only the fields whose widgets actually rendered. An absent field means "the
	## player was never asked", which the normalizer leaves alone -- as opposed to
	## an empty one, which would overwrite a value some other producer supplied.
	var debrief: Dictionary = {}
	if not _debrief_objective_checks.is_empty():
		var completed: Array = []
		for i in _debrief_objective_checks.size():
			var check: CheckBox = _debrief_objective_checks[i]
			if is_instance_valid(check) and check.button_pressed:
				completed.append(i)
		debrief["completed_objective_indices"] = completed
	if _debrief_signals_spin != null and is_instance_valid(_debrief_signals_spin):
		debrief["signals_investigated"] = int(_debrief_signals_spin.value)
	if not _debrief_lost_checks.is_empty():
		var lost: Array = []
		for cid in _debrief_lost_checks:
			var check2: CheckBox = _debrief_lost_checks[cid]
			if is_instance_valid(check2) and check2.button_pressed:
				lost.append(cid)
		debrief["lost_marine_ids"] = lost
	if _debrief_mvp_option != null and is_instance_valid(_debrief_mvp_option):
		var idx: int = _debrief_mvp_option.selected
		if idx >= 0 and idx < _debrief_mvp_ids.size():
			debrief["mvp_id"] = str(_debrief_mvp_ids[idx])
	return debrief


# ──────────────────────────────────────────────────────────────────────────────
# Receipt rendering — Compendium pp.201-206
# ──────────────────────────────────────────────────────────────────────────────
#
# PRESENTATION ONLY. Nothing below writes to _campaign. The eight _process_* and
# two _check_* functions that used to live here each rolled their own dice, read
# their own JSON table and mutated the core as they went; the rules are now in
# BugHuntPostBattleResolver (pure) and the writes in BugHuntPhaseManager (the one
# mutator). Three private table helpers went with them -- _roll_dice_formula,
# _find_in_table and _find_in_op_progress. The last of those was also a live
# class-(b) abort: six of the nine casualty rows carry a null Lost Marine range,
# entry.has(key) is TRUE for those, and assigning null to a typed Array unwinds
# the function. The resolver's _find_row type-tests the value instead.


func _build_snapshot() -> Dictionary:
	## Everything the resolver is allowed to see, and a COPY of it. The resolver is
	## pure by contract; handing it the core would be the one thing that lets a rule
	## write state from outside the single mutator.
	if _campaign == null:
		return {}
	var chars: Array = []
	if "main_characters" in _campaign:
		for mc in _campaign.main_characters:
			if mc is Dictionary:
				chars.append((mc as Dictionary).duplicate(true))
	var bay: Dictionary = {}
	if "sick_bay" in _campaign and _campaign.sick_bay is Dictionary:
		bay = (_campaign.sick_bay as Dictionary).duplicate(true)
	var mlm: Dictionary = {}
	if "military_life_modifiers" in _campaign and _campaign.military_life_modifiers is Dictionary:
		mlm = _campaign.military_life_modifiers
	return {
		"characters": chars,
		"battle_result": _battle_results.duplicate(true),
		"sick_bay": bay,
		"reputation": int(_campaign.reputation) if "reputation" in _campaign else 0,
		"operational_progress_modifier": (
			int(_campaign.operational_progress_modifier)
			if "operational_progress_modifier" in _campaign else 0),
		"missions_in_current_operation": (
			int(_campaign.missions_in_current_operation)
			if "missions_in_current_operation" in _campaign else 0),
		# Banked by a paid early R&R on a previous turn (p.206). Step 7 of THIS
		# resolve consumes it and emits the clear, so it must be read, not assumed.
		"pending_military_life_rolls": int(mlm.get("pending_rolls", 0)),
	}


func _render_receipt() -> void:
	var steps: Array = _receipt.get("steps", [])
	if steps.is_empty():
		var lbl := Label.new()
		lbl.text = "No post-battle steps applied."
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_content_container.add_child(lbl)
		return
	## Choices are grouped under the step that raised them, so the player reads the
	## rule and answers it in the same card rather than in a separate block.
	var by_step: Dictionary = {}
	for c in _receipt.get("choices_needed", []):
		if not (c is Dictionary):
			continue
		by_step[str(c.get("id", ""))] = c
	for step in steps:
		if step is Dictionary:
			_render_step(step, by_step)


func _render_step(step: Dictionary, by_step: Dictionary) -> void:
	var index: int = int(step.get("step", 0))
	var title: String = str(step.get("title", ""))
	var heading: String = title if index <= 0 else "Step %d: %s" % [index, title]
	var card := _create_card(heading, _content_container)

	var cite: String = str(step.get("cite", ""))
	if not cite.is_empty():
		_muted_label(cite, card, 11)

	## A step's own rolls, in the shape the resolver records them:
	## {die, value, subject?, modifier?, total?}. Showing the die and the number is
	## what lets a player check a result against the printed table themselves.
	for roll in step.get("rolls", []):
		if not (roll is Dictionary):
			continue
		var txt: String = "%s -> %s" % [str(roll.get("die", "")), str(roll.get("value", ""))]
		if roll.has("modifier") and int(roll["modifier"]) != 0:
			txt += " %+d = %s" % [int(roll["modifier"]),
				str(roll.get("total", roll.get("value", "")))]
		var subj: String = str(roll.get("subject", ""))
		if not subj.is_empty():
			# _character_name returns the id unchanged when it matches nobody, which
			# is what the objective rolls want -- their subject is "objective 2".
			txt += "  (%s)" % _character_name(subj)
		var col: String = str(roll.get("column", ""))
		if not col.is_empty():
			txt += " [%s]" % col
		_muted_label(txt, card, 11)

	var lines: Array = step.get("lines", [])
	if lines.is_empty() and bool(step.get("skipped", false)):
		_muted_label("Not applicable this turn.", card, 12)
	for line in lines:
		var lbl := Label.new()
		lbl.text = str(line)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		card.add_child(lbl)

	for c in step.get("choices", []):
		if c is Dictionary and by_step.has(str(c.get("id", ""))):
			_render_choice(c, card)


func _render_choice(choice: Dictionary, card: VBoxContainer) -> void:
	## One widget per choice KIND. The prompt text is the resolver's -- it carries
	## the book's own wording and the numbers the rule computed, so the panel never
	## restates a cost or a threshold and the two cannot drift.
	var cid: String = str(choice.get("id", ""))
	var kind: String = str(choice.get("kind", ""))
	if cid.is_empty() or kind.is_empty():
		return
	var prompt: String = str(choice.get("prompt", ""))

	match kind:
		"court_martial_buyout", "advanced_care", "military_life_purchase", "early_rr":
			var check := CheckBox.new()
			check.text = prompt
			check.add_theme_font_size_override("font_size", _scaled_font(13))
			# Re-check affordability HERE as well as in the resolver: a purchase
			# priced against the XP the character had when the receipt was built can
			# be made unaffordable by an advancement picked further up the page.
			if kind == "military_life_purchase":
				check.disabled = int(choice.get("xp_available", 0)) < int(choice.get("xp_cost", 0))
			card.add_child(check)
			_choice_nodes[cid] = {"choice": choice, "node": check}
		"mvp":
			var opt := OptionButton.new()
			for o in choice.get("options", []):
				if o is Dictionary:
					opt.add_item(str(o.get("name", o.get("id", ""))))
			if opt.item_count > 0:
				opt.select(0)
			_labelled_row(prompt, opt, card)
			_choice_nodes[cid] = {"choice": choice, "node": opt}
		"military_life_priority":
			var popt := OptionButton.new()
			for v in choice.get("options", []):
				popt.add_item("%+d" % int(v))
			if popt.item_count > 0:
				popt.select(0)
			_labelled_row(prompt, popt, card)
			_choice_nodes[cid] = {"choice": choice, "node": popt}
		"military_life_weapon":
			# The ONE choice the resolver cannot pre-fill: it is pure and never sees
			# the roster's equipment, so the weapon list comes from the character.
			var wopt := OptionButton.new()
			for w in _character_equipment(str(choice.get("target", ""))):
				wopt.add_item(str(w))
			if wopt.item_count > 0:
				wopt.select(0)
			else:
				wopt.disabled = true
				wopt.add_item("(no personal weapons)")
			_labelled_row(prompt, wopt, card)
			_choice_nodes[cid] = {"choice": choice, "node": wopt}
		"military_life_favor":
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = maxi(int(choice.get("max_spend", 0)), 0)
			spin.step = 1
			spin.value = 0
			_labelled_row(prompt, spin, card)
			_choice_nodes[cid] = {"choice": choice, "node": spin}
		"advancement":
			_render_advancement(choice, card)
		_:
			push_warning("BugHuntPostBattlePanel: unrendered choice kind '%s'" % kind)


func _render_advancement(choice: Dictionary, card: VBoxContainer) -> void:
	## Several stats can be bought from ONE experience pool, so affordability is a
	## running total rather than a per-row test: every unchecked option whose cost
	## no longer fits is disabled as the player spends, and re-enabled if they
	## change their mind. The resolver charges the same costs, so this is a
	## courtesy, not the enforcement.
	var prompt: String = str(choice.get("prompt", ""))
	var pool: int = int(choice.get("xp_available", 0))
	var lbl := Label.new()
	lbl.text = "%s (%d XP available)" % [prompt, pool]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(lbl)

	var remaining := Label.new()
	remaining.add_theme_font_size_override("font_size", _scaled_font(11))
	remaining.add_theme_color_override("font_color", COLOR_TEXT_SEC)

	var boxes: Array = []
	for opt in choice.get("options", []):
		if not (opt is Dictionary):
			continue
		var stat: String = str(opt.get("stat", ""))
		var cost: int = int(opt.get("xp_cost", 0))
		var check := CheckBox.new()
		check.text = "%s +1  (%d XP)" % [stat.capitalize().replace("_", " "), cost]
		check.add_theme_font_size_override("font_size", _scaled_font(13))
		check.set_meta("stat", stat)
		check.set_meta("xp_cost", cost)
		check.disabled = cost > pool
		card.add_child(check)
		boxes.append(check)

	var refit := func(_pressed: bool) -> void:
		var spent: int = 0
		for b in boxes:
			if is_instance_valid(b) and b.button_pressed:
				spent += int(b.get_meta("xp_cost", 0))
		for b in boxes:
			if is_instance_valid(b) and not b.button_pressed:
				b.disabled = int(b.get_meta("xp_cost", 0)) > pool - spent
		if is_instance_valid(remaining):
			remaining.text = "%d XP remaining" % maxi(pool - spent, 0)
	for b in boxes:
		b.toggled.connect(refit)
	refit.call(false)

	card.add_child(remaining)
	_choice_nodes[str(choice.get("id", ""))] = {"choice": choice, "node": null, "boxes": boxes}


func _character_equipment(char_id: String) -> Array:
	if _campaign == null or not ("main_characters" in _campaign):
		return []
	for mc in _campaign.main_characters:
		if not (mc is Dictionary):
			continue
		if str(mc.get("id", mc.get("character_id", ""))) != char_id:
			continue
		var gear: Variant = mc.get("equipment", [])
		return gear if gear is Array else []
	return []


func _collect_answers() -> Dictionary:
	## choice id -> the player's answer, in the shapes
	## BugHuntPostBattleResolver.apply_choices() matches on. A choice whose widget
	## has nothing selected is OMITTED rather than answered with a blank: that
	## function iterates the answers it is GIVEN, so an absent key means "not
	## taken", while an empty string would emit a weapon bonus on no weapon.
	var answers: Dictionary = {}
	for cid in _choice_nodes:
		var entry: Dictionary = _choice_nodes[cid]
		var choice: Dictionary = entry.get("choice", {})
		var kind: String = str(choice.get("kind", ""))
		var node: Variant = entry.get("node", null)

		if kind == "advancement":
			var picked: Array = []
			for b in entry.get("boxes", []):
				if is_instance_valid(b) and b.button_pressed:
					picked.append(str(b.get_meta("stat", "")))
			if not picked.is_empty():
				answers[cid] = picked
			continue

		if node == null or not is_instance_valid(node):
			continue

		match kind:
			"court_martial_buyout", "advanced_care", "military_life_purchase", "early_rr":
				answers[cid] = (node as CheckBox).button_pressed
			"mvp":
				var mopt := node as OptionButton
				var mi: int = mopt.selected
				var opts: Array = choice.get("options", [])
				if mi >= 0 and mi < opts.size() and opts[mi] is Dictionary:
					answers[cid] = str((opts[mi] as Dictionary).get("id", ""))
			"military_life_priority":
				var popt := node as OptionButton
				var pi: int = popt.selected
				var pvals: Array = choice.get("options", [])
				if pi >= 0 and pi < pvals.size():
					answers[cid] = int(pvals[pi])
			"military_life_weapon":
				var wopt := node as OptionButton
				if not wopt.disabled and wopt.selected >= 0:
					answers[cid] = wopt.get_item_text(wopt.selected)
			"military_life_favor":
				var spend: int = int((node as SpinBox).value)
				if spend > 0:
					answers[cid] = spend
	return answers


func _labelled_row(prompt: String, control: Control, parent: VBoxContainer) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = prompt
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(lbl)
	control.custom_minimum_size = Vector2(0, 44)
	row.add_child(control)
	parent.add_child(row)


func _muted_label(text: String, parent: VBoxContainer, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _scaled_font(size))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	parent.add_child(lbl)
	return lbl


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox
