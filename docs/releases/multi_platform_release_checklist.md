# Multi-Platform Release Checklist

## 1. Overview

This document is the master checklist for the technical process of packaging, uploading, and releasing the game on each target platform. Follow these steps carefully for each release to ensure a smooth launch.

--- 

## 2. Pre-Release: Universal Steps

-   [ ] **Final Build Compilation**: Compile the final, release-ready version of the game using the `build.gd` script.
-   [ ] **Versioning**: Ensure the game's version number (e.g., `v1.0.0`) is correctly set in `project.godot` and matches the intended release version.
-   [ ] **Testing**: Complete a final smoke test on the release build on all target platforms.
-   [ ] **Store Assets**: Confirm all assets from the `storefront_asset_checklist.md` are finalized and ready for upload.
-   [ ] **Privacy Policy**: Ensure the `privacy_policy.md` is finalized and hosted at a public URL.

--- 

## 3. Steam (PC/Mac/Linux) Release Process

-   **Reference**: [Steamworks Documentation](https://partner.steamgames.com/doc)

### 3.1. Initial Setup (First time only)
-   [ ] Complete Steamworks developer registration and pay app fee.
-   [ ] Create the main AppID for the game.
-   [ ] Create a separate DLC AppID for the "Compendium DLC".
-   [ ] Configure Depots for each platform (Windows, Mac, Linux).
-   [ ] Install the Steamworks SDK.

### 3.2. For Each Release
-   [ ] **Build Upload**: Use `SteamPipe` GUI or CLI to upload the builds to their respective depots.
-   [ ] **Set Launch Options**: Configure the executable paths for each platform in the Steamworks dashboard.
-   [ ] **Update Store Page**: Upload all capsules, screenshots, and descriptions. Set the release date.
-   [ ] **DLC Configuration**: Link the DLC AppID to the main game. Set its price and configure its store page.
-   [ ] **Submit for Review**: Submit the game and store page for review by Valve. This can take several days.
-   [ ] **Press "Release"**: Once approved, the "Release" button will become available on the set release date.

--- 

## 4. Google Play Store (Android) Release Process

-   **Reference**: [Google Play Console Help](https://support.google.com/googleplay/android-developer)

### 4.1. Initial Setup (First time only)
-   [ ] Register for a Google Play Developer account and pay the fee.
-   [ ] Create a new app in the Google Play Console.
-   [ ] Complete the "App content" section, including the content rating questionnaire and privacy policy link.
-   [ ] Set up an In-App Product for the "Compendium DLC".

### 4.2. For Each Release
-   [ ] **Generate Keystore**: Create a private signing key for your app. **DO NOT LOSE THIS KEY.**
-   [ ] **Configure Godot Export**: In Godot's Android export preset, enter the signing key details.
-   [ ] **Export AAB**: Export the project as an Android App Bundle (`.aab`).
-   [ ] **Create a New Release**: In the Play Console, go to the "Production" track and create a new release.
-   [ ] **Upload AAB**: Upload the signed `.aab` file.
-   [ ] **Enter Release Notes**: Add release notes for the new version.
-   [ ] **Update Store Listing**: Upload all required icons, graphics, and screenshots.
-   [ ] **Rollout**: Submit the release for review. Once approved, you can publish it to 100% of users.

--- 

## 5. Apple App Store (iOS) Release Process

-   **Reference**: [Apple Developer Documentation](https://developer.apple.com/documentation/)

### 5.1. Initial Setup (First time only)
-   [ ] Enroll in the Apple Developer Program (annual fee required).
-   [ ] Create an App ID in the Developer portal.
-   [ ] Create Provisioning Profiles and Certificates for development and distribution.
-   [ ] Create an app record in App Store Connect.
-   [ ] Set up an In-App Purchase for the "Compendium DLC".

### 5.2. For Each Release
-   [ ] **Configure Godot Export**: In Godot's iOS export preset, enter the App ID and signing certificate information.
-   [ ] **Export Xcode Project**: Export the project from Godot, which creates an Xcode project.
-   [ ] **Open in Xcode**: Open the project on a macOS device with Xcode installed.
-   [ ] **Configure Project**: Set the version number, build number, and sign the app with your distribution certificate.
-   [ ] **Archive Build**: Use the "Archive" function in Xcode.
-   [ ] **Upload to App Store Connect**: From the Organizer window in Xcode, validate and upload the archived build.
-   [ ] **TestFlight (Recommended)**: Distribute the build to internal or external testers via TestFlight to catch any final issues.
-   [ ] **Submit for Review**: In App Store Connect, select the uploaded build and submit it for review. This is the longest review process, often taking several days to a week.
-   [ ] **Release**: Once approved, you can manually release it or have it automatically release on a set date.
