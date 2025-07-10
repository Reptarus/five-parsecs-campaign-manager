# Build and Versioning Process

## 1. Overview

This document defines the official process for versioning the game and creating builds for different platforms. A standardized process is essential for maintaining clarity, avoiding errors, and ensuring that every build is traceable.

--- 

## 2. Versioning Scheme

We will use **Semantic Versioning (SemVer)** to number our releases. The format is `MAJOR.MINOR.PATCH`.

-   **MAJOR (`v1.0.0`)**: Incremented for major, incompatible changes or significant new features that change the core experience. The initial release will be `v1.0.0`.
-   **MINOR (`v1.1.0`)**: Incremented for substantial new features or content that are backward-compatible (e.g., adding the Compendium DLC features).
-   **PATCH (`v1.0.1`)**: Incremented for backward-compatible bug fixes and minor tweaks.

### Version Location

The canonical version number for a build is set in the Godot project settings:

`Project -> Project Settings -> Application -> Config -> Version`

This version number should be updated **before** starting the build process for a new release.

--- 

## 3. Build Process

All official builds should be generated using Godot's command-line export tools to ensure consistency. The existing `build.gd` script can be used as a wrapper for this.

### 3.1. Build Environment

-   **Godot Version**: [Specify the exact Godot version, e.g., 4.4.2]
-   **Export Templates**: Ensure the correct version of the export templates are installed.

### 3.2. Build Script (`build.gd`)

The `build.gd` script should be enhanced to accept platform arguments.

**Example Usage:**

```bash
# To build for Windows
godot --headless --run build.gd --platform=windows

# To build for all platforms
godot --headless --run build.gd --platform=all
```

**Conceptual `build.gd` Logic:**

```gdscript
# build.gd
extends SceneTree

func _init():
    var platform = OS.get_cmdline_args().get("--platform", "all")
    var version = ProjectSettings.get_setting("application/config/version")
    var build_dir = "builds/v" + version

    if not DirAccess.dir_exists_absolute(build_dir):
        DirAccess.make_dir_recursive_absolute(build_dir)

    if platform == "windows" or platform == "all":
        _export("Windows Desktop", build_dir + "/windows/")
    if platform == "linux" or platform == "all":
        _export("Linux/X11", build_dir + "/linux/")
    if platform == "android" or platform == "all":
        _export("Android", build_dir + "/android/")
    # ... other platforms

    quit()

func _export(preset_name: String, path: String):
    print("Exporting preset: ", preset_name)
    var preset = EditorExportPlatform.get_export_preset(preset_name)
    if preset:
        preset.export_path = path + preset.export_path.get_file()
        var result = preset.export()
        if result == OK:
            print("Export successful.")
        else:
            print("Export failed.")
```

### 3.3. Build Artifacts

-   All builds will be placed in a top-level `builds/` directory.
-   Each version will have its own subdirectory (e.g., `builds/v1.0.0/`).
-   Inside the version directory, each platform will have its own subdirectory (e.g., `builds/v1.0.0/windows/`).

This structure keeps all build artifacts organized and easy to find.

--- 

## 4. Release Checklist

1.  [ ] **Confirm Stability**: Ensure the `main` branch is stable and all automated tests are passing.
2.  [ ] **Update Version**: Update the version number in `project.godot`.
3.  [ ] **Update Changelog**: Add a new entry to `CHANGELOG.md` detailing the changes in this version.
4.  [ ] **Commit Version Change**: Commit the version and changelog updates with a message like `chore: Bump version to vX.Y.Z`.
5.  [ ] **Tag the Release**: Create a new Git tag for the version (e.g., `git tag -a vX.Y.Z -m "Release vX.Y.Z"`).
6.  [ ] **Run Build Script**: Execute the build script to generate the artifacts for all platforms.
7.  [ ] **Push Tag**: Push the new tag to the remote repository (`git push --tags`).
8.  [ ] **Upload Builds**: Upload the generated build artifacts to the respective platform storefronts (Steam, Google Play, App Store) as detailed in the `multi_platform_release_checklist.md`.
