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
| `references/narrative-screen.md` | NarrativeScreen (CanvasLayer L95), advisor system, text generator, integration pattern for phase-panel branches |
| `references/sheet-export.md` | Sheet/PDF export system (SheetRenderer, PdfExportRouter, GodotPDF/GodotHaru backends), field manifests, Sprint 3 PDF-native text overlay design |
| `references/ornament-panel.md` | OrnamentPanel rulebook-faithful callout chrome (rounded + colored stroke + procedural corner brackets via 9-slice atlas). Atlas variants, sci-fi vs fantasy reading, decision matrix vs CalloutCard/BookFrame, tuning workflow |

## Quick Decision Tree

- **Styling/colors/spacing** → Read `deep-space-theme.md`
- **Creating new panels** → Read `panel-patterns.md`
- **Adding animations** → Read `tweenfx-guide.md`
- **Scene navigation** → Read `scene-router.md`
- **Responsive layout** → Read `panel-patterns.md` (responsive section)
- **Button styling** → Use `DialogStyles` utility or read `panel-patterns.md`
- **Reusable widgets** → Check `src/ui/components/common/` first (14 components)
- **Narrative event overlay** → Read `narrative-screen.md` (extending Phase 1 to other phase panels, or modifying the overlay)
- **Full-screen overlay z-order issues** → Read `narrative-screen.md` (CanvasLayer L95 pattern, never extend Control for these)
- **Sheet rendering / PDF export / printable sheets** → Read `sheet-export.md` (SheetRenderer, PdfExportRouter, GodotPDF/GodotHaru gotchas, Sprint 3 PDF-native text overlay design)
- **Rulebook-styled callout panel (rounded + colored stroke + corner brackets)** → Read `ornament-panel.md` (OrnamentPanel, atlas variants, tuning workflow). DO NOT try to repurpose Modiphius .ai border art at panel scale — brackets are procedurally generated, not extracted

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` | `FiveParsecsCampaignPanel` | Base panel with theme + factory methods |
| `src/ui/screens/campaign/CampaignScreenBase.gd` | `CampaignScreenBase` | Lightweight base for campaign screens (dashboard, etc.) |
| `src/ui/screens/SceneRouter.gd` | Autoload | Scene navigation (70+ routes) |
| `addons/TweenFX/TweenFX.gd` | Autoload | 95+ animation types |
| `src/ui/components/base/UIColors.gd` | `UIColors` (RefCounted) | Canonical design token source |
| `src/ui/themes/ThemeManager.gd` | Autoload | Theme switching, colorblind modes, reduced animation, font scaling |
| `src/ui/themes/AccessibilityThemes.gd` | `AccessibilityThemes` (RefCounted) | WCAG 2.1 AA color palettes (high contrast + 3 colorblind) |
| `src/ui/components/common/` | 14 files | Reusable widgets (see below) |
| `src/ui/screens/print/PrintSheetScreen.gd` + `.tscn` | PrintSheetScreen | Tab bar + right rail for printable sheet export (Crew Log / Encounter Log / World Record) |
| `src/ui/components/sheet/SheetRenderer.gd` | `SheetRenderer` | Manifest-driven overlay renderer (PNG background + Label fields), SubViewport PNG/PDF export |
| `src/core/export/PdfExportRouter.gd` | `PdfExportRouter` | Plugin abstraction: GodotHaru (preferred) / GodotPDF (fallback) / none |
| `data/sheets/<book>/*_fields.json` | Field manifests | Pixel-coord field rects, source dot-paths, font sizes — calibrated via debug overlay |

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
| `BookFrame.gd` | path-loaded | Page-level chrome wrapper (chapter-bracket + page-corner ornaments). NOT for individual panels |
| `CalloutCard.gd` | path-loaded | Sharp-corner Elite-Ranks-style callout. Use for inline-title-upper-left variant |
| `OrnamentPanel.gd` | path-loaded | Rounded sci-fi callout chrome: StyleBoxFlat + procedural corner brackets (NinePatchRect from 9-slice atlas). Auto-picks compact/standard atlas based on `custom_minimum_size`. See `references/ornament-panel.md` |

## Critical Gotchas

1. **TweenFX pivot_offset** — MUST set `node.pivot_offset = node.size / 2` before scale/rotation animations (`pop_in`, `punch_in`, `pulsate`, `tada`)
2. **TweenFX looping** — `alarm`, `breathe`, `attract`, `glow_pulse` must be explicitly stopped with `TweenFX.stop()`
3. **TweenFX.tada()** — Only takes 2 args `(node, duration)`, no scale parameter
4. **TweenFX no horizontal slide** — `drop_in`/`drop_out` are vertical only. Use raw Tween for horizontal slides
5. **UIColors is canonical** — New components must use `UIColors.COLOR_*` directly, not inline hex codes. Legacy files (CrewTaskEventDialog, ConfirmationDialog) define their own constants — do not copy this pattern
6. **Autoload timing with `load()`** — Autoloads can't reference `class_name` of non-autoload scripts at parse time. Use `load("res://path.gd")` at runtime (see TransitionManager → LoadingScreen pattern)
7. **`_pending_*` pattern for static factories** — Window subclasses with static `show_*()` methods must store data in `_pending_*` vars and apply in `_ready()`, because `_ready()` hasn't run when the factory sets properties
8. **Never hardcode colors** — always use `UIColors.*` constants
9. **Animation accessibility guard** — All TweenFX calls must be guarded: `var skip: bool = tm != null and tm.is_reduced_animation_enabled()`. Use explicit `bool` type (NOT `:=`) — Godot 4.6 can't infer compound booleans with nullable
10. **AcceptDialog/Window Deep Space styling** — `add_theme_stylebox_override("panel", stylebox)` with COLOR_BASE bg, COLOR_BORDER border. See MainMenu Bug Hunt dialog (line ~493) for canonical pattern
11. **ThemeManager colorblind dict keys** — AccessibilityThemes palettes use `"text_primary"`, `"base"`, `"accent"`, `"border"`, `"success"` (NOT `"text"`, `"background"`)
12. **Full-screen overlays use CanvasLayer L95** — Never `extends Control` for full-screen narrative/event overlays; a Control added to root renders BEHIND MainMenu's chrome CanvasLayers (L80/90). Use `extends CanvasLayer`, `layer = 95`, wrap UI in a `_root: Control` at `PRESET_FULL_RECT`. See `narrative-screen.md`.
13. **Optional asset paths need `ResourceLoader.exists()` guard** — Registries like `SpeciesPortraitRegistry.DEFAULT_PORTRAIT` can point at res:// art that doesn't ship. `if ResourceLoader.exists(p): load(p)` before consuming; fall back to colored-initials / gradient
14. **Cleanup with `_exit_tree()` not `tree_exited`** — For chrome restore on overlay dismiss, override `_exit_tree()`. `tree_exited` fires AFTER detachment so `/root/PersistentResourceBar` lookups fail
15. **Modiphius .ai border delivery has page-chrome ONLY** — Don't try to repurpose `assets/ui/borders/ornaments/ornament_*.svg` for panel-corner brackets. Those are 170×231 chapter-title-bracket composites for page-edge use. The rulebook's small panel-corner brackets are typography decoration drawn in InDesign, NOT in the Illustrator delivery. For per-panel corner brackets use `OrnamentPanel.gd` (procedurally-generated atlas via `scripts/generate_corner_bracket_atlas.py`). See `references/ornament-panel.md`
16. **After generating new asset PNGs via script, MUST run `Godot --headless --import --quit`** — `.import` files don't exist until Godot scans. `ResourceLoader.exists()` returns false until that scan completes, and silent-fallback patterns render nothing without errors. Applies to OrnamentPanel atlases after running the bracket generator
