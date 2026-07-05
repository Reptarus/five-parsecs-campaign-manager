# Standard Operating Procedures

Institutional knowledge for the Five Parsecs Campaign Manager. Each SOP is
short and scannable. Linked from `CLAUDE.md`. Update when a new convention
emerges or an old one changes.

**Rule for adding an SOP**: only document a pattern after you've used it
*twice*. The first time is an experiment, the second time is a pattern, the
third time is when you wish you'd written it down. Document at the second.

**Rule for editing an SOP**: if a procedure changed, update the doc in the
same commit as the code change. Stale SOPs are worse than no SOPs.

## Index

| Doc | Covers | Read when |
|---|---|---|
| [asset-pipeline.md](./asset-pipeline.md) | Cataloging Drive deliveries, PSD layer extraction, naming conventions, directory layout | Before touching `assets/`, `data/scenes/`, or running any extraction script |
| [narrative-scene-authoring.md](./narrative-scene-authoring.md) | SceneStage manifest schema (bg/actors/fx + character_slots + ambient_motion), full-canvas layer contract, hand-export pipeline, roster-aware crew figures, ambient "living painting" motion | Before authoring/editing a `data/scenes/<id>.json`, exporting scene art layers, wiring crew figures into a scene, or tuning ambient motion |
| [visual-runtime-verification.md](./visual-runtime-verification.md) | When MCP visual verification is mandatory vs optional, screenshot evidence, gallery overlay pattern, motion transform-probe, full-overlay capture harness | Before merging any change that affects rendering (portraits, scenes, animations, motion, UI components with textures) |
| [component-patterns.md](./component-patterns.md) | Single-source-of-truth JSON + loader, path-loaded preload, export-safe `load()` rule, deferred initial swap | Before writing any new `.gd` component or data file |
| [sheet-export.md](./sheet-export.md) | Field-coordinate JSON manifest, SubViewport PNG export, PDF router (GodotHaru/GodotPDF), debug-overlay calibration | Before adding a new printable sheet, swapping the PDF backend, or modifying SheetRenderer / PdfExportRouter |
| [ornament-panel-pattern.md](./ornament-panel-pattern.md) | OrnamentPanel architecture (rounded chrome + colored stroke + corner brackets via 9-slice atlas), procedural bracket generator, decision matrix vs CalloutCard/BookFrame | Before writing new section cards / dialog panels that should match the Modiphius rulebook aesthetic, or before tuning bracket art |
| [cross-mode-transfer.md](./cross-mode-transfer.md) | Canonical-hub character transfer between gamemodes (5PFH/Bug Hunt/Planetfall/Tactics): 9 book-defined + 3 composed routes, reward-suppression, lossless snapshot, `user://transfers/` file-drop envelope, mode-generic dashboard pickup, Planetfall ending matrix | Before adding/editing a transfer leg, the file-drop envelope, the snapshot, or the dashboard pickup |
| [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) | ResponsiveManager DPI-aware breakpoints + `layout_class_changed` rotation signal + `get_effective_columns()`, the CampaignScreenBase/BaseCampaignPanel convergence, AdaptivePanelGroup, the square-base/portrait gotchas | Before touching ResponsiveManager, adding a screen that must adapt to size/orientation, building a multi-pane screen, or changing `project.godot [display]` |
| [android-runtime-testing.md](./android-runtime-testing.md) | Two-tier Android testing strategy: T1 MCP window-resize simulation (Windows) + T2 on-device; one-click deploy vs ADB; remote debugger profiling (FPS/draw-calls/memory); logcat tags; performance thresholds | Before any responsive UI merge (T1 minimum) or before distributing any Android APK (T2 required) |
| [decision-log.md](./decision-log.md) | Material "we picked X over Y because Z" records | When you're tempted to second-guess a pattern, or before proposing to replace one |

## Anti-regressions log

Specific traps we've fallen into and the rule that prevents them.

