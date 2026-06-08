# SOP: Responsive / Adaptive UI (mobile + tablet + desktop)

**Read this before** touching `ResponsiveManager`, adding a screen that must adapt to orientation/size, building a multi-pane screen, or changing `project.godot [display]`. Shipped during the mobile/tablet re-pivot (Jun 2026). Supersedes the archived `docs/archive/RESPONSIVE_BREAKPOINTS_IMPLEMENTATION.md`.

## TL;DR — the model

The app targets **the full range 375px portrait phone → 1920px desktop landscape, in both orientations**, on one adaptive layout. The single source of truth is the **`ResponsiveManager` autoload**. Screens never re-derive breakpoints from raw viewport width — they consult `ResponsiveManager` and react to its signals.

- **`stretch = canvas_items` + `expand`**, **square 1080×1080 base**, **`handheld/orientation=6` (SENSOR)**, `viewport_min_width=320` (`project.godot [display]`).
- A screen adapts via two things: the **layout class** (how many columns fit) and the **orientation** (portrait collapses).

## ResponsiveManager (`src/autoload/ResponsiveManager.gd`)

| API | Purpose |
|---|---|
| `current_breakpoint` (`Breakpoint` enum MOBILE/TABLET/DESKTOP/WIDE/ULTRAWIDE) | Device-size class, **DPI-aware** (see below) |
| `get_effective_columns()` / `get_effective_crew_columns()` | Max comfortable side-by-side panes for the viewport **AND orientation**. **Portrait is ALWAYS 1 (single-column), every width bucket** — even a wide portrait tablet shows one focused column / tab strip (360dp, the most common phone, is only ~321 design px at our effective ~1.12 scale, far too tight for 2 cols). Only LANDSCAPE uses the multi-column width ladder. Use THESE, not the legacy `get_optimal_columns()` |
| `should_collapse_to_single_column()` | `get_effective_columns() <= 1` |
| `is_portrait()` / `is_landscape` | orientation |
| `signal layout_class_changed(effective_columns)` | **Fires on a width-bucket change OR a rotation.** The keystone — connect to THIS for re-layout, not only `breakpoint_changed` |
| `signal breakpoint_changed` / `orientation_changed` / `viewport_resized` | lower-level; legacy/desktop consumers |
| `DESIGN_BASE_WIDTH` (1920) | proportional-sizing scale reference; **distinct** from the square stretch base |

**Decision seams (testable, pure):** `_classify_breakpoint(dip_width)` and `_evaluate_layout_change(prev_bp, prev_landscape)` are factored out so the breakpoint ladder and the emit guard can be unit-tested without a real window. See `tests/unit/test_responsive_manager_effective_columns.gd` (16 cases).

### DPI-aware breakpoints (the non-obvious part — read this)

With `canvas_items` + `expand` + a square base, **portrait content is ALWAYS ~1080 units wide** (width-driven scaling), on a phone AND a tablet. So `root.get_visible_rect().size` (the design/content space) **cannot tell a phone from a tablet in portrait** — it always reads WIDE. Therefore `ResponsiveManager` classifies breakpoints from **density-independent physical size**, not content size:

```
dip = DisplayServer.window_get_size() / DisplayServer.screen_get_scale()
current_breakpoint = _classify_breakpoint(dip.x)
```

`screen_get_scale()` reports a real value on Android/iOS/macOS/Wayland/Web (e.g. 2.75 on an xxhdpi phone) and falls back to 1.0 on Windows desktop (where physical px already = logical px). Result: a 1080px phone @ 2.75× → ~393 dp (MOBILE → 1 col), a 1536px tablet @ 2× → 768 dp (DESKTOP → 2 col), a 1280px desktop window @ 1× → WIDE (3 col). Verified live.

## The base-class convergence

`CampaignScreenBase` (dashboards, crew, etc.) and `BaseCampaignPanel`/`FiveParsecsCampaignPanel` (creation panels, compendium) both now:

