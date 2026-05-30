local MetadataExport = require "MetadataExport"

local ExportParams = {}

local function getSetting(exportSettings, lrKey, shortKey)
    return exportSettings[lrKey] or exportSettings[shortKey]
end

function ExportParams.buildBeforeExportParams(exportSettings, destDir, collisionMode, options)
    options = options or {}

    local params = {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = destDir,
        LR_export_useSubfolder = false,
        LR_format = getSetting(exportSettings, "LR_format", "format") or "JPEG",
        LR_jpeg_quality = getSetting(exportSettings, "LR_jpeg_quality", "jpeg_quality")
            or options.jpegQualityDefault
            or 0.85,
        LR_export_colorSpace = getSetting(exportSettings, "LR_export_colorSpace", "export_colorSpace") or "sRGB",
        LR_size_doConstrain = getSetting(exportSettings, "LR_size_doConstrain", "size_doConstrain") or false,
        LR_size_maxHeight = getSetting(exportSettings, "LR_size_maxHeight", "size_maxHeight") or 9999,
        LR_size_maxWidth = getSetting(exportSettings, "LR_size_maxWidth", "size_maxWidth") or 9999,
        LR_size_resizeType = getSetting(exportSettings, "LR_size_resizeType", "size_resizeType") or "longEdge",
        LR_collisionHandling = collisionMode,
        LR_export_bitDepth = getSetting(exportSettings, "LR_export_bitDepth", "export_bitDepth") or 8,
        LR_reimportExportedPhoto = false,
        LR_outputSharpeningOn = getSetting(exportSettings, "LR_outputSharpeningOn", "outputSharpeningOn") or false,
        LR_useWatermark = false,
    }

    return MetadataExport.applyToParams(params, exportSettings, options)
end

return ExportParams
