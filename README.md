# SnapSweep 🧹📸
### Smart, Privacy-First Android Gallery & Storage Cleaner

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20Only-3DDC84?logo=android)](https://www.android.com)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20On--Device-success?logo=shield)](https://github.com/aditya21030/snapsweep-photo)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**SnapSweep** is a high-performance, privacy-first gallery cleaner engineered exclusively for Android. It detects byte-for-byte exact duplicates, groups visual burst shots, flags blurry camera photos, finds massive videos, and organizes media into 8 practical categories—all in under 1.5 seconds without ever uploading a single byte to the cloud.

---

## ✨ Key Features

### ⚡ Ultra-Fast 3-Tier Scanning Pipeline
* **Instant Category Discovery (< 150 ms)**: Groups thousands of photos into 8 smart categories instantly using zero-I/O metadata inspection.
* **Dimensional Pruning**: Photos with unique pixel dimensions bypass disk I/O entirely (eliminating ~95% of unnecessary storage reads).
* **Parallel Targeted Verification**: Computes cryptographic MD5 hashes only on files sharing both identical pixel dimensions and identical byte length.

### 👯 Exact Duplicates & Safe Smart Clean
* **100% Bit-for-Bit Matching**: Groups identical copies saved in multiple albums (e.g. WhatsApp, Camera, Downloads).
* **Auto-Select Extra Copies**: Keeps the best original resolution copy while safely pre-selecting extra redundant copies for cleanup.
* **30-Day Trash Recovery**: Media is safely sent to Android's native Trash / Recently Deleted folder, allowing full recovery within 30 days.

### 📸 Burst & Similar Photos Review
* **Temporal Clustering**: Groups consecutive shots taken within 45 seconds with matching aspect ratio (burst mode, multiple poses, selfies).
* **64-bit dHash Engine**: Compares visual similarity using perceptual hashing within isolated background Dart threads (`ScannerIsolate`).
* **Never Auto-Deleted**: Similar photos are flagged for user review only; you always decide which shots to keep.

### 🔍 Focused Blurry Photo Detector
* **Laplacian Variance Algorithm**: Evaluates camera roll shots using normalized grayscale variance (`variance < 80.0`) to catch shaky, out-of-focus captures.
* **Targeted Camera Filter**: Ignores screenshots and digital graphics to prevent false positives.

### 🎥 Large Videos Cleaner
* **Direct MediaStore Discovery**: Surfaces space-hogging 4K/1080p video recordings and WhatsApp video forwards in parallel batches of 15.

### 🗂️ 8 Smart Media Categories
1. **Screenshots** (DCIM/Screenshots, Screen capture patterns)
2. **Social & WhatsApp** (WhatsApp Images, Telegram, Instagram)
3. **Bills & Finance** (Invoices, receipts, statement captures)
4. **Documents & IDs** (Documents, cards, forms)
5. **Food & Dining** (Food photos, menus)
6. **Memes & Downloads** (Download folder, humor graphics)
7. **Personal & Portraits** (Camera roll portraits)
8. **Others** (General gallery items)

### 🔬 Interactive Fullscreen Photo Inspector
* **Pinch-to-Zoom (0.8x to 5.0x)**: Inspect facial smiles, sharpness, and details at full resolution before confirming deletion.
* **EXIF Metadata Banner**: View pixel dimensions, capture timestamp, and file size at a glance.
* **Dedicated Selection Badges**: Tap anywhere to zoom; tap the corner circle to toggle selection with tactile haptic feedback.

### 📳 Tactile Haptic Engine
* Integrated micro-haptics across all interactions:
  * `selectionClick()` on every photo toggle, tab switch, and scope chip.
  * `lightImpact()` on Select All / Deselect All.
  * `mediumImpact()` on moving items to Trash.

---

## 🔒 Privacy & Safety Guarantee

* **100% Offline Processing**: All hashing, ML classification, and thumbnail processing happen strictly on your device.
* **No Cloud Uploads**: Photos, videos, and filenames are never transmitted to any external server.
* **No Account Required**: Use immediately with zero sign-ups or telemetry tracking.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/       # Colors, strings, legal policies
│   ├── services/        # ScannerIsolate (dHash, MD5, Laplacian blur), AdService
│   ├── theme/           # Material 3 light/dark themes & Outfit typography
│   └── utils/           # Byte formatting, date helpers
├── data/
│   └── services/        # MediaService (PhotoManager), CategorizationService (ML Kit + metadata)
└── presentation/
    ├── common/          # FullscreenPhotoViewer, DashboardCard
    ├── providers/       # ScanProvider, ThemeProvider
    └── screens/
        ├── cleaner/     # SmartCleanPreviewScreen
        ├── categories/  # CategoriesScreen, CategoryCleanerScreen
        ├── home/        # HomeScreen, CleanerTab, FloatingNavBar
        ├── permission/  # PermissionScreen (Trust Gate)
        ├── preview/     # DuplicatePreviewScreen (Duplicates & Similar)
        ├── settings/    # SettingsScreen, LegalScreen
        └── splash/      # SplashScreen, SweepingSplashScreen
```

* **Framework**: Flutter 3.x (Dart 3.x)
* **Target**: Android (API 24 to API 35+)
* **State Management**: `provider` (Selector & Consumer fine-grained rebuilds)
* **Navigation**: `go_router` (Type-safe declarative routing)
* **Storage Access**: `photo_manager` with scoped storage permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`)
* **Computer Vision**: Pure-isolate `image` processing + `google_mlkit_text_recognition` / `google_mlkit_image_labeling`

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.10.8 or newer)
* Android Studio / Android SDK (API 34+)
* Java 17+

### Installation & Run

```bash
# Clone the repository
git clone https://github.com/aditya21030/snapsweep-photo.git
cd snapsweep-photo

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run on connected Android device
flutter run
```

### Release APK Build (Split-per-ABI)

To produce optimized, lightweight APKs:

```bash
flutter build apk --release --split-per-abi
```

Generated APKs will be located at:
* **ARM64-v8a**: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~54 MB)
* **ARMv7a**: `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (~44 MB)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
