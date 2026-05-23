class_name EntityCardActionsRow
extends HBoxContainer

## Standardized verb-row component for entity cards (Sprint 2 Item 6).
##
## Problem: each "entity card" (Character, Ship, Equipment, ...) reinvented its
## own action buttons in a slightly different shape and order, with different
## labels and accent colors. Players got View/Edit/Remove on one screen,
## Details/Edit on another, and Delete vs Remove inconsistently.
##
## This component centralizes the verb row. Adopters:
##   1. Add an EntityCardActionsRow child
##   2. Call setup(actions) with one Action per verb
##   3. Listen on the `action_pressed(action_id)` signal
##
## Canonical verbs (Sprint 2 plan spec): EDIT, INSPECT, PRINT, DELETE.
## Convenience constructors are provided for the common subsets so adopters
## don't have to spell out the labels every time.

signal action_pressed(action_id: String)

const SPACING_XS := UIColors.SPACING_XS
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

## Canonical action IDs — adopters should stick to these strings.
const ACTION_EDIT := "edit"
const ACTION_INSPECT := "inspect"   # synonyms in code: VIEW, DETAILS
const ACTION_PRINT := "print"
const ACTION_DELETE := "delete"     # synonyms in code: REMOVE

## One action descriptor: id (canonical key), label (display text), danger
## (red accent for destructive verbs). Adopters can extend the label per
## context (e.g., "Print Sheet" instead of bare "Print").
class Action:
	extends RefCounted
	var id: String
	var label: String
	var danger: bool

	func _init(p_id: String, p_label: String, p_danger: bool = false) -> void:
		id = p_id
		label = p_label
		danger = p_danger


func _ready() -> void:
	add_theme_constant_override("separation", SPACING_XS)


## Build buttons for the given list of Action descriptors.
## Calling setup() again clears prior buttons — safe for re-render.
func setup(actions: Array) -> void:
	for child in get_children():
		child.queue_free()
	for action_variant in actions:
		var action: Action = action_variant as Action
		if action == null:
			continue
		var btn := Button.new()
		btn.text = action.label
		btn.custom_minimum_size.y = TOUCH_TARGET_MIN
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if action.danger:
			btn.add_theme_color_override("font_color", UIColors.COLOR_RED)
		var captured_id: String = action.id
		btn.pressed.connect(func(): action_pressed.emit(captured_id))
		add_child(btn)


## Convenience: standard 3-verb row (Inspect / Edit / Delete).
## Used by CharacterCard EXPANDED variant.
static func default_actions() -> Array:
	return [
		Action.new(ACTION_INSPECT, "View"),
		Action.new(ACTION_EDIT, "Edit"),
		Action.new(ACTION_DELETE, "Remove", true),
	]


## Convenience: 4-verb row with Print Sheet (for cards that have a print view).
## Adopters: CharacterDetailsScreen header (when Print Sheet sprint lands).
static func actions_with_print() -> Array:
	return [
		Action.new(ACTION_INSPECT, "View"),
		Action.new(ACTION_EDIT, "Edit"),
		Action.new(ACTION_PRINT, "Print"),
		Action.new(ACTION_DELETE, "Remove", true),
	]
