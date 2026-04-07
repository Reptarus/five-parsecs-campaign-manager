extends AcceptDialog
## DLC Management Dialog - Manage expansion pack ownership and feature toggles
##
## Accessible from Settings menu. Shows three DLC packs with owned/unowned status.
## Per-feature ContentFlag toggles organized by DLC pack.
## Code-only UI (no .tscn needed).

signal dlc_ownership_changed(dlc_id: String, owned: bool)
signal feature_toggled(flag: int, enabled: bool)

# Design constants
const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_DANGER := UIColors.COLOR_DANGER
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_LOCKED_BG := Color("#1A1A2E", 0.2)
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const TOUCH_TARGET := 44

# DLC pack display info
const DLC_DISPLAY: Array[Dictionary] = [
	{
		"id": "trailblazers_toolkit",
		"name": "Trailblazer's Toolkit",
		"description": "New species (Krag, Skulker), Psionics system, advanced training, bot upgrades, ship parts, psionic equipment.",
		"flags": [
			{"flag": "SPECIES_KRAG", "label": "Krag Species"},
			{"flag": "SPECIES_SKULKER", "label": "Skulker Species"},
			{"flag": "PSIONICS", "label": "Psionics System"},
			{"flag": "NEW_TRAINING", "label": "Advanced Training"},
			{"flag": "BOT_UPGRADES", "label": "Bot Upgrades"},
			{"flag": "NEW_SHIP_PARTS", "label": "New Ship Parts"},
			{"flag": "PSIONIC_EQUIPMENT", "label": "Psionic Equipment"},
		],
	},
	{
		"id": "freelancers_handbook",
		"name": "Freelancer's Handbook",
		"description": "Progressive difficulty, combat options, PvP/Co-op battles, AI variations, elite enemies, no-minis combat, grid movement.",
		"flags": [
			{"flag": "PROGRESSIVE_DIFFICULTY", "label": "Progressive Difficulty"},
			{"flag": "DIFFICULTY_TOGGLES", "label": "Difficulty Toggles"},
			{"flag": "AI_VARIATIONS", "label": "AI Variations"},
			{"flag": "DEPLOYMENT_VARIABLES", "label": "Deployment Variables"},
			{"flag": "ESCALATING_BATTLES", "label": "Escalating Battles"},
			{"flag": "ELITE_ENEMIES", "label": "Elite Enemies"},
			{"flag": "DRAMATIC_COMBAT", "label": "Dramatic Combat"},
			{"flag": "NO_MINIS_COMBAT", "label": "No-Minis Combat"},
			{"flag": "GRID_BASED_MOVEMENT", "label": "Grid-Based Movement"},
			{"flag": "CASUALTY_TABLES", "label": "Casualty Tables"},
			{"flag": "DETAILED_INJURIES", "label": "Detailed Injuries"},
			{"flag": "EXPANDED_MISSIONS", "label": "Expanded Missions"},
			{"flag": "EXPANDED_QUESTS", "label": "Expanded Quests"},
			{"flag": "EXPANDED_CONNECTIONS", "label": "Expanded Connections"},
			{"flag": "PVP_BATTLES", "label": "PvP Battles"},
			{"flag": "COOP_BATTLES", "label": "Co-op Battles"},
			{"flag": "TERRAIN_GENERATION", "label": "Terrain Generation"},
		],
	},
	{
		"id": "fixers_guidebook",
		"name": "Fixer's Guidebook",
		"description": "Stealth missions, street fights, salvage jobs, expanded factions, world strife, loans, name generation.",
		"flags": [
			{"flag": "STEALTH_MISSIONS", "label": "Stealth Missions"},
			{"flag": "STREET_FIGHTS", "label": "Street Fights"},
			{"flag": "SALVAGE_JOBS", "label": "Salvage Jobs"},
			{"flag": "EXPANDED_FACTIONS", "label": "Expanded Factions"},
			{"flag": "FRINGE_WORLD_STRIFE", "label": "Fringe World Strife"},
			{"flag": "EXPANDED_LOANS", "label": "Expanded Loans"},
			{"flag": "NAME_GENERATION", "label": "Name Generation"},
			{"flag": "INTRODUCTORY_CAMPAIGN", "label": "Introductory Campaign"},
			{"flag": "PRISON_PLANET_CHARACTER", "label": "Prison Planet Character"},
		],
	},
]

