class_name ScreenChrome
extends RefCounted

## Shared screen chrome — the parts of the Library's look that are NODES rather
## than styles.
##
## ── DIVISION OF LABOUR ───────────────────────────────────────────────────────
## Anything that is purely "what does this control look like" belongs in
## sci_fi_theme.tres as a base type or a type variation, because a .tscn can adopt
## it with one `theme_type_variation` property and no code at all. What a theme
## CANNOT do is build a node tree, decide which container to wrap, or call an
## autoload. That is this file.
##
##   theme          -> Button/PanelContainer/LineEdit looks; NavCard; SectionCard
##   DialogStyles   -> which button variation a button gets
##   ScreenChrome   -> header rows, section cards, page plumbing, back navigation
##
## ── WHY STATICS ON A RefCounted ──────────────────────────────────────────────
## The screens that need this have four different ancestors (Control,
## CampaignScreenBase, FiveParsecsCampaignPanel, and one path-string extend), so
## there is no single base class to hang it on — the same conclusion
## SettingsOverlay.reserve_band_on() reached and documented. DialogStyles proves
## the pattern works from every ancestor, including path-extending panels.
##
## Autoloads are only ever touched through a guarded get_node_or_null() INSIDE a
## function body, never at parse time: an autoload cannot be resolved while global
## class_names are still being registered, and a detached node (a gdUnit test
## instantiating a screen with .new()) cannot resolve an absolute path at all.

const PortraitChromeScript := preload("res://src/ui/components/base/PortraitChrome.gd")
const ShortScreenScrollScript := preload("res://src/ui/components/base/ShortScreenScroll.gd")

## Node names, so a screen can find what was built for it without keeping a
## reference, and so a second call can recognise its own work.
const HEADER_NAME := "ScreenHeader"
const BACK_NAME := "BackButton"
const TITLE_NAME := "TitleLabel"
const CONTEXT_NAME := "ContextLabel"
const BACKGROUND_NAME := "PageBackground"


# ============================================================================
# Type scale
# ============================================================================

## Resolve a design token (UIColors.FONT_SIZE_*) to the size this screen should
## actually draw at.
##
## ── WHY EVERY OVERRIDE HAS TO GO THROUGH HERE ────────────────────────────────
## ResponsiveManager rescales the sizes stored in sci_fi_theme.tres, so anything
## that just inherits the theme already responds to screen size. But a control
## with add_theme_font_size_override() is invisible to the theme system for good
## — and this app had 990 of those in non-battle UI against 208 that asked for a
## responsive size. That is why type looked identical on a 360dp phone and a
## 1440px desktop: the theme was scaling, and almost nothing was listening.
##
## Wrapping the token at the call site keeps the design tokens as plain consts
## (they are the authored ladder, and must stay comparable) while making the
## VALUE that reaches the control depend on the current breakpoint.
##
## Safe from anywhere: a static has no `self`, so the autoload is reached through
## the main loop's root, and every failure path returns the token unchanged.
static func font_size(base: int) -> int:
	var loop := Engine.get_main_loop()
	if loop == null:
		return base
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return base
	var rm := tree.root.get_node_or_null(NodePath("/root/ResponsiveManager"))
	if rm != null and rm.has_method("get_responsive_font_size"):
		return int(rm.get_responsive_font_size(base))
	return base


# ============================================================================
# Header
# ============================================================================

## The Library's header row: [< Back] [Title] [context].
##
## HFlowContainer, not HBox, and that is load-bearing: on a 360dp phone the three
## items do not fit on one line, and a flow container wraps them onto a second
## line instead of clipping the title. A FlowContainer ignores main-axis expand,
## which is why the title is NOT expand-filled here — an expanding child would
## force the context label to wrap even on a desktop.
static func build_header(title: String, back_callable: Callable,
		context_text: String = "") -> HFlowContainer:
	var header := HFlowContainer.new()
	header.name = HEADER_NAME
	header.add_theme_constant_override("h_separation", UIColors.SPACING_MD)
	header.add_theme_constant_override("v_separation", UIColors.SPACING_XS)

	var back := Button.new()
	back.name = BACK_NAME
	back.text = "< Back"
	DialogStyles.style_back_button(back)
	if back_callable.is_valid():
		back.pressed.connect(back_callable)
	header.add_child(back)

	var title_label := Label.new()
	title_label.name = TITLE_NAME
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_XL))
	title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_label)

	if not context_text.is_empty():
		header.add_child(_build_context_label(context_text))
	return header


