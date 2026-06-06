# UI Panel Developer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: theme gotchas, TweenFX patterns, panel construction issues, responsive edge cases -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` define all game terminology, stat names, and mechanic labels displayed in UI. If a UI label doesn't match the book, the UI is wrong.

---

## Critical Gotchas — Must Remember

### 1. TweenFX pivot_offset

MUST set `node.pivot_offset = node.size / 2` before any scale or rotation animation. Without this, animations pivot from the top-left corner instead of center.

```gdscript
# CORRECT
node.pivot_offset = node.size / 2
TweenFX.pop_in(node, 0.3)

# WRONG — will scale from top-left
TweenFX.pop_in(node, 0.3)
```

### 2. TweenFX Looping Animations

These loop indefinitely and MUST be explicitly stopped:
- `alarm`, `breathe`, `attract`, `glow_pulse`

Call `TweenFX.stop(node)` or kill the tween when the node is hidden/freed. Forgetting to stop causes orphaned tweens.

### 3. TweenFX.tada() Signature

`TweenFX.tada(node, duration)` — only 2 arguments. There is no scale parameter.

### 4. Deep Space Theme Constants

Never hardcode colors or spacing. Always use the Deep Space theme system:
- Spacing: 8px grid (8, 16, 24, 32)
- Touch targets: 48-56px minimum
- Typography: 11-24px scale
- Colors: base/elevated/input/border/accent/text/status palettes
- Use `BaseCampaignPanel` factory methods for consistent panel construction

### 5. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`.

---

## Responsive / Adaptive UI (Jun 2026 mobile/tablet re-pivot) — FOUNDATIONAL

The app is dual-platform adaptive: 375px phone → 1920px desktop, both orientations. **`ResponsiveManager` (autoload) is the single source of truth.** Full SOP: `docs/sop/responsive-adaptive-ui.md`. Hard rules:

