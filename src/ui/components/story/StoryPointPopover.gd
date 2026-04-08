class_name StoryPointPopover
extends PopupPanel

## Unified Story Point + Stars of the Story popover
##
## Compact dropdown accessible from the CampaignDashboard SP badge.
## Combines Story Point spending (Core Rules pp.66-67) and
## Stars of the Story emergency abilities (Core Rules p.67).
## Uses PopupPanel for built-in click-outside-to-dismiss.

const StoryPointSystemClass = preload(
	"res://src/core/systems/StoryPointSystem.gd")
const StarsSystemClass = preload(
	"res://src/core/systems/StarsOfTheStorySystem.gd")

signal story_point_spent(type: int, details: Dictionary)
signal star_ability_activated(
	ability: int, result: Dictionary)

# Design tokens
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG

const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG

const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_DISABLED := UIColors.COLOR_TEXT_DISABLED
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_DANGER := UIColors.COLOR_DANGER

# System references
var _sp_system: StoryPointSystemClass
var _stars_system: StarsSystemClass

# UI references
var _balance_label: Label
var _spend_buttons: Array[Button] = []
var _star_rows: Dictionary = {}  # StarAbility -> {button, uses_label}


func _ready() -> void:
	size = Vector2i(340, 0)  # Width fixed, height auto
	transient = true
	transparent = false
	_build_ui()
	_apply_panel_style()


## Initialize with system instances
func initialize(
	sp_system: StoryPointSystemClass,
	stars_system: StarsSystemClass
) -> void:
	_sp_system = sp_system
	_stars_system = stars_system


## Refresh all button states from current system state
func refresh() -> void:
	if not _sp_system or not _stars_system:
		return
	_update_balance()
	_update_spend_buttons()
	_update_star_rows()


# ── UI Construction ──────────────────────────────────────

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left", SPACING_MD)
	margin.add_theme_constant_override(
		"margin_right", SPACING_MD)
	margin.add_theme_constant_override(
		"margin_top", SPACING_MD)
	margin.add_theme_constant_override(
		"margin_bottom", SPACING_MD)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(
		"separation", SPACING_SM)
	margin.add_child(vbox)

	# ── Balance header ──
	_balance_label = Label.new()
	_balance_label.text = "STORY POINTS: 0"
	_balance_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	_balance_label.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_balance_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_balance_label)

	# ── Separator ──
	var sep1 := HSeparator.new()
	sep1.modulate = COLOR_BORDER
	vbox.add_child(sep1)

	# ── Spend options section ──
	var spend_header := Label.new()
	spend_header.text = "SPEND OPTIONS"
	spend_header.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	spend_header.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(spend_header)

	_create_spend_button(
		vbox,
		StoryPointSystemClass.SpendType.ROLL_TWICE_PICK_ONE,
		"Roll Twice, Pick One", "1 SP")
	_create_spend_button(
		vbox,
		StoryPointSystemClass.SpendType.REROLL_RESULT,
		"Reroll Any Result", "1 SP")
	_create_spend_button(
		vbox,
		StoryPointSystemClass.SpendType.GET_CREDITS,
		"+3 Credits", "1 SP / turn")
	_create_spend_button(
		vbox,
		StoryPointSystemClass.SpendType.GET_XP,
		"+3 XP (one character)", "1 SP / turn")
	_create_spend_button(
		vbox,
		StoryPointSystemClass.SpendType.EXTRA_ACTION,
		"Extra Campaign Action", "1 SP / turn")

	# ── Separator ──
	var sep2 := HSeparator.new()
	sep2.modulate = COLOR_BORDER
	vbox.add_child(sep2)

	# ── Emergency abilities section ──
	var stars_header := Label.new()
	stars_header.text = "EMERGENCY (once/campaign)"
	stars_header.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	stars_header.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(stars_header)

	_create_star_row(
		vbox,
		StarsSystemClass.StarAbility.IT_WASNT_THAT_BAD,
		"It Wasn't That Bad!")
	_create_star_row(
		vbox,
		StarsSystemClass.StarAbility.DRAMATIC_ESCAPE,
		"Dramatic Escape")
	_create_star_row(
		vbox,
		StarsSystemClass.StarAbility.ITS_TIME_TO_GO,
		"It's Time To Go")
	_create_star_row(
		vbox,
		StarsSystemClass.StarAbility.RAINY_DAY_FUND,
		"Rainy Day Fund")


func _create_spend_button(
	parent: VBoxContainer,
	spend_type: int,
	label_text: String,
	cost_text: String
) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(
		"separation", SPACING_SM)

	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(
		_on_spend_pressed.bind(spend_type))
	_style_spend_button(btn)
	hbox.add_child(btn)

	var cost_lbl := Label.new()
	cost_lbl.text = cost_text
	cost_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	cost_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	cost_lbl.custom_minimum_size.x = 70
	cost_lbl.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT)
	hbox.add_child(cost_lbl)

	parent.add_child(hbox)
	_spend_buttons.append(btn)


