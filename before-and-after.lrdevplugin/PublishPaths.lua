local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"

local PublishPaths = {}

PublishPaths.REMOTE_ID_SEP = "::"

function PublishPaths.getFileExtension(format)
    if format == "TIFF" then return "tif" end
    return "jpg"
end

function PublishPaths.getExportFormat(publishSettings)
    return publishSettings.LR_format or publishSettings.format or "JPEG"
end

function PublishPaths.getExportFilename(photo, ext)
    local baseName = LrPathUtils.removeExtension(photo:getFormattedMetadata("fileName"))
    local dateStr = photo:getRawMetadata("dateTimeOriginalISO8601") or ""
    local y, mo, d, h, mi, s = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if y then
        return string.format("%s-%s-%s-%s-%s-%s-%s.%s", y, mo, d, h, mi, s, baseName, ext)
    end
    return baseName .. "." .. ext
end

function PublishPaths.encodeRemoteId(filename, settingsHash)
    return filename .. PublishPaths.REMOTE_ID_SEP .. settingsHash
end

function PublishPaths.decodeRemoteId(remoteId)
    if not remoteId then return nil, nil end
    local sep = remoteId:find(PublishPaths.REMOTE_ID_SEP, 1, true)
    if sep then
        return remoteId:sub(1, sep - 1), remoteId:sub(sep + #PublishPaths.REMOTE_ID_SEP)
    end
    return remoteId, nil
end

function PublishPaths.exportedPaths(publishSettings, photo)
    local ext = PublishPaths.getFileExtension(PublishPaths.getExportFormat(publishSettings))
    local filename = PublishPaths.getExportFilename(photo, ext)
    local afterPath = LrPathUtils.child(publishSettings.afterFolder, filename)
    local beforePath = LrPathUtils.child(publishSettings.beforeFolder, filename)
    return filename, afterPath, beforePath
end

local function photoBaseName(photo)
    return LrPathUtils.removeExtension(photo:getFormattedMetadata("fileName"))
end

function PublishPaths.findExportFileInFolder(folder, photo, ext)
    local filename = PublishPaths.getExportFilename(photo, ext)
    local exact = LrPathUtils.child(folder, filename)
    if LrFileUtils.exists(exact) then
        return exact, filename
    end

    local baseName = photoBaseName(photo)
    local suffix = "-" .. baseName .. "." .. ext
    for file in LrFileUtils.files(folder) do
        if #file >= #suffix and file:sub(-#suffix) == suffix then
            return LrPathUtils.child(folder, file), file
        end
    end

    local plain = LrPathUtils.child(folder, baseName .. "." .. ext)
    if LrFileUtils.exists(plain) then
        return plain, baseName .. "." .. ext
    end

    return nil, filename
end

function PublishPaths.resolveExportedPair(publishSettings, photo)
    local format = PublishPaths.getExportFormat(publishSettings)
    local ext = PublishPaths.getFileExtension(format)
    local afterPath, afterName = PublishPaths.findExportFileInFolder(
        publishSettings.afterFolder, photo, ext
    )
    if not afterPath then
        return nil, nil, afterName
    end

    local beforePath = LrPathUtils.child(publishSettings.beforeFolder, afterName)
    if LrFileUtils.exists(beforePath) then
        return afterPath, beforePath, afterName
    end

    local _, beforeName = PublishPaths.findExportFileInFolder(
        publishSettings.beforeFolder, photo, ext
    )
    if beforeName then
        beforePath = LrPathUtils.child(publishSettings.beforeFolder, beforeName)
        if LrFileUtils.exists(beforePath) then
            return afterPath, beforePath, afterName
        end
    end

    return nil, nil, afterName
end

return PublishPaths