## Restyle a header that already exists as .tscn nodes.
##
## The manager screens are scene-built, so their Back button and title Label are
## already in the tree with signals wired. Rebuilding the row in code would mean
## re-wiring all of that; this just makes the existing nodes look right. Moving
## Back in front of the title is a node-order change and stays a .tscn edit.
static func adopt_header(back: Button, title: Label, context: Label = null) -> void:
	if back != null:
		if back.text.strip_edges() == "Back":
			back.text = "< Back"
		DialogStyles.style_back_button(back)
	if title != null:
		# Screen titles converge on FONT_SIZE_XL. The scene files ask for 32, which
		# is wide enough that "Equipment Manager" wrapped to two lines and pushed
		# the Back button off the top of a 360dp phone.
		title.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_XL))
		title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if context != null:
		context.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_SM))
		context.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)


## Update (or add) the muted context label on a header built by build_header().
static func set_header_context(header: HFlowContainer, text: String) -> void:
	if header == null:
		return
	var existing := header.get_node_or_null(NodePath(CONTEXT_NAME))
	if existing is Label:
		(existing as Label).text = text
		existing.visible = not text.is_empty()
		return
	if text.is_empty():
		return
	header.add_child(_build_context_label(text))


static func _build_context_label(text: String) -> Label:
	var ctx := Label.new()
	ctx.name = CONTEXT_NAME
	ctx.text = text
	ctx.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_SM))
	# TEXT_SECONDARY, not TEXT_MUTED: muted is about 3.7:1 against a card and
	# misses the 4.5:1 that normal-size text needs to stay readable.
	ctx.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ctx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ctx


# ============================================================================
# Cards
# ============================================================================

## Mark a panel as an interactive navigation card (the Library's list rows).
##
## The 3px cyan LEFT edge is an affordance, not decoration: it is what tells the
## player "this whole box is tappable and goes somewhere". Static boxes must NOT
## get it, or it stops meaning anything — use apply_section_card() for those.
static func apply_card(panel: PanelContainer) -> void:
	if panel != null:
		panel.theme_type_variation = &"NavCard"


## Mark a panel as a static content card.
static func apply_section_card(panel: PanelContainer) -> void:
	if panel != null:
		panel.theme_type_variation = &"SectionCard"


## The interactive-card recipe as a raw StyleBoxFlat.
##
## Only for call sites that genuinely need the box rather than the name — chiefly
## hover handlers that duplicate the current stylebox and recolour it. Prefer
## apply_card(), which keeps the look in the theme where accessibility variants
## and the theme editor can see it.
static func card_style(accent: Color = UIColors.COLOR_CYAN) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColors.COLOR_SECONDARY
	s.border_color = accent
	s.border_width_left = 3
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(4)
	s.content_margin_left = UIColors.SPACING_MD
	s.content_margin_right = UIColors.SPACING_MD
	s.content_margin_top = UIColors.SPACING_SM
	s.content_margin_bottom = UIColors.SPACING_SM
	return s


## The static-card recipe as a raw StyleBoxFlat. Same caveat as card_style().
static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColors.COLOR_SECONDARY
	s.border_color = UIColors.COLOR_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(UIColors.SPACING_MD)
	return s


