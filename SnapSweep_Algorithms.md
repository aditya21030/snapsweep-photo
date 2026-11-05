# SnapSweep: Algorithm Review

Reviewed from the repo code (`scanner_isolate.dart`, `categorization_service.dart`, `scan_provider.dart`, compressor and screenshot screens). Timeline, swipe and widget code was not read, so those rows are general best practice.

## Per-feature table

| Feature | Current in code | Best practice | Upgrade? |
|---|---|---|---|
| Exact duplicates | Sparse MD5 (16KB head + mid + tail + length) | Size → sparse hash → full hash only on collisions. xxHash/BLAKE3 for speed. | **Yes.** Sparse MD5 can match files that differ only outside the sampled bytes. Add a full-hash confirm on matches only. |
| Visually similar | 128-bit dual-axis dHash (9×9) + Hamming ≤16, inside burst clusters | pHash (DCT) or 16×16 dHash, BK-tree or bit-sampling LSH lookup, union-find grouping | **Yes.** The hash runs on a 64px thumbnail, which is coarse. Use 128–256px. Replace greedy grouping with union-find at Hamming ≤10–12 so chains (A≈B, B≈C, A≉C) don't merge. |
| Cross-resolution copies (WhatsApp, forwards) | Hamming ≤2 with aspect-ratio buckets (±0.035) | Same hash plus an aspect-ratio gate | **Keep.** |
| Burst grouping | Camera shots ≤4s apart, aspect ratio within 0.08, timestamp order | Same, plus MediaStore burst/sequence IDs when present | **Minor.** Adaptive 2–4s window. |
| Blur detection | Center-weighted Laplacian variance (blurry if <85), dynamic-range guard (<35), motion-vs-focus ratio >3 | Laplacian variance or Tenengrad on a normalised ~512px image, plus an FFT high-frequency ratio | **Yes, biggest accuracy gain.** Laplacian variance depends on resolution, so the 85 threshold is unreliable at 64px. Compute on ≥384–512px. Keep 64px only as a cheap pre-filter. |
| Best-shot keeper | Not blurry → sharpness → folder authority → resolution → file size → earliest date | Sharpness + exposure + face quality (eyes open, smile) + resolution | **Yes.** Add ML Kit face detection and an exposure/histogram-clipping check. |
| Categorization | Tiered: metadata/keywords → ML Kit labels (confidence ≥0.35) → OCR + regex (currency, Aadhaar/PAN/DL, meme slang) → aspect-ratio fallback | Same tiered approach: cheap tiers first, ML only on unresolved items, cached | **Keep.** Add a persistent cache keyed by asset ID + modified time. Raise the label threshold to about 0.5 for destructive actions. |
| Screenshots / expiry | Age filters (7/30/60/90 days), path and aspect-ratio detection | Age filter plus OCR keyword scoring (OTP, ticket, receipt, order confirmation) | **Optional.** Auto-select likely expired items, user confirms. |
| Large videos | Size-sorted list | Rank by size, then bitrate (size/duration), then resolution | **Minor.** Bitrate shows which videos shrink most. |
| Video compressor | vidsqueeze presets: 720p (~80% saving), 1080p (~65%), 1440p HEVC | Hardware MediaCodec, HEVC where supported, bitrate target per preset, skip files already under target | **Keep.** Add a skip check so small videos aren't re-encoded. |
| Swipe / trash / restore | Trash with 30-day restore | Soft delete with a manifest, purge after the window | **Keep.** |

## Priority order

1. Raise the thumbnail from 64px to about 256px for both dHash and blur. This gives the biggest accuracy gain for modest cost.
2. Full-hash confirmation on exact-duplicate matches, so exact matches are certain before deletion.
3. Union-find grouping at Hamming ≤10–12, plus LSH or BK-tree lookup for large galleries (pairwise comparison inside a cluster is O(n²)).
4. Face and exposure scoring in best-shot ranking.

## Key thresholds in the code today

- Exact duplicate: sparse MD5, 3 × 16KB samples + length
- Cross-resolution replica: Hamming ≤2, aspect-ratio ±0.035
- Similar/burst: Hamming ≤16, 4s window, aspect-ratio ±0.08
- Blur: variance <85, dynamic range <35 treated as flat, sharpness score = min(100, variance/3)
- ML Kit label confidence: ≥0.35
