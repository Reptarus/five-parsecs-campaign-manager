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

Coordinates from a starter pass are always slightly off. Iterate:

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

**GodotPDF page size is hardcoded at 612×792 (US letter portrait)**. The
`_pageSize` member var on `addons/godotpdf/PDF.gd` is set at construction
and not exposed. Our 3:2 landscape sheets letterbox into the portrait
page with vertical margins when the GodotPDF backend handles the export.
GodotHaru DOES support arbitrary per-page sizing via libharu, so the
GodotHaru path (preferred on Steam Win/Linux) renders edge-to-edge at
the requested `page_size_inches`. If we ever need true landscape via
GodotPDF, fork the addon and expose a setter — but that creates a fork
to maintain, so weigh against the upside before doing it.

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
- **Don't call `pdf.free()` on a GodotHaru `PDF_DOC` or `PDF_PAGE`.**
  Both are RefCounted (auto-free on scope exit) even though `free`
  appears in their ClassDB method lists (inherited from Object).
  Calling `.free()` throws `"Can't free a RefCounted object."` This
  bit us during Sprint 2 runtime testing.

## Sprint 3 (researched, deferred) — PDF-native text overlay

Current PDF export rasterizes the full SheetRenderer output (background +
Label overlays) into a single embedded image. Text is therefore baked
pixels: not selectable, not searchable, not scalable. Sprint 3 emits
the **background PNG only** as the image layer, then overlays **native
PDF text elements** per field — producing selectable, searchable,
infinitely-scalable text with smaller file sizes.

**Status**: researched and documented; deferred pending alpha-tester
feedback on whether the current rasterized output is sufficient.

**Where the research lives**:

- Architectural design and decisions: `.claude/skills/ui-development/references/sheet-export.md` (long-form, ~10KB) — includes per-backend dispatch matrix, font handling options, PDF escape rules, coordinate transform math, renderer refactor sketch, test plan, open decisions, effort estimate
- Plan-file pickup point: `C:\Users\admin\.claude\plans\staged-noodling-wilkes.md` Sprint 3 stub
- Project memory cold-start: `memory/project_sheet_export_pdf_text_overlay_design.md`

**Key facts confirmed during Sprint 2 introspection** (won't change):

- Both backends expose text APIs: GodotHaru has `PDF_PAGE.text_out / text_rect / show_text / set_font_and_size / begin_text / end_text / text_width / measure_text`; GodotPDF has `pdf.newLabel(pageNum, position, text, size, font)`
- GodotHaru ships PDF 14 built-in fonts via `pdf.get_font("Helvetica" | "Times-Roman" | ...)`; custom TTF via `load_tt_font_from_file`
- GodotPDF supports only Helvetica built-in; custom TTF via `newFont()` requires `importer="keep"` on the TTF's `.import` sidecar for exported builds
- PDF text strings must escape `(`, `)`, `\` — GodotHaru handles this internally (libharu-backed), GodotPDF does NOT (line 389 of PDF.gd concatenates raw text). Sprint 3 must pre-escape at the SheetRenderer layer
- Coordinate origin asymmetry: GodotPDF flips Y internally (top-left input), GodotHaru does not (caller must flip for PDF bottom-left native). Normalize at the router boundary
- Estimated effort: 11-13h of focused work (one sprint)

**Open decisions** for Sprint 3 kickoff (do not prematurely commit):

1. Font strategy — built-in Helvetica only (zero shipping) vs ship Montserrat for on-screen parity vs hybrid
2. Multi-line handling on GodotPDF (no native wrap) — truncate (MVP) vs fork to add wrap
3. Coordinate normalization — keep asymmetry vs unify at the router seam
4. Keep the existing rasterized-only export path as a legacy option, or remove?

See the skill reference for full discussion of each.
