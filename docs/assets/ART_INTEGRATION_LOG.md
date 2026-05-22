# Modiphius Art - Integration Log

Tracks which assets have been pulled out of the Drive delivery and wired into
the project. The auto-generated `MODIPHIUS_ART_REFERENCE.md` answers *what
exists*; this file answers *what's wired*.

Append entries as integration work lands. Do not edit the auto-generated docs.

---

## 2026-05-21 - Three quick wins (cover art, species portraits, Planetfall preset crew)

### Win 1: Mode cover art on MainMenu

**Files copied** (`assets/covers/`):
- `cover_standard.png` (from `Cover Text/5PFH_Title_Red.png`)
- `cover_bug_hunt.png` (from `Cover Text/5PH_Bug Hunt_Cover_001w.png`)
- `cover_planetfall.png` (from `Cover Text/5PH_Planetfall_Cover_001w.png`)
- `cover_tactics.png` (from `Cover Text/5PH_Tactics_Cover_001w.png`)

**Code changes**:
- `src/ui/screens/mainmenu/MainMenu.gd`:
  - Added `COVER_PATHS` const dict (4 entries)
  - Added `_build_mode_showcase()`, `_wire_mode_hovers()`, `_swap_cover()` methods
  - Inserted a `ModeShowcase` TextureRect anchored to the left half of the menu
  - Hover on New Campaign / Bug Hunt / Tactics / Planetfall swaps the cover
    with a 0.34s crossfade (0.12s out, 0.22s in)
  - Hidden on narrow viewports (< 768px) via `_on_viewport_resized()`

**Behavior**: Cover defaults to Standard 5PFH. Hovering a mode button fades to
that mode's cover. No mouse-exit reset (sticky so the last hovered mode stays
visible).

### Win 2: Species portraits as Character.get_portrait() fallback

**Files copied** (`assets/portraits/species/`, 13 files, 88 MB):
- `engineer_01.png`, `feral_01.png`, `k_erin_01.png`, `krag_01.png`,
  `skulker_01.png`, `soulless_01.png`, `swift_01.png`, `swift_02.png`,
  `precursor_01.png`, `hulker_01.png`, `psionic_01.png`,
  `de_converted_01.png`, `unity_agent_01.png`

**Code changes**:
- New file: `src/core/character/SpeciesPortraitRegistry.gd` (RefCounted, all
  static). Maps `species_id` -> Array of portrait paths. Deterministic per
  `character_id` pick when multiple variants exist (e.g. swift has 2 variants).
- `src/core/character/Character.gd`:
  - Added `const SpeciesPortraitRegistry = preload(...)` at top
  - Rewrote `get_portrait()`: explicit `portrait_path` -> registry by
    `species_id` -> default fallback

**Behavior**: Any character without a manually-picked portrait now shows their
species portrait automatically. `CharacterCard._update_portrait()` already
consumes `get_portrait()` so no UI changes needed. Save/load unaffected
(portrait_path stays empty for registry-resolved characters).

**Species without portraits yet** (fall through to default): human, bot,
manipulator, traveler, empath, minor_alien, primitive, hopeful_rookie, mutant.

### Win 3: Planetfall preset-crew portraits + data

**Files copied** (`assets/portraits/planetfall/`, 7 files, 62 MB):
- `preset_captain.png`, `preset_science_officer.png`, `preset_old_man.png`,
  `preset_engineer_twins.png`, `preset_navigator.png`, `preset_pilot.png`,
  `preset_security.png`

**Code/data changes**:
- New file: `data/planetfall/preset_crew.json` - declares "The Original Seven"
  preset with member roles, species, portrait paths, Modiphius SKUs
- New file: `src/game/campaign/PlanetfallPresetCrew.gd` (RefCounted, static)
  with `list_presets()`, `get_preset(id)`, `get_members(id)`,
  `apply_member_to_character(char, member)` methods

**Behavior**: Data + loader ready. **No picker UI wired yet** -
`PlanetfallRosterPanel` is still a placeholder. Future work: add a "Use Preset
Crew" toggle in PlanetfallCreationCoordinator's Roster step that calls
`PlanetfallPresetCrew.apply_member_to_character()` for each member.

Stats/class/background intentionally NOT specified in the JSON so the
character creation flow keeps applying book-prescribed defaults once we know
them. Edit the JSON (not the loader) to add more presets.

---

## 2026-05-21 (late) - PSD layered composition pilot (Meeting.psd)

### Scope

User flagged that the Modiphius PSDs are fully layered. Pilot to prove
KoDP/Six Ages style scene composition: one PSD becomes many runtime scene
variants by mixing/matching figure overlays on a shared background. Plan
lives at `C:/Users/admin/.claude/plans/elegant-strolling-zephyr.md`.

### Pipeline built

