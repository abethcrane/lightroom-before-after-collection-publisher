# Before & After publish — notes

## Metadata-only republish (future optimization)

Right now **every queued rendition** runs **after** in `processRenderedPhotos`, then **queues** a **deferred before job**. After the callback returns, a **sleep-only** async task waits **25s**, then **`LrFunctionContext.postAsyncTaskWithContext`** runs **`catalogWriteWaitRetry`** snapshot+apply → second **`LrExportSession`** → move → **`catalogWriteWait`** restore (**`createDevelopSnapshot`** still only inside that gate). No `pcall` around those ops.

Even when **Develop** sliders did not change (e.g. IPTC/metadata-only republish), the **before** path still runs until we reintroduce **`needsBefore`** optimization below.

## Catalog write contention during publish

Runtime evidence: **nested** `withWriteAccessDo` **inside** `processRenderedPhotos` fails — publish/export already holds catalog write → instant **“blocked by another write access call…”** (untimed) or long **aborted** (timed).

**Current mitigation:**

- **`processRenderedPhotos`**: move **after** only; **`record*`**; **queue** `pendingBeforeJobs`. **No** catalog writes for before in this callback.

**Scheduling:** After publish returns, **`LrTasks.startAsyncTask`** **only** **`sleep(25)`** — no catalog APIs — then **`postAsyncTaskWithContext`** runs deferred work. Snapshot step uses **`catalogWriteWaitRetry`** (6× **180s** attempts, **15s** pause). **`getPublishedPhotos`** is **not** called inside **`withWriteAccessDo`**; only **`setEditedFlag`** on pre-filtered **`LrPublishedPhoto`** rows (see SDK: published-collection queries from async tasks).

- **`LrFunctionContext.postAsyncTaskWithContext`** (after **`sleep(25)`** trampoline + **`sleep(1)`**): deferred before + flags. Do not start another publish until logs show deferred work finished — overlapping publishes fight for the same catalog gate.

**Do not** wrap `createDevelopSnapshot` / `applyDevelopSettings` in **`pcall`** --- Lightroom errors with **Yielding is not allowed within a C or metamethod call**.

**Do not** nest catalog snapshot/restore **inside** `processRenderedPhotos` while the publish rendition pipeline is active.

Historical: **`sleep(25)`** trampoline after publish, then **`sleep(1)`** in **`postAsync`**, then after deferred work **`sleep(5)`** before the edited-flag gate (plus **25s** extra quiesce if before-export failed). **Virtual-copy** before publish repeatedly deadlocked (`createVirtualCopies` blocked).

**UX:** **`record*`** runs as soon as the **after** file is moved; the **before** file + develop restore follow in async. **`record*`** can clear **“to publish”** before the **before** JPEG exists; **`before-photos`** lags until deferred work finishes.

**Edited flags:** **`getPublishedPhotos`** + match **outside** the write gate; **`setEditedFlag` only inside** **`withWriteAccessDo`** (**240s** wait, **one retry**). Logs should show **`matched N PublishedPhoto row(s)`** (typically **1**), not a full-catalog scan inside the gate.

## Wrong tint on exported before

Tracked separately (WB merge / unknown develop keys / VC **`applyDevelopSettings`** semantics). **`DevelopDefaults.buildBeforeSettings`** documents the strip/neutralize strategy.
