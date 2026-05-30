--[[
  Apply Lightroom export settings so catalog metadata (especially keywords marked
  for export) is written into rendered JPEGs. Used for publish "after" renders
  (via updateExportSettings) and nested "before" LrExportSession exports.
]]

local MetadataExport = {}

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

return MetadataExport
