# Campaign Dashboard — comprehensive at-a-glance campaign overview
# Extends CampaignScreenBase for shared deep-space theming + responsive layout
extends CampaignScreenBase

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const CampaignTimelinePanelClass = preload("res://src/ui/components/history/CampaignTimelinePanel.gd")
const CharacterHistoryPanelClass = preload("res://src/ui/components/history/CharacterHistoryPanel.gd")

# ── Node References (unique names from .tscn) ─────────────────────
# Header
@onready var campaign_name_label: Label = %CampaignNameLabel
@onready var phase_label: Label = %PhaseLabel
@onready var credits_label: Label = %CreditsLabel
@onready var story_points_label: Label = %StoryPointsLabel

# Three columns
@onready var left_column: PanelContainer = %LeftColumn
@onready var crew_vbox: VBoxContainer = %CrewVBox
@onready var center_column: PanelContainer = %CenterColumn
@onready var center_vbox: VBoxContainer = %CenterVBox
@onready var right_column: PanelContainer = %RightColumn
@onready var right_vbox: VBoxContainer = %RightVBox

# Progress
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_hbox: HBoxContainer = %ProgressHBox

# Buttons
@onready var action_button: Button = %ActionButton
@onready var manage_crew_button: Button = %ManageCrewButton
@onready var save_button: Button = %SaveButton
@onready var export_button: Button = %ExportButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton

# Header panel ref
@onready var header_panel: PanelContainer = %HeaderPanel

var phase_manager: Node
var _active_dialogs: Array[Node] = []
var _history_overlay: Control = null
var _active_history_panel: Control = null

# ── Lifecycle ──────────────────────────────────────────────────────

func _setup_screen() -> void:
	phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	_connect_signals()
	if phase_manager:
		_setup_phase_manager()
	_apply_dashboard_styles()
	_update_all()
	_create_history_overlay()

func _exit_tree() -> void:
	# Disconnect autoload signals to prevent memory leaks
	if phase_manager:
		if phase_manager.has_signal("phase_changed") and phase_manager.phase_changed.is_connected(_on_phase_changed):
			phase_manager.phase_changed.disconnect(_on_phase_changed)
		if phase_manager.has_signal("phase_completed") and phase_manager.phase_completed.is_connected(_on_phase_completed):
			phase_manager.phase_completed.disconnect(_on_phase_completed)
		if phase_manager.has_signal("phase_event_triggered") and phase_manager.phase_event_triggered.is_connected(_on_phase_event):
			phase_manager.phase_event_triggered.disconnect(_on_phase_event)
	_cleanup_dialogs()
	super._exit_tree()

# ── Signal wiring ──────────────────────────────────────────────────

