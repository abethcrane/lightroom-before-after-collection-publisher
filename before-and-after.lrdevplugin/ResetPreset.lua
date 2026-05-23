local LrApplication = import "LrApplication"

local ResetPreset = {}

ResetPreset.NAME = "Reset For Before"

function ResetPreset.find()
    local folders = LrApplication.developPresetFolders()
    for _, folder in ipairs(folders) do
        for _, preset in ipairs(folder:getDevelopPresets()) do
            if preset:getName() == ResetPreset.NAME then
                return preset
            end
        end
    end
    return nil
end

function ResetPreset.missingMessage()
    return "Could not find a develop preset named \"" .. ResetPreset.NAME .. "\".\n\n" ..
        "Import presets/Reset For Before.xmp from the plugin package:\n" ..
        "Develop → Presets → right-click User Presets → Import…"
end

return ResetPreset