var _dlc_mgr: Node
var _pack_containers: Dictionary = {}  # dlc_id -> VBoxContainer (for flag toggles)
var _ownership_buttons: Dictionary = {}  # dlc_id -> Button
var _flag_checkboxes: Dictionary = {}  # flag_name -> CheckBox


func _ready() -> void:
	title = "Manage Expansions"
	min_size = Vector2i(500, 600)
	_dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	_build_ui()
	_refresh_state()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(main_vbox)

	# Header
	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.text = "[b]Five Parsecs Compendium Expansions[/b]\nToggle DLC ownership and enable/disable individual features per campaign."
	main_vbox.add_child(header)

	# Build each DLC pack card
	for pack_info in DLC_DISPLAY:
		var card := _build_pack_card(pack_info)
		main_vbox.add_child(card)


func _build_pack_card(pack_info: Dictionary) -> PanelContainer:
	var dlc_id: String = pack_info.id
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_ELEVATED
	card_style.set_corner_radius_all(8)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = COLOR_BORDER
	card_style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	# Pack header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(header_hbox)

	var pack_label := Label.new()
	pack_label.text = pack_info.name
	pack_label.add_theme_font_size_override("font_size", 18)
	pack_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	pack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(pack_label)

	var own_btn := Button.new()
	own_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET)
	own_btn.pressed.connect(_on_ownership_toggled.bind(dlc_id))
	# Only show ownership toggle in dev/offline mode
	var store_mgr: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/StoreManager") if Engine.get_main_loop() else null
	var is_dev: bool = not store_mgr or (
		store_mgr.has_method("is_offline_mode")
		and store_mgr.is_offline_mode())
	if not is_dev:
		own_btn.disabled = true
		own_btn.tooltip_text = "Purchase from the Expansions screen"
	header_hbox.add_child(own_btn)
	_ownership_buttons[dlc_id] = own_btn

	# Description
	var desc_label := Label.new()
	desc_label.text = pack_info.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Enable/Disable all buttons
	var bulk_hbox := HBoxContainer.new()
	bulk_hbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(bulk_hbox)

	var enable_all_btn := Button.new()
	enable_all_btn.text = "Enable All"
	enable_all_btn.custom_minimum_size = Vector2(80, 32)
	enable_all_btn.pressed.connect(_on_enable_all.bind(dlc_id))
	bulk_hbox.add_child(enable_all_btn)

	var disable_all_btn := Button.new()
	disable_all_btn.text = "Disable All"
	disable_all_btn.custom_minimum_size = Vector2(80, 32)
	disable_all_btn.pressed.connect(_on_disable_all.bind(dlc_id))
	bulk_hbox.add_child(disable_all_btn)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Feature toggles
	var flags_container := VBoxContainer.new()
	flags_container.add_theme_constant_override("separation", 4)
	vbox.add_child(flags_container)
	_pack_containers[dlc_id] = flags_container

	var flags: Array = pack_info.flags
	for flag_info in flags:
		var cb := CheckBox.new()
		cb.text = flag_info.label
		cb.custom_minimum_size = Vector2(0, 32)
		cb.add_theme_font_size_override("font_size", 14)
		cb.toggled.connect(_on_flag_toggled.bind(flag_info.flag))
		flags_container.add_child(cb)
		_flag_checkboxes[flag_info.flag] = cb

	return card