func _connect_signals() -> void:
	if phase_manager:
		if phase_manager.has_signal("phase_changed"):
			phase_manager.phase_changed.connect(_on_phase_changed)
		if phase_manager.has_signal("phase_completed"):
			phase_manager.phase_completed.connect(_on_phase_completed)
		if phase_manager.has_signal("phase_event_triggered"):
			phase_manager.phase_event_triggered.connect(
				_on_phase_event
			)
	if action_button:
		action_button.pressed.connect(_on_action_pressed)
	if manage_crew_button:
		manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if export_button:
		export_button.pressed.connect(_on_export_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _setup_phase_manager() -> void:
	if phase_manager.has_method("setup"):
		phase_manager.setup(_game_state)
	var FPC = GameEnums.FiveParcsecsCampaignPhase
	phase_manager.start_phase(FPC.SETUP)
	phase_manager.start_phase(FPC.UPKEEP)

# ── Styling ────────────────────────────────────────────────────────

func _apply_dashboard_styles() -> void:
	# Style the three column panels
	for panel in [left_column, center_column, right_column]:
		if panel:
			_apply_panel_style(panel, "glass")
	if header_panel:
		_apply_panel_style(header_panel, "glass_elevated")
	if progress_panel:
		_apply_panel_style(progress_panel, "compact")
	# Style buttons
	for btn in [
		save_button, export_button, load_button,
		manage_crew_button, quit_button
	]:
		if btn:
			_style_button(btn)
	if action_button:
		_style_button(action_button, true)

# ── Master update ──────────────────────────────────────────────────

func _update_all() -> void:
	var campaign = _get_campaign()
	if not campaign:
		_show_empty_state()
		return

	_update_header(campaign)
	_update_crew_manifest(campaign)
	_update_ship_and_equipment(campaign)
	_update_intel_overview(campaign)
	_update_progress_strip(campaign)

func _show_empty_state() -> void:
	if campaign_name_label:
		campaign_name_label.text = "No Campaign Loaded"
	if phase_label:
		phase_label.text = ""
	if credits_label:
		credits_label.text = ""
	if story_points_label:
		story_points_label.text = ""

# ── Header ─────────────────────────────────────────────────────────

func _update_header(campaign) -> void:
	if campaign_name_label:
		campaign_name_label.text = campaign.campaign_name \
			if not campaign.campaign_name.is_empty() \
			else "Unnamed Campaign"
	if phase_label:
		var phase_text: String = campaign.game_phase \
			if "game_phase" in campaign else "—"
		var pd: Dictionary = campaign.progress_data \
			if "progress_data" in campaign else {}
		var turn: int = pd.get("turns_played", 0) + 1
		phase_label.text = "Turn %d — %s" \
			% [turn, phase_text.capitalize()]
		phase_label.add_theme_color_override(
			"font_color", COLOR_CYAN
		)
	if credits_label:
		credits_label.text = "Credits: %d" % campaign.credits
		var cc: Color = COLOR_AMBER if campaign.credits < 5 \
			else COLOR_EMERALD
		credits_label.add_theme_color_override("font_color", cc)
	if story_points_label:
		story_points_label.text = "SP: %d" % campaign.story_points
		story_points_label.add_theme_color_override(
			"font_color", COLOR_BLUE
		)

# ── Left Column: Crew Manifest ─────────────────────────────────────

func _update_crew_manifest(campaign) -> void:
	if not crew_vbox:
		return
	# Clear existing
	for child in crew_vbox.get_children():
		child.queue_free()

	# Section header
	var header := _create_section_header("CREW MANIFEST")
	crew_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	crew_vbox.add_child(sep)

	var members: Array = _get_crew_members(campaign)
	if members.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No crew members"
		empty_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		crew_vbox.add_child(empty_lbl)
		return

	for member in members:
		var card := _build_crew_card(member)
		crew_vbox.add_child(card)

func _get_crew_members(campaign) -> Array:
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if campaign.has_method("get_active_crew_members"):
		return campaign.get_active_crew_members()
	if "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []

func _build_crew_card(member) -> PanelContainer:
	var is_dict := member is Dictionary
	var char_name: String
	var species: String
	var char_class: String
	var is_captain: bool
	var stats: Dictionary

	if is_dict:
		char_name = member.get(
			"character_name", member.get("name", "Unknown")
		)
		species = member.get("species", "Unknown")
		char_class = member.get("class", "Unknown")
		is_captain = member.get("is_captain", false)
		stats = {
			"C": member.get("combat", 0),
			"R": member.get("reaction", 0),
			"T": member.get("toughness", 0),
			"S": member.get("speed", 0),
			"Sv": member.get("savvy", 0),
			"L": member.get("luck", 0),
		}
	else:
		char_name = member.character_name \
			if "character_name" in member else str(member)
		species = member.species \
			if "species" in member else "Unknown"
		char_class = str(member.character_class) \
			if "character_class" in member else "Unknown"
		is_captain = member.is_captain \
			if "is_captain" in member else false
		stats = {
			"C": member.combat if "combat" in member else 0,
			"R": member.reaction if "reaction" in member else 0,
			"T": member.toughness if "toughness" in member else 0,
			"S": member.speed if "speed" in member else 0,
			"Sv": member.savvy if "savvy" in member else 0,
			"L": member.luck if "luck" in member else 0,
		}

	# Build card
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: String = "accent_amber" if is_captain \
		else "elevated"
	_apply_panel_style(panel, card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", SPACING_SM)
	if is_captain:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		star.add_theme_color_override("font_color", COLOR_AMBER)
		name_row.add_child(star)
	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY
	)
	name_row.add_child(name_lbl)
	vbox.add_child(name_row)

	# Subtitle
	var sub := Label.new()
	sub.text = "%s / %s" % [species, char_class]
	sub.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	sub.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(sub)

	# Stat line
	var stat_parts: Array[String] = []
	for key in stats:
		stat_parts.append("%s:%d" % [key, stats[key]])
	var stat_lbl := Label.new()
	stat_lbl.text = "  ".join(stat_parts)
	stat_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	stat_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(stat_lbl)

	panel.add_child(vbox)
	return panel

# ── Center Column: Ship + Equipment ────────────────────────────────

func _update_ship_and_equipment(campaign) -> void:
	if not center_vbox:
		return
	for child in center_vbox.get_children():
		child.queue_free()

	_build_ship_section(campaign)
	_build_equipment_section(campaign)

func _build_ship_section(campaign) -> void:
	var header := _create_section_header("SHIP")
	center_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	center_vbox.add_child(sep)

	var sd: Dictionary = campaign.ship_data \
		if "ship_data" in campaign else {}
	if sd.is_empty():
		var empty := Label.new()
		empty.text = "No ship data"
		empty.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		center_vbox.add_child(empty)
		return

	# Ship name + type
	var ship_name: String = sd.get("name", "Unknown Ship")
	var ship_type: String = sd.get("type", "Unknown")
	center_vbox.add_child(
		_create_info_row("Ship", "%s (%s)" % [ship_name, ship_type])
	)

	# Hull bar
	var hull: int = sd.get("hull", 0)
	var hull_max: int = sd.get("hull_max", hull)
	if hull_max > 0:
		var hull_row := VBoxContainer.new()
		hull_row.add_theme_constant_override(
			"separation", SPACING_XS
		)
		var hull_label := Label.new()
		hull_label.text = "Hull: %d / %d" % [hull, hull_max]
		hull_label.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM
		)
		hull_label.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY
		)
		hull_row.add_child(hull_label)
		var bar := ProgressBar.new()
		bar.max_value = hull_max
		bar.value = hull
		bar.custom_minimum_size = Vector2(0, 16)
		bar.show_percentage = false
		# Color-code the bar
		var pct: float = float(hull) / float(hull_max)
		var bar_style := StyleBoxFlat.new()
		if pct > 0.5:
			bar_style.bg_color = COLOR_EMERALD
		elif pct > 0.25:
			bar_style.bg_color = COLOR_AMBER
		else:
			bar_style.bg_color = COLOR_RED
		bar_style.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", bar_style)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(COLOR_PRIMARY.r, COLOR_PRIMARY.g,
			COLOR_PRIMARY.b, 0.8)
		bg_style.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg_style)
		hull_row.add_child(bar)
		center_vbox.add_child(hull_row)

	# Fuel / Cargo
	center_vbox.add_child(
		_create_info_row(
			"Fuel", str(sd.get("fuel", "—"))
		)
	)
	var cargo_cap: int = sd.get("cargo_capacity", 0)
	if cargo_cap > 0:
		center_vbox.add_child(
			_create_info_row("Cargo", "0 / %d" % cargo_cap)
		)

	# Ship weapons
	var ship_weapons: Array = sd.get("weapons", [])
	if not ship_weapons.is_empty():
		center_vbox.add_child(
			_create_info_row(
				"Weapons", ", ".join(ship_weapons)
			)
		)

