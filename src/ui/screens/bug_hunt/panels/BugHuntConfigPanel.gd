extends Control

## Bug Hunt Config Panel — Step 1 of 4
## Campaign name, difficulty selection, regiment name generation.

signal config_updated(data: Dictionary)

# Deep space theme tokens (via UIColors canonical source)
const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_INPUT := _UC.COLOR_INPUT
const COLOR_DANGER := _UC.COLOR_DANGER
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _coordinator = null
var _name_edit: LineEdit
var _validation_label: Label
var _regiment_label: Label
var _color_label: Label
var _difficulty_option: OptionButton
var _escalation_check: CheckButton

## Co-op campaign (Compendium pp.209-211). The rules and the map are
## BugHuntCoopCampaign's; this card only collects the three things p.210 asks the
## players for -- who is playing, and how many sectors each -- and the coordinator
## hands them to BugHuntCampaignCore.start_coop_campaign() at Launch.
const CoopView := preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
var _coop_check: CheckButton
var _coop_body: VBoxContainer
var _coop_rows_box: VBoxContainer
var _coop_per_option: OptionButton
var _coop_total_label: Label
var _coop_error_label: Label
var _escalation_note: Label
var _coop_preselect_pending: bool = false

var _config_data: Dictionary = {
	"campaign_name": "",
	"regiment_name": "",
	"uniform_color": "",
	"difficulty": "mess_me_up",
	"use_campaign_escalation": false,
	"coop_enabled": false,
	"coop_players": [],
	"coop_sectors_per_player": 0,
}

const DIFFICULTIES := [
	{"id": "im_too_pretty_to_die", "name": "I'm Too Pretty to Die"},
	{"id": "hey_not_too_crazy", "name": "Hey, Not Too Crazy"},
	{"id": "mess_me_up", "name": "Mess Me Up"},
	{"id": "mega_violence", "name": "Mega-violence"},
	{"id": "living_nightmare", "name": "Living Nightmare"}
]


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Never sideways: a form a finger drags left and right is broken on a phone. With the
	# axis off, every row below must wrap (test_bug_hunt_screen_fit.gd holds that).
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "BUG HUNT — CAMPAIGN SETUP"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	# ISSUE-053: Flavor text to fill sparse layout
	var flavor := Label.new()
	flavor.text = "Military deployment in hostile territory. " \
		+ "Your squad faces waves of alien threats with limited support."
	flavor.add_theme_font_size_override("font_size", _scaled_font(14))
	flavor.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)

	# Campaign Name
	var name_card := _create_card("Campaign Name", vbox)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tap here to name your campaign..."
	_name_edit.add_theme_color_override("font_color", COLOR_TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(COLOR_TEXT_SEC, 0.5))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = COLOR_INPUT
	input_style.border_color = COLOR_BORDER
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(12)
	_name_edit.add_theme_stylebox_override("normal", input_style)
	var focus_style := input_style.duplicate()
	focus_style.border_color = _UC.COLOR_FOCUS
	_name_edit.add_theme_stylebox_override("focus", focus_style)
	_name_edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	_name_edit.text_changed.connect(_on_name_changed)
	name_card.add_child(_name_edit)

	_validation_label = Label.new()
	_validation_label.text = ""
	_validation_label.add_theme_color_override("font_color", COLOR_DANGER)
	_validation_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_validation_label.visible = false
	name_card.add_child(_validation_label)

	# Regiment Name
	var regiment_card := _create_card("Regiment", vbox)
	_regiment_label = Label.new()
	_regiment_label.text = "Not yet generated"
	_regiment_label.add_theme_color_override("font_color", COLOR_TEXT)
	_regiment_label.add_theme_font_size_override("font_size", _scaled_font(18))
	_regiment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regiment_card.add_child(_regiment_label)

	_color_label = Label.new()
	_color_label.text = "Uniform: —"
	_color_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_color_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regiment_card.add_child(_color_label)

	var gen_btn := Button.new()
	gen_btn.text = "Generate Regiment Name"
	gen_btn.custom_minimum_size.y = 48
	gen_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gen_btn.pressed.connect(_on_generate_regiment)
	regiment_card.add_child(gen_btn)

	# Difficulty
	var diff_card := _create_card("Mission Difficulty", vbox)
	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size.y = 48
	for i in range(DIFFICULTIES.size()):
		_difficulty_option.add_item(DIFFICULTIES[i].name, i)
	_difficulty_option.selected = 2  # Default: "Mess Me Up"
	_difficulty_option.item_selected.connect(_on_difficulty_changed)
	diff_card.add_child(_difficulty_option)

	# Campaign Escalation
	_escalation_check = CheckButton.new()
	_escalation_check.text = "Use Campaign Escalation (fixed Priority sequence)"
	_escalation_check.custom_minimum_size.y = 48  # ISSUE-046: TOUCH_TARGET_MIN
	_escalation_check.add_theme_color_override("font_color", COLOR_TEXT)
	# Wrapped: unwrapped, this one toggle demanded 420 px and set the width of the whole
	# step (verify_layout, 338 px phone).
	_escalation_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_escalation_check.toggled.connect(_on_escalation_toggled)
	diff_card.add_child(_escalation_check)

	_escalation_note = _muted("", diff_card, 12)
	_escalation_note.visible = false

	_build_coop_card(vbox)
	if _coop_preselect_pending:
		_coop_preselect_pending = false
		preselect_coop()


