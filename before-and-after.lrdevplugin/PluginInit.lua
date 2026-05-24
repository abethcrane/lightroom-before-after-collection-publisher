local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"

local ResetPreset = require "ResetPreset"

local logger = LrLogger("BeforeAfterExport")
logger:enable("logfile")

logger:info("Before and After plugin loaded from " .. _PLUGIN.path)

if not ResetPreset.find() then
    LrFunctionContext.postAsyncTaskWithContext("BeforeAfterPresetCheck", function()
        LrDialogs.message("Before & After Export", ResetPreset.missingMessage(), "warning")
    end)
end
