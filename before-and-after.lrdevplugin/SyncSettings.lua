local SyncFromDisk = require "SyncFromDisk"

local SyncSettings = {}

function SyncSettings.mergeCachedFolders(exportSettings)
    if not SyncFromDisk.isActive() or not exportSettings then
        return
    end

    local cached = SyncFromDisk.getPublishSettings()
    if not cached then
        return
    end

    if not exportSettings.afterFolder or exportSettings.afterFolder == "" then
        exportSettings.afterFolder = cached.afterFolder
    end
    if not exportSettings.beforeFolder or exportSettings.beforeFolder == "" then
        exportSettings.beforeFolder = cached.beforeFolder
    end
end

return SyncSettings