# ── Co-op campaign (Compendium pp.209-211) ───────────────────────────────────

func _build_coop_card(parent: VBoxContainer) -> void:
	var coop_card := _create_card("Co-op Campaign", parent)
	_coop_check = CheckButton.new()
	_coop_check.text = "Play as a co-op campaign: several players fight over one shared " \
		+ "sector map (Compendium pp.209-211)"
	_coop_check.custom_minimum_size.y = 48
	_coop_check.add_theme_color_override("font_color", COLOR_TEXT)
	_coop_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_check.toggled.connect(_on_coop_toggled)
	coop_card.add_child(_coop_check)

	_coop_body = VBoxContainer.new()
	_coop_body.add_theme_constant_override("separation", _UC.SPACING_SM)
	_coop_body.visible = false
	coop_card.add_child(_coop_body)

	var players_lbl := Label.new()
	players_lbl.text = "Players"
	players_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	players_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	_coop_body.add_child(players_lbl)

	_coop_rows_box = VBoxContainer.new()
	_coop_rows_box.add_theme_constant_override("separation", _UC.SPACING_SM)
	_coop_body.add_child(_coop_rows_box)

	var add_btn := Button.new()
	add_btn.text = "Add Player"
	add_btn.custom_minimum_size.y = 48
	add_btn.pressed.connect(_on_coop_add_player)
	_coop_body.add_child(add_btn)

	# p.210 sectors per player, the range and its wording both read from the data.
	var per_lbl := Label.new()
	per_lbl.text = "Sectors per player"
	per_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	per_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	_coop_body.add_child(per_lbl)
	_coop_per_option = OptionButton.new()
	_coop_per_option.custom_minimum_size.y = 48
	var span: Vector2i = CoopView.sectors_per_player_range()
	for n in range(span.x, span.y + 1):
		var item: String = str(n)
		if n == span.x:
			item += " (shorter campaign)"
		elif n == span.y:
			item += " (longer campaign)"
		_coop_per_option.add_item(item, n)
	_coop_per_option.item_selected.connect(_on_coop_per_selected)
	_coop_body.add_child(_coop_per_option)
	if _config_data.coop_sectors_per_player <= 0:
		_config_data.coop_sectors_per_player = span.x
	var quote: String = str((CoopView.CoopRef.rules().get("sectors_per_player", {})
		as Dictionary).get("_quote", ""))
	if not quote.is_empty():
		_muted(quote, _coop_body, 12)

	_coop_total_label = Label.new()
	_coop_total_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_total_label.add_theme_color_override("font_color", COLOR_TEXT)
	_coop_body.add_child(_coop_total_label)

	# p.209 Preparatory Steps, in the book's words: the two choices the players make
	# together before the map exists.
	_muted("Enemies (%s): %s" % [CoopView.CITE_PREP, CoopView.PREP_ENEMIES], _coop_body, 12)
	_muted("Difficulty (%s): %s The Mission Difficulty above is this campaign's one setting."
		% [CoopView.CITE_PREP, CoopView.PREP_DIFFICULTY], _coop_body, 12)

	_coop_error_label = Label.new()
	_coop_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_error_label.add_theme_color_override("font_color", COLOR_DANGER)
	_coop_error_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_coop_error_label.visible = false
	_coop_body.add_child(_coop_error_label)


## Turn co-op on from outside (the main menu's "Bug Hunt Co-op Campaign" choice). Safe to
## call before the panel has built: it is applied at the end of _build_ui().
func preselect_coop() -> void:
	if _coop_check == null:
		_coop_preselect_pending = true
		return
	if not _coop_check.button_pressed:
		_coop_check.button_pressed = true  # emits toggled -> _on_coop_toggled


