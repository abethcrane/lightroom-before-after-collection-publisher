local GLOBAL_KEY = "__BeforeAfterSyncFromDisk"

local state = _G[GLOBAL_KEY]
if not state then
    state = {
        active = false,
        photoIds = {},
        diskInfoById = {},
        publishSettings = nil,
        synced = 0,
        failed = 0,
        done = false,
    }
    _G[GLOBAL_KEY] = state
end

local SyncFromDisk = {}

function SyncFromDisk.begin(photoIds, diskInfoById, publishSettings)
    local PublishSettingsCache = require "PublishSettingsCache"
    PublishSettingsCache.remember(nil, publishSettings)

    state.active = true
    state.photoIds = photoIds or {}
    state.diskInfoById = diskInfoById or {}
    state.publishSettings = publishSettings
    state.synced = 0
    state.failed = 0
    state.done = false
end

function SyncFromDisk.isActive()
    return state.active
end

function SyncFromDisk.getPublishSettings()
    return state.publishSettings
end

function SyncFromDisk.shouldSyncPhoto(photo)
    return state.active and photo and state.photoIds[photo.localIdentifier] == true
end

function SyncFromDisk.getDiskInfo(photo)
    if not photo then return nil end
    return state.diskInfoById[photo.localIdentifier]
end

function SyncFromDisk.recordResult(synced, failed)
    state.synced = state.synced + (synced or 0)
    state.failed = state.failed + (failed or 0)
end

function SyncFromDisk.markDone()
    state.done = true
    state.active = false
end

function SyncFromDisk.getResult()
    return {
        synced = state.synced,
        failed = state.failed,
        done = state.done,
    }
end

function SyncFromDisk.reset()
    state.active = false
    state.photoIds = {}
    state.diskInfoById = {}
    state.publishSettings = nil
    state.synced = 0
    state.failed = 0
    state.done = false
end

return SyncFromDisk
