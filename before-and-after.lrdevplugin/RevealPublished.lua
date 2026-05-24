local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrShell = import "LrShell"

local PublishPaths = require "PublishPaths"
local PublishSettingsCache = require "PublishSettingsCache"

local M = {}

local function exportedFilenameFromRemoteId(remoteId)
    return PublishPaths.decodeRemoteId(remoteId)
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

local function foldersConfigured(settings)
    return settings
        and settings.afterFolder and settings.afterFolder ~= ""
        and settings.beforeFolder and settings.beforeFolder ~= ""
end

local function mergeServiceFolderPaths(settings, serviceSettings)
    if not serviceSettings then
        return settings
    end
    if serviceSettings.afterFolder and serviceSettings.afterFolder ~= "" then
        settings.afterFolder = serviceSettings.afterFolder
    end
    if serviceSettings.beforeFolder and serviceSettings.beforeFolder ~= "" then
        settings.beforeFolder = serviceSettings.beforeFolder
    end
    return settings
end

local function fillFolderPathsFromOurServices(catalog, settings, service)
    settings = PublishSettingsCache.getEffectiveSettings(settings, service)
    if foldersConfigured(settings) then
        return settings
    end

    for _, publishService in ipairs(M.findOurPublishServices(catalog)) do
        settings = PublishSettingsCache.getEffectiveSettings(settings, publishService)
        mergeServiceFolderPaths(settings, publishService:getPublishSettings())
        if foldersConfigured(settings) then
            PublishSettingsCache.remember(publishService, settings)
            return settings
        end
    end

    return settings
end

local function resolveCollectionSettings(collection, service)
    local serviceSettings = service and service:getPublishSettings() or {}
    local settings = {}
    for key, value in pairs(serviceSettings) do
        settings[key] = value
    end
    mergeServiceFolderPaths(settings, serviceSettings)

    if foldersConfigured(settings) then
        PublishSettingsCache.remember(service, settings)
        return settings
    end

    if collection and type(collection.getCollectionInfoSummary) == "function" then
        local summary = collection:getCollectionInfoSummary()
        if summary then
            local overlay = summary.publishSettings or summary.collectionSettings
            if overlay then
                for key, value in pairs(overlay) do
                    settings[key] = value
                end
            end
        end
    end

    mergeServiceFolderPaths(settings, serviceSettings)
    PublishSettingsCache.remember(service, settings)
    return settings
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

local function addCollectionEntries(collection, entries)
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
        addCollectionEntries(collection, entries)
    end

    return entries
end

local function findPublishedPhotoInCollection(collection, photo)
    for _, publishedPhoto in ipairs(collection:getPublishedPhotos() or {}) do
        if samePhoto(publishedPhoto:getPhoto(), photo) then
            return publishedPhoto
        end
    end
    return nil
end

local function photoInCollection(collection, photo)
    if findPublishedPhotoInCollection(collection, photo) then
        return true
    end
    if type(collection.getPhotos) == "function" then
        for _, member in ipairs(collection:getPhotos() or {}) do
            if samePhoto(member, photo) then
                return true
            end
        end
    end
    return false
end

local function findOurCollectionContext(collection, photo)
    if not M.isOurPublishedCollection(collection) or not photoInCollection(collection, photo) then
        return nil, nil, nil
    end

    local publishService = collection:getService()
    if not publishService then
        return nil, nil, nil
    end

    return resolveCollectionSettings(collection, publishService),
        findPublishedPhotoInCollection(collection, photo),
        publishService
end

local function findInPublishedTree(node, photo)
    for _, collection in ipairs(node:getChildCollections() or {}) do
        local settings, publishedPhoto, service = findOurCollectionContext(collection, photo)
        if settings ~= nil or publishedPhoto ~= nil then
            return settings, publishedPhoto, service
        end
    end
    for _, childSet in ipairs(node:getChildCollectionSets() or {}) do
        local settings, publishedPhoto, service = findInPublishedTree(childSet, photo)
        if settings ~= nil or publishedPhoto ~= nil then
            return settings, publishedPhoto, service
        end
    end
    return nil, nil, nil
