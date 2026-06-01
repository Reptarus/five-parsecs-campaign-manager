## NarrativeScreen — full-screen King-of-Dragon-Pass-style narrative event
## display. Takes over the screen, hides game chrome, renders an
## illustration + narrative text + optional advisor commentary + choices.
##
## Architecture (per docs/design/narrative_system_design.md §2 revised):
##   BackgroundDim (ColorRect, blocks input)
##   IllustrationFrame (Control, top 55%)
##     GradientFallback (ColorRect, always present — fallback when SceneStage empty)
##     SceneStage (the only rendering path for layered/flat art)
##   NarrativePanel (PanelContainer, bottom 45%)
##     EventTitle / NarrativeText / AdvisorRow / Briefing / TurnRestrictions
##     BonusObjective / ChoicesContainer / OutcomePanel
##   SkipButton (Button, top-right)
##
## Phase 1 scaffold: gradient ColorRect fallback when scene_id unresolved.
## Story Track use: single "Continue to Battle" choice dismisses immediately
## (no outcome panel rendered for inevitable single-choice events).
##
## Path-loaded (no class_name) per docs/sop/component-patterns.md.
## Extends CanvasLayer (layer 95) so it always renders above MainMenu's
## chrome (Layer 80 PersistentResourceBar, Layer 90 NotificationManager)
## and below TransitionManager (Layer 100). Internal hierarchy lives under
## a Control child (`_root`) at PRESET_FULL_RECT.
extends CanvasLayer

const OVERLAY_LAYER := 95

const NarrativeTextGenerator = preload(
	"res://src/ui/screens/narrative/NarrativeTextGenerator.gd")
const AdvisorSystem = preload(
	"res://src/ui/screens/narrative/AdvisorSystem.gd")
const NarrativeChoiceButtonClass = preload(
	"res://src/ui/screens/narrative/NarrativeChoiceButton.gd")
const SceneStageScript = preload(
	"res://src/ui/screens/narrative/SceneStage.gd")
const SceneAtmosphereLayerScript = preload(
	"res://src/ui/screens/narrative/SceneAtmosphereLayer.gd")

# Deep Space theme constants (mirroring BaseCampaignPanel — local copies so
# this component has no inheritance dependency).
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_WARNING := Color("#D97706")
const COLOR_SUCCESS := Color("#10B981")
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const ILLUSTRATION_RATIO := 0.55  # top 55% of screen
const PORTRAIT_SIZE := 64

signal choice_made(choice_id: int, outcome: Dictionary)
signal narrative_completed(result: Dictionary)
signal skip_requested()

# State
var _event_data: Dictionary = {}
var _context: Dictionary = {}
var _last_choice_id: int = -1
var _last_outcome: Dictionary = {}

# UI references
var _root: Control = null
var _bg_dim: ColorRect = null
var _illustration_frame: Control = null
var _gradient_fallback: ColorRect = null
var _scene_stage: Control = null
var _atmosphere_layer: Control = null
var _narrative_panel: PanelContainer = null
var _event_title: Label = null
var _narrative_text: RichTextLabel = null
var _advisor_row: HBoxContainer = null
var _advisor_portrait: TextureRect = null
var _advisor_portrait_fallback: Label = null
var _advisor_name_lbl: Label = null
var _advisor_quote_lbl: RichTextLabel = null
var _briefing_header: Label = null
var _briefing_text: RichTextLabel = null
var _restrictions_text: RichTextLabel = null
var _bonus_panel: PanelContainer = null
var _bonus_text: RichTextLabel = null
var _choices_container: VBoxContainer = null
var _outcome_panel: VBoxContainer = null
var _outcome_text: RichTextLabel = null
var _continue_button: Button = null
var _skip_button: Button = null


func _ready() -> void:
	layer = OVERLAY_LAYER
	visible = false
	_build_ui()
	# Safety-net chrome restore — fires while still in tree (unlike
	# tree_exited which fires AFTER detach, breaking /root lookups per
	# the CLAUDE.md "detached nodes + absolute paths" gotcha).


