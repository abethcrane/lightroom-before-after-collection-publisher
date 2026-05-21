--[[ Debug NDJSON ingest for Cursor debug session — do not log secrets ]]
-- Basename must not be "Agent*" — Lightroom resolves that as a toolkit script, not a bundled require.
local BACursorDebugLog = {}

local LOG_PATH = "/Users/beth/code/scratch/.cursor/debug-ab1073.log"
local SESSION_ID = "ab1073"

local function encodeJsonStr(s)
    if s == nil then return "null" end
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

local function encodeData(data)
    if not data then return "" end
    local parts = {}
    for k, v in pairs(data) do
        local key = encodeJsonStr(k)
        local val
        if type(v) == "boolean" then
            val = v and "true" or "false"
        elseif type(v) == "number" then
            val = tostring(v)
        elseif v == nil then
            val = "null"
        else
            val = encodeJsonStr(v)
        end
        parts[#parts + 1] = key .. ":" .. val
    end
    return table.concat(parts, ",")
end

function BACursorDebugLog.log(location, message, hypothesisId, data)
    -- #region agent log
    local ts = os.time() * 1000
    local line = string.format(
        '{"sessionId":"%s","timestamp":%d,"location":%s,"message":%s,"hypothesisId":%s,"data":{%s}}\n',
        SESSION_ID,
        ts,
        encodeJsonStr(location),
        encodeJsonStr(message),
        encodeJsonStr(hypothesisId or ""),
        encodeData(data or {})
    )
    local f = io.open(LOG_PATH, "a")
    if f then
        f:write(line)
        f:close()
    end
    -- #endregion
end

--- Capture keys relevant to BW vs color for hypothesis testing
function BACursorDebugLog.extractTreatmentFields(settings)
    if not settings then return {} end
    return {
        Treatment = settings.Treatment,
        ConvertToGrayscale = settings.ConvertToGrayscale,
        ProcessVersion = settings.ProcessVersion,
    }
end

return BACursorDebugLog
