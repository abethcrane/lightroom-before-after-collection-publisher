local AuditCollections = {}

AuditCollections.COLLECTION_SET = "Before & After"
AuditCollections.METADATA_COLLECTION = "Metadata Issues"
AuditCollections.RESTORE_COLLECTION = "Restore Failures"

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

function AuditCollections.updateCollection(catalog, collectionName, photos)
    local collectionSet = findCollectionSet(catalog, AuditCollections.COLLECTION_SET)
    if not collectionSet then
        catalog:withWriteAccessDo("Create audit collection set", function()
            catalog:createCollectionSet(AuditCollections.COLLECTION_SET, nil, true)
        end)
        collectionSet = findCollectionSet(catalog, AuditCollections.COLLECTION_SET)
    end

    local collection = findCollection(collectionSet, collectionName)
    if not collection then
        catalog:withWriteAccessDo("Create audit collection", function()
            catalog:createCollection(collectionName, collectionSet, true)
        end)
        collection = findCollection(collectionSet, collectionName)
    end

    local existing = collection:getPhotos()
    catalog:withWriteAccessDo("Update " .. collectionName .. " collection", function()
        if #existing > 0 then
            collection:removePhotos(existing)
        end
        if #photos > 0 then
            collection:addPhotos(photos)
        end
    end)
end

return AuditCollections
