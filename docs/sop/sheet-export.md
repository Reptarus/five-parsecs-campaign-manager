# Sheet / PDF Export SOP

How we render player data onto official Modiphius sheet PNGs and export to
PNG/PDF. Pattern shipped May 23 2026 for the 3 Core Rulebook sheets (Crew
Log, Encounter Log, World Record Sheet) and designed to absorb future
expansion-book sheets without re-architecting.

The whole pipeline is six layers — assets, field-coordinate manifest,
renderer, PDF router, screen, nav. Each layer is independently testable
and replaceable. Read this whole doc before adding a new sheet; you'll do
it half as fast the second time.

## Architecture at a glance

```
PrintSheetScreen (tab bar, right rail, blank-mode toggle)
  └─ SheetRenderer (Control)
       ├─ BackgroundTexture (the official PNG, KEEP_ASPECT)
       ├─ FieldNodes (Labels positioned per data/sheets/<book>/<id>_fields.json)
       └─ DebugOverlay (_draw() red rects when calibrating)

       export_to_png(path):
         SubViewport(2764×1843) + set_size_2d_override + await frame_post_draw
         get_texture().get_image().save_png(path)

       export_to_pdf(path):
         PdfExportRouter.best_available_backend() →
           "godotharu" (GDExtension binary)  OR
           "godotpdf"  (pure GDScript addon)  OR
           ""          (PNG-only fallback toast)
```

## The overlay is built in SOURCE pixels — do not scale per node

`SheetRenderer` positions and sizes every field node in **source (2764x1843) pixels**
with the **manifest's own** `font_size`, as children of a `FieldLayer` whose transform
carries the display scale. `_content_fit()` computes that fit once and is the only
place the letterbox is decided; the debug overlay reads the same function.

**Why it must stay that way** (T11-06, Sep 5 2026). Scaling per node means giving each
Label a scaled font and a scaled rect, and that is unfixable in Godot 4.6:
`add_theme_font_size_override()` invalidates the minimum-size cache but does not
recompute it until the next frame, so `size = rect` on the following line is clamped up
to the *previous* font's line height. It is not an ordering bug — a brand-new,
never-laid-out Label clamps the same way, because its first minimum uses the theme's
DEFAULT font. The result was every field Label sitting at a flat **21 px** at every
scale, and fields painting over each other once the sheet was small enough. Proof and
counter-examples: `tests/tools/probe_label_min_cache.gd`.

Consequences worth keeping in mind when editing this file:

- **The preview and the export are now one layout.** The export clone is set to the
  source size, where the layer's scale is 1.0 and its offset 0. A geometry change you
  see on screen is the geometry that prints.
- **A short box is now a real finding.** The clamp can still bind where a manifest rect
  (after `label_inset` / `rule_offset`) is shorter than its font's line height at source
  scale. Measured at introduction: **0 of 211 fields** across the three Core sheets. If
  that count rises, the manifest or the font size is wrong — not the renderer.
  ⚠ **UPDATED Sep 5 2026 (T11-22).** Correcting the baker's rule search took 24 crew-log
  fields below their own line height, so `_populate_fields()` now grows such a band
  **UPWARD** into the printed caption rather than letting the Label grow downward through
  the box border. The count above is therefore no longer the whole guard — but a band that
  needs growing is still worth looking at, because it means the caption inset and the rule
  leave less room than the font needs.

### ⚠ The baker takes the NEAREST rule, not the farthest (T11-22, Sep 5 2026)

`scripts/bake_sheet_label_insets.py::rule_offset()` searches from `h-6` to `h+18` below a
field for the horizontal rule the value is written on. It used to return `spanning[-1]` —
the FARTHEST match in that window — and on a two-row layout that window reaches the NEXT
structure down.

Measured on `assets/sheets/core/crew_log.png`: `captain_name`'s box bottom is y=774, the
rule that CLOSES ITS OWN BOX is at y=777-778, and the TOP border of the Weapon box beneath
it is at y=790. The baked offset pointed at 790. **128 of 184 crew-log fields** were
mis-baked; a before/after render of the same campaign shows the captain's name struck
through by its own box border in the old build.

Rules for anyone touching this:

- A field is written on the **first** line beneath it, never on a later line that happens
  to fall inside the search window.
- Take the bottom of the **first contiguous run**, not `spanning[0]`: a printed rule is
  2-3px thick and a baseline on its top edge sits inside the stroke.
- **Verify against the artwork, not the prediction.** The row that prompted this said "40
  row-2 weapon fields"; the real scope was 128. Scan the field's own column for every
  spanning rule in the neighbourhood and read which one closes its box.
- `tests/unit/test_sheet_field_mapping.gd` guards it with `rule_offset <= rect.h + 12`.
  **12 is measured**: legitimate rules on these three sheets sit 2-9px below their box (the
  40 weapon fields are the +9 case), and the defect produced +16 and worse.
