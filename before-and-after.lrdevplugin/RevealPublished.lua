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

local function sameCollection(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if a.localIdentifier and b.localIdentifier then
        return a.localIdentifier == b.localIdentifier
    end
    return false
end

function M.isOurPublishService(service)
    if not service or type(service.getPluginId) ~= "function" then
        return false
    end

    local pid = service:getPluginId()
    if not pid then
        return false
    end
    if pid == _PLUGIN.id then
        return true
    end
    local prefix = _PLUGIN.id .. "."
    return pid:sub(1, #prefix) == prefix
end

function M.isOurPublishedCollection(collection)
    if not collection or type(collection.getService) ~= "function" then
        return false
    end
    return M.isOurPublishService(collection:getService())
end

local function samePhoto(a, b)
    if not a or not b then return false end
    return a.localIdentifier == b.localIdentifier
end

local function resolveCollectionSettings(collection, service)
    local settings = service and service:getPublishSettings()
    if settings and settings.afterFolder and settings.afterFolder ~= ""
        and settings.beforeFolder and settings.beforeFolder ~= "" then
        return settings
    end

    local ok, summary = pcall(function()
        return collection:getCollectionInfoSummary()
    end)
    if ok and summary then
        if summary.publishSettings then
            return summary.publishSettings
        end
        if summary.collectionSettings then
            return summary.collectionSettings
        end
    end

    return settings or {}
end

local function appendCollectionsFromNode(node, collections, seen)
    for _, collection in ipairs(node:getChildCollections() or {}) do
        if M.isOurPublishedCollection(collection) and not seen[collection] then
            seen[collection] = true
            collections[#collections + 1] = collection
        end
    end
    for _, childSet in ipairs(node:getChildCollectionSets() or {}) do
        appendCollectionsFromNode(childSet, collections, seen)
    end
end

local function findOurPublishedCollections(catalog)
    local collections = {}
    local seen = {}
    for _, service in ipairs(M.findOurPublishServices(catalog)) do
        appendCollectionsFromNode(service, collections, seen)
    end
    return collections
end

function M.findOurPublishServices(catalog)
    local ours = {}
    local services = catalog:getPublishServices()
    if not services or #services == 0 then
        services = catalog:getPublishServices(_PLUGIN.id)
    end
    if services then
        for _, service in ipairs(services) do
            if M.isOurPublishService(service) then
                ours[#ours + 1] = service
            end
        end
    end
    return ours
end

function M.findPublishServiceForDialog(catalog, propertyTable)
    local ours = M.findOurPublishServices(catalog)
    if #ours == 0 then
        return nil
    end
    if #ours == 1 then
        return ours[1]
    end

    local afterFolder = propertyTable and propertyTable.afterFolder
    local beforeFolder = propertyTable and propertyTable.beforeFolder
    if afterFolder and afterFolder ~= "" and beforeFolder and beforeFolder ~= "" then
        for _, service in ipairs(ours) do
            local saved = service:getPublishSettings()
            if saved
                and saved.afterFolder == afterFolder
                and saved.beforeFolder == beforeFolder then
                return service
            end
        end
    end

    return ours[1]
end

function M.resolveTargetPublishedCollections(catalog, activeOnly)
    local collections = {}
    local seen = {}

    for _, source in ipairs(catalog:getActiveSources() or {}) do
        if M.isOurPublishedCollection(source) then
            if not seen[source] then
                seen[source] = true
                collections[#collections + 1] = source
            end
        elseif M.isOurPublishService(source) then
            appendCollectionsFromNode(source, collections, seen)
        end
    end

    if activeOnly ~= false and #collections > 0 then
        return collections
    end

    if #collections == 0 then
        return findOurPublishedCollections(catalog)
    end

    return collections
end

local function photoBelongsToCollection(photo, collection)
    local contained = photo:getContainedPublishedCollections()
    if not contained then
        return false
    end
    for _, pc in ipairs(contained) do
        if sameCollection(pc, collection) then
            return true
        end
    end
    return false
end

local function addGridPhotosForCollection(catalog, collection, settings, entries, seen)
    local targets = catalog:getTargetPhotos()
    if not targets or #targets == 0 then
        return 0
    end

    local added = 0
    for _, photo in ipairs(targets) do
        if photo and not seen[photo.localIdentifier] and photoBelongsToCollection(photo, collection) then
            seen[photo.localIdentifier] = true
            entries[#entries + 1] = {
                photo = photo,
                publishedPhoto = nil,
                publishedCollection = collection,
                settings = settings,
            }
            added = added + 1
        end
    end
    return added
end

local function addCollectionEntries(catalog, collection, entries)
    if not M.isOurPublishedCollection(collection) then
        return
    end

    local service = collection:getService()
    if not service then
        return
    end

    local settings = resolveCollectionSettings(collection, service)
    local seen = {}

    local publishedByPhotoId = {}
    for _, publishedPhoto in ipairs(collection:getPublishedPhotos() or {}) do
        local photo = publishedPhoto:getPhoto()
        if photo then
            publishedByPhotoId[photo.localIdentifier] = publishedPhoto
        end
    end

    local photos = {}
    if type(collection.getPhotos) == "function" then
        photos = collection:getPhotos() or {}
    end

    if #photos == 0 then
        for _, publishedPhoto in ipairs(collection:getPublishedPhotos() or {}) do
            local photo = publishedPhoto:getPhoto()
            if photo and not seen[photo.localIdentifier] then
                seen[photo.localIdentifier] = true
                entries[#entries + 1] = {
                    photo = photo,
                    publishedPhoto = publishedPhoto,
                    publishedCollection = collection,
                    settings = settings,
                }
            end
        end
        addGridPhotosForCollection(catalog, collection, settings, entries, seen)
        return
    end

    for _, photo in ipairs(photos) do
        if photo and not seen[photo.localIdentifier] then
            seen[photo.localIdentifier] = true
            entries[#entries + 1] = {
                photo = photo,
                publishedPhoto = publishedByPhotoId[photo.localIdentifier],
                publishedCollection = collection,
                settings = settings,
            }
        end
    end
end

function M.getCollectionsForService(service)
    local collections = {}
    local seen = {}
    if M.isOurPublishService(service) then
        appendCollectionsFromNode(service, collections, seen)
    end
    return collections
end

function M.collectPublishedPhotoEntriesForService(catalog, service)
    local entries = {}
    if not M.isOurPublishService(service) then
        return entries
    end

    for _, collection in ipairs(M.getCollectionsForService(service)) do
        addCollectionEntries(catalog, collection, entries)
    end

    return entries
end

function M.collectPublishedPhotoEntries(catalog, activeOnly)
    local entries = {}
    local collections = M.resolveTargetPublishedCollections(catalog, activeOnly)

    for _, collection in ipairs(collections) do
        addCollectionEntries(catalog, collection, entries)
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
