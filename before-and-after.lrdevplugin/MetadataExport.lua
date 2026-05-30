--[[
  Apply Lightroom export settings so catalog metadata (especially keywords marked
  for export) is written into rendered JPEGs. Used for publish "after" renders
  (via updateExportSettings) and nested "before" LrExportSession exports.

  IPTC-IIM ObjectName (Lightroom "Title" in legacy IPTC) is capped at 64 bytes.
  When LR embeds metadata, that truncation can propagate. For titles longer than
  64 bytes we patch XMP-dc:Title via exiftool after render so the full catalog
  title is preserved in XMP.
]]

local LrFileUtils = import "LrFileUtils"
local LrLogger = import "LrLogger"
local LrShell = import "LrShell"
local LrTasks = import "LrTasks"

local MetadataExport = {}

local logger = LrLogger("MetadataExport")
logger:enable("logfile")

local IPTC_OBJECT_NAME_MAX_BYTES = 64
local WIN_ENV = WIN_ENV or (LrShell.pathToMsdosPath ~= nil)

local METADATA_KEY_PATTERNS = {
    "^LR_metadata_",
    "^metadata_",
}

local function keyMatchesMetadataField(key)
    if type(key) ~= "string" then
        return false
    end
    for _, pattern in ipairs(METADATA_KEY_PATTERNS) do
        if key:find(pattern) then
            return true
        end
    end
    return key == "LR_minimizeEmbeddedMetadata"
        or key == "minimizeEmbeddedMetadata"
        or key == "metadata_keywordOptions"
        or key == "embeddedMetadataOption"
end

local function shouldIncludeKeywords(exportSettings, options)
    if options and options.includeKeywords == false then
        return false
    end
    local source = options and options.sourceSettings
    if source and source.includeKeywordsInExport == false then
        return false
    end
    if exportSettings and exportSettings.includeKeywordsInExport == false then
        return false
    end
    return true
end

--- Copy metadata-related export keys from a parent settings table (e.g. publish preset).
local function inheritMetadataFields(dest, source)
    if not source then
        return
    end
    for key, value in pairs(source) do
        if keyMatchesMetadataField(key) then
            dest[key] = value
        end
    end
end

local function resolveKeywordOptions(exportSettings, options)
    local source = options and options.sourceSettings
    if source and source.keywordHierarchyInExport ~= nil then
        return source.keywordHierarchyInExport and "hierarchical" or "flat"
    end
    if exportSettings and exportSettings.keywordHierarchyInExport ~= nil then
        return exportSettings.keywordHierarchyInExport and "hierarchical" or "flat"
    end
    return "hierarchical"
end

--- Turn on keyword/metadata embedding (keys from Export.lrmodule presets / AgExportSettings).
local function applyKeywordDefaults(dest, exportSettings, options)
    dest.minimizeEmbeddedMetadata = false
    dest.LR_minimizeEmbeddedMetadata = false
    dest.metadata_keywordOptions = resolveKeywordOptions(exportSettings, options)
end

--- @param exportSettings table Lightroom export/publish property table (modified in place)
--- @param options? table { includeKeywords?: boolean, sourceSettings?: table }
function MetadataExport.apply(exportSettings, options)
    if not exportSettings then
        return
    end
    options = options or {}

    if not shouldIncludeKeywords(exportSettings, options) then
        return
    end

    inheritMetadataFields(exportSettings, options.sourceSettings)
    applyKeywordDefaults(exportSettings, exportSettings, options)
end

function MetadataExport.applyToParams(params, exportSettings, options)
    if not params then
        return params
    end
    options = options or {}
    options.sourceSettings = options.sourceSettings or exportSettings
    MetadataExport.apply(params, options)
    return params
end

local function shellQuote(value)
    if WIN_ENV then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- @param title string UTF-8 catalog title
function MetadataExport.titleNeedsXmpPatch(title)
    return title and title ~= "" and #title > IPTC_OBJECT_NAME_MAX_BYTES
end

--- Write full catalog title to XMP-dc:Title (exiftool must be on PATH).
--- @return boolean success
function MetadataExport.writeXmpTitle(filePath, title)
    if not MetadataExport.titleNeedsXmpPatch(title) then
        return true
    end
    if not filePath or filePath == "" or not LrFileUtils.exists(filePath) then
        return false
    end

    local cmd = "exiftool -overwrite_original -m -XMP-dc:Title="
        .. shellQuote(title) .. " " .. shellQuote(filePath)
    local exitCode = LrTasks.execute(cmd)
    if exitCode ~= 0 then
        logger:error("exiftool XMP-dc:Title failed (exit " .. tostring(exitCode) .. "): " .. filePath)
        return false
    end
    logger:info("XMP-dc:Title patched (" .. #title .. " bytes): " .. filePath)
    return true
end

--- Patch XMP-dc:Title on exported files when catalog title exceeds IPTC ObjectName limit.
function MetadataExport.writeXmpTitlesForPhoto(photo, filePaths, exportSettings, options)
    if not shouldIncludeKeywords(exportSettings, options) then
        return
    end
    local title = photo:getFormattedMetadata("title")
    if not MetadataExport.titleNeedsXmpPatch(title) then
        return
    end
    for _, filePath in ipairs(filePaths) do
        MetadataExport.writeXmpTitle(filePath, title)
    end
end

return MetadataExport