func _build_ui() -> void:
	# Root Control — holds the entire surface, fills the viewport.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks
	add_child(_root)

	# Background dim — full-screen ColorRect that eats input
	_bg_dim = ColorRect.new()
	_bg_dim.color = Color(0, 0, 0, 0.85)
	_bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bg_dim)

	# Illustration frame (top 55%)
	_illustration_frame = Control.new()
	_illustration_frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_illustration_frame.anchor_bottom = ILLUSTRATION_RATIO
	_illustration_frame.offset_bottom = 0
	_illustration_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_illustration_frame)

	# Gradient fallback (always present, behind SceneStage)
	_gradient_fallback = ColorRect.new()
	_gradient_fallback.color = COLOR_BASE
	_gradient_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gradient_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration_frame.add_child(_gradient_fallback)

	# SceneStage (on top of gradient, may render nothing if scene_id missing)
	_scene_stage = SceneStageScript.new()
	_scene_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration_frame.add_child(_scene_stage)

	# Atmosphere layer (sibling above SceneStage, below UI). Renders ambient
	# particle effects driven by world traits or art_tag context. Sits inside
	# the illustration frame so it inherits the 55% clip and never bleeds into
	# the narrative panel. See docs/research/scene-stage-atmosphere.md.
	_atmosphere_layer = SceneAtmosphereLayerScript.new()
	_atmosphere_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmosphere_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration_frame.add_child(_atmosphere_layer)

	# Narrative panel (bottom 45%)
	_narrative_panel = PanelContainer.new()
	_narrative_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_narrative_panel.anchor_top = ILLUSTRATION_RATIO
	_narrative_panel.offset_top = 0
	_narrative_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_narrative_panel(_narrative_panel)
	_root.add_child(_narrative_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_narrative_panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", SPACING_XL)
	margin.add_theme_constant_override("margin_right", SPACING_XL)
	margin.add_theme_constant_override("margin_top", SPACING_LG)
	margin.add_theme_constant_override("margin_bottom", SPACING_LG)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_MD)
	margin.add_child(vbox)

	_event_title = Label.new()
	_event_title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_event_title.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(_event_title)

	_narrative_text = RichTextLabel.new()
	_narrative_text.bbcode_enabled = true
	_narrative_text.fit_content = true
	_narrative_text.scroll_active = false
	_narrative_text.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_MD)
	_narrative_text.add_theme_color_override(
		"default_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_narrative_text)

	# Advisor row (optional, hidden by default)
	_advisor_row = HBoxContainer.new()
	_advisor_row.add_theme_constant_override("separation", SPACING_MD)
	_advisor_row.visible = false
	vbox.add_child(_advisor_row)

	_advisor_portrait = TextureRect.new()
	_advisor_portrait.custom_minimum_size = Vector2(
		PORTRAIT_SIZE, PORTRAIT_SIZE)
	_advisor_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_advisor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_advisor_row.add_child(_advisor_portrait)

	_advisor_portrait_fallback = Label.new()
	_advisor_portrait_fallback.custom_minimum_size = Vector2(
		PORTRAIT_SIZE, PORTRAIT_SIZE)
	_advisor_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advisor_portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_advisor_portrait_fallback.add_theme_font_size_override(
		"font_size", FONT_SIZE_XL)
	_advisor_portrait_fallback.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_advisor_portrait_fallback.visible = false
	_advisor_row.add_child(_advisor_portrait_fallback)

	var advisor_vbox := VBoxContainer.new()
	advisor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advisor_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	advisor_vbox.add_theme_constant_override("separation", SPACING_XS)
	_advisor_row.add_child(advisor_vbox)

	_advisor_name_lbl = Label.new()
	_advisor_name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_advisor_name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	advisor_vbox.add_child(_advisor_name_lbl)

	_advisor_quote_lbl = RichTextLabel.new()
	_advisor_quote_lbl.bbcode_enabled = true
	_advisor_quote_lbl.fit_content = true
	_advisor_quote_lbl.scroll_active = false
	_advisor_quote_lbl.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_MD)
	_advisor_quote_lbl.add_theme_color_override(
		"default_color", COLOR_TEXT_PRIMARY)
	advisor_vbox.add_child(_advisor_quote_lbl)

	# Briefing section (optional)
	_briefing_header = Label.new()
	_briefing_header.text = "THE BRIEFING"
	_briefing_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_briefing_header.add_theme_color_override("font_color", COLOR_WARNING)
	_briefing_header.visible = false
	vbox.add_child(_briefing_header)

	_briefing_text = RichTextLabel.new()
	_briefing_text.bbcode_enabled = true
	_briefing_text.fit_content = true
	_briefing_text.scroll_active = false
	_briefing_text.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_MD)
	_briefing_text.add_theme_color_override(
		"default_color", COLOR_TEXT_PRIMARY)
	_briefing_text.visible = false
	vbox.add_child(_briefing_text)

	# Turn restrictions (optional)
	_restrictions_text = RichTextLabel.new()
	_restrictions_text.bbcode_enabled = true
	_restrictions_text.fit_content = true
	_restrictions_text.scroll_active = false
	_restrictions_text.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)
	_restrictions_text.visible = false
	vbox.add_child(_restrictions_text)

	# Bonus objective (optional)
	_bonus_panel = PanelContainer.new()
	_style_bonus_panel(_bonus_panel)
	_bonus_panel.visible = false
	vbox.add_child(_bonus_panel)

	_bonus_text = RichTextLabel.new()
	_bonus_text.bbcode_enabled = true
	_bonus_text.fit_content = true
	_bonus_text.scroll_active = false
	_bonus_text.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)
	_bonus_text.add_theme_color_override("default_color", COLOR_SUCCESS)
	_bonus_panel.add_child(_bonus_text)

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_choices_container)

	# Outcome panel (hidden until a choice is made, kept for future phases)
	_outcome_panel = VBoxContainer.new()
	_outcome_panel.add_theme_constant_override("separation", SPACING_MD)
	_outcome_panel.visible = false
	vbox.add_child(_outcome_panel)

	_outcome_text = RichTextLabel.new()
	_outcome_text.bbcode_enabled = true
	_outcome_text.fit_content = true
	_outcome_text.scroll_active = false
	_outcome_text.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_MD)
	_outcome_panel.add_child(_outcome_text)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size.y = 48
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue_button.pressed.connect(_on_continue_pressed)
	_outcome_panel.add_child(_continue_button)

	# Skip button (top-right corner overlay). Styled with a visible border so
	# users see an exit affordance even when the Continue button below is the
	# obvious primary action. Was previously `flat=true` with secondary-color
	# text — invisible against the dim background at small sizes.
	_skip_button = Button.new()
	_skip_button.text = "Skip ✕"
	_skip_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_skip_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var sb_skip := StyleBoxFlat.new()
	sb_skip.bg_color = COLOR_ELEVATED
	sb_skip.set_border_width_all(1)
	sb_skip.border_color = COLOR_BORDER
	sb_skip.set_corner_radius_all(4)
	sb_skip.set_content_margin_all(SPACING_SM)
	_skip_button.add_theme_stylebox_override("normal", sb_skip)
	var sb_skip_hover := sb_skip.duplicate()
	sb_skip_hover.border_color = COLOR_FOCUS
	sb_skip_hover.set_border_width_all(2)
	_skip_button.add_theme_stylebox_override("hover", sb_skip_hover)
	_skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.offset_left = -120
	_skip_button.offset_top = 12
	_skip_button.offset_right = -12
	_skip_button.offset_bottom = 52
	_skip_button.pressed.connect(_on_skip_pressed)
	_root.add_child(_skip_button)


