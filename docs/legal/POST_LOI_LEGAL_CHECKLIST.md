# Post-LOI legal checklist

**Created**: 2026-08-11 · **Status**: OPEN, blocked on the signed LOI

Everything here is deliberately unfinished. The placeholders below are **not
oversights** — each one marks a term that is not settled until the Letter of Intent
is signed, and inventing a value would be worse than showing a visible blank.
They stay as they are until then.

This is the master list. When the LOI is signed, work this page top to bottom.

> ⚠ Placeholders are **visible to testers**. Confirmed on the tablet Aug 13 2026:
> the privacy policy's first paragraph reads "Last Updated: [DATE OF RELEASE]" and
> "contact us at [CONTACT EMAIL - TO BE ADDED BEFORE RELEASE]". That is accepted
> for closed alpha. It is not acceptable for public release.

---

## 1. Placeholders in the shipped legal documents

These four files ship inside the APK (`data/*` export filter, verified by
unzipping) and are displayed by `EULAScreen`, `LegalTextViewer`, MainMenu and
Settings.

| File | Line | Placeholder | Settled by |
|---|---|---|---|
| `data/legal/eula.md` | 22 | `[PENDING MODIPHIUS REVIEW: Exact license grant scope, sublicensing terms, and attribution requirements…]` | LOI / Modiphius legal |
| `data/legal/eula.md` | 36 | `[PENDING MODIPHIUS REVIEW: Revenue share terms, if any…]` | LOI commercial terms |
| `data/legal/eula.md` | 78 | `[PENDING MODIPHIUS REVIEW: Governing law jurisdiction…]` | LOI. Likely England and Wales (Modiphius registered office: 39 Harwood Road, London SW6 4QP) or the Developer's jurisdiction |
| `data/legal/eula.md` | 87 | `[CONTACT EMAIL - TO BE ADDED BEFORE RELEASE]` | Developer decision, needed regardless of the LOI |
| `data/legal/privacy_policy.md` | 4 | `[DATE OF RELEASE]` | Release date |
| `data/legal/privacy_policy.md` | 8 | `[CONTACT EMAIL - TO BE ADDED BEFORE RELEASE]` | Developer decision |
| `data/legal/privacy_policy.md` | 120 | `[CONTACT EMAIL - TO BE ADDED BEFORE RELEASE]` | Developer decision |

**The contact email is the one item NOT gated on Modiphius.** GDPR Art. 13 requires
a controller contact route, and the policy already tells EU users to exercise their
rights by contacting us. Worth filling in ahead of the rest.

## 2. ⚠ There are TWO copies of each legal document, and they have diverged

| Copy | Purpose | Privacy version | Discloses Talo / bug reports |
|---|---|---|---|
| `data/legal/privacy_policy.md` | shipped in the app | **1.1** | yes |
| `docs/legal/gh-pages/privacy.html` | public web copy | **1.0** | **no** |

The web copy also still carries its own placeholders (`privacy.html` 3,
`eula.html` 5). Store listings require a public privacy policy URL, so if the
GitHub Pages site is live it currently contradicts what the app shows.

**Whenever a legal document changes, both copies must change.** Nothing enforces
this today; it is a manual step, and it has already been missed once.

## 3. Bumping a version is not optional

`LegalConsentManager` gates re-consent on exact version equality:

```gdscript
if privacy_accepted_version != PRIVACY_VERSION:
    return true   # re-prompt
```

So a material edit to `privacy_policy.md` or `eula.md` **must** be paired with a
bump to `PRIVACY_VERSION` / `EULA_VERSION` in
`src/core/legal/LegalConsentManager.gd`, and to the `**Version X.Y**` line inside
the document itself. Without the bump, no existing user is ever re-prompted and
they keep consenting to a document they never saw.

Verified working on device Aug 13 2026: bumping 1.0 → 1.1 re-prompted a tester who
had already accepted.

## 4. Gated on the webhook going live, not on the LOI

The privacy policy's §1.3 and §3 already describe bug reports being delivered to a
private Discord channel. **That is currently aspirational**: `support_config.cfg`
does not exist, and the Android export filter would exclude it anyway (see
`docs/sop/sheet-export.md` and the QA ledger). Either wire the webhook or the
disclosure is describing something the build does not do.

Same shape in reverse for analytics: the policy correctly says sharing is opt-in
and off by default, and that is true, but almost nothing is instrumented yet, so
opting in currently sends very little.

## 5. Release-gated items outside the legal docs

Not LOI-blocked, but they belong on the same pre-release sweep:

- `src/core/store/StoreManager.gd` — `PRODUCT_IDS` Steam entries are literal
  placeholders (`STEAM_DLC_APP_ID_1`, …). Android/iOS ids look real.
- `steam_appid.txt` contains **480**, which is Valve's public Spacewar test appid.
- `project.godot` `config/version="0.9.7-alpha1"`.
- Talo access key: ships inside the APK and is extractable. Confirm in the Talo
  dashboard that its scopes are minimal (write events / identify only). The JWT
  carries no `exp`, so it does not expire on its own.

## 6. Verifying after the edits

```powershell
# every legal doc still loads, converts, and renders without unsupported markdown
Godot_console.exe --headless --path <project> --script tests/tools/verify_legal_docs.gd

# the consent screens are still scrollable by touch (T9-36)
Godot_console.exe --path <project> --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -c -a tests/unit/test_legal_screens_scroll.gd
```

⚠ `verify_legal_docs` fails on markdown links, tables and blockquotes, because the
in-app converter has no branch for them. If the finished legal text needs a
clickable contact link, the converter needs a branch first: today a
`[text](mailto:…)` would print literally AND feed its brackets to a BBCode parser.
