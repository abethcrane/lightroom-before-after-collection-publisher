# Before & After Export — Lightroom Classic

Lightroom Classic plugin + develop preset for exporting matched **before** and **after** JPEG/TIFF pairs from edited photos.

- **After** — your current edit
- **Before** — same crop, rotation, lens corrections, and transform; tonal/color edits reset to defaults

Tested on **Lightroom Classic 15**.

## Install

### 1. Develop preset (required)

The plugin applies a develop preset named **Reset For Before** to generate the before image. Install it first:

1. In Lightroom Classic, open the **Develop** module
2. In the **Presets** panel, right-click **User Presets** → **Import…**
3. Select `presets/Reset For Before.xmp` from this repo (or from a release zip)

Alternatively, copy the `.xmp` file into your User Presets folder and restart Lightroom:

- **macOS:** `~/Library/Application Support/Adobe/Camera Raw/Settings/User Presets/`
- **Windows:** `%APPDATA%\Adobe\CameraRaw\Settings\User Presets\`

### 2. Plugin

Copy or symlink the plugin folder into Lightroom's Modules directory:

- **macOS:** `~/Library/Application Support/Adobe/Lightroom/Modules/`
- **Windows:** `%APPDATA%\Adobe\Lightroom\Modules\`

Or use **File → Plug-in Manager → Add** and point at `before-and-after.lrdevplugin/`.

Restart Lightroom Classic (or click **Reload Plug-in** in Plug-in Manager).

```bash
# Development symlink (macOS)
ln -s "$(pwd)/before-and-after.lrdevplugin" \
  ~/Library/Application\ Support/Adobe/Lightroom/Modules/
```

## Usage

Two workflows — see [before-and-after.lrdevplugin/README.md](before-and-after.lrdevplugin/README.md) for full detail.

### Ad-hoc export

Select photos → **File → Plug-in Extras → Export Before and After** → pick a folder → export `-before`/`-after` pairs.

### Publish service

Add **Before & After Publish** under Publish Services → configure after/before folders → add photos to the collection → **Publish**. Re-publishes when edits or metadata change.

The plugin also creates **Before & After** helper collections in your catalog (**Metadata Issues**, **Restore Failures**) — see the plugin README.

## Release zip

```bash
./scripts/build-release.sh
```

Creates `dist/before-and-after-export-<version>.zip` with the plugin folder and preset.

## Development

The Adobe Lightroom Classic SDK is **not** included in this repo. Download it from Adobe if you're extending the plugin.

## License

MIT — see [LICENSE](LICENSE).