func _refresh_state() -> void:
	if not _dlc_mgr:
		return

	for pack_info in DLC_DISPLAY:
		var dlc_id: String = pack_info.id
		var owned: bool = _dlc_mgr.has_dlc(dlc_id)

		# Update ownership button
		var btn: Button = _ownership_buttons.get(dlc_id)
		if btn:
			btn.text = "Owned" if owned else "Not Owned"
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(4)
			style.set_content_margin_all(4)
			if owned:
				style.bg_color = COLOR_SUCCESS.darkened(0.3)
			else:
				style.bg_color = COLOR_DANGER.darkened(0.3)
			btn.add_theme_stylebox_override("normal", style)

		# Update flag checkboxes
		var flags: Array = pack_info.flags
		for flag_info in flags:
			var cb: CheckBox = _flag_checkboxes.get(flag_info.flag)
			if cb:
				var flag_value: int = _dlc_mgr.ContentFlag.get(flag_info.flag, -1)
				if flag_value >= 0 and owned:
					cb.disabled = false
					cb.button_pressed = _dlc_mgr.is_feature_enabled(flag_value as DLCManager.ContentFlag)
				else:
					cb.disabled = true
					cb.button_pressed = false


func _on_ownership_toggled(dlc_id: String) -> void:
	if not _dlc_mgr:
		return
	var currently_owned: bool = _dlc_mgr.has_dlc(dlc_id)
	_dlc_mgr.set_dlc_owned(dlc_id, not currently_owned)
	_dlc_mgr.save_ownership()
	_refresh_state()
	dlc_ownership_changed.emit(dlc_id, not currently_owned)


# No-Minis Combat incompatible flags (Compendium p.66)
const NO_MINIS_INCOMPATIBLE: Array[String] = [
	"ESCALATING_BATTLES", "AI_VARIATIONS", "DEPLOYMENT_VARIABLES",
]

func _on_flag_toggled(enabled: bool, flag_name: String) -> void:
	if not _dlc_mgr:
		return
	var flag_value: int = _dlc_mgr.ContentFlag.get(flag_name, -1)
	if flag_value < 0:
		return
	_dlc_mgr.set_feature_enabled(flag_value as DLCManager.ContentFlag, enabled)
	feature_toggled.emit(flag_value, enabled)

	# Enforce No-Minis Combat incompatibilities (Compendium p.66)
	if enabled:
		if flag_name == "NO_MINIS_COMBAT":
			for incompat_flag in NO_MINIS_INCOMPATIBLE:
				var incompat_value: int = _dlc_mgr.ContentFlag.get(incompat_flag, -1)
				if incompat_value >= 0:
					_dlc_mgr.set_feature_enabled(incompat_value as DLCManager.ContentFlag, false)
		elif flag_name in NO_MINIS_INCOMPATIBLE:
			var no_minis_value: int = _dlc_mgr.ContentFlag.get("NO_MINIS_COMBAT", -1)
			if no_minis_value >= 0:
				_dlc_mgr.set_feature_enabled(no_minis_value as DLCManager.ContentFlag, false)
	_refresh_state()


func _on_enable_all(dlc_id: String) -> void:
	if not _dlc_mgr or not _dlc_mgr.has_dlc(dlc_id):
		return
	for pack_info in DLC_DISPLAY:
		if pack_info.id != dlc_id:
			continue
		var flags: Array = pack_info.flags
		for flag_info in flags:
			var flag_value: int = _dlc_mgr.ContentFlag.get(flag_info.flag, -1)
			if flag_value >= 0:
				_dlc_mgr.set_feature_enabled(flag_value as DLCManager.ContentFlag, true)
	_refresh_state()


func _on_disable_all(dlc_id: String) -> void:
	if not _dlc_mgr:
		return
	for pack_info in DLC_DISPLAY:
		if pack_info.id != dlc_id:
			continue
		var flags: Array = pack_info.flags
		for flag_info in flags:
			var flag_value: int = _dlc_mgr.ContentFlag.get(flag_info.flag, -1)
			if flag_value >= 0:
				_dlc_mgr.set_feature_enabled(flag_value as DLCManager.ContentFlag, false)
	_refresh_state()
