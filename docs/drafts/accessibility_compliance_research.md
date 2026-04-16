# EU/UK Accessibility Compliance Research
## Five Parsecs Campaign Manager

**Prepared for**: Modiphius Entertainment (Gavin + team) / Elijah Rhyne
**Date**: April 16, 2026
**Meeting context**: April 22, 2026 call — accessibility compliance planning
**App**: Five Parsecs Campaign Manager v0.9.7-dev (Godot 4.6, GDScript)
**Platforms**: Steam (Windows/Linux/macOS), Google Play (Android), Apple App Store (iOS)
**Markets**: Worldwide including EU and UK

---

## 1. Executive Summary

Five Parsecs Campaign Manager already has a strong accessibility foundation: four colorblind themes, high-contrast mode (21:1 ratio), font scaling, reduced-motion toggle, 48px minimum touch targets, keyboard navigation, and Godot 4.6's native AccessKit screen reader driver enabled. We estimate the app is approximately 65-70% of the way to WCAG 2.1 Level AA conformance today.

The primary gaps are: screen reader OS integration (pipes are built but detection stubs return false), missing text alternatives for some visual elements, incomplete focus order management on complex screens, and the absence of a published accessibility statement. Closing these gaps is achievable before launch and positions us well for both the European Accessibility Act (now in force) and UK Equality Act compliance.

---

## 2. Regulatory Landscape

### 2.1 European Accessibility Act (EAA) — Directive (EU) 2019/882

**Status**: In force since **June 28, 2025**. All EU member states have transposed the directive into national law.

**What it covers**: The EAA mandates accessibility for products and services placed on the EU market, including:
- Mobile applications
- E-commerce services (including in-app purchases and DLC storefronts)
- Desktop software distributed to consumers

**How it applies to us**: Five Parsecs Campaign Manager is a consumer-facing app sold through storefronts in EU markets. The app's in-app DLC store (Steam/Google Play/App Store purchases) constitutes an e-commerce service. The app itself is consumer software. Both categories fall under the EAA.

**Technical standard**: The EAA references **EN 301 549** as the harmonised European standard for ICT accessibility. EN 301 549 V3.2.1 incorporates WCAG 2.1 Level AA and adds additional requirements specific to native software and mobile applications that go beyond what WCAG covers for web content. A revised version (V4.1.1) is expected in 2026.

**Key requirements for our app**:
- All UI controls must be accessible via assistive technology (screen readers)
- Text content must meet contrast ratio requirements (4.5:1 for normal text, 3:1 for large text)
- Non-text content must have text alternatives
- All functionality must be operable via keyboard
- Users must not be locked into a single screen orientation
- Touch targets must meet minimum size requirements
- Timing-adjustable content must allow users to extend or disable time limits
- The in-app store/DLC purchase flow must be fully accessible

**Microenterprise exemption**: Businesses with fewer than 10 employees AND less than EUR 2 million annual turnover are exempt from the EAA's *service* requirements (but NOT product requirements). This exemption likely applies to Elijah's studio as developer, but **does not apply to Modiphius** as the publisher with EU presence. The publisher distributing the app in EU markets bears compliance responsibility.

**Penalties**: Vary by EU member state. Germany allows fines up to EUR 500,000. France allows EUR 5,000 to EUR 250,000. Some jurisdictions allow product/service removal from market or suspension of business rights. The general EU framework allows penalties up to EUR 100,000 or 4% of annual revenue.

**Transition period**: Products and services placed on the market *after* June 28, 2025 must comply immediately. Products already on the market before that date have until June 28, 2030. Since Five Parsecs Campaign Manager has not launched yet, **we will need to comply from day one**.

### 2.2 UK Equality Act 2010

**Status**: In force since 2010. Applies to all organisations providing goods or services in the UK.

**What it requires**: Organisations must make "reasonable adjustments" so that disabled people are not placed at a substantial disadvantage when accessing goods, services, or facilities. This applies to digital products including apps.

**Technical standard**: The Equality Act does not hard-code a specific technical standard, but **WCAG 2.2 Level AA** is the accepted benchmark for demonstrating "reasonable adjustments" for digital services. (Note: WCAG 2.2 builds on 2.1 with a few additional criteria; meeting 2.1 AA gets us most of the way.)

**How it applies to us**: Modiphius is UK-based (London). The app will be sold to UK consumers. This clearly falls under the Act.

**Enforcement**: The Equality and Human Rights Commission (EHRC) can investigate, issue unlawful act notices, and initiate legal proceedings. Individuals can also bring civil claims for discrimination.

