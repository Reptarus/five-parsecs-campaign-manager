class_name KeywordLinker
extends RefCounted

## Static helper bridging RichTextLabel BBCode keyword links to KeywordTooltip.
##
## Game data surfaces (enemy stat tables, weapon trait lists, etc.) commonly
## want to display terms like "Pistol" or "Heavy" as clickable popover triggers
## without each consumer reimplementing the meta-format bridge.
##
## There are two BBCode formats in use across the codebase:
##   [url=keyword:Heavy]Heavy[/url]   (KeywordTooltip.format_equipment_with_keywords)
##   [url=heavy]Heavy[/url]           (KeywordDB.parse_text_for_keywords)
## This helper accepts both.
##
## Typical usage:
##   var rtl := RichTextLabel.new()
##   rtl.bbcode_enabled = true
##   rtl.fit_content = true
##   rtl.text = KeywordLinker.build_traits_bbcode(["Pistol", "Heavy"])
##   var tooltip := KeywordTooltip.new()
##   add_child(tooltip)
##   KeywordLinker.attach(rtl, tooltip)

const COLOR_KEYWORD_LINK := "#4FC3F7"  # Deep Space focus cyan

## Wire a RichTextLabel's meta_clicked to a KeywordTooltip instance.
## Idempotent: safe to call multiple times on the same label.
static func attach(rich_text: RichTextLabel, tooltip: KeywordTooltip) -> void:
	if rich_text == null or tooltip == null:
		return
	rich_text.bbcode_enabled = true
	var callable := Callable(KeywordLinker, "_dispatch_meta").bind(tooltip)
	if not rich_text.meta_clicked.is_connected(callable):
		rich_text.meta_clicked.connect(callable)

## Build BBCode for a comma-separated list of weapon trait keywords.
## Each term becomes a clickable link styled in the design-system cyan.
## Empty input returns an empty string (caller decides on placeholder).
static func build_traits_bbcode(traits: Array) -> String:
	if traits.is_empty():
		return ""
	var parts: Array[String] = []
	for raw_trait in traits:
		var term := str(raw_trait).strip_edges()
		if term.is_empty():
			continue
		parts.append(_link_for(term))
	return ", ".join(parts)

## Build BBCode for a single clickable keyword term.
static func build_keyword_link(term: String) -> String:
	var t := term.strip_edges()
	if t.is_empty():
		return ""
	return _link_for(t)

## Build BBCode for a clickable keyword link with a separate display label.
## Use when the on-screen abbreviation differs from the KeywordDB key
## (e.g. "Combat" displayed for the "combat_skill" key).
## Both empty → empty string.
static func build_keyword_link_labeled(key: String, display_label: String) -> String:
	var k := key.strip_edges()
	var lbl := display_label.strip_edges()
	if k.is_empty() or lbl.is_empty():
		return ""
	return "[url=keyword:%s][color=%s]%s[/color][/url]" % [k, COLOR_KEYWORD_LINK, lbl]

## Wrap recognized terms inside free text with clickable, color-styled links via KeywordDB.
## Falls back to the input text unchanged if KeywordDB autoload is missing.
## KeywordDB emits bare [url=lower_term]Display[/url] tags; we post-process to add
## the design-system link color so wrapped terms are visually distinguishable.
static func wrap_known_keywords(text: String) -> String:
	if text.is_empty():
		return text
	var tree := Engine.get_main_loop()
	var kdb: Node = tree.root.get_node_or_null("/root/KeywordDB") if tree else null
	if kdb == null or not kdb.has_method("parse_text_for_keywords"):
		return text
	var raw: String = kdb.parse_text_for_keywords(text)
	var rx := RegEx.new()
	rx.compile("\\[url=([^\\]]+)\\]([^\\[]+)\\[/url\\]")
	var replacement: String = "[url=$1][color=%s]$2[/color][/url]" % COLOR_KEYWORD_LINK
	return rx.sub(raw, replacement, true)

## Internal — dispatch meta_clicked to the bound tooltip.
static func _dispatch_meta(meta: Variant, tooltip: KeywordTooltip) -> void:
	var s := str(meta)
	var term: String = s.substr(8) if s.begins_with("keyword:") else s
	if tooltip == null or term.is_empty():
		return
	var pos := Vector2.ZERO
	var tree := Engine.get_main_loop()
	if tree is SceneTree and tree.root and tree.root.get_viewport():
		pos = tree.root.get_viewport().get_mouse_position()
	tooltip.show_for_keyword(term, pos)

## Internal — emit BBCode in the "keyword:" prefix format expected by KeywordTooltip natively.
static func _link_for(term: String) -> String:
	return "[url=keyword:%s][color=%s]%s[/color][/url]" % [term, COLOR_KEYWORD_LINK, term]