- **Anything that walks the field nodes must walk the SUBTREE.** They are no longer
  direct children of the renderer. `_collect_text_layer()` and the export's re-adopt
  both look for the `sheet_src_rect` meta recursively; a walk that finds nothing does
  not error, it silently ships a PDF with an empty searchable layer. Verify with
  `tests/tools/emit_sheet_pdf.gd` (`text_layer_entries=` must be non-zero) and read the
  file back with PyPDF2.
- **Do not make the layer a direct child of a Container.** Godot resets `scale` to
  `Vector2(1, 1)` on a Control instantiated under a Container.

Measure geometry with `tests/tools/probe_sheet_field_geometry.gd`, which prints each
node's manifest rect beside the rect it actually has, plus the clamped-node and
overlapping-pair counts.

## Adding a new sheet from a PNG source

This is the path you'll use for ~every future sheet, since Modiphius
ships sheet PNGs in their art bundles.

### 1. Copy the asset

```
assets/sheets/<book>/<sheet_id>.png
```

`<book>` is one of `core`, `compendium`, `planetfall`, `tactics` (add
new books as they ship). `<sheet_id>` is `snake_case`, no version
suffix — when Modiphius redesigns a sheet, the new PNG overwrites the
old one and the field JSON gets recalibrated.

The Core Rulebook PNGs live at `C:\Users\admin\Documents\5PFH\5PFH
Art\5 Parsecs Core Rulebook\Art\png\Sheets\` (outside the repo, user's
local bundle). Source dimensions are `2764×1843` for all three Core
sheets. That resolution becomes the canonical render resolution.

### 2. Run headless import

```powershell
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --headless --import --quit `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager"
```

Skipping this is the #1 way to ship a sheet that silently renders
nothing. `TextureRect.texture = load("res://assets/sheets/...png")`
returns `null` if the `.import` sidecar doesn't exist, and Godot
doesn't error — it just renders blank. See the
[asset-pipeline.md](./asset-pipeline.md) for the canonical import rule.

### 3. Create the field manifest

```
data/sheets/<book>/<sheet_id>_fields.json
```

Schema (one file per sheet, pixel coords against the source PNG):

```json
{
  "sheet_id": "crew_log",
  "book": "core",
  "source_png": "res://assets/sheets/core/crew_log.png",
  "source_size": [2764, 1843],
  "_calibration_note": "Coordinates are starter values, calibrate via debug overlay",
  "fields": [
    {
      "id": "captain_name",
      "type": "text",
      "rect": [320, 145, 540, 60],
      "font_size": 36,
      "align": "left",
      "source": "campaign.captain.character_name"
    }
  ]
}
```

**Field types**:

| `type` | Behavior |
|---|---|
| `text` | Single-line Label, truncates with ellipsis |
| `multiline_text` | RichTextLabel, wraps within rect |
| `number` | Int/float as plain string, right-aligned by default |
| `checkbox` | Fills the rect if the source value is truthy |
| `checkbox_grid` | Pip row; fills cells 1..N where N = source int value |

Extend the type list by adding a case to
`SheetRenderer._build_field_node()`.

**The `source` field is a dot-notation path** against the data context
the renderer builds. Top-level keys are populated automatically:

- `campaign.*` — `FiveParsecsCampaignCore` with `captain` shortcut
  pointing at the captain crew member, and `crew[N]` array access for
  any crew member by index
- `world.*` — `PlanetDataManager.get_current_planet()` dict (traits
  via `world.traits[N]`)
- `journal.*` — `CampaignJournal` entries; `journal.last_battle.*`
  resolves to the most recent battle entry

Dot-traversal handles dicts AND objects (via `.get(key)` then property
access), and `[N]` array indexing. See `SheetRenderer._resolve_source()`
for the exact algorithm — if you need a new top-level context key, add
it there.

### 4. Calibrate via debug overlay

**Sprint 2.5 PREFERRED PATH (May 24 2026)**: use the automated extractor
at `tools/extract_sheet_fields.py` instead of manual measurement. The
sheets are designed with uniform cyan field borders that are trivially
detectable via color thresholding + connected-component analysis.

```powershell
# Extract candidate rects + visualization overlay
py tools/extract_sheet_fields.py assets/sheets/core/crew_log.png --debug-overlay
# Inspect tools/_debug/crew_log_overlay.png — red rects should outline every cyan field
# Then assign field IDs (per-sheet helper script, e.g. tools/assign_crew_log_ids.py)
```

The extractor produces `<sheet>_fields_extracted.json` (candidate
rects + OCR labels + detection metadata). A per-sheet ID-assignment
helper maps detected rects to semantic field IDs + source dot-paths.
For Crew Log this produces 144 fields (16 header + 8 character slots ×
16 fields each) in ~5 minutes vs ~3-4 hours of manual measurement. See
`.claude/skills/ui-development/references/sheet-export.md` for the full
Sprint 2.5 design + tuning guide.