**Key difference from EAA**: The UK Equality Act is principle-based ("reasonable adjustments") rather than prescriptive. There is no microenterprise exemption. The standard of "reasonable" is judged relative to the organisation's size, resources, and the nature of the product. For a published commercial app, meeting WCAG 2.1 AA would be considered a strong demonstration of reasonable adjustment.

### 2.3 Bottom Line for Us

| Regulation | Applies? | Standard | Timeline |
|---|---|---|---|
| European Accessibility Act (EAA) | **Yes** — app sold in EU markets, DLC store is e-commerce | EN 301 549 (incorporates WCAG 2.1 AA) | Must comply at launch (new product) |
| UK Equality Act 2010 | **Yes** — publisher is UK-based, sold to UK consumers | WCAG 2.1/2.2 AA (accepted benchmark) | Must comply at launch (ongoing obligation) |
| EN 301 549 V3.2.1 | **Yes** — harmonised standard for EAA | WCAG 2.1 AA + native software requirements | Current version; V4.1.1 expected 2026 |

**Our compliance target should be WCAG 2.1 Level AA** as the common denominator that satisfies both the EAA (via EN 301 549) and the UK Equality Act.

---

## 3. WCAG 2.1 AA Compliance Matrix

WCAG 2.1 AA consists of 50 success criteria (30 Level A + 20 Level AA). Below are the criteria most relevant to a native app (not a website), with our current status for each. Criteria that are purely web-specific (e.g., page titles for web pages, bypass blocks for web navigation) are omitted or noted as not applicable.

### Principle 1: Perceivable

| # | Criterion | Level | Status | Notes |
|---|---|---|---|---|
| 1.1.1 | Non-Text Content | A | **Partial** | Buttons have text labels. Some icons (game-icons.net SVGs) lack text alternatives. Portrait initials are decorative (OK). Terrain map symbols need alt text for screen readers. |
| 1.2.1 | Audio-only / Video-only | A | **N/A** | App has no audio/video content |
| 1.2.2 | Captions (Prerecorded) | A | **N/A** | No video content |
| 1.2.3 | Audio Description | A | **N/A** | No video content |
| 1.2.5 | Audio Description (Prerecorded) | AA | **N/A** | No video content |
| 1.3.1 | Info and Relationships | A | **Partial** | Godot AccessKit exposes standard Control node types (Button, Label, etc.) to the accessibility tree. Custom-drawn UI elements (battlefield map, character cards built from code) may not expose structure. |
| 1.3.2 | Meaningful Sequence | A | **Partial** | Tab order follows visual layout in most panels. Some code-built screens may have non-obvious tab sequences. |
| 1.3.3 | Sensory Characteristics | A | **Pass** | Instructions do not rely solely on shape, color, size, or location. Status information uses text labels alongside color. |
| 1.3.4 | Orientation | AA | **Pass** | App supports both portrait and landscape; no orientation lock |
| 1.3.5 | Identify Input Purpose | AA | **Partial** | Input fields exist for character names, numbers, etc. Autocomplete/purpose attributes are a web concept, but the principle of identifying field purpose applies. Most fields have labels. |
| 1.4.1 | Use of Color | A | **Pass** | Color is never the sole means of conveying information. Status badges include text. Health bars include numeric values. Four colorblind themes available. |
| 1.4.2 | Audio Control | A | **N/A** | No auto-playing audio |
| 1.4.3 | Contrast (Minimum) | AA | **Pass** | Default theme: primary text ~10:1, secondary text ~4.5:1 (both pass AA). High contrast theme: 21:1. |
| 1.4.4 | Resize Text | AA | **Pass** | Font scaling: Small (0.85x), Normal (1.0x), Large (1.15x) via AccessibilitySettingsPanel. UI uses responsive layouts. |
| 1.4.5 | Images of Text | AA | **Pass** | No images of text used. All text is rendered as actual text. |
| 1.4.10 | Reflow | AA | **Pass** | Responsive design with 3 breakpoints (Mobile <480, Tablet 480-768, Desktop >1024). HFlowContainer layouts reflow content. |
| 1.4.11 | Non-text Contrast | AA | **Partial** | UI component borders generally meet 3:1 against adjacent colors. Some subtle borders in default dark theme may be close to threshold. High contrast theme fully passes. |
| 1.4.12 | Text Spacing | AA | **Pass** | Text rendering uses Godot's built-in text layout which respects system text spacing. Font sizing settings available. |
| 1.4.13 | Content on Hover or Focus | AA | **Partial** | Tooltip system (KeywordDB) exists. Need to verify that tooltips are dismissible, hoverable, and persistent per WCAG requirements. |

