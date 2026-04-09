class_name PlanetfallEnemyTrackerPanel
extends Control

## Enemy Tracker panel — accessible from Dashboard and Step 12.
## Shows 3 tactical enemies with info levels, boss/strongpoint status,
## occupied sectors. Source: Planetfall pp.50-51, 61, 68

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _content: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	_clear_container(_content)
	_build_content()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(160, 48)
	_close_btn.pressed.connect(func(): hide())


func _build_content() -> void:
	if not _campaign:
		return

	var title := Label.new()
	title.text = "TACTICAL ENEMIES"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.text = "Tactical Enemies appear at milestones 1, 2, and 5. Gather Enemy Information through missions and scout patrols to locate their Bosses and Strongpoints."
	info.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	info.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content.add_child(info)

	var enemies: Array = _campaign.tactical_enemies if "tactical_enemies" in _campaign else []
	if enemies.is_empty():
		var empty := Label.new()
		empty.text = "No Tactical Enemies present yet. They appear at Milestones 1, 2, and 5."
		empty.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(empty)
	else:
		for i in range(enemies.size()):
			var enemy: Variant = enemies[i]
			if enemy is Dictionary:
				_build_enemy_card(enemy, i)

	# Ancient Signs section
	_build_ancient_signs_section()

	_content.add_child(_close_btn)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _build_enemy_card(enemy: Dictionary, index: int) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	var defeated: bool = enemy.get("defeated", false)
	style.border_color = COLOR_SUCCESS if defeated else COLOR_DANGER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	_content.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(header_row)

	var enemy_type: String = enemy.get("type", "Unknown Enemy")
	var name_lbl := Label.new()
	name_lbl.text = "Enemy %d: %s" % [index + 1, enemy_type]
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_lbl)

	if defeated:
		var status := Label.new()
		status.text = "DEFEATED"
		status.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		status.add_theme_color_override("font_color", COLOR_SUCCESS)
		header_row.add_child(status)

	# Info level
	var enemy_info_val: int = enemy.get("enemy_info", 0)
	var info_lbl := Label.new()
	info_lbl.text = "Enemy Information: %d / 6" % enemy_info_val
	info_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	info_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(info_lbl)

	if enemy_info_val >= 6:
		var full_intel := Label.new()
		full_intel.text = "Full intel — can always attempt Strike Mission"
		full_intel.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		full_intel.add_theme_color_override("font_color", COLOR_SUCCESS)
		vbox.add_child(full_intel)

	# Boss + Strongpoint status
	var boss_located: bool = enemy.get("boss_located", false)
	var strongpoint: bool = enemy.get("strongpoint_located", false)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(status_row)

	var boss_lbl := Label.new()
	boss_lbl.text = "Boss: %s" % ("Located" if boss_located else "Unknown")
	boss_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	boss_lbl.add_theme_color_override(
		"font_color", COLOR_WARNING if boss_located else COLOR_TEXT_SECONDARY)
	status_row.add_child(boss_lbl)

	var sp_lbl := Label.new()
	sp_lbl.text = "Strongpoint: %s" % ("Located" if strongpoint else "Unknown")
	sp_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	sp_lbl.add_theme_color_override(
		"font_color", COLOR_DANGER if strongpoint else COLOR_TEXT_SECONDARY)
	status_row.add_child(sp_lbl)

	# Occupied sectors
	var sectors: Array = enemy.get("occupied_sectors", [])
	var sectors_lbl := Label.new()
	sectors_lbl.text = "Occupied Sectors: %d" % sectors.size()
	sectors_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	sectors_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(sectors_lbl)


func _build_ancient_signs_section() -> void:
	var signs: Array = _campaign.ancient_signs if "ancient_signs" in _campaign else []
	var section := Label.new()
	section.text = "ANCIENT SIGNS: %d" % signs.size()
	section.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	section.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(section)

	var desc := Label.new()
	desc.text = "Roll 1D6 when obtaining a sign. On a roll equal to or below total signs, locate an Ancient Site for a Delve mission."
	desc.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(desc)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		if child == _close_btn:
			continue
		child.queue_free()