func _style_narrative_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_ELEVATED
	sb.set_border_width_all(1)
	sb.border_color = COLOR_BORDER
	panel.add_theme_stylebox_override("panel", sb)


func _style_bonus_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BASE
	sb.set_border_width_all(1)
	sb.border_color = COLOR_SUCCESS
	sb.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", sb)


## Returns whether the screen is currently presenting an event.
func is_presenting() -> bool:
	return visible


## Main entry point — populates the screen and shows it.
## event_data shape per docs/plans/narrative-screen-phase-1.md.
func present(event_data: Dictionary, context: Dictionary) -> void:
	_event_data = event_data
	_context = context
	_last_choice_id = -1
	_last_outcome = {}
	_hide_chrome()
	_populate_illustration()
	_populate_character_slots()
	_populate_narrative_text()
	_populate_advisor()
	_populate_briefing()
	_populate_restrictions()
	_populate_bonus()
	_populate_choices()
	_outcome_panel.visible = false
	_choices_container.visible = true
	visible = true


## Hide the screen, restore chrome, free self.
func dismiss() -> void:
	_restore_chrome()
	visible = false
	queue_free()


# ── Population helpers ─────────────────────────────────────────────

func _populate_illustration() -> void:
	var art_tag: String = str(_event_data.get("art_tag", ""))
	var scene_id: String = str(_event_data.get("scene_id", art_tag))
	# Drive the atmosphere layer regardless of whether a scene manifest
	# resolves — even a gradient-fallback scene gets weather (snow on
	# frozen worlds, dust in interiors, smoke over the battle aftermath).
	_apply_atmosphere(art_tag)
	if scene_id.is_empty():
		return
	# Try SceneStage with the scene_id. If it doesn't resolve to a
	# manifest, SceneStage logs a push_warning and renders nothing —
	# the gradient_fallback ColorRect underneath remains visible.
	if _scene_stage and _scene_stage.has_method("set_scene"):
		_scene_stage.set_scene(scene_id)


