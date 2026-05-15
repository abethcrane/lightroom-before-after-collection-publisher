local LrApplication = import "LrApplication"
local LrExportSession = import "LrExportSession"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrLogger = import "LrLogger"
local LrErrors = import "LrErrors"

local DevelopDefaults = require "DevelopDefaults"

local logger = LrLogger("BeforeAfterExport")
logger:enable("logfile")

local BeforeAfterExport = {}

local function buildExportParams(options)
    return {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = options.destPath,
        LR_export_useSubfolder = false,
        LR_format = options.format or "JPEG",
        LR_jpeg_quality = options.jpegQuality or 0.85,
        LR_export_colorSpace = options.colorSpace or "sRGB",
        LR_size_doConstrain = options.constrainSize or false,
        LR_size_maxHeight = options.maxDimension or 9999,
        LR_size_maxWidth = options.maxDimension or 9999,
        LR_size_resizeType = "longEdge",
        LR_collisionHandling = "rename",
        LR_export_bitDepth = options.bitDepth or 8,
        LR_reimportExportedPhoto = false,
        LR_removeFaceMetadata = true,
        LR_metadata_keywordOptions = "lightroomHierarchical",
        LR_outputSharpeningOn = false,
        LR_useWatermark = false,
    }
end

local function renameRendition(renditionPath, photo, suffix)
    local dir = LrPathUtils.parent(renditionPath)
    local ext = LrPathUtils.extension(renditionPath)
    local baseName = LrPathUtils.removeExtension(photo:getFormattedMetadata("fileName"))
    local dateStr = photo:getRawMetadata("dateTimeOriginalISO8601") or ""

    local y, mo, d, h, mi, s = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    local prefix = ""
    if y then
        prefix = string.format("%s-%s-%s-%s-%s-%s-", y, mo, d, h, mi, s)
    end
    local newName = prefix .. baseName .. suffix .. "." .. ext
    local newPath = LrPathUtils.child(dir, newName)

    if LrFileUtils.exists(newPath) then
        LrFileUtils.delete(newPath)
    end

    local success = LrFileUtils.move(renditionPath, newPath)
    if not success then
        logger:error("Failed to rename " .. renditionPath .. " -> " .. newPath)
        return renditionPath
    end
    return newPath
end

local function exportSinglePhoto(photo, exportParams, progressScope)
    local session = LrExportSession({
        photosToExport = { photo },
        exportSettings = exportParams,
    })

    local renderedPaths = {}
    for _, rendition in session:renditions({ stopIfCanceled = true }) do
        local success, pathOrMsg = rendition:waitForRender()
        if progressScope and progressScope:isCanceled() then
            LrErrors.throwCanceled()
        end
        if success then
            table.insert(renderedPaths, pathOrMsg)
        else
            logger:error("Render failed for " .. tostring(photo) .. ": " .. tostring(pathOrMsg))
            error("Render failed: " .. tostring(pathOrMsg))
        end
    end
    return renderedPaths
end

function BeforeAfterExport.processPhotos(photos, options, progressScope)
    local catalog = LrApplication.activeCatalog()
    local results = { after = {}, before = {}, errors = {} }
    local total = #photos

    local exportParams = buildExportParams(options)

    for i, photo in ipairs(photos) do
        if progressScope:isCanceled() then
            LrErrors.throwCanceled()
        end

        local photoName = photo:getFormattedMetadata("fileName")
        progressScope:setCaption("Processing " .. photoName .. " (" .. i .. "/" .. total .. ")")
        progressScope:setPortionComplete(((i - 1) * 2), total * 2)

        local currentSettings = photo:getDevelopSettings()
        logger:trace("Saved settings for " .. photoName)

        catalog:withWriteAccessDo("Before/After safety snapshot", function()
            photo:createDevelopSnapshot("Before-After Backup", true)
        end)

        local ok, err = pcall(function()
            logger:trace("Exporting 'after' for " .. photoName)
            local afterPaths = exportSinglePhoto(photo, exportParams, progressScope)
            for _, p in ipairs(afterPaths) do
                local renamed = renameRendition(p, photo, options.afterSuffix or "-after")
                table.insert(results.after, renamed)
                logger:trace("After: " .. renamed)
            end

            progressScope:setPortionComplete(((i - 1) * 2) + 1, total * 2)

            local beforeSettings = DevelopDefaults.buildBeforeSettings(currentSettings)

            catalog:withWriteAccessDo("Apply before settings", function()
                photo:applyDevelopSettings(beforeSettings)
            end)

            logger:trace("Exporting 'before' for " .. photoName)
            local beforePaths = exportSinglePhoto(photo, exportParams, progressScope)
            for _, p in ipairs(beforePaths) do
                local renamed = renameRendition(p, photo, options.beforeSuffix or "-before")
                table.insert(results.before, renamed)
                logger:trace("Before: " .. renamed)
            end
        end)

        catalog:withWriteAccessDo("Restore original settings", function()
            photo:applyDevelopSettings(currentSettings)
        end)
        logger:trace("Restored settings for " .. photoName)

        if not ok then
            logger:error("Error processing " .. photoName .. ": " .. tostring(err))
            table.insert(results.errors, { photo = photoName, error = tostring(err) })
        end

        progressScope:setPortionComplete(i * 2, total * 2)
    end

    return results
end

return BeforeAfterExport
