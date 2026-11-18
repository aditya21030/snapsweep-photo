# SnapSweep 🧹📸
### Smart, Privacy-First Android Gallery & Storage Cleaner

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Platform-Android%20(API%2024--36)-3DDC84?logo=android)](https://www.android.com)
[![Target SDK](https://img.shields.io/badge/Target%20SDK-36%20(Android%2016)-brightgreen)](https://developer.android.com)
[![Privacy](https://img.shields.io/badge/Media%20Analysis-100%25%20On--Device-success?logo=shield)](https://github.com/aditya21030/snapsweep-photo)
[![Tests](https://img.shields.io/badge/Tests-55%20Passing-success)](test/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**SnapSweep** is a high-performance, privacy-first gallery cleaner built specifically for Android. It intelligently identifies duplicate photos, compresses heavy 4K/HD videos, groups rapid burst sequences, auto-organizes media into AI categories, and purges hidden messaging clutter. 

All media analysis, computer vision, and cryptographic hashing run **strictly on-device**; personal photos and videos are never uploaded to any external server.

---

## 🌟 Core Highlights

| Feature | Description |
|---|---|
| **⚡ Instant Deletion** | Cleaned items are removed immediately without blocking popups or delay screens. |
| **👆 1-Tap Toggle** | Clean "Select all / Deselect" toggle headers replace cluttered dropdown menus. |
| **🔒 100% On-Device AI** | Google ML Kit OCR and vision models run offline in native Android threads. |
| **👯 Exact & Similar Duplicates** | 64-bit dHash perceptual analysis and MD5 verification ensure 0% false positives. |
| **👑 Burst Best Photo Picker** | Automatically calculates sharpness and flags the single best shot in a sequence. |
| **🗜️ 80% Video Compressor** | Hardware GPU video transcoding powered by AndroidX Jetpack Media3 Transformer. |
| **💬 WhatsApp & Social Purge** | Identifies redundant forwarded files in hidden `Sent` media directories. |
| **📱 Home Screen Widgets** | Material 3 launcher widgets with instant storage stats and deep-link cleaners. |
| **💳 In-App Billing** | Google Play one-time license (`snapsweep_remove_ads`) to remove ads permanently. |

---

## ✨ Comprehensive Feature Walkthrough

### 1. ⚡ Multi-Tier Scanning Pipeline
SnapSweep uses a staged scanning engine to process thousands of gallery photos in seconds without dropping UI frames:
- **Tier 1 - Metadata Discovery**: Fast content resolver queries MediaStore for instant count, sizes, and bucket mapping.
- **Tier 2 - Dimensional Pruning**: Bypasses heavy hashing on files with unique pixel dimensions.
- **Tier 3 - Pure-Isolate Cryptographic Matching**: Computes 64-bit difference hashes (`dHash`) and targeted MD5 checksums inside a dedicated background worker (`ScannerIsolate`).
- **Tier 4 - Native C++ Bitmap Inference**: Executes lightweight ML Kit image labeling and OCR text detection directly in Kotlin via `MediaClassifier.kt` with zero Dart bridge serialization overhead.

### 2. 👯 Exact Duplicates & Safe Smart Clean
- **Bit-for-Bit Accuracy**: Accurately groups duplicate images saved across separate albums (Camera, Downloads, WhatsApp, Cloud syncs).
- **Camera Authority Hierarchy**: Automatically protects the original high-resolution camera photo (`DCIM/Camera`) while pre-selecting downloaded duplicates for cleanup.
- **Android 11+ MediaStore Trash Support**: Uses system-native recoverable Trash on API 30+; falls back to permanent direct deletion on Android 10 and below with explicit confirmation dialogs.

### 3. 👑 Burst & Rapid Shot "Best Photo Selector"
- **Temporal Clustering**: Groups continuous photo captures taken within 2 to 4 seconds of each other with identical aspect ratios.
- **Laplacian Sharpness Scoring**: Evaluates edge clarity, focal sharpness, and resolution to automatically crown the sharpest photo with a **BEST SHOT** badge.
- **Keep Best, Clear Rest**: Selects inferior redundant shots with a single tap so users keep only the clearest memory.

### 4. 🗜️ GPU Video Compressor ("Compress & Save")
- **Hardware Acceleration**: Built on AndroidX Jetpack Media3 Transformer via `vidsqueeze` for GPU-accelerated H.264 and HEVC encoding.
- **3 Balanced Presets**:
  - **Balanced (Recommended)**: Capped at 1080p Full HD with optimized variable bitrate for ~65% storage savings.
  - **Maximum Space Saver**: Capped at 720p HD for up to ~80% size reduction, ideal for messaging and social sharing.
  - **Ultra HD Preserver**: Retains 1440p / 4K detail while pruning excessive raw camera bitrates.
- **In-App Side-by-Side Player**: Preview and compare the compressed result against the original before saving.
- **Auto-Purge Transcode Temp**: Immediately cleans temporary cache files after exporting to gallery.

### 5. ⏳ Temporary Screenshot Expiry Cleaner
- **Age-Based Segregation**: Automatically segments screenshots into actionable retention tiers:
  - **Over 30 Days Old** (Recommended for expired OTPs, QR codes, flight tickets, and order confirmations)
  - **Over 90 Days Old**
  - **Over 1 Year Old**
  - **All Screenshots**
- **One-Tap "Select Expired"**: Instantly selects obsolete screenshots for immediate bulk deletion.

### 6. 💬 WhatsApp & Social Media Purge
- **Hidden Sent Copy Detector**: Locates redundant duplicate files quietly created in `WhatsApp Images/Sent` and `WhatsApp Video/Sent`.
- **Token Boundary Recognition**: Matches directory structures accurately without false positives on filenames containing words like "present" or "sentence".
- **Category Segmentation**: Filter media across Sent Copies, Videos, Photos, or All Messaging Media.

### 7. 🃏 Swipe to Clean (Gesture Deck)
- **Tinder-Style Card Deck**: Smooth physics-based gestural cards with drag rotation and fling animations.
- **Gestures**:
  - **Swipe Left**: Queue for deletion.
  - **Swipe Right**: Keep photo.
  - **Swipe Up**: Skip card.
- **Scope Customization**: Filter the card deck by All Photos, This Month, Last Month, Screenshots, Social Media, or Blurry Photos.
- **Multi-Level Undo**: Instantly rewind previous swipes to revert accidental decisions.
- **Pre-Delete Summary**: Review queued items and total reclaimed bytes before executing final deletion.

### 8. ⏳ Storage Timeline Time Machine
- **Monthly Gallery Aggregation**: Groups all photos and videos chronologically month by month.
- **Peak Storage Spotlight**: Instantly flags heaviest months (e.g. holiday trips taking 15+ GB) with a direct **Clean Month** shortcut.
- **Capacity Heatbars**: Proportional visual capacity indicators displaying relative disk footprint per month.

### 9. 📱 Android Home Screen Widgets
- **Material 3 AppWidget**: Dark-themed widget layout (`snapsweep_widget.xml`) built with `home_widget`.
- **Live Health Monitor**: Displays real-time reclaimable junk size and total reviewable items directly on the launcher.
- **Cold-Start Deep Linking**: Launches directly into `/smart-clean` or `/swipe-clean` with buffered intent resolution across permission gates.

### 10. 🗂️ On-Device AI Categories
Automatically organizes photos into distinct, edge-to-edge preview cards:
1. **Screenshots** (Native Android screenshot detection)
2. **Screen Recordings** (Video capture heuristics)
3. **Social & WhatsApp** (Messaging media directories)
4. **Bills & Finance** (OCR keyword matching for receipts, invoices, tax documents)
5. **Documents & IDs** (Passports, driver licenses, PDF scans)
6. **Food & Dining** (Vision labeling for meals, dishes, restaurants)
7. **Personal & Portraits** (Camera roll portraits with face detection)
8. **Nature & Landscapes** (Mountains, lakes, sunsets, flora)
9. **Travel & Places** (Monuments, architecture, landmarks)
10. **Pets & Animals** (Dogs, cats, domestic animals)
11. **Large Videos** (Video files sorted by file size)

---

## 🎨 Design System: "Flat, Solid, Four Colors"

SnapSweep adheres to an editorial, typography-first aesthetic inspired by Swiss poster design:

### Palette Specification
- **Light Theme**:
  - **Ink** (`#12052D`): Primary text, contrast elements, dark badges.
  - **Violet** (`#6D2DF7`): Brand accent, primary action buttons, active indicators.
  - **Gold** (`#FCC80E`): Highlights, Best Shot crowns, hero callouts, alert badges.
  - **Lavender** (`#F6F5FC`): Primary clean background surface.
  - **Lilac** (`#ECE7FE`): Secondary card containers and selection chips.
- **Dark Theme**:
  - **Ink** (`#12052D`): Background base.
  - **Ink 2** (`#1D0C47`): Elevated card surfaces.
  - **Violet Deep** (`#5F1FEF`): Dark-mode primary button accent.
  - **Gold** (`#FCC80E`): High-contrast emphasis and hero indicators.

### Editorial Typography
- **Hero & Display**: `Bricolage Grotesque` (800 ExtraBold, tight letter-spacing) for metrics, counters, and hero headers (`display68`, `display48`, `title30`, `heading20`).
- **Body & Controls**: `DM Sans` (400 to 700 Weight) for clean, legible labels, captions, and action buttons (`body15`, `button15`, `meta13`, `caption11`).

---

## 🛠️ Tech Stack & Architecture

```
lib/
├── core/
│   ├── constants/       # AppColors, strings, legal copy
│   ├── services/        # AdService, BillingService, ScannerIsolate, WidgetService, AnalyticsService
│   ├── theme/           # AppTheme, AppTypography (Bricolage Grotesque & DM Sans)
│   └── utils/           # AppUtils (byte formatting, time calculations)
├── data/
│   └── services/        # MediaService (PhotoManager), CategorizationService (ML Kit OCR & Vision)
└── presentation/
    ├── common/          # FullscreenPhotoViewer, OnlineGate, UpdateGate, OperationResult
    ├── providers/       # ScanProvider (state & orchestrator), ThemeProvider
    └── screens/
        ├── burst/       # BurstCleanerScreen (Best Shot selector)
        ├── categories/  # CategoriesScreen, CategoryCleanerScreen
        ├── cleaner/     # SmartCleanPreviewScreen, MessagingCleanerScreen, ScreenshotCleanerScreen
        ├── compressor/  # MediaCompressorScreen (GPU hardware transcoding)
        ├── home/        # HomeScreen, CleanerTab, FloatingNavBar
        ├── permission/  # PermissionScreen (Scoped Storage Trust Gate)
        ├── preview/     # DuplicatePreviewScreen (Duplicates & Similar)
        ├── settings/    # SettingsScreen, RemoveAdsScreen, LegalScreen
        ├── splash/      # SplashScreen, SweepingSplashScreen
        ├── swipe/       # SwipeCleanerScreen (Gestural card deck)
        └── timeline/    # TimelineCleanerScreen (Monthly Time Machine)
```

- **Framework**: Flutter 3.x (Dart 3.x)
- **Android Target**: Android 16 (API Level 36), Min SDK 24 (Android 7.0+)
- **Video Transcoding**: AndroidX Jetpack Media3 Transformer via `vidsqueeze`
- **Native ML Inference**: `com.google.mlkit:image-labeling` and `com.google.mlkit:text-recognition`
- **State Management**: `provider` with granular `Selector` rebuild optimization
- **Routing**: `go_router` with declarative deep linking
- **Permissions**: Scoped Storage with `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10.8 or newer
- Android SDK Platform 36 (Android 16)
- Java Development Kit (JDK 17)

### Local Development Setup

```bash
# 1. Clone the repository
git clone https://github.com/aditya21030/snapsweep-photo.git
cd snapsweep-photo

# 2. Install Flutter packages
flutter pub get

# 3. Verify static analysis (0 warnings, 0 errors)
dart analyze

# 4. Execute test suite (55 automated tests)
flutter test

# 5. Run on connected Android device / emulator
flutter run
```

---

## 📦 Production Builds & Signing

SnapSweep includes an automated production build helper script ([`scripts/build-release.ps1`](file:///d:/Flutter/Snapsweep/scripts/build-release.ps1)) that handles temporary directory routing, verified AdMob parameters, and Gradle execution:

### 1. Configure Keystore Properties
Create `android/key.properties` (git-ignored) with your release signing credentials:
```properties
storeFile=../path/to/your/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

### 2. Build Release APK (for Direct Device Testing)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### 3. Build Release App Bundle (for Google Play Console)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -AppBundle
```
Output: `build\app\outputs\bundle\release\app-release.aab`

---

## 💰 Advertising & In-App Purchases

### Google AdMob Configuration
- **Application ID**: `ca-app-pub-8510502760785545~9932107864` (Configured in `AndroidManifest.xml`)
- **Interstitial Ad Unit ID**: `ca-app-pub-8510502760785545/8753913671`
- **Trigger Policy**: Interstitial ads display directly upon successful cleanup completion. A 5-second rapid-switch buffer prevents back-to-back ad fatigue.
- **Privacy & UMP**: Automatically presents the Google User Messaging Platform (UMP) consent form for users within the EEA/UK.

### Google Play In-App Purchase
- **Product ID**: `snapsweep_remove_ads` (Non-consumable one-time purchase)
- **Purchase Restoration**: Automatic restoration via Google Play Billing on reinstall or across devices.
- **Ad Suppression**: Activating the ad-free license immediately disables all interstitial ads and native banners permanently.

---

## 🔒 Privacy & Data Safety

- **Zero Cloud Uploads for Media**: Photo inspection, hashing, and category sorting run entirely on the user's phone processor.
- **No Account Required**: SnapSweep operates immediately upon installation without requiring personal registration or login credentials.
- **Permanent vs. Trashed**: Android 11+ moves deleted items to the system Trash for safe recovery. Android 10 and below uses permanent deletion after clear user confirmation.
- **Legal Documentation**: Complete Privacy Policy and Terms of Service are available in [`docs/privacy-policy.md`](file:///d:/Flutter/Snapsweep/docs/privacy-policy.md) and [`docs/terms-and-conditions.md`](file:///d:/Flutter/Snapsweep/docs/terms-and-conditions.md).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