func _apply_atmosphere(art_tag: String) -> void:
	if _atmosphere_layer == null:
		return
	var traits_value = _context.get("world_traits", [])
	var traits: Array = traits_value if traits_value is Array else []
	if _atmosphere_layer.has_method("set_atmosphere_for_world_traits"):
		_atmosphere_layer.set_atmosphere_for_world_traits(traits, art_tag)


## Composite the player's crew into the scene's character slots (if any). The
## captain takes the "hero" slot; remaining slots are filled by event-relevant
## crew via AdvisorSystem's role logic, deduped, with roster-order fallback.
## No-op when the scene declares no slots or there is no crew in context.
func _populate_character_slots() -> void:
	if not _scene_stage or not _scene_stage.has_method("get_character_slots"):
		return
	var slots: Array = _scene_stage.get_character_slots()
	if slots.is_empty():
		return
	var crew_value = _context.get("crew", [])
	var crew: Array = crew_value if crew_value is Array else []
	if crew.is_empty():
		return

	var used: Dictionary = {}
	var assignments: Array = []
	var hero_slot: String = _cs_hero_slot_id(slots)
	var captain = _cs_find_captain(crew)
	if captain != null and hero_slot != "":
		assignments.append(_cs_assignment(hero_slot, captain))
		used[_cs_id(captain)] = true

	for slot in slots:
		if not (slot is Dictionary):
			continue
		var sid: String = str(slot.get("id", ""))
		if sid == "" or sid == hero_slot:
			continue
		var member = _cs_pick_crew(str(slot.get("role", "")), crew, used)
		if member == null:
			continue
		assignments.append(_cs_assignment(sid, member))
		used[_cs_id(member)] = true

	if not assignments.is_empty():
		_scene_stage.set_character_slots(assignments)


func _cs_find_captain(crew: Array):
	for m in crew:
		if m != null and _cs_bool(m, "is_captain"):
			return m
	return crew[0] if not crew.is_empty() else null


func _cs_hero_slot_id(slots: Array) -> String:
	for slot in slots:
		if slot is Dictionary and str(slot.get("id", "")) == "hero":
			return "hero"
	if not slots.is_empty() and slots[0] is Dictionary:
		return str(slots[0].get("id", ""))
	return ""


func _cs_pick_crew(role: String, crew: Array, used: Dictionary):
	if not role.is_empty():
		var advisor = AdvisorSystem.select_advisor(role, crew, "")
		if advisor != null and not used.has(_cs_id(advisor)):
			return advisor
	for m in crew:
		if m != null and not used.has(_cs_id(m)):
			return m
	return null


func _cs_assignment(slot_id: String, member) -> Dictionary:
	return {
		"slot_id": slot_id,
		"species_id": _cs_str(member, "species_id"),
		"character_id": _cs_id(member),
	}


func _cs_id(member) -> String:
	return _cs_str(member, "character_id")


func _cs_str(obj, prop: String) -> String:
	if obj != null and prop in obj:
		return str(obj.get(prop))
	return ""


func _cs_bool(obj, prop: String) -> bool:
	if obj != null and prop in obj:
		return bool(obj.get(prop))
	return false


