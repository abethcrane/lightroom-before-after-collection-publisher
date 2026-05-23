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

local function buildBeforeExportParams(exportSettings, destDir)
    return {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = destDir,
        LR_export_useSubfolder = false,
        LR_format = exportSettings.LR_format or "JPEG",
        LR_jpeg_quality = exportSettings.LR_jpeg_quality or 0.85,
        LR_export_colorSpace = exportSettings.LR_export_colorSpace or "sRGB",
        LR_size_doConstrain = exportSettings.LR_size_doConstrain or false,
        LR_size_maxHeight = exportSettings.LR_size_maxHeight or 9999,
        LR_size_maxWidth = exportSettings.LR_size_maxWidth or 9999,
        LR_size_resizeType = exportSettings.LR_size_resizeType or "longEdge",
        LR_collisionHandling = "overwrite",
        LR_export_bitDepth = exportSettings.LR_export_bitDepth or 8,
        LR_reimportExportedPhoto = false,
        LR_outputSharpeningOn = exportSettings.LR_outputSharpeningOn or false,
        LR_useWatermark = false,
    }
end

function provider.processRenderedPhotos(functionContext, exportContext)
    local catalog = LrApplication.activeCatalog()
    local exportSettings = exportContext.propertyTable
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

    local restoreFailures = {}
    local successCount = 0
    local errorCount = 0

    for _, rendition in exportContext:renditions({ stopIfCanceled = true, progressScope = progressScope }) do
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
            local snapshotId = BeforeAfterExport.createSafetySnapshot(catalog, photo)
            if not snapshotId then
                logger:warn("Could not resolve safety snapshot id for " .. photoName)
            end

            local afterPath = BeforeAfterExport.renameRendition(pathOrMsg, photo, afterSuffix)
            logger:info("export-after " .. photoName .. ": wrote " .. afterPath)

            CatalogWrite.runWithWriteAccess(catalog, "Apply reset preset for before export", function()
                photo:applyDevelopPreset(resetPreset)
            end)

            local destDir = LrPathUtils.parent(afterPath)
            local beforeExportParams = buildBeforeExportParams(exportSettings, destDir)
            local beforeSession = LrExportSession({
                photosToExport = { photo },
                exportSettings = beforeExportParams,
            })

            local beforeOk = true
            local beforeErr = nil
            for _, bRendition in beforeSession:renditions({ progressScope = progressScope }) do
                local bSuccess, bPath = bRendition:waitForRender()
                if bSuccess then
                    local beforePath = BeforeAfterExport.renameRendition(bPath, photo, beforeSuffix)
                    logger:info("export-before " .. photoName .. ": wrote " .. beforePath)
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

            if beforeOk and restoreOk then
                successCount = successCount + 1
            else
                errorCount = errorCount + 1
                if not beforeOk then
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

    if errorCount > 0 and successCount == 0 then
        LrDialogs.message(
            "Export Before & After",
            "Export failed for " .. errorCount .. " photo(s). See the plugin log for details.",
            "critical"
        )
    end
end

return provider
