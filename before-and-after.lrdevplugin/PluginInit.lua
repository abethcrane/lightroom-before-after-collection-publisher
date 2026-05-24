local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

local ResetPreset = require "ResetPreset"

local logger = LrLogger("BeforeAfterExport")
logger:enable("logfile")

logger:info("Before and After plugin loaded from " .. _PLUGIN.path)

local infoPath = LrPathUtils.child(_PLUGIN.path, "Info.lua")
if LrFileUtils.exists(infoPath) then
    local ok, infoRet = pcall(dofile, infoPath)
    if ok and type(infoRet) == "table" and infoRet.VERSION then
        local v = infoRet.VERSION
        logger:info(string.format(
            "Before and After VERSION %s",
            tostring(v.display or "?")
        ))
    end
end

if not ResetPreset.find() then
    LrFunctionContext.postAsyncTaskWithContext("BeforeAfterPresetCheck", function()
        LrDialogs.message("Before & After Export", ResetPreset.missingMessage(), "warning")
    end)
end
