local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"

local catalog = LrApplication.activeCatalog()
local photos = catalog:getTargetPhotos()

if #photos == 0 then
    LrDialogs.message(
        "No photos selected",
        "Please select one or more photos in the Library module before running this export.",
        "warning"
    )
    return
end

photos[1]:openExportDialog()
