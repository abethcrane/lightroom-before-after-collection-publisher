local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"

local BeforeAfterExport = require "BeforeAfterExport"
local CatalogWrite = require "CatalogWrite"
local PublishPaths = require "PublishPaths"
local RevealPublished = require "RevealPublished"

local logger = LrLogger("MarkPublishedUpToDate")
logger:enable("logfile")

local function collectEntries(catalog)
    local selected = catalog:getTargetPhotos()
    if selected and #selected > 0 then
        local allEntries = RevealPublished.collectPublishedPhotoEntries(catalog, false)
        local byId = {}
        for _, entry in ipairs(allEntries) do
            byId[entry.photo.localIdentifier] = entry
        end

        local entries = {}
        for _, photo in ipairs(selected) do
            local entry = byId[photo.localIdentifier]
            if entry then
                entries[#entries + 1] = entry
            end
        end
        return entries
    end

    return RevealPublished.collectPublishedPhotoEntries(catalog, true)
end

LrFunctionContext.postAsyncTaskWithContext("MarkPublishedUpToDate", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local catalog = LrApplication.activeCatalog()
    local entries = collectEntries(catalog)
    if #entries == 0 then
        LrDialogs.message(
            "Before & After Publish",
            "Open a Before & After publish collection (e.g. website photos), or select "
                .. "photos from one, then run this command again.",
            "warning"
        )
        return
    end

    logger:info("Mark as up to date: " .. #entries .. " published photo(s) to check")

    local synced = 0
    local missing = {}
    local skipped = 0

    CatalogWrite.doWrite(catalog, "Mark published photos up to date", function()
        for _, entry in ipairs(entries) do
            local publishSettings = entry.settings
            local photo = entry.photo
            local publishedPhoto = entry.publishedPhoto

            if not publishSettings.afterFolder or publishSettings.afterFolder == ""
                or not publishSettings.beforeFolder or publishSettings.beforeFolder == "" then
                skipped = skipped + 1
            else
                local afterPath, beforePath, filename = PublishPaths.resolveExportedPair(
                    publishSettings, photo
                )
                if not afterPath or not beforePath then
                    missing[#missing + 1] = photo:getFormattedMetadata("fileName")
                        .. " (expected " .. tostring(filename) .. ")"
                    logger:info("Missing pair for " .. tostring(filename))
                else
                    local hash = BeforeAfterExport.computeSettingsHash(photo:getDevelopSettings())
                    publishedPhoto:setRemoteId(PublishPaths.encodeRemoteId(filename, hash))
                    publishedPhoto:setRemoteUrl(afterPath)
                    publishedPhoto:setEditedFlag(false)
                    synced = synced + 1
                end
            end
        end
    end)

    logger:info(string.format(
        "Mark as up to date done: synced=%d missing=%d skipped=%d",
        synced, #missing, skipped
    ))

    local lines = { synced .. " photo(s) marked as up to date (synced from disk)." }
    if #missing > 0 then
        local preview = table.concat(missing, "\n", 1, math.min(5, #missing))
        if #missing > 5 then
            preview = preview .. "\n… and " .. (#missing - 5) .. " more"
        end
        lines[#lines + 1] = #missing .. " skipped — after/before file pair missing on disk:\n" .. preview
    end
    if skipped > 0 then
        lines[#lines + 1] = skipped .. " skipped — publish service folders not configured."
    end

    LrDialogs.message("Before & After Publish", table.concat(lines, "\n\n"), synced > 0 and "info" or "warning")
end)
