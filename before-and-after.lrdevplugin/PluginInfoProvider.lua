local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrView = import "LrView"

local ResetPreset = require "ResetPreset"

local function getVersionDisplay()
    local infoPath = LrPathUtils.child(_PLUGIN.path, "Info.lua")
    if LrFileUtils.exists(infoPath) then
        local ok, infoRet = pcall(dofile, infoPath)
        if ok and type(infoRet) == "table" and infoRet.VERSION then
            return infoRet.VERSION.display or "unknown"
        end
    end
    return "unknown"
end

return {
    sectionsForTopOfDialog = function(f, propertyTable)
        local presetInstalled = ResetPreset.find() ~= nil
        local presetStatus = presetInstalled
            and "Installed"
            or "Not found — import presets/Reset For Before.xmp"

        return {
            {
                title = "Before and After Export",
                f:row {
                    f:static_text {
                        title = "Version " .. getVersionDisplay(),
                        fill_horizontal = 1,
                    },
                },
                f:row {
                    f:static_text {
                        title = "Develop preset \"" .. ResetPreset.NAME .. "\": " .. presetStatus,
                        fill_horizontal = 1,
                        height_in_lines = 2,
                    },
                },
                f:row {
                    f:static_text {
                        title = "Exports matched before/after pairs. The develop preset is required for the \"before\" render.",
                        fill_horizontal = 1,
                        height_in_lines = 2,
                    },
                },
            },
        }
    end,
}