1. **Derive the layout bucket from `ResponsiveManager`** via `_resolve_layout_mode()` (maps `current_breakpoint` → local `LayoutMode`), not their old independent `viewport.x vs 1440` logic. This killed a flap where the two paths disagreed (local 1440 vs RM 1024 DESKTOP/WIDE boundary).
2. **Connect `layout_class_changed`** → re-layout, so screens re-lay-out on a constant-width rotation (which `breakpoint_changed` misses).
3. **Dedupe with `_last_effective_columns` + `_last_is_portrait`**: `_update_layout_for_mode()` records both; `_relayout_if_class_changed()` relayouts only when EITHER changed. This prevents double-relayout when `breakpoint_changed` and `layout_class_changed` both fire on a bucket-cross, and makes rotation handling correct-by-construction (not reliant on the column matrix happening to differ across orientation).
4. **Re-apply layout after `_setup_screen()`** (`CampaignScreenBase._ready`): the initial `_apply_responsive_layout()` runs BEFORE the screen builds its nodes, so a code-built responsive node (e.g. HelpScreen's sidebar) would otherwise get no orientation-correct initial layout until the first rotation.

## Recipe: make a screen rotation-ready

- **Extends a base class?** You inherit the wiring. Just make your `_apply_mobile/tablet/desktop_layout` overrides branch on **orientation** (`should_use_single_column()` / `should_collapse_to_single_column()`), NOT only the width bucket. A width-bucket-only override (e.g. "show sidebar on DESKTOP") will be re-fired on rotation but won't change anything, because the bucket is unchanged on a constant-width rotation. (This was the HelpScreen + EquipmentPanel-split fix.)
- **Subclass overriding `_ready()`?** It **MUST call `super._ready()`** or it loses ALL responsive wiring. (TacticsDashboard regressed on exactly this.)
- **Self-wired screen (not a base subclass)?** Connect `ResponsiveManager.layout_class_changed` yourself and re-layout in the handler; pull `get_effective_columns()` synchronously in your setup for the initial paint (the signal has no boot emit).

## AdaptivePanelGroup (`src/ui/components/base/AdaptivePanelGroup.gd`)

Reusable container for the pervasive **"N side-by-side panes"** idiom (`MainContent` HBox/Grid in ~9 screens: Dashboard, PreBattle, Equipment, ShipManager, PatronRivalManager, etc.). Modes driven by `get_effective_columns()`:

- **GRID** (≥2 cols): panes side-by-side.
- **STACK** (1 col, overview): panes stacked, scroll.
- **TABS** (1 col, master-detail): one pane visible, a `TabBar` strip switches (`clip_tabs` handles 375px overflow).

**Critical design rule — NO per-rotation reparenting.** Panes are reparented into one internal `GridContainer` ONCE (in `add_pane`) and never moved again; a mode change only toggles `columns` + per-pane `visible` + the TabBar. Reparenting on every rotation would re-fire each pane's `_enter_tree`/`_exit_tree` (lifecycle churn). API: `add_pane(control, title)`, `show_pane(i)`, `portrait_mode = STACK|TABS|AUTO`. Tested in `tests/unit/test_adaptive_panel_group.gd` (8 cases incl. the no-reparent contract). Pick STACK for browse/overview screens, TABS for pick-then-act/master-detail.

## ResponsiveContainer (`src/ui/components/base/ResponsiveContainer.gd`)

A `@tool` container for **local** two-pane horizontal↔vertical switching of one subtree. AUTO mode now consults `ResponsiveManager.should_collapse_to_single_column()` (global) `OR` its local `min_width_for_horizontal` (additive — only adds compact cases). Use for a single subtree that should reflow narrower than the whole screen; use `AdaptivePanelGroup` for whole-screen multi-pane policy.

## Gotchas

1. **Portrait content is always ~1080 wide** (square base + expand). Never breakpoint off `get_visible_rect()` — use `ResponsiveManager` (DPI-aware). [the root cause of "phone == tablet in portrait"]
2. **`breakpoint_changed` misses constant-width rotation.** Connect `layout_class_changed` for any orientation-dependent layout.
3. **A width-bucket-keyed override won't collapse on rotation** even though it re-fires — branch on orientation.
4. **`_apply_responsive_layout()` runs before `_setup_screen()`** in `CampaignScreenBase._ready` — code-built responsive nodes need the post-setup re-apply (already in the base) or a synchronous pull in setup.
5. **3-column screens that stack to 1 column** need an OUTER scroll + content-sized columns; nested inner+outer ScrollContainers double-scroll. (Dashboard Phase-4 work.)
6. **Touch-target sizing stays device-keyed** (COMFORT on mobile bucket, MIN otherwise), NOT orientation-keyed — target size tracks input method, not aspect.

## Phase status (Jun 2026)

- **Phases 0-5 DONE + verified.** P0 (ResponsiveManager API/signal/seams + DPI breakpoints), P1 (base-class convergence + CrewManagement/TacticsDashboard/EquipmentPanel + `project.godot`), P2 (HelpScreen/CompendiumScreen), P3 (`AdaptivePanelGroup` + `ResponsiveContainer`).
- **Phase 4 (5 hard screens, COMMITTED, live-verified both orientations):** CampaignDashboard outer-scroll wrap (1-col → outer AUTO + inner DISABLED); GalaxyLog legend HFlow + Recenter; TacticalBattleUI rails suppress in portrait (`_reconcile_portrait_layout` = `intent AND not collapse`, intent captured after the stage match) + "intel" drawer mirror; PreBattle + EquipmentManager → `AdaptivePanelGroup(TABS)` (PreBattle `$`→`%` migration first). Added `AdaptivePanelGroup.focus_pane(i)` (no-op outside TABS).
- **Phase 5 (device-QA + fast-follow, UNCOMMITTED):** static audit swept 70 screens → 18 issues, all remediated — 7 more `AdaptivePanelGroup` migrations (PatronRivalManager/CampaignEventsManager/AdvancementManager TABS; ShipManager/PurchaseItemsComponent/EquipmentGenerationScene/CharacterCreator STACK), 4 fixed-width caps (CampaignJournalScreen/EquipmentPanel/TravelPhase/BattleTransitionUI — restore exact desktop widths when not collapsed), 3 turn-controller portrait top-bars (BugHunt/Planetfall/Tactics — landscape byte-identical), touch-target bumps. `AdaptivePanelGroup` now on **9 screens**.

### AdaptivePanelGroup migration recipe (the 9-screen pattern)

`unique_name_in_owner=true` on each pane node; `_setup_adaptive_panels()` called AFTER `@onready` resolves: grab panes via `%`, `main_content = pane.get_parent()`, `vbox = main_content.get_parent()`, create the group at `main_content.get_index()`, `add_pane()` each (reparents once), `main_content.queue_free()`, store `_panel_group`. Header/footer/controls are SIBLINGS of MainContent → stay outside. `@onready` caches object refs that SURVIVE reparent; only RE-RESOLVED `$`-paths break (migrate to `%`). `add_pane` forces `EXPAND_FILL` but NOT `custom_minimum_size` — clear clip-causing min-widths separately. `focus_pane(index)` index = `add_pane` order; STACK for browse, TABS for master-detail (wire selection → `focus_pane`).

### Verifying a migration when full-instantiation is blocked

Manager screens with pre-existing `_ready` crashes (e.g. `var x: Panel = _create_*_panel()` where the factory returns `PanelContainer`, or missing data JSONs) **halt the `--debug` MCP run**, so a full-instantiation probe can't reach the group. Verify those via: parse-check (`load()` every touched script + scene headless), git-diff review against this recipe (confirm unique-names added, footer outside, focus index, landscape restore), and ONE clean live probe of a screen whose `_setup_adaptive_panels()` runs FIRST in `_ready` (ShipManager) — the pattern is identical across screens.

### Text scaling across orientations (the square-base trap)

The square 1080×1080 stretch base + `canvas_items`/`expand` scales 2D content by `min(window.x, window.y) / 1080`. In LANDSCAPE the short axis is the height (~0.97× on a 1080p window — fine). In PORTRAIT the short axis is the small WIDTH → ~0.4× → **text renders tiny** (16px → ~6px). `SettingsManager._apply_ui_scale()` counteracts this (recomputed on `root.size_changed`):

```
content_scale_factor = TARGET_EFFECTIVE(1.12) × ui_scale × dpi_scale × (1080.0 / min(window.x, window.y))
```

The `1080/min(window)` term CANCELS the square-base stretch and holds a CONSTANT effective scale (~1.12) in both orientations — text is the same physical size portrait and landscape, and resizing changes how much content fits, not the text size. `dpi_scale` (`screen_get_scale()`) is real on Android/iOS/macOS/Wayland/Web, **1.0 on Windows** (use `screen_get_dpi()` for Windows-hiDPI). `content_scale_factor` does NOT affect ResponsiveManager's dp breakpoint classification — column/collapse is unchanged.

### Narrow-width fit (portrait rows must fit ~384px)

CRITICAL LESSON: with the square base, portrait content lays out in a fake-wide 1080 design space (then scales to 0.4×), so "portrait verified at content_scale 1.0" only tests COLUMN COLLAPSE — individual rows are never forced to fit a real phone width. After the scaling fix above, the portrait design space is the real ~384px, and rows authored for 1080 overflow. Patterns to make rows fit ~384px (applied across ~19 screens):
- Header / badge / button rows: `HBoxContainer` → `HFlowContainer` (wraps in portrait, single-line on desktop). FlowContainer uses `h_separation`/`v_separation` (NOT `separation`), ignores main-axis expand (so DROP the title's `SIZE_EXPAND_FILL`), and aligns via `FlowContainer.ALIGNMENT_*`.
- Long labels (names, ship/world descriptions): `autowrap_mode = AUTOWRAP_WORD_SMART` + `SIZE_EXPAND_FILL`. Shared `CampaignScreenBase._create_info_row()` does this on the value label.
- A 1-col GridContainer makes ALL stacked columns share the WIDEST column's min-width — so ONE long label in one column clips the whole screen. Wrap it.
- Fixed-size card grids (`_create_stats_grid`, cards are fixed 64px and can't shrink, inside scroll-disabled layouts): drop column count in portrait via `should_use_single_column()`.
- Verify by measuring `get_combined_minimum_size().x` of every Control against the portrait viewport width (a live MCP `run_script` tree-walk) — find the widest intrinsic-min driver, not just visible clipping.

### Slider-first hybrid + portrait de-clip (Jun 2026)

**Strategy (researched, see plan):** pure uniform scale-down FAILS for data-dense UIs (touch-target 44/48dp + ~16-17pt text floors; Paradox/Civ got panned for it). The answer is ADAPT + a user UI-scale slider as the COMPLEMENT (not substitute). Godot's dynamic/MSDF fonts re-rasterize crisp at any `content_scale_factor`, so it does NOT blur like Paradox. **The bar is "no screen CLIPS at the DEFAULT (100%) on the 360dp floor"** — NOT pixel-perfect; the slider (`SettingsScreen` 0.75-2.0) backstops the rest. **Design floor = 360dp → ~321 design px at 100%** (supersedes the older "~384px").

**De-clip = trim the WRAPPER CHROME, measured-driven** (CampaignDashboard went 110px→0 overflow at 360 this way). ALWAYS tree-walk `get_combined_minimum_size().x` to find the REAL driver FIRST — the original plan assumed the header/buttons; the real drivers were the non-wrapping ProgressHBox + glass-panel padding (the plan was wrong until measured). Levers, applied in a `_apply_portrait_chrome()` gated on `should_use_single_column()` and called from ALL of `_apply_mobile/tablet/desktop_layout` (portrait can be any width bucket):
- Column `"glass"` PanelContainer padding (`SPACING_LG` 24/side = 48): re-style with `set_content_margin_all(SPACING_SM)` in portrait, restore `_apply_panel_style(col,"glass")` in landscape.
- Inner scroll `MarginContainer` margin_right 16 → `SPACING_XS` (4) in portrait.
- Root `MarginContainer` margins 24 → `SPACING_XS` (4) in portrait (max with safe-area insets, below).
- Non-wrapping secondary HBox strips (e.g. Turns/Battles/Difficulty, 3 fixed labels ~303px that CAN'T fit) — **hide in portrait** (`.visible = not portrait`); the key value is already in the stat strip. Robust vs long values.
- Header → `MobileAppBar` (below). Each change restores its original value in landscape → desktop stays pixel-identical (verify: 0 offenders + screenshot at 1280).

**`MobileAppBar`** (`src/ui/components/common/MobileAppBar.gd`, pure-`.gd`): portrait-only self-hiding (reads `/root/ResponsiveManager`, toggles on `layout_class_changed`). Back ← + title + key-stat subtitle + an **actions slot**. Mount as child 0 of the content VBox. In portrait the screen hides `HeaderPanel` and **REPARENTS the interactive header controls** (e.g. the Story Points button whose popover anchors to its live `get_global_rect()`, + the help button) INTO the app-bar actions slot; reparents them BACK to the header in landscape. Never `free()` them.

**⚠️ GOTCHA — `%UniqueName` lookup breaks after reparenting under a runtime node:** once a unique-named scene node is reparented under a node created at runtime via `.new()` (the app bar isn't in the scene's unique-name registry), `get_node("%StoryPointsLabel")` / `%StoryPointsLabel` returns **null** — even though the node renders fine and its signals fire. The cached `@onready var` (a direct object ref) SURVIVES reparenting and keeps working. So: drive reparented nodes via cached refs, NOT `%` lookups; and don't trust `%` in runtime DIAGNOSTICS of reparented nodes (it reports a false "orphan").

**Safe-area** (`CampaignScreenBase.get_safe_area_insets()`): returns design-px notch/status-bar/nav insets (`DisplayServer.get_display_safe_area()` ÷ content scale). **Zeros on desktop/Web (no-op)**; real on Android/iOS. Wire as `maxi(base_margin, inset)` on the root MarginContainer. Real notch behavior validates ON-DEVICE only.

- Plan file: `C:\Users\admin\.claude\plans\so-we-need-to-playful-hearth.md`.

## Verification

- **Unit:** `tests/unit/test_responsive_manager_effective_columns.gd` (16) + `tests/unit/test_adaptive_panel_group.gd` (10, incl. `focus_pane` TABS-switch + GRID-noop guard). gdUnit4 with `-c`, NEVER `--headless` (signal-11).
- **Live (MCP):** `run_project` → `run_script` to `DisplayServer.window_set_size()` and read `ResponsiveManager.current_viewport_size` / `get_effective_columns()` / a screen's actual columns. `window_set_size` is async — read on the NEXT `run_script` call. Disable the TransitionManager overlay ColorRect (`visible=false`) so screenshots aren't blocked. Test the matrix: 540×960 (phone→1 col), 768×1024 (tablet→2), 1280×720 (desktop→3), plus a constant-width rotation to confirm `layout_class_changed` re-lays-out exactly once.
