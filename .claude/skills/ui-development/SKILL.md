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
| `references/narrative-screen.md` | NarrativeScreen (CanvasLayer L95), advisor system, text generator, integration pattern for phase-panel branches, SceneStage character slots + ambient motion. For scene AUTHORING (manifest schema, layer contract, verification) see `docs/sop/narrative-scene-authoring.md` |
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
- **Authoring/editing a narrative SCENE** (manifest, art layers, crew figures, motion) → Read `docs/sop/narrative-scene-authoring.md` (layer contract, manifest schema, verification)
- **Roster-aware crew figures in a scene** → Read `narrative-screen.md` (character slots — SpeciesFigureRegistry, tree-order depth NOT z_index, feet anchoring)
- **Ambient / "living painting" motion** → Read `narrative-screen.md` (ambient motion — drift+breathe+overscan on layer CONTAINERS, gate on Reduced Motion, verify via transform-probe not screenshot)
- **Sheet rendering / PDF export / printable sheets** → Read `sheet-export.md` (SheetRenderer, PdfExportRouter, GodotPDF/GodotHaru gotchas, Sprint 3 PDF-native text overlay design)
- **Rulebook-styled callout panel (rounded + colored stroke + corner brackets)** → Read `ornament-panel.md` (OrnamentPanel, atlas variants, tuning workflow). DO NOT try to repurpose Modiphius .ai border art at panel scale — brackets are procedurally generated, not extracted
- **Galaxy Log / hex map / per-planet detail popup** → Galaxy Log lives at `src/ui/screens/galaxy_log/` + `src/ui/components/galaxy_log/`. **Shared planet renderer** lives at `src/core/world/PlanetDetailBuilder.gd`: any new surface that needs to show planet details (dashboard, popup, future export sheet) calls `PlanetDetailBuilder.build_into(vbox, planet)` — do NOT re-implement section rendering. Architecture summary in project CLAUDE.md "Galaxy Log" section
- **Hex math / axial coordinates / hex polygon drawing** → `src/core/world/GalaxyHexLayout.gd` static utility. `axial_to_pixel()`, `hex_corners()`, `ring_slot_to_axial()`, `next_free_outward()`. Pure RefCounted, no instantiation. Flat-top hexes, redblobgames formulas
- **Custom `_draw()` invalidation** → Use property setters that call `queue_redraw()`. NEVER `_process()` → `queue_redraw()` (wasteful for static art). Canonical examples: HexStarMap `_show_breadcrumb`, HexCell `is_current`/`is_starting`/`_hovered`

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
| `src/ui/screens/narrative/SceneStage.gd` | path-loaded | Layered scene composer: bg/slot/actor/fx layers, `set_character_slots()`, ambient motion. See `narrative-screen.md` + `docs/sop/narrative-scene-authoring.md` |
| `src/core/character/SpeciesFigureRegistry.gd` | path-loaded | `species_id → full-figure PNG(s)`, existence-aware variant pick (parallel to `SpeciesPortraitRegistry`) |
| `src/ui/screens/dev/SceneViewer.gd` + `.tscn` | path-loaded | Dev harness: preview a scene manifest in isolation (`-- scene_id=X test_crew=... autoshot`) |
| `data/scenes/<id>.json` | Scene manifest | SceneStage bg/actor/fx layers + `character_slots` + `ambient_motion` |

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
16. **After generating new asset PNGs via script, MUST run `Godot --headless --import --quit`** — `.import` files don't exist until Godot scans. `ResourceLoader.exists()` returns false until that scan completes, and silent-fallback patterns render nothing without errors. Applies to OrnamentPanel atlases after running the bracket generator, and to SceneStage scene/figure PNGs
17. **SceneStage depth = TREE ORDER, never `z_index`** — character-slot figures render behind baked foreground actors because a `SlotLayer` sits between bg and actor layers in the node tree. `z_index` overrides tree order across parents and would let crew jump in front of enemies. See `references/narrative-screen.md`
18. **Ambient motion applies to layer CONTAINERS, never individual rects** — `_layout_character_slots()` owns each figure's `rect.position`; drifting a rect fights the layout on resize. Drift the container, the transform composes on top. Overscan (1.04) hides the letterbox edge drift exposes
19. **A screenshot CANNOT verify motion** — drift/breathe/parallax need a headless transform-probe (sample node transforms at t0 vs t+N). A still frame proves only that it renders. See `docs/sop/visual-runtime-verification.md`
20. **Ambient/scene motion MUST gate on Reduced Motion** — `get_node_or_null("/root/ThemeManager").is_reduced_animation_enabled()` (the same accessibility setting TweenFX honors via #9). Off must mean perfectly static (scale 1, pos 0)
21. **Dict producer→consumer key drift is silent** (May 29 2026 retro caught 2 of these in one file). When writing a Dictionary destined for a separate consumer (`NarrativeScreen.present(event_data, ...)`, `BattleCalculations.resolve_ranged_attack(attacker, ...)`, any panel `_data.get(...)` read), Grep the consumer's `_populate_*` / `_data.get` sites for the EXACT key names BEFORE finalizing the producer. Examples that bit us: producer used `"briefing"` while NarrativeScreen reads `"briefing_text"`; producer used `"held_the_field"` while resolvers emit `"held_field"`. Neither error nor warning surfaces — the feature just silently doesn't render. Fix: match the consumer keys EXACTLY; for legacy-spelling tolerance use a chained get (`result.get("held_field", result.get("held_the_field", false))`); default missing keys to the SAFEST value, not the convenient one. Add a gdUnit4 bug-pin test that asserts `d.has("briefing_text") == true and d.has("briefing") == false` to lock the contract.
22. **For unit-testable dict-transform helpers on Control classes** — refactor the helper `static` so tests can call `ClassName._helper(args)` without instantiating the Control (which trips `@onready %` scene-dependency asserts at `_ready` time). Pattern shipped in `CampaignTurnController._battle_result_to_narrative_dict` May 29 + `test_b2_narrative_bridge.gd` (8 tests / 120ms). Reuse for any pure-data helper on Control-extending classes.
23. **SceneAtmosphereLayer** (`src/ui/screens/narrative/SceneAtmosphereLayer.gd`, May 29 2026) — GPUParticles2D-driven, sibling of SceneStage inside IllustrationFrame. 5 ambient effects (snow/dust_motes/fog_haze/embers/smoke_columns) driven by world traits + art_tag fallback. Catalog SSOT: `data/atmosphere/world_trait_atmosphere.json` via `AtmosphereCatalog.gd`. Procedural radial-falloff texture generated at runtime + per-effect color_ramp tinting — PNG textures are [OPTIONAL] polish upgrades, NOT [NEEDED] to ship. `clip_contents = true` prevents particles bleeding into the narrative panel. Reduced Motion gated (clears active effect when on). Per-effect-id `{node, cfg}` dict storage; ONE `resized` connection on `_ready` walks all active emitters (Godot 4.6 connect-dedup compares method-on-target, so per-emitter `bind`s would error "already connected").
24. **Tier 2 image slots** (`SceneStage.gd` + `Tier2AssetRegistry.gd`, May 29 2026) — extends `character_slots` with `anchor_mode` (feet/center/top/top_left) + `scale_mode` (height/width) + assignment-level `source` field (`tier2:<key>` or `res://...` path; bypasses `SpeciesFigureRegistry`). Defaults preserve backward compat. Use for non-figure scene fragments (wide compositions like Planetfall STALKER 6000×3500). SOP §4a documents the contract. Per-slot drift is REMOVED — `_layout_character_slots` overwrites position absolutely, so any per-rect drift tween dies on the next resize. Only whole-scene ambient motion on layer containers parallaxes slot figures now.