end

local function revealFromPublishedPhoto(publishedPhoto, settings, service, side)
    if not publishedPhoto then
        return false
    end

    settings = PublishSettingsCache.getEffectiveSettings(settings or {}, service)

    if side == "after" then
        local afterPath = publishedPhoto:getRemoteUrl()
        if afterPath and afterPath ~= "" and LrFileUtils.exists(afterPath) then
            LrShell.revealInShell(afterPath)
            return true
        end
    end

    local remoteId = publishedPhoto:getRemoteId()
    local afterPath = publishedPhoto:getRemoteUrl()
    local filename = (afterPath and afterPath ~= "") and LrPathUtils.leafName(afterPath)
        or exportedFilenameFromRemoteId(remoteId)

    if side == "before" and filename and settings.beforeFolder and settings.beforeFolder ~= "" then
        local beforePath = LrPathUtils.child(settings.beforeFolder, filename)
        if LrFileUtils.exists(beforePath) then
            LrShell.revealInShell(beforePath)
            return true
        end
    end

    if remoteId and foldersConfigured(settings) then
        M.revealPublishedSide(settings, remoteId, side)
        return true
    end

    return false
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

function M.revealPublishedSideForPhoto(publishSettings, photo, side)
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

    local afterPath, beforePath, filename = PublishPaths.resolveExportedPair(publishSettings, photo)
    local path = side == "before" and beforePath or afterPath
    if not path or not LrFileUtils.exists(path) then
        LrDialogs.message(
            "Before & After Publish",
            "Exported file not found"
                .. (filename and (":\n" .. LrPathUtils.child(root, filename)) or ".")
                .. "\n\nPublish or sync from disk if files should already exist.",
            "warning"
        )
        return
    end

    LrShell.revealInShell(path)
end

function M.findOurPublishedPhoto(photo)
    local foundSettings = nil
    local foundPublishedPhoto = nil
    local foundService = nil

    local pubs = photo:getContainedPublishedCollections()
    if pubs then
        for _, collection in ipairs(pubs) do
            local settings, publishedPhoto, service = findOurCollectionContext(collection, photo)
            if settings ~= nil or publishedPhoto ~= nil then
                foundSettings = settings
                foundPublishedPhoto = publishedPhoto
                foundService = service
                break
            end
        end
    end

    if foundSettings == nil and foundPublishedPhoto == nil then
        local catalog = LrApplication.activeCatalog()
        for _, publishService in ipairs(M.findOurPublishServices(catalog)) do
            local settings, publishedPhoto, service = findInPublishedTree(publishService, photo)
            if settings ~= nil or publishedPhoto ~= nil then
                foundSettings = settings
                foundPublishedPhoto = publishedPhoto
                foundService = service
                break
            end
        end
    end

    if foundSettings == nil and foundPublishedPhoto == nil then
        return nil, nil, nil
    end

    return foundSettings or {}, foundPublishedPhoto, foundService
end

function M.revealForCatalogPhoto(photo, side)
    local settings, publishedPhoto, service = M.findOurPublishedPhoto(photo)
    if not settings then
        LrDialogs.message(
            "Before & After Publish",
            "This photo is not in any published collection from this plug-in.",
            "warning"
        )
        return
    end

    local catalog = LrApplication.activeCatalog()
    settings = fillFolderPathsFromOurServices(catalog, settings, service)

    if revealFromPublishedPhoto(publishedPhoto, settings, service, side) then
        return
    end

    if not foldersConfigured(settings) then
        LrDialogs.message(
            "Before & After Publish",
            "After/before folder paths are not available.\n\n"
                .. "In Publish Manager, confirm both folder paths and click Done, then try again.",
            "warning"
        )
        return
    end

    M.revealPublishedSideForPhoto(settings, photo, side)
end

return M