func _build_equipment_section(campaign) -> void:
	var eq_sep := HSeparator.new()
	eq_sep.modulate = COLOR_BORDER
	center_vbox.add_child(eq_sep)

	var header := _create_section_header("EQUIPMENT")
	center_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	center_vbox.add_child(sep)

	var ed: Dictionary = campaign.equipment_data \
		if "equipment_data" in campaign else {}
	if ed.is_empty():
		var empty := Label.new()
		empty.text = "No equipment data"
		empty.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		center_vbox.add_child(empty)
		return

	# Weapons list
	var weapons: Array = ed.get("weapons", [])
	if not weapons.is_empty():
		center_vbox.add_child(
			_create_info_row(
				"Weapons",
				str(weapons.size()),
				COLOR_RED
			)
		)
		for w in weapons:
			if w is Dictionary:
				var name_str: String = w.get("name", "Unknown")
				var wtype: String = w.get("type", "")
				var detail := "  %s" % name_str
				if not wtype.is_empty():
					detail += " (%s)" % wtype
				var item_lbl := Label.new()
				item_lbl.text = detail
				item_lbl.add_theme_font_size_override(
					"font_size", FONT_SIZE_XS
				)
				item_lbl.add_theme_color_override(
					"font_color", COLOR_TEXT_SECONDARY
				)
				center_vbox.add_child(item_lbl)

	# Armor
	var armor: Array = ed.get("armor", [])
	if not armor.is_empty():
		center_vbox.add_child(
			_create_info_row(
				"Armor",
				str(armor.size()),
				COLOR_BLUE
			)
		)
		for a in armor:
			if a is Dictionary:
				var item_lbl := Label.new()
				item_lbl.text = "  %s" % a.get("name", "Unknown")
				item_lbl.add_theme_font_size_override(
					"font_size", FONT_SIZE_XS
				)
				item_lbl.add_theme_color_override(
					"font_color", COLOR_TEXT_SECONDARY
				)
				center_vbox.add_child(item_lbl)

	# Gear
	var gear: Array = ed.get("gear", [])
	if not gear.is_empty():
		center_vbox.add_child(
			_create_info_row(
				"Gear",
				str(gear.size()),
				COLOR_EMERALD
			)
		)
		for g in gear:
			if g is Dictionary:
				var item_lbl := Label.new()
				item_lbl.text = "  %s" % g.get("name", "Unknown")
				item_lbl.add_theme_font_size_override(
					"font_size", FONT_SIZE_XS
				)
				item_lbl.add_theme_color_override(
					"font_color", COLOR_TEXT_SECONDARY
				)
				center_vbox.add_child(item_lbl)

# ── Right Column: Intel Overview ───────────────────────────────────

func _update_intel_overview(campaign) -> void:
	if not right_vbox:
		return
	for child in right_vbox.get_children():
		child.queue_free()

	_build_world_section(campaign)
	_build_patrons_section(campaign)
	_build_rivals_section(campaign)
	_build_rumors_section(campaign)
	_build_phase_checklist()
	_build_history_buttons()

