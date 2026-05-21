local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

local logger = LrLogger("BeforeAfterExport")
logger:enable("print")
logger:enable("logfile")

logger:info("=== Before and After Export plugin INIT ===")
logger:info("Plugin path: " .. _PLUGIN.path)
logger:info("SDK version: " .. tostring(import("LrApplication").versionTable().major))

local infoPath = LrPathUtils.child(_PLUGIN.path, "Info.lua")
logger:info("Info.lua exists: " .. tostring(LrFileUtils.exists(infoPath)))

if LrFileUtils.exists(infoPath) then
    local okIv, infoRet = pcall(dofile, infoPath)
    if okIv and type(infoRet) == "table" and infoRet.VERSION then
        local v = infoRet.VERSION
        logger:info(
            string.format(
                "Before and After VERSION %s (%s.%s.%s) — Reload plugin in Lightroom if this isn't what you expected.",
                tostring(v.display or "?"),
                tostring(v.major or 0),
                tostring(v.minor or 0),
                tostring(v.revision or 0)
            )
        )
    elseif not okIv then
        logger:warn("Info.lua parse failed (version unknown): " .. tostring(infoRet))
    end
end

local testPath = LrPathUtils.child(_PLUGIN.path, "TestMenu.lua")
logger:info("TestMenu.lua exists: " .. tostring(LrFileUtils.exists(testPath)))
