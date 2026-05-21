local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrPathUtils = import "LrPathUtils"

local DevelopDefaults = require "DevelopDefaults"

LrFunctionContext.postAsyncTaskWithContext("DumpSettings", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    if not photo then
        LrDialogs.message("Dump Settings", "Select a photo first.", "warning")
        return
    end

    local photoName = photo:getFormattedMetadata("fileName")
    local current = photo:getDevelopSettings()
    local beforeRecipe = DevelopDefaults.buildBeforeSettings(current)

    -- Apply our before, read what LR actually resolves, then restore
    catalog:withWriteAccessDo("Dump: apply before", function()
        photo:applyDevelopSettings(beforeRecipe)
    end)
    local lrResolved = photo:getDevelopSettings()
    catalog:withWriteAccessDo("Dump: restore after", function()
        photo:applyDevelopSettings(current)
    end)

    local outPath = LrPathUtils.child(_PLUGIN.path, "settings_dump.txt")
    local f = io.open(outPath, "w")
    if not f then
        LrDialogs.message("Dump Settings", "Could not write to " .. outPath, "critical")
        return
    end

    f:write("Photo: " .. photoName .. "\n")
    f:write("Timestamp: " .. os.date() .. "\n\n")
    f:write("Columns:\n")
    f:write("  AFTER     = current develop settings (the edited photo)\n")
    f:write("  RECIPE    = what buildBeforeSettings() produces\n")
    f:write("  RESOLVED  = what getDevelopSettings() returns after applying RECIPE\n")
    f:write("  (RESOLVED shows what LR actually does with our recipe)\n\n")

    local allKeys = {}
    local seen = {}
    for k in pairs(current) do if not seen[k] then allKeys[#allKeys+1] = k; seen[k] = true end end
    for k in pairs(beforeRecipe) do if not seen[k] then allKeys[#allKeys+1] = k; seen[k] = true end end
    for k in pairs(lrResolved) do if not seen[k] then allKeys[#allKeys+1] = k; seen[k] = true end end
    table.sort(allKeys)

    local function fmt(v)
        if v == nil then return "-" end
        if type(v) == "table" then return "[table]" end
        return tostring(v)
    end

    f:write(string.format("%-45s  %-20s  %-20s  %-20s  %s\n", "KEY", "AFTER", "RECIPE", "RESOLVED", ""))
    f:write(string.rep("-", 130) .. "\n")

    for _, k in ipairs(allKeys) do
        local av = fmt(current[k])
        local rv = fmt(beforeRecipe[k])
        local sv = fmt(lrResolved[k])
        local flag = ""
        if av ~= sv and av ~= rv then
            flag = " <-- changed"
        end
        if av == sv and av ~= rv then
            flag = " <-- recipe ignored?"
        end
        f:write(string.format("%-45s  %-20s  %-20s  %-20s  %s\n", k, av, rv, sv, flag))
    end

    f:close()
    LrDialogs.message("Dump Settings", "Written to:\n" .. outPath, "info")
end)