func _build_world_section(campaign) -> void:
	var header := _create_section_header("CURRENT WORLD")
	right_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	right_vbox.add_child(sep)

	var wd: Dictionary = campaign.world_data \
		if "world_data" in campaign else {}
	if wd.is_empty():
		var empty := Label.new()
		empty.text = "No world data"
		empty.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		right_vbox.add_child(empty)
		return

	right_vbox.add_child(
		_create_info_row("Name", wd.get("name", "Unknown"))
	)
	right_vbox.add_child(
		_create_info_row("Type", wd.get("type", "Unknown"))
	)

	# Traits
	var traits: Array = wd.get("traits", [])
	if not traits.is_empty():
		right_vbox.add_child(
			_create_info_row(
				"Traits", ", ".join(traits), COLOR_PURPLE
			)
		)

	# Danger level
	var danger: int = wd.get("danger_level", 0)
	if danger > 0:
		var danger_dots := ""
		for i in range(danger):
			danger_dots += "●"
		for i in range(5 - danger):
			danger_dots += "○"
		var dcolor: Color = COLOR_EMERALD
		if danger >= 4:
			dcolor = COLOR_RED
		elif danger >= 2:
			dcolor = COLOR_AMBER
		right_vbox.add_child(
			_create_info_row("Danger", danger_dots, dcolor)
		)

func _build_patrons_section(campaign) -> void:
	var p_sep := HSeparator.new()
	p_sep.modulate = COLOR_BORDER
	right_vbox.add_child(p_sep)

	var patrons_arr: Array = campaign.patrons \
		if "patrons" in campaign else []
	var header := _create_section_header(
		"PATRONS (%d)" % patrons_arr.size()
	)
	right_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	right_vbox.add_child(sep)

	if patrons_arr.is_empty():
		var empty := Label.new()
		empty.text = "No patrons"
		empty.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		right_vbox.add_child(empty)
		return

	for patron in patrons_arr:
		if patron is Dictionary:
			var p_name: String = patron.get("name", "Unknown")
			var p_type: String = patron.get("type", "")
			var missions: int = patron.get(
				"missions_completed", 0
			)
			var row := _create_info_row(
				p_name,
				"%s (missions: %d)" % [p_type, missions],
				COLOR_EMERALD
			)
			right_vbox.add_child(row)

func _build_rivals_section(campaign) -> void:
	var r_sep := HSeparator.new()
	r_sep.modulate = COLOR_BORDER
	right_vbox.add_child(r_sep)

	var rivals_arr: Array = campaign.rivals \
		if "rivals" in campaign else []
	var header := _create_section_header(
		"RIVALS (%d)" % rivals_arr.size()
	)
	right_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	right_vbox.add_child(sep)

	if rivals_arr.is_empty():
		var empty := Label.new()
		empty.text = "No rivals"
		empty.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED
		)
		right_vbox.add_child(empty)
		return

	for rival in rivals_arr:
		if rival is Dictionary:
			var r_name: String = rival.get("name", "Unknown")
			var r_type: String = rival.get("type", "")
			var panel := PanelContainer.new()
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_panel_style(panel, "accent_red")
			var row := _create_info_row(
				r_name, r_type, COLOR_RED
			)
			panel.add_child(row)
			right_vbox.add_child(panel)

func _build_rumors_section(campaign) -> void:
	var q_sep := HSeparator.new()
	q_sep.modulate = COLOR_BORDER
	right_vbox.add_child(q_sep)

	var rumors: int = campaign.quest_rumors \
		if "quest_rumors" in campaign else 0
	right_vbox.add_child(
		_create_info_row(
			"Quest Rumors", str(rumors), COLOR_PURPLE
		)
	)

# ── Progress Strip ─────────────────────────────────────────────────

func _update_progress_strip(campaign) -> void:
	if not progress_hbox:
		return
	for child in progress_hbox.get_children():
		child.queue_free()

	var pd: Dictionary = campaign.progress_data \
		if "progress_data" in campaign else {}

	# Turns played
	var turns: int = pd.get("turns_played", 0)
	progress_hbox.add_child(
		_create_progress_stat("Turns", str(turns))
	)

	# Battles
	var won: int = pd.get("battles_won", 0)
	var lost: int = pd.get("battles_lost", 0)
	progress_hbox.add_child(
		_create_progress_stat(
			"Battles", "%dW / %dL" % [won, lost]
		)
	)

	# Victory condition
	var vc: Dictionary = campaign.victory_conditions \
		if "victory_conditions" in campaign else {}
	if not vc.is_empty():
		var vc_type: String = vc.get("type", "")
		var vc_target: int = vc.get("target", 0)
		if not vc_type.is_empty() and vc_target > 0:
			var progress_val: int = turns if vc_type == "turns" \
				else won
			progress_hbox.add_child(
				_create_progress_stat(
					"Victory",
					"%d / %d (%s)" % [
						progress_val, vc_target, vc_type
					]
				)
			)

	# Difficulty
	var diff_names := {0: "Easy", 1: "Normal", 2: "Hard", 3: "Insanity"}
	var diff_name: String = diff_names.get(
		campaign.difficulty, "Normal"
	)
	progress_hbox.add_child(
		_create_progress_stat("Difficulty", diff_name)
	)

func _create_progress_stat(
	label: String, value: String
) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_XS)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY
	)
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	val.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(val)
	return hbox