⚠ **THE EXTRACTOR IS A LEAD, NOT AN ANSWER — verified twice on 2026-08-09.**
Rendering the artwork with every detected box numbered is a mandatory step, not a
nicety. On the two secondary sheets that render showed:

- **the sheet TITLE's letterforms are detected as boxes** (indices 0-16 on the
  World Record sheet, 0-11 on the Encounter Log). Every one is a false positive.
- **a real box was MISSED entirely** — "Invading Force" on the World Record sheet.
  It had to be measured by hand (cyan rules at y=154/318, sides at x=1870/2633).
- **an index does not mean what you assume**: extracted box 19 is *War Progress*,
  the box BELOW Invading Force, which only a crop of that region revealed.

And when a manifest's existing rects are wrong, do NOT "snap" them to the nearest
detected cell. Tried and rejected: a centre-based snap moved `trait_3` from x=320
to x=1003, away from its sibling rows, because the centre of an arbitrarily wrong
rect is arbitrary too. That produces a *differently* wrong rect which no longer
trips the divider test — worse than the original, because it now looks calibrated.

**FALLBACK (legacy path)**: if the extractor misbehaves on a new sheet
or the cyan border color drifts, fall back to manual debug-overlay loop:

1. Run the project, open Print Sheet, select the new sheet tab.
2. Tick **Debug overlay** (top-right, dev builds only).
3. Red rects show where each field's bounding box lands.
4. Open the source PNG in GIMP / Photoshop / Krita, measure the
   target field, update the `rect` array in JSON.
5. Reload the scene (no need to restart Godot — the JSON loads on
   render). Repeat.

Expect 3-4 hours of calibration for a 30-40 field sheet the first time.
The second sheet from the same book takes ~half that because typography
and grid spacing usually repeats.

**Calibration reference availability (Core Rulebook only known case)**:

- **Crew Log**: ONE filled example exists in the Core Rules PDF (around
  page 60, the "Example Crew" — Flint Jameson + 5 members). This is the
  ONLY filled-sheet example Modiphius ships in the Core Rules. Use it
  to calibrate Crew Log fields by direct visual comparison — much faster
  than measuring rects from a blank PNG. Reduces Crew Log calibration
  to ~1-1.5h.
- **Encounter Log + World Record Sheet**: NO filled examples in Core
  Rules. Calibrate against the BLANK sheet PNGs themselves — the
  printed labels on the artwork show exactly where data is supposed to
  go. The debug-overlay loop works but is slower (~3-4h each).
- **Future expansion books** (Compendium / Planetfall / Tactics, when
  Modiphius ships them): unknown if they include filled examples. Worth
  asking Modiphius on the May 25 call as a low-cost partnership ask
  ("if you have filled examples of any sheets, send them along — saves
  us hours of calibration"). Capture answer in
  `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md`.

### 5. Wire the tab into PrintSheetScreen

Add an entry to the `_tabs` array in `PrintSheetScreen._build_ui()`:

```gdscript
_tabs = [
    {"id": "crew_log",          "label": "Crew Log"},
    {"id": "encounter_log",     "label": "Encounter Log"},
    {"id": "world_record_sheet", "label": "World Record"},
    {"id": "<your_sheet_id>",   "label": "Your Sheet"},
]
```

The screen auto-builds the tab button and routes to
`SheetRenderer.render_sheet(id, _build_data_context())`. No other code
changes needed for a single-page sheet.

## Extracting a sheet from a PDF source

For expansion books where Modiphius ships a PDF but not standalone
sheet PNGs (likely scenario for Compendium / Planetfall / Tactics),
extract the page as an image first.

```powershell
py -c "from PyPDF2 import PdfReader; r = PdfReader(r'docs/rules/Five Parsecs From Home-Compendium.pdf'); print(len(r.pages))"
```

PyPDF2 can't rasterize pages directly. Use the project's existing
pattern: open the PDF in a viewer that exports a page as PNG at 300
DPI minimum (Adobe Reader, Edge, or pdf2image if you're willing to
install Poppler).

Target output resolution: **at least 2400px on the long edge**. The
Core Rulebook sheets are 2764×1843 (~250 DPI on a US Letter page).
Higher is better — rendered text quality is bottlenecked by source
pixel density.

Crop to the page bleed, save as PNG to `assets/sheets/<book>/`,
proceed with steps 2-5 above.

**Do not** install PyMuPDF / fitz / pdfplumber for this. CLAUDE.md's
"Python Tools" rule restricts the project to PyPDF2 only.

## Adding a new field type to SheetRenderer

When the existing `text` / `multiline_text` / `number` / `checkbox` /
`checkbox_grid` types don't cover a new sheet's layout (e.g. a radial
dial, a token track, a colored status pip):

1. Add the type name to the field manifest's allowed values (no
   schema file enforces this; the test suite at
   `tests/unit/test_sheet_field_mapping.gd` reads the field types from
   the manifests directly).
