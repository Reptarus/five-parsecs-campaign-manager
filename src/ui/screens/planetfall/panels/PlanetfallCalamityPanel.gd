class_name PlanetfallCalamityPanel
extends Control

## Dashboard overlay showing active calamities with resolution progress.
## Each calamity card shows name, description, ongoing effect, resolution
## instructions, and progress tracking.
## Source: Planetfall pp.165-169

const PlanetfallCalamityScript := preload(
	"res://src/core/systems/PlanetfallCalamitySystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_BASE := Color("#1A1A2E")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _calamity_sys: PlanetfallCalamityScript
var _content: VBoxContainer


func _ready() -> void:
	_calamity_sys = PlanetfallCalamityScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	if not _content:
		return
	for child in _content.get_children():
		child.queue_free()
	_build_content()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(func(): visible = false)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(close_btn)


func _build_content() -> void:
	if not _campaign:
		return

	var title := Label.new()
	title.text = "ACTIVE CALAMITIES"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var active: Array = _calamity_sys.get_active_calamities(_campaign)

	if active.is_empty():
		var empty := Label.new()
		empty.text = "No active calamities. The colony is safe... for now."
		empty.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		empty.add_theme_color_override("font_color", COLOR_SUCCESS)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(empty)
		return

	for cal in active:
		_build_calamity_card(cal)


func _build_calamity_card(cal: Dictionary) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_DANGER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	_content.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(inner)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = cal.get("name", "Unknown Calamity")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_DANGER)
	inner.add_child(name_lbl)

	# Description
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = cal.get("description", "")
	desc.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	inner.add_child(desc)

	# Ongoing effect
	var ongoing: String = cal.get("ongoing_effect", "")
	if not ongoing.is_empty():
		_add_section(inner, "Ongoing Effect", ongoing, COLOR_WARNING)

	# Resolution instructions
	var resolution: String = cal.get("resolution", "")
	if not resolution.is_empty():
		_add_section(inner, "How to Resolve", resolution, COLOR_ACCENT)

	# Progress tracking
	var progress: Dictionary = cal.get("progress", {})
	if not progress.is_empty():
		_add_progress_display(inner, cal.get("id", ""), progress)

	# Reward (shown for context)
	var reward: String = cal.get("reward", "")
	if not reward.is_empty():
		_add_section(inner, "Reward on Resolution", reward, COLOR_SUCCESS)

	# Triggered turn
	var turn: int = cal.get("triggered_turn", 0)
	if turn > 0:
		var turn_lbl := Label.new()
		turn_lbl.text = "Triggered: Turn %d" % turn
		turn_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		turn_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		inner.add_child(turn_lbl)


func _add_section(parent: VBoxContainer, title_text: String,
		content_text: String, accent: Color) -> void:
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	t.add_theme_color_override("font_color", accent)
	parent.add_child(t)

	var c := RichTextLabel.new()
	c.bbcode_enabled = true
	c.fit_content = true
	c.scroll_active = false
	c.text = content_text
	c.add_theme_font_size_override("normal_font_size", FONT_SIZE_XS)
	c.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	parent.add_child(c)


func _add_progress_display(parent: VBoxContainer, cal_id: String,
		progress: Dictionary) -> void:
	var progress_text: String = ""

	match cal_id:
		"slyn_assault":
			progress_text = "Slyn killed: %d / 30" % progress.get("slyn_killed", 0)
		"robot_rampage":
			progress_text = "Sleeper chips collected: %d / 5" % progress.get("chips_collected", 0)
		"mega_predators":
			progress_text = "Enhanced Lifeforms killed: %d / 5" % progress.get("enhanced_killed", 0)
		"wildlife_aggression":
			var found: bool = progress.get("controller_killed", false)
			progress_text = "Controller: %s" % ("Killed!" if found else "Not yet found")
		"virus":
			var cure_data: int = progress.get("cure_data", 0)
			progress_text = "Cure Data: %d (roll 2D6 <= %d to discover cure)" % [cure_data, cure_data]
		"enemy_super_weapon":
			var wp: int = progress.get("weapon_progress", 0)
			progress_text = "Weapon progress: %d / 15" % wp
		"swarm_infestation":
			var sectors_cleared: int = progress.get("sectors_cleared", 0)
			var sectors_infested: int = progress.get("sectors_infested", 1)
			progress_text = "Sectors cleared: %d / %d infested" % [sectors_cleared, sectors_infested]
		"environmental_risk":
			var sectors_cleared: int = progress.get("sectors_cleared", 0)
			progress_text = "Anomalous sectors cleared: %d / 3" % sectors_cleared

	if not progress_text.is_empty():
		var lbl := Label.new()
		lbl.text = "Progress: %s" % progress_text
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		parent.add_child(lbl)
