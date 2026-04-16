local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"

local logger = LrLogger("BeforeAfterExport")
logger:enable("print")
logger:enable("logfile")

logger:info("=== Before and After Export plugin INIT ===")
logger:info("Plugin path: " .. _PLUGIN.path)
logger:info("SDK version: " .. tostring(import("LrApplication").versionTable().major))

local infoPath = LrPathUtils.child(_PLUGIN.path, "Info.lua")
logger:info("Info.lua exists: " .. tostring(import("LrFileUtils").exists(infoPath)))

local testPath = LrPathUtils.child(_PLUGIN.path, "TestMenu.lua")
logger:info("TestMenu.lua exists: " .. tostring(import("LrFileUtils").exists(testPath)))
