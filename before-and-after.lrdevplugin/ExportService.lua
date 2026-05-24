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
local MetadataValidation = require "MetadataValidation"
local PublishSync = require "PublishSync"
local PublishSettingsCache = require "PublishSettingsCache"
local ResetPreset = require "ResetPreset"
local SyncFromDisk = require "SyncFromDisk"
local SyncSettings = require "SyncSettings"

local logger = LrLogger("BeforeAfterExportService")
logger:enable("logfile")

local provider = {}

provider.exportPresetFields = {
    { key = "afterSuffix", default = "-after" },
    { key = "beforeSuffix", default = "-before" },
}

provider.allowFileFormats = { "JPEG", "TIFF" }
provider.allowColorSpaces = { "sRGB", "Adobe RGB", "ProPhoto RGB" }

function provider.sectionsForTopOfDialog(f, propertyTable)
    return {
        {
            title = "Before & After Naming",
            f:row {
                f:static_text { title = "After suffix:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind("afterSuffix"), width_in_chars = 15 },
            },
            f:row {
                f:static_text { title = "Before suffix:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind("beforeSuffix"), width_in_chars = 15 },
            },
            f:row {
                f:static_text {
                    title = "Exports paired files to the folder above using these suffixes.",
                    fill_horizontal = 1,
                    height_in_lines = 2,
                },
            },
        },
    }
end

function provider.updateExportSettings(exportSettings)
    PublishSettingsCache.remember(nil, exportSettings)
    SyncSettings.mergeCachedFolders(exportSettings)
end

function provider.processRenderedPhotos(functionContext, exportContext)
    if not exportContext then
        return
    end

    if exportContext.publishedCollection or exportContext.publishService then
        if SyncFromDisk.isActive() then
            return PublishSync.run(functionContext, exportContext)
        end
        return
    end

    local catalog = LrApplication.activeCatalog()
    local exportSettings = exportContext.propertyTable
    if not exportSettings then
        LrDialogs.message("Export Before & After", "Missing export settings.", "critical")
        return
    end

    local afterSuffix = exportSettings.afterSuffix or "-after"
    local beforeSuffix = exportSettings.beforeSuffix or "-before"

    local resetPreset = ResetPreset.find()
    if not resetPreset then
        LrDialogs.message("Export Before & After", ResetPreset.missingMessage(), "critical")
        return
    end

    local nPhotos = exportContext.exportSession:countRenditions()
    local progressScope = exportContext:configureProgress({
        title = "Exporting Before & After (" .. nPhotos .. " photos)",
    })

    local renditions = {}
    for _, rendition in exportContext:renditions({ stopIfCanceled = true }) do
        renditions[#renditions + 1] = rendition
    end

    local collisionResolver = BeforeAfterExport.createCollisionResolver(exportSettings)
    local conflicts = BeforeAfterExport.collectRenditionConflicts(
        renditions, afterSuffix, beforeSuffix
    )
    local collisionMode = collisionResolver:resolveBatchConflicts(conflicts)
    logger:info(string.format(
        "Export collision: mode=%s batchConflicts=%d",
        collisionMode, #conflicts
    ))

    local restoreFailures = {}
    local successCount = 0
    local errorCount = 0
    local skipCount = 0

    for _, rendition in ipairs(renditions) do
        if progressScope:isCanceled() then
            break
        end

        local photo = rendition.photo
        local photoName = photo:getFormattedMetadata("fileName")
        progressScope:setCaption("Processing " .. photoName)

        local success, pathOrMsg = rendition:waitForRender()
        if not success then
            errorCount = errorCount + 1
            rendition:uploadFailed(pathOrMsg)
            logger:error("After render failed for " .. photoName .. ": " .. tostring(pathOrMsg))
        else
            local currentSettings = photo:getDevelopSettings()
            local expectedHash = BeforeAfterExport.computeSettingsHash(currentSettings)

            local afterPath, afterSkipped = BeforeAfterExport.renameRendition(
                pathOrMsg, photo, afterSuffix, collisionResolver
            )
            if afterSkipped then
                skipCount = skipCount + 1
                logger:info("Skipped after export for " .. photoName)
            else
            local snapshotId = BeforeAfterExport.createSafetySnapshot(catalog, photo)
            if not snapshotId then
                logger:warn("Could not resolve safety snapshot id for " .. photoName)
            end

            logger:info("export-after " .. photoName .. ": wrote " .. afterPath)

            CatalogWrite.runWithWriteAccess(catalog, "Apply reset preset for before export", function()
                photo:applyDevelopPreset(resetPreset)
            end)

            local destDir = LrPathUtils.parent(afterPath)
            local nestedCollisionMode = collisionResolver:getMode()
            if nestedCollisionMode == "ask" then
                nestedCollisionMode = "overwrite"
            end
            local beforeExportParams = ExportParams.buildBeforeExportParams(
                exportSettings, destDir, nestedCollisionMode
            )
            local beforeSession = LrExportSession({
                photosToExport = { photo },
                exportSettings = beforeExportParams,
            })

            local beforeOk = true
            local beforeErr = nil
            local beforeSkipped = false
            for _, bRendition in beforeSession:renditions({ progressScope = progressScope }) do
                local bSuccess, bPath = bRendition:waitForRender()
                if bSuccess then
                    local beforePath, skipped = BeforeAfterExport.renameRendition(
                        bPath, photo, beforeSuffix, collisionResolver
                    )
                    if skipped then
                        beforeSkipped = true
                        logger:info("Skipped before export for " .. photoName)
                    else
                        logger:info("export-before " .. photoName .. ": wrote " .. beforePath)
                    end
                else
                    beforeOk = false
                    beforeErr = tostring(bPath)
                    logger:error("Before render failed for " .. photoName .. ": " .. beforeErr)
                end
            end

            if LrTasks.canYield() then
                LrTasks.sleep(0.5)
            end

            local restoreOk = BeforeAfterExport.restoreAfterBeforeExport(
                catalog, photo, snapshotId, currentSettings, expectedHash, photoName,
                "Export Before & After", { suppressDialog = true }
            )
            if not restoreOk then
                table.insert(restoreFailures, photo)
            end

            if beforeSkipped and beforeOk then
                skipCount = skipCount + 1
            end

            if beforeOk and restoreOk and not beforeSkipped then
                successCount = successCount + 1
            elseif not beforeOk then
                errorCount = errorCount + 1
                rendition:uploadFailed(beforeErr or "Before export failed")
            end
            end
        end
    end

    if #restoreFailures > 0 then
        AuditCollections.updateCollection(catalog, AuditCollections.RESTORE_COLLECTION, restoreFailures)
        LrDialogs.message(
            "Export Before & After",
            #restoreFailures .. " photo(s) could not be fully restored after exporting the \"before\" version." ..
                "\n\nThey have been added to '" .. AuditCollections.COLLECTION_SET ..
                " > " .. AuditCollections.RESTORE_COLLECTION ..
                "'. Use Undo or snapshot \"" .. BeforeAfterExport.SNAPSHOT_NAME ..
                "\" on each photo if it still looks like the \"before\" version.",
            "warning"
        )
    end

    if skipCount > 0 and successCount > 0 then
        LrDialogs.message(
            "Export Before & After",
            "Exported " .. successCount .. " photo(s), skipped " .. skipCount .. " existing file(s).",
            "info"
        )
    elseif skipCount > 0 and successCount == 0 and errorCount == 0 then
        LrDialogs.message(
            "Export Before & After",
            "Skipped " .. skipCount .. " existing file(s); nothing new was exported.",
            "info"
        )
    end

    if errorCount > 0 and successCount == 0 and skipCount == 0 then
        LrDialogs.message(
            "Export Before & After",
            "Export failed for " .. errorCount .. " photo(s). See the plugin log for details.",
            "critical"
        )
    end
end

return provider
