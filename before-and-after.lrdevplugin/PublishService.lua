local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrExportSession = import "LrExportSession"
local LrFileUtils = import "LrFileUtils"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"
local LrView = import "LrView"

local AuditCollections = require "AuditCollections"
local BeforeAfterExport = require "BeforeAfterExport"
local CatalogWrite = require "CatalogWrite"
local ExportParams = require "ExportParams"
local MarkUpToDate = require "MarkUpToDate"
local MetadataExport = require "MetadataExport"
local MetadataValidation = require "MetadataValidation"
local PublishPaths = require "PublishPaths"
local PublishSync = require "PublishSync"
local PublishSettingsCache = require "PublishSettingsCache"
local ResetPreset = require "ResetPreset"
local RevealPublished = require "RevealPublished"
local SyncFromDisk = require "SyncFromDisk"
local SyncSettings = require "SyncSettings"

local logger = LrLogger("BeforeAfterPublish")
logger:enable("logfile")

local provider = {}

provider.titleForGoToPublishedPhoto = "Go to Published After"

function provider.goToPublishedPhoto(publishSettings, info)
    RevealPublished.revealForPublishInfo(publishSettings, info, "after")
end

provider.small_icon = nil
provider.supportsIncrementalPublish = "only"
provider.canExportVideo = false

provider.exportPresetFields = {
    { key = "afterFolder",  default = "" },
    { key = "beforeFolder", default = "" },
    { key = "includeKeywordsInExport", default = true },
    { key = "keywordHierarchyInExport", default = true },
    { key = "validateMetadata", default = true },
    { key = "requiredCreator", default = "" },
}

provider.metadataThatTriggersRepublish = function(publishSettings)
    return {
        default = false,
        title = true,
        caption = true,
        keywords = true,
        rating = true,
        label = true,
        gps = true,
        creator = true,
        dateCreated = true,
    }
end

provider.hideSections = { "exportLocation", "fileNaming", "metadata" }
provider.allowFileFormats = { "JPEG", "TIFF" }
provider.allowColorSpaces = { "sRGB" }

local computeSettingsHash = BeforeAfterExport.computeSettingsHash

function provider.updateExportSettings(exportSettings)
    MetadataExport.apply(exportSettings)
    PublishSettingsCache.remember(nil, exportSettings)
    SyncSettings.mergeCachedFolders(exportSettings)
end