## A titled static card wrapping `content`.
static func section_card(title: String, content: Control,
		description: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	apply_section_card(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	panel.add_child(vbox)

	if not title.is_empty():
		var title_label := Label.new()
		title_label.text = title
		title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_LG))
		title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		# Card titles can be content-driven (a planet or crew name interpolated in),
		# so their unwrapped width is unbounded. Autowrap is safe in a VBox column.
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title_label)

	if content != null:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(content)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_SM))
		desc.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)
	return panel


# ============================================================================
# Inputs
# ============================================================================

## The Library's search box.
static func style_search_field(edit: LineEdit) -> void:
	if edit == null:
		return
	edit.theme_type_variation = &"SearchField"
	edit.custom_minimum_size.y = maxf(
		edit.custom_minimum_size.y, UIColors.TOUCH_TARGET_MIN
	)
	edit.clear_button_enabled = true


# ============================================================================
# Page plumbing
# ============================================================================

## Wire the three things every page needs, in one call.
##
## These helpers all exist and all work; what was missing was one place that
## remembers to use all three. Screens picked one or two each, which is why page
## gutters had five different values across the app.
##
##   1. PortraitChrome  — 16dp side gutters in portrait, restored in landscape
##   2. reserve_band_on — keeps content out from under the gear/bug chrome
##   3. ShortScreenScroll (optional) — lets a tall column scroll on a short screen
##
## Every step no-ops when its prerequisite is missing, so it is safe to call from
## any screen shape.
static func apply_page_chrome(screen: Control, mc: MarginContainer = null,
		scroll_column: BoxContainer = null, pinned: int = 1) -> void:
	if screen == null:
		return

	var margin := mc
	if margin == null:
		margin = screen.get_node_or_null(NodePath("MarginContainer")) as MarginContainer
	if margin != null:
		var pc := PortraitChromeScript.new()
		screen.add_child(pc)
		pc.setup(margin)

	if scroll_column != null:
		var sss := ShortScreenScrollScript.new()
		screen.add_child(sss)
		sss.setup(scroll_column, pinned)

	reserve_band(screen)


## Gutter variant for a screen that pads with anchor offsets instead of wrapping
## its content in a MarginContainer (the Library is built that way).
static func apply_page_chrome_offsets(screen: Control, content: Control) -> void:
	if screen == null or content == null:
		return
	var pc := PortraitChromeScript.new()
	screen.add_child(pc)
	pc.setup_offsets(content)
	reserve_band(screen)


## Ask SettingsOverlay to keep its top-right chrome from covering this screen.
static func reserve_band(screen: Node) -> void:
	if screen == null or not screen.is_inside_tree():
		return
	var so := screen.get_node_or_null("/root/SettingsOverlay")
	if so != null and so.has_method("reserve_band_on"):
		so.reserve_band_on(screen)


## Put the page colour behind a screen that renders over something else.
##
## Most screens need nothing here — the project's clear colour IS
## UIColors.COLOR_PRIMARY, so an ordinary full-screen page is already on the right
## background. This is for overlays and embedded panels, which have another
## screen showing through behind them.
static func ensure_background(screen: Control) -> ColorRect:
	if screen == null:
		return null
	var existing := screen.get_node_or_null(NodePath(BACKGROUND_NAME))
	if existing is ColorRect:
		return existing as ColorRect
	var bg := ColorRect.new()
	bg.name = BACKGROUND_NAME
	bg.color = UIColors.COLOR_PRIMARY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	screen.add_child(bg)
	screen.move_child(bg, 0)
	return bg


# ============================================================================
# Navigation
# ============================================================================

## Go back the way the player came, falling back to a named route.
##
## Screens used to hand-roll this, and four of them called a SceneRouter.go_back()
## that did not exist behind a has_method() guard — so they silently always took
## the fallback and ignored the history.
static func navigate_back(from: Node, fallback: String = "main_menu") -> void:
	if from == null or not from.is_inside_tree():
		return
	var router := from.get_node_or_null("/root/SceneRouter")
	if router == null:
		return
	if router.has_method("navigate_back"):
		router.navigate_back()
	elif router.has_method("navigate_to"):
		router.navigate_to(fallback)
