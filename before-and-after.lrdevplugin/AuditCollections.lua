local AuditCollections = {}

AuditCollections.COLLECTION_SET = "Before & After"
AuditCollections.METADATA_COLLECTION = "Metadata Issues"
AuditCollections.RESTORE_COLLECTION = "Restore Failures"

local CatalogWrite = require "CatalogWrite"

local function findCollectionSet(catalog, name)
    for _, cs in ipairs(catalog:getChildCollectionSets()) do
        if cs:getName() == name then return cs end
    end
    return nil
end

local function findCollection(parent, name)
    if not parent then return nil end
    for _, c in ipairs(parent:getChildCollections()) do
        if c:getName() == name then return c end
    end
    return nil
end

local function ensureCollectionSet(catalog)
    local collectionSet = findCollectionSet(catalog, AuditCollections.COLLECTION_SET)
    if collectionSet then return collectionSet end

    CatalogWrite.runWithWriteAccess(catalog, "Create audit collection set", function()
        catalog:createCollectionSet(AuditCollections.COLLECTION_SET, nil, true)
    end)
    return findCollectionSet(catalog, AuditCollections.COLLECTION_SET)
end

local function ensureCollection(catalog, collectionSet, collectionName)
    local collection = findCollection(collectionSet, collectionName)
    if collection then return collection end

    CatalogWrite.runWithWriteAccess(catalog, "Create audit collection", function()
        catalog:createCollection(collectionName, collectionSet, true)
    end)
    return findCollection(collectionSet, collectionName)
end

function AuditCollections.updateCollection(catalog, collectionName, photos)
    local collectionSet = ensureCollectionSet(catalog)
    if not collectionSet then
        return false
    end

    local collection = ensureCollection(catalog, collectionSet, collectionName)
    if not collection then
        return false
    end

    local existing = collection:getPhotos()
    return CatalogWrite.runWithWriteAccess(catalog, "Update " .. collectionName .. " collection", function()
        if #existing > 0 then
            collection:removePhotos(existing)
        end
        if #photos > 0 then
            collection:addPhotos(photos)
        end
    end)
end

return AuditCollections