func _populate_narrative_text() -> void:
	var title: String = str(_event_data.get("title", ""))
	_event_title.text = title
	var composed: String = NarrativeTextGenerator.compose_full_text(
		_event_data, _context)
	_narrative_text.text = composed


func _populate_advisor() -> void:
	var role: String = str(_event_data.get("advisor_role", ""))
	if role.is_empty():
		var art_tag: String = str(_event_data.get("art_tag", ""))
		role = AdvisorSystem.infer_role_from_art_tag(art_tag)
	if role.is_empty():
		_advisor_row.visible = false
		return

	var crew_value = _context.get("crew", [])
	var crew: Array = crew_value if crew_value is Array else []
	# AdvisorSystem.select_advisor returns Variant — crew members can be
	# Character resources OR Dictionary shapes. Don't constrain to Object.
	var advisor = AdvisorSystem.select_advisor(
		role, crew, str(_event_data.get("art_tag", "")))
	if advisor == null:
		_advisor_row.visible = false
		return

	var mood: String = str(_event_data.get("advisor_mood", "neutral"))
	var quote: String = AdvisorSystem.generate_quote(advisor, role, mood)
	if quote.is_empty():
		_advisor_row.visible = false
		return

	_apply_advisor_portrait(advisor)
	_advisor_name_lbl.text = "%s, %s Advisor" % [
		_advisor_display_name(advisor),
		role.capitalize()]
	_advisor_quote_lbl.text = "[i]\"%s\"[/i]" % quote
	_advisor_row.visible = true


