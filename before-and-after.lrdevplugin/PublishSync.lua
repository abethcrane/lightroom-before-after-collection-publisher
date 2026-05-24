local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrLogger = import "LrLogger"

local SyncFromDisk = require "SyncFromDisk"

local logger = LrLogger("BeforeAfterPublish")
logger:enable("logfile")

local PublishSync = {}

function PublishSync.resolvePublishSettings(exportContext)
    local publishSettings = exportContext and exportContext.propertyTable
    if publishSettings and publishSettings.afterFolder and publishSettings.afterFolder ~= ""
        and publishSettings.beforeFolder and publishSettings.beforeFolder ~= "" then
        return publishSettings
    end

    local cached = SyncFromDisk.getPublishSettings()
    if cached and cached.afterFolder and cached.afterFolder ~= ""
        and cached.beforeFolder and cached.beforeFolder ~= "" then
        return cached
    end

    local publishedCollection = exportContext and exportContext.publishedCollection
    if publishedCollection and type(publishedCollection.getService) == "function" then
        local service = publishedCollection:getService()
        if service then
            local serviceSettings = service:getPublishSettings()
            if serviceSettings then
                return serviceSettings
            end
        end
    end

    local publishService = exportContext and exportContext.publishService
    if publishService and type(publishService.getPublishSettings) == "function" then
        local serviceSettings = publishService:getPublishSettings()
        if serviceSettings then
            return serviceSettings
        end
    end

    return publishSettings
end

function PublishSync.run(functionContext, exportContext)
    if not exportContext or not exportContext.exportSession then
        SyncFromDisk.recordResult(0, 0)
        return
    end

    local exportSession = exportContext.exportSession
    local publishSettings = PublishSync.resolvePublishSettings(exportContext)
    local afterFolder = publishSettings and publishSettings.afterFolder
    local beforeFolder = publishSettings and publishSettings.beforeFolder

    if not afterFolder or afterFolder == "" or not beforeFolder or beforeFolder == "" then
        LrDialogs.message(
            "Before & After Publish",
            "Please configure both 'after' and 'before' folder paths in the publish service settings.",
            "critical"
        )
        SyncFromDisk.recordResult(0, 0)
        return
    end

    for _, dir in ipairs({ afterFolder, beforeFolder }) do
        if not LrFileUtils.exists(dir) then
            LrFileUtils.createAllDirectories(dir)
        end
    end

    local progressScope = exportContext:configureProgress({
        title = "Marking up to date from disk (" .. exportSession:countRenditions() .. " queued)",
    })

    for _, rendition in exportSession:renditions() do
        rendition:skipRender()
    end

    local synced = 0
    local failed = 0

    for _, rendition in exportContext:renditions({ stopIfCanceled = true }) do
        local photo = rendition.photo
        if not photo then
            failed = failed + 1
        else
            if progressScope then
                progressScope:setCaption(photo:getFormattedMetadata("fileName"))
            end
            rendition:waitForRender()

            if SyncFromDisk.shouldSyncPhoto(photo) then
                local diskInfo = SyncFromDisk.getDiskInfo(photo)
                if diskInfo then
                    rendition:recordPublishedPhotoId(diskInfo.remoteId)
                    rendition:recordPublishedPhotoUrl(diskInfo.afterPath)
                    synced = synced + 1
                else
                    rendition:uploadFailed("After/before pair missing on disk")
                    failed = failed + 1
                end
            end
        end
    end

    if progressScope then
        progressScope:done()
    end

    SyncFromDisk.recordResult(synced, failed)
    logger:info(string.format("Sync-from-disk publish done: synced=%d failed=%d", synced, failed))
end

return PublishSync
