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
| `get_effective_columns()` / `get_effective_crew_columns()` | Max comfortable side-by-side panes for the viewport **AND orientation** (portrait downgrades). Use THESE, not the legacy `get_optimal_columns()` |
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

- **Done + verified (unit + live MCP):** Phase 0 (ResponsiveManager API/signal/seams + DPI breakpoints), Phase 1 (base-class convergence + CrewManagement/TacticsDashboard/EquipmentPanel fixes + `project.godot` config), Phase 2 (HelpScreen/CompendiumScreen orientation fixes), Phase 3 (`AdaptivePanelGroup` + `ResponsiveContainer` reconcile).
- **Pending (Phase 4 — the hard screens):** Dashboard outer-scroll (1-col stack); GalaxyLog legend HFlow + recenter; TacticalBattleUI rails→drawers in portrait; PreBattle/EquipmentManager → `AdaptivePanelGroup(TABS)` (PreBattle needs `$`-path→`%`-name migration first — its deep absolute `@onready` paths shatter on reparent). Then Phase 5 device-QA matrix.
- Plan file: `C:\Users\admin\.claude\plans\so-we-need-to-playful-hearth.md`.

## Verification

- **Unit:** `tests/unit/test_responsive_manager_effective_columns.gd` (16) + `tests/unit/test_adaptive_panel_group.gd` (8). gdUnit4 with `-c`, NEVER `--headless` (signal-11).
- **Live (MCP):** `run_project` → `run_script` to `DisplayServer.window_set_size()` and read `ResponsiveManager.current_viewport_size` / `get_effective_columns()` / a screen's actual columns. `window_set_size` is async — read on the NEXT `run_script` call. Disable the TransitionManager overlay ColorRect (`visible=false`) so screenshots aren't blocked. Test the matrix: 540×960 (phone→1 col), 768×1024 (tablet→2), 1280×720 (desktop→3), plus a constant-width rotation to confirm `layout_class_changed` re-lays-out exactly once.