2. Add a branch to `SheetRenderer._build_field_node(field, value)` that
   returns the Control subclass for that type.
3. If the type needs custom drawing (radial fill, etc.), build it as a
   Control with `_draw()` rather than a Label, so it scales with the
   parent SheetRenderer.
4. Add a unit test covering the new type in
   `tests/unit/test_sheet_renderer.gd`.

## Evaluating a new PDF plugin

Three plugins were evaluated for the May 2026 MVP. Use this checklist
for any future replacement:

| Criterion | Why it matters |
|---|---|
| **Implementation** (pure GDScript / GDExtension / engine module) | Module = requires engine recompile, disqualified. GDExtension = binary per platform. GDScript = universal. |
| **Godot version target** | Must support 4.6+ and stay current with future LTS. Plugins that stopped at 3.x are dead-ends. |
| **License** (MIT / zlib / Apache / GPL) | GPL contaminates the Steam build, avoid. MIT/zlib/Apache OK. |
| **Platform binary coverage** | For GDExtension, which platforms ship pre-built? Self-building per platform is a tax we don't want. |
| **Feature set vs our needs** | We need: vector primitives (rectangle, line), text rendering (TrueType embed), image embedding (the sheet PNG itself). We don't need: encryption, annotations, form fields. |
| **Maintenance freshness** | Last commit within ~12 months. Stale plugins won't survive Godot point releases. |

Current backends shipping in the project:

- **GodotHaru** (`addons/godotharu/`) — C++ GDExtension wrapping
  libharu. Win + Linux binaries shipped. Full vector/font/image
  support. Used on Steam Win/Linux when present.
- **GodotPDF** (`addons/godotpdf/`) — pure GDScript. Universal,
  thinner feature set. Used everywhere GodotHaru isn't available.
- **None** — `PdfExportRouter.best_available_backend()` returns `""`.
  `SheetRenderer.export_to_pdf()` returns `ERR_UNAVAILABLE` and the UI
  toasts "PDF unavailable on this platform; save PNG instead."

Add a new backend by extending the constants and detection block in
`src/core/export/PdfExportRouter.gd`. Detection uses
`ClassDB.class_exists(&"ClassName")` for GDExtensions and
`ResourceLoader.exists(path)` for pure-GDScript addons — see
[component-patterns.md](./component-patterns.md) for the path-loaded
preload rule that explains why these are the robust checks.

## Mapping fields when the official PNG redesigns

When Modiphius redesigns a sheet (new layout, different field
positions), the PNG asset gets overwritten and the field JSON gets
recalibrated. **The field IDs stay the same** — that's the contract
between the JSON and the data-source side. If a field is renamed in
the new sheet (e.g. "Captain Name" → "Squad Leader"), keep the
`id: "captain_name"` and update only the `rect`. Source-path
resolution (`campaign.captain.character_name`) doesn't care what the
field is *called* on the printed sheet.

Fields that don't exist in the new layout: delete them from the JSON.
Fields that are *added*: append them with new IDs. The renderer
iterates the JSON, so missing IDs render nothing rather than
crashing.

Save the previous-version JSON to `docs/archive/sheets/` if the
redesign is significant enough that someone might want to diff. We
don't have a use case for runtime sheet-version selection yet — when
we do, version the JSON filenames (`crew_log_v2_fields.json`) and add
a tab selector.

## Cross-platform export gotchas

**SubViewport `_ready()` timing**: `SubViewport.get_texture()` returns
an empty image if called before the first frame post-draw. The
`SheetRenderer._render_offscreen()` await is non-negotiable:

```gdscript
await RenderingServer.frame_post_draw
var img: Image = sub_viewport.get_texture().get_image()
```

