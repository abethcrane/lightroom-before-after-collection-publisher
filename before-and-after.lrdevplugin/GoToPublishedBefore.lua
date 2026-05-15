local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"

local RevealPublished = require "RevealPublished"

LrFunctionContext.postAsyncTaskWithContext("GoToPublishedBefore", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if not photos or #photos == 0 then
        LrDialogs.message("Before & After Publish", "Select one or more published photos.", "warning")
        return
    end

    for _, photo in ipairs(photos) do
        RevealPublished.revealForCatalogPhoto(photo, "before")
    end
end)
