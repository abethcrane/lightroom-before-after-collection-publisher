local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrShell = import "LrShell"

local PublishPaths = require "PublishPaths"

local M = {}

local function exportedFilenameFromRemoteId(remoteId)
    return PublishPaths.decodeRemoteId(remoteId)
end

function M.isOurPublishService(service)
    if not service then return false end
    local pid = service:getPluginId()
    if pid == _PLUGIN.id then
        return true
    end
    local prefix = _PLUGIN.id .. "."
    return pid:sub(1, #prefix) == prefix
end

function M.isOurPublishedCollection(collection)
    return M.isOurPublishService(collection:getService())
end

local function samePhoto(a, b)
    if not a or not b then return false end
    return a.localIdentifier == b.localIdentifier
end

local function addCollectionEntries(collection, entries)
    if not M.isOurPublishedCollection(collection) then
        return
    end
    local settings = collection:getService():getPublishSettings()
    local publishedById = {}
    for _, publishedPhoto in ipairs(collection:getPublishedPhotos()) do
        local photo = publishedPhoto:getPhoto()
        if photo then
            publishedById[photo.localIdentifier] = publishedPhoto
        end
    end

    local photosToScan = {}
    if collection.getPhotos then
        photosToScan = collection:getPhotos() or {}
    end
    if #photosToScan == 0 then
        for _, publishedPhoto in pairs(publishedById) do
            local photo = publishedPhoto:getPhoto()
            if photo then
                photosToScan[#photosToScan + 1] = photo
            end
        end
    end

    for _, photo in ipairs(photosToScan) do
        local publishedPhoto = publishedById[photo.localIdentifier]
        if publishedPhoto then
            entries[#entries + 1] = {
                photo = photo,
                publishedPhoto = publishedPhoto,
                settings = settings,
            }
        end
    end
end

local function walkPublishedTree(node, entries)
    for _, collection in ipairs(node:getChildCollections() or {}) do
        addCollectionEntries(collection, entries)
    end
    for _, childSet in ipairs(node:getChildCollectionSets() or {}) do
        walkPublishedTree(childSet, entries)
    end
end

function M.collectPublishedPhotoEntries(catalog, activeOnly)
    local entries = {}

    if activeOnly ~= false then
        for _, source in ipairs(catalog:getActiveSources() or {}) do
            if source.getPublishedPhotos then
                addCollectionEntries(source, entries)
            end
        end
        if #entries > 0 then
            return entries
        end
    end

    local services = catalog:getPublishServices(_PLUGIN.id)
    if services then
        for _, service in ipairs(services) do
            if M.isOurPublishService(service) then
                walkPublishedTree(service, entries)
            end
        end
    end

    return entries
end

--- Recursively walk an LrPublishService or LrPublishedCollectionSet tree.
local function findInPublishedTree(node, photo)
    for _, pc in ipairs(node:getChildCollections() or {}) do
        for _, pp in ipairs(pc:getPublishedPhotos()) do
            if samePhoto(pp:getPhoto(), photo) then
                return pc:getService():getPublishSettings(), pp
            end
        end
    end
    for _, childSet in ipairs(node:getChildCollectionSets() or {}) do
        local settings, publishedPhoto = findInPublishedTree(childSet, photo)
        if settings then
            return settings, publishedPhoto
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

function M.findOurPublishedPhoto(photo)
    local pubs = photo:getContainedPublishedCollections()
    if pubs then
        for _, pc in ipairs(pubs) do
            local svc = pc:getService()
            if M.isOurPublishService(svc) then
                for _, pp in ipairs(pc:getPublishedPhotos()) do
                    if samePhoto(pp:getPhoto(), photo) then
                        return svc:getPublishSettings(), pp
                    end
                end
            end
        end
    end

    local catalog = LrApplication.activeCatalog()
    local services = catalog:getPublishServices(_PLUGIN.id)
    if services then
        for _, svc in ipairs(services) do
            if M.isOurPublishService(svc) then
                local settings, publishedPhoto = findInPublishedTree(svc, photo)
                if settings then
                    return settings, publishedPhoto
                end
            end
        end
    end

    return nil, nil
end

function M.findOurPublishContext(photo)
    local settings, publishedPhoto = M.findOurPublishedPhoto(photo)
    if not settings then
        return nil, nil
    end
    return settings, publishedPhoto:getRemoteId()
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
