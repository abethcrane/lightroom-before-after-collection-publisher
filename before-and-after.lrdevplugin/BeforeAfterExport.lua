local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrLogger = import "LrLogger"
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

local function getSetting(exportSettings, lrKey, shortKey)
    return exportSettings[lrKey] or exportSettings[shortKey]
end

function BeforeAfterExport.getExportDestDir(exportSettings)
    local dir = getSetting(exportSettings, "LR_export_destinationPathPrefix", "export_destinationPathPrefix") or ""
    local useSubfolder = getSetting(exportSettings, "LR_export_useSubfolder", "export_useSubfolder")
    local subPath = getSetting(exportSettings, "LR_export_subfolderPath", "export_subfolderPath")
    if useSubfolder and subPath and subPath ~= "" then
        dir = LrPathUtils.child(dir, subPath)
    end
    return dir
end

function BeforeAfterExport.getCollisionMode(exportSettings)
    local mode = getSetting(exportSettings, "LR_collisionHandling", "collisionHandling") or "ask"
    if mode == "ask" or mode == "prompt" or mode == "askEachTime" then
        return "ask"
    end
    if mode == "overwrite" or mode == "overwriteExistingFiles" then
        return "overwrite"
    end
    if mode == "rename" or mode == "renameExistingFiles" or mode == "chooseNewNameForEachFile" then
        return "rename"
    end
    if mode == "skip" or mode == "skipExistingFiles" then
        return "skip"
    end
    return mode
end

function BeforeAfterExport.createCollisionResolver(exportSettings)
    local preferredMode = BeforeAfterExport.getCollisionMode(exportSettings)
    local resolvedMode = nil

    local function promptForConflicts(conflicts)
        local preview = {}
        for i = 1, math.min(5, #conflicts) do
            preview[#preview + 1] = LrPathUtils.leafName(conflicts[i])
        end

        local message = #conflicts .. " before/after file(s) already exist in the export folder."
        if #preview > 0 then
            message = message .. "\n\n" .. table.concat(preview, "\n")
            if #conflicts > #preview then
                message = message .. "\n… and " .. (#conflicts - #preview) .. " more"
            end
        end
        message = message .. "\n\nOverwrite existing files?"

        logger:info(string.format(
            "Collision prompt: preferred=%s conflicts=%d",
            preferredMode, #conflicts
        ))

        local result = LrDialogs.confirm("Files already exist", message, "Overwrite All", "Skip All")
        resolvedMode = result == "ok" and "overwrite" or "skip"
        return resolvedMode
    end

    return {
        preferredMode = preferredMode,

        resolveBatchConflicts = function(self, conflicts)
            if resolvedMode then
                return resolvedMode
            end
            if preferredMode ~= "ask" then
                return preferredMode
            end
            if #conflicts == 0 then
                return "ask"
            end
            return promptForConflicts(conflicts)
        end,

        resolveOnConflict = function(self, conflictPath)
            if resolvedMode then
                return resolvedMode
            end
            if preferredMode ~= "ask" then
                return preferredMode
            end
            logger:info("Collision prompt at rename: " .. conflictPath)
            return promptForConflicts({ conflictPath })
        end,

        getMode = function(self)
            return resolvedMode or preferredMode
        end,
    }
end

function BeforeAfterExport.computeSuffixedPath(destDir, photo, suffix, ext)
    local baseName = LrPathUtils.removeExtension(photo:getFormattedMetadata("fileName"))
    local dateStr = photo:getRawMetadata("dateTimeOriginalISO8601") or ""

    local y, mo, d, h, mi, s = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    local prefix = ""
    if y then
        prefix = string.format("%s-%s-%s-%s-%s-%s-", y, mo, d, h, mi, s)
    end
    return LrPathUtils.child(destDir, prefix .. baseName .. suffix .. "." .. ext)
end

local function uniquePath(path)
    if not LrFileUtils.exists(path) then
        return path
    end

    local dir = LrPathUtils.parent(path)
    local leaf = LrPathUtils.leafName(path)
    local base = LrPathUtils.removeExtension(leaf)
    local ext = LrPathUtils.extension(leaf)

    local n = 2
    while true do
        local candidate = LrPathUtils.child(dir, base .. "-" .. n .. "." .. ext)
        if not LrFileUtils.exists(candidate) then
            return candidate
        end
        n = n + 1
    end
end

function BeforeAfterExport.collectRenditionConflicts(renditions, afterSuffix, beforeSuffix)
    local conflicts = {}
    local seen = {}

    local function addConflict(path)
        if path and path ~= "" and LrFileUtils.exists(path) and not seen[path] then
            seen[path] = true
            conflicts[#conflicts + 1] = path
        end
    end

    for _, rendition in ipairs(renditions) do
        local destPath = rendition.destinationPath
        if destPath and destPath ~= "" then
            local photo = rendition.photo
            local dir = LrPathUtils.parent(destPath)
            local ext = LrPathUtils.extension(destPath)
            addConflict(BeforeAfterExport.computeSuffixedPath(dir, photo, afterSuffix, ext))
            addConflict(BeforeAfterExport.computeSuffixedPath(dir, photo, beforeSuffix, ext))
        end
    end

    return conflicts
end

function BeforeAfterExport.renameRendition(renditionPath, photo, suffix, collisionResolver)
    local dir = LrPathUtils.parent(renditionPath)
    local ext = LrPathUtils.extension(renditionPath)
    local newPath = BeforeAfterExport.computeSuffixedPath(dir, photo, suffix, ext)

    if newPath == renditionPath then
        return newPath, false
    end

    if LrFileUtils.exists(newPath) then
        local collisionMode = collisionResolver:getMode()
        if collisionMode == "ask" then
            collisionMode = collisionResolver:resolveOnConflict(newPath)
        end

        if collisionMode == "rename" then
            newPath = uniquePath(newPath)
        elseif collisionMode == "skip" then
            if LrFileUtils.exists(renditionPath) then
                LrFileUtils.delete(renditionPath)
            end
            logger:info("Skipped existing file: " .. newPath)
            return nil, true
        else
            LrFileUtils.delete(newPath)
        end
    end

    local success = LrFileUtils.move(renditionPath, newPath)
    if not success then
        logger:error("Failed to rename " .. renditionPath .. " -> " .. newPath)
        return renditionPath, false
    end
    return newPath, false
end

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

return BeforeAfterExport