# ── Phase callbacks ────────────────────────────────────────────────

func _on_phase_changed(_old_phase, new_phase) -> void:
	_update_phase_ui(new_phase)

func _on_phase_completed() -> void:
	if action_button:
		action_button.disabled = false

func _on_phase_event(_event: Dictionary) -> void:
	_update_all()

func _update_phase_ui(phase) -> void:
	var FPC = GameEnums.FiveParcsecsCampaignPhase
	var phase_names = GameEnums.PHASE_NAMES
	var phase_name: String = phase_names.get(phase, "Unknown")
	if phase_label:
		var campaign = _get_campaign()
		var turn: int = 1
		if campaign:
			var pd: Dictionary = campaign.progress_data \
				if "progress_data" in campaign else {}
			turn = pd.get("turns_played", 0) + 1
		phase_label.text = "Turn %d — %s" % [turn, phase_name]
	if action_button:
		var nxt = _get_next_phase(phase)
		var next_name: String = phase_names.get(nxt, "Unknown")
		action_button.text = "Next: " + next_name

func _get_next_phase(current) -> int:
	var FPC = GameEnums.FiveParcsecsCampaignPhase
	match current:
		FPC.SETUP: return FPC.UPKEEP
		FPC.UPKEEP: return FPC.STORY
		FPC.STORY: return FPC.TRAVEL
		FPC.TRAVEL: return FPC.PRE_MISSION
		FPC.PRE_MISSION: return FPC.MISSION
		FPC.MISSION: return FPC.BATTLE_SETUP
		FPC.BATTLE_SETUP: return FPC.BATTLE_RESOLUTION
		FPC.BATTLE_RESOLUTION: return FPC.POST_MISSION
		FPC.POST_MISSION: return FPC.ADVANCEMENT
		FPC.ADVANCEMENT: return FPC.TRADING
		FPC.TRADING: return FPC.CHARACTER
		FPC.CHARACTER: return FPC.RETIREMENT
		FPC.RETIREMENT: return FPC.UPKEEP
		_: return FPC.NONE

# ── Button handlers ────────────────────────────────────────────────

func _on_action_pressed() -> void:
	if not phase_manager:
		return
	var next_phase = _get_next_phase(
		phase_manager.current_phase
	)
	var FPC = GameEnums.FiveParcsecsCampaignPhase
	if next_phase != FPC.NONE:
		var success: bool = phase_manager.start_phase(next_phase)
		if success:
			_update_phase_ui(next_phase)
		else:
			_show_message("Cannot advance to next phase.")

func _on_manage_crew_pressed() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("crew_management")
	else:
		get_tree().change_scene_to_file(
			"res://src/ui/screens/crew/CrewManagement.tscn"
		)

func _on_save_pressed() -> void:
	if not _game_state or not _game_state.has_method("save_campaign"):
		_show_message("Save system not available.")
		return
	var result: Dictionary = _game_state.save_campaign()
	if result.get("success", false):
		_show_message("Campaign saved successfully.")
	else:
		_show_message(
			"Save failed: %s" % result.get(
				"message", "Unknown error"
			)
		)

func _on_export_pressed() -> void:
	if not _game_state:
		_show_message("Game state not available.")
		return
	var campaign = _get_campaign()
	if not campaign:
		_show_message("No active campaign to export.")
		return
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(
		["*.save ; Campaign Save Files"]
	)
	file_dialog.title = "Export Campaign Save"
	file_dialog.size = Vector2i(800, 500)
	var cname: String = ""
	if campaign.has_method("get_campaign_id"):
		cname = campaign.get_campaign_id()
	elif "campaign_name" in campaign:
		cname = campaign.campaign_name.to_lower().replace(
			" ", "_"
		)
	if cname.is_empty():
		cname = "campaign"
	file_dialog.current_file = cname + ".save"
	file_dialog.file_selected.connect(
		_on_export_file_selected.bind(file_dialog)
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	)
	add_child(file_dialog)
	_active_dialogs.append(file_dialog)
	file_dialog.popup_centered()

func _on_export_file_selected(
	path: String, file_dialog: Node
) -> void:
	if is_instance_valid(file_dialog):
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	if not _game_state:
		_show_message("Game state not available.")
		return
	var campaign = _get_campaign()
	if not campaign or not campaign.has_method("save_to_file"):
		_show_message("Cannot export: no active campaign.")
		return
	var err = campaign.save_to_file(path)
	if err == OK:
		_show_message("Campaign exported to:\n%s" % path)
	else:
		_show_message("Export failed (error %d)" % err)

