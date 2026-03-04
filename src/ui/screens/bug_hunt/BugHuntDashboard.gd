extends Control

## Bug Hunt Dashboard — Campaign overview screen.
## Shows regiment info, squad roster, grunt pool, reputation,
## movie magic, and provides navigation to turn controller.

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_ACCENT := Color("#2D5A7B")

var _campaign: Resource
var _content: VBoxContainer
var _save_btn: Button


func _ready() -> void:
	_load_campaign()
	_build_ui()
	_populate()


func _load_campaign() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		_campaign = gs.get_current_campaign()
	elif gs and "current_campaign" in gs:
		_campaign = gs.current_campaign

	# Validate this is a Bug Hunt campaign (has main_characters property)
	if _campaign and not "main_characters" in _campaign:
		_campaign = null


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)


func _populate() -> void:
	if not _campaign:
		var lbl := Label.new()
		lbl.text = "No Bug Hunt campaign loaded."
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		lbl.add_theme_font_size_override("font_size", 20)
		_content.add_child(lbl)
		return

	# Header
	var name_str: String = _campaign.campaign_name if "campaign_name" in _campaign else "Unknown"
	var regiment: String = _campaign.regiment_name if "regiment_name" in _campaign else ""
	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	if not regiment.is_empty():
		var reg_lbl := Label.new()
		reg_lbl.text = regiment
		reg_lbl.add_theme_font_size_override("font_size", 18)
		reg_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		reg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(reg_lbl)

	# Campaign info card
	var info := _create_card("Campaign Status", _content)
	var turn: int = _campaign.campaign_turn if "campaign_turn" in _campaign else 0
	var rep: int = _campaign.reputation if "reputation" in _campaign else 0
	var diff: String = _campaign.difficulty if "difficulty" in _campaign else "standard"
	_add_row(info, "Turn", str(turn))
	_add_row(info, "Reputation", str(rep))
	_add_row(info, "Difficulty", diff.replace("_", " ").capitalize())

	# Squad roster
	var chars: Array = _campaign.main_characters if "main_characters" in _campaign else []
	var squad := _create_card("Squad (%d Main Characters)" % chars.size(), _content)
	for mc in chars:
		if mc is not Dictionary:
			continue
		var mc_name: String = mc.get("name", mc.get("character_name", "?"))
		var line := "%s — R:%d S:%d CS:%d T:%d Sv:%d XP:%d" % [
			mc_name,
			mc.get("reactions", 0), mc.get("speed", 0),
			mc.get("combat_skill", 0), mc.get("toughness", 0),
			mc.get("savvy", 0), mc.get("xp", 0)]
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.add_theme_font_size_override("font_size", 14)
		squad.add_child(lbl)

	# Grunt pool
	var grunts: Array = _campaign.grunts if "grunts" in _campaign else []
	var grunt_card := _create_card("Grunt Pool (%d)" % grunts.size(), _content)
	if grunts.is_empty():
		var no_grunts := Label.new()
		no_grunts.text = "No grunts available"
		no_grunts.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		grunt_card.add_child(no_grunts)
	else:
		var grunt_info := Label.new()
		grunt_info.text = "%d grunts (React:1 Spd:4 CS:0 Tough:4)" % grunts.size()
		grunt_info.add_theme_color_override("font_color", COLOR_TEXT)
		grunt_card.add_child(grunt_info)

	# Movie Magic
	var movie_card := _create_card("Movie Magic", _content)
	var all_magic := [
		"Barricade", "Double-Up", "Escape", "Evac",
		"Extra Support", "Lucky Find", "Reinforcements",
		"Remove Contact", "Survived", "You Want Some Too?"]
	var used: Dictionary = _campaign.movie_magic_used if "movie_magic_used" in _campaign else {}
	for ability_name in all_magic:
		var ability_id: String = ability_name.to_lower().replace(" ", "_").replace("-", "_").replace("?", "")
		var is_used: bool = used.get(ability_id, false)
		var lbl := Label.new()
		if is_used:
			lbl.text = "[X] " + ability_name
			lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		else:
			lbl.text = "[ ] " + ability_name
			lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		lbl.add_theme_font_size_override("font_size", 13)
		movie_card.add_child(lbl)

	# Stagger fade-in for all cards added so far
	_stagger_card_reveal()

	# Navigation buttons
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(nav)

	var play_btn := Button.new()
	play_btn.text = "Continue Campaign"
	play_btn.custom_minimum_size = Vector2(200, 48)
	play_btn.pressed.connect(_on_continue)
	nav.add_child(play_btn)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.custom_minimum_size = Vector2(120, 48)
	_save_btn.pressed.connect(_on_save)
	nav.add_child(_save_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(140, 48)
	menu_btn.pressed.connect(_on_main_menu)
	nav.add_child(menu_btn)
	# TweenFX press feedback
	for btn: Button in [play_btn, _save_btn, menu_btn]:
		btn.pressed.connect(func():
			btn.pivot_offset = btn.size / 2
			TweenFX.press(btn, 0.2)
		)
	# CTA breathing on primary action button
	play_btn.pivot_offset = play_btn.size / 2
	TweenFX.breathe(play_btn, 3.0, 0.05)


func _stagger_card_reveal() -> void:
	var children := _content.get_children()
	for child in children:
		if child is Control:
			child.modulate.a = 0.0
	for i in children.size():
		if children[i] is Control:
			if i > 0:
				await get_tree().create_timer(0.05).timeout
			TweenFX.fade_in(children[i], 0.25)


func _on_continue() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("bug_hunt_turn_controller")


func _on_save() -> void:
	if not _campaign:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		var result: Dictionary = gs.save_campaign(_campaign)
		if result.get("success", false):
			_flash_save_button()
	elif _campaign.has_method("save_to_file") and _campaign.has_method("get_campaign_id"):
		# Fallback: direct save if GameState unavailable
		var path: String = "user://saves/" + _campaign.get_campaign_id() + ".save"
		_campaign.save_to_file(path)


func _flash_save_button() -> void:
	if _save_btn and is_instance_valid(_save_btn):
		_save_btn.text = "Saved!"
		_save_btn.pivot_offset = _save_btn.size / 2
		TweenFX.punch_in(_save_btn, 0.15, 0.2)
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(_save_btn):
				_save_btn.text = "Save"
		)


func _on_main_menu() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox


func _add_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.custom_minimum_size.x = 120
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", COLOR_TEXT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(val)
