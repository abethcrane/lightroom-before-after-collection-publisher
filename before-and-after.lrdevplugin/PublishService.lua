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
local ResetPreset = require "ResetPreset"
local RevealPublished = require "RevealPublished"

local logger = LrLogger("BeforeAfterPublish")
logger:enable("logfile")
logger:enable("print")

local provider = {}

provider.titleForGoToPublishedPhoto = "Go to Published After"

function provider.goToPublishedPhoto(publishSettings, info)
    RevealPublished.revealPublishedSide(publishSettings, info.remoteId, "after")
end

provider.small_icon = nil
provider.supportsIncrementalPublish = "only"
provider.canExportVideo = false

provider.exportPresetFields = {
    { key = "afterFolder",  default = "" },
    { key = "beforeFolder", default = "" },
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

local REMOTE_ID_SEP = "::"

local function getFileExtension(format)
    if format == "TIFF" then return "tif" end
    return "jpg"
end

local computeSettingsHash = BeforeAfterExport.computeSettingsHash

local function encodeRemoteId(filename, settingsHash)
    return filename .. REMOTE_ID_SEP .. settingsHash
end

local function decodeRemoteId(remoteId)
    if not remoteId then return nil, nil end
    local sep = remoteId:find(REMOTE_ID_SEP, 1, true)
    if sep then
        return remoteId:sub(1, sep - 1), remoteId:sub(sep + #REMOTE_ID_SEP)
    end
    return remoteId, nil
end

local function getExportFilename(photo, ext)
    local baseName = LrPathUtils.removeExtension(photo:getFormattedMetadata("fileName"))
    local dateStr = photo:getRawMetadata("dateTimeOriginalISO8601") or ""
    local y, mo, d, h, mi, s = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if y then
        return string.format("%s-%s-%s-%s-%s-%s-%s.%s", y, mo, d, h, mi, s, baseName, ext)
    end
    return baseName .. "." .. ext
end

local function validatePhoto(photo, publishSettings)
    local issues = {}
    local title = photo:getFormattedMetadata("title")
    if not title or title == "" then
        table.insert(issues, "missing title")
    end
    local camera = photo:getFormattedMetadata("cameraModel")
    if not camera or camera == "" then
        table.insert(issues, "missing camera model")
    end
    if publishSettings.requiredCreator and publishSettings.requiredCreator ~= "" then
        local creator = photo:getFormattedMetadata("creator")
        if creator ~= publishSettings.requiredCreator then
            table.insert(issues, "creator is '" .. tostring(creator) .. "', expected '" .. publishSettings.requiredCreator .. "'")
        end
    end
    return issues
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
                        if path then propertyTable.afterFolder = path[1] end
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
                        if path then propertyTable.beforeFolder = path[1] end
                    end,
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
    }
end

function provider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local publishSettings = exportContext.propertyTable
    local catalog = LrApplication.activeCatalog()

    local afterFolder = publishSettings.afterFolder
    local beforeFolder = publishSettings.beforeFolder

    if not afterFolder or afterFolder == "" or not beforeFolder or beforeFolder == "" then
        LrDialogs.message("Before & After Publish", "Please configure both 'after' and 'before' folder paths in the publish service settings.", "critical")
        return
    end

    for _, dir in ipairs({ afterFolder, beforeFolder }) do
        if not LrFileUtils.exists(dir) then
            LrFileUtils.createAllDirectories(dir)
        end
    end

    local resetPreset = ResetPreset.find()
    if not resetPreset then
        LrDialogs.message("Before & After Publish", ResetPreset.missingMessage(), "critical")
        return
    end

    if publishSettings.validateMetadata then
        local allIssues = {}
        local flaggedPhotos = {}
        for i, rendition in exportSession:renditions() do
            local photo = rendition.photo
            local issues = validatePhoto(photo, publishSettings)
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
            local ext = getFileExtension(publishSettings.LR_format or "JPEG")
            local filename = getExportFilename(photo, ext)
            local currentSettings = photo:getDevelopSettings()
            local newHash = computeSettingsHash(currentSettings)

            local previousRemoteId = rendition.publishedPhotoId
            local isRepublish = previousRemoteId ~= nil
            local _, oldHash = decodeRemoteId(previousRemoteId)
            -- Always re-export before on republish (including LR's "Mark for Republish").
            -- Develop-only skip applied only on first publish when hash is already known.
            local needsBefore = isRepublish or (oldHash == nil) or (oldHash ~= newHash)

            local afterPath = LrPathUtils.child(afterFolder, filename)
            if LrFileUtils.exists(afterPath) then LrFileUtils.delete(afterPath) end
            LrFileUtils.move(pathOrMsg, afterPath)
            logger:info("publish-after " .. photoName .. ": wrote " .. afterPath)

            if needsBefore then
                logger:info("Develop settings changed, exporting before for " .. photoName)

                local expectedHash = newHash
                local snapshotId = BeforeAfterExport.createSafetySnapshot(catalog, photo)
                if not snapshotId then
                    logger:warn("Could not resolve safety snapshot id for " .. photoName)
                end

                CatalogWrite.runWithWriteAccess(catalog, "Apply reset preset for before export", function()
                    photo:applyDevelopPreset(resetPreset)
                end)

                local beforeExportParams = {
                    LR_export_destinationType = "specificFolder",
                    LR_export_destinationPathPrefix = beforeFolder,
                    LR_export_useSubfolder = false,
                    LR_format = publishSettings.LR_format or "JPEG",
                    LR_jpeg_quality = publishSettings.LR_jpeg_quality or 1,
                    LR_export_colorSpace = publishSettings.LR_export_colorSpace or "sRGB",
                    LR_size_doConstrain = publishSettings.LR_size_doConstrain or false,
                    LR_size_maxHeight = publishSettings.LR_size_maxHeight or 9999,
                    LR_size_maxWidth = publishSettings.LR_size_maxWidth or 9999,
                    LR_size_resizeType = publishSettings.LR_size_resizeType or "longEdge",
                    LR_collisionHandling = "overwrite",
                    LR_export_bitDepth = publishSettings.LR_export_bitDepth or 8,
                    LR_reimportExportedPhoto = false,
                    LR_outputSharpeningOn = publishSettings.LR_outputSharpeningOn or false,
                    LR_useWatermark = false,
                }

                local beforeSession = LrExportSession({ photosToExport = { photo }, exportSettings = beforeExportParams })
                for _, bRendition in beforeSession:renditions() do
                    local bSuccess, bPath = bRendition:waitForRender()
                    if bSuccess then
                        local beforePath = LrPathUtils.child(beforeFolder, filename)
                        if bPath ~= beforePath then
                            if LrFileUtils.exists(beforePath) then LrFileUtils.delete(beforePath) end
                            LrFileUtils.move(bPath, beforePath)
                        end
                        logger:info("publish-before " .. photoName .. ": wrote " .. beforePath)
                    else
                        logger:error("Before render failed for " .. photoName .. ": " .. tostring(bPath))
                    end
                end

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

            else
                logger:info("Skipping before for " .. photoName .. " (first publish, develop unchanged)")
            end

            rendition:recordPublishedPhotoId(encodeRemoteId(filename, newHash))
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
        local filename = decodeRemoteId(remoteId)
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
        defaultCollectionCanBeDeleted = false,
        canAddCollection = true,
        maxCollectionSetDepth = 0,
    }
end

return provider
