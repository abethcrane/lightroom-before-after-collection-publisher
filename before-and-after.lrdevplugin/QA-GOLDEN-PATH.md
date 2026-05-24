# QA golden path — Before & After Export

Manual regression checklist for Lightroom Classic. Run after plugin changes, before a release, or when debugging publish/sync issues.

**Environment:** Lightroom Classic 15+ · develop preset **Reset For Before** installed · plugin loaded (symlink or Modules folder)

**Log file (macOS):** `~/Library/Application Support/Adobe/Lightroom/lrc_console.log`

---

## Setup (once per test session)

- [ ] Plug-in Manager shows expected version (currently **1.3.2+**)
- [ ] **Reset For Before** preset visible under User Presets in Develop
- [ ] Publish service exists: **Before & After Publish** with:
  - After folder (e.g. `…/synced-photos`)
  - Before folder (e.g. `…/before-photos`)
  - Metadata validation configured if you test that path
- [ ] No stale **(missing plug-in)** publish services in the sidebar (delete orphans if present)
- [ ] Smart or regular collection under the publish service with a few known test photos

Use 2–3 photos you can recognize on disk (with EXIF date for publish filename format).

---

## 1. Ad-hoc export (File → Export)

### 1.1 Single photo

1. Library → select **one** edited photo
2. **File → Plug-in Extras → Export Before and After** (or File → Export)
3. Destination: **Before and After Export**
4. Choose folder, JPEG, default suffixes (`-after` / `-before`)
5. **Existing Files:** Overwrite (simplest for first run)
6. Export

**Expect:**

- [ ] `IMG-after.jpg` and `IMG-before.jpg` (or your suffixes) in target folder
- [ ] After = current edit; before = geometry only, defaults for tone/color
- [ ] Photo in Develop unchanged (not stuck on before look)
- [ ] **Before-After Backup** snapshot exists if you check Develop → Snapshots

### 1.2 Multiple photos

Same as 1.1 with **3+ photos**.

**Expect:**

- [ ] Paired files for each photo
- [ ] Progress completes without critical error dialog
- [ ] No photos added to **Before & After → Restore Failures**

### 1.3 Collision: skip existing

Re-run 1.2 with **Existing Files → Skip**.

**Expect:**

- [ ] Info dialog about skipped files (or nothing new written)
- [ ] Existing files untouched

### 1.4 Collision: overwrite

Re-run with **Existing Files → Overwrite**.

**Expect:**

- [ ] Files replaced with fresh renders

---

## 2. Publish service — first publish

1. Add test photos to publish collection (or ensure smart collection matches them)
2. Confirm they appear under **New Photos to Publish**
3. Click **Publish**

**Expect:**

- [ ] After + before files on disk using publish naming: `YYYY-MM-DD-HH-MM-SS-basename.jpg`
- [ ] Photos move out of **New Photos to Publish** into published state
- [ ] Develop settings restored on each photo (not stuck on before)
- [ ] Log: `PublishService start` / `publish-after` / `publish-before` lines (no crash)

---

## 3. Publish service — republish

### 3.1 Develop edit

1. Change exposure (or similar) on a **published** photo
2. Photo should show as modified / ready to republish
3. Publish

**Expect:**

- [ ] Both after and before files re-written on disk
- [ ] Photo clears from republish queue when done
- [ ] *(Known issue — roadmap)* Sometimes photo **stays** in ready-to-publish; note if it happens

### 3.2 Metadata-only edit

1. Change title or keywords on a published photo (no develop change)
2. Publish

**Expect:**

- [ ] Files re-exported (both after and before — by design today)
- [ ] Same known-issue check as 3.1 for stuck republish flag

### 3.3 Mark for Republish

1. Right-click published photo → **Mark for Republish**
2. Publish

**Expect:**

- [ ] Files refreshed on disk
- [ ] Queue clears (or note stuck flag)

---

## 4. Sync from disk (Publish Manager)

Use when files already exist but catalog lost publish state (e.g. reconnected service).

**Prereq:** After + before file pairs already on disk for photos in the collection queue.

1. **File → Publish Manager** → select your **Before & After Publish** service
2. Confirm folder paths
3. Click **Mark all as up to date from disk…**

**Expect:**

- [ ] Dialog: N photos marked up to date (N > 0)
- [ ] Photos leave **New Photos to Publish** without full re-render
- [ ] Log: `Sync from disk` / `Sync-from-disk publish done: synced=N`
- [ ] No crash (`getPluginId`, yielding, etc.)

**Negative case:** Remove one before file from disk, run again.

**Expect:**

- [ ] That photo listed as skipped (missing pair); others sync if present

---

## 5. Go to published file

On a **published** photo (with remote ID):

- [ ] **Plug-in Extras → Go to Published After** → Finder reveals after file
- [ ] **Plug-in Extras → Go to Published Before** → Finder reveals before file

**Negative:** Unpublished / new-to-publish photo → sensible warning (no published remote ID).

---

## 6. Delete from publish collection

1. Remove photo from published collection
2. Click **Publish** (applies staged deletion)

**Expect:**

- [ ] After and before files deleted from disk
- [ ] Photo no longer in collection

---

## 7. Metadata audit

1. Include at least one photo **missing title** or **camera model**
2. **Library → Plug-in Extras → Audit Metadata**

**Expect:**

- [ ] **Before & After → Metadata Issues** collection populated
- [ ] Report written under `~/Documents/Before and After Export/reports/`

---

## 8. Publish with metadata validation

Enable **Warn about metadata issues** + **Required creator** in Publish Manager.

1. Publish a photo with bad metadata

**Expect:**

- [ ] Confirm dialog listing issues
- [ ] **Publish Anyway** works; **Cancel** aborts
- [ ] Flagged photos added to **Metadata Issues** if you proceed

---

## 9. Restore failure (edge case)

Hard to force reliably. If a photo lands in **Before & After → Restore Failures** after export/publish:

- [ ] Develop still looks like before → Undo or apply **Before-After Backup** snapshot fixes it

---

## 10. Plugin lifecycle

- [ ] **Reload Plug-in** in Plug-in Manager → no error on load
- [ ] Missing preset: temporarily rename preset → restart → warning on load (restore after)

---

## Quick smoke (5 min)

Minimum before merging:

1. [ ] Ad-hoc export — 1 photo
2. [ ] Publish — 1 new photo from collection
3. [ ] Sync from disk — if you use reconnect workflow
4. [ ] Go to Published After — 1 photo

---

## Automated tests (future)

| Area | Automatable? | Notes |
|------|----------------|-------|
| Export / publish pipeline | No | Requires Lightroom runtime + render |
| Catalog / publish collections | No | SDK objects not available headless |
| `encodeRemoteId` / `decodeRemoteId` | Yes | Pure string logic |
| Filename date formatting | Partial | Needs mock `LrPhoto` |
| Disk index / pair resolution | Partial | Needs temp dirs + mocks |

No automated suite in-repo yet; this file is the source of truth for QA.
