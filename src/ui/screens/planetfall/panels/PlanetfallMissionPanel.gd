class_name PlanetfallMissionPanel
extends Control

## Step 6: Mission Determination — select mission type for this turn.
## 13 mission types loaded from mission_types.json.
## Some missions are event-triggered, some require tactical enemies.
## Source: Planetfall pp.64-65, 114-133

signal phase_completed(result_data: Dictionary)

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _missions: Array = []
var _selected_mission: Dictionary = {}

var _title_label: Label
var _list_container: VBoxContainer
var _detail_container: VBoxContainer
var _confirm_btn: Button


func _ready() -> void:
	_load_missions()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_selected_mission = {}
	_clear_container(_list_container)
	_clear_container(_detail_container)
	_build_mission_list()
	if _confirm_btn:
		_confirm_btn.disabled = true


func complete() -> void:
	if not _selected_mission.is_empty():
		_on_confirm_pressed()


## ============================================================================
## DATA
## ============================================================================

func _load_missions() -> void:
	var path := "res://data/planetfall/mission_types.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is Dictionary:
		_missions = json.data.get("missions", [])


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
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 6: MISSION DETERMINATION"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Two-column layout: mission list + detail
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(hbox)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", SPACING_SM)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_list_container)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", SPACING_SM)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail_container)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm Mission Selection"
	_confirm_btn.custom_minimum_size = Vector2(240, 48)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## MISSION LIST
## ============================================================================

func _build_mission_list() -> void:
	var header := Label.new()
	header.text = "Available Missions"
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_list_container.add_child(header)

	for mission in _missions:
		if mission is not Dictionary:
			continue
		var mid: String = mission.get("id", "")
		var mname: String = mission.get("name", "Unknown")
		var category: String = mission.get("category", "")
		var forced: bool = mission.get("forced", false)
		var needs_enemies: bool = mission.get("requires_tactical_enemies", false)
		var event_triggered: bool = mission.get("event_triggered", false)

		var btn := Button.new()
		btn.text = mname
		btn.custom_minimum_size.y = 40
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Dim unavailable missions
		if needs_enemies and not _has_tactical_enemies():
			btn.tooltip_text = "Requires Tactical Enemies on the map"
			btn.disabled = true
		if event_triggered:
			btn.tooltip_text = "Triggered by campaign events"

		btn.pressed.connect(_on_mission_selected.bind(mission))
		_list_container.add_child(btn)


func _on_mission_selected(mission: Dictionary) -> void:
	_selected_mission = mission
	_show_mission_detail(mission)
	if _confirm_btn:
		_confirm_btn.disabled = false


func _show_mission_detail(mission: Dictionary) -> void:
	_clear_container(_detail_container)

	var name_lbl := Label.new()
	name_lbl.text = mission.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	var cat_lbl := Label.new()
	cat_lbl.text = "Category: %s" % mission.get("category", "").capitalize()
	cat_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	cat_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cat_lbl)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = mission.get("description", "")
	desc.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc)

	var deploy_lbl := Label.new()
	deploy_lbl.text = "Max Deploy: %d characters" % mission.get("max_deploy", 6)
	deploy_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	deploy_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(deploy_lbl)

	var page_lbl := Label.new()
	page_lbl.text = "Rulebook: p.%d" % mission.get("page", 0)
	page_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	page_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(page_lbl)


func _on_confirm_pressed() -> void:
	if _confirm_btn:
		_confirm_btn.disabled = true
	phase_completed.emit({"selected_mission": _selected_mission})


## ============================================================================
## HELPERS
## ============================================================================

func _has_tactical_enemies() -> bool:
	if not _campaign or not "tactical_enemies" in _campaign:
		return false
	return not _campaign.tactical_enemies.is_empty()


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
