class_name PlanetfallScoutReportsPanel
extends Control

## Step 3: Scout Reports (Planetfall pp.59-61), in the book's order:
##   1. Scout Explore: "one Scout Explore action" on a sector the player picks on the map.
##   2. Scout Discovery (optional): a D100 roll, led by a scout if the player assigns one.
##   3. Process Enemy Information: a 1D6 per enemy against its Enemy Information.
## The phase manager resolves and records every part (scout_explore, scout_discovery_roll,
## scout_discovery_apply, scout_enemy_information); this screen shows the map, asks for
## the picks and renders the receipt, so a resumed turn shows what was rolled.
##
## Until 2026-10-28 this screen rolled its own dice, showed no map, told the player to
## "mark these values on your colony map" and wrote nothing, and it carried its own copy
## of the Discovery table whose results were never applied.

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const SectorGridScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ACCENT := UIColors.COLOR_CYAN
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const TOUCH_TARGET_MIN := 48

var _campaign: Resource
var _phase_manager: Node
## The sector the player has tapped and not yet confirmed, for Explore or an
## Exploration report.
var _pending_sector: String = ""

var _title_label: Label
var _grid: Control
var _map_hint: Label
var _explore_btn: Button
var _explore_result: VBoxContainer
var _scout_select: OptionButton
var _discovery_btn: Button
## Why a button is disabled, under it: a phone has no hover for a tooltip, and a
## longer button label would be wider than a phone (an unwrapped Button's text is its
## minimum width).
var _discovery_why: Label
var _intel_why: Label
var _discovery_result: VBoxContainer
var _choice_box: VBoxContainer
var _intel_btn: Button
var _intel_result: VBoxContainer


func _ready() -> void:
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_pending_sector = ""
	if _campaign:
		MapScript.ensure_map(_campaign)
	_populate_scout_select()
	_render()


## Resolve whatever is left with the defaults: explore the first sector the rules allow,
## skip the optional Discovery, process Enemy Information, then complete.
## What the turn screen's footer shows for this step: {ready, reason}. Ready once
## Enemy Information is processed; until then the reason names the part still to do.
## The step used to carry its own "Continue to Step 4" button at the bottom of the
## scroll, beside a footer "Complete Phase" that was disabled on every step.
func step_status() -> Dictionary:
	var status: Dictionary = {"ready": false, "reason": ""}
	if not _phase_manager or not _campaign:
		status.ready = true
		return status
	var receipt: Dictionary = _phase_manager.scout_receipt()
	if receipt.has("enemy_information"):
		status.ready = true
	elif not _explore_settled(receipt):
		status.reason = "Explore a sector first (part 1)."
	elif _picking_report(receipt):
		status.reason = "Tap the sector for the Exploration Report first (part 2)."
	else:
		status.reason = "Process Enemy Information to finish this step (part 3)."
	return status


func complete() -> void:
	if not _phase_manager or not _campaign:
		phase_completed.emit({})
		return
	var receipt: Dictionary = _phase_manager.scout_receipt()
	if not receipt.has("explore"):
		var targets: Array = MapScript.explore_targets(_campaign)
		if not targets.is_empty():
			_phase_manager.scout_explore(str(targets[0]))
	if not _phase_manager.scout_receipt().has("enemy_information"):
		_phase_manager.scout_enemy_information()
	phase_completed.emit({})


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_MD)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 3: SCOUT REPORTS"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	vbox.add_child(_prose("Your scouts explore one sector, then may roll for a Scout "
			+ "Discovery. Last, the colony pieces together any Enemy Information (pp.59-61)."))

	# 1. Scout Explore
	vbox.add_child(_heading("1. Scout Explore"))
	_map_hint = _prose("")
	vbox.add_child(_map_hint)
	_grid = SectorGridScript.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.sector_selected.connect(_on_sector_picked)
	vbox.add_child(_grid)
	_explore_btn = _button("Explore the selected sector", _on_explore_pressed)
	vbox.add_child(_explore_btn)
	_explore_result = _result_box()
	vbox.add_child(_explore_result)

	# 2. Scout Discovery (optional)
	vbox.add_child(_heading("2. Scout Discovery (optional)"))
	vbox.add_child(_prose("You may assign a scout to lead it. It does not stop them going "
			+ "on a mission this turn. Scouts in Sick Bay cannot be assigned (p.60)."))
	var scout_row := HFlowContainer.new()
	scout_row.add_theme_constant_override("h_separation", SPACING_SM)
	scout_row.add_theme_constant_override("v_separation", SPACING_SM)
	vbox.add_child(scout_row)
	var scout_lbl := Label.new()
	scout_lbl.text = "Scout leading it:"
	scout_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	scout_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	scout_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scout_row.add_child(scout_lbl)
	_scout_select = OptionButton.new()
	_scout_select.custom_minimum_size = Vector2(220, TOUCH_TARGET_MIN)
	scout_row.add_child(_scout_select)
	_discovery_btn = _button("Roll Scout Discovery (D100)", _on_discovery_pressed)
	vbox.add_child(_discovery_btn)
	_discovery_why = _prose("")
	vbox.add_child(_discovery_why)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_choice_box)
	_discovery_result = _result_box()
	vbox.add_child(_discovery_result)

	# 3. Process Enemy Information
	vbox.add_child(_heading("3. Process Enemy Information"))
	vbox.add_child(_prose("For each enemy you hold Enemy Information on, roll 1D6. Equal to "
			+ "or under it, you have tracked down a Boss and may Strike (pp.60-61)."))
	_intel_btn = _button("Process Enemy Information", _on_intel_pressed)
	vbox.add_child(_intel_btn)
	_intel_why = _prose("")
	vbox.add_child(_intel_why)
	_intel_result = _result_box()
	vbox.add_child(_intel_result)

	TouchScrollOpenerRef.open_subtree(self)


