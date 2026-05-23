local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrProgressScope = import "LrProgressScope"

local ReportPaths = require "ReportPaths"

local logger = LrLogger("BeforeAfterAudit")
logger:enable("logfile")

local COLLECTION_SET_NAME = "Before & After"
local COLLECTION_NAME = "Metadata Issues"

local function getRequiredCreator()
    local catalog = LrApplication.activeCatalog()
    local publishServices = catalog:getPublishServices(_PLUGIN.id)
    if publishServices then
        for _, service in ipairs(publishServices) do
            local settings = service:getPublishSettings()
            if settings and settings.requiredCreator and settings.requiredCreator ~= "" then
                return settings.requiredCreator
            end
        end
    end
    return nil
end

local function validatePhoto(photo, requiredCreator)
    local issues = {}
    local title = photo:getFormattedMetadata("title")
    if not title or title == "" then
        table.insert(issues, "missing title")
    end
    local camera = photo:getFormattedMetadata("cameraModel")
    if not camera or camera == "" then
        table.insert(issues, "missing camera model")
    end
    if requiredCreator then
        local creator = photo:getFormattedMetadata("creator")
        if creator ~= requiredCreator then
            table.insert(issues, "creator is '" .. tostring(creator) .. "', expected '" .. requiredCreator .. "'")
        end
    end
    return issues
end

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

LrFunctionContext.postAsyncTaskWithContext("AuditMetadata", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local catalog = LrApplication.activeCatalog()

    local progressScope = LrProgressScope({
        title = "Auditing metadata...",
        functionContext = context,
    })

    local activeSources = catalog:getActiveSources()
    local allPhotos = {}

    if activeSources and #activeSources > 0 then
        for _, source in ipairs(activeSources) do
            if source.getPhotos then
                for _, p in ipairs(source:getPhotos()) do
                    table.insert(allPhotos, p)
                end
            end
        end
    end

    if #allPhotos == 0 then
        local selected = catalog:getTargetPhotos()
        if selected and #selected > 0 then
            allPhotos = selected
        end
    end

    if #allPhotos == 0 then
        progressScope:done()
        LrDialogs.message("Audit Metadata", "No photos found. Select a collection or some photos first.", "warning")
        return
    end

    local requiredCreator = getRequiredCreator()
    local total = #allPhotos
    local flaggedPhotos = {}
    local reportLines = {}

    local counts = { title = 0, camera = 0, creator = 0 }

    for i, photo in ipairs(allPhotos) do
        if progressScope:isCanceled() then break end
        progressScope:setPortionComplete(i, total)

        local issues = validatePhoto(photo, requiredCreator)
        if #issues > 0 then
            table.insert(flaggedPhotos, photo)
            local name = photo:getFormattedMetadata("fileName")
            local line = name .. ": " .. table.concat(issues, ", ")
            table.insert(reportLines, line)
            for _, issue in ipairs(issues) do
                if issue == "missing title" then counts.title = counts.title + 1 end
                if issue == "missing camera model" then counts.camera = counts.camera + 1 end
                if issue:find("creator is") then counts.creator = counts.creator + 1 end
            end
        end
    end

    progressScope:setCaption("Updating collection...")
    progressScope:setPortionComplete(0, 1)

    local collectionSet = findCollectionSet(catalog, COLLECTION_SET_NAME)
    if not collectionSet then
        catalog:withWriteAccessDo("Create audit collection set", function()
            catalog:createCollectionSet(COLLECTION_SET_NAME, nil, true)
        end)
        collectionSet = findCollectionSet(catalog, COLLECTION_SET_NAME)
    end

    local collection = findCollection(collectionSet, COLLECTION_NAME)
    if not collection then
        catalog:withWriteAccessDo("Create audit collection", function()
            catalog:createCollection(COLLECTION_NAME, collectionSet, true)
        end)
        collection = findCollection(collectionSet, COLLECTION_NAME)
    end

    local existing = collection:getPhotos()
    if #existing > 0 then
        catalog:withWriteAccessDo("Clear old audit results", function()
            collection:removePhotos(existing)
        end)
    end

    if #flaggedPhotos > 0 then
        catalog:withWriteAccessDo("Add flagged photos to audit collection", function()
            collection:addPhotos(flaggedPhotos)
        end)
    end

    progressScope:setCaption("Writing report...")

    local reportDir = ReportPaths.getReportDir()
    local timestamp = os.date("%Y-%m-%d-%H-%M-%S")
    local reportPath = LrPathUtils.child(reportDir, "metadata-audit-" .. timestamp .. ".txt")

    local header = string.format(
        "Metadata Audit — %s\n" ..
        "Total photos scanned: %d\n" ..
        "Photos with issues: %d\n" ..
        "  Missing title: %d\n" ..
        "  Missing camera model: %d\n" ..
        "  Wrong/missing creator: %d\n" ..
        "---\n",
        os.date("%Y-%m-%d %H:%M:%S"),
        total, #flaggedPhotos,
        counts.title, counts.camera, counts.creator
    )

    local f = io.open(reportPath, "w")
    if f then
        f:write(header)
        for _, line in ipairs(reportLines) do
            f:write(line .. "\n")
        end
        f:close()
    end

    progressScope:done()

    local summary = string.format(
        "Scanned %d photos, found %d with issues.\n\n" ..
        "  Missing title: %d\n" ..
        "  Missing camera: %d\n" ..
        "  Wrong creator: %d\n\n" ..
        "Collection '%s > %s' updated with flagged photos.\n" ..
        "Report saved to:\n%s",
        total, #flaggedPhotos,
        counts.title, counts.camera, counts.creator,
        COLLECTION_SET_NAME, COLLECTION_NAME,
        reportPath
    )

    LrDialogs.message("Metadata Audit Complete", summary, "info")
end)
