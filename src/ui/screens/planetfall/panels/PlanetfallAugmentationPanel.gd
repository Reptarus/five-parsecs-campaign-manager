class_name PlanetfallAugmentationPanel
extends Control

## Augmentation purchase panel — accessible from Dashboard and PostBattle XP step.
## 8 augmentations with escalating AP cost. Max 1 per turn.
## Applies to all current and future characters (except Bots/Soulless).
## Source: Planetfall p.105

signal phase_completed(result_data: Dictionary)
signal augmentation_purchased(augmentation: Dictionary)

const PlanetfallAugmentationScript := preload(
	"res://src/core/systems/PlanetfallAugmentationSystem.gd")

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
var _phase_manager: Node
var _aug_system: PlanetfallAugmentationScript
var _standalone: bool = false  ## true when opened from Dashboard (not turn step)

var _title_label: Label
var _ap_label: Label
var _cost_label: Label
var _list_container: VBoxContainer
var _result_container: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	_aug_system = PlanetfallAugmentationScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func set_standalone(standalone: bool) -> void:
	## When true, shows a Close button instead of emitting phase_completed.
	_standalone = standalone
	if _close_btn:
		_close_btn.text = "Close" if _standalone else "Continue"


func refresh() -> void:
	_clear_container(_list_container)
	_clear_container(_result_container)
	_update_ap_display()
	_build_augmentation_list()
	if _close_btn:
		_close_btn.disabled = false
		_close_btn.text = "Close" if _standalone else "Continue"


func complete() -> void:
	_on_close_pressed()


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
	_title_label.text = "GENETIC AUGMENTATION"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.text = "Purchase augmentations to enhance all current and future characters. Cost increases with each purchase. Max 1 per campaign turn. Bots and Soulless imports are excluded."
	info.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	info.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(info)

	# AP + cost display
	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(stat_row)

	_ap_label = Label.new()
	_ap_label.text = "Augmentation Points: 0"
	_ap_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_ap_label.add_theme_color_override("font_color", COLOR_CYAN)
	stat_row.add_child(_ap_label)

	_cost_label = Label.new()
	_cost_label.text = "Next Cost: 1 AP"
	_cost_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_cost_label.add_theme_color_override("font_color", COLOR_WARNING)
	stat_row.add_child(_cost_label)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_list_container)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	_close_btn = Button.new()
	_close_btn.text = "Continue"
	_close_btn.custom_minimum_size = Vector2(200, 48)
	_close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_btn)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## AUGMENTATION LIST
## ============================================================================

func _build_augmentation_list() -> void:
	var all_augs: Array = _aug_system.get_all_augmentations()
	var available: Array = _aug_system.get_available_augmentations(_campaign)
	var available_ids: Array = []
	for a in available:
		if a is Dictionary:
			available_ids.append(a.get("id", ""))

	var purchased_this_turn: bool = _aug_system.has_purchased_this_turn(_campaign)

	for aug in all_augs:
		if aug is not Dictionary:
			continue
		var aid: String = aug.get("id", "")
		var aname: String = aug.get("name", "Unknown")
		var desc: String = aug.get("description", "")
		var is_available: bool = available_ids.has(aid)
		var is_owned: bool = not is_available and not available_ids.has(aid)

		# Card container
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_ELEVATED
		style.border_color = COLOR_SUCCESS if not is_available else COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(SPACING_MD)
		card.add_theme_stylebox_override("panel", style)
		_list_container.add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", SPACING_SM)
		card.add_child(card_vbox)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", SPACING_SM)
		card_vbox.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = aname
		name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)

		if not is_available:
			var owned_lbl := Label.new()
			owned_lbl.text = "OWNED"
			owned_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			owned_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
			name_row.add_child(owned_lbl)
		elif is_available and not purchased_this_turn:
			var buy_btn := Button.new()
			buy_btn.text = "Purchase"
			buy_btn.custom_minimum_size = Vector2(100, 36)
			buy_btn.disabled = not _aug_system.can_augment(_campaign, aid)
			buy_btn.pressed.connect(_on_purchase_pressed.bind(aid))
			name_row.add_child(buy_btn)

		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		desc_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_lbl)


func _on_purchase_pressed(augmentation_id: String) -> void:
	var result: Dictionary = _aug_system.apply_augmentation(
		_campaign, augmentation_id)
	if result.get("success", false):
		var aug: Dictionary = result.get("augmentation", {})
		var cost: int = result.get("cost", 0)
		_add_result_bbcode(
			"[color=#10B981]Purchased %s for %d AP![/color]" % [
				aug.get("name", ""), cost])
		augmentation_purchased.emit(aug)
		_update_ap_display()
		# Rebuild list to show owned status
		_clear_container(_list_container)
		_build_augmentation_list()
	else:
		_add_result_bbcode(
			"[color=#DC2626]%s[/color]" % result.get("error", "Failed"))


func _on_close_pressed() -> void:
	if _close_btn:
		_close_btn.disabled = true
	if _standalone:
		hide()
	else:
		phase_completed.emit({})


## ============================================================================
## HELPERS
## ============================================================================

func _update_ap_display() -> void:
	if not _campaign:
		return
	var ap: int = _campaign.augmentation_points if "augmentation_points" in _campaign else 0
	var cost: int = _aug_system.get_augmentation_cost(_campaign)
	if _ap_label:
		_ap_label.text = "Augmentation Points: %d" % ap
	if _cost_label:
		_cost_label.text = "Next Cost: %d AP" % cost


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
