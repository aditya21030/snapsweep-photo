# SnapSweep 🧹📸
### Smart, Privacy-First Android Gallery & Storage Cleaner

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20Only-3DDC84?logo=android)](https://www.android.com)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20On--Device-success?logo=shield)](https://github.com/aditya21030/snapsweep-photo)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**SnapSweep** is an ultra-fast, privacy-first gallery cleaner engineered exclusively for Android. It eliminates duplicate clutter, compresses heavy 4K videos using native hardware encoding, sweeps burst shots to keep only the best pose, purges temporary expired screenshots, and clears redundant WhatsApp sent media. All processing occurs 100% offline on-device without telemetry or cloud uploads.

---

## ✨ Complete Feature Overview

### 1. ⚡ 3-Tier Scanning Pipeline (< 1.5s Execution)
- **Tier 1 - Zero-I/O Metadata Discovery**: Groups thousands of gallery items into smart categories in under 150 ms using pure MediaStore cursor metadata.
- **Tier 2 - Dimensional Pruning**: Assets with unique pixel dimensions bypass disk read operations entirely, eliminating ~95% of disk overhead.
- **Tier 3 - Pure-Isolate Cryptographic Verification**: Calculates 64-bit dHash and targeted MD5 hashes strictly on files with identical dimensions and byte length inside a dedicated background worker (`ScannerIsolate`).

---

### 2. 👯 Exact Duplicates & Safe Smart Clean
- **100% Bit-for-Bit Matching**: Groups identical copies saved across different folders (e.g. WhatsApp, Camera, Downloads).
- **Smart Authority Selection**: Automatically preserves the original high-resolution camera capture (`DCIM/Camera`) while pre-selecting redundant downloaded copies for deletion.
- **Native 30-Day Trash Recovery**: Deletion uses Android Scoped Storage Trash (`IS_TRASHED = 1`), allowing users to easily restore photos from the system gallery within 30 days.

---

### 3. 🃏 Swipe to Clean (Interactive Card Deck)
- **Tinder-Style Gestural Deck**: Smooth 120 FPS card physics with drag resistance, rotation tilt, and velocity-based fling animations.
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
- **Keep Best, Trash Rest**: Automatically pre-selects inferior and closed-eye shots for removal while locking the crowned winner.
- **1-Tap Purge**: Batch moves redundant burst shots to Trash with a single tap.

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
- **Native Android Jetpack Media3 Transformer**: Hardware-accelerated GPU/NPU transcoding powered by `vidsqueeze` (H.264 / HEVC) with zero device overheating.
- **3 Quality Presets**:
  - **Balanced (Recommended)**: Capped at 1080p Full HD with optimized bitrate for ~65% storage savings.
  - **Maximum Space Saver**: Capped at 720p HD for up to ~80% reduction, perfect for sharing.
  - **Ultra HD Preserver**: Retains 1440p / 4K detail while optimizing heavy bitrates.
- **Live Side-by-Side Video Preview**: Integrated in-app video player to preview and compare the compressed result before finalizing.
- **Safe Replacement Workflow**: Automatically saves the compressed video to the device gallery and safely moves the original file to Trash only when storage savings are verified.
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

- **100% Offline Processing**: All hashing, ML classification, and thumbnail processing happen strictly on your device.
- **No Cloud Uploads**: Photos, videos, and filenames are never transmitted to any external server.
- **No Account Required**: Use immediately with zero sign-ups or telemetry tracking.
- **Safe Trash Deletion**: All deletions invoke Android's native `deleteWithIds` Scoped Storage Trash API, guaranteeing items can be recovered within 30 days.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/       # AppColors, strings, legal policies
│   ├── services/        # ScannerIsolate (dHash, MD5, blur), WidgetService, AdService, BillingService
│   ├── theme/           # Material 3 light/dark themes & Outfit typography
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

To compile release APKs:

```bash
# Universal Release APK
flutter build apk --release

# Architecture-Optimized Release APKs (Split-per-ABI)
flutter build apk --split-per-abi --release
```

To sign with Android APK Signature Schemes v2 and v3:

```bash
apksigner sign --ks android/app/upload-keystore.jks --ks-pass pass:android --key-pass pass:android --ks-key-alias upload build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
