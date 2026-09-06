class_name ItemChoicePopup
extends Window

## Item Choice Popup - Crew Task Reward Picker
## Shows when a task result gives the player a choice between items (e.g., "Handgun OR Blade")
## Follows Deep Space theme and AssignEquipmentComponent popup pattern

signal item_chosen(item_name: String)

# Deep Space theme constants (matching BaseCampaignPanel)
const COLOR_BASE := UIColors.COLOR_PRIMARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const TOUCH_TARGET_MIN := 48
## T11-42. The popup used to hard-fix its width at MIN_WIDTH and never widen for
## content, which is what pushed the option labels outside the visible rect.
## MAX_WIDTH matches the cap the rest of this codebase uses for centred overlays
## (560; the enemy-generation wizard is the one 700 exception). Both are in DESIGN
## px under the square-1080 `canvas_items`+`expand` base, where the design width is
## >= 1080 in BOTH orientations - so 560 cannot run off a phone the way T11-05 did.
const MIN_WIDTH := 380
const MAX_WIDTH := 560

func _init() -> void:
	title = "Choose Reward"
	size = Vector2i(MIN_WIDTH, 100)  # both axes re-fit in show_choices()
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(_on_close_requested)

func show_choices(result_name: String, options: Array,
		heading: String = "Choose Your Reward") -> void:
	## `heading` defaults to the original reward wording so the six existing
	## callers are unaffected. It exists because this popup is also the right
	## component for a mandatory PENALTY choice (Compendium p.137 illegal salvage:
	## pay credits / hand over salvage / gain an Enforcer Rival), where calling it
	## a reward would be actively misleading. Set `.title` on the Window before
	## calling if the titlebar should change too.
	## Build the popup UI and display it
	# Calculate height: header(~60) + description(~30) + separator(~10) + buttons(56 each) + padding(32)
	# ⚠ T11-42: this is now only a FLOOR. Wrapping the subtitle makes its height
	# depend on how many lines the prose takes at this width, which a constant
	# cannot know - so _fit_height_to_content() corrects it once laid out.
	var estimated_height: int = 130 + (options.size() * 64)
	size = Vector2i(MIN_WIDTH, estimated_height)

	# Background panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title_label := Label.new()
	title_label.text = heading
	title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(18))
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Subtitle (result name)
	if not result_name.is_empty():
		var subtitle := Label.new()
		subtitle.text = result_name
		subtitle.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
		subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# T11-42 - THE fix, and it is this line rather than anything on the
		# buttons. `result_name` is prose (CampaignEventEffects passes a ~100-char
		# p.126 prompt), and a Label with autowrap OFF reports the WHOLE string as
		# its minimum width: measured 609 px against this Window's fixed 380.
		# Being the widest child it set the VBox minimum, every SIZE_EXPAND_FILL
		# button was stretched to 577 px, and their CENTRED labels were pushed
		# clean past the window's right clip - three blank blue buttons, on the
		# one screen whose entire purpose is presenting a p.126 choice.
		# The buttons' own labels needed only 363 px and always fitted; the
		# overflow figure named the consequence, not the cause (T11-18).
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subtitle)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	# Choice buttons
	var button_container := VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(button_container)

	# T11-42 second-order guard. Correcting the width defect by wrapping the
	# subtitle turns its height into a content-dependent value, and the constant
	# above would then clip the buttons off the BOTTOM - trading a horizontal
	# defect for a vertical one, which is exactly what the T11-22 correction did
	# before it was caught. Deferred because a freshly built Control reports its
	# real minimum only once the layout has run.
	call_deferred("_fit_to_content")

	for option_name in options:
		var btn := Button.new()
		btn.text = str(option_name)
		# T11-42 regression guard, not the fix. Wrapping the subtitle above is what
		# restores these labels; this stops a future long OPTION string from
		# re-widening the container the same way. Ellipsis over silent clipping so
		# a truncated option still reads as truncated.
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Normal style
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = COLOR_ACCENT
		btn_normal.set_corner_radius_all(4)
		btn_normal.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_normal)

		# Hover style
		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = COLOR_ACCENT_HOVER
		btn_hover.set_corner_radius_all(4)
		btn_hover.set_content_margin_all(8)
		btn_hover.border_color = COLOR_FOCUS
		btn_hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", btn_hover)

		# Pressed style
		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = COLOR_ELEVATED
		btn_pressed.set_corner_radius_all(4)
		btn_pressed.set_content_margin_all(8)
		btn_pressed.border_color = COLOR_FOCUS
		btn_pressed.set_border_width_all(2)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		# Text color
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(16))

		btn.pressed.connect(_on_option_selected.bind(str(option_name)))
		button_container.add_child(btn)

	popup_centered()

func _on_option_selected(option_name: String) -> void:
	item_chosen.emit(option_name)
	queue_free()

## Grow the popup to whatever its content actually needs, on BOTH axes.
##
## GROW ONLY. Shrinking here would fight the floor computed above and could hide a
## button, and the floor is the conservative number of the two.
##
## ⚠ Width and height are corrected for OPPOSITE reasons and both are needed.
## Width: an option label longer than MIN_WIDTH would otherwise be ellipsised, and
## this popup presents a Core Rules p.126 CHOICE whose option text carries the
## effect - "Old nemesis (persistent, +1 enemies)" trimmed mid-clause is a worse
## failure than it looks. Height: wrapping the subtitle (see show_choices) made its
## height depend on the line count, which the constant cannot know - and clipping
## the buttons off the BOTTOM instead is exactly the trade the T11-22 correction
## made before it was caught.
func _fit_to_content() -> void:
	var needed: Vector2 = get_contents_minimum_size()
	var w: int = clampi(int(ceil(needed.x)), MIN_WIDTH, MAX_WIDTH)
	var h: int = maxi(size.y, int(ceil(needed.y)))
	if w == size.x and h == size.y:
		return
	size = Vector2i(w, h)
	# The subtitle wraps, so a WIDER window needs FEWER lines and a narrower one
	# more. Re-measure once at the settled width rather than trusting a height
	# computed against the previous one.
	await get_tree().process_frame
	# The popup is modal and will not normally be freed inside one frame, but a
	# coroutine that resumes onto a freed Window errors rather than no-ops.
	if not is_inside_tree():
		return
	var settled: Vector2 = get_contents_minimum_size()
	if settled.y > float(size.y):
		size = Vector2i(size.x, int(ceil(settled.y)))


func _on_close_requested() -> void:
	# Player must choose — don't allow closing without a selection
	pass
