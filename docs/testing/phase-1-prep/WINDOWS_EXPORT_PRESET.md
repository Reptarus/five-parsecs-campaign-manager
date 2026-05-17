# Phase 1 Prep — Windows Export Preset Draft

**Owner**: Engineering (Elijah)
**Created**: 2026-05-01 (Phase 0.5 of workback)
**For**: P1.T5 task — execute Mon May 4 morning
**Target file**: `export_presets.cfg` (root of project)

**Purpose**: Pre-staged Windows export preset entry. Paste-ready text below; the manual setup in Godot Editor is the canonical path because the editor regenerates `export_presets.cfg` with auto-derived hashes.

**Context**: Currently `export_presets.cfg` has only one preset (`fiveparsecsfromhometest`, Android, signed). Alpha-1 requires a Windows preset for cohort distribution. Code-signing cert is deferred to Phase D — alpha ships unsigned with documented Defender SmartScreen walkthrough.

---

## Recommended approach: Editor-driven preset creation (NOT manual file edit)

**Why**: Godot's export_presets.cfg uses internal hashes/IDs for some fields. Manual edits can desync from internal state. The editor handles this correctly.

### Step 1 — Open Project → Export

1. In Godot 4.6 editor: Project menu → Export…
2. Click "Add..." → select "Windows Desktop"
3. Default preset name will be "Windows Desktop" — rename to **"five-parsecs-windows-alpha"** for clarity

### Step 2 — Configure preset

In the Options panel on the right side, set these values:

| Section | Field | Value | Notes |
|---|---|---|---|
| **Name** | preset name | `five-parsecs-windows-alpha` | matches build script + workback plan reference |
| **Resources** | Export Mode | `Export all resources in the project except resources checked below` | inherits exclude_filter pattern |
| **Resources** | Filters to export non-resource files | `*.tscn, *.json, *.gd, *.tres, *.cfg` | matches existing Android preset include_filter |
| **Resources** | Filters to exclude files | `assets/BookImages/*, addons/godotsteam/*, addons/GodotApplePlugins/*, addons/gdUnit4/*, tests/*, docs/*, *.x86_64, *.sh, *.apk, .env.local, .env.example` | mirrors existing Android exclude + adds .env files |
| **Patches** | (leave default) | empty | not used for alpha |
| **Encryption** | Encrypt Exported PCK | UNCHECKED | alpha is unsigned + unencrypted |
| **Encryption** | Encrypt Index-Only Mode | UNCHECKED | |
| **Script** | GDScript Export Mode | `Compiled bytecode (faster loading)` | matches Android preset script_export_mode=2 |
| **Custom Templates** | Debug | (leave empty) | uses Godot's built-in 4.6-stable templates |
| **Custom Templates** | Release | (leave empty) | same |
| **Application** | Modify Resources | UNCHECKED | not needed |
| **Application** | Console Wrapper Icon | (leave empty) | |
| **Application** | Icon | `res://icon.svg` (or game icon if available) | |
| **Binary Format** | 64-bit | CHECKED | x86_64 target |
| **Binary Format** | Embed PCK | **CHECKED** | single .exe file for tester distribution simplicity |
| **Texture Format** | (defaults) | | |
| **Codesign** | Enable | UNCHECKED | code-signing cert deferred to Phase D |
| **SSH Remote Deploy** | Enabled | UNCHECKED | local export only |

### Step 3 — Set export path

- Field: **Export Path** at top of dialog
- Value: `./build/FiveParsecsAlpha.exe`
- This creates `./build/FiveParsecsAlpha.exe` + `./build/FiveParsecsAlpha.pck` (or single embedded .exe if "Embed PCK" is checked)

### Step 4 — Save preset

- Close the Export dialog (preset auto-saves)
- Verify `export_presets.cfg` now contains a `[preset.1]` section with `platform="Windows Desktop"` and `name="five-parsecs-windows-alpha"`

### Step 5 — Build via headless export