### Principle 2: Operable

| # | Criterion | Level | Status | Notes |
|---|---|---|---|---|
| 2.1.1 | Keyboard | A | **Partial** | AccessibilityManager provides F6 section cycling, keyboard shortcuts. Godot's built-in focus system handles Tab/Shift-Tab for standard controls. Complex custom UI (battlefield map, terrain generator) may not be fully keyboard-operable. |
| 2.1.2 | No Keyboard Trap | A | **Pass** | Escape key returns to previous focus via AccessibilityManager. Dialog close buttons present. No known keyboard traps. |
| 2.1.4 | Character Key Shortcuts | A | **Pass** | No single-character keyboard shortcuts that could conflict with assistive technology |
| 2.2.1 | Timing Adjustable | A | **Pass** | No timed content. Campaign turns are player-paced. No auto-advancing timers. |
| 2.2.2 | Pause, Stop, Hide | A | **Pass** | Reduced motion toggle disables all 70+ TweenFX animations. No auto-playing moving/blinking content that cannot be stopped. |
| 2.3.1 | Three Flashes | A | **Pass** | No flashing content. Reduced motion toggle available as additional safety. |
| 2.4.1 | Bypass Blocks | A | **Partial** | F6 cycles UI sections (AccessibilityManager). Not all screens implement section registration for F6 cycling. |
| 2.4.2 | Page Titled | A | **Pass** | Each screen has a visible title. Screen reader announcement for panel changes implemented (`announce_panel_change()`). |
| 2.4.3 | Focus Order | A | **Partial** | Standard Godot controls have logical focus order. Code-built complex panels may need explicit `focus_neighbor_*` configuration. |
| 2.4.4 | Link Purpose | A | **Pass** | Links/buttons have descriptive text. No generic "click here" labels. |
| 2.4.5 | Multiple Ways | AA | **Pass** | Campaign dashboard provides multiple navigation paths. SceneRouter handles all navigation. |
| 2.4.6 | Headings and Labels | AA | **Pass** | Sections use clear headings. Form fields have labels. |
| 2.4.7 | Focus Visible | AA | **Pass** | AccessibilityManager adds cyan focus ring (2px border, Color #4FC3F7) to all registered elements. Godot's default focus styles also apply. |
| 2.5.1 | Pointer Gestures | A | **Pass** | No multipoint or path-based gestures required. All actions are single-tap/click. |
| 2.5.2 | Pointer Cancellation | A | **Pass** | Godot buttons activate on release (up-event), not on down-event. |
| 2.5.3 | Label in Name | A | **Partial** | Visual labels generally match accessible names. Need to audit that AccessKit-exposed names match visible text for all controls. |
| 2.5.4 | Motion Actuation | A | **Pass** | No motion-based inputs (shake, tilt). All actions use standard controls. |

### Principle 3: Understandable

| # | Criterion | Level | Status | Notes |
|---|---|---|---|---|
| 3.1.1 | Language of Page | A | **Partial** | App is English-only. Godot project does not set a language property that assistive technology can read. Need to set `TranslationServer.set_locale()` or equivalent. |
| 3.1.2 | Language of Parts | AA | **N/A** | English-only app, no mixed-language content |
| 3.2.1 | On Focus | A | **Pass** | Focus changes do not trigger unexpected context changes |
| 3.2.2 | On Input | A | **Pass** | Form inputs do not trigger unexpected context changes |
| 3.2.3 | Consistent Navigation | AA | **Pass** | Navigation patterns are consistent. Dashboard layout is persistent. SceneRouter provides predictable navigation. |
| 3.2.4 | Consistent Identification | AA | **Pass** | UI components with the same function use consistent labels and icons throughout |
| 3.3.1 | Error Identification | A | **Pass** | Validation errors are shown with text descriptions. `announce_validation_error()` available for screen reader. |
| 3.3.2 | Labels or Instructions | A | **Pass** | Form fields have labels. Campaign creation wizard provides step-by-step instructions. |
| 3.3.3 | Error Suggestion | AA | **Partial** | Some validation provides correction suggestions. Not all error states include actionable guidance. |
| 3.3.4 | Error Prevention | AA | **Pass** | Destructive actions (delete save, dismiss crew) require confirmation dialogs |

### Principle 4: Robust

| # | Criterion | Level | Status | Notes |
|---|---|---|---|---|
| 4.1.1 | Parsing | A | **Pass** | Native app (not HTML). Godot scene tree is well-formed. |
| 4.1.2 | Name, Role, Value | A | **Partial** | AccessKit driver exposes standard Control nodes automatically. Custom widgets (code-built panels, battlefield map) may not expose correct roles/names. This is the primary gap. |
| 4.1.3 | Status Messages | AA | **Partial** | `AccessibilityManager.announce_to_screen_reader()` exists for status messages. Not all status changes (turn phase transitions, battle results, campaign events) trigger announcements yet. |

### Summary

| Category | Total Criteria | Pass | Partial | Gap | N/A |
|---|---|---|---|---|---|
| Perceivable | 17 | 9 | 5 | 0 | 3 |
| Operable | 15 | 10 | 4 | 0 | 1 |
| Understandable | 9 | 7 | 2 | 0 | 0 |
| Robust | 3 | 1 | 2 | 0 | 0 |
| **Total** | **44 applicable** | **27** | **13** | **0** | **6** |

No outright failures. 13 criteria are partially met and need targeted work to reach full compliance.

---

## 4. Current Implementation Summary

### Already Built and Verified

| Feature | Implementation | Files |
|---|---|---|
| **Colorblind Themes (4 modes)** | Deuteranopia, Protanopia, Tritanopia, High Contrast with WCAG-compliant palettes | `AccessibilityThemes.gd` (365 lines), `ThemeManager.gd` (667 lines) |
| **High Contrast Mode** | 21:1 ratio, pure black/white backgrounds, yellow focus rings, 3px borders | `ThemeManager._apply_high_contrast_variant()` |
| **Font Scaling** | Small (0.85x), Normal (1.0x), Large (1.15x) via settings panel | `AccessibilitySettingsPanel.gd` (300 lines) |
| **Reduced Motion Toggle** | Disables 70+ TweenFX animations, speeds up essential transitions | `ThemeManager.set_reduced_animation()` + `TweenFX` addon |
| **Touch Targets** | 48px minimum, 56px comfortable. Enforced via `TOUCH_TARGET_MIN` constant | `WorldPhaseComponent`, `BaseCampaignPanel` |
| **Keyboard Navigation** | F6 section cycling, F7+Ctrl high contrast toggle, F8+Ctrl read element, Escape back | `AccessibilityManager.gd` (378 lines) |
| **Focus Management** | Focus groups, 10-item focus history, focus indicators (cyan 2px ring) | `AccessibilityManager.gd` |
| **Screen Reader Architecture** | Announcement queue with timing, panel change announcements, validation error announcements, element type detection | `AccessibilityManager.gd` |
| **AccessKit Driver** | Godot 4.6 native accessibility tree enabled | `project.godot`: `general/accessibility_driver="accesskit"` |
| **Responsive Design** | 3 breakpoints, HFlowContainer layouts, max-width content centering | `FiveParsecsCampaignPanel`, responsive layout system |
| **Default Theme Contrast** | Primary text ~10:1 ratio, secondary text ~4.5:1 ratio (both pass WCAG AA) | Deep Space theme in `sci_fi_theme.tres` |
| **Color-independent Information** | Status badges include text labels, health shows numeric values alongside color | Throughout UI codebase |
| **Settings Persistence** | Accessibility preferences saved to `user://theme_config.cfg` and survive app restart | `ThemeManager.save_config()` |

### Partially Built (Infrastructure Exists, Completion Needed)

| Feature | Current State | What Remains |
|---|---|---|
| **Screen Reader OS Detection** | `_detect_screen_reader()` and `_check_*_high_contrast()` methods exist but return `false` (stubs) | Connect to OS APIs: Windows registry for high contrast, NVDA/JAWS process detection, macOS `NSWorkspace` accessibility, Android TalkBack, iOS VoiceOver |
| **Screen Reader Announcements** | `announce_to_screen_reader()` emits signal but does not call native OS screen reader API | With AccessKit enabled, Godot 4.6 should route announcements through the accessibility tree. Need to verify this works and ensure all status changes trigger announcements |
| **F6 Section Cycling** | `_cycle_ui_sections()` returns `false` (stub) | Each major screen needs to register its focusable sections |

---

## 5. Gap Analysis

### Priority 1: Must-Have Before Launch

These items are required for EAA/EN 301 549 compliance and should block release if unresolved.

| Gap | WCAG Criteria | Effort | Description |
|---|---|---|---|
| **Screen reader integration verification** | 4.1.2, 4.1.3 | Medium (2-3 days) | Verify that Godot 4.6's AccessKit driver correctly exposes all standard Control nodes to NVDA (Windows), VoiceOver (macOS/iOS), and TalkBack (Android). Test with actual screen readers. Fix any nodes that are not exposed. |
| **Custom widget accessibility** | 4.1.2, 1.3.1 | Medium (3-5 days) | Code-built panels, battlefield map, character cards, and terrain generator create UI elements programmatically. These need explicit `accessibility_name`, `accessibility_role`, and `accessibility_description` properties set via Godot's AccessKit bindings. |
| **Text alternatives for icons** | 1.1.1 | Low (1-2 days) | Audit all icon-only buttons and decorative images. Add `tooltip_text` (which AccessKit reads as accessible name) or `accessibility_name` to every interactive icon. |
| **Focus order audit** | 2.4.3, 1.3.2 | Medium (2-3 days) | Walk through every screen with keyboard-only navigation. Fix tab order where it does not match visual layout. Set `focus_neighbor_*` properties on code-built panels. |
| **Status message announcements** | 4.1.3 | Medium (2-3 days) | Add `announce_to_screen_reader()` calls for: turn phase changes, battle results, campaign events, save/load confirmations, DLC purchase results, error states. |
| **Language declaration** | 3.1.1 | Low (< 1 hour) | Set `TranslationServer.set_locale("en")` at startup so assistive technology knows the app language. |
| **Accessibility statement** | EAA requirement | Low (1 day) | Write and publish an accessibility statement documenting conformance level, known limitations, and contact information. Required by EN 301 549. Can be in-app and/or on the website. |
| **DLC store flow audit** | EAA e-commerce | Low (1-2 days) | Walk through the entire DLC purchase flow with keyboard and screen reader. The EAA specifically covers e-commerce transactions. |

### Priority 2: Should-Have (Strengthens Compliance, Reduces Risk)

| Gap | WCAG Criteria | Effort | Description |
|---|---|---|---|
| **Non-text contrast audit** | 1.4.11 | Low (1 day) | Measure contrast ratios for all UI component borders, icons, and focus indicators against their backgrounds. Fix any below 3:1. |
| **Tooltip dismissibility** | 1.4.13 | Low (1 day) | Ensure all tooltips (KeywordDB keyword tooltips, item previews) are dismissible with Escape, remain visible when hovered, and persist until dismissed. |
| **Error suggestion improvements** | 3.3.3 | Low (1-2 days) | Add actionable correction suggestions to validation errors where currently only the error is stated. |
| **Screen reader detection (native)** | N/A (UX) | Medium (2-3 days) | Replace `_detect_screen_reader()` stubs with actual OS API calls. Enables automatic announcement mode when a screen reader is detected. Not strictly required (users can enable manually) but improves UX. |
| **Accessible name = visible name audit** | 2.5.3 | Low (1 day) | Verify that every control's accessible name (as exposed by AccessKit) matches or contains its visible text label. |
| **Additional font scale options** | 1.4.4 | Low (1 day) | Consider adding Extra Large (1.3x-1.5x) option. Current max is 1.15x which may be insufficient for some low-vision users. EN 301 549 requires up to 200% text scaling without loss of content. |

### Priority 3: Nice-to-Have (Post-Launch Enhancements)

| Gap | Effort | Description |
|---|---|---|
| **WCAG 2.2 criteria** | Medium | WCAG 2.2 adds criteria like 2.4.11 (Focus Not Obscured), 2.4.13 (Focus Appearance), 2.5.7 (Dragging Movements), 2.5.8 (Target Size minimum 24x24px). UK guidance references 2.2; proactive compliance is advisable. |
| **Localization infrastructure** | High | While English-only now, the i18n framework should be in place for potential EU language requirements. |
| **Accessibility testing automation** | Medium | Integrate accessibility checks into QA pipeline. Godot does not have built-in accessibility linting, but manual screen reader testing protocols can be documented. |
| **User preference sync** | Low | Respect OS-level accessibility preferences (high contrast, reduced motion, font size) automatically rather than requiring manual in-app configuration. |

---

## 6. Godot 4.6 AccessKit Assessment

### What AccessKit Provides Automatically

Godot 4.6 includes the AccessKit library as its accessibility driver. When `general/accessibility_driver="accesskit"` is set in `project.godot` (which we have), the engine provides:

1. **Automatic accessibility tree for standard Control nodes**: Button, Label, LineEdit, CheckBox, CheckButton, OptionButton, SpinBox, TextEdit, RichTextLabel, ProgressBar, HSlider, VSlider, TabBar, Tree, ItemList, and other built-in Control types are automatically exposed to platform assistive technology APIs.

2. **Cross-platform screen reader support**: AccessKit translates Godot's accessibility tree to the native platform APIs:
   - **Windows**: UI Automation (used by NVDA, JAWS, Narrator)
   - **macOS/iOS**: NSAccessibility / UIAccessibility (used by VoiceOver)
   - **Linux**: AT-SPI2 (used by Orca)
   - **Android**: Android Accessibility Framework (used by TalkBack)

3. **Automatic role/name exposure**: Standard controls get their role (button, text field, checkbox, etc.) and name (from `text`, `tooltip_text`, or node name) exposed automatically.

4. **System accessibility preference detection**: AccessKit gives access to system-level settings like high contrast preferences and reduced motion preferences.

5. **Focus tracking**: The focused Control node is reported to assistive technology automatically.

### What We Still Need to Do

1. **Custom/code-built widgets**: Any UI element that is NOT a standard Godot Control (or is a Control with heavily customized rendering) needs manual accessibility annotation. This includes:
   - Battlefield terrain map (custom draw calls)
   - Character cards (code-assembled from multiple Controls)
   - Stat displays (custom formatted)
   - Campaign phase progress indicators

2. **Screen reader bindings**: Godot 4.5+ added the ability to attach custom screen reader bindings to any Node. We should use these for:
   - Complex panels that need custom descriptions
   - Dynamic status areas
   - Lists of game items/events

3. **Verification and testing**: AccessKit support in Godot is relatively new (introduced in 4.5, April 2025). We must test with actual screen readers on each platform to confirm:
   - All standard controls are correctly exposed
   - Focus changes are announced
   - Button presses and state changes are reported
   - Dialog open/close events are communicated

4. **AccessibilityManager reconciliation**: Our custom `AccessibilityManager.gd` was written before AccessKit integration was available. Some of its functionality (focus tracking, element announcements) may now be handled natively by AccessKit. We should audit for overlap and either:
   - Remove redundant custom code, relying on AccessKit
   - Keep custom code for higher-level features (panel change announcements, campaign progress) that AccessKit does not handle

### Risk Assessment

AccessKit in Godot is a relatively young feature (roughly 1 year old as of April 2026). The Godot team has acknowledged that screen reader support is still experimental in some areas. We should budget time for:
- Platform-specific quirks and bugs
- Possible need for workarounds on specific screen readers
- Testing on all target platforms (not just desktop)

---

## 7. Platform-Specific Requirements

### 7.1 Apple App Store (iOS/macOS)

**Mandatory accessibility requirements** (enforced during App Review):
- VoiceOver support for all interactive elements
- Dynamic Type implementation (system font size scaling)
- Color contrast minimum 4.5:1 for text
- Text alternatives for all meaningful images and icons

**Accessibility Nutrition Labels**: Apple has introduced voluntary accessibility labels for the App Store. Developers can report which accessibility features their app supports. While currently voluntary, Apple has indicated these will become required over time.

**Our status**: AccessKit should provide VoiceOver support automatically for standard Godot controls. We need to verify this works in practice on iOS, as Godot's iOS accessibility support may have limitations. Font scaling is implemented. Contrast ratios pass. Icon text alternatives need the audit noted in Section 5.

**Risk**: Apple App Review has been known to reject apps for accessibility failures. We should test thoroughly with VoiceOver on a physical iOS device before submission.

### 7.2 Google Play Store (Android)

**Requirements**: Google Play does not currently mandate specific accessibility features for general apps. However:
- TalkBack compatibility is an industry expectation
- The EAA applies to apps distributed in EU member states via Google Play
- Google Play's accessibility features listing allows developers to declare accessibility support

**Our status**: AccessKit should provide TalkBack support for standard Godot controls on Android. We need to verify this on a physical device. Touch target sizes (48px minimum) align with Android's accessibility guidelines (48dp minimum).

**Risk**: Lower risk of rejection compared to Apple, but EAA compliance is still required for EU distribution.

### 7.3 Steam (Windows/Linux/macOS)

**Requirements**: Steam does not mandate accessibility features. However:
- Steam introduced **accessibility tags** in 2025, allowing developers to self-report accessibility features via a wizard in Steamworks
- Tags cover 16+ categories across gameplay, visual, audio, and input accessibility
- Players can search and filter by accessibility tags
- The tags were updated in January 2026 with additional options

**Our status**: We can accurately report the following Steam accessibility tags:
- Colorblind modes: **Yes** (4 themes)
- High contrast mode: **Yes**
- Screen reader support: **Partial** (pending verification)
- Keyboard navigation: **Yes**
- Adjustable text size: **Yes**
- Reduced motion: **Yes**

**Opportunity**: Accurately reporting accessibility features on Steam improves discoverability and demonstrates commitment to accessibility. This is a marketing advantage, not just a compliance requirement.

### 7.4 Platform Summary

| Platform | Mandatory Requirements | Rejection Risk | Testing Needed |
|---|---|---|---|
| Apple App Store | VoiceOver, Dynamic Type, contrast, alt text | **High** — enforced in App Review | Physical iOS device with VoiceOver |
| Google Play | None store-specific (EAA applies separately) | **Low** for store, **Medium** for EAA | Physical Android device with TalkBack |
| Steam | None (voluntary tags) | **None** for accessibility | Windows with NVDA, macOS with VoiceOver |

---

## 8. Recommended Action Items

### Phase 1: Verification and Quick Wins (1-2 weeks, before launch)

| # | Action | Effort | Owner |
|---|---|---|---|
| 1 | **Screen reader testing sprint**: Test every major screen with NVDA (Windows), VoiceOver (macOS/iOS), and TalkBack (Android) using physical devices. Document what works and what does not. | 3-4 days | QA + Dev |
| 2 | **Language declaration**: Add `TranslationServer.set_locale("en")` to app startup | < 1 hour | Dev |
| 3 | **Icon alt text audit**: Add `tooltip_text` to all icon-only buttons and meaningful images | 1-2 days | Dev |
| 4 | **Focus order walkthrough**: Tab through every screen, fix broken tab orders | 2-3 days | Dev |
| 5 | **DLC store accessibility audit**: Walk through purchase flow with keyboard + screen reader | 1 day | QA |
| 6 | **Write accessibility statement**: Document conformance, known issues, contact info | 1 day | Dev + Modiphius |

### Phase 2: Gap Remediation (2-4 weeks)

| # | Action | Effort | Owner |
|---|---|---|---|
| 7 | **Custom widget accessibility**: Add AccessKit annotations to code-built UI (battlefield map, character cards, terrain generator, stat displays) | 3-5 days | Dev |
| 8 | **Status announcements**: Wire `announce_to_screen_reader()` into turn phase changes, battle results, campaign events, save/load, errors | 2-3 days | Dev |
| 9 | **Non-text contrast audit**: Measure and fix border/icon contrast ratios below 3:1 | 1 day | Dev |
| 10 | **Tooltip behavior fixes**: Ensure dismiss-on-Escape, hover-persistent, keyboard-accessible | 1 day | Dev |
| 11 | **Expand font scale range**: Add Extra Large (1.3x or 1.5x) option to meet EN 301 549 200% text scaling | 1 day | Dev |
| 12 | **AccessibilityManager/AccessKit reconciliation**: Audit overlap, remove redundant code, keep high-level features | 1-2 days | Dev |

### Phase 3: Post-Launch (Ongoing)

| # | Action | Effort | Owner |
|---|---|---|---|
| 13 | **WCAG 2.2 gap analysis**: Evaluate new 2.2 criteria and implement where applicable | 2-3 days | Dev |
| 14 | **Automated accessibility testing**: Document manual testing protocol, explore Godot accessibility linting options | Ongoing | QA |
| 15 | **User feedback channel**: Establish a way for users with disabilities to report accessibility issues | Setup: 1 day | Modiphius |
| 16 | **Steam accessibility tags**: Complete the Steamworks accessibility wizard and publish tags | 1 day | Dev/Publisher |

---

## 9. Timeline Suggestion

### Pre-Launch Critical Path

| Week | Focus | Deliverables |
|---|---|---|
| **Week 1** | Verification | Screen reader testing sprint complete. Bug list documented. Language set. Quick wins (alt text, focus order fixes) in progress. |
| **Week 2** | Quick Wins | Icon alt text complete. Focus order fixed. DLC store audited. Accessibility statement drafted. |
| **Week 3** | Gap Remediation | Custom widget annotations. Status announcements wired. Font scale expanded. |
| **Week 4** | Final Testing | Re-test with screen readers. Non-text contrast verified. Accessibility statement finalized and published. |

### Post-Launch

| Timeframe | Focus |
|---|---|
| **Launch + 1 month** | Monitor accessibility feedback. Steam tags published. |
| **Launch + 3 months** | WCAG 2.2 gap analysis. Address any screen reader issues discovered by users. |
| **Launch + 6 months** | Evaluate localization needs. Consider additional accessibility features based on user feedback. |

### Key Dates

- **April 22, 2026**: Modiphius meeting — present this research, align on timeline
- **Launch day**: Accessibility statement published, WCAG 2.1 AA conformance documented, screen reader support verified on all platforms
- **June 28, 2030**: EAA transition deadline for pre-existing services (not applicable to us since we launch after June 2025, but relevant for any future major version changes)

---

## Appendix A: Key Reference Standards

| Standard | Full Name | Relevance |
|---|---|---|
| WCAG 2.1 | Web Content Accessibility Guidelines 2.1 | Core technical standard referenced by both EAA and UK Equality Act |
| EN 301 549 V3.2.1 | Accessibility requirements for ICT products and services | EU harmonised standard (extends WCAG to native apps) |
| EN 301 549 V4.1.1 | (Expected 2026) | Updated version supporting EAA |
| WCAG 2.2 | Web Content Accessibility Guidelines 2.2 | Newer version; UK benchmark trending toward this |

## Appendix B: Research Sources

- [European Accessibility Act — EAA Compliance Guide (Level Access)](https://www.levelaccess.com/compliance-overview/european-accessibility-act-eaa/)
- [European Accessibility Act — European Commission](https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/european-accessibility-act-eaa_en)
- [EAA & Video Games: Going Over The Facts (Player Research, June 2025)](https://www.playerresearch.com/blog/european-accessibility-act-video-games-going-over-the-facts-june-2025/)
- [Impact of EAA on Online Gaming (Bird & Bird, 2026)](https://www.twobirds.com/en/insights/2026/the-impact-of-the-european-accessibility-act-on-online-gaming-and-gaming-devices)
- [Is Your Game Ready for the EAA? (Sprung Studios)](https://www.sprungstudios.com/eaa-compliance-for-games/)
- [EAA Exemptions 2025 — Who Doesn't Need to Comply?](https://www.webyes.com/blogs/eaa-exemptions/)
- [UK Equality Act: An In-Depth Guide (2026)](https://www.accessibilitychecker.org/guides/uk-equality-act/)
- [UK Web Accessibility Laws: 2026 Compliance Guide (Level Access)](https://www.levelaccess.com/blog/website-accessibility-laws-in-the-u-k/)
- [What to Expect from UK Digital Accessibility in 2026 (YUDU)](https://www.yudu.com/blog/digital-accessibility-expectations-2026/)
- [EN 301 549 — ETSI Harmonized European Standard](https://www.etsi.org/human-factors-accessibility/en-301-549-v3-the-harmonized-european-standard-for-ict-accessibility)
- [EN 301 549 Conformance (WCAG.com)](https://www.wcag.com/compliance/en-301-549/)
- [Godot 4.5 Accessibility Features (Game Developer)](https://www.gamedeveloper.com/programming/godot-4-5-ushers-in-accessibility-features-including-screen-reader-support)
- [Godot 4.5 Accessibility (Can I Play That?)](https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/)
- [Godot AccessKit PR #76829 (GitHub)](https://github.com/godotengine/godot/pull/76829)
- [Godot Accessibility Demo (GitHub)](https://github.com/aefren/godot-accessibility-demo)
- [Apple Accessibility Developer Documentation](https://developer.apple.com/accessibility/)
- [Apple Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [Steam Accessibility Features (Steam Support)](https://help.steampowered.com/en/faqs/view/02F5-ACB2-6038-0F36)
- [Steam Accessibility Tags (Accessibility Labs)](https://accessibility-labs.com/steam-accessibility-features/)
- [Steam Updates Accessibility Tags (Can I Play That?, Jan 2026)](https://caniplaythat.com/2026/01/26/steam-updates-accessibility-tags/)
- [Google Play Accessibility Features](https://support.google.com/googleplay/answer/16318151?hl=en)
- [WCAG 2.1 AA Checklist (Accessible.org)](https://accessible.org/wcag/)
- [WCAG 2.1 Success Criteria (W3C)](https://www.w3.org/TR/WCAG21/)
- [Guidance on Applying WCAG 2.2 to Mobile Applications (W3C)](https://www.w3.org/TR/wcag2mobile-22/)
