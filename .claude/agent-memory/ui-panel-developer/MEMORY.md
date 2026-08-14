# UI Panel Developer — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Durable rules only. Dated session logs were archived 2026-08-06 to -->
<!-- docs/archive/agent-memory-logs/ui-panel-developer-MEMORY-2026-08-06.md -->

## ABSOLUTE RULE

The Core Rules and Compendium PDFs at `docs/rules/` are canonical for any game value that reaches the
UI. If code disagrees with the book, the code is wrong.

**Deep Space theme constants are NOT duplicated here.** One canonical copy lives in
`.claude/skills/ui-development/references/deep-space-theme.md` (spacing grid, touch targets,
typography scale, colour palette, BBCode). Read it there; never hardcode a colour or size, and
prefer the `BaseCampaignPanel` factory methods.

---

## Responsive / Adaptive UI — FOUNDATIONAL

Dual-platform adaptive: 375px phone → 1920px desktop, both orientations. **`ResponsiveManager`
(autoload) is the single source of truth.** Full SOP: `docs/sop/responsive-adaptive-ui.md`.

- **NEVER use `get_visible_rect()` for portrait/orientation/breakpoint logic.** Under the square 1080
  `canvas_items`+`expand` base it returns the VIRTUAL base size (~1080², per `Window.content_scale_size`),
  NOT physical pixels — so `y > x` is essentially never true and device portrait is never detected.
  This was a SYSTEMIC bug: `BaseCampaignPanel.should_use_single_column()` (L474) and
  `CampaignScreenBase.should_use_single_column()` (L383) both used it, silently defeating
  already-correct per-panel stacking (EquipmentPanel `_apply_split_orientation`, WorldInfoPanel card
  row) — the panels called the helper, got `false`, and stayed multi-column. Both now delegate to
  `_responsive_manager.should_collapse_to_single_column()`. Anti-regression: `grep -rn get_visible_rect
  src/ui` should only ever find pan/zoom math.
- **Breakpoints are DPI-aware**: classified by `window_get_size() / screen_get_scale()`. Call
  `get_effective_columns()` / `get_effective_crew_columns()` / `should_collapse_to_single_column()` —
  never the legacy `get_optimal_columns()`.
- **Rotation re-layout rides `layout_class_changed`** (fires on width-bucket change OR rotation), NOT
  `breakpoint_changed` (which misses constant-width rotation).
- **Orientation-dependent `_apply_*_layout` overrides MUST branch on `should_use_single_column()`**,
  not the width bucket — a bucket-keyed override re-fires on rotation but changes nothing (the bug
  behind the HelpScreen sidebar and the EquipmentPanel split).
- **A `_ready()` override MUST call `super._ready()`** or it loses ALL responsive wiring
  (TacticsDashboard regressed on exactly this).
- **Multi-pane screens (N side-by-side panels) → `AdaptivePanelGroup`** (`add_pane(control, title)`,
  `portrait_mode = STACK|TABS`). Panes reparent in ONCE; mode changes only toggle
  columns/visibility/TabBar. A 3-col→1-col screen also needs an OUTER scroll plus content-sized
  columns — don't nest inner and outer scrolls.
- **Touch targets stay device-keyed** (COMFORT on the mobile bucket, MIN otherwise), NOT
  orientation-keyed.
- `project.godot [display]`: square `1080×1080` base, `stretch canvas_items/expand`,
  `handheld/orientation=6` (SENSOR), `viewport_min_width=320`.
- Tests: `test_responsive_manager_effective_columns.gd` (16), `test_adaptive_panel_group.gd` (8).

## Portrait de-clip recipe

Bar: **no screen CLIPS at the DEFAULT (100%) UI scale on the 360dp floor (~321 design px)**. The
UI-scale slider (`SettingsScreen`, 0.75-2.0) is the BACKSTOP, not the fix — data-dense UIs don't
uniformly scale down (44/48dp touch and ~16-17pt text floors). ADAPT the layout.

**MEASURE the real driver first** via an MCP tree-walk of `get_combined_minimum_size().x`. The
assumed driver is routinely wrong — in the one sprint that did this, it was a non-wrapping
`HBoxContainer` plus glass-panel padding, not the header everyone suspected.

Levers, in order: glass `content_margin` `SPACING_LG`(24)→`SPACING_SM`(8) · scroll margins 16→4 ·
root margins 24→`SPACING_XS`(4) · HIDE non-wrapping secondary strips in portrait · true multi-button
`HBoxContainer`→`HFlowContainer` (a `.tscn` type change) · long Labels `autowrap_mode=2`.
**RESTORE every value in landscape** and verify 1280 is pixel-identical with 0 offenders.