| Trap | Rule | Reference |
|---|---|---|
| `Image.load(res_path)` works in editor, **breaks silently in exported builds** | Use `load()` for `res://` paths, only use `Image.load()` for `user://` or absolute paths | [component-patterns.md](./component-patterns.md#export-safe-asset-loading) |
| `CharacterCard` read `character_data.portrait_path` directly, bypassing the species registry fallback | Always call `get_portrait()`, never read `portrait_path` directly | [component-patterns.md](./component-patterns.md#single-source-of-truth-for-derived-data) |
| Mid-file `const` declaration in GDScript rejected at parse time | All `const` and `preload` at top of file, before `@export` vars | [component-patterns.md](./component-patterns.md#path-loaded-preload-pattern) |
| `Engine.has_singleton()` returns false for autoloads | Use `get_node_or_null("/root/Name")` for autoloads. `Engine.has_singleton()` is for engine singletons only | CLAUDE.md "Gotchas" |
| `layer.composite()` returns bbox-cropped image, losing canvas position | Use `psd.composite(layer_filter=lambda l, t=target: l is t)` for canvas-sized output with position preserved in alpha | [asset-pipeline.md](./asset-pipeline.md#psd-extraction) |
| Headless compile clean does NOT mean the code works at runtime | Visual runtime verification is mandatory for anything that renders | [visual-runtime-verification.md](./visual-runtime-verification.md) |
| Modifying production code during a pilot creates rollback debt | Use MCP runtime injection overlays for pilots, only commit to production once architecture is proven | [visual-runtime-verification.md](./visual-runtime-verification.md#runtime-injection-pattern) |
| A still screenshot was used to "verify" looping/ambient motion | A screenshot cannot show motion. Prove it with a headless transform-probe sampling node transforms at t0 vs t+N | [visual-runtime-verification.md](./visual-runtime-verification.md) |
| `z_index` used for SceneStage layer depth let crew figures jump in front of foreground actors | Use TREE ORDER for depth (insert the SlotLayer between bg and actors). `z_index` overrides tree order across parents | [narrative-scene-authoring.md](./narrative-scene-authoring.md) |
| Drifting a character-slot rect for parallax fought `_layout_character_slots()` on every resize | Apply ambient motion to the layer CONTAINER, never the individual rect — the layout owns rect.position | [narrative-scene-authoring.md](./narrative-scene-authoring.md) |
| Scene-wide drift exposed the letterbox edge of a full-canvas backdrop | Overscan every layer (~1.04) so drift stays within headroom; keep the breathe floor at the overscan value | [narrative-scene-authoring.md](./narrative-scene-authoring.md) |
| Photoshop per-layer export trimmed actor PNGs to content bounds, breaking SceneStage alignment | Export via Layers to Files with "Trim Layers" UNCHECKED; every layer must be full canvas size | [narrative-scene-authoring.md](./narrative-scene-authoring.md) |
| New ambient/looping motion ignored the Reduced Motion accessibility setting | Gate on `ThemeManager.is_reduced_animation_enabled()` — off must mean perfectly static | [narrative-scene-authoring.md](./narrative-scene-authoring.md) |
| Bug Hunt muster-out wrote a `user://transfers/` file that NOTHING ever read — veterans silently vanished | A transfer SOURCE leg is dead code without a DESTINATION pickup; wire `_check_pending_transfers.call_deferred()` into the target dashboard's `_setup_screen()` | [cross-mode-transfer.md](./cross-mode-transfer.md) |
| `convert_from_planetfall` zeroed the WHOLE ship debt on `independence_won` — the book only prepays 2D6 of it | Verify ending-bonus values against Planetfall pp.165-166; use `ship_debt_prepaid` (partial), never full forgiveness | [cross-mode-transfer.md](./cross-mode-transfer.md) |
| Tempted to write a direct converter for a route with no book rule (Planetfall→Bug Hunt etc.) | Compose two book-defined legs through the 5PFH canonical — invent zero values | [cross-mode-transfer.md](./cross-mode-transfer.md) |
| Breakpointed off `get_visible_rect()` → phone and tablet looked identical in portrait (content always ~1080 wide with the square base) | Classify by density-independent physical size via `ResponsiveManager` (`window_get_size()/screen_get_scale()`), never the stretched content rect | [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) |
| Read `window_set_size()` state in the SAME `run_script` call that set the size — got stale values | `window_set_size` is ASYNC. Always read ResponsiveManager state in a SEPARATE `run_script` call AFTER the resize | [android-runtime-testing.md](./android-runtime-testing.md#step-by-step-procedure) |
| Remote debugger panel stayed empty after one-click deploy on Godot 4.3+ | Known engine bug #96524 — if debugger panel is empty, fall back to `adb logcat -s Godot:* AndroidRuntime:*`; add `AndroidRuntime:*` to catch native crashes missed by `Godot:*` alone | [android-runtime-testing.md](./android-runtime-testing.md#method-a-one-click-deploy-preferred) |
| A screen didn't re-lay-out on a constant-width portrait↔landscape rotation | Connect `ResponsiveManager.layout_class_changed` (fires on rotation too), not only `breakpoint_changed`; branch `_apply_*_layout` overrides on `should_use_single_column()`, not the width bucket | [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) |
| A `_ready()` override silently lost all responsive wiring (TacticsDashboard) | A subclass overriding `_ready()` MUST call `super._ready()` | [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) |
| Assumed 1024dp falls in the DESKTOP bucket (expected 3 cols, got 4) | `_classify_breakpoint` uses STRICT LESS-THAN. `1024 < 1024` is false -> WIDE (4 cols). `BREAKPOINTS[Breakpoint.WIDE] = 1440` is in the dict but NEVER used in the ladder (ceiling check uses ULTRAWIDE=2560). Effective WIDE range is 1024-2559dp. | [android-runtime-testing.md](./android-runtime-testing.md) |

## When SOPs disagree with code

The code is the truth. Investigate the divergence:

1. If the code is *correct* and the SOP is out-of-date → update the SOP in
   the same commit as your code change.
2. If the SOP is *correct* and the code is wrong → fix the code, leave the
   SOP alone.
3. If both could be right depending on context → split the SOP into the two
   cases, or add the context to the existing entry.

Don't quietly delete an SOP rule because your current code violates it.
That's how regressions get re-introduced.