- **Breakpoints are DPI-aware.** `ResponsiveManager` classifies by `window_get_size()/screen_get_scale()` (density-independent), NOT `get_visible_rect()`. Reason: with `canvas_items`+`expand`+square 1080 base, portrait content is ALWAYS ~1080 wide, so the content rect can't distinguish a phone from a tablet. Call `get_effective_columns()` / `get_effective_crew_columns()` / `should_collapse_to_single_column()` (orientation-aware) — never the legacy `get_optimal_columns()`.
- **Rotation re-layout rides `layout_class_changed`** (fires on width-bucket change OR rotation), NOT `breakpoint_changed` (misses constant-width rotation). `CampaignScreenBase` + `BaseCampaignPanel` already wire it + dedupe via `_last_effective_columns` + `_last_is_portrait`.
- **Orientation-dependent `_apply_*_layout` overrides MUST branch on `should_use_single_column()`**, not the width bucket — a bucket-keyed override re-fires on rotation but changes nothing (the bug behind HelpScreen sidebar + EquipmentPanel split).
- **A `_ready()` override MUST call `super._ready()`** or it loses ALL responsive wiring (TacticsDashboard regressed on this). Code-built responsive nodes get their initial layout from the post-`_setup_screen()` re-apply in `CampaignScreenBase._ready`.
- **Multi-pane screens (N side-by-side panels) → `AdaptivePanelGroup`** (`add_pane(control, title)`, `portrait_mode = STACK|TABS`). Panes reparent in ONCE; mode changes only toggle columns/visibility/TabBar (no per-rotation reparent churn). A 3-col→1-col screen also needs an OUTER scroll + content-sized columns (don't nest inner+outer scrolls).
- **`project.godot [display]`**: square `1080×1080` base, `stretch canvas_items/expand`, `handheld/orientation=6` (SENSOR), `viewport_min_width=320`.
- **Touch targets stay device-keyed** (COMFORT on mobile bucket, MIN otherwise), NOT orientation-keyed.
- Tests: `tests/unit/test_responsive_manager_effective_columns.gd` (16), `tests/unit/test_adaptive_panel_group.gd` (8). Live MCP verify via `DisplayServer.window_set_size()` + read `ResponsiveManager` (async — read next call).

## May 27, 2026: Narrative Scene Composition + Ambient Motion

SceneStage gained roster-aware **character slots** + scene-wide **ambient motion**. Full authoring SOP: `docs/sop/narrative-scene-authoring.md`; UI wiring: `references/narrative-screen.md`. Hard rules (each is also an anti-regression):

- **Depth = TREE ORDER, not `z_index`.** A `SlotLayer` inserted between bg and actor layers keeps crew figures behind baked foreground actors. `z_index` overrides tree order across parents and breaks this.
- **Ambient motion on layer CONTAINERS, never individual rects.** `_layout_character_slots()` owns each figure's `rect.position`; drifting a rect fights the layout on resize. Drift/breathe the container — the transform composes on top.
- **Overscan (1.04) baseline** hides the letterbox edge that scene-wide drift would expose; the breathe scale-swing floor stays AT overscan so headroom never collapses.
- **Gate scene/ambient motion on `ThemeManager.is_reduced_animation_enabled()`** (raw `create_tween`, so the gate is manual — TweenFX's guard doesn't cover it). Off = scale 1, pos 0, static.
- **Motion is verified by a headless transform-probe, NOT a screenshot** — a still frame can't show drift. Sample node `.position`/`.scale` at t0 vs t+3s.
- Crew figures: `SpeciesFigureRegistry` (`species_id → PNG`, existence-aware variant pick). Feet-anchored (bottom-center), uniform humanoid shapes only (scales by HEIGHT). `assets/figures/species/<id>_NN.png`.
- Full-canvas layer contract: every scene PNG must be canvas-sized (Photoshop per-layer export TRIMS — use Layers to Files, Trim UNCHECKED). Run `--headless --import` after new PNGs.
- Dev harness: `src/ui/screens/dev/SceneViewer.tscn` (`-- scene_id=X test_crew=precursor,swift,k_erin autoshot`).

## May 29, 2026: Sprints 1-6 narrative+combat ship + retro fixes

Six narrative-system + combat-system sprints shipped in one session (B2/A5/Tier 2/B3/A2/A1). UI-domain pieces:

- **B2 Auto-resolve narrative bridge** (`CampaignTurnController.gd`). Wraps auto-resolved battle outcomes in `NarrativeScreen` as `Aftermath: Victory/Objective Held/Withdrawal` before POST_MISSION. Same gating pattern as Story Track / Character Phase / Crew Task integrations: branch on `SettingsManager.are_narrative_events_enabled()` + DLC, present, listen for `narrative_completed`/`skip_requested`, route to next phase.
- **A5 SceneAtmosphereLayer** — sibling of SceneStage inside IllustrationFrame, GPUParticles2D-driven, 5 effects (snow/dust_motes/fog_haze/embers/smoke_columns). Procedural radial-falloff white circle generated at runtime + color_ramp tinted per-effect → atmosphere PNG textures are [OPTIONAL] not [NEEDED]. `AtmosphereCatalog.gd` SSOT, `world_trait_atmosphere.json` mapping. Reduced Motion gated. `clip_contents = true` prevents particles bleeding into the narrative panel.
- **Tier 2 image slots** — `SceneStage.gd` extended with slot `anchor_mode` (feet/center/top/top_left) + `scale_mode` (height/width) + assignment `source` field. `Tier2AssetRegistry.gd` maps `tier2:<key>` to res:// paths. SOP §4a documents the contract. Feet-anchored default = backward compat preserved.
- **A2 advisor quotes** — `data/narrative/advisor_quotes.json` expanded 18 → 108 (6 quotes per role × mood cell). Voice-consistent per role. No em dashes in new lines (grandfathered seed kept).
- **Sub-cat scene PoC** — 8 of 14 sub-category scenes shipped via `scripts/scene_layers_to_manifest.py` + headless import. Canvas sizes wildly varied (1280×696 to 6000×3888) but `STRETCH_KEEP_ASPECT_CENTERED` letterboxes correctly. Scene IDs MUST match the `art_tag` keys in `atmosphere_openers.json` (full `ship_interior_*` prefix, `battle_aftermath_*` prefix, etc.).
- **Species placeholders** — engineer/krag/skulker/psionic/unity_agent (×3 variants); De-converted intentionally [OUT OF SCOPE] as Strange Character type rendered via underlying species.

### Retro-review caught 2 silent-failure UI bugs (now fixed + tested)

- `CampaignTurnController._battle_result_to_narrative_dict` returned key `"briefing"` but `NarrativeScreen._populate_briefing` reads `"briefing_text"`. Fix: producer key now matches consumer; 8 gdUnit4 bug-pin tests in `tests/unit/test_b2_narrative_bridge.gd` lock the contract.
- Same file used `"held_the_field"` but both resolvers emit `"held_field"`. Held-field partial successes were silently mislabeled as Withdrawals. Fix accepts both spellings, defaults to FALSE.
- **General rule**: when writing any dict destined for `NarrativeScreen.present()` (or `BattleCalculations.resolve_ranged_attack`, or any cross-file consumer), Grep the consumer's `_populate_*` / `_data.get(...)` sites for the EXACT key names. Key drift is silent — no error, no warning, just feature missing at runtime.
- For unit-testability of pure-dict-transform helpers on Control-extending classes: refactor the helper `static`. Tests then call `ClassName._helper(args)` without instantiation (the Control's `@onready` % scene asserts would otherwise trip).

## Cross-Mode Character Transfer Framework — UI pieces (SHIPPED — all 4 modes)

Characters move between the 4 persistent modes via a canonical-hub service (`src/core/character/CharacterTransferService.gd`); transfers are direct file-drops at `user://transfers/<id>.json`, NOT a barracks. UI-domain wiring:

- **Mode-generic pickup is in `src/ui/screens/campaign/CampaignScreenBase.gd`** (the shared base): `_check_pending_transfers()`, `_apply_pending_transfers()`, `_add_character_to_mode()` (dispatches per `_campaign_mode()`: five_parsecs→`add_crew_member`, bug_hunt→`add_main_character`, planetfall→`add_roster_character`, tactics→`add_veteran_character` — Jun 4, was a push_warning Phase-2 placeholder), `_notify_transfer_result()`, and the `_on_transfers_applied()` virtual hook. Each dashboard (CampaignDashboard / BugHuntDashboard / PlanetfallDashboard / TacticsDashboard) calls `_check_pending_transfers.call_deferred()` in `_setup_screen` and OVERRIDES `_on_transfers_applied()` to rebuild its crew display. Replicate this override pattern for any new mode dashboard.
- **Planetfall import UI**: `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` (NEW) — select source char from 5PFH/Bug Hunt saves → preview → Class Training D6 picker → add to roster. The creation-wizard entry is the import button in `PlanetfallRosterPanel.gd` (was a disabled "future sprint" stub, now wired). Dashboard cards on PlanetfallDashboard: "Import Veterans" + "Muster Colonists Out". BugHuntDashboard already had Enlist / Muster Out cards (Foundation).
- **Tactics import UI (Jun 4)**: `src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd` (NEW) — select source char from 5PFH/Bug Hunt/Planetfall saves → preview the Tactics conversion → embed snapshot → `add_veteran_character`. TacticsDashboard cards: "Commission Veteran" (opens the panel) + "Retire Veteran Out" (3-target overlay → 5PFH / Bug Hunt / Planetfall). A transferred char becomes a NAMED VETERAN in `TacticsCampaignCore.veteran_characters[]`, NOT a squad unit.
- Imported chars are added through the NEW mutator `FiveParsecsCampaignCore.add_crew_member()` (5PFH) etc. — never append to crew arrays directly from a panel.

## Session 53: Compendium Setup Card + Colony Travel Buttons (Apr 9, 2026)

### ExpandedConfigPanel — New "COMPENDIUM SETUP OPTIONS" Card
Added `_build_compendium_setup_section(parent)` with `COMPENDIUM_SETUP_FLAGS` const (6 items). Pattern: DLC-gated CheckBox + description Label per flag, HSeparator between packs. Full-width (`custom_minimum_size.x = 1000`). Handler `_on_compendium_setup_toggled(enabled, flag_name)` uses `DLCManager.set_feature_enabled()` + `serialize_campaign_flags()`. Build order: ...narrative → compendium_setup → expansion_features.

### ExpansionFeatureSection — Exclusion Filter
`setup()` now accepts `exclude_flags: Array[String]` param. Filters in `_build_pack_section()` loop. ExpandedConfigPanel passes the 6 promoted flags to avoid duplicate toggles.

### UpkeepPhaseComponent — Colony World Buttons
`_build_colony_world_buttons(vbox)` adds species-conditional travel buttons after zone buttons. Krag: amber-brown style, 1 SP cost (disabled if insufficient). Skulker: green style, free. `_on_colony_travel_pressed(species_id)` handles SP deduction + planet generation + travel state.

---

## Session 49: UX Polish Sprint (Apr 8, 2026)

8 items shipped in one sprint. Key changes in ui-panel-developer domain:

### ThemeManager.gd — Two Bug Fixes
- **Colorblind mode was silently broken**: `_apply_colorblind_variant()` checked for dict keys `"text"`/`"background"` but AccessibilityThemes palettes use `"text_primary"`/`"base"`. All 3 modes (Deuteranopia/Protanopia/Tritanopia) now apply correctly. Also wires accent, border, focus, success colors.
- **Reduced animation toggle didn't apply immediately**: Added `_apply_animation_settings()` call inside `set_reduced_animation()`. Was only called at cold boot via `_load_config()`.

### TweenFX Added to 4 Major Screens
All guarded by `ThemeManager.is_reduced_animation_enabled()`. Explicit `var x: bool =` typing (Godot 4.6 can't infer `A and B` with nullable).
- **CampaignDashboard**: Staggered `fade_in` cascade on crew cards (0.18s each, 50ms interval)
- **WorldPhaseController**: `fade_in` on active step container in `_show_current_step()`
- **CharacterDetailsScreen**: Staggered `pop_in` on stats_grid badges (needs `pivot_offset` set)
- **SettingsScreen**: `fade_in` on scroll content after `_build_ui()`

### MainMenu.gd — Load Campaign Dialog Styled
Deep Space StyleBoxFlat (COLOR_BASE bg, COLOR_BORDER border, 6px corners) applied to AcceptDialog. Campaign buttons get COLOR_ELEVATED normal / COLOR_ACCENT hover. Import button gets cyan (#4FC3F7) border accent. Matches Bug Hunt dialog pattern at line 493.

### CaptainPanel.gd + CrewPanel.gd — Help (?) Buttons
Both preload `RulesPopupClass`. Cyan "?" button (40x40, flat) added to `$Content/Controls`. On press → `RulesPopupClass.show_rules()` with Core Rules page references (pp.12-22 captain, pp.23-25 crew).

### FiveParsecsCrewExporter.gd — HP Integer Formatting
Lines 149, 232: `str(health) + "/" + str(max_health)` → `"%d/%d" % [int(health), int(max_health)]`

### Gotcha: Godot 4.6 Boolean Type Inference
`var x := tm != null and tm.is_reduced_animation_enabled()` fails compile. Must use `var x: bool = ...` for compound boolean with nullable.

---

## Session 47: Equipment Pipeline — UI Domain (Apr 8, 2026)

### UnifiedBattleLog — New Entry Types

- 5 new `ENTRY_COLORS`: armor_save, deflector, stim_pack, trait_effect, item_consumed
- 5 new logging methods: `log_armor_save()`, `log_deflector_use()`, `log_stim_pack()`, `log_trait_effect()`, `log_item_consumed()`

### PostBattleSequence — Consumed Items Signal

- Connected `items_consumed_in_battle` signal from PostBattlePhase backend
- `_on_backend_items_consumed` handler processes consumed item display
- Disconnect in `_exit_tree()` for cleanup

### PostBattleSummarySheet — Consumed Items Section

- `_setup_consumed_items()` dynamically creates section after LootSection
- Uses `main_vbox.move_child()` for correct ordering

### TravelPhaseUI — World Arrival + Forge License

- World Arrival Summary panel: displays world trait, rivals, license status
- Forge license UI with crew picker dialog
- 10 travel event state mutation helpers
- World trait persistence to `campaign.world_data`

---

## Session 43: Story Points Dashboard Wiring (Apr 7, 2026)

### CampaignDashboard.gd — New Methods

- **`_sync_sp_system()`** — Reloads `_sp_system` from `campaign.story_point_turn_state` so popover shows fresh data. Called from `_on_phase_event()`, `_on_phase_completed()`, and `_toggle_sp_popover()` (safety net before open). Without this, popover balance/limits go stale after CampaignPhaseManager modifies campaign during turn rollover.
- **`_show_xp_character_picker(campaign)`** — Shows ConfirmationDialog + ItemList for "+3 XP" spend. Filters to alive/active crew. On confirm: applies `+3 XP` to selected character + journal entry. On cancel/close: refunds SP via `_sp_system.add_points(1, "Cancelled")`.
- **Extra Action toast** — EXTRA_ACTION branch now shows `NotificationManager.show_notification()` toast confirming the tabletop action.

### StoryPointPopover.gd — Battle-Only Star Abilities

In `_update_star_rows()`, Dramatic Escape and It's Time To Go are now force-disabled on dashboard:
- `battle_only` check disables button + sets tooltip "Available during battle"
- Uses `COLOR_WARNING` for uses label when has remaining uses but battle-locked
- Uses `COLOR_TEXT_SECONDARY` for name label (dimmed but not fully disabled)
- "It Wasn't That Bad" and "Rainy Day Fund" remain usable from dashboard

---

## Session 41: UX Sprint — Dashboard Polish + Accessibility + Tutorials (Apr 7, 2026)

### CampaignDashboard.gd Changes
- **HubFeatureCards** — `_add_hub_cards()` adds Compendium + Battle Simulator cards to `center_vbox` (after ship/equipment). Uses `HubFeatureCard.new()` (class_name, no preload). Must `add_child()` BEFORE `setup()` since `_build_ui()` runs in `_ready()`
- **Role pills** — `_create_pill(text, color)` helper: StyleBoxFlat with 8px corners, 0.2 alpha bg, 1px border. Used in `_build_crew_card()` replacing plain "Species / Class" subtitle. Blue=species, Purple=class, Amber=captain
- **Stat strip** — `_update_stat_strip()` inserts `__stat_strip` HBoxContainer between HeaderPanel and MainContent via `parent.move_child(strip, header_panel.get_index() + 1)`. 4 badges: CREW/TURN/CREDITS/STORY PTS
- **Help button** — "?" button added to HeaderHBox, triggers `_on_help_pressed()` which loads TutorialUI + starts "campaign_dashboard" tutorial
- **Tutorial auto-start** — `_check_dashboard_tutorial()` called deferred from `_setup_screen()`

### AccessibilitySettingsPanel.gd Changes
- **Reduced Motion toggle** — CheckButton wired to `ThemeManager.set_reduced_animation()` / `is_reduced_animation_enabled()`. Bold title + italic description pattern
- **Font Size dropdown** — OptionButton (Small/Normal/Large → 0.85/1.0/1.15) wired to `ThemeManager.set_scale_factor()` / `get_scale_factor()`

### CharacterDetailsScreen.gd — Crew Swipe
- `_crew_list: Array[Dictionary]` + `_current_index: int` loaded from `GameStateManager.get_temp_data("crew_list_for_swipe")`
- `_unhandled_input()` detects horizontal swipe (touch: delta.x > 80, duration < 0.4s, abs(x) > abs(y)*2) + arrow keys
- `_navigate_crew(direction)` wraps index, creates new Character from dict, calls `populate_ui()`
- Page dots: `_build_page_dots()` / `_update_page_dots()` — ● active (COLOR_FOCUS), ○ inactive (COLOR_TEXT_DISABLED)
- **CrewManagementScreen.gd** — `_store_crew_list_for_swipe()` converts all members to dicts, finds selected index by character_id

### TutorialOverlay.gd — Full Rewrite
- CanvasLayer `layer = 95` (between Notifications L90 and Loading L99)
- Deep Space styled tooltip (dark bg, cyan border, 8px corners)
- VBox layout: label + step counter + Skip/Next buttons
- `_find_parent_scroll()` + `ScrollContainer.ensure_control_visible()` for scroll-aware targeting
- `ReferenceRect` for highlight border (not ColorRect)
- Centering fallback when no target_path specified

### Tutorial JSON Files
- `data/tutorials/first_run.json` — 4 steps (welcome, New Campaign, Library, Options)
- `data/tutorials/campaign_dashboard.json` — 6 steps (header, left/center/right columns, action button, save)

---

## Session 40b: Legal Stack UI + Compendium Library + Icon SOP (Apr 7, 2026)

### Legal UI Components

- **EULAScreen.gd + .tscn** — First-launch blocking screen. Scrollable RichTextLabel with Markdown-to-BBCode. Privacy checkbox + "View Privacy Policy" link. Bottom-pinned DECLINE (red) / ACCEPT (green) via `DialogStyles`. Persists to `user://legal_consent.cfg`
- **LegalTextViewer.gd** — Reusable full-screen Markdown viewer. Opens from Settings → Legal & Privacy section. Used for EULA, Privacy Policy, Open Source Licenses, Credits
- **Settings → Legal & Privacy section** — New section in `SettingsScreen.gd`: 4 document links (LegalTextViewer), analytics toggle (default OFF), Export My Data button, Delete All Data button (red danger + confirmation dialog)

### Compendium Library UI (Session 40b — OVERHAULED in Session 48)

- Renamed to "Library" in MainMenu + hub title
- 10 categories, 246+ items, extensible for Planetfall/Tactics
- **Session 48 overhaul**: Both screens extend `FiveParsecsCampaignPanel` (responsive). Hub uses `HFlowContainer` for 4-col desktop / 1-col mobile grid. Category view has card-style rows (3px cyan left border, type icons, hover effects, TweenFX.press feedback). Filter tabs humanized via `set_meta("filter_value")`. Section headers group items by type. `EmptyStateWidget` for no results. 6 new type SVG icons in `assets/icons/compendium/items/`.
- **Key pattern**: Skip `super._ready()`, call `_ensure_base_background()` + `_setup_responsive_layout()` manually to avoid unwanted FormContainer structure
- **Gotcha**: `_create_section_header` name collides with BaseCampaignPanel — renamed to `_create_group_header`
- **Gotcha**: TweenFX.pop_in() requires CanvasItem, NOT Window — removed from RulesPopup
- **Gotcha**: New SVGs need `--headless --import` to generate .import files

### Icon SOP (game-icons.net)

- Source: game-icons.net SVGs (CC BY 3.0), local repo at `C:\Users\admin\Documents\lorcana-tokens\game-icons-sorted-by-artist`
- Format: white on transparent, use `modulate` for color
- Path convention: `assets/icons/{context}/` (e.g., `assets/icons/stats/`, `assets/icons/equipment/`)
- Attribution in `data/legal/third_party_licenses.md`

---

## Session 45: Bug Hunt UX Fixes (Apr 8, 2026)

### HubFeatureCard Pending Data Pattern (CRITICAL)
`HubFeatureCard.setup()` can be called before OR after `add_child()`. If called before `_ready()`, data is stored in `_pending_*` vars and applied in `_ready()`. Always safe either way now.
- CampaignDashboard does `add_child` then `setup` (was always fine)
- BugHuntDashboard does `setup` then `add_child` (was broken, now fixed)

### CampaignDashboard._create_colored_badge() (renamed)
Was `_create_stat_badge()` — renamed to avoid parent signature conflict with `CampaignScreenBase._create_stat_badge(stat_name: String, value: int, show_plus: bool)`. Dashboard version takes `(label_text, value_text, color)`.

### TransitionManager + _ready() Timing
When `TransitionManager.fade_to_scene()` instantiates a scene, `_ready()` fires BEFORE the node is in the scene tree. Any `get_node_or_null("/root/...")` calls will fail. Fix: `call_deferred("_initialize")` in `_ready()`.

---

## Session 39: Crew Size UI Changes (Apr 7, 2026)

### ExpandedConfigPanel — Difficulty & Progressive Difficulty (Session 40)

- "Nightmare" label renamed to "Insanity" (Core Rules p.65)
- Only 5 real difficulty modes exposed: Story(Easy), Standard(Normal), Challenging, Hardcore, Insanity
- HARD/NIGHTMARE/ELITE enum values are DEPRECATED — never add them to UI
- **Progressive Difficulty section** (DLC-gated under PROGRESSIVE_DIFFICULTY):
  - Two CheckBoxes: Option 1 (Classic) + Option 2 (Compendium), combinable
  - Warning label appears when both checked ("deadly around Turn 20")
  - Stored as `local_campaign_config["progressive_difficulty_options"]` (Array of ints)
  - Included in `get_campaign_config_data()` and `restore_panel_data()`

### ExpandedConfigPanel — Dead Code Deleted (Session 40)

These files NO LONGER EXIST — do not reference them:
- ConfigPanel.gd+.tscn (replaced by ExpandedConfigPanel)
- CampaignSetupDialog.gd+.tscn (bypassed by MainMenu remapping)
- CampaignSetupScreen.gd, DifficultyOption.gd, gameplay_options_menu.gd
- QuickStartDialog.gd, CampaignLoadDialog.gd, CampaignSummaryPanel.gd

### ExpandedConfigPanel — CREW SIZE Card
- New OptionButton with item IDs 4, 5, 6 (default index 2 = crew size 6)
- Description label updates per selection showing enemy dice formula
- Stored in `local_campaign_config["campaign_crew_size"]`
- Follows same pattern as existing difficulty section (`_build_difficulty_section`)
- Restore via `set_campaign_config()` matches by item_id

### PreBattleUI — Deployment Cap
- `_max_deploy: int` instance var set from `campaign_crew_size`
- "Deploying X / Y max" Label added to crew selection panel
- `_on_character_selected()` returns early at cap (no overselection)
- CampaignTurnController passes `campaign_crew_size` to `setup_crew_selection()`

### FinalPanel — Crew Size in Summary
- Crew count label shows "X Crew Members (Campaign Size: Y)"
- Completion check uses `campaign_crew_size` from config, not hardcoded 6
Applies to scene meta, config dicts, chart data, theme lookups. Zero exceptions.

### 6. WorldPhaseComponent Base Class Collisions

WorldPhaseComponent defines `_help_dialog` var and `_show_help_dialog()` method. Child components MUST NOT redeclare these — causes Parser Error at runtime (not caught by headless check). UpkeepPhaseComponent and CrewTaskComponent both had this bug (fixed Mar 21).

### 7. BUG-034 Selected Card Contrast Pattern

When a card changes background color on selection, update text colors too:
```gdscript
# In _set_card_selected_state():
if selected:
    desc_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)  # bright on dark bg
else:
    desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)  # muted on normal bg
```

### 8. PDF Rulebooks Available

If you need to verify UI labels, stat names, or game terminology against the source material:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Python (PyPDF2 ONLY)**: `py -c "from PyPDF2 import PdfReader; r = PdfReader('path'); print(r.pages[PAGE].extract_text())"` — do NOT use PyMuPDF/fitz

### 9. UIColors Over Local Constants

World phase components should use `UIColors.COLOR_EMERALD`, `UIColors.COLOR_RED`, etc. instead of local `const COLOR_*` definitions. Base class provides `TOUCH_TARGET_MIN := 48`.

**Bug Hunt panels** (Session 44): All 12 Bug Hunt UI files now use `const _UC = preload("res://src/ui/components/base/UIColors.gd")` pattern. BugHuntDashboard extends `BugHuntScreenBase` → `CampaignScreenBase` and uses factory methods directly. Child panels (ConfigPanel, SquadPanel, etc.) use the `_UC` preload pattern since they extend Control directly (instantiated via `Script.new()`).

### 10. DLC UI Components (Session 33, Apr 6)

New code-built components in `src/ui/components/dlc/` and `src/ui/screens/store/`:
- **DLCContentCatalog.gd** — Marketing copy catalog (RefCounted, class_name). Use static methods: `get_pack_catalog()`, `get_pack_name()`, `get_features_for_display()`, `get_pack_for_flag()`
- **DLCPackCard.gd** — Rich card extending PanelContainer. Call `setup(dlc_id)` then `refresh(is_owned, price, enabled_count, total_count)`
- **DLCFeatureToggleRow.gd** — Atomic toggle row. `setup()` takes 7 params. Two states: owned (CheckBox) or locked (lock + upsell button)
- **ExpansionFeatureSection.gd** — Grouped toggles. `setup(mode)` with 3 modes: "campaign_creation" (shows disclaimer), "settings", "read_only"
- **DLCUpsellBanner.gd** — Static factory `DLCUpsellBanner.create_for_flag(flag_name)` returns configured PanelContainer
- **DLCActivationToast.gd** — Static helper `DLCActivationToast.show_for_dlc(dlc_id)` adds CanvasLayer toast
- **StoreScreen.gd** — Extends CampaignScreenBase. Uses DLCPackCard, BundleCard, BugHuntCard
- **MainMenu** — "Expansions" button routes to SceneRouter `"store"`. Social footer at bottom-left (code-built, hides on narrow)

### 11. Asset Generation Requires `--import` Before Runtime Test

After any script generates new PNGs (or other assets) into `assets/`, MUST run `Godot --headless --import --quit` before runtime testing. `.import` sidecar files don't exist until Godot scans the asset, and `ResourceLoader.exists()` returns false until that scan completes. Silent-fallback patterns (atlas-load misses, portrait-load misses) render nothing without errors. Bit OrnamentPanel atlas sprint (May 23, 2026).

### 12. Modiphius .ai Border Delivery Is Page-Chrome ONLY

The Modiphius `.ai` border delivery at `assets/ui/borders/ornaments/ornament_*.svg` contains ONLY page-chrome: chapter title brackets, edge accents, page-corner ornaments at PAGE corners. It does NOT contain the small panel-corner brackets the rulebook uses on individual content panels (NORMS OF THE GAME p.11, CHARACTER CREATION p.12, COVER EXAMPLES p.39, etc.) — those are typography decoration drawn in InDesign during typesetting, not delivered as Illustrator assets. Verified 2026-05-23 via 37-fragment extraction + filesystem search.

For per-panel corner brackets use **`OrnamentPanel.gd`** with a procedurally-generated atlas (`scripts/generate_corner_bracket_atlas.py`). Two atlas variants: `ornament_atlas_compact.png` (128×128, 32px corners) for badges, `ornament_atlas_9slice.png` (256×256, 64px corners) for sections. NinePatchRect's "corners stay fixed when scaled" behavior matches the rulebook's "brackets are fixed size at all panel sizes" rule exactly. See `.claude/skills/ui-development/references/ornament-panel.md` for API + tuning workflow + decision matrix vs CalloutCard/BookFrame.

Sci-fi vs fantasy bracket-read: multiple notches per leg + stepped tips = sci-fi machined panel. Clean L with one notch = fantasy RPG corner ornament. Tune via `*_FRAC` constants in the generator script, then re-run `--import` (see #11).

### 13. Design Analysis Before Coding When Matching Printed Source

When the task is "build a UI component to match printed reference material" (rulebook, magazine, design system spec): pause before coding. The 30-60min analysis phase saves multiple code-tinker iterations.

1. **Render the source at HIGH RES** — ≥2x scale (`pypdfium2 ... .render(scale=2.5)`). 80 DPI hides small details and leads to wrong conclusions. I once concluded "rulebook has no per-panel corner brackets" because my 80 DPI renders blurred them.
2. **Sample 8-12 representative page types** — chapter intros, body content, callouts, tables, appendix. One page won't reveal the system.
3. **Build an element-by-page-type comparison table** — forces you to be explicit instead of generalizing from gut feel.
4. **Look at FACING PAGES** — tabletop rulebooks often mirror-symmetric. ONE asset + 4 flips often = 4 corners.
5. **Infer the design rules** from the table (what always appears with what, what scales, what stays fixed). Those become your component requirements.
6. **THEN design the component API.** Not before.

Anti-pattern: "I see the reference, I'll just start building." Visual ≠ design rules. Burned 3+ iterations on OrnamentPanel before doing this (2026-05-23). Once analysis was done, the architecture was obvious within an hour.

### Session 36: Story Track UI + Character QOL (Apr 7, 2026)

- **StoryPhasePanel.gd** — Rewritten: 3 modes (clock, event briefing, evidence search). Code-built UI, extends BasePhasePanel
- **StoryTrackSection.gd** — `set_story_data()` accepts StoryTrackSystem state dict (7 milestones, clock/evidence)
- **CampaignDashboard.gd** — `_build_narrative_status()` (renamed from `_build_story_track_status()`) — shows intro progress, story track waiting state, or story track active status
- **CharacterEventTimeline.gd** — NEW component at `src/ui/components/character/`. Filterable event log (toggle buttons: All/Battle/Injury/Adv/Story/Kill). Deep Space themed, reverse-chronological
- **CharacterDetailsScreen.gd** — Portrait upload (FileDialog → Image.load_from_file → resize 256 → user://portraits/), status bar (chips: ACTIVE/SICK BAY, battles, kills, XP), stat color coding (green=max, red=danger, orange=warning), removed redundant history overlay, `_get_char_id()` helper

### Session 38-39b: Intro Campaign + Story Track Config Panel + Runtime Fixes (Apr 7, 2026)

- **ExpandedConfigPanel.gd** — 3 separate cards → 1 unified "NARRATIVE OPTIONS" card with 2 CheckBoxes + combo explanation label. Config keys: `story_track_enabled` (bool) + `introductory_campaign` (bool). **Bug fix**: Intro checkbox visibility uses `is_feature_available()` (DLC owned) not `is_feature_enabled()` (DLC owned + toggle) — avoids chicken-and-egg during creation.
- **InlineRenameWidget.gd** — `renamed` signal renamed to `name_confirmed` (native VBoxContainer `renamed` conflict in Godot 4.6)
- **WorldPhaseController.gd** — `_should_skip_intro_step()` for intro campaign phase gating + **added to `_can_advance_to_next_step()`** to prevent deadlock (same pattern as Black Zone auto-skip)
- **CampaignDashboard.gd** — `_build_narrative_status()` queries live `CampaignPhaseManager.get_intro_status()` first, falls back to progress_data (fixes stale-data-on-first-load issue)
- **FinalPanel.gd** — Now shows "Introductory Campaign: Enabled (6 guided turns)" in review summary
- **SceneRouter.gd** — New `navigate_to_with_loading()` method for heavy transitions with LoadingScreen
- **CampaignCreationUI.gd** — Uses `navigate_to_with_loading()` for campaign start transition
- **MainMenu.gd** — `_navigate_with_loading()` helper; Continue/Load/Import all use loading screen

### Session 37: UX Enhancement Sprint — Fallout Companion App Patterns (Apr 7, 2026)

14 new reusable components in `src/ui/components/common/`, 5 modified files, 0 compile errors. Based on 65-screenshot analysis of the Fallout Wasteland Warfare companion app by Maloric Digital.

**New components (all code-built, no .tscn):**
- **EmptyStateWidget** — Themed VBoxContainer: icon + title + flavor text + optional action button. Used in CampaignDashboard (6 locations)
- **LoadingScreen** — CanvasLayer L99, itemized task list: pending→active (glow_pulse)→complete (checkmark). `run_sequence()` for staggered auto-completion
- **AcknowledgeDialog** — Titleless Window modal. Static: `AcknowledgeDialog.show_message(parent, text)`
- **StepperControl** — [−] value [+] HBoxContainer, auto-disable at bounds, `punch_in` on change. `setup(initial, min, max, step)`
- **InlineRenameWidget** — Display/edit VBoxContainer. Tap → LineEdit + ✓/✕. `headshake` on empty, `fold_in` transition
- **PersistentResourceBar** — CanvasLayer L80. Credits/StoryPts/Patrons/Rivals. `show_bar()`/`hide_bar()` with fold animations
- **PreviewButton + ItemPreviewPopup** — Eye icon → read-only item detail Window. `PreviewButton.set_preview_data(dict)`
- **HubFeatureCard** — PanelContainer: cyan left border + icon + title + desc + arrow. Hover/press effects
- **OverflowMenu** — ⋮ Button → PopupPanel with labeled count badges
- **DialogStyles** — Static utility: `style_confirm_button()`, `style_danger_button()`, `style_primary_button()`
- **RulesPopup** — Full rules reference Window. Static: `RulesPopup.show_rules(parent, title, body, requirements)`
- **DebugScreen** — Settings→Debug: log viewer + COPY TO CLIPBOARD + EMAIL SUPPORT. `DebugScreen.log_message()` static logger

**Modified files:**
- `CrewTaskEventDialog.gd` — Card draw (slide from left, 250ms) + discard (drop+fade, 200ms) + `fold_in` outcome reveals
- `CampaignDashboard.gd` — 6 empty states replaced with EmptyStateWidget themed copy
- `TransitionManager.gd` — `fade_to_scene_with_loading()` method (uses `load()` for LoadingScreen — autoload timing)
- `SettingsScreen.gd` — DEBUG button + `_add_toggle_row()` enhanced with description parameter (bold title + italic desc)
- `MainMenu.gd` — Version number label in social footer

**Key patterns established:**
- `_pending_*` for static factory Window subclasses (data stored before `_ready()`)
- `load()` instead of class_name in autoloads (TransitionManager → LoadingScreen)
- Raw Tween for horizontal slides (TweenFX has no horizontal variant)
- `TweenFX.stop()` before state change on looping animations (glow_pulse in LoadingScreen)
