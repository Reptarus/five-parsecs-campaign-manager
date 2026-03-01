# Five Parsecs Campaign Manager - Production Deployment Checklist

**Version**: 1.0
**Target Release**: v1.0-rc1 (Release Candidate 1)
**Deployment Date**: TBD (After Phase 1 completion)
**Platform**: Windows x64, Linux AppImage
**Godot Version**: 4.5.1-stable (non-mono)

---

## Pre-Deployment Validation

### 🔴 CRITICAL - Must Complete Before ANY Deployment

- [ ] **BattlePhase Handler Created**
  - [ ] Create `src/core/campaign/phases/BattlePhase.gd`
  - [ ] Implement battle setup → combat → resolution flow
  - [ ] Wire into `CampaignPhaseManager.gd`
  - [ ] Test complete turn cycle (Travel → World → Battle → Post-Battle)
  - **Estimated Time**: 3-4 hours
  - **Owner**: Developer
  - **Status**: NOT STARTED

- [ ] **Platform Builds Created**
  - [ ] Windows x64 build exported
  - [ ] Linux AppImage build exported
  - [ ] Builds tested on respective platforms
  - **Estimated Time**: 4-6 hours
  - **Owner**: Developer
  - **Status**: NOT STARTED

- [ ] **E2E Tests Passing**
  - [ ] Fix equipment field mismatch in 2 failing tests
  - [ ] Validate 100% test coverage (138/138 tests)
  - [ ] Run full test suite on both platforms
  - **Estimated Time**: 35 minutes
  - **Owner**: QA/Developer
  - **Status**: NOT STARTED

- [ ] **Save/Load Validation**
  - [ ] Test save file creation on Windows
  - [ ] Test save file creation on Linux
  - [ ] Test cross-platform save file compatibility (Windows → Linux, Linux → Windows)
  - [ ] Validate schema migration from v1 to current version
  - **Estimated Time**: 1 hour
  - **Owner**: QA
  - **Status**: NOT STARTED

- [ ] **Performance Profiling**
  - [ ] Profile on low-end hardware (4GB RAM, integrated graphics)
  - [ ] Validate 60 FPS target in all phases
  - [ ] Check memory usage under 500MB
  - [ ] Test long campaign stability (100+ turns)
  - **Estimated Time**: 2 hours
  - **Owner**: QA
  - **Status**: NOT STARTED

- [ ] **Memory Leak Audit**
  - [ ] Run 1000-turn stress test
  - [ ] Monitor memory usage trends
  - [ ] Fix any detected memory leaks
  - **Estimated Time**: 2 hours
  - **Owner**: Developer
  - **Status**: NOT STARTED

---

## Platform-Specific Builds

### Windows x64 Build

- [ ] **Export Configuration**
  - [ ] Set export preset: Windows Desktop (64-bit)
  - [ ] Configure icon: `assets/icon.png`
  - [ ] Enable console output for debugging (optional)
  - [ ] Set executable name: `FiveParsecsCampaignManager.exe`

- [ ] **Build Artifacts**
  - [ ] Create export folder: `builds/windows-x64/`
  - [ ] Export executable + data files
  - [ ] Package dependencies (Godot runtime)
  - [ ] Create zip archive: `FiveParsecs-v1.0-rc1-Windows-x64.zip`

- [ ] **Windows Testing**
  - [ ] Test on Windows 10 (minimum supported)
  - [ ] Test on Windows 11 (current)
  - [ ] Validate file permissions (user directory write access)
  - [ ] Test save file paths (`AppData/Roaming/FiveParsecs/`)
  - [ ] Verify antivirus compatibility (Windows Defender)

**Estimated Time**: 2 hours
**Status**: NOT STARTED

---

### Linux AppImage Build

- [ ] **Export Configuration**
  - [ ] Set export preset: Linux/X11 (64-bit)
  - [ ] Configure icon: `assets/icon.png`
  - [ ] Enable console output for debugging (optional)
  - [ ] Set executable name: `FiveParsecsCampaignManager.x86_64`

- [ ] **Build Artifacts**
  - [ ] Create export folder: `builds/linux-x64/`
  - [ ] Export executable + data files
  - [ ] Package as AppImage: `FiveParsecs-v1.0-rc1-Linux-x86_64.AppImage`
  - [ ] Set executable permissions: `chmod +x FiveParsecs-*.AppImage`