Reusable: `src/ui/components/common/MobileAppBar.gd` (portrait-only self-hiding top bar; it
**REPARENTS** interactive header controls in and out — never duplicates them) and
`src/ui/components/base/PortraitChrome.gd` (self-wiring: `.new()` → `add_child` → `setup($MarginContainer)`;
captures the scene's original margin for the landscape restore).

---

## Critical Gotchas

1. **TweenFX `pivot_offset`** — MUST set `node.pivot_offset = node.size / 2` **before** any scale or
   rotation animation, or it pivots from the top-left. Needs it: `press`, `pop_in`, `pulsate`,
   `punch_in`, `breathe`, `tada`, `critical_hit`, `upgrade`, `attract`, `headshake`. Safe without:
   `fade_in`, `fade_out`, `blink`, `spotlight`, `alarm`, `shake`.
2. **TweenFX looping animations must be explicitly stopped** — `alarm`, `breathe`, `attract`,
   `glow_pulse`. Call `TweenFX.stop(node, ...)` / `stop_all(node)` when the node is hidden or freed,
   or you orphan tweens.
3. **`TweenFX.tada(node, duration)` takes 2 args** — there is no scale parameter.
4. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Use
   `var x: Type = dict["key"]`.
5. **`%UniqueName` breaks after reparenting a node under a runtime `.new()` node** — `get_node("%X")`
   returns null even though the node renders and its signals fire, while the cached `@onready` ref
   SURVIVES. Drive reparented nodes via cached refs, not `%`.
6. **A freshly-created `class_name` script isn't in the global class cache until an editor rescan** —
   the running game throws "Identifier not declared". Use `load("res://...")` for new helper scripts.
7. **`queue_free()` DEFERS to end of frame.** Rebuilding a container in place must `remove_child()`
   FIRST, or old and new children coexist for a frame (a toolbar rebuild returned 14 buttons, not 7).
8. **Full-screen overlays MUST extend `CanvasLayer`, not `Control`** — a Control added to root renders
   BEHIND the L80 PersistentResourceBar and L90 NotificationManager. Use `layer = 95` and wrap the UI
   in a child `Control` at `PRESET_FULL_RECT`.
9. **Use `_exit_tree()`, not `tree_exited`, to restore chrome.** `tree_exited` fires AFTER the node
   detaches, so `get_node_or_null("/root/PersistentResourceBar")` fails with "Can't use get_node()
   with absolute paths from outside the active scene tree".
10. **Registry-provided asset paths must be `ResourceLoader.exists()`-guarded** —
    `SpeciesPortraitRegistry.DEFAULT_PORTRAIT` points at a file that doesn't ship, and `load()` on a
    missing `res://` path crashes. Let the colored-initials / gradient fallback handle the miss.
11. **Never assume a documented widget is wired.** `BookFrame`, `OrnamentPanel` and
    `InlineRenameWidget` are built, documented, and referenced by nothing in `src/`. Run
    `py scripts/lint_orphan_assets.py` for ground truth.

---

## Narrative scene composition + ambient motion

Authoring SOP: `docs/sop/narrative-scene-authoring.md`; UI wiring:
`.claude/skills/ui-development/references/narrative-screen.md`.

- Crew figures composite into manifest-declared `character_slots` keyed by `species_id`. Depth uses
  **tree order** (a `SlotLayer` inserted between the bg and actor layers), **NOT `z_index`** — crew
  must render behind baked foreground actors. Figures are feet-anchored (bottom-center).
- Ambient motion applies to the layer **CONTAINERS**, never individual rects, so it never fights slot
  layout. An overscan baseline (1.04) hides the letterbox edge that drift would expose.
- **Gated by Reduced Motion** (`ThemeManager.is_reduced_animation_enabled()`).
- Motion is verified by a **headless transform-probe, not a screenshot**.

## Cross-Mode Transfer — UI layer only

You own presentation: `PlanetfallCharacterImportPanel.gd`, `TacticsVeteranImportPanel.gd`, and the
dashboard transfer cards. The conversion math lives in `CharacterTransferService` (character-data-engineer)
and the pickup base in `CampaignScreenBase` (campaign-systems-engineer). **These panels are
presentational and must not mutate campaign state directly.**

Any new "show planet details" surface MUST call the shared
`PlanetDetailBuilder.build_into(vbox, planet)` (owned by character-data-engineer) — do not
re-implement section rendering.

## Before matching printed source

Do the design analysis before coding. Modiphius `.ai` border art is **page-chrome only** — it does not
survive at individual-panel scale (see `references/ornament-panel.md` for why, and the decision matrix
between `OrnamentPanel` / `CalloutCard` / `BookFrame`). Asset generation requires `--import` before any
runtime test.
