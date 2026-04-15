local LrView = import "LrView"

return {
    sectionsForTopOfDialog = function(f, propertyTable)
        return {
            {
                title = "Before and After Export - Status",
                f:row {
                    f:static_text {
                        title = "Plugin loaded successfully. If you see this, Info.lua is working.\n" ..
                                "Plugin path: " .. _PLUGIN.path,
                        fill_horizontal = 1,
                    },
                },
            },
        }
    end,
}
