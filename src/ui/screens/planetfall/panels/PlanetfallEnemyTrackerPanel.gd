class_name PlanetfallEnemyTrackerPanel
extends Control

## Enemy Tracker panel — accessible from Dashboard and Step 12.
## Shows 3 tactical enemies with info levels, boss/strongpoint status,
## occupied sectors. Source: Planetfall pp.50-51, 61, 68

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const MilestoneScript := preload("res://src/core/systems/PlanetfallMilestoneSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

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
	TouchScrollOpenerRef.open_subtree(self)


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
	_close_btn.custom_minimum_size = Vector2(120, 48)
	_close_btn.pressed.connect(func(): hide())
	# First and top right, as on every dashboard overlay: reachable the moment it opens.
	# _clear_container() keeps it, so every rebuilt section lands below it.
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(_close_btn)


func _build_content() -> void:
	if not _campaign:
		return

	var title := Label.new()
	title.text = "TACTICAL ENEMIES"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var arrivals: String = _arrival_milestones()
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.text = ("A Tactical Enemy emerges at Milestones %s (p.50). Win battles against "
			+ "an enemy and send scouts out to gather Enemy Information: it tracks down a "
			+ "Boss, and a captured Boss reveals the Strongpoint (p.51).") % arrivals
	ScreenChrome.size_rich_text(info, ScreenChrome.font_size(FONT_SIZE_SM))
	info.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content.add_child(info)

	var enemies: Array = _campaign.tactical_enemies if "tactical_enemies" in _campaign else []
	if enemies.is_empty():
		var empty := Label.new()
		empty.text = "No Tactical Enemy is on the map yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
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


func _build_enemy_card(enemy: Dictionary, index: int) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	var defeated: bool = enemy.get("defeated", false)
	style.border_color = COLOR_SUCCESS if defeated else COLOR_DANGER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
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

	# `type` is the generator's whole type record, so printing it put a Dictionary on
	# the card; the map module owns the name.
	var name_lbl := Label.new()
	name_lbl.text = "Enemy %d: %s" % [index + 1, MapScript.enemy_name(_campaign, index)]
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_lbl)

	if defeated:
		var status := Label.new()
		status.text = "DEFEATED"
		status.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		status.add_theme_color_override("font_color", COLOR_SUCCESS)
		header_row.add_child(status)

	# Enemy Information lives in ONE store on the core. Each enemy record also carries an
	# `enemy_info` field that nothing writes, and this card read it, so it showed 0 for
	# every enemy however much the scouts and victories had gathered.
	var max_info: int = PlanetfallCampaignCore.ENEMY_INFO_MAX
	var gathered: int = _campaign.get_enemy_info_count(index) \
			if _campaign.has_method("get_enemy_info_count") else 0
	_add_line(vbox, "Enemy Information: %d / %d" % [gathered, max_info], COLOR_CYAN)
	if gathered >= max_info:
		_add_line(vbox, "With %d Enemy Information you can always opt to carry out the "
				% max_info + "Strike (p.61).", COLOR_SUCCESS, FONT_SIZE_XS)

	# Where the Boss is this turn and where the Strongpoint stands, by sector (p.51, p.61).
	var marks: Dictionary = MapScript.enemy_marks(_campaign, index)
	var boss_at: String = str(marks.get("boss", ""))
	var sp_at: String = str(marks.get("strongpoint", ""))
	_add_line(vbox, "Boss: %s" % ("tracked down in %s" % MapScript.label(boss_at)
			if boss_at != "" else "not tracked down"),
			COLOR_WARNING if boss_at != "" else COLOR_TEXT_SECONDARY)
	_add_line(vbox, "Strongpoint: %s" % (MapScript.label(sp_at) if sp_at != ""
			else "not located"), COLOR_DANGER if sp_at != "" else COLOR_TEXT_SECONDARY)

	# The sectors it holds, named the way the map names them, not only counted.
	var held: Array = MapScript.held_by(_campaign, index)
	var names: Array[String] = []
	for k in held:
		names.append(MapScript.label(str(k)))
	_add_line(vbox, ("Holds %d sector%s: %s" % [held.size(), "" if held.size() == 1 else "s",
			", ".join(names)]) if not held.is_empty() else "Holds no sectors.",
			COLOR_TEXT_SECONDARY)


func _add_line(parent: Control, text: String, color: Color,
		size: int = FONT_SIZE_SM) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


## The milestones a Tactical Enemy arrives on, read from the milestone table.
static func _arrival_milestones() -> String:
	var at: Array = MilestoneScript.new().milestones_with_effect("tactical_enemy_emerges")
	var parts: Array[String] = []
	for n in at:
		parts.append(str(n))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


func _build_ancient_signs_section() -> void:
	var signs: Array = _campaign.ancient_signs if "ancient_signs" in _campaign else []
	var section := Label.new()
	section.text = "ANCIENT SIGNS: %d" % signs.size()
	section.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	section.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(section)

	var desc := Label.new()
	desc.text = ("Each time you obtain a Sign, roll 1D6. Equal to or below the Signs you "
			+ "hold locates an Ancient Site for a Delve, and all Signs are then discarded "
			+ "(p.61).")
	desc.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
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
