extends Control

## Tactics Battle Setup Panel — Covers ORDERS, RECON, BATTLE_PREP, DEPLOYMENT phases.
## Generates scenario, shows objectives, displays deployment zones.
## Covers phases 0-3 of the 8-phase turn.

signal phase_completed(phase: int, data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _phase_desc: Label
var _complete_btn: Button


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func setup(phase_mgr, campaign_res) -> void:
	_phase_manager = phase_mgr
	_campaign = campaign_res


func show_phase(phase: int) -> void:
	if not _phase_title or not _phase_desc:
		return

	var phase_names := {
		0: "Operational Orders",
		1: "Reconnaissance",
		2: "Battle Preparation",
		3: "Deployment",
	}
	var phase_descs := {
		0: "Plan your approach. Assign units to operational zones and choose your battle plan for this turn.",
		1: "Gather intelligence on enemy positions. Roll Observation tests to reveal enemy composition and terrain features.",
		2: "Generate the battle scenario. Roll for scenario type, objectives, and battlefield conditions.",
		3: "Deploy your forces according to the scenario deployment rules. Place units in your deployment zone.",
	}

	_phase_title.text = phase_names.get(phase, "Unknown Phase")
	_phase_desc.text = phase_descs.get(phase, "")

	# Update content for specific phase
	_rebuild_phase_content(phase)


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_phase_title = Label.new()
	_phase_title.text = "Battle Setup"
	_phase_title.add_theme_font_size_override("font_size", _scaled_font(22))
	_phase_title.add_theme_color_override("font_color", COLOR_TEXT)
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_title)

	_phase_desc = Label.new()
	_phase_desc.text = ""
	_phase_desc.add_theme_font_size_override("font_size", _scaled_font(14))
	_phase_desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_phase_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_phase_desc)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	# Complete button
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Phase"
	_complete_btn.custom_minimum_size = Vector2(200, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _rebuild_phase_content(phase: int) -> void:
	for child in _content.get_children():
		child.queue_free()

	match phase:
		0:  # Orders
			_add_info_card("Battle Plan",
				"Choose your operational approach for this turn. "\
				+ "Your battle plan affects AI behavior and deployment options.")
		1:  # Recon
			_add_info_card("Intelligence Report",
				"Observation tests reveal enemy composition. "\
				+ "Better intel means fewer surprises during battle.")
		2:  # Battle Prep
			var scenario_type := ["Skirmish", "Battle",
				"Grand Battle", "Evolving Objective"][randi() % 4]
			_add_info_card("Scenario: %s" % scenario_type,
				"Battlefield conditions generated. "\
				+ "Review the scenario briefing before deploying.")
		3:  # Deployment
			_add_info_card("Deployment Zone",
				"Place your forces in the deployment zone. "\
				+ "Consider terrain, cover, and objectives.")


func _add_info_card(card_title: String, body: String) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	var title := Label.new()
	title.text = card_title
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	title.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = body
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_content.add_child(card)


func _on_complete() -> void:
	var current: int = _phase_manager.current_phase \
		if _phase_manager else 0
	phase_completed.emit(current, {})
