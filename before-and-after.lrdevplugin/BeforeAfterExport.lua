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

function BeforeAfterExport.renameRendition(renditionPath, photo, suffix)
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
