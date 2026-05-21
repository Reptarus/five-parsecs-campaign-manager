## ModeShowcaseCard - the left-half MainMenu info card.
##
## Renders one mode entry from ModeInfoCatalog: cover hero, title + DLC badge,
## tagline, description prose, key features, CTA button. Hover on any mode
## button in MainMenu calls set_mode(id) to swap the displayed mode with a
## short crossfade. The CTA button emits cta_pressed(mode_id, is_unlocked) so
## MainMenu can route to either the existing per-mode handler (unlocked) or the
## store screen (locked).
##
## All visuals built in code, no .tscn dependency. Deep Space theme constants
## sourced from BaseCampaignPanel.
extends PanelContainer

const ModeInfoCatalog = preload("res://src/ui/screens/mainmenu/ModeInfoCatalog.gd")

# Deep Space theme constants (mirror BaseCampaignPanel — duplicated to avoid
# extending it for what's essentially a marketing surface)
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")

const COVER_MAX_HEIGHT := 260

signal cta_pressed(mode_id: String, is_unlocked: bool)

var _current_mode_id: String = ""
var _fade_tween: Tween = null

var _cover: TextureRect
var _title_label: Label
var _dlc_badge: Label
var _tagline_label: Label
var _description: RichTextLabel
var _features_box: VBoxContainer
var _cta_button: Button


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	# Panel chrome
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.bg_color.a = 0.85
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Cover hero - constrained height so it doesn't dominate
	_cover = TextureRect.new()
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cover.custom_minimum_size = Vector2(0, COVER_MAX_HEIGHT)
	_cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_cover)

	# Title row: name + DLC badge
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	root.add_child(title_row)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	_dlc_badge = Label.new()
	_dlc_badge.add_theme_font_size_override("font_size", 12)
	_dlc_badge.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = COLOR_ELEVATED
	badge_style.set_border_width_all(1)
	badge_style.border_color = COLOR_BORDER
	badge_style.set_corner_radius_all(4)
	badge_style.set_content_margin_all(6)
	_dlc_badge.add_theme_stylebox_override("normal", badge_style)
	title_row.add_child(_dlc_badge)

	# Tagline (italic, dim)
	_tagline_label = Label.new()
	_tagline_label.add_theme_font_size_override("font_size", 14)
	_tagline_label.add_theme_color_override("font_color", COLOR_FOCUS)
	_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_tagline_label)

	var sep := HSeparator.new()
	root.add_child(sep)

	# Description (verbatim book copy)
	_description = RichTextLabel.new()
	_description.bbcode_enabled = false
	_description.fit_content = false
	_description.scroll_active = true
	_description.scroll_following = false
	_description.add_theme_font_size_override("normal_font_size", 13)
	_description.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.custom_minimum_size = Vector2(0, 140)
	root.add_child(_description)

	# Features list
	_features_box = VBoxContainer.new()
	_features_box.add_theme_constant_override("separation", 4)
	root.add_child(_features_box)

	# CTA button
	_cta_button = Button.new()
	_cta_button.custom_minimum_size = Vector2(0, 48)
	_cta_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cta_button.add_theme_font_size_override("font_size", 16)
	_apply_cta_style(true)
	_cta_button.pressed.connect(_on_cta_pressed)
	root.add_child(_cta_button)


func _apply_cta_style(unlocked: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_ACCENT if unlocked else COLOR_WARNING
	s.set_border_width_all(1)
	s.border_color = COLOR_FOCUS if unlocked else COLOR_WARNING
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	_cta_button.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = COLOR_ACCENT_HOVER if unlocked else Color("#E69035")
	_cta_button.add_theme_stylebox_override("hover", h)
	_cta_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)


## Public: swap to a different mode. Crossfades unless instant=true.
func set_mode(mode_id: String, instant: bool = false) -> void:
	if mode_id == _current_mode_id and _cover and _cover.texture:
		return
	if not _cover:
		# _ready hasn't run yet; defer
		await ready
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if instant:
		_populate(mode_id)
		modulate.a = 1.0
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.10)
	_fade_tween.tween_callback(_populate.bind(mode_id))
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.20)


func _populate(mode_id: String) -> void:
	var info: Dictionary = ModeInfoCatalog.get_mode(mode_id)
	if info.is_empty():
		push_warning("ModeShowcaseCard: unknown mode '%s'" % mode_id)
		return
	_current_mode_id = mode_id

	# Cover
	var cover_path: String = info.get("cover_path", "")
	if ResourceLoader.exists(cover_path):
		var tex = load(cover_path)
		if tex is Texture2D:
			_cover.texture = tex
		else:
			_cover.texture = null
	else:
		_cover.texture = null

	# Title + tagline
	_title_label.text = info.get("display_name", "")
	_tagline_label.text = info.get("tagline", "")

	# DLC badge
	var required_dlc: String = ModeInfoCatalog.get_required_dlc(mode_id)
	var unlocked: bool = ModeInfoCatalog.is_unlocked(mode_id)
	if required_dlc.is_empty():
		_dlc_badge.text = "Included"
		_dlc_badge.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif unlocked:
		_dlc_badge.text = "DLC Owned"
		_dlc_badge.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_dlc_badge.text = "DLC Required"
		_dlc_badge.add_theme_color_override("font_color", COLOR_WARNING)

	# Description (verbatim book copy)
	_description.text = info.get("description", "")

	# Features list
	for child in _features_box.get_children():
		child.queue_free()
	var features: Array = info.get("key_features", [])
	for feat in features:
		var lbl := Label.new()
		lbl.text = "  •  %s" % str(feat)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_features_box.add_child(lbl)

	# CTA
	_cta_button.text = ModeInfoCatalog.get_cta_label(mode_id)
	_apply_cta_style(unlocked)


func get_current_mode_id() -> String:
	return _current_mode_id


func is_current_mode_unlocked() -> bool:
	return ModeInfoCatalog.is_unlocked(_current_mode_id)


func _on_cta_pressed() -> void:
	cta_pressed.emit(_current_mode_id, is_current_mode_unlocked())