function provider.sectionsForTopOfDialog(f, propertyTable)
    return {
        {
            title = "Before & After Publish Settings",
            synopsis = propertyTable.afterFolder,
            f:row {
                f:static_text { title = "After folder:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind("afterFolder"), fill_horizontal = 1, width_in_chars = 40 },
                f:push_button {
                    title = "Browse...",
                    action = function()
                        local path = LrDialogs.runOpenPanel({ title = "Choose 'after' folder", canChooseFiles = false, canChooseDirectories = true, canCreateDirectories = true, allowsMultipleSelection = false })
                        if path then
                            propertyTable.afterFolder = path[1]
                            PublishSettingsCache.remember(nil, propertyTable)
                        end
                    end,
                },
            },
            f:row {
                f:static_text { title = "Before folder:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind("beforeFolder"), fill_horizontal = 1, width_in_chars = 40 },
                f:push_button {
                    title = "Browse...",
                    action = function()
                        local path = LrDialogs.runOpenPanel({ title = "Choose 'before' folder", canChooseFiles = false, canChooseDirectories = true, canCreateDirectories = true, allowsMultipleSelection = false })
                        if path then
                            propertyTable.beforeFolder = path[1]
                            PublishSettingsCache.remember(nil, propertyTable)
                        end
                    end,
                },
            },
        },
        {
            title = "Keywords in exported files",
            synopsis = propertyTable.includeKeywordsInExport
                and (propertyTable.keywordHierarchyInExport and "Hierarchy" or "Flat")
                or "Off",
            f:row {
                f:checkbox {
                    value = LrView.bind("includeKeywordsInExport"),
                    title = "Write Lightroom keywords into after/before JPEGs (keywords must be marked Include on Export in the Keyword List)",
                },
            },
            f:row {
                f:checkbox {
                    value = LrView.bind("keywordHierarchyInExport"),
                    title = "Write keywords as Lightroom hierarchy (parent|child in XMP)",
                    enabled = LrView.bind("includeKeywordsInExport"),
                },
            },
            f:row {
                f:static_text {
                    title = "Unchecked: flat keyword list only. Uses Lightroom XMP embedding (exiftool -HierarchicalSubject to verify).",
                    fill_horizontal = 1,
                    height_in_lines = 2,
                },
            },
        },
        {
            title = "Metadata Validation",
            synopsis = propertyTable.validateMetadata and "Enabled" or "Disabled",
            f:row { f:checkbox { value = LrView.bind("validateMetadata"), title = "Warn about metadata issues before publishing" } },
            f:row {
                f:static_text { title = "Required creator:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind("requiredCreator"), width_in_chars = 20, enabled = LrView.bind("validateMetadata") },
            },
            f:row {
                f:static_text { title = "Checks: title present, camera model present, creator matches required value.", fill_horizontal = 1, height_in_lines = 2 },
            },
        },
        {
            title = "Sync from disk",
            synopsis = "Mark photos as published when files already exist",
            f:row {
                f:static_text {
                    title = "If after/before files already exist on disk, mark all photos in your publish collections as up to date without re-exporting.",
                    fill_horizontal = 1,
                    height_in_lines = 2,
                },
            },
            f:row {
                f:push_button {
                    title = "Mark all as up to date from disk…",
                    action = function()
                        MarkUpToDate.startFromPublishSettings(propertyTable)
                    end,
                },
            },
        },
    }
end

function provider.processRenderedPhotos(functionContext, exportContext)
    if SyncFromDisk.isActive() then
        return PublishSync.run(functionContext, exportContext)
    end

    if not exportContext or not exportContext.exportSession then
        logger:error("processRenderedPhotos: missing export context or session")
        return
    end

    local publishSettings = PublishSync.resolvePublishSettings(exportContext)
    local publishService = exportContext.publishService
    if not publishService and exportContext.publishedCollection then
        publishService = exportContext.publishedCollection:getService()
    end
    PublishSettingsCache.remember(publishService, publishSettings)

    local catalog = LrApplication.activeCatalog()

    local afterFolder = publishSettings and publishSettings.afterFolder
    local beforeFolder = publishSettings and publishSettings.beforeFolder

    if not afterFolder or afterFolder == "" or not beforeFolder or beforeFolder == "" then
        LrDialogs.message("Before & After Publish", "Please configure both 'after' and 'before' folder paths in the publish service settings.", "critical")
        return
    end

    for _, dir in ipairs({ afterFolder, beforeFolder }) do
        if not LrFileUtils.exists(dir) then
            LrFileUtils.createAllDirectories(dir)
        end
    end

    local exportSession = exportContext.exportSession

    local resetPreset = ResetPreset.find()
    if not resetPreset then
        LrDialogs.message("Before & After Publish", ResetPreset.missingMessage(), "critical")
        return
    end

    if publishSettings and publishSettings.validateMetadata then
        local allIssues = {}
        local flaggedPhotos = {}
        for i, rendition in exportSession:renditions() do
            local photo = rendition.photo
            local issues = MetadataValidation.validatePhoto(photo, {
                requiredCreator = publishSettings.requiredCreator,
            })
            if #issues > 0 then
                local name = photo:getFormattedMetadata("fileName")
                table.insert(allIssues, name .. ": " .. table.concat(issues, ", "))
                table.insert(flaggedPhotos, photo)
            end
        end
        if #allIssues > 0 then
            AuditCollections.updateCollection(catalog, AuditCollections.METADATA_COLLECTION, flaggedPhotos)
            local proceed = LrDialogs.confirm(
                "Metadata issues found",
                #allIssues .. " photo(s) have metadata issues:\n\n" .. table.concat(allIssues, "\n")
                    .. "\n\nFlagged photos added to '" .. AuditCollections.COLLECTION_SET .. " > " .. AuditCollections.METADATA_COLLECTION .. "'."
                    .. "\n\nPublish anyway?",
                "Publish Anyway", "Cancel"
            )
            if proceed == "cancel" then return end
        end
    end

    local nRenditions = exportSession:countRenditions()
    if nRenditions == 0 then
        LrDialogs.message(
            "Before & After Publish",
            "Lightroom queued 0 photos. If you expected updates, make a small Develop or Metadata "
                .. "change so items show as Modified.",
            "info"
        )
        return
    end

    logger:info(string.format(
        "PublishService start: renditionCount=%d afterFolder=%s beforeFolder=%s",
        nRenditions, afterFolder, beforeFolder
    ))

    local progressScope = exportContext:configureProgress({ title = "Publishing Before & After (" .. nRenditions .. " photos)" })
    local publishedPhotos = {}
    local restoreFailures = {}

    for i, rendition in exportContext:renditions({ stopIfCanceled = true }) do
        local photo = rendition.photo
        local photoName = photo:getFormattedMetadata("fileName")
        progressScope:setCaption("Publishing " .. photoName)

        local success, pathOrMsg = rendition:waitForRender()

        if success then
            local ext = PublishPaths.getFileExtension(PublishPaths.getExportFormat(publishSettings))
            local filename = PublishPaths.getExportFilename(photo, ext)
            local currentSettings = photo:getDevelopSettings()
            local newHash = computeSettingsHash(currentSettings)

            local afterPath = LrPathUtils.child(afterFolder, filename)
            if LrFileUtils.exists(afterPath) then LrFileUtils.delete(afterPath) end
            LrFileUtils.move(pathOrMsg, afterPath)
            logger:info("publish-after " .. photoName .. ": wrote " .. afterPath)

            logger:info("Exporting before for " .. photoName)

            local expectedHash = newHash
            local snapshotId = BeforeAfterExport.createSafetySnapshot(catalog, photo)
            if not snapshotId then
                logger:warn("Could not resolve safety snapshot id for " .. photoName)
            end

            CatalogWrite.runWithWriteAccess(catalog, "Apply reset preset for before export", function()
                photo:applyDevelopPreset(resetPreset)
            end)

            local beforeExportParams = ExportParams.buildBeforeExportParams(
                publishSettings, beforeFolder, "overwrite", { jpegQualityDefault = 1 }
            )

            local beforeSession = LrExportSession({ photosToExport = { photo }, exportSettings = beforeExportParams })
            local beforePath = nil
            for _, bRendition in beforeSession:renditions() do
                local bSuccess, bPath = bRendition:waitForRender()
                if bSuccess then
                    beforePath = LrPathUtils.child(beforeFolder, filename)
                    if bPath ~= beforePath then
                        if LrFileUtils.exists(beforePath) then LrFileUtils.delete(beforePath) end
                        LrFileUtils.move(bPath, beforePath)
                    end
                    logger:info("publish-before " .. photoName .. ": wrote " .. beforePath)
                else
                    logger:error("Before render failed for " .. photoName .. ": " .. tostring(bPath))
                end
            end

            local exportedPaths = { afterPath }
            if beforePath and LrFileUtils.exists(beforePath) then
                exportedPaths[#exportedPaths + 1] = beforePath
            end
            MetadataExport.writeXmpTitlesForPhoto(photo, exportedPaths, publishSettings)

            if LrTasks.canYield() then
                LrTasks.sleep(0.5)
            end

            local restoreOk = BeforeAfterExport.restoreAfterBeforeExport(
                catalog, photo, snapshotId, currentSettings, expectedHash, photoName,
                "Before & After Publish", { suppressDialog = true }
            )
            if not restoreOk then
                table.insert(restoreFailures, photo)
            end
            newHash = restoreOk and expectedHash or computeSettingsHash(photo:getDevelopSettings())

            rendition:recordPublishedPhotoId(PublishPaths.encodeRemoteId(filename, newHash))
            rendition:recordPublishedPhotoUrl(afterPath)
            table.insert(publishedPhotos, photo)
        else
            rendition:uploadFailed(pathOrMsg)
            logger:error("Render failed for " .. photoName .. ": " .. tostring(pathOrMsg))
        end
    end

    local restoreFailureCount = #restoreFailures

    local publishedCollection = exportContext.publishedCollection

    LrTasks.startAsyncTask(function()
        local cat = LrApplication.activeCatalog()

        if restoreFailureCount > 0 then
            local updated = AuditCollections.updateCollection(cat, AuditCollections.RESTORE_COLLECTION, restoreFailures)
            if updated then
                logger:info(string.format(
                    "Added %d restore failure(s) to '%s > %s'",
                    restoreFailureCount, AuditCollections.COLLECTION_SET, AuditCollections.RESTORE_COLLECTION
                ))
            else
                logger:error(string.format(
                    "Could not update '%s > %s' with %d restore failure(s)",
                    AuditCollections.COLLECTION_SET, AuditCollections.RESTORE_COLLECTION, restoreFailureCount
                ))
            end
            LrDialogs.message(
                "Before & After Publish",
                restoreFailureCount .. " photo(s) could not be fully restored after exporting the \"before\" version." ..
                    "\n\nThey have been added to '" .. AuditCollections.COLLECTION_SET ..
                    " > " .. AuditCollections.RESTORE_COLLECTION ..
                    "'. Use Undo or snapshot \"" .. BeforeAfterExport.SNAPSHOT_NAME ..
                    "\" on each photo if it still looks like the \"before\" version.",
                "warning"
            )
        end

        local publishedPhotoIds = {}
        for _, p in ipairs(publishedPhotos) do
            publishedPhotoIds[p.localIdentifier] = true
        end

        -- LR's publish watcher re-marks photos as modified after the restore
        -- step changes develop settings. We need to clear flags after the
        -- watcher has settled. Try multiple times with increasing delays.
        for attempt = 1, 3 do
            LrTasks.sleep(attempt == 1 and 8 or 5)

            local pubPhotos = publishedCollection:getPublishedPhotos()
            local targets = {}
            for _, pp in ipairs(pubPhotos) do
                local p = pp:getPhoto()
                if p and publishedPhotoIds[p.localIdentifier] and pp:getEditedFlag() then
                    targets[#targets + 1] = pp
                end
            end

            if #targets == 0 then
                logger:info("Flags already clear (attempt " .. attempt .. ")")
                break
            end

            cat:withWriteAccessDo("Clear edited flags after publish", function()
                for _, pp in ipairs(targets) do
                    pp:setEditedFlag(false)
                end
            end, { timeout = 30 })

            logger:info("Cleared " .. #targets .. " edited flag(s) (attempt " .. attempt .. ")")
        end
    end)
end

function provider.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
    for _, remoteId in ipairs(arrayOfPhotoIds) do
        local filename = PublishPaths.decodeRemoteId(remoteId)
        local afterPath = LrPathUtils.child(publishSettings.afterFolder, filename)
        local beforePath = LrPathUtils.child(publishSettings.beforeFolder, filename)
        if LrFileUtils.exists(afterPath) then LrFileUtils.delete(afterPath) end
        if LrFileUtils.exists(beforePath) then LrFileUtils.delete(beforePath) end
        deletedCallback(remoteId)
    end
end

function provider.getCollectionBehaviorInfo(publishSettings)
    return {
        defaultCollectionName = "Photos",
        defaultCollectionCanBeDeleted = true,
        canAddCollection = true,
        maxCollectionSetDepth = 0,
    }
end

return provider