- [ ] **Linux Testing**
  - [ ] Test on Ubuntu 22.04 LTS (recommended)
  - [ ] Test on Fedora 39 (latest)
  - [ ] Validate file permissions (user home directory)
  - [ ] Test save file paths (`~/.local/share/FiveParsecs/`)
  - [ ] Verify dependency availability (X11, OpenGL)

**Estimated Time**: 2 hours
**Status**: NOT STARTED

---

### macOS App Bundle (Optional - Deferred)

- [ ] **Export Configuration**
  - [ ] Set export preset: macOS
  - [ ] Configure icon: `assets/icon.icns`
  - [ ] Code signing (Apple Developer account required)
  - [ ] Set bundle identifier: `com.fiveparsecs.campaignmanager`

- [ ] **Build Artifacts**
  - [ ] Create export folder: `builds/macos/`
  - [ ] Export `.app` bundle
  - [ ] Notarize for Gatekeeper (Apple Developer account)
  - [ ] Create DMG: `FiveParsecs-v1.0-rc1-macOS.dmg`

- [ ] **macOS Testing**
  - [ ] Test on macOS 12 Monterey (minimum supported)
  - [ ] Test on macOS 14 Sonoma (current)
  - [ ] Validate Gatekeeper approval
  - [ ] Test save file paths (`~/Library/Application Support/FiveParsecs/`)

**Estimated Time**: 4 hours
**Status**: DEFERRED TO v1.1

---

### Android APK (Optional - Deferred)

- [ ] **Export Configuration**
  - [ ] Set export preset: Android
  - [ ] Configure permissions: `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE`
  - [ ] Set minimum SDK: API 21 (Android 5.0)
  - [ ] Set target SDK: API 34 (Android 14)
  - [ ] Configure keystore for signing

- [ ] **Build Artifacts**
  - [ ] Create export folder: `builds/android/`
  - [ ] Export APK: `FiveParsecs-v1.0-rc1-Android.apk`
  - [ ] Sign APK with release keystore
  - [ ] Align APK for Google Play (optional)

- [ ] **Android Testing**
  - [ ] Test on Android 8.0 (minimum recommended)
  - [ ] Test on Android 14 (current)
  - [ ] Validate touch targets (48dp minimum)
  - [ ] Test save file paths (`/sdcard/Android/data/com.fiveparsecs/`)
  - [ ] Verify permissions granted

**Estimated Time**: 5 hours
**Status**: DEFERRED TO v1.2 (Mobile Optimized)

---

## Post-Deployment Monitoring

### Error Reporting Configuration

- [ ] **Sentry Integration** (Optional)
  - [ ] Create Sentry project: `five-parsecs-campaign-manager`
  - [ ] Add Sentry GDScript SDK (if available)
  - [ ] Configure error capture in `ErrorLogger.gd`
  - [ ] Test error reporting (intentional crash)
  - **Estimated Time**: 2 hours
  - **Status**: DEFERRED (manual logging sufficient for v1.0)

- [ ] **Manual Error Logging**
  - [ ] Ensure `ErrorLogger.gd` writes to log file
  - [ ] Log file path: `user://logs/error_log.txt`
  - [ ] Include timestamp, error type, stack trace
  - [ ] Rotate log files (keep last 5)
  - **Status**: IMPLEMENTED ✅

---

### Analytics Tracking (Opt-In Only)

- [ ] **Privacy-First Analytics**
  - [ ] No PII collection (no usernames, emails, IP addresses)
  - [ ] Opt-in consent dialog on first launch
  - [ ] Anonymous telemetry only (campaign stats, system info)
  - [ ] Clear privacy policy displayed
  - **Estimated Time**: 3 hours
  - **Status**: DEFERRED TO v1.1

- [ ] **Telemetry Data Collected** (If user opts in)
  - [ ] Campaign turn count (min/max/avg)
  - [ ] Victory condition completion rates
  - [ ] Average session duration
  - [ ] Crash reports (stack traces only)
  - [ ] System specs (OS, Godot version, screen resolution)

---

### Crash Reporting Setup

- [ ] **Godot Debug Build**
  - [ ] Enable `--verbose` flag for debug builds
  - [ ] Log file auto-creation in `user://logs/`
  - [ ] Stack trace capture on crashes
  - [ ] User-facing crash dialog with log file path

- [ ] **User Feedback Channel**
  - [ ] GitHub Issues template for bug reports
  - [ ] Discord server for community support (optional)
  - [ ] Email support: `support@fiveparsecs.com` (optional)
  - **Estimated Time**: 1 hour
  - **Status**: PARTIALLY IMPLEMENTED (GitHub Issues only)

