local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrProgressScope = import "LrProgressScope"
local LrTasks = import "LrTasks"

local logger = LrLogger("BeforeAfterAudit")
logger:enable("logfile")

local COLLECTION_SET_NAME = "Before & After"
local COLLECTION_NAME = "Metadata Issues"
local REQUIRED_CREATOR = "Beth Crane"

local function validatePhoto(photo)
    local issues = {}
    local title = photo:getFormattedMetadata("title")
    if not title or title == "" then
        table.insert(issues, "missing title")
    end
    local camera = photo:getFormattedMetadata("cameraModel")
    if not camera or camera == "" then
        table.insert(issues, "missing camera model")
    end
    local creator = photo:getFormattedMetadata("creator")
    if creator ~= REQUIRED_CREATOR then
        table.insert(issues, "creator is '" .. tostring(creator) .. "', expected '" .. REQUIRED_CREATOR .. "'")
    end
    return issues
end

local function findOrCreateCollectionSet(catalog, name)
    for _, cs in ipairs(catalog:getChildCollectionSets()) do
        if cs:getName() == name then return cs end
    end
    local cs = catalog:createCollectionSet(name, nil, true)
    return cs
end

local function findOrCreateCollection(catalog, name, parent)
    local children
    if parent then
        children = parent:getChildCollections()
    else
        children = catalog:getChildCollections()
    end
    for _, c in ipairs(children) do
        if c:getName() == name then return c end
    end
    local c = catalog:createCollection(name, parent, true)
    return c
end

LrFunctionContext.postAsyncTaskWithContext("AuditMetadata", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local catalog = LrApplication.activeCatalog()

    local progressScope = LrProgressScope({
        title = "Auditing metadata...",
        functionContext = context,
    })

    local allPhotos = catalog:getAllPhotos()
    local total = #allPhotos
    local flaggedPhotos = {}
    local reportLines = {}

    local counts = { title = 0, camera = 0, creator = 0 }

    for i, photo in ipairs(allPhotos) do
        if progressScope:isCanceled() then break end
        progressScope:setPortionComplete(i, total)

        local issues = validatePhoto(photo)
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

    catalog:withWriteAccessDo("Audit metadata — update collection", function()
        local collectionSet = findOrCreateCollectionSet(catalog, COLLECTION_SET_NAME)
        local collection = findOrCreateCollection(catalog, COLLECTION_NAME, collectionSet)

        local existing = collection:getPhotos()
        if #existing > 0 then
            collection:removePhotos(existing)
        end

        if #flaggedPhotos > 0 then
            collection:addPhotos(flaggedPhotos)
        end
    end)

    progressScope:setCaption("Writing report...")

    local reportDir = LrPathUtils.child(_PLUGIN.path, "reports")
    if not LrFileUtils.exists(reportDir) then
        LrFileUtils.createAllDirectories(reportDir)
    end

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
