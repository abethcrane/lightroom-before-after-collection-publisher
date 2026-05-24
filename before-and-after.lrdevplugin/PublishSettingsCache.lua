local LrLogger = import "LrLogger"
local LrPrefs = import "LrPrefs"

local logger = LrLogger("PublishSettingsCache")
logger:enable("logfile")

local GLOBAL_KEY = "__BeforeAfterPublishSettingsCache"

local cache = _G[GLOBAL_KEY]
if not cache then
    cache = {
        byServiceId = {},
        lastKnown = nil,
    }
    _G[GLOBAL_KEY] = cache
end

local prefs = LrPrefs.prefsForPlugin()

local PublishSettingsCache = {}

local function readFolder(settings, key)
    if not settings then
        return nil
    end
    local value = settings[key]
    if value and value ~= "" then
        return value
    end
    return nil
end

local function snapshotFromSettings(settings)
    if not settings then
        return nil
    end

    local afterFolder = readFolder(settings, "afterFolder")
    local beforeFolder = readFolder(settings, "beforeFolder")
    if not afterFolder or not beforeFolder then
        return nil
    end

    return {
        afterFolder = afterFolder,
        beforeFolder = beforeFolder,
        LR_format = settings.LR_format,
    }
end

local function snapshotFromPrefs()
    local afterFolder = prefs.afterFolder
    local beforeFolder = prefs.beforeFolder
    if not afterFolder or afterFolder == "" or not beforeFolder or beforeFolder == "" then
        return nil
    end
    return {
        afterFolder = afterFolder,
        beforeFolder = beforeFolder,
        LR_format = prefs.LR_format,
    }
end

local function persistSnapshot(snapshot)
    if not snapshot then
        return
    end
    cache.lastKnown = snapshot
    prefs.afterFolder = snapshot.afterFolder
    prefs.beforeFolder = snapshot.beforeFolder
    if snapshot.LR_format then
        prefs.LR_format = snapshot.LR_format
    end
    logger:info(string.format(
        "Remembered publish folders: after=%s before=%s",
        snapshot.afterFolder, snapshot.beforeFolder
    ))
end

function PublishSettingsCache.remember(service, settings)
    local snapshot = snapshotFromSettings(settings)
    if not snapshot then
        return
    end

    persistSnapshot(snapshot)
    if service and service.localIdentifier then
        cache.byServiceId[service.localIdentifier] = snapshot
    end
end

function PublishSettingsCache.getLastKnown()
    return cache.lastKnown or snapshotFromPrefs()
end

function PublishSettingsCache.getEffectiveSettings(base, service)
    base = base or {}

    local snapshot = nil
    if service and service.localIdentifier then
        snapshot = cache.byServiceId[service.localIdentifier]
    end
    snapshot = snapshot or cache.lastKnown or snapshotFromPrefs()

    if snapshot then
        if not readFolder(base, "afterFolder") then
            base.afterFolder = snapshot.afterFolder
        end
        if not readFolder(base, "beforeFolder") then
            base.beforeFolder = snapshot.beforeFolder
        end
        if not base.LR_format and snapshot.LR_format then
            base.LR_format = snapshot.LR_format
        end
    end

    return base
end

function PublishSettingsCache.merge(settings, service)
    return PublishSettingsCache.getEffectiveSettings(settings, service)
end

return PublishSettingsCache