---

## Rollback Plan

### Scenario: Critical Bug Discovered Post-Deployment

- [ ] **Preserve Previous Version**
  - [ ] Archive v0.9.x builds in `builds/archive/`
  - [ ] Keep v0.9.x save file migration paths
  - [ ] Maintain v0.9.x download links for 30 days
  - **Status**: NOT APPLICABLE (v1.0 is first public release)

- [ ] **Rollback Procedure**
  1. Remove v1.0 download links immediately
  2. Restore v0.9.x download links as primary
  3. Post announcement on GitHub Releases page
  4. Notify users via Discord/email (if applicable)
  5. Document bug in GitHub Issues with `critical` label
  6. Create hotfix branch from v1.0 tag
  7. Deploy v1.0.1 patch within 48 hours

- [ ] **User Migration Path**
  - [ ] Provide save file migration tool (v1.0 → v0.9.x)
  - [ ] Document breaking changes in CHANGELOG.md
  - [ ] Offer manual migration instructions
  - **Estimated Time**: 4 hours (emergency response)
  - **Status**: CONTINGENCY PLAN (not needed if pre-deployment testing passes)

---

## Release Workflow

### 1. Version Tagging

- [ ] **Git Tag Creation**
  ```bash
  git tag -a v1.0-rc1 -m "Release Candidate 1 - Production Testing"
  git push origin v1.0-rc1
  ```

- [ ] **GitHub Release Draft**
  - [ ] Title: `Five Parsecs Campaign Manager v1.0-rc1`
  - [ ] Description: Include CHANGELOG.md excerpt
  - [ ] Attach Windows build: `FiveParsecs-v1.0-rc1-Windows-x64.zip`
  - [ ] Attach Linux build: `FiveParsecs-v1.0-rc1-Linux-x86_64.AppImage`
  - [ ] Mark as "Pre-release" (RC status)

---

### 2. Release Notes Template

```markdown
# Five Parsecs Campaign Manager v1.0-rc1

**Release Date**: YYYY-MM-DD
**Release Type**: Release Candidate (Production Testing)
**Platforms**: Windows x64, Linux x86_64

## What's New

- ✅ Complete turn loop orchestration (Travel → World → Battle → Post-Battle)
- ✅ Victory condition system with custom targets
- ✅ Character creation with Background/Motivation/Class modifiers
- ✅ Save/Load system with automatic backup rotation (5 backups)
- ✅ 98.5% test coverage (136/138 tests passing)
- ✅ Performance optimizations (2-3.3x targets)

## Bug Fixes

- 🔧 Fixed quest rumor consumption bug (rumors now properly removed when used)
- 🔧 Fixed equipment field mismatch in E2E tests

## Known Issues

- ⚠️ macOS and Android builds not yet available (deferred to v1.1+)
- ⚠️ 130 TODO comments remain (non-critical, tracked in GitHub Issues)

## System Requirements

**Minimum**:
- OS: Windows 10 / Ubuntu 20.04
- RAM: 4GB
- GPU: OpenGL 3.3 compatible (integrated graphics sufficient)
- Storage: 500MB

**Recommended**:
- OS: Windows 11 / Ubuntu 22.04
- RAM: 8GB
- GPU: Dedicated graphics card
- Storage: 1GB

## Installation

**Windows**:
1. Download `FiveParsecs-v1.0-rc1-Windows-x64.zip`
2. Extract to desired location
3. Run `FiveParsecsCampaignManager.exe`

**Linux**:
1. Download `FiveParsecs-v1.0-rc1-Linux-x86_64.AppImage`
2. Make executable: `chmod +x FiveParsecs-*.AppImage`
3. Run: `./FiveParsecs-v1.0-rc1-Linux-x86_64.AppImage`

## Feedback

Report bugs: https://github.com/[your-repo]/issues
Documentation: https://github.com/[your-repo]/wiki
```

---

### 3. Distribution Channels

- [ ] **GitHub Releases** (Primary)
  - [ ] Upload Windows build
  - [ ] Upload Linux build
  - [ ] Publish release notes
  - [ ] Mark as pre-release (RC status)

- [ ] **Itch.io** (Optional)
  - [ ] Create project page
  - [ ] Upload builds with version tags
  - [ ] Set pricing (free for v1.0)
  - [ ] Add screenshots and gameplay videos
  - **Status**: DEFERRED TO v1.1