Calling this from `_ready()` or the first frame returns a 0×0 image.
Documented in the Godot 4.6
[Using Viewports](https://docs.godotengine.org/en/4.6/tutorials/rendering/viewports.html)
tutorial.

**`set_size_2d_override` not `size`**: setting `SubViewport.size` to
`Vector2i(2764, 1843)` makes the viewport that large but doesn't
remap content scaling. Use:

```gdscript
sub_viewport.set_size_2d_override(Vector2i(2764, 1843))
sub_viewport.set_size_2d_override_stretch(true)
```

This is the canonical Godot 4.6 pattern for offscreen render at
arbitrary resolution independent of the on-screen display size.

**FileDialog on Android/iOS**: `FileDialog` with `ACCESS_FILESYSTEM`
opens the host OS picker on Win/Mac/Linux but doesn't behave the same
on mobile. Save to `user://exports/<sheet>_<timestamp>.png` on Android
and iOS, then toast the path. A share-intent integration is Phase 2;
for MVP a path toast is sufficient.

**Page size — RESOLVED Aug 9 2026, both backends now agree.** This section
used to say GodotPDF was locked to 612×792 portrait "and GodotHaru renders
edge-to-edge at the requested size". Both halves were problems:

- GodotPDF's `_pageSize` really was fixed and unexposed. It now has a
  `setPageSize()` local patch, so it honours `page_size_inches`.
- **"Edge-to-edge" was the libharu BUG, not its feature.** US Letter landscape
  is 792×612 (1.294:1) and the sheet is 2764×1843 (1.4998:1) — they never
  matched, so drawing edge-to-edge STRETCHED the sheet vertically by 15.9%.
  Measured on the artifact as **251 × 217 DPI**, against a correct 251 × 251
  from the mobile path. Circles printed as ovals and every glyph was 16% too
  tall, and nothing in the code or on screen showed it.

Both paths now call `PdfExportRouter._fit_rect()`, which letterboxes to the
source aspect. Do not "reclaim" the letterbox bands by stretching — the sheet
is 3:2 and Letter is not.

### The safe print margin (`PRINT_MARGIN_PT = 18`)

`_fit_rect()` insets by 0.25in per side before fitting, giving **756×504pt at
(18, 54)**.

MEASURED, not chosen. `crew_log.png`'s ink spans x 46..2703 of 2764. Fitted
edge-to-edge across the full 792pt page that left **0.183in** of clear paper on
the left and 0.239in on the right — inside the ~0.25in unprintable border of a
typical consumer printer. Printing at "Actual size" clipped the outer box borders
off the form. It only ever looked survivable because most print dialogs default
to shrink-to-fit, which was silently rescuing the output.

After the inset: 0.425 / 0.478 / 0.985 / 0.970in of clear paper. And because the
same 2764 pixels now span 10.5in instead of 11in, **effective resolution goes UP:
251 -> 263 DPI.**

Pinned by `test_fit_rect_keeps_the_sheets_ink_clear_of_the_unprintable_border`,
which carries the measured ink bbox so it fails if the margin is reduced.

⚠ A new sheet whose ink sits closer to its own edge needs this RE-MEASURED
against the artwork, not assumed.

⚠ **The general rule this taught**: two backends implementing one behaviour will
diverge, and a divergence in OUTPUT geometry is invisible from the call site.
Put the shared decision in ONE function both call, and verify the artifact.

**GodotPDF `newImage()` requires `FORMAT_RGB8` or `FORMAT_RGBA8`**.
SubViewport textures usually return RGBA8 already, but the router's
defensive `img.convert(Image.FORMAT_RGBA8)` covers the edge case where
a transparent-bg or HDR viewport returns a different format. Without
the convert, `newImage()` silently returns false and the export fails
with a generic `ERR_CANT_CREATE` — easy to miss in logs.

**PDF backend caching**: `PdfExportRouter.best_available_backend()`
caches its result in a static var. Detection runs once per session —
which is fine, plugins don't appear or disappear at runtime. If you
add a hot-reload scenario (unlikely), expose a `_reset_cache()` static
method.

**Synology Drive timestamp churn**: see the CLAUDE.md "Synology Drive
Sync" note. Sheet PNGs in `assets/sheets/` will phantom-modify;
Godot's `checkOnChange: false` setting prevents this from reimporting
constantly. Don't be alarmed if `git status` shows `assets/sheets/`
clean even after a sync event — the actual bytes haven't changed.

## Why this layered architecture

Each layer has one job and one reason to change:

- **Asset layer** changes when Modiphius redesigns a sheet (or ships
  a new one). No code touches.
- **Field manifest** changes during calibration. No GDScript touches.
- **SheetRenderer** changes when we add a new field type. No data
  touches.
- **PdfExportRouter** changes when we add or replace a PDF plugin.
  No SheetRenderer touches.
- **PrintSheetScreen** changes when we add a new tab or rail control.
  No renderer or router touches.

The router abstraction in particular is modeled after `StoreAdapter`
in `src/core/store/` — same pattern, different problem. When you add
a third PDF backend, you'll touch `PdfExportRouter.gd` only. That's
the test for whether the abstraction is paying its rent.

## Anti-patterns

- **Don't bake field coordinates into GDScript.** They're data, they
  belong in JSON. The whole point of the renderer is that calibration
  is a data edit, not a code edit.
- **Don't use `FileAccess.file_exists("res://...")` for asset checks.**
  Use `ResourceLoader.exists()`. The former breaks in exported PCK
  builds. See [component-patterns.md](./component-patterns.md#export-safe-asset-loading).
- **Don't call `SubViewport.get_texture().get_image()` synchronously.**
  The image will be empty. Always `await
  RenderingServer.frame_post_draw` first.
- **Don't read `Engine.has_singleton("GodotHaru")`** to detect the PDF
  plugin. GDExtension classes register via ClassDB, not as engine
  singletons. Use `ClassDB.class_exists(&"PDF_DOC")`.
- **Don't add sheet-specific code to SheetRenderer.** If a sheet needs
  custom behavior, extend the field-type system. The renderer should
  stay generic across all sheets and all books.
- **Don't hand-write a journal entry in a fixture or probe.** Build it with
  `CampaignJournal.auto_create_battle_entry()`. `create_entry()` assembles
  every entry from a FIXED key set and silently drops everything else, so a
  hand-written entry is a shape the app can never produce — and a test or
  render probe built on one is validating fiction. This is what let five of
  the Encounter Log's six boxes print blank on every campaign while the suite
  was green. See "The Appendix X audit" below.
- **Don't test only `SheetDataContext.build()`.** Every unit test calls it directly
  and PASSES the campaign, world and entries in — so it is structurally blind to
  how `PrintSheetScreen._build_data_context()` OBTAINS them. Two device-only bugs
  lived exactly there: a `has_method("get_entries")` guard on a method with zero
  definitions (real name `get_all_entries`), so the sheet received no journal
  entries at all; and `world is Dictionary` against a `PlanetData` OBJECT, so the
  whole World block printed blank. Assert on the screen's own resolution step.
- **Don't assume the world is a Dictionary.**
  `PlanetDataManager.get_current_planet()` returns a **`PlanetData` object**;
  `SheetDataContext._as_dictionary()` coerces it via `serialize()`. Fixtures must
  pass the object, because that is what the app passes.
- **Don't decide a field is unmodelled without grepping the OWNER.** Two
  blocks on the World Record Sheet were marked blank-until-modelled on
  plausible-sounding reasoning ("Interdiction is a per-roll check, not planet
  state"), and both were wrong: `InterdictionRule` persists the licence record
  and the Galactic War keeps three tracked planet lists. Writing the reason
  down is good; it is not the same as checking.
- **Don't read a PDF's text layer as a reading order.** Extraction emits
  glyph runs in content-stream order, which for a form built in a layout tool
  reflects object creation, not position. Appendix X emits the licensing
  octagons as "No Obtained Yes"; the artwork reads **Yes | Obtained | No**.
  Crop the PNG and look.
- **Don't call `pdf.free()` on a GodotHaru `PDF_DOC` or `PDF_PAGE`.**
  Both are RefCounted (auto-free on scope exit) even though `free`
  appears in their ClassDB method lists (inherited from Object).
  Calling `.free()` throws `"Can't free a RefCounted object."` This
  bit us during Sprint 2 runtime testing.

## Searchable text — SHIPPED Aug 9 2026 (as an INVISIBLE layer)

The exported PDF is searchable, selectable and copy-pasteable. The picture is
unchanged: the sheet is still one embedded raster, with an **invisible text
layer** (PDF render mode `3 Tr`) laid over it — the technique a scanner's OCR
layer uses.

### Why invisible, and not the "native text" redesign this section used to plan

The old plan was to emit the **blank** sheet as the image and re-typeset every
field as visible PDF text (est. 11-13h). That buys the same searchability but
requires the PDF's typesetter to agree with Godot's on font, wrap and alignment
— three independent ways for the printed page to stop matching the app.

Mode 3 gets the searchability with none of that risk, because the visible text
is still the exact render the app produced. Font choice, wrap behaviour and
alignment in the hidden layer are then *cosmetic*: they move the selection
highlight, never a printed glyph. That is also why GodotPDF's missing
`text_width` stopped being a blocker — a width ESTIMATE is fine for a layer
nobody can see.

**Do not "upgrade" this to visible native text without a reason** the invisible
layer cannot serve. Infinite-zoom crispness on the *values* is the only real
one, and it costs pixel parity with the app.

### The rule that makes it trustworthy

`SheetRenderer._collect_text_layer(sub_viewport)` reads the text off **the nodes
the SubViewport actually rasterized** — NOT a second pass over the manifest.

Two producers for one fact is the shape that has bitten this project repeatedly:
a manifest-driven second pass would keep asserting a value the picture no longer
shows, and nothing would error. Derived from the clone, the two cannot disagree
because there is only one source. Pinned by
`test_collect_text_layer_reads_the_rasterized_nodes`.

**Blank mode yields an empty layer.** "Print blank to fill in by hand" must not
ship a hidden copy of the data the player asked to leave off the page — invisible
text still survives search, copy-paste and extraction.

### Escaping: the two backends need OPPOSITE treatment

⚠ This section previously said "GodotHaru handles escaping internally … Sprint 3
must pre-escape at the SheetRenderer layer". **Those two clauses contradict each
other and the second is wrong.**

| Backend | Escaping | Consequence of getting it wrong |
|---|---|---|
| GodotHaru | escapes internally (`HPDF_Stream_WriteEscapeText`) | pre-escaping DOUBLE-escapes: "Vance (Doc) Ryu" reads back as `Vance \(Doc\) Ryu` |
| GodotPDF | concatenated raw into `(text) Tj` | one unbalanced `)` ends the string early → **unopenable file, and `export()` still returns OK** |

Resolution: escape at the point the string enters the content stream.
`PDF.gd.escapePdfText()` does it for GodotPDF; the router only *flattens*
newlines (`flatten_field_text`) and escapes nothing. Backslash must be replaced
FIRST or it re-escapes the escapes. Verified by round-tripping 8 hostile names
through both backends; reverting the addon half makes PyPDF2 refuse the file.

### Facts still true (re-verified Aug 9 2026 by live introspection)

- `PDF_PAGE` exposes 75 methods including `begin_text / end_text / text_out /
  text_rect / text_width / set_font_and_size / set_text_rendering_mode`
- `PDF_DOC` exposes `get_font("Helvetica")`, `load_tt_font_from_file`,
  `set_title / set_author / set_subject / set_keywords / set_creation_date`
- GodotPDF supports only built-in Helvetica; custom TTF via `newFont()` still
  requires `importer="keep"` on the TTF's `.import` sidecar for exported builds
- Coordinate asymmetry is real and is handled inside each backend's placement
  helper: `newLabel` takes a TOP-DOWN y and emits the baseline at
  `(_pageSize.y - y) - fontSize`, so the router back-solves; libharu's
  `text_out` takes the PDF-native baseline directly

### Measured cost

| | before | after |
|---|---|---|
| extractable text | **0 chars** | 322-325 chars, 15/15 expected values |
| file size (libharu) | 223,255 B | 224,300 B (+0.5%) |
| libharu export time | 215 ms | **141 ms** (see below) |
| file size (GodotPDF) | 223,109 B | 225,669 B (+1.1%) |
| printed pixels | — | **unchanged** |

### The libharu image handoff: raw bytes, not PNG

The GodotHaru path used to call `img.save_png_to_buffer()` then
`load_png_image_from_mem()`. That makes the pipeline **Godot PNG-ENCODES 15 MB ->
libharu PNG-DECODES it -> libharu re-compresses it with flate**. The encode and
the decode are both pure waste; the PDF never contains a PNG.

MEASURED: `save_png_to_buffer()` on a 2764×1843 RGB8 image costs **~84 ms**;
`get_data()` costs ~0 (it returns the buffer that already exists). That is why the
C++ backend was benchmarking **215 ms against the pure-GDScript backend's 65 ms**
— the "slow" one simply was not doing an encode.

Now uses `load_raw_image_from_mem(bytes, w, h, 1, 8)` (color space 1 =
`HPDF_CS_DEVICE_RGB`), falling back to the PNG round-trip if an older GodotHaru
lacks the entry point. **215 -> 141 ms**, and the stream is still `/FlateDecode`
because `set_compression_mode(0x0F)` includes `HPDF_COMP_IMAGE`.

⚠ Verified beyond the byte count — a wrong colour space produces the same LENGTH
— by inflating BOTH backends' image streams and comparing: **identical SHA256**,
with `#5CBADE` (low red, high blue) intact, so no channel swap.

### Things MEASURED and deliberately NOT done

Recorded so nobody re-derives them:

- **PNG predictors** (`/DecodeParms /Predictor`). Conventional wisdom says they
  help line art. Measured here they HURT: Sub +8.4%, Average +30.8%, Up −4.8%
  — all worse than plain deflate. The sheet is 80.6% flat `#FFFFFF` and 10.9%
  flat `#EBEBEB`, so LZ77 already matches those runs and predictors destroy the
  run structure.
- **`/Indexed` colour.** The sheet has 1,342 distinct colours and the top 256
  cover 99.75% of pixels — so an 8-bit palette is LOSSY for ~13k pixels, all of
  them text antialiasing. Fringing on glyphs to save ~150KB is a bad trade.
- **deflate level 9** would save 9.2%, and it is NOT reachable. Godot's
  `PackedByteArray.compress()` takes only a mode, and the obvious lever —
  ProjectSettings `compression/formats/zlib/compression_level` — does NOT feed
  it. TESTED: with the setting reading back as `9`, `compress(COMPRESSION_DEFLATE)`
  returned a byte-identical 17,937. The 4.6 docs word it as affecting
  "compressed scenes and resources", and that is literally all it affects.
  (`COMPRESSION_ZSTD` compresses this data 5x better than deflate, but PDF has
  no zstd filter — the `/Filter` set is Flate/LZW/RunLength/DCT/JPX/CCITT/JBIG2.)
- **Higher render DPI.** The artwork is natively 2764px across an 11in page =
  251 DPI, so rendering larger upscales the ART for no gain.
- **The 10.9% grey.** Verified to be IN THE ARTWORK (10.85% of the source PNG
  vs 10.86% of the render), not something the exporter adds.
- **VRAM texture compression** is not a risk: `crew_log.png.import` has
  `compress/mode=0` (Lossless) and `"vram_texture": false`, so the printed sheet
  carries no block-compression artifacts. ⚠ `detect_3d/compress_to=1` would flip
  it to VRAM-compressed if the texture were ever used in a 3D material — it never
  is, but that is the one edit that would silently degrade print output.
- **`/ViewerPreferences /PrintScaling /None`.** Looks right for a print form — it
  stops the dialog shrinking the page. **Do NOT add it.** Forcing 100% scale is
  exactly what makes the sheet clip; see the print-margin section above.

## The Appendix X audit — Aug 9 2026 (the two secondary sheets)

**The books PRINT these sheets.** Core Rules Appendix X, PDF pp.180-181, contains
the Crew Log, the Encounter Log and the World Record Sheet in full. That is the
authority on what every box means, and it is extractable:

```powershell
py -c "from PyPDF2 import PdfReader; r=PdfReader('docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf'); print(r.pages[179].extract_text())"
```

Read it BEFORE mapping a field. It settles caption questions in seconds that are
otherwise guesswork — but see the anti-pattern above: its text ORDER is not the
visual order, so crop the PNG for anything positional.

### What the captions actually mean

| Box | Means | Source of truth |
|---|---|---|
| Encounter Type | which Encounter Table the opposition came from (Criminal Elements / Hired Muscle / Interested Parties / Roving Threats) | Core Rules pp.94-103 |
| Mission | the job + its objective | p.89 objective tables |
| Deployment Conditions | the p.88 condition | `data/deployment_conditions.json` (11 titles, max 18 chars) |
| **Shiny Bits** | **the p.89 NOTABLE SIGHT** — "Shiny bits: Gain 1 credit" is one of its nine results | p.89 Notable Sights |
| Outcome/Notable Events | free text | journal `description` |
| Enemy Types / Enemy Weapons | hand-filled during play; only row 1 Name/Type + Number are app-known | — |
| Licensing Required | Yes / Obtained / No, **Yes+Obtained joined by a connector rule** so a licensed world ticks both | `InterdictionRule`, p.75 |
| Invading Force | **the book never defines it** — the phrase appears ONLY on the printed sheet, nowhere in the rules text | free-text box |
| War Progress | the p.126 Galactic War result, in the book's own words | `invaded_planets` / `lost_planets` / `liberated_planets` |

Two of those were previously written off as unmodelled and were not. `Shiny Bits`
was mapped to credits earned, which is the wrong mechanic entirely.

### The defect underneath all of it

`CampaignJournal.create_entry()` builds every entry from a **fixed key set** and
drops the rest. The Encounter Log read `mission_type`, `deployment_condition`,
`enemy_count` off the entry's TOP LEVEL, where a journal entry has never had them.
They resolved to `""` — a legal blank on a print form, not null — so the T9-09
non-null sweep and 28 green tests all passed while five of six boxes printed empty.

The fix is the project's standard funnel rule, applied end to end:

1. `BattleResultNormalizer` — the one chokepoint every battle path crosses — now
   passes `deployment_condition` and `notable_sight` through, and DERIVES
   `enemy_count` from `enemy_force.count` (post-setup-delta) rather than copying
   the generator's pre-delta value.
2. `CampaignJournal.auto_create_battle_entry()` records the scenario in `stats`,
   next to the enemy: mission type, condition title, enemy count, category,
   objective, notable sight + effect.
3. `SheetDataContext._build_journal()` reads `stats` first, top level as fallback.

**Anything the printed sheet needs must exist in `stats`.** A key outside it is
not "missing from the sheet", it is deleted at the chokepoint.

### The guard

`test_every_addressed_box_prints_something_on_a_populated_campaign` asserts every
manifest source renders NON-BLANK against a populated campaign, with an explicit
`blank_by_design` map (each entry carrying its reason) and a stale-exemption check
so a fixed field cannot silently lose coverage. Detection-proven: reverting the
journal producer turns it red.

Its fixture is built by `CampaignJournal.auto_create_battle_entry()`, and so is
`tests/tools/emit_sheet_png.gd`'s. Both used to hand-write entries.

### Verifying a mapping

Render at source resolution and READ THE ARTIFACT — this is the only step that
catches a caption collision or a value under the wrong heading:

```powershell
$env:SHEET="world_record_sheet"
Godot_console.exe --path <project> --script tests/tools/emit_sheet_png.gd
# writes user://sheet_alignment_probe.png at 2764x1843; crop and look
```

⚠ The CV extractor misses **wide** cells. It found the five narrow stat columns of
the Enemy Types table and not the Name/Type column beside them, and missed
"Invading Force" entirely. Both were measured from the cyan rules by hand. Treat
`*_fields_extracted.json` as a lead, never as the field list.
