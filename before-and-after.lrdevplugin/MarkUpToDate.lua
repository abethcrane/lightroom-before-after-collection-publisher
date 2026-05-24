local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"
local LrTasks = import "LrTasks"

local BeforeAfterExport = require "BeforeAfterExport"
local PublishPaths = require "PublishPaths"
local RevealPublished = require "RevealPublished"
local SyncFromDisk = require "SyncFromDisk"
local PublishSettingsCache = require "PublishSettingsCache"

local logger = LrLogger("MarkUpToDate")
logger:enable("logfile")

local MarkUpToDate = {}

local function mergeFolderSettings(baseSettings, folderSettings)
    if not folderSettings then
        return baseSettings or {}
    end

    local settings = {}
    for key, value in pairs(baseSettings or {}) do
        settings[key] = value
    end
    if folderSettings.afterFolder and folderSettings.afterFolder ~= "" then
        settings.afterFolder = folderSettings.afterFolder
    end
    if folderSettings.beforeFolder and folderSettings.beforeFolder ~= "" then
        settings.beforeFolder = folderSettings.beforeFolder
    end
    if folderSettings.LR_format then
        settings.LR_format = folderSettings.LR_format
    end
    return settings
end

local function foldersConfigured(settings)
    return settings
        and settings.afterFolder and settings.afterFolder ~= ""
        and settings.beforeFolder and settings.beforeFolder ~= ""
end

local function waitForPublishDone(publishDoneRef, timeoutSeconds)
    local deadline = os.clock() + (timeoutSeconds or 600)
    while not publishDoneRef.done and os.clock() < deadline do
        if LrTasks.canYield() then
            LrTasks.yield()
        else
            LrTasks.sleep(0.1)
        end
    end
    return publishDoneRef.done
end

