# Android Release Signing — Runbook

**Status**: the release keystore has NOT been generated yet. Until it is, the release
slot points at the Android SDK's **published debug key** and Play will reject any
upload signed with it.

**Verified current state** (`.godot/export_credentials.cfg`):

```
keystore/release="C:\Users\admin\.android\debug.keystore"
keystore/release_user="androiddebugkey"
keystore/release_password="android"
```

That private key ships inside the Android SDK on every developer machine on earth.
Anyone can sign with it, so Play treats it as no signature at all.

Everything else in the release preset is already done and committed (`a2215e36`):
version code/name, AAB output, native-library compression, launcher icons, and
`.gitignore` coverage for key material.

---

## Why this is the one step nobody else can do for you

The keystore is **permanent**. Once an app is published under a key:

- Losing the key or its password means **the app can never be updated** — not by you,
  not by Google. The only remedy is publishing a new listing under a new package name
  and losing every install, review and wishlist.
- Leaking the key means someone else can publish updates that Android will accept as
  genuinely yours.

So the password must be chosen by you and stored where it survives this machine.

---

## 1. Generate the key

`keytool` ships with the JDK. Verified present on this machine:

```
C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\keytool.exe
```

Store the keystore **outside the repository**. `.gitignore` now blocks `*.jks` and
friends, but the reliable protection is simply not putting it in a git working tree.

```powershell
# Somewhere outside the repo, e.g.:
New-Item -ItemType Directory -Force "C:\Users\admin\keys"

& "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\keytool.exe" `
  -genkeypair -v `
  -alias fpfh-upload `
  -keyalg RSA -keysize 2048 `
  -validity 10000 `
  -keystore "C:\Users\admin\keys\fpfh-release.jks"
```

It will prompt for a keystore password, then for name/organisation/locality fields
(these appear in the certificate; "Five Parsecs From Home" / your org is fine), then
confirm. Use the **same password** for the key as for the store unless you have a
reason not to — Godot's export dialog assumes that shape.

**Why these values**

| Flag | Value | Reason |
|---|---|---|
| `-keyalg RSA -keysize 2048` | | What Play requires for upload keys. |
| `-validity 10000` | ~27 years | Play requires the certificate to outlast 22 Oct 2033. A short validity silently blocks future updates. |
| `-alias fpfh-upload` | | Named for its role. If Play App Signing is enabled this is the *upload* key; if not, it is the app signing key itself. Generating it is correct either way. |

## 2. Back it up before doing anything else

Losing this file is unrecoverable. Put a copy in **at least two** places that are not
this SSD — a password manager's file attachment, an encrypted archive in Synology
Drive, and/or a USB key in a drawer. Store the password separately from the file.

Do this **now**, not after the first build. The window where the key exists in
exactly one place is the dangerous one.

## 3. Point Godot at it

Per `feedback_export_presets_editor_only`, the Godot editor rewrites
`export_presets.cfg` whenever the export dialog is touched, so do this **in the
editor UI**, not by editing files:

1. Open the project in Godot 4.6.
2. **Project → Export… → Android (`fiveparsecsfromhometest`)**.
3. Under **Keystore**, set:
   - *Release*: `C:\Users\admin\keys\fpfh-release.jks`
   - *Release User*: `fpfh-upload`
   - *Release Password*: the password you chose
4. Close the dialog (this writes `.godot/export_credentials.cfg`, which is gitignored
   — Godot stores that password in **plaintext**).

## 4. Build both artifacts

Build **two** things. The AAB is for Play; the APK exists so Chris can install
directly even if Play Console access has not come through.

```powershell
$GODOT = "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
$PROJ  = "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager"

# AAB (preset is already set to export_format=1)
& $GODOT --headless --path $PROJ --export-release "fiveparsecsfromhometest" `
    "$PROJ\build\FiveParsecs-0.9.7.aab"
```

For the sideload APK, flip **Export Format** to *APK* in the same dialog, export, then
set it back to *AAB*. (The preset is committed as AAB so the default path is the one
Play wants.)

## 5. Verify before sending it anywhere

```powershell
# The signature is the production key, NOT androiddebugkey
apksigner verify --print-certs "$PROJ\build\FiveParsecs-0.9.7.apk"
```

Checklist:

- [ ] `apksigner` prints your certificate, **not** `CN=Android Debug`
- [ ] Build log contains **no** `Invalid version number` warning
- [ ] Launcher icon is the 5PFH art, not the Godot robot
- [ ] Artifact is under 100 MB (ceiling 150 MB, `CLOSED_ALPHA_PLAN.md:83`)
- [ ] Installs and opens on a device that is not this dev machine
- [ ] One full campaign turn completes on that device

## 6. Every build after this one

Two version fields have to move, and they do different jobs:

| Field | Where | Who reads it |
|---|---|---|
| `version/code` | `export_presets.cfg` (Android preset) | Play. Rejects a re-used code, and testers are not offered the update. Currently `2`. |
| `config/version` | `project.godot` | The About panel, the main-menu footer, and **every bug report** (`BugReportContext.gd:48`). Currently `0.9.7-alpha1`. |

Bump **both** for each weekly alpha build — `alpha1` → `alpha2` and so on.

This matters more than it looks. `config/version` was `0.9.7-dev` for every build ever
made, so across a six-week alpha with weekly drops (A1–A6) every incoming bug report
would have claimed the same version and there would be no way to tell which build a
tester was on, or whether a fix had actually reached them.

`version/name` in the Android preset is deliberately the bare `0.9.7`: Godot rejects
anything with a hyphen there (`Invalid version number "0.9.7-dev"`). The
human-readable alpha tag lives in `config/version` instead.

---

## Open questions for Modiphius (do not block on these)

Both were asked in the Jul 27 recap; neither blocks generating the key above.

1. **Does a Play Console app entry already exist for Five Parsecs?** If Modiphius
   created one, the package name must match `com.reptarus.fiveparsecs` or one side has
   to change — cheaper to know before the first upload.
2. **Is Play App Signing enabled on it?** If yes, the key above is the *upload* key and
   Google holds the app signing key. If no, the key above **is** the app signing key
   and the backup discipline in step 2 becomes even more critical.
3. **Play Console access for `elijahrhyne@gmail.com`** (Release Manager is sufficient).
   Without it there is no upload, no internal track, and no pre-launch report until
   Chris returns (~Aug 6). The sideload APK exists precisely so this cannot block
   getting a build into his hands.
