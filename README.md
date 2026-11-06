# SnapSweep 🧹📸
### Smart, Privacy-First Android Gallery & Storage Cleaner

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20Only-3DDC84?logo=android)](https://www.android.com)
[![Privacy](https://img.shields.io/badge/Media%20Analysis-On--Device-success?logo=shield)](https://github.com/aditya21030/snapsweep-photo)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**SnapSweep** is a gallery cleaner for Android. It finds duplicate clutter, compresses videos, groups burst shots, and helps review screenshots and messaging media. Photo and video analysis runs on-device without uploading gallery content. Ads and Google Play Billing use network services.

---

## ✨ Complete Feature Overview

### 1. ⚡ Staged Scanning Pipeline
- **Tier 1 - Metadata Discovery**: Reads MediaStore metadata to organize gallery items into categories.
- **Tier 2 - Dimensional Pruning**: Assets with unique pixel dimensions bypass duplicate file reads.
- **Tier 3 - Pure-Isolate Cryptographic Verification**: Calculates 64-bit dHash and targeted MD5 hashes strictly on files with identical dimensions and byte length inside a dedicated background worker (`ScannerIsolate`).

---

### 2. 🎨 "Flat, Solid, Four Colors" Design System (Light & Dark)
- **Solid 4-Color Palette**: Ink (`#12052D`), Violet (`#6D2DF7`), Gold (`#FCC80E`), and Lavender (`#F6F5FC`) in Light Mode; Ink (`#12052D`), Ink 2 (`#1D0C47`), Violet Deep (`#5F1FEF`), and Gold (`#FCC80E`) in Dark Mode.
- **Editorial Typography Scale**:
  - `Bricolage Grotesque` (800 Weight, tight tracking) for bold numbers, metrics, hero headers, and titles (`display68`, `display48`, `title30`, `heading20`).
  - `DM Sans` (400 to 700 Weight) for clean legible metadata, labels, captions, and action buttons (`body15`, `button15`, `meta13`, `caption11`).
- **Floating Island Navigation**: Floating pill navigation bar with active solid Gold pill (`#FCC80E`) and dark Ink text/icons across Cleaner, Swipe, Categories, and Settings.
- **Flat Elevation System**: Zero artificial drop-shadows or gradients; pure solid hierarchy guided by color proportion (Lavender 45%, Ink 25%, Violet 20%, Gold 10%).

---

### 2. 👯 Exact Duplicates & Safe Smart Clean
- **100% Bit-for-Bit Matching**: Groups identical copies saved across different folders (e.g. WhatsApp, Camera, Downloads).
- **Smart Authority Selection**: Automatically preserves the original high-resolution camera capture (`DCIM/Camera`) while pre-selecting redundant downloaded copies for deletion.
- **Recoverable removal on Android 11+**: Media is moved to Android's system Trash and can be restored while the system retains it. On Android 10 and older, removal is permanent and the confirmation dialog says so.

---

### 3. 🃏 Swipe to Clean (Interactive Card Deck)
- **Gesture Deck**: Swipe cards with drag resistance, rotation, and fling animations.
- **Intuitive Actions**:
  - **Swipe Left**: Queue for Trash.
  - **Swipe Right**: Keep photo.
  - **Swipe Up**: Skip card.
- **Scope Filters**: Switch between All Photos, This Month, Last Month, Screenshots, Social & WhatsApp, and Blurry Photos.
- **Multi-Level Undo History**: Instantly undo previous card swipes to revert mistakes.
- **Batch Review Bottom Sheet**: Review queued trash items with total reclaimed megabytes before confirming deletion.

---

### 4. 👑 Burst & Rapid Shot "Best Photo Selector"
- **Temporal Clustering**: Groups sequences of photos captured within 2 to 4 seconds of each other with matching aspect ratios (selfies, action shots, group poses).
- **Automated Quality Scoring**: Analyzes sharpness, resolution, and capture authority to automatically crown the sharpest photo with a golden **BEST SHOT** badge.
- **Keep Best, Review Rest**: Ranks burst shots and lets users review the remaining photos for removal.
- **Batch Removal**: Moves selected burst shots to Trash on Android 11+; older Android versions permanently delete them after confirmation.

---

### 5. ⏳ "Temporary Media" Screenshot Expiry Cleaner
- **Age Expiry Buckets**: Automatically segments screenshots by age:
  - **> 30 Days Old** (Recommended cleanup for OTPs, boarding passes, and receipts)
  - **> 60 Days Old**
  - **> 90 Days Old**
  - **> 1 Year Old**
  - **All Screenshots**
- **Expired Reclaim Highlight**: Computes exact megabytes consumed by obsolete screenshots.
- **One-Tap "Select Expired"**: Instantly flags all stale screenshots for fast disposal with a persistent review bar.

---

### 6. 🗜️ Video Compressor ("Compress & Save")
- **Native Android Jetpack Media3 Transformer**: Video transcoding through `vidsqueeze` with H.264 and HEVC support.
- **3 Quality Presets**:
  - **Balanced (Recommended)**: Capped at 1080p Full HD with optimized bitrate for ~65% storage savings.
  - **Maximum Space Saver**: Capped at 720p HD for up to ~80% reduction, perfect for sharing.
  - **Ultra HD Preserver**: Retains 1440p / 4K detail while optimizing heavy bitrates.
- **Live Side-by-Side Video Preview**: Integrated in-app video player to preview and compare the compressed result before finalizing.
- **Safe Replacement Workflow**: Saves a smaller compressed copy before removing the original, if the user enables that option. Android 11+ moves the original to Trash; older versions permanently delete it.
- **App Cache Leakage Cleanup**: Automatically purges temporary transcoding files from internal app storage immediately after saving.

---

### 7. 💬 WhatsApp & Messaging Deep Cleaner
- **Redundant Sent Copies Purge**: Detects hidden duplicate copies automatically created by WhatsApp and Telegram in `WhatsApp Images/Sent` and `WhatsApp Video/Sent`.
- **Targeted Sub-Filters**: Filter messaging files by Sent Copies, Videos, Photos, or All Media.
- **Folder Token Boundary Matching**: Accurately detects sent directories without false-positive matching on filenames (e.g. `presentation.jpg` or `present.jpg`).
- **Quick Clean Sent Recommendation**: Single-tap hero action to safely reclaim sent copies in one step.

---

### 8. ⏳ Storage Timeline "Time Machine"
- **Chronological Storage History**: Aggregates all gallery photos and videos month by month (e.g. October 2024, September 2024).
- **Heaviest Month Spotlight**: Automatically identifies peak storage consumption months (e.g. vacations or events taking 15+ GB) with a direct **Clean Month** action.
- **Visual Capacity Heatbars**: Proportional progress bars displaying relative disk consumption per month with live thumbnail previews.

---

### 9. 📱 Android Home Screen Widget
- **Material 3 AppWidget**: Adaptive dark-themed widget layout (`snapsweep_widget.xml`) powered by `home_widget`.
- **Live Storage Health**: Displays real-time reclaimable junk size and total items to review directly on the home screen.
- **One-Tap Quick Actions**:
  - **Quick Clean** button: Launches directly into `/smart-clean`.
  - **Swipe** button: Launches directly into `/swipe-clean`.
- **Cold-Start Deep Link Handler**: Safely buffers widget click intents across cold app launches until permissions and home navigation are initialized.

---

### 10. 🔍 Focused Blurry Photo Detector
- **Laplacian Variance Algorithm**: Evaluates camera roll shots using normalized grayscale variance (`variance < 80.0`) to catch shaky, out-of-focus captures.
- **Targeted Camera Filter**: Ignores screenshots and digital graphics to prevent false blur positives.

---

### 11. 🗂️ 8 Smart Media Categories
1. **Screenshots** (Authoritative Android Screenshots bucket and screen aspect ratio heuristics)
2. **Social & WhatsApp** (WhatsApp Images, WhatsApp Video, Telegram, Instagram)
3. **Bills & Finance** (Invoices, receipts, financial document keywords)
4. **Documents & IDs** (PDFs, docs, ID cards, forms)
5. **Food & Dining** (Food photos, dining captures)
6. **Memes & Downloads** (Download bucket, humor graphics)
7. **Personal & Portraits** (Camera roll portraits)
8. **Large Videos** (Space-hogging 4K/1080p video recordings sorted by size)

---

### 12. 🔬 Interactive Fullscreen Inspector
- **Pinch-to-Zoom (0.8x to 5.0x)**: Full-resolution image inspection with smooth double-tap zoom.
- **Integrated Video Player**: In-viewer video playback with play/pause, seek (+/- 5s), volume mute toggle, and position timeline.
- **Direct Video Compression**: One-tap "Compress Video" button in the top action bar to immediately shrink any video.
- **EXIF Metadata Banner**: View pixel dimensions, capture date/time, and file size at a glance.

---

### 13. 💳 Google Play In-App Billing
- **Permanent Ad-Free License**: Official Google Play Billing integration (`snapsweep_remove_ads`) allowing users to permanently remove ads.
- **Instant Purchase Restoration**: One-tap purchase restoration synchronized with Google Play services across devices.
- **Smart Ad Suppression**: When premium license is active, all interstitial ads are disabled throughout the app.

---

### 14. 📳 Tactile Haptic Engine
- Micro-haptics across all interactions:
  - `selectionClick()` on every photo toggle, tab switch, and scope chip.
  - `lightImpact()` on Select All / Deselect All.
  - `mediumImpact()` on moving items to Trash.
  - `heavyImpact()` on video compression completion.

---

## 🔒 Privacy & Safety Guarantee

- **On-device media processing**: Hashing, ML classification, and thumbnail processing happen on your device.
- **No gallery uploads for analysis**: The scanner and compressor process gallery files on-device.
- **No SnapSweep account required**: Use the cleaner without creating an app account.
- **Removal behavior**: Android 11+ uses MediaStore Trash. Android 10 and older use permanent deletion because system Trash is unavailable; the app shows the applicable action before removal.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/       # AppColors, strings, legal policies
│   ├── services/        # ScannerIsolate (dHash, MD5, blur), WidgetService, AdService, BillingService
│   ├── theme/           # Solid 4-color themes & Bricolage Grotesque / DM Sans typography
│   └── utils/           # AppUtils (byte formatting, date helpers)
├── data/
│   └── services/        # MediaService (PhotoManager), CategorizationService (ML Kit + metadata)
└── presentation/
    ├── common/          # FullscreenPhotoViewer, DashboardCard, CategoryCard
    ├── providers/       # ScanProvider, ThemeProvider
    └── screens/
        ├── burst/       # BurstCleanerScreen (Best Shot Selector)
        ├── categories/  # CategoriesScreen, CategoryCleanerScreen
        ├── cleaner/     # SmartCleanPreviewScreen, MessagingCleanerScreen, ScreenshotCleanerScreen
        ├── compressor/  # MediaCompressorScreen (Media3 hardware transcoding)
        ├── home/        # HomeScreen, CleanerTab, FloatingNavBar
        ├── permission/  # PermissionScreen (Scoped Storage Trust Gate)
        ├── preview/     # DuplicatePreviewScreen (Duplicates & Similar)
        ├── settings/    # SettingsScreen, LegalScreen
        ├── splash/      # SplashScreen, SweepingSplashScreen
        ├── swipe/       # SwipeCleanerScreen (Gestural card deck)
        └── timeline/    # TimelineCleanerScreen (Monthly Time Machine)
```

- **Framework**: Flutter 3.x (Dart 3.x)
- **Target**: Android (API 24 to API 35+)
- **Video Transcoding**: `vidsqueeze` (AndroidX Jetpack Media3 Transformer)
- **Home Screen Widget**: `home_widget` (Native Android AppWidgetProvider)
- **State Management**: `provider` (Selector & Consumer fine-grained rebuilds)
- **Navigation**: `go_router` (Type-safe declarative routing with widget deep linking)
- **Storage Access**: `photo_manager` with scoped storage permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`)
- **Computer Vision**: Pure-isolate `image` processing + `google_mlkit_text_recognition` / `google_mlkit_image_labeling`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10.8 or newer)
- Android Studio / Android SDK (API 34+)
- Java 17+

### Installation & Run

```bash
# Clone the repository
git clone https://github.com/aditya21030/snapsweep-photo.git
cd snapsweep-photo

# Install dependencies
flutter pub get

# Run static analysis (0 warnings, 0 errors)
flutter analyze

# Run on connected Android device
flutter run
```

### Production Release Build & Signing

Set up an ignored `android/key.properties` file with `keyAlias`, `keyPassword`, `storeFile`, and `storePassword` before making a signed release build. Debug builds do not require release signing properties. Then build and verify the APK:

```bash
# Universal Release APK
flutter build apk --release

# Architecture-optimized release APKs
flutter build apk --split-per-abi --release

# Verify the Gradle-signed APK
apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## Advertising configuration

Android's AdMob application ID is configured in `android/app/src/main/AndroidManifest.xml`.
The confirmed production interstitial unit is `ca-app-pub-9787505657189806/2924077899` and is the default for release builds. The native placement remains disabled until its separate unit is supplied. To override units:

```powershell
.\scripts\build-release.ps1 -InterstitialAdUnitId YOUR_INTERSTITIAL_UNIT_ID -NativeAdUnitId YOUR_NATIVE_UNIT_ID
```

Debug/profile builds use Google's official test units. Release placements without a configured unit ID stay disabled. Native and interstitial placements require different unit IDs.

A native template appears below dashboard tools when loaded and permitted. Cleanup and compression completion flows use a shared result dialog. Only Continue can show a preloaded interstitial. One shared policy permits at most one completion interstitial per process session and persists a three-minute cooldown across restarts. If no ad is ready, continuation is immediate. Ad-free purchases bypass ads. UMP refreshes consent, ad requests wait for `canRequestAds`, and required privacy options are available in Settings. Publish the appropriate consent messages in AdMob Privacy & messaging before distributing advertising builds.

The in-app policies are also available in `docs/privacy-policy.md` and `docs/terms-and-conditions.md` for publication. Hosting these documents and updating the Google Play policy URL/Data safety declarations are separate publishing steps.

The release helper keeps temporary build files on the project drive, uses the configured release signing, and restores the calling shell environment afterwards. Gradle uses a single worker and in-process Kotlin compilation for memory-constrained machines.

## Remove Ads purchase and required updates

The single non-consumable product is `snapsweep_remove_ads`, with the `buy-once` Buy purchase option in Play Console. The intended India price is INR 149 once. The purchase page displays the localized price returned by Google Play, never a hard-coded charge. Activate the product/purchase option and enable the buyer's country in Play Console. Pending, cancelled and failed payments do not unlock Remove Ads. Owned purchases are restored through Google Play and acknowledged after a successful ownership query. Refunded/revoked ownership is reconciled on resume. The implementation uses the on-device Play Billing ownership query; it does not claim server-side verification. A secure verification backend remains future work.

The Remove Ads page is available from Settings. It includes checkout, purchase status, restore, terms and privacy links. Only advertising is sold; no other cleaner feature is advertised as premium.

Android release builds check Google Play updates in the background at startup, on resume and every five minutes while foregrounded. Only an available version strictly newer than the installed version blocks access for free and ad-free users. The update page has Update now, Open Google Play and Check again, with no skip action. Immediate updates use Play's native flow. Cancel/failure does not unlock the app. A confirmed newer version is remembered until that version or newer is installed, or Play definitively reports no update. Old markers are cleared immediately after reading the installed version, before checking Play. Failed/unknown checks allow access unless a previously confirmed version is still newer than the installed version. Debug/profile builds bypass the gate for development. No Play Console or backend minimum-version service is configured.

**Distribution:** A directly sideloaded APK opens normally when Play update checks are unavailable. Current/newer APKs do not prompt based on stale or same-version Play responses. Play ownership/update support is needed for the actual in-app installation flow. Updates must actually be available to the user's Play account, country, device and release track. This change cannot enforce updates in old app versions that do not contain the gate.

Build the Play Console bundle with `./scripts/build-release.ps1 -AppBundle`. Use `./scripts/build-release.ps1` for a signed APK. Both include the confirmed production interstitial unit by default; the native unit remains unconfigured.

Before production, upload the bundle to Internal testing and add the buyer account to Settings > License testing. Install using the Play opt-in link. Test successful purchase, cancellation, pending payment, restore after reinstall, refund/revocation and no duplicate checkout. For updates, install a gate-enabled Play build, then publish a higher version code to the same eligible test track (or use Google's internal app sharing update test workflow). Check cancellation, offline retry, app restart and final install. Local automated tests mock store/update channels and do not replace these device tests.

## Durable gallery scan checkpoints

Completed results now contain the gallery catalog and its matching analysis/category cache in one atomic snapshot. Reopening a completed scan restores both without enumerating or classifying the gallery again; use Refresh to discover gallery changes. Existing legacy snapshots remain readable without resetting the analysis version.

Before a new scan processes images, it saves a resumable catalog. Each batch appends a small, flushed journal record containing its completed hashes, category decisions and sizes. An interrupted scan restores the snapshot plus journal and resumes unfinished work. Fresh MediaStore metadata and sizes invalidate edited files before cached analysis is reused. Restarting may repeat an in-flight batch that was not durably saved, and final group assembly can run again. A torn final journal record is ignored; a completed snapshot supersedes and compacts the journal. Background category refinement uses the same checkpoints.

The Remove Ads page follows the supplied light/dark references, including a scalable gallery/ad illustration, a single benefits card, one-time store pricing, restore and legal links. The light action is violet and the dark action is gold. Prices always come from Google Play. Rendered QA previews are in `build/ui-review`.