local function showResult(result, missing, skipped)
    local lines = { result.synced .. " photo(s) marked as up to date (synced from disk)." }
    if result.failed > 0 then
        lines[#lines + 1] = result.failed .. " failed during sync — see the plugin log."
    end
    if #missing > 0 then
        local preview = table.concat(missing, "\n", 1, math.min(5, #missing))
        if #missing > 5 then
            preview = preview .. "\n… and " .. (#missing - 5) .. " more"
        end
        lines[#lines + 1] = #missing .. " skipped — after/before file pair missing on disk:\n" .. preview
    end
    if skipped > 0 then
        lines[#lines + 1] = skipped .. " skipped — after/before folders not configured."
    end

    LrDialogs.message(
        "Before & After Publish",
        table.concat(lines, "\n\n"),
        result.synced > 0 and "info" or "warning"
    )
end

function MarkUpToDate.run(options)
    options = options or {}
    local catalog = LrApplication.activeCatalog()
    local folderSettings = options.folderSettings

    local publishService = options.publishService
        or RevealPublished.findPublishServiceForDialog(catalog, folderSettings)
    if not publishService then
        LrDialogs.message(
            "Before & After Publish",
            "No Before & After publish service found.\n\n"
                .. "Add the publish service under Publish Services, then try again.",
            "warning"
        )
        return
    end

    local entries = RevealPublished.collectPublishedPhotoEntriesForService(catalog, publishService)
    PublishSettingsCache.remember(publishService, folderSettings)

    if #entries == 0 then
        local collections = RevealPublished.getCollectionsForService(publishService)
        local message
        if #collections == 0 then
            message = "No publish collections found under this service.\n\n"
                .. "Add a collection (or smart collection) under the service, then try again."
        else
            message = "No photos found in publish collections under this service.\n\n"
                .. "Add photos to a collection under the service, then try again."
        end
        LrDialogs.message("Before & After Publish", message, "warning")
        return
    end

    if folderSettings and not foldersConfigured(folderSettings) then
        LrDialogs.message(
            "Before & After Publish",
            "Set both after and before folder paths above, then try again.",
            "warning"
        )
        return
    end

    logger:info("Sync from disk: checking " .. #entries .. " photo(s)")

    local folderIndexes = {}
    local pendingSync = {}
    local missing = {}
    local skipped = 0

    for i, entry in ipairs(entries) do
        if i % 50 == 0 and LrTasks.canYield() then
            LrTasks.yield()
        end

        local publishSettings = mergeFolderSettings(entry.settings, folderSettings)
        local photo = entry.photo

        if not photo then
            skipped = skipped + 1
        elseif not entry.publishedCollection or type(entry.publishedCollection.publishNow) ~= "function" then
            skipped = skipped + 1
        elseif not foldersConfigured(publishSettings) then
            skipped = skipped + 1
        else
            local cacheKey = publishSettings.afterFolder .. "\0" .. publishSettings.beforeFolder
            if not folderIndexes[cacheKey] then
                folderIndexes[cacheKey] = {
                    after = PublishPaths.buildFolderIndex(publishSettings.afterFolder),
                    before = PublishPaths.buildFolderIndex(publishSettings.beforeFolder),
                }
            end
            local indexes = folderIndexes[cacheKey]

            local afterPath, beforePath, filename = PublishPaths.resolveExportedPairWithIndex(
                publishSettings, photo, indexes.after, indexes.before
            )
            if not afterPath or not beforePath then
                missing[#missing + 1] = photo:getFormattedMetadata("fileName")
                    .. " (expected " .. tostring(filename) .. ")"
            else
                pendingSync[#pendingSync + 1] = {
                    photo = photo,
                    publishedCollection = entry.publishedCollection,
                    afterPath = afterPath,
                    remoteId = PublishPaths.encodeRemoteId(
                        filename,
                        BeforeAfterExport.computeSettingsHash(photo:getDevelopSettings())
                    ),
                }
            end
        end
    end

    if #pendingSync == 0 then
        local lines = {}
        if #missing > 0 then
            local preview = table.concat(missing, "\n", 1, math.min(5, #missing))
            if #missing > 5 then
                preview = preview .. "\n… and " .. (#missing - 5) .. " more"
            end
            lines[#lines + 1] = #missing .. " skipped — after/before file pair missing on disk:\n" .. preview
        end
        if skipped > 0 then
            lines[#lines + 1] = skipped .. " skipped — after/before folders not configured."
        end
        if #lines == 0 then
            lines[1] = "No photos to sync."
        end
        LrDialogs.message("Before & After Publish", table.concat(lines, "\n\n"), "warning")
        return
    end

    local photoIds = {}
    local diskInfoById = {}
    local collections = {}
    local collectionList = {}

    for _, item in ipairs(pendingSync) do
        photoIds[item.photo.localIdentifier] = true
        diskInfoById[item.photo.localIdentifier] = {
            afterPath = item.afterPath,
            remoteId = item.remoteId,
        }
        if not collections[item.publishedCollection] then
            collections[item.publishedCollection] = true
            collectionList[#collectionList + 1] = item.publishedCollection
        end
    end

    local serviceSettings = folderSettings
    if not foldersConfigured(serviceSettings) and collectionList[1] then
        local service = collectionList[1]:getService()
        if service then
            serviceSettings = service:getPublishSettings()
        end
    end

    SyncFromDisk.begin(photoIds, diskInfoById, serviceSettings)

    for _, collection in ipairs(collectionList) do
        local publishDoneRef = { done = false }
        local publishOk, publishErr = LrTasks.pcall(function()
            collection:publishNow(function()
                publishDoneRef.done = true
            end)
        end)

        if not publishOk then
            SyncFromDisk.reset()
            logger:error("publishNow failed: " .. tostring(publishErr))
            LrDialogs.message(
                "Before & After Publish",
                "Publish failed:\n" .. tostring(publishErr),
                "critical"
            )
            return
        end

        if not waitForPublishDone(publishDoneRef, 600) then
            SyncFromDisk.reset()
            LrDialogs.message(
                "Before & After Publish",
                "Timed out waiting for publish on collection \"" .. collection:getName() .. "\".",
                "critical"
            )
            return
        end
    end

    SyncFromDisk.markDone()
    local result = SyncFromDisk.getResult()
    SyncFromDisk.reset()

    logger:info(string.format(
        "Sync from disk done: synced=%d failed=%d missing=%d skipped=%d",
        result.synced, result.failed, #missing, skipped
    ))

    showResult(result, missing, skipped)
end

function MarkUpToDate.startFromPublishSettings(propertyTable)
    LrFunctionContext.postAsyncTaskWithContext("MarkUpToDate", function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)

        local ok, err = LrTasks.pcall(function()
            local catalog = LrApplication.activeCatalog()
            local publishService = RevealPublished.findPublishServiceForDialog(catalog, propertyTable)

            MarkUpToDate.run({
                folderSettings = propertyTable,
                publishService = publishService,
            })
        end)

        if not ok then
            SyncFromDisk.reset()
            logger:error("Sync from disk failed: " .. tostring(err))
            LrDialogs.message(
                "Before & After Publish",
                "Sync from disk failed:\n" .. tostring(err),
                "critical"
            )
        end
    end)
end

return MarkUpToDate