- **`scripts/psd_extract.py`** - end-to-end auto-extraction. Uses `psd-tools`
  1.17.0 (`py -m pip install psd-tools`). Per Context7 verification, uses
  `psd.composite(layer_filter=lambda l, t=layer: l is t)` (canvas-sized output
  with position preserved in alpha), NOT `layer.composite()` (bbox-cropped).
  Walks `psd.descendants()`, skips groups/hidden/text layers, bounding-box
  heuristics assign each leaf layer to bg/actor/fx/prop/skip.
- **`src/ui/screens/narrative/SceneStage.gd`** - runtime composer. Loads
  `data/scenes/<id>.json`, stacks bg/actor/fx layers as same-sized
  TextureRects. Public API: `set_scene(id)`, `show_actor(id, fade)`,
  `hide_actor(id, fade)`, `set_actor_visibility(id, bool)`, `get_actor_ids()`,
  `clear()`. Uses `load()` for `res://` paths (export-safe).
- **`.gitignore`** - `assets/scenes/*/_raw/` excluded (raw cache, big files).
  The categorized copies in `bg/`, `actors/`, `fx/`, `props/` are committed.

### Meeting.psd extraction result

- 31 candidate leaf layers (after skipping groups/hidden/text)
- Categorized as: 13 bg + 5 actor + 0 fx + 12 prop + 1 skip
- Output sizes: actors 4.1 MB, bg 87 MB, props 13 MB, _raw cache 104 MB
- Composition manifest at `data/scenes/meeting.json`
- Per-layer catalog at `assets/scenes/meeting/_layer_catalog.json`

### Visual proof captured

3 SceneStage instances side-by-side on MainMenu showing:
1. Full scene (all 5 actors visible) - captain center + silhouettes bottom
2. Empty corridor (all actors hidden) - just architecture
3. Foreground figure only (1 actor visible) - silhouettes only, captain gone

Same architectural backdrop in all 3 cells, different figure composition.
Architecture proven. Screenshot saved in `.mcp/screenshots/`.

### Quirks / followups

- Heuristic miscategorization: my guess that `actor_03` was the captain was
  wrong - it turned out to be the silhouette layer. Categorization itself is
  correct (5 actor layers identified accurately), just need to inspect which
  ID is which for specific-actor compositions. The catalog JSON has bbox
  data to disambiguate.
- 13 bg layers feels high - the artist stacked many environmental plates
  (lighting passes, atmospheric haze, structural elements). They render fine
  stacked but each one is ~7 MB and they add up to 87 MB for one PSD. At
  scale (50 PSDs) this would be 4+ GB. Mitigation candidates: flatten bg
  layers in the extractor down to 1-3 representative plates, or apply VRAM
  compression via `.import` overrides.
- Heuristics don't yet detect fx layers from Meeting.psd (it doesn't use
  blend modes). Other PSDs likely do; need a real fx-heavy PSD to validate.

### What this unlocks

The narrative system can now do per-event visual citation: same "Meeting"
backdrop, but the rendered actors change depending on whether the player is
meeting a patron, a rival, an alien, or finding an empty room. That's the
KoDP/Six Ages multiplier we wanted. Production code unchanged - SceneStage
is ready to be wired into NarrativeScreen when that exists.

## 2026-05-21 (later) - Mode info card + portrait fallback fix + bug squash

### Scope expansion: ModeShowcaseCard

User flagged that a bare cover-swap wasn't enough. The left-half showcase
should be a full mode info card: cover hero, title, tagline, DLC badge, prose
description, key features, and a state-aware CTA button.

### User decisions locked

- **DLC gating**: Standard 5PFH free, Bug Hunt + Planetfall + Tactics all paid
  (Bug Hunt already had `bug_hunt` pack; added new `planetfall_pack` and
  `tactics_pack` to DLCManager.DLC_IDS).
- **Description copy**: pulled verbatim from the rulebooks. Sources cited per
  mode in `data/mode_info.json` under each entry's `source` field.

### New/changed files

- `src/core/systems/DLCManager.gd` (edit) - added `planetfall_pack` and
  `tactics_pack` entries
- `data/mode_info.json` (new) - 4 mode entries with verbatim Modiphius copy,
  taglines, key_features arrays, cover_paths, DLC requirements, CTA labels
- `src/ui/screens/mainmenu/ModeInfoCatalog.gd` (new) - RefCounted static
  loader. Methods: `get_all`, `get_mode`, `mode_ids`, `get_required_dlc`,
  `is_unlocked`, `get_cta_label`. Consults `/root/DLCManager`.
- `src/ui/screens/mainmenu/ModeShowcaseCard.gd` (new) - PanelContainer
  renders one mode entry. `set_mode(id, instant)` with crossfade. Emits
  `cta_pressed(mode_id, is_unlocked)`. Deep Space themed inline.
