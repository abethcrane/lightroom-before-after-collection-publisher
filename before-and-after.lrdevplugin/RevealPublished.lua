local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrShell = import "LrShell"

local REMOTE_ID_SEP = "::"

local M = {}

local function exportedFilenameFromRemoteId(remoteId)
    if not remoteId then
        return nil
    end
    local sep = remoteId:find(REMOTE_ID_SEP, 1, true)
    if sep then
        return remoteId:sub(1, sep - 1)
    end
    return remoteId
end

local function isOurPublishService(service)
    local pid = service:getPluginId()
    if pid == _PLUGIN.id then
        return true
    end
    local prefix = _PLUGIN.id .. "."
    return pid:sub(1, #prefix) == prefix
end

--- Recursively walk an LrPublishService or LrPublishedCollectionSet tree.
local function findInPublishedTree(node, photo)
    for _, pc in ipairs(node:getChildCollections() or {}) do
        for _, pp in ipairs(pc:getPublishedPhotos()) do
            if pp:getPhoto() == photo then
                return pc:getService():getPublishSettings(), pp:getRemoteId()
            end
        end
    end
    for _, childSet in ipairs(node:getChildCollectionSets() or {}) do
        local settings, rid = findInPublishedTree(childSet, photo)
        if settings then
            return settings, rid
        end
    end
    return nil, nil
end

--- @param side "after"|"before"
function M.revealPublishedSide(publishSettings, remoteId, side)
    local folderKey = side == "before" and "beforeFolder" or "afterFolder"
    local root = publishSettings[folderKey]
    if not root or root == "" then
        LrDialogs.message(
            "Before & After Publish",
            'Please configure the "' .. folderKey .. '" path in Publish Manager.',
            "warning"
        )
        return
    end

    local filename = exportedFilenameFromRemoteId(remoteId)
    if not filename or filename == "" then
        LrDialogs.message("Before & After Publish", "No published remote ID — publish this photo first.", "warning")
        return
    end

    local path = LrPathUtils.child(root, filename)
    if not LrFileUtils.exists(path) then
        LrDialogs.message(
            "Before & After Publish",
            "Exported file not found:\n" .. path .. "\n\nRepublish from the plug-in collection if you moved or deleted files.",
            "warning"
        )
        return
    end

    LrShell.revealInShell(path)
end

function M.findOurPublishContext(photo)
    -- Standard published collections only (fast path).
    local pubs = photo:getContainedPublishedCollections()
    if pubs then
        for _, pc in ipairs(pubs) do
            local svc = pc:getService()
            if isOurPublishService(svc) then
                for _, pp in ipairs(pc:getPublishedPhotos()) do
                    if pp:getPhoto() == photo then
                        return svc:getPublishSettings(), pp:getRemoteId()
                    end
                end
            end
        end
    end

    -- getContainedPublishedCollections omits *smart* published collections (SDK docs):
    -- scan our publish services' full tree.
    local catalog = LrApplication.activeCatalog()
    local services = catalog:getPublishServices(_PLUGIN.id)
    if services then
        for _, svc in ipairs(services) do
            if isOurPublishService(svc) then
                local settings, rid = findInPublishedTree(svc, photo)
                if settings then
                    return settings, rid
                end
            end
        end
    end

    return nil, nil
end

function M.revealForCatalogPhoto(photo, side)
    local settings, remoteId = M.findOurPublishContext(photo)
    if not settings then
        LrDialogs.message(
            "Before & After Publish",
            "This photo is not in any published collection from this plug-in.",
            "warning"
        )
        return
    end
    M.revealPublishedSide(settings, remoteId, side)
end

return M