func _heading(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	return lbl


func _prose(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return lbl


## An action button sized to its text. `choice` is for the sentence-length answers to a
## Discovery: those wrap and fill the width, because an unwrapped Button reports its whole
## text as a minimum and pushes a phone page off the right edge; a wrapping one left at
## SHRINK_CENTER would shrink to a one-word sliver instead.
func _button(text: String, handler: Callable, choice: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	if choice:
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(handler)
	return btn


func _result_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	return box


func _show_lines(box: VBoxContainer, lines: Array) -> void:
	for child in box.get_children():
		child.queue_free()
	for line in lines:
		var lbl := Label.new()
		lbl.text = str(line)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		box.add_child(lbl)


## ============================================================================
## STATE → SCREEN
## ============================================================================

## Draw every part from the phase manager's receipt.
func _render() -> void:
	if not _campaign or not _grid:
		return
	var receipt: Dictionary = _phase_manager.scout_receipt() if _phase_manager else {}
	var explored: bool = receipt.has("explore")
	var settled: bool = _explore_settled(receipt)
	var discovery: Dictionary = receipt.get("discovery", {})
	var intel_done: bool = receipt.has("enemy_information")
	var picking_report: bool = _picking_report(receipt)

	var pickable: Array = []
	if not settled:
		pickable = MapScript.explore_targets(_campaign)
		_map_hint.text = ("Tap a sector to explore. It cannot be enemy-held or already "
				+ "Exploited (p.60). Your colony is marked H.")
	elif not explored:
		# Every sector is enemy-held or Exploited: nothing can be explored, and the step
		# must still finish (processing Enemy Information does not need an Explore).
		_map_hint.text = ("Every sector is enemy-held or already Exploited, so there is "
				+ "nothing to explore this turn (p.60).")
	elif picking_report:
		pickable = MapScript.unexplored_keys(_campaign)
		_map_hint.text = "Exploration report: tap a sector that has not been Explored (p.59)."
	else:
		_map_hint.text = "This turn's Scout Explore is done."
	_grid.configure(_campaign, pickable, _pending_sector)

	_explore_btn.visible = not explored
	_explore_btn.disabled = _pending_sector == "" or explored
	_explore_btn.text = "Explore %s" % MapScript.label(_pending_sector) \
			if _pending_sector != "" and not explored else "Explore the selected sector"
	_show_lines(_explore_result, receipt.get("explore", {}).get("lines", []))

	# A disabled button says why, in a line under it.
	# Discovery follows an Explore (p.60), so it is hidden when nothing could be explored.
	_scout_select.disabled = not explored or not discovery.is_empty() or intel_done
	_discovery_btn.visible = discovery.is_empty() and not intel_done \
			and (explored or not settled)
	_discovery_btn.disabled = not explored
	_show_why(_discovery_why, _discovery_btn, "Explore a sector first.")
	_render_discovery(discovery)

	_intel_btn.visible = not intel_done
	_intel_btn.disabled = not settled or picking_report
	_show_why(_intel_why, _intel_btn, "Explore a sector first." if not settled
			else "Tap the sector for the Exploration Report first.")
	_show_lines(_intel_result, receipt.get("enemy_information", {}).get("lines", []))
	TouchScrollOpenerRef.open_subtree(self)
	step_status_changed.emit()


func _show_why(why: Label, btn: Button, reason: String) -> void:
	why.text = reason
	why.visible = btn.visible and btn.disabled


## Scout Explore is done, or cannot be done because no sector may be explored (p.60).
func _explore_settled(receipt: Dictionary) -> bool:
	return receipt.has("explore") or MapScript.explore_targets(_campaign).is_empty()


## A Scout Discovery Exploration Report is waiting for the player to pick its sector.
func _picking_report(receipt: Dictionary) -> bool:
	var discovery: Dictionary = receipt.get("discovery", {})
	return not discovery.is_empty() and not bool(discovery.get("applied", false)) \
			and str(discovery.get("choice", "")) == "sector"


func _render_discovery(discovery: Dictionary) -> void:
	for child in _choice_box.get_children():
		child.queue_free()
	if discovery.is_empty():
		_show_lines(_discovery_result, [])
		return
	var entry: Dictionary = discovery.get("entry", {})
	var head: Array = ["D100 %d: %s. %s" % [int(entry.get("roll", 0)), str(entry.get("name", "")),
			str(entry.get("description", ""))]]
	if bool(discovery.get("applied", false)):
		_show_lines(_discovery_result, head + discovery.get("lines", []))
		return
	_show_lines(_discovery_result, head)
	match str(discovery.get("choice", "")):
		"sector":
			var apply_btn := _button("Explore %s" % MapScript.label(_pending_sector)
					if _pending_sector != "" else "Tap a sector on the map above",
					func() -> void: _apply_discovery({"sector": _pending_sector}))
			apply_btn.disabled = _pending_sector == ""
			_choice_box.add_child(apply_btn)
		"enemy":
			_choice_box.add_child(_prose("Recon patrol: choose the enemy to gain 1 Enemy "
					+ "Information on (p.59)."))
			for idx in MapScript.active_indices(_campaign):
				var i: int = int(idx)
				_choice_box.add_child(_button(MapScript.enemy_name(_campaign, i),
						func() -> void: _apply_discovery({"enemy_index": i}), true))
		"scout_down":
			_choice_box.add_child(_button("Escape on foot: an injury roll, +2 XP if they survive",
					func() -> void: _apply_discovery({"scout_down": "escape"}), true))
			_choice_box.add_child(_button("Play the Scout Down! mission this turn",
					func() -> void: _apply_discovery({"scout_down": "mission"}), true))
		_:
			_apply_discovery({})


func _populate_scout_select() -> void:
	if not _scout_select:
		return
	_scout_select.clear()
	_scout_select.add_item("No scout assigned", 0)
	_scout_select.set_item_metadata(0, "")
	if not _campaign or not _campaign.has_method("get_active_roster"):
		return
	var idx: int = 1
	for c in _campaign.get_active_roster():
		if c is Dictionary and str(c.get("class", "")) == "scout":
			_scout_select.add_item("%s (Scout)" % str(c.get("name", "Scout")), idx)
			_scout_select.set_item_metadata(idx, str(c.get("id", "")))
			idx += 1


## ============================================================================
## ACTIONS (each one call into the phase manager, then a redraw)
## ============================================================================

func _on_sector_picked(sector_key: String) -> void:
	_pending_sector = sector_key
	_render()


func _on_explore_pressed() -> void:
	if not _phase_manager or _pending_sector == "":
		return
	_phase_manager.scout_explore(_pending_sector)
	_pending_sector = ""
	_render()


func _on_discovery_pressed() -> void:
	if not _phase_manager:
		return
	var scout_id: String = str(_scout_select.get_selected_metadata()) \
			if _scout_select.selected >= 0 else ""
	_phase_manager.scout_discovery_roll(scout_id)
	_render()


func _apply_discovery(choice: Dictionary) -> void:
	if not _phase_manager:
		return
	_phase_manager.scout_discovery_apply(choice)
	_pending_sector = ""
	_render()


func _on_intel_pressed() -> void:
	if not _phase_manager:
		return
	_phase_manager.scout_enemy_information()
	_render()