func _on_load_pressed() -> void:
	if not _game_state:
		_show_message("Game state not available.")
		return
	var campaigns: Array = _game_state.get_available_campaigns()
	var dialog := AcceptDialog.new()
	dialog.title = "Load Campaign"
	dialog.ok_button_text = "Cancel"
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 0)
	for info in campaigns:
		var btn := Button.new()
		btn.text = "%s  (%s)" % [
			info.get("name", "Unnamed"),
			info.get("date_string", "")
		]
		var p: String = info.get("path", "")
		btn.pressed.connect(
			_load_campaign_from_dialog.bind(p, dialog)
		)
		vbox.add_child(btn)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var import_btn := Button.new()
	import_btn.text = "Import from File..."
	import_btn.pressed.connect(
		_on_import_from_file.bind(dialog)
	)
	vbox.add_child(import_btn)
	dialog.add_child(vbox)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()

func _on_import_from_file(load_dialog: Node) -> void:
	if is_instance_valid(load_dialog):
		load_dialog.hide()
		load_dialog.queue_free()
		_active_dialogs.erase(load_dialog)
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(
		["*.save ; Campaign Save Files", "*.json ; JSON Files"]
	)
	file_dialog.title = "Import Campaign File"
	file_dialog.size = Vector2i(800, 500)
	file_dialog.file_selected.connect(
		_on_import_file_selected.bind(file_dialog)
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	)
	add_child(file_dialog)
	_active_dialogs.append(file_dialog)
	file_dialog.popup_centered()

func _on_import_file_selected(
	path: String, file_dialog: Node
) -> void:
	if is_instance_valid(file_dialog):
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	if not _game_state:
		_show_message("Game state not available.")
		return
	if _game_state.has_method("import_campaign"):
		var result: Dictionary = _game_state.import_campaign(path)
		if result.get("success", false):
			_show_message("Imported: %s" % result.get("message", ""))
			_update_all()
		else:
			_show_message(
				"Import failed: %s" % result.get(
					"message", "Unknown error"
				)
			)
	else:
		var result: Dictionary = _game_state.load_campaign(path)
		if result.get("success", false):
			_show_message("Loaded: %s" % result.get("message", ""))
			_update_all()
		else:
			_show_message(
				"Load failed: %s" % result.get(
					"message", "Unknown error"
				)
			)

func _load_campaign_from_dialog(
	path: String, dialog: Node
) -> void:
	if is_instance_valid(dialog):
		dialog.hide()
		dialog.queue_free()
		_active_dialogs.erase(dialog)
	if not _game_state or not _game_state.has_method("load_campaign"):
		_show_message("Load system not available.")
		return
	var result: Dictionary = _game_state.load_campaign(path)
	if result.get("success", false):
		_show_message("Loaded: %s" % result.get("message", ""))
		_update_all()
	else:
		_show_message(
			"Load failed: %s" % result.get(
				"message", "Unknown error"
			)
		)

func _on_quit_pressed() -> void:
	if _game_state and _game_state.has_method("end_campaign"):
		_game_state.end_campaign()
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("main_menu")
	else:
		get_tree().change_scene_to_file(
			"res://src/ui/screens/mainmenu/MainMenu.tscn"
		)

# ── Helpers ────────────────────────────────────────────────────────

func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	if is_instance_valid(dialog):
		dialog.queue_free()
	_active_dialogs.erase(dialog)

func _cleanup_dialogs() -> void:
	for dialog in _active_dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()
	_active_dialogs.clear()

# ── History Overlay System ────────────────────────────────────────

func _create_history_overlay() -> void:
	_history_overlay = Control.new()
	_history_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_overlay.visible = false
	_history_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_history_overlay)
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(COLOR_PRIMARY.r, COLOR_PRIMARY.g, COLOR_PRIMARY.b, 0.95)
	_history_overlay.add_child(bg)

func _show_history_panel(panel: Control) -> void:
	if _active_history_panel and is_instance_valid(_active_history_panel):
		_active_history_panel.queue_free()
	_active_history_panel = panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_overlay.add_child(panel)
	_history_overlay.visible = true

func _hide_history_overlay() -> void:
	_history_overlay.visible = false
	if _active_history_panel and is_instance_valid(_active_history_panel):
		_active_history_panel.queue_free()
		_active_history_panel = null

func _build_phase_checklist() -> void:
	if not right_vbox:
		return
	var checklist = get_node_or_null("/root/TurnPhaseChecklist")
	if not checklist:
		return
	var status: Dictionary = checklist.get_completion_status() \
		if checklist.has_method("get_completion_status") else {}
	if status.is_empty():
		return

	var req_total: int = status.get("required_total", 0)
	var req_done: int = status.get("required_complete", 0)
	if req_total == 0:
		return

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	right_vbox.add_child(sep)

	var header := _create_section_header("PHASE CHECKLIST")
	right_vbox.add_child(header)

	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = req_total
	progress.value = req_done
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	right_vbox.add_child(progress)

	var pct_label := Label.new()
	pct_label.text = "%d / %d required actions complete" % [req_done, req_total]
	pct_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	pct_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	right_vbox.add_child(pct_label)

	var incomplete: Array = checklist.get_incomplete_required_actions() \
		if checklist.has_method("get_incomplete_required_actions") else []
	for action_id in incomplete:
		var desc: String = checklist.get_action_description(action_id) \
			if checklist.has_method("get_action_description") else action_id
		var item := Label.new()
		item.text = "  - %s" % desc
		item.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		item.add_theme_color_override("font_color", COLOR_AMBER)
		right_vbox.add_child(item)