- `src/ui/screens/mainmenu/MainMenu.gd` (edit) - removed bare TextureRect +
  `_swap_cover` path, replaced with ModeShowcaseCard. CTA routing: unlocked
  modes fire the underlying mode button's pressed signal (reuses existing
  save-detect / dialog logic); locked modes navigate to `store`.
- `src/ui/components/character/CharacterCard.gd` (edit) - `_update_portrait`
  now calls `character_data.get_portrait()` (so species registry fallback
  actually fires) AND uses `load()` instead of `Image.load()` for `res://`
  paths (export-safe; the previous path silently broke in release builds).

### Runtime verified at this stage

- All 4 mode hovers swap card data correctly (script asserts: title, badge,
  CTA text, unlocked state)
- Standard shows "Included" green badge + cyan "New Campaign" CTA
- Bug Hunt shows "DLC Owned" green badge (default-owned in dev)
- Planetfall + Tactics show "DLC Required" orange badge + orange "Unlock X"
  CTA, distinct from unlocked CTAs
- Character gallery of 6 cards (5 species registry + 1 explicit preset path)
  all render correct Modiphius portraits via the updated CharacterCard path
- Headless reparse clean after each batch of edits

### Critical bug squashed mid-session

`CharacterCard._update_portrait()` used `Image.load(path)` +
`ImageTexture.create_from_image()`. Works in editor (file accessible on
disk), **silently breaks in exported builds** (only `.ctex` ships in the
`.pck`, not the raw PNG). Godot emitted the warning at runtime:
`Loaded resource as image file, this will not work on export`. Fix: branch on
`pp.begins_with("res://")` - use `load(pp) as Texture2D` for `res://` paths,
keep `Image.load()` only for `user://` / absolute paths (portrait-upload
flow). Affects every CharacterCard render across the entire app, not just the
new species registry.

### Remaining visual bugs (still open)

1. **VISUAL BUG - replace text title with logo PNG** (from earlier run):
   "5 Parsecs From Home Manager" Label competes with the Standard cover. Same
   bug as before, not yet fixed.
2. **VISUAL POLISH - cover backgrounds are opaque white**: All 4 mode covers
   were exported with white backgrounds. Inside the dark-themed card panel,
   the white box is jarring. Options:
   - Re-export from the PSDs with transparent backgrounds
   - Use a shader/blend mode to multiply against the card bg
   - Crop tightly to the title-text only
3. **VISUAL POLISH - cover sizing varies between modes**: Tactics cover ends
   up smaller in the cover area than Standard because aspect ratios differ
   slightly. Card uses STRETCH_KEEP_ASPECT_CENTERED so this is correct
   behavior, just inconsistent visually.

### Bugs fixed this session (struck through entries below)

- TIMING BUG - cover invisible on first run after asset drop: **FIXED**
  by `_initial_mode_swap.call_deferred()` in `_build_mode_showcase`
- VISUAL BUG - cover overflows left-half rect: **FIXED**
  by ModeShowcaseCard using `EXPAND_IGNORE_SIZE` on the cover TextureRect
  inside a constrained VBoxContainer
- CharacterCard not consulting `get_portrait()`: **FIXED**
- Export-unsafe Image.load on res:// paths: **FIXED**

## Runtime-test findings (2026-05-21, MainMenu live run) - initial round

Confirmed working:
- All 4 cover PNGs imported by Godot and load via `ResourceLoader.exists()` /
  `load()`. Standard cover comes back as `1843x695` post-import compression.
- `MainMenu.ModeShowcase` node exists at runtime, correct rect (886x820 at
  60,180), wired into the tree.
- Calling `_swap_cover("standard", true)` post-`_ready` correctly sets the
  texture and modulate to 0.85 - the runtime path is sound.

Visual bugs to fix:

1. **VISUAL BUG - replace text title with logo PNG**: The existing
   `Title` Label ("5 Parsecs From Home Manager") sits on top of the Standard
   cover graphic which already says "FIVE PARSECS FROM HOME" in big red type.
   Remove the Label and use a transparent-background PNG of the logo instead.
   Candidate sources from the Drive: any of the `Cover Text` files (likely
   need the PSD for alpha cutout), or the `Nordic Weasel` logo as a layout
   reference for placement. Hold for art-asset triage.

2. **VISUAL BUG - cover overflows the left-half showcase rect**: With
   `EXPAND_FIT_WIDTH_PROPORTIONAL` + `STRETCH_KEEP_ASPECT_CENTERED`, the
   `TextureRect` grows beyond its anchor box and the cover image bleeds across
   the full viewport, sliding under the right-side button column. Fix: change
   `expand_mode` to `EXPAND_IGNORE_SIZE` so the rect stays inside its anchors
   and the texture fits within.

