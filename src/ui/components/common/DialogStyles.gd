class_name DialogStyles
extends RefCounted

## Semantic button styling. Despite the name this is the app-wide button API —
## seven of its nine consumers are screens, not dialogs (CompendiumScreen,
## GalaxyLogScreen, SettingsScreen, EULAScreen, LegalTextViewer,
## CampaignEditorScreen, CampaignJournalScreen). The name is kept because those
## call sites reference the identifier; treat it as "ButtonStyles".
##
## ── WHY THESE ARE ONE-LINERS NOW ─────────────────────────────────────────────
## They used to build three StyleBoxFlats each, at runtime, per button. That had
## two defects that no amount of call-site care could fix:
##
##   1. Only `normal`, `hover` and `pressed` were written. A styled button that
##      went DISABLED or took keyboard FOCUS fell back to the project theme's
##      box — which had a different corner radius — so the button visibly changed
##      shape mid-interaction.
##   2. A stylebox applied through add_theme_stylebox_override() is invisible to
##      the theme system. ThemeManager's accessibility variants walk the Theme and
##      could never reach a single one of these buttons.
##
## Both go away by naming the look in the theme instead: the variations live in
## sci_fi_theme.tres, inherit Button's full five-state stylebox set, and are real
## theme data. Per the Godot 4.6 theming guide, type variations are the documented
## mechanism for shared custom looks; per-control overrides "become hard to manage".
##
## Every existing call site keeps working unchanged.

## Green — completes/accepts something.
static func style_confirm_button(btn: Button) -> void:
	_apply(btn, &"ConfirmButton")

## Red — deletes, abandons, or otherwise cannot be undone.
static func style_danger_button(btn: Button) -> void:
	_apply(btn, &"DangerButton")

## Muted — backs out without committing.
static func style_cancel_button(btn: Button) -> void:
	_apply(btn, &"CancelButton")

## Blue — the one action the screen most wants you to take.
static func style_primary_button(btn: Button) -> void:
	_apply(btn, &"PrimaryButton")

## Dark — a real action, but not the one being pushed.
static func style_secondary_button(btn: Button) -> void:
	_apply(btn, &"SecondaryButton")

## The "< Back" button in a screen header.
##
## Its own variation rather than an alias for the secondary style, so that back
## navigation can be restyled app-wide later without touching every other muted
## button. Today BackButton inherits SecondaryButton in the theme, so they look
## identical — which is the intended starting point, not an oversight.
static func style_back_button(btn: Button) -> void:
	_apply(btn, &"BackButton")


## The touch floor is applied HERE rather than in the theme because a theme
## stylebox can only push a control's minimum size up via its content margins,
## and margins also inset the label. 48px is the Material/Android minimum target
## and this project's floor (UIColors.TOUCH_TARGET_MIN); a button that already
## asks for more keeps it.
static func _apply(btn: Button, variation: StringName) -> void:
	if btn == null:
		return
	btn.theme_type_variation = variation
	btn.custom_minimum_size.y = maxf(
		btn.custom_minimum_size.y, UIColors.TOUCH_TARGET_MIN
	)