func _apply_advisor_portrait(advisor) -> void:
	var pp: String = ""
	# `has_method` only exists on Object; guard for Dict crew members.
	if advisor is Object and advisor.has_method("get_portrait"):
		pp = str(advisor.get_portrait())
	elif "portrait_path" in advisor:
		pp = str(advisor.get("portrait_path"))

	var tex: Texture2D = null
	# Guard against missing-asset errors: ResourceLoader.exists() for res://,
	# FileAccess.file_exists() for user:// or absolute paths. Without this
	# guard, load() and Image.load() emit errors when the default-portrait
	# path returned by get_portrait() doesn't ship as a real asset.
	if pp.begins_with("res://"):
		if ResourceLoader.exists(pp):
			var res = load(pp)
			if res is Texture2D:
				tex = res
	elif not pp.is_empty():
		if FileAccess.file_exists(pp):
			var img := Image.new()
			if img.load(pp) == OK:
				tex = ImageTexture.create_from_image(img)

	if tex:
		_advisor_portrait.texture = tex
		_advisor_portrait.visible = true
		_advisor_portrait_fallback.visible = false
	else:
		# Colored-initial fallback (mirror CharacterCard pattern)
		_advisor_portrait.texture = null
		_advisor_portrait.visible = false
		var name: String = _advisor_display_name(advisor)
		var initial: String = name.substr(0, 1).to_upper() if not name.is_empty() else "?"
		_advisor_portrait_fallback.text = initial
		var hue: float = float(name.hash() % 8) / 8.0
		var bg_color: Color = Color.from_hsv(hue, 0.5, 0.4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg_color
		sb.set_corner_radius_all(int(PORTRAIT_SIZE / 2.0))
		_advisor_portrait_fallback.add_theme_stylebox_override(
			"normal", sb)
		_advisor_portrait_fallback.visible = true


func _advisor_display_name(advisor) -> String:
	# `has_method` only exists on Object; guard for Dict crew members.
	if advisor is Object and advisor.has_method("get_display_name"):
		return str(advisor.get_display_name())
	for prop in ["character_name", "name"]:
		if prop in advisor:
			var n = advisor.get(prop)
			if n != null and str(n).length() > 0:
				return str(n)
	return "Crew Member"


func _populate_briefing() -> void:
	var briefing: String = str(_event_data.get("briefing_text", ""))
	if briefing.is_empty():
		_briefing_header.visible = false
		_briefing_text.visible = false
		return
	_briefing_header.visible = true
	_briefing_text.visible = true
	_briefing_text.text = briefing


func _populate_restrictions() -> void:
	var restrictions_value = _event_data.get("turn_restrictions", [])
	var restrictions: Array = restrictions_value if restrictions_value is Array else []
	if restrictions.is_empty():
		_restrictions_text.visible = false
		return
	var lines: Array[String] = []
	lines.append("[b][color=#D97706]Campaign Turn Modifications:[/color][/b]")
	for r in restrictions:
		lines.append("  • %s" % str(r))
	_restrictions_text.text = "\n".join(lines)
	_restrictions_text.visible = true


func _populate_bonus() -> void:
	var bonus_value = _event_data.get("bonus_objective", {})
	var bonus: Dictionary = bonus_value if bonus_value is Dictionary else {}
	if bonus.is_empty():
		_bonus_panel.visible = false
		return
	var desc: String = str(bonus.get("description", ""))
	var reward: String = str(bonus.get("reward", ""))
	if desc.is_empty():
		_bonus_panel.visible = false
		return
	var text := "[b]☆ BONUS OBJECTIVE[/b]\n  %s" % desc
	if not reward.is_empty():
		text += "\n  → %s" % reward
	_bonus_text.text = text
	_bonus_panel.visible = true


func _populate_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()
	var choices_value = _event_data.get("choices", [])
	var choices: Array = choices_value if choices_value is Array else []
	if choices.is_empty():
		# Informational event — synthesize a single Continue choice.
		var fallback_btn := NarrativeChoiceButtonClass.new()
		fallback_btn.choice_pressed.connect(_on_choice_pressed)
		_choices_container.add_child(fallback_btn)
		fallback_btn.setup({"id": -1, "label": "Continue", "hint": ""})
		return
	for choice in choices:
		if not choice is Dictionary:
			continue
		var btn := NarrativeChoiceButtonClass.new()
		btn.choice_pressed.connect(_on_choice_pressed)
		_choices_container.add_child(btn)
		btn.setup(choice)


# ── Chrome management ─────────────────────────────────────────────

func _hide_chrome() -> void:
	var bar = get_node_or_null("/root/PersistentResourceBar")
	if bar and bar.has_method("hide_bar"):
		bar.hide_bar()


func _restore_chrome() -> void:
	var bar = get_node_or_null("/root/PersistentResourceBar")
	if bar and bar.has_method("show_bar"):
		bar.show_bar()


func _exit_tree() -> void:
	# Belt + suspenders: ensure chrome restore even on indirect dismissal
	# (parent scene change, queue_free from outside). Runs WHILE still in
	# tree so /root autoload lookups still work — unlike tree_exited which
	# fires AFTER detach and breaks absolute-path access.
	_restore_chrome()


# ── Signal handlers ──────────────────────────────────────────────

func _on_choice_pressed(choice_id: int) -> void:
	_last_choice_id = choice_id
	_last_outcome = _resolve_outcome(choice_id)
	choice_made.emit(choice_id, _last_outcome)

	# Phase 1 / Story Track behavior: if the outcome has no text, dismiss
	# immediately (inevitable single-choice events). If outcome.text is
	# populated, show the outcome panel and wait for Continue (future phases).
	var outcome_text: String = str(_last_outcome.get("text", ""))
	if outcome_text.is_empty():
		_dispatch_completion()
		return
	_show_outcome(outcome_text)


func _resolve_outcome(choice_id: int) -> Dictionary:
	# Phase 1: look up an inline outcome on the choice itself, else empty.
	# Phase 2+: integrating phase panels can override by passing outcomes
	# via a callback or by patching the event_data.choices[i].outcome field.
	var choices_value = _event_data.get("choices", [])
	var choices: Array = choices_value if choices_value is Array else []
	for choice in choices:
		if choice is Dictionary and int(choice.get("id", 0)) == choice_id:
			var inline_outcome = choice.get("outcome", {})
			if inline_outcome is Dictionary:
				return inline_outcome
	return {}


func _show_outcome(text: String) -> void:
	_choices_container.visible = false
	_outcome_text.text = text
	_outcome_panel.visible = true


func _on_continue_pressed() -> void:
	_dispatch_completion()


func _dispatch_completion() -> void:
	var result := {
		"choice_id": _last_choice_id,
		"outcome": _last_outcome,
		"event_id": str(_event_data.get("id", "")),
	}
	narrative_completed.emit(result)
	dismiss()


func _on_skip_pressed() -> void:
	skip_requested.emit()
	dismiss()
