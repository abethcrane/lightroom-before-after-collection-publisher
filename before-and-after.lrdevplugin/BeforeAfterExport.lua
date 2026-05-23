local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrExportSession = import "LrExportSession"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrLogger = import "LrLogger"
local LrErrors = import "LrErrors"
local LrTasks = import "LrTasks"

local AuditCollections = require "AuditCollections"
local CatalogWrite = require "CatalogWrite"
local ResetPreset = require "ResetPreset"

local logger = LrLogger("BeforeAfterExport")
logger:enable("logfile")
logger:enable("print")

local SNAPSHOT_NAME = "Before-After Backup"

local BeforeAfterExport = {}

BeforeAfterExport.SNAPSHOT_NAME = SNAPSHOT_NAME

function BeforeAfterExport.computeSettingsHash(settings)
    local parts = {}
    for k, v in pairs(settings) do
        if type(v) ~= "table" then
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    local str = table.concat(parts, ";")
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2147483647
    end
    return tostring(hash)
end

local function findSnapshotId(photo, snapshotName)
    for _, snap in ipairs(photo:getDevelopSnapshots()) do
        if snap.name == snapshotName then
            return snap.snapshotID
        end
    end
    return nil
end

function BeforeAfterExport.createSafetySnapshot(catalog, photo)
    local ok = CatalogWrite.runWithWriteAccess(catalog, "Before/After safety snapshot", function()
        photo:createDevelopSnapshot(SNAPSHOT_NAME, true)
    end)
    if not ok then return nil end
    return findSnapshotId(photo, SNAPSHOT_NAME)
end

local function applyRestore(catalog, photo, snapshotId, fallbackSettings, label)
    return CatalogWrite.runWithWriteAccess(catalog, label, function()
        if snapshotId then
            photo:applyDevelopSnapshot(snapshotId)
        else
            photo:applyDevelopSettings(fallbackSettings)
        end
    end)
end

function BeforeAfterExport.restoreAfterBeforeExport(catalog, photo, snapshotId, fallbackSettings, expectedHash, photoName, dialogTitle, options)
    options = options or {}
    if LrTasks.canYield() then
        LrTasks.sleep(0.2)
    end

    local function attempt(useSnapshot, suffix)
        local label = useSnapshot and "Restore develop snapshot" or "Restore develop settings"
        if suffix then
            label = label .. " " .. suffix
        end
        if LrTasks.canYield() then
            return applyRestore(catalog, photo, useSnapshot and snapshotId or nil, fallbackSettings, label)
        end
        return CatalogWrite.runWithWriteAccessAsync(
            catalog, label,
            function()
                if useSnapshot and snapshotId then
                    photo:applyDevelopSnapshot(snapshotId)
                else
                    photo:applyDevelopSettings(fallbackSettings)
                end
            end
        )
    end

    local restoreOk = attempt(snapshotId ~= nil)
    if not restoreOk then
        if LrTasks.canYield() then
            LrTasks.sleep(0.75)
        end
        restoreOk = attempt(snapshotId ~= nil, "(retry)")
    end

    if not restoreOk and snapshotId and fallbackSettings then
        logger:warn(string.format(
            "Snapshot restore failed for %s, trying applyDevelopSettings fallback",
            photoName
        ))
        restoreOk = attempt(false, "(fallback)")
    end

    local restoredHash = expectedHash and BeforeAfterExport.computeSettingsHash(photo:getDevelopSettings()) or nil
    local hashMatch = expectedHash == nil or restoredHash == expectedHash

    if restoreOk and not hashMatch and snapshotId and fallbackSettings then
        logger:warn(string.format(
            "Snapshot restore hash mismatch for %s, trying applyDevelopSettings fallback",
            photoName
        ))
        restoreOk = attempt(false, "(fallback)")
        restoredHash = BeforeAfterExport.computeSettingsHash(photo:getDevelopSettings())
        hashMatch = restoredHash == expectedHash
    end

    if expectedHash then
        logger:info(string.format(
            "Hash post-restore %s: expected=%s actual=%s match=%s restoreOk=%s",
            photoName, expectedHash, restoredHash, tostring(hashMatch), tostring(restoreOk)
        ))
    end

    local fullyRestored = restoreOk and hashMatch
    if not fullyRestored and not options.suppressDialog then
        LrDialogs.message(
            dialogTitle or "Before & After",
            "Could not fully restore develop settings for \"" .. photoName ..
                "\". Use Undo or snapshot \"" .. SNAPSHOT_NAME ..
                "\" if the photo still looks like the \"before\" version." ..
                "\n\nFailed photos from this run are added to '" ..
                AuditCollections.COLLECTION_SET .. " > " .. AuditCollections.RESTORE_COLLECTION .. "'.",
            "critical"
        )
    end

    return fullyRestored, restoredHash
end

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
    for _, rendition in session:renditions({
        stopIfCanceled = true,
        progressScope = progressScope,
    }) do
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

    local resetPreset = ResetPreset.find()
    if not resetPreset then
        LrDialogs.message("Export Before & After", ResetPreset.missingMessage(), "critical")
        return results
    end

    local exportParams = buildExportParams(options)
    local restoreFailures = {}

    for i, photo in ipairs(photos) do
        if progressScope:isCanceled() then
            LrErrors.throwCanceled()
        end

        local photoName = photo:getFormattedMetadata("fileName")
        progressScope:setCaption("Processing " .. photoName .. " (" .. i .. "/" .. total .. ")")
        progressScope:setPortionComplete(((i - 1) * 2), total * 2)

        local currentSettings = photo:getDevelopSettings()
        local expectedHash = BeforeAfterExport.computeSettingsHash(currentSettings)
        local snapshotId = BeforeAfterExport.createSafetySnapshot(catalog, photo)
        if not snapshotId then
            logger:warn("Could not resolve safety snapshot id for " .. photoName)
        end

        local ok, err = pcall(function()
            local afterPaths = exportSinglePhoto(photo, exportParams, progressScope)
            for _, p in ipairs(afterPaths) do
                local renamed = renameRendition(p, photo, options.afterSuffix or "-after")
                table.insert(results.after, renamed)
            end

            progressScope:setPortionComplete(((i - 1) * 2) + 1, total * 2)

            CatalogWrite.runWithWriteAccess(catalog, "Apply reset preset for before", function()
                photo:applyDevelopPreset(resetPreset)
            end)

            local beforePaths = exportSinglePhoto(photo, exportParams, progressScope)
            for _, p in ipairs(beforePaths) do
                local renamed = renameRendition(p, photo, options.beforeSuffix or "-before")
                table.insert(results.before, renamed)
            end
        end)

        local restoreOk = BeforeAfterExport.restoreAfterBeforeExport(
            catalog, photo, snapshotId, currentSettings, expectedHash, photoName, "Export Before & After"
        )
        if not restoreOk then
            table.insert(restoreFailures, photo)
        end

        if not ok then
            logger:error("Error processing " .. photoName .. ": " .. tostring(err))
            table.insert(results.errors, { photo = photoName, error = tostring(err) })
        end

        progressScope:setPortionComplete(i * 2, total * 2)
    end

    if #restoreFailures > 0 then
        AuditCollections.updateCollection(catalog, AuditCollections.RESTORE_COLLECTION, restoreFailures)
    end

    return results
end

return BeforeAfterExport
