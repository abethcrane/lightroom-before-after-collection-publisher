# Before & After Export — Lightroom Classic Plugin

Exports two versions of each selected photo:

- **After** — the current edited version
- **Before** — same crop/rotation/geometry but with all tonal/color edits reset to defaults

This matches what Lightroom shows in its Before/After view (in the common case of no import presets).

## Requirements

- Lightroom Classic v6+ (SDK 5.0+)
- Tested on Lightroom Classic 14–15
- **Required:** develop preset **Reset For Before** (included in `presets/` at repo root)

## Install

Install the develop preset first, then the plugin. See the [root README](../README.md) for full paths on macOS and Windows.

1. Import `presets/Reset For Before.xmp` via Develop → Presets → Import
2. Add `before-and-after.lrdevplugin/` via File → Plug-in Manager → Add
3. Reload the plugin or restart Lightroom

## Usage

1. Select one or more photos in the Library module
2. Go to **File > Plug-in Extras > Export Before & After**
3. Configure output settings (destination, format, quality, suffixes)
4. Click **Export**

For each photo `IMG_1234.CR3`, you'll get:
- `IMG_1234-after.jpg` — full edit
- `IMG_1234-before.jpg` — geometry only, defaults for everything else

## What "Before" Means

The "before" version preserves:

- **Crop & rotation** (CropTop/Bottom/Left/Right/Angle)
- **Orientation**
- **Lens corrections** (profile-based distortion, CA, vignette)
- **Perspective/transform corrections** (Upright, manual perspective)
- **Camera profile & process version**

Everything else is reset via the **Reset For Before** develop preset:

- White balance → As Shot (camera original)
- Exposure, contrast, highlights, shadows → 0
- HSL, color grading, split toning → 0
- Sharpening → LR defaults (Amount 40, Radius 1.0, Detail 25)
- Noise reduction → LR defaults (Color NR 25)
- Effects (vignette, grain) → off
- Retouching, gradients, brushes → removed

## Safety

Before modifying any photo's develop settings, the plugin:

1. Saves the complete settings table in memory
2. Creates a develop snapshot named **"Before-After Backup"**
3. Restores original settings after export

If something goes wrong (crash, etc.), you can manually restore from the snapshot in Develop > Snapshots.

## Limitations

- **No SDK access to LR's internal "Before" state.** If you've manually set a custom Before via the History panel or snapshots, this plugin won't know about it. It constructs "before" from the Reset For Before preset + your geometry.
- **Import presets not accounted for.** If you applied a develop preset during import, LR's Before/After shows that preset as the baseline. This plugin uses Adobe defaults instead.
- **Settings API is "experimental"** per Adobe. The `getDevelopSettings`/`applyDevelopSettings` APIs have been stable for 10+ years but Adobe reserves the right to change them. New develop features (e.g., AI masking) may add settings keys not covered by the preset.
- **Sequential processing.** Each photo requires two renders (after + before), so large batches will take a while.

## Debugging

Logs go to Lightroom's plugin log:

- **macOS:** `~/Library/Application Support/Adobe/Lightroom/`
- **Windows:** `%APPDATA%\Adobe\Lightroom\`

## Publish Service

The plugin includes a publish service for incremental before/after publishing.

### Setup

1. Go to **File > Plug-in Manager**, find "Before and After Export"
2. In the Library module, click **+** next to **Publish Services** and choose **Before & After Publish**
3. Configure:
   - **After folder** — where edited images are published
   - **Before folder** — where "before" versions are published
   - **Metadata validation** — optionally require title, camera model, and a specific creator
4. Add photos to the default "Photos" collection and click **Publish**

### Incremental behavior

On each publish:
- **After** images are always re-exported
- **Before** images are re-exported on first publish and on every republish (including **Mark for Republish** and metadata edits). Before is skipped only on the rare first-publish path where develop settings haven't changed since the hash was recorded.

### Deleting

Removing a photo from the published collection deletes both the after and before files from disk.

## Audit Metadata

**Library > Plug-in Extras > Audit Metadata** scans photos from the active source (or current selection) and flags metadata issues:

- Missing title
- Missing camera model
- Wrong/missing creator (pulls the required value from your publish service settings, if configured)

Flagged photos are collected into **Before & After > Metadata Issues**. Reports are saved to:

- **macOS:** `~/Documents/Before and After Export/reports/`
- **Windows:** `%USERPROFILE%\Documents\Before and After Export\reports\`

## Roadmap

- [x] Publish service provider (auto-republish when edits change)
- [ ] Integration with Jeffrey Friedl's Collection Publisher
- [ ] Subfolder mode (before/ and after/ subdirectories instead of suffixes)
- [ ] Configurable "before" definition (choose which settings to preserve)
- [ ] Batch progress with per-photo thumbnails
