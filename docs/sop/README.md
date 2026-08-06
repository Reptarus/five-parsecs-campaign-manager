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
| A post-battle rule read a `battle_result` key NO producer ever wrote — the rule was correct and could never fire | Anything the post-battle sequence needs about the scenario must be stamped onto `mission_data` BEFORE the battle and pass through `BattleResultNormalizer` (the one chokepoint all 4 paths cross). A consumer read without a producer write is the bug | CLAUDE.md "The battle-phase data funnel" |
| `has_method("check_rival_encounter")` guarded a method with ZERO definitions repo-wide, so the p.85 Rival check never ran in ANY campaign | A `has_method()` guard whose target does not exist is a permanently-false branch, not a safety net. Grep for `func <name>` before trusting one | CLAUDE.md "The battle-phase data funnel" |
| Battlefield Finds rolled once PER CREW MEMBER (p.121 is "Roll D100 once") — a loop bound mistaken for a rule | When a step loops, confirm the COUNT against the book, not just the table it rolls on | CLAUDE.md "The battle-phase data funnel" |
| A seeded harness row asserting an exact value broke when an unrelated fix changed how many dice earlier steps drew | The seed fixes the STREAM, not the value. Assert the INVARIANT (uniform delta, difference between two crew) so upstream dice-consumption changes cannot flip it. Never re-seed until green | `tests/tools/verify_post_battle.gd` XP rows |
| A test asserted "no Rival was created" against a context where creating one was IMPOSSIBLE (no campaign to write to) | Every negative assertion needs a CONTROL proving the positive is reachable; and gate-tests need the input shape that made the old code misbehave (an empty crew made a per-crew loop vacuous) | `tests/unit/test_battle_funnel_routing.gd` |
| A "dead file" quietly held the ONLY caller of three live rules (p.126 Galactic War, p.59 hull repair, p.79 fuel) | Before shelving a zero-instantiation file, grep what its callers were. A dead file is a liability, not a curiosity — a rule "fixed" inside one has not been fixed | CLAUDE.md "The campaign-wide data flow sweep" |
| A UI component deep-COPIES its inputs (`duplicate(true)`), so every edit it makes is discarded when the step ends | A step that mutates copies must replay through the owning chokepoint (EquipmentTransferService, GameStateManager) — check whether the component owns its data before trusting its handlers | CLAUDE.md "The campaign-wide data flow sweep" |
| Writing to a property the class does not have ABORTS the function, taking every line after it | `Character extends Resource` directly — properties on `BaseCharacterResource` are NOT on it. Confirm a property exists before assigning; the abort is silent and kills the rest of the handler | CLAUDE.md "The campaign-wide data flow sweep" |
| An MCP probe read 0 from a component created with `.new()` — the `/root/X` lookup errored and aborted | Add the node to the tree before asserting on it, or the probe measures the detached-node trap instead of the code | `docs/sop/visual-runtime-verification.md` |
| Remote debugger panel stayed empty after one-click deploy on Godot 4.3+ | Known engine bug #96524 — if debugger panel is empty, fall back to `adb logcat -s Godot:* AndroidRuntime:*`; add `AndroidRuntime:*` to catch native crashes missed by `Godot:*` alone | [android-runtime-testing.md](./android-runtime-testing.md#method-a-one-click-deploy-preferred) |
| A screen didn't re-lay-out on a constant-width portrait↔landscape rotation | Connect `ResponsiveManager.layout_class_changed` (fires on rotation too), not only `breakpoint_changed`; branch `_apply_*_layout` overrides on `should_use_single_column()`, not the width bucket | [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) |
| A `_ready()` override silently lost all responsive wiring (TacticsDashboard) | A subclass overriding `_ready()` MUST call `super._ready()` | [responsive-adaptive-ui.md](./responsive-adaptive-ui.md) |
| Assumed 1024dp falls in the DESKTOP bucket (expected 3 cols, got 4) | `_classify_breakpoint` uses STRICT LESS-THAN. `1024 < 1024` is false -> WIDE (4 cols). `BREAKPOINTS[Breakpoint.WIDE] = 1440` is in the dict but NEVER used in the ladder (ceiling check uses ULTRAWIDE=2560). Effective WIDE range is 1024-2559dp. | [android-runtime-testing.md](./android-runtime-testing.md) |
| Four Compendium chapters were correct, gated, panelled — and never BUILT, because an early return sat above their setup calls | When a rule looks missing, check for a function that already implements it and has **no caller**. Held 5× on Aug 6 2026 (early return / wrong call order / no drawer opener / zero-caller producer ×2). No key census finds it: both halves exist and are correct, only execution order is wrong | CLAUDE.md "Battle-phase DELIVERY audit" |
| A populated panel lived in a drawer with no opener at the DEFAULT tier — built, seeded, signal-connected, unreachable | Cross **container membership × opener availability**, not just "is the component instantiated". A component-scoped census returns clean because the component genuinely is fine; the failure is one level up | CLAUDE.md "Battle-phase DELIVERY audit" |
| `queue_free()` in a rebuild loop left OLD and NEW children parented together for a frame (toolbar showed 14 buttons, not 7) | `queue_free()` DEFERS to end-of-frame. When rebuilding a container in place, `remove_child()` FIRST, then `queue_free()` | `TacticalBattleUI._rebuild_drawer_toolbar` |
| 79 live-state checks all missed that duplication, because they assert the button is PRESENT | A containment/`in`/`contains` assertion is blind to duplication. When a rebuild is involved, assert the COUNT or the exact list | `tests/tools/verify_battle_ui.gd` |
| Two long-standing harness failures were reported as live defects; both were the TEST | A red row is a LEAD, not a verdict. One asserted the PRE-FIX behaviour (danger pay on an Opportunity mission — p.120/p.83 make it Patron-only); one watched 4 fields too narrow to express a legal p.129 heal. **Widen the observation, never relax the assertion** — then prove the widened version can still fail | `tests/tools/verify_post_battle.gd` |
| `--headless --quit` reported clean while a script failed to PARSE, taking the whole post-battle wizard down | `--quit` validates STARTUP scripts only. Use `--headless --import` before committing — it loads every script in the project. 2254 passing unit cases and a 46/46 backend harness also missed it, because neither loads that UI script | CLAUDE.md "Gotchas" |
| Grepping an exported `.gdc` for a source string returned MISS and looked like a stale build | Godot `.gdc` is **Zstd-compressed** (`GDSC` magic + `28 B5 2F FD`); decompress from byte 12 before searching. Direct static calls to a global `class_name` also do NOT retain the method name — only string literals (e.g. the argument to `has_method()`) survive the constant pool. **Always run a CONTROL probe** with a string known to be months old | `scripts/verify_apk.py` |
| Reported "1 lint violation" when there were 3 — the extra two were real defects | Never truncate a lint's own output (`Select-Object -Last N`, `head`). Read the count line it prints | CLAUDE.md "Data Ownership" |

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