- [ ] **Steam** (Optional - Future)
  - [ ] Requires Steam Direct fee ($100)
  - [ ] Requires extensive Steam SDK integration
  - [ ] Requires achievements, trading cards, Steam Cloud saves
  - **Status**: DEFERRED TO v2.0

---

## Post-Release Validation (First 48 Hours)

### Critical Monitoring

- [ ] **GitHub Issues Triage**
  - [ ] Monitor for crash reports (check every 4 hours)
  - [ ] Respond to critical bugs within 12 hours
  - [ ] Create hotfix branch if P0 bugs found

- [ ] **Error Log Analysis**
  - [ ] Review submitted error logs (if users share)
  - [ ] Identify common crash patterns
  - [ ] Prioritize fixes for v1.0.1

- [ ] **User Feedback Collection**
  - [ ] Monitor GitHub Discussions
  - [ ] Track Discord mentions (if server exists)
  - [ ] Collect usability feedback for v1.1

---

## Success Criteria (v1.0-rc1 → v1.0 Graduation)

### Quantitative Metrics

- [ ] **Stability**
  - [ ] Zero critical bugs reported in first 7 days
  - [ ] <5 minor bugs reported in first 7 days
  - [ ] 95%+ uptime (no frequent crashes)

- [ ] **Performance**
  - [ ] 60 FPS maintained on minimum spec hardware
  - [ ] <500MB memory usage under normal gameplay
  - [ ] Save/Load completes in <5 seconds

- [ ] **User Satisfaction**
  - [ ] 90%+ positive feedback on GitHub (stars, comments)
  - [ ] <10% bug-related negative feedback
  - [ ] At least 10 successful campaign completions reported

### Qualitative Metrics

- [ ] **Gameplay Loop**
  - [ ] Users can complete full turn cycle without errors
  - [ ] Victory conditions trigger correctly
  - [ ] Save/Load preserves all campaign state

- [ ] **Usability**
  - [ ] New users can start campaign within 5 minutes
  - [ ] UI navigation is intuitive (minimal support requests)
  - [ ] Documentation covers 90%+ of user questions

---

## Hotfix Deployment (Emergency Response)

### Trigger Conditions (P0 - Critical)

- Game-breaking bug preventing turn completion
- Save file corruption causing data loss
- Crashes on startup affecting >50% of users
- Security vulnerability discovered

### Hotfix Workflow

1. **Triage** (Within 1 hour of report)
   - [ ] Reproduce bug on local environment
   - [ ] Assess severity (P0/P1/P2)
   - [ ] Determine root cause

2. **Fix Development** (Within 4 hours)
   - [ ] Create hotfix branch: `hotfix/v1.0.1-[bug-description]`
   - [ ] Implement minimal fix (no feature additions)
   - [ ] Add regression test
   - [ ] Test on both platforms

3. **Deployment** (Within 8 hours)
   - [ ] Tag hotfix: `v1.0.1`
   - [ ] Build Windows + Linux releases
   - [ ] Update GitHub Release
   - [ ] Post announcement on all channels

4. **Post-Mortem** (Within 24 hours)
   - [ ] Document root cause analysis
   - [ ] Identify prevention measures
   - [ ] Update testing procedures

---

## Final Sign-Off

### Pre-Deployment Approval

- [ ] **Development Lead**: All features complete, code reviewed
- [ ] **QA Lead**: All tests passing, platforms validated
- [ ] **Product Owner**: Release notes approved, user documentation complete
- [ ] **DevOps**: Builds created, distribution channels configured

**Deployment Authorization**: _____________________ (Name + Date)

---

## Appendix: Platform-Specific Notes

### Windows Deployment Notes

- **Installer**: Not required for v1.0 (portable zip distribution)
- **Antivirus**: Unsigned executable may trigger Windows Defender warnings
  - Solution: Add executable to exclusions (user responsibility)
  - Future: Code signing certificate for v1.1+ (~$300/year)

### Linux Deployment Notes

- **AppImage**: Self-contained, no dependencies required
- **Permissions**: Ensure `chmod +x` instructions in README
- **Desktop Integration**: AppImage auto-integrates on first launch
- **Alternative**: Flatpak/Snap packages deferred to v1.2

### macOS Deployment Notes (Deferred)

- **Gatekeeper**: Requires Apple Developer account ($99/year)
- **Notarization**: Required for macOS 10.15+ distribution
- **Code Signing**: Must sign with Developer ID certificate
- **Decision**: Deferred until Windows/Linux validates market demand

---

**Checklist Version**: 1.0
**Last Updated**: 2025-11-27
**Next Review**: After Phase 1 completion