func _build_history_buttons() -> void:
	if not right_vbox:
		return
	var h_sep := HSeparator.new()
	h_sep.modulate = COLOR_BORDER
	right_vbox.add_child(h_sep)
	var header := _create_section_header("CAMPAIGN HISTORY")
	right_vbox.add_child(header)
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	right_vbox.add_child(sep)
	# Journal button
	var journal_btn := Button.new()
	journal_btn.text = "Campaign Journal"
	journal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	journal_btn.pressed.connect(_on_journal_pressed)
	right_vbox.add_child(journal_btn)
	_style_button(journal_btn, true)
	# Contacts button
	var contacts_btn := Button.new()
	contacts_btn.text = "Contacts & Rivals"
	contacts_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contacts_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	contacts_btn.pressed.connect(_on_contacts_pressed)
	right_vbox.add_child(contacts_btn)
	_style_button(contacts_btn)
	# Hall of Fame button
	var hof_btn := Button.new()
	hof_btn.text = "Hall of Fame"
	hof_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hof_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	hof_btn.pressed.connect(_on_hof_pressed)
	right_vbox.add_child(hof_btn)
	_style_button(hof_btn)

func _on_journal_pressed() -> void:
	var panel := CampaignTimelinePanelClass.new()
	panel.back_pressed.connect(_hide_history_overlay)
	panel.character_selected.connect(_on_timeline_character_selected)
	_show_history_panel(panel)

func _on_contacts_pressed() -> void:
	var panel := _build_contacts_panel()
	_show_history_panel(panel)

func _on_hof_pressed() -> void:
	var panel := _build_hof_panel()
	_show_history_panel(panel)

func _on_timeline_character_selected(character_id: String) -> void:
	var campaign = _get_campaign()
	if not campaign:
		return
	var members: Array = _get_crew_members(campaign)
	for member in members:
		var mid: String = ""
		if member is Dictionary:
			mid = member.get("character_id", member.get("id", ""))
		elif "character_id" in member:
			mid = member.character_id
		if mid == character_id:
			_hide_history_overlay()
			var history_panel := CharacterHistoryPanelClass.new()
			history_panel.setup(member, character_id)
			history_panel.back_pressed.connect(_hide_history_overlay)
			_show_history_panel(history_panel)
			return

func _build_contacts_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PRIMARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XL)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_MD)
	scroll.add_child(vbox)
	# Header with back button
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(header_hbox)
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.pressed.connect(_hide_history_overlay)
	header_hbox.add_child(back_btn)
	var title := Label.new()
	title.text = "Contacts & Rivals"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	# Load NPC data
	var npc_tracker := get_node_or_null("/root/NPCTracker")
	if not npc_tracker:
		var empty := Label.new()
		empty.text = "NPC Tracker not available"
		empty.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty)
		return panel
	# Patrons section
	vbox.add_child(_create_section_header("PATRONS"))
	var p_sep := HSeparator.new()
	p_sep.modulate = COLOR_BORDER
	vbox.add_child(p_sep)
	var patrons: Array = npc_tracker.get_all_patrons()
	# Fall back to campaign data if NPCTracker has no entries
	if patrons.is_empty():
		var campaign = _get_campaign()
		if campaign and "patrons" in campaign:
			patrons = campaign.patrons if campaign.patrons is Array else []
	if patrons.is_empty():
		var empty := Label.new()
		empty.text = "No patrons yet"
		empty.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty)
	else:
		for patron in patrons:
			vbox.add_child(_create_npc_contact_card(patron, "patron"))
	# Rivals section
	var r_sep := HSeparator.new()
	r_sep.modulate = COLOR_BORDER
	vbox.add_child(r_sep)
	vbox.add_child(_create_section_header("RIVALS"))
	var r_sep2 := HSeparator.new()
	r_sep2.modulate = COLOR_BORDER
	vbox.add_child(r_sep2)
	var rivals: Array = npc_tracker.get_all_rivals()
	# Fall back to campaign data if NPCTracker has no entries
	if rivals.is_empty():
		var campaign_r = _get_campaign()
		if campaign_r and "rivals" in campaign_r:
			rivals = campaign_r.rivals if campaign_r.rivals is Array else []
	if rivals.is_empty():
		var empty := Label.new()
		empty.text = "No rivals yet"
		empty.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty)
	else:
		for rival in rivals:
			vbox.add_child(_create_npc_contact_card(rival, "rival"))
	# Locations section
	var l_sep := HSeparator.new()
	l_sep.modulate = COLOR_BORDER
	vbox.add_child(l_sep)
	vbox.add_child(_create_section_header("LOCATIONS VISITED"))
	var l_sep2 := HSeparator.new()
	l_sep2.modulate = COLOR_BORDER
	vbox.add_child(l_sep2)
	var locations: Array = npc_tracker.get_all_locations()
	if locations.is_empty():
		var empty := Label.new()
		empty.text = "No locations visited yet"
		empty.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty)
	else:
		for location in locations:
			vbox.add_child(_create_location_contact_card(location))
	return panel

