---
name: ui-development
description: "Use this skill when working with UI panels, components, the Deep Space theme, responsive layout, TweenFX animations, or scene routing. Covers BaseCampaignPanel (FiveParsecsCampaignPanel), SceneRouter, TweenFX addon, and all general UI components and screens."
---

# UI Development

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/deep-space-theme.md` | Complete color palette, 8px spacing grid, typography scale, BBCode colors, all constants |
| `references/panel-patterns.md` | BaseCampaignPanel factory methods, signal-up/call-down, responsive layout, glass card styles |
| `references/tweenfx-guide.md` | 70 animations, pivot_offset requirement list, looping cleanup, accessibility, .tada() signature |
| `references/scene-router.md` | SceneRouter 70+ routes, navigation methods, history, caching, category helpers |

## Quick Decision Tree

- **Styling/colors/spacing** → Read `deep-space-theme.md`
- **Creating new panels** → Read `panel-patterns.md`
- **Adding animations** → Read `tweenfx-guide.md`
- **Scene navigation** → Read `scene-router.md`
- **Responsive layout** → Read `panel-patterns.md` (responsive section)
- **Button styling** → Use `DialogStyles` utility or read `panel-patterns.md`
- **Reusable widgets** → Check `src/ui/components/common/` first (14 components)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` | `FiveParsecsCampaignPanel` | Base panel with theme + factory methods |
| `src/ui/screens/campaign/CampaignScreenBase.gd` | `CampaignScreenBase` | Lightweight base for campaign screens (dashboard, etc.) |
| `src/ui/screens/SceneRouter.gd` | Autoload | Scene navigation (70+ routes) |
| `addons/TweenFX/TweenFX.gd` | Autoload | 95+ animation types |
| `src/ui/components/base/UIColors.gd` | `UIColors` (RefCounted) | Canonical design token source |
| `src/ui/components/common/` | 14 files | Reusable widgets (see below) |

## Reusable Widget Library (`src/ui/components/common/`)

| Component | Class | Purpose |
|-----------|-------|---------|
| `EmptyStateWidget.gd` | `EmptyStateWidget` | Themed empty state: icon + title + flavor text + optional action button |
| `LoadingScreen.gd` | `LoadingScreen` | CanvasLayer (L99) itemized loading with pending/active/complete states |
| `AcknowledgeDialog.gd` | `AcknowledgeDialog` | Titleless error modal — message IS body, single OK. Static: `AcknowledgeDialog.show_message(parent, text)` |
| `StepperControl.gd` | `StepperControl` | Quantity widget: [−] value [+], auto-disable at bounds, `punch_in` animation |
| `InlineRenameWidget.gd` | `InlineRenameWidget` | Two-mode: display (name + "tap to rename") / edit (LineEdit + ✓/✕) |
| `PersistentResourceBar.gd` | `PersistentResourceBar` | CanvasLayer (L80) overlay: Credits/StoryPts/Patrons/Rivals bar |
| `PreviewButton.gd` | `PreviewButton` | Eye icon button for preview-without-commit |
| `ItemPreviewPopup.gd` | `ItemPreviewPopup` | Read-only item detail popup. Static: `ItemPreviewPopup.show_preview(parent, data)` |
| `HubFeatureCard.gd` | `HubFeatureCard` | Dark card + cyan left border + icon + title + desc + arrow |
| `OverflowMenu.gd` | `OverflowMenu` | Three-dot button → popup with labeled count badges |
| `DialogStyles.gd` | `DialogStyles` | Static button styling: `style_confirm_button()`, `style_danger_button()`, `style_primary_button()` |
| `RulesPopup.gd` | `RulesPopup` | Full rules reference modal. Static: `RulesPopup.show_rules(parent, title, body, requirements)` |
| `ConfirmationDialog.gd` | `FPCMConfirmationDialog` | Confirm/cancel dialog with green/red buttons |
| `Tooltip.gd` | `Tooltip` | Universal tooltip with 8 position modes |

## Critical Gotchas

1. **TweenFX pivot_offset** — MUST set `node.pivot_offset = node.size / 2` before scale/rotation animations (`pop_in`, `punch_in`, `pulsate`, `tada`)
2. **TweenFX looping** — `alarm`, `breathe`, `attract`, `glow_pulse` must be explicitly stopped with `TweenFX.stop()`
3. **TweenFX.tada()** — Only takes 2 args `(node, duration)`, no scale parameter
4. **TweenFX no horizontal slide** — `drop_in`/`drop_out` are vertical only. Use raw Tween for horizontal slides
5. **UIColors is canonical** — New components must use `UIColors.COLOR_*` directly, not inline hex codes. Legacy files (CrewTaskEventDialog, ConfirmationDialog) define their own constants — do not copy this pattern
6. **Autoload timing with `load()`** — Autoloads can't reference `class_name` of non-autoload scripts at parse time. Use `load("res://path.gd")` at runtime (see TransitionManager → LoadingScreen pattern)
7. **`_pending_*` pattern for static factories** — Window subclasses with static `show_*()` methods must store data in `_pending_*` vars and apply in `_ready()`, because `_ready()` hasn't run when the factory sets properties
8. **Never hardcode colors** — always use `UIColors.*` constants