func _create_star_row(
	parent: VBoxContainer,
	ability: int,
	label_text: String
) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(
		"separation", SPACING_SM)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL)
	hbox.add_child(name_lbl)

	var uses_lbl := Label.new()
	uses_lbl.text = "1/1"
	uses_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	uses_lbl.add_theme_color_override(
		"font_color", COLOR_SUCCESS)
	uses_lbl.custom_minimum_size.x = 30
	uses_lbl.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER)
	hbox.add_child(uses_lbl)

	var use_btn := Button.new()
	use_btn.text = "Use"
	use_btn.custom_minimum_size = Vector2(60, TOUCH_TARGET_MIN)
	use_btn.pressed.connect(
		_on_star_pressed.bind(ability))
	_style_star_button(use_btn)
	hbox.add_child(use_btn)

	parent.add_child(hbox)
	_star_rows[ability] = {
		"name_label": name_lbl,
		"uses_label": uses_lbl,
		"button": use_btn
	}


# ── State Updates ────────────────────────────────────────

func _update_balance() -> void:
	var pts: int = _sp_system.get_current_points()
	_balance_label.text = "STORY POINTS: %d" % pts


func _update_spend_buttons() -> void:
	var has_points: bool = (
		_sp_system.get_current_points() >= 1)
	var status: Dictionary = (
		_sp_system.get_turn_spending_status())

	# Indices match creation order
	# 0=ROLL_TWICE, 1=REROLL, 2=CREDITS, 3=XP, 4=ACTION
	if _spend_buttons.size() >= 5:
		_spend_buttons[0].disabled = not has_points
		_spend_buttons[1].disabled = not has_points
		_spend_buttons[2].disabled = not (
			has_points and status.get(
				"credits_available", true))
		_spend_buttons[3].disabled = not (
			has_points and status.get(
				"xp_available", true))
		_spend_buttons[4].disabled = not (
			has_points and status.get(
				"action_available", true))


func _update_star_rows() -> void:
	for ability: int in _star_rows:
		var row: Dictionary = _star_rows[ability]
		var remaining: int = (
			_stars_system.get_uses_remaining(ability))
		var max_uses: int = (
			_stars_system.get_max_uses(ability))
		var can_use: bool = _stars_system.can_use(ability)

		# Battle-only abilities disabled outside active battle
		var battle_only: bool = ability in [
			StarsSystemClass.StarAbility.DRAMATIC_ESCAPE,
			StarsSystemClass.StarAbility.ITS_TIME_TO_GO]
		if battle_only:
			can_use = false

		row["uses_label"].text = "%d/%d" % [
			remaining, max_uses]

		if can_use:
			row["uses_label"].add_theme_color_override(
				"font_color", COLOR_SUCCESS)
			row["name_label"].add_theme_color_override(
				"font_color", COLOR_TEXT_PRIMARY)
			row["button"].disabled = false
			row["button"].tooltip_text = ""
		elif battle_only and remaining > 0:
			# Has uses but needs battle context
			row["uses_label"].add_theme_color_override(
				"font_color", COLOR_WARNING)
			row["name_label"].add_theme_color_override(
				"font_color", COLOR_TEXT_SECONDARY)
			row["button"].disabled = true
			row["button"].tooltip_text = (
				"Available during battle")
		else:
			row["uses_label"].add_theme_color_override(
				"font_color", COLOR_TEXT_DISABLED)
			row["name_label"].add_theme_color_override(
				"font_color", COLOR_TEXT_DISABLED)
			row["button"].disabled = true
			row["button"].tooltip_text = ""


# ── Signal Handlers ──────────────────────────────────────

func _on_spend_pressed(spend_type: int) -> void:
	if not _sp_system or not _sp_system.can_spend(spend_type):
		return

	var details: Dictionary = {}
	if spend_type == StoryPointSystemClass.SpendType.GET_XP:
		details["needs_character_selection"] = true

	if _sp_system.spend_point(spend_type, details):
		story_point_spent.emit(spend_type, details)
		refresh()


func _on_star_pressed(ability: int) -> void:
	if not _stars_system or not _stars_system.can_use(ability):
		return

	var context: Dictionary = {}
	var result: Dictionary = _stars_system.use_ability(
		ability, context)

	if result.get("success", false):
		star_ability_activated.emit(ability, result)
		refresh()


# ── Styling ──────────────────────────────────────────────

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, 0.97)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)


func _style_spend_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_ELEVATED
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = COLOR_ACCENT_HOVER
	btn.add_theme_stylebox_override("hover", hover)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(
		COLOR_ELEVATED.r, COLOR_ELEVATED.g,
		COLOR_ELEVATED.b, 0.4)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_color_override(
		"font_disabled_color", COLOR_TEXT_DISABLED)


func _style_star_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_ACCENT
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = COLOR_ACCENT_HOVER
	btn.add_theme_stylebox_override("hover", hover)

	var disabled := normal.duplicate()
	disabled.bg_color = COLOR_TEXT_DISABLED
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_color_override(
		"font_disabled_color", Color(0.3, 0.3, 0.3))