func _on_coop_toggled(pressed: bool) -> void:
	_config_data.coop_enabled = pressed
	_coop_body.visible = pressed
	if pressed and (_config_data.coop_players as Array).is_empty():
		_config_data.coop_players = ["", ""]
	# p.211: "Set up the mission as normal, using the Priority level from the sector
	# map." The co-op map supplies every mission's Priority, so the p.187 escalation
	# sequence -- which also replaces the Priority roll -- cannot apply alongside it.
	if pressed:
		_escalation_check.set_pressed_no_signal(false)
		_config_data.use_campaign_escalation = false
		_escalation_note.text = "Not used in a co-op campaign: each mission's Priority " \
			+ "comes from the sector map (Compendium p.211)."
	_escalation_check.disabled = pressed
	_escalation_note.visible = pressed
	_rebuild_coop_rows()
	_emit_update()


func _rebuild_coop_rows() -> void:
	for child in _coop_rows_box.get_children():
		child.queue_free()
	var names: Array = _config_data.coop_players
	for i in names.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", _UC.SPACING_SM)
		var edit := LineEdit.new()
		edit.text = str(names[i])
		edit.placeholder_text = "Player %d" % (i + 1)
		edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_color_override("font_color", COLOR_TEXT)
		edit.text_changed.connect(_on_coop_name_changed.bind(i))
		row.add_child(edit)
		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(0, 48)
		remove_btn.disabled = names.size() <= 1
		remove_btn.pressed.connect(_on_coop_remove_player.bind(i))
		row.add_child(remove_btn)
		_coop_rows_box.add_child(row)
	_refresh_coop_status()
	# Rows arrive after the wizard's own sweep, so they open themselves.
	TouchScrollOpenerRef.open_subtree(_coop_body)


func _on_coop_name_changed(text: String, index: int) -> void:
	var names: Array = _config_data.coop_players
	if index >= 0 and index < names.size():
		names[index] = text
	_refresh_coop_status()
	_emit_update()


func _on_coop_add_player() -> void:
	(_config_data.coop_players as Array).append("")
	_rebuild_coop_rows()
	_emit_update()


func _on_coop_remove_player(index: int) -> void:
	var names: Array = _config_data.coop_players
	if names.size() > 1 and index >= 0 and index < names.size():
		names.remove_at(index)
	_rebuild_coop_rows()
	_emit_update()


func _on_coop_per_selected(index: int) -> void:
	_config_data.coop_sectors_per_player = _coop_per_option.get_item_id(index)
	_refresh_coop_status()
	_emit_update()


func _refresh_coop_status() -> void:
	var count: int = CoopView.clean_players(_config_data.coop_players).size()
	var per: int = int(_config_data.coop_sectors_per_player)
	_coop_total_label.text = "%d player%s x %d sectors = %d sectors on the map" % [
		count, "" if count == 1 else "s", per, count * per]
	var err: String = CoopView.coop_config_error(_config_data)
	_coop_error_label.text = err
	_coop_error_label.visible = _config_data.coop_enabled and not err.is_empty()


func _muted(text: String, parent: Control, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.add_theme_font_size_override("font_size", _scaled_font(size))
	parent.add_child(lbl)
	return lbl


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	## Glass morphism card matching CampaignScreenBase pattern.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_LG)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", _UC.SPACING_SM)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text.to_upper()
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	return vbox


func _on_name_changed(new_name: String) -> void:
	_config_data.campaign_name = new_name
	if new_name.strip_edges().is_empty():
		_validation_label.text = "Pick a name for your campaign. Anything memorable works."
		_validation_label.visible = true
	else:
		_validation_label.visible = false
	_emit_update()


func _on_generate_regiment() -> void:
	if _coordinator and _coordinator.has_method("generate_regiment_name"):
		var result: Dictionary = _coordinator.generate_regiment_name()
		_config_data.regiment_name = result.get("full_name", "Unknown Regiment")
		_config_data.uniform_color = result.get("uniform_color", "")
		_regiment_label.text = _config_data.regiment_name
		_color_label.text = "Uniform: " + _config_data.uniform_color
		_emit_update()


func _on_difficulty_changed(index: int) -> void:
	if index >= 0 and index < DIFFICULTIES.size():
		_config_data.difficulty = DIFFICULTIES[index].id
		_emit_update()


func _on_escalation_toggled(pressed: bool) -> void:
	_config_data.use_campaign_escalation = pressed
	_emit_update()


func _emit_update() -> void:
	# Deep: the co-op player list is an Array, and a shallow copy would hand the
	# state manager this panel's own list to hold.
	config_updated.emit(_config_data.duplicate(true))