```bash
"C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --export-release "five-parsecs-windows-alpha" "build/FiveParsecsAlpha.exe" --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

**Verify**:

- Exit code 0
- `build/FiveParsecsAlpha.exe` exists
- File size <200 MB (per `ALPHA_1_REGRESSION_CHECKLIST.md` Section 1.1)

---

## Reference: paste-ready preset block (USE ONLY IF EDITOR APPROACH FAILS)

Below is a draft preset block based on the existing Android preset structure. **Use this only as a fallback if the editor-driven approach above fails or produces malformed output.** Then manually verify in Godot editor that the preset loads correctly before exporting.

```ini
[preset.1]

name="five-parsecs-windows-alpha"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.tscn, *.json, *.gd, *.tres, *.cfg"
exclude_filter="assets/BookImages/*, addons/godotsteam/*, addons/GodotApplePlugins/*, addons/gdUnit4/*, tests/*, docs/*, *.x86_64, *.sh, *.apk, .env.local, .env.example"
export_path="./build/FiveParsecsAlpha.exe"
patches=PackedStringArray()
patch_delta_encoding=false
patch_delta_compression_level_zstd=19
patch_delta_min_reduction=0.1
patch_delta_include_filters="*"
patch_delta_exclude_filters=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PackedStringArray()
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name="Reptarus / Modiphius"
application/product_name="Five Parsecs From Home Digital"
application/file_description="Five Parsecs From Home Digital — Closed Alpha Build"
application/copyright="© 2026 Reptarus / Modiphius. Five Parsecs From Home is a Modiphius product."
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script="Expand-Archive -LiteralPath '{temp_dir}\\{archive_name}' -DestinationPath '{temp_dir}'\n$action = New-ScheduledTaskAction -Execute '{temp_dir}\\{exe_name}' -Argument '{cmd_args}'\n$trigger = New-ScheduledTaskTrigger -Once -At 00:00\n$settings = New-ScheduledTaskSettingsSet\n$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings\nRegister-ScheduledTask godot_remote_debug -InputObject $task -Force:$true\nStart-ScheduledTask -TaskName godot_remote_debug\nwhile ((Get-ScheduledTask -TaskName godot_remote_debug).State -ne 'Ready') {{ Start-Sleep -Milliseconds 100 }}\nUnregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue"
ssh_remote_deploy/cleanup_script="Stop-ScheduledTask -TaskName godot_remote_debug -ErrorAction:SilentlyContinue\nUnregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue\nRemove-Item -Recurse -Force '{temp_dir}'"
```

**WARNING**: The `[preset.1.options]` section uses internal hashes for some fields in real Godot exports. The block above is the documented schema but Godot may generate slightly different content. After paste, open Project → Export and verify the preset loads cleanly + edit any malformed fields via the editor UI.

---

## Acceptance criteria for P1.T5 (per workback plan)

| # | Criterion | Verification |
|---|---|---|
| 1 | Preset visible in Godot editor Project → Export | manual |
| 2 | Headless export command produces .exe | command exit 0 |
| 3 | .exe size <200 MB | `ls -la build/` |
| 4 | .exe runs on clean Windows VM | manual launch |
| 5 | First-launch consent flow works (depends on P1.T7) | E2E manual smoke |

P1.T5 is BLOCKED on Talo plugin install (P1.T1) — both should be done same morning.

---

## Post-install / first-build steps

Once the preset works:

1. Add `build/` to `.gitignore` (build artifacts are not committed):

   ```
   # Build outputs
   build/
   *.exe
   ```

2. Document the SmartScreen walkthrough in `docs/testing/ALPHA_TESTER_ONBOARDING.md` Step 3 with screenshots from the first clean-VM test launch (per workback P1.T6)

3. Hash the build artifact for distribution integrity:

   ```bash
   certutil -hashfile build/FiveParsecsAlpha.exe SHA256
   ```

   Record hash in the per-build TEST_EXECUTION_REPORT.

---

*Doc v1, 2026-05-01. To be archived after P1.T5 + P1.T6 verification.*