func _create_npc_contact_card(npc: Dictionary, npc_type: String) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style: String = "elevated" if npc_type == "patron" else "accent_red"
	_apply_panel_style(card, card_style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	card.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = npc.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	var name_color: Color = COLOR_EMERALD if npc_type == "patron" else COLOR_RED
	name_lbl.add_theme_color_override("font_color", name_color)
	vbox.add_child(name_lbl)
	if npc_type == "patron":
		var info := Label.new()
		info.text = "Relationship: %d/5 | Jobs: %d completed, %d failed" % [
			npc.get("relationship", 0),
			npc.get("jobs_completed", 0),
			npc.get("jobs_failed", 0)
		]
		info.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		vbox.add_child(info)
	else:
		var info := Label.new()
		info.text = "Encounters: %d (W:%d L:%d)" % [
			npc.get("encounters", 0),
			npc.get("victories", 0),
			npc.get("defeats", 0)
		]
		info.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		vbox.add_child(info)
	var history: Array = npc.get("history", [])
	if not history.is_empty():
		for entry in history:
			var entry_lbl := Label.new()
			var turn_str: String = str(entry.get("turn", "?"))
			var event_str: String = str(entry.get("event", entry.get("result", "")))
			entry_lbl.text = "  Turn %s: %s" % [turn_str, event_str]
			entry_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			entry_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
			vbox.add_child(entry_lbl)
	return card

func _create_location_contact_card(location: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	_apply_panel_style(card, "elevated")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	card.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = location.get("name", "Unknown Location")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_PURPLE)
	vbox.add_child(name_lbl)
	var info := Label.new()
	info.text = "Visits: %d | Reputation: %d" % [
		location.get("visits", 0),
		location.get("reputation", 0)
	]
	info.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(info)
	var npcs_met: Array = location.get("npcs_met", [])
	if not npcs_met.is_empty():
		var npcs_lbl := Label.new()
		npcs_lbl.text = "Contacts: " + ", ".join(npcs_met)
		npcs_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		npcs_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(npcs_lbl)
	return card

func _build_hof_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PRIMARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XL)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_MD)
	scroll.add_child(vbox)
	# Header with back button
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(header_hbox)
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.pressed.connect(_hide_history_overlay)
	header_hbox.add_child(back_btn)
	var title := Label.new()
	title.text = "Hall of Fame"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	# Load archived campaigns
	var legacy := get_node_or_null("/root/LegacySystem")
	if not legacy:
		var empty := Label.new()
		empty.text = "Legacy System not available"
		empty.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty)
		return panel
	var archives: Array = []
	if legacy.has_method("get_hall_of_fame"):
		archives = legacy.get_hall_of_fame()
	if archives.is_empty():
		var empty := Label.new()
		empty.text = "No completed campaigns yet.\nComplete a campaign to see it immortalized here!"
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty)
	else:
		for archive in archives:
			var card := PanelContainer.new()
			_apply_panel_style(card, "accent_amber")
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var card_vbox := VBoxContainer.new()
			card_vbox.add_theme_constant_override("separation", SPACING_XS)
			card.add_child(card_vbox)
			var name_lbl := Label.new()
			name_lbl.text = archive.get("campaign_id", "Unknown Campaign")
			name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
			name_lbl.add_theme_color_override("font_color", COLOR_AMBER)
			card_vbox.add_child(name_lbl)
			var victory: bool = archive.get("victory", false)
			var status_lbl := Label.new()
			if victory:
				status_lbl.text = "VICTORY — %d Story Points" % archive.get("story_points", 0)
				status_lbl.add_theme_color_override("font_color", COLOR_EMERALD)
			else:
				status_lbl.text = "Ended — Turn %d" % archive.get("turns_survived", 0)
				status_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			status_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			card_vbox.add_child(status_lbl)
			var crew_count: int = archive.get("crew", []).size()
			var crew_lbl := Label.new()
			crew_lbl.text = "Crew: %d members" % crew_count
			crew_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			crew_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			card_vbox.add_child(crew_lbl)
			vbox.add_child(card)
	return panel

# ── Responsive overrides ──────────────────────────────────────────

func _apply_mobile_layout() -> void:
	_set_column_layout(1)

func _apply_tablet_layout() -> void:
	_set_column_layout(2 if not should_use_single_column() else 1)

func _apply_desktop_layout() -> void:
	_set_column_layout(3 if not should_use_single_column() else 2)

func _set_column_layout(columns: int) -> void:
	# MainContent is a GridContainer after Step 4
	var main_content = left_column.get_parent() if left_column else null
	if main_content and main_content is GridContainer:
		main_content.columns = columns
	# ButtonContainer is the parent of action_button
	var btn_container = action_button.get_parent() if action_button else null
	if btn_container and btn_container is GridContainer:
		btn_container.columns = 3 if columns == 1 else 6
