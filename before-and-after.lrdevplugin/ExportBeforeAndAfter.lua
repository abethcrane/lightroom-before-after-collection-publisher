local LrApplication = import "LrApplication"
local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrFunctionContext = import "LrFunctionContext"
local LrPathUtils = import "LrPathUtils"
local LrProgressScope = import "LrProgressScope"
local LrTasks = import "LrTasks"
local LrView = import "LrView"
local LrLogger = import "LrLogger"

local BeforeAfterExport = require "BeforeAfterExport"

local logger = LrLogger("BeforeAfterExport")
logger:enable("logfile")

local function getDesktopPath()
    return LrPathUtils.getStandardFilePath("desktop")
end

local function showExportDialog()
    local options = nil

    LrFunctionContext.callWithContext("BeforeAfterDialog", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)

        props.destPath = getDesktopPath()
        props.format = "JPEG"
        props.jpegQuality = 85
        props.afterSuffix = "-after"
        props.beforeSuffix = "-before"
        props.constrainSize = false
        props.maxDimension = 2048

        local contents = f:column {
            spacing = f:control_spacing(),
            bind_to_object = props,

            f:group_box {
                title = "Destination",
                fill_horizontal = 1,
                f:row {
                    f:static_text {
                        title = "Export to:",
                        width = 80,
                        alignment = "right",
                    },
                    f:edit_field {
                        value = LrView.bind("destPath"),
                        fill_horizontal = 1,
                        width_in_chars = 40,
                    },
                    f:push_button {
                        title = "Browse...",
                        action = function()
                            local path = LrDialogs.runOpenPanel({
                                title = "Choose export folder",
                                canChooseFiles = false,
                                canChooseDirectories = true,
                                canCreateDirectories = true,
                                allowsMultipleSelection = false,
                            })
                            if path then
                                props.destPath = path[1]
                            end
                        end,
                    },
                },
            },

            f:group_box {
                title = "File Settings",
                fill_horizontal = 1,
                f:row {
                    f:static_text {
                        title = "Format:",
                        width = 80,
                        alignment = "right",
                    },
                    f:popup_menu {
                        value = LrView.bind("format"),
                        items = {
                            { title = "JPEG", value = "JPEG" },
                            { title = "TIFF", value = "TIFF" },
                        },
                        width = 100,
                    },
                },
                f:row {
                    f:static_text {
                        title = "JPEG Quality:",
                        width = 80,
                        alignment = "right",
                    },
                    f:slider {
                        value = LrView.bind("jpegQuality"),
                        min = 10,
                        max = 100,
                        integral = true,
                        width = 160,
                    },
                    f:edit_field {
                        value = LrView.bind("jpegQuality"),
                        width_in_chars = 4,
                    },
                },
            },

            f:group_box {
                title = "Naming",
                fill_horizontal = 1,
                f:row {
                    f:static_text {
                        title = "After suffix:",
                        width = 80,
                        alignment = "right",
                    },
                    f:edit_field {
                        value = LrView.bind("afterSuffix"),
                        width_in_chars = 15,
                    },
                },
                f:row {
                    f:static_text {
                        title = "Before suffix:",
                        width = 80,
                        alignment = "right",
                    },
                    f:edit_field {
                        value = LrView.bind("beforeSuffix"),
                        width_in_chars = 15,
                    },
                },
            },

            f:group_box {
                title = "Image Sizing",
                fill_horizontal = 1,
                f:row {
                    f:checkbox {
                        value = LrView.bind("constrainSize"),
                        title = "Resize to fit",
                    },
                },
                f:row {
                    f:static_text {
                        title = "Long edge:",
                        width = 80,
                        alignment = "right",
                    },
                    f:edit_field {
                        value = LrView.bind("maxDimension"),
                        width_in_chars = 6,
                        enabled = LrView.bind("constrainSize"),
                    },
                    f:static_text {
                        title = "pixels",
                    },
                },
            },
        }

        local result = LrDialogs.presentModalDialog({
            title = "Export Before & After",
            contents = contents,
            actionVerb = "Export",
        })

        if result == "ok" then
            options = {
                destPath = props.destPath,
                format = props.format,
                jpegQuality = props.jpegQuality / 100,
                afterSuffix = props.afterSuffix,
                beforeSuffix = props.beforeSuffix,
                constrainSize = props.constrainSize,
                maxDimension = props.maxDimension,
                colorSpace = "sRGB",
            }
        end
    end)

    return options
end

local function runExport(photos, options)
    LrTasks.startAsyncTask(function()
        LrTasks.yield()
        logger:info("BeforeAfterExport async task canYield=" .. tostring(LrTasks.canYield()))

        local progressScope = LrProgressScope({
            title = "Exporting Before & After (" .. #photos .. " photos)",
        })

        local ok, results = LrTasks.pcall(function()
            return BeforeAfterExport.processPhotos(photos, options, progressScope)
        end)

        progressScope:done()

        if not ok then
            LrDialogs.message("Export failed", tostring(results), "critical")
            return
        end

        local errorCount = #results.errors
        local successCount = #results.after

        if errorCount > 0 then
            local errorList = {}
            for _, e in ipairs(results.errors) do
                table.insert(errorList, e.photo .. ": " .. e.error)
            end
            LrDialogs.message(
                "Export completed with errors",
                successCount .. " photos exported successfully.\n" ..
                errorCount .. " photos had errors:\n\n" ..
                table.concat(errorList, "\n"),
                "warning"
            )
        elseif successCount > 0 then
            LrDialogs.message(
                "Export complete",
                successCount .. " photo(s) exported to:\n" .. options.destPath,
                "info"
            )
        end
    end, "BeforeAfterExport")
end

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

local options = showExportDialog()
if not options then return end

if not LrFileUtils.exists(options.destPath) then
    LrFileUtils.createAllDirectories(options.destPath)
end

runExport(photos, options)