3. **TIMING BUG - cover invisible on very first run after asset drop**: On
   the first project run after new PNGs land, `_ready()` fires before Godot
   finishes the texture import. `_swap_cover("standard", true)` bails at the
   `ResourceLoader.exists()` guard (returns true) but `load()` returns a
   stub, so the texture stays null. Subsequent runs are fine because the
   `.godot/imported/` cache is warm. Fix: defer the initial swap by one frame
   (`await get_tree().process_frame` before the first `_swap_cover` call in
   `_build_mode_showcase`) so import settles.

## Session 4 (May 21, 2026) - PSD batch + layer review tool

Added per-PSD `_review.html` triage tool (self-contained browser app,
embedded base64 thumbnails on checkerboard, click-to-recategorize,
download-JSON workflow) and extracted 3 more PSDs to validate
generalization.

### Tools added

- **`scripts/psd_review_html.py`**: generates `_review.html` next to
  any `_layer_catalog.json`. Embeds 256px PNG thumbnails as base64
  data URIs, single-file output, ~0.2-0.4 MB per PSD
- **`scripts/psd_apply_review.py`**: reads edited catalog, re-shuffles
  PNGs between `bg/`/`actors/`/`fx/`/`props/` to match new categories,
  rewrites `data/scenes/<stem>.json` so Godot's SceneStage picks up
  changes without code edits. Idempotent
- **`scripts/psd_extract.py`** updated to emit `_review.html` at end of
  extraction automatically

### Batch results (4 PSDs)

| PSD | Layers | bg | actor | fx | prop | skip | Notes |
|---|---|---|---|---|---|---|---|
| Meeting (re-emitted) | 31 | 13 | 5 | 0 | 12 | 1 | Pilot — review HTML generated standalone |
| Firefight | 45 | 10 | 3 | 1 | 19 | 12 | First FX layer auto-detected — combat scene with opacity-reduced effects |
| Shipyard | 15 | 7 | 0 | 0 | 5 | 3 | **0 actors auto-detected** — wide landscape, figures fell under 3% area floor |
| 2Engineers | 31 | 6 | 3 | 0 | 17 | 5 | Character close-up, clean detection |

122 layers across 4 PSDs. ~30s-1m extraction time per PSD.

### Heuristic failure modes observed (now documented in SOP)

1. **MULTIPLY/OVERLAY/COLOR_DODGE plates at opacity 255 tagged BG/PROP**:
   The fx heuristic requires `opacity < 230`. Most lighting plates in
   Meeting are 255 → categorized as BG. Visible in review tool by
   non-NORMAL blend mode tag. User reassigns to FX in browser
2. **Wide landscape, no actors detected (Shipyard)**: 3% canvas-area
   floor for the actor heuristic is too high for figures in a 6000px-
   wide scene. User reassigns small portrait-shaped layers to ACTOR
3. **Layers wider than canvas tagged as PROP instead of BG**: 70%/60%
   width/height gate doesn't always fire when overlap is one-sided
4. **Adjustment layers (gradients, Brightness/Contrast)**: psd-tools
   cannot composite without scipy. Auto-categorized as SKIP, safe to
   ignore. Install with `pip install 'psd-tools[composite]'` if needed

Captured in `docs/sop/decision-log.md` as "Conservative-bias heuristics
over aggressive-bias" — false negatives are visible at review time;
false positives only surface at runtime composition

### Verification

Browser-rendered review tool screenshot at
`.mcp/screenshots/psd_review_tool_meeting.png` shows the 31-card grid
with Deep Space theme, filter bar with counts, per-card dropdowns,
working footer state. Heuristic misfires (MULTIPLY shadow plates tagged
BG, COLOR_DODGE prop tagged PROP) are immediately visible at-a-glance
from the metadata strip on each card

### What's pending now

- Manual triage pass on the 4 extracted PSDs (`_review.html` workflow)
- Re-extracting any PSD where the review reveals systematic issues vs
  one-off misfires (run `apply_review.py` for one-offs, edit
  `psd_extract.py` heuristics + re-extract for systematic)
- Visual MCP verification of SceneStage rendering one of the new PSDs
  (currently only Meeting was visually proven)
- Decision: tune the fx heuristic (drop `opacity < 230` requirement,
  letting any non-NORMAL blend mode qualify) — would re-categorize most
  shadow/lighting plates correctly on first pass for future PSDs

## What's still pending

- **Equipment icons** (`equip 1-8.png` in Compendium + Tactics + Planetfall) -
  need 1-hour triage to identify each
- **Painted-mini reference photos** (44 files) - secondary portrait pool,
  could supplement species coverage
- **Named scene paintings** (~173 detectable + 248 untagged in General Art) -
  need the NarrativeScreen runtime first
- **Borders / page templates** (Borders/Borders and Misc, .ai source files) -
  need vector-to-PNG conversion + UI redesign decisions
