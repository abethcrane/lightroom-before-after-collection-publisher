--[[
    Default develop settings for Lightroom Classic (Process Version 2012+).

    These represent a "zeroed" photo with no user edits applied.
    Note: some defaults are non-zero (e.g. Sharpness=40, ColorNoiseReduction=25).

    Geometry-related settings (crop, lens corrections, transform, orientation)
    are intentionally EXCLUDED — they get overlaid from the current edit.
]]

local DevelopDefaults = {}

DevelopDefaults.GEOMETRY_KEYS = {
    -- Crop
    "CropAngle",
    "CropBottom",
    "CropConstrainToWarp",
    "CropLeft",
    "CropRight",
    "CropTop",

    -- Orientation
    "Orientation",

    -- Lens corrections
    "EnableLensCorrections",
    "LensProfileEnable",
    "LensProfileSetup",
    "LensProfileName",
    "LensProfileFilename",
    "LensProfileDistortionScale",
    "LensProfileChromaticAberrationScale",
    "LensProfileVignettingScale",
    "LensManualDistortionAmount",
    "DefringePurpleAmount",
    "DefringePurpleHueLo",
    "DefringePurpleHueHi",
    "DefringeGreenAmount",
    "DefringeGreenHueLo",
    "DefringeGreenHueHi",
    "AutoLateralCA",

    -- Transform / Perspective
    "EnableTransform",
    "PerspectiveVertical",
    "PerspectiveHorizontal",
    "PerspectiveRotate",
    "PerspectiveScale",
    "PerspectiveAspect",
    "PerspectiveX",
    "PerspectiveY",
    "PerspectiveUpright",
    "UprightVersion",
    "UprightTransformCount",
    "UprightFourSegmentsCount",
    "UprightPreview",
    "UprightTransform_0",
    "UprightTransform_1",
    "UprightTransform_2",
    "UprightTransform_3",
    "UprightTransform_4",
    "UprightTransform_5",
    "UprightFocalLength35mm",
    "UprightFocalMode",
    "UprightGuidedDependentDigest",

    -- Process version + camera profile (preserve the rendering engine)
    "ProcessVersion",
    "CameraProfile",
    "CameraProfileDigest",

}

DevelopDefaults.SETTINGS = {
    WhiteBalance = "As Shot",

    -- Basic tone (PV2012+)
    Exposure2012 = 0,
    Contrast2012 = 0,
    Highlights2012 = 0,
    Shadows2012 = 0,
    Whites2012 = 0,
    Blacks2012 = 0,

    -- Legacy basic tone (PV2010 and earlier, included for compatibility)
    Exposure = 0,
    Brightness = 50,
    Contrast = 25,
    HighlightRecovery = 0,
    FillLight = 0,
    Shadows = 5,

    -- Presence
    Clarity2012 = 0,
    Clarity = 0,
    Dehaze = 0,
    Vibrance = 0,
    Saturation = 0,
    Texture = 0,

    -- Tone Curve
    ToneCurveName2012 = "Linear",
    ToneCurveName = "Medium Contrast",
    ParametricShadows = 0,
    ParametricDarks = 0,
    ParametricLights = 0,
    ParametricHighlights = 0,
    ParametricShadowSplit = 25,
    ParametricMidtoneSplit = 50,
    ParametricHighlightSplit = 75,

    -- HSL / Color
    HueAdjustmentRed = 0,
    HueAdjustmentOrange = 0,
    HueAdjustmentYellow = 0,
    HueAdjustmentGreen = 0,
    HueAdjustmentAqua = 0,
    HueAdjustmentBlue = 0,
    HueAdjustmentPurple = 0,
    HueAdjustmentMagenta = 0,
    SaturationAdjustmentRed = 0,
    SaturationAdjustmentOrange = 0,
    SaturationAdjustmentYellow = 0,
    SaturationAdjustmentGreen = 0,
    SaturationAdjustmentAqua = 0,
    SaturationAdjustmentBlue = 0,
    SaturationAdjustmentPurple = 0,
    SaturationAdjustmentMagenta = 0,
    LuminanceAdjustmentRed = 0,
    LuminanceAdjustmentOrange = 0,
    LuminanceAdjustmentYellow = 0,
    LuminanceAdjustmentGreen = 0,
    LuminanceAdjustmentAqua = 0,
    LuminanceAdjustmentBlue = 0,
    LuminanceAdjustmentPurple = 0,
    LuminanceAdjustmentMagenta = 0,
    ConvertToGrayscale = false,

    -- Grayscale Mix (only used if ConvertToGrayscale = true)
    GrayMixerRed = 0,
    GrayMixerOrange = 0,
    GrayMixerYellow = 0,
    GrayMixerGreen = 0,
    GrayMixerAqua = 0,
    GrayMixerBlue = 0,
    GrayMixerPurple = 0,
    GrayMixerMagenta = 0,

    -- Color Grading (replaces Split Toning in newer versions)
    SplitToningShadowHue = 0,
    SplitToningShadowSaturation = 0,
    SplitToningHighlightHue = 0,
    SplitToningHighlightSaturation = 0,
    SplitToningBalance = 0,
    ColorGradeMidtoneHue = 0,
    ColorGradeMidtoneSat = 0,
    ColorGradeMidtoneLum = 0,
    ColorGradeShadowLum = 0,
    ColorGradeHighlightLum = 0,
    ColorGradeBlending = 50,
    ColorGradeGlobalHue = 0,
    ColorGradeGlobalSat = 0,
    ColorGradeGlobalLum = 0,

    -- Detail
    Sharpness = 40,
    SharpenRadius = 1.0,
    SharpenDetail = 25,
    SharpenEdgeMasking = 0,
    LuminanceSmoothing = 0,
    LuminanceNoiseReductionDetail = 50,
    LuminanceNoiseReductionContrast = 0,
    ColorNoiseReduction = 25,
    ColorNoiseReductionDetail = 50,
    ColorNoiseReductionSmoothness = 50,

    -- Effects
    PostCropVignetteAmount = 0,
    PostCropVignetteMidpoint = 50,
    PostCropVignetteFeather = 50,
    PostCropVignetteRoundness = 0,
    PostCropVignetteStyle = 1,
    PostCropVignetteHighlightContrast = 0,
    GrainAmount = 0,
    GrainSize = 25,
    GrainFrequency = 50,

    -- Calibration
    ShadowTint = 0,
    RedHue = 0,
    RedSaturation = 0,
    GreenHue = 0,
    GreenSaturation = 0,
    BlueHue = 0,
    BlueSaturation = 0,

    -- Enable flags — disable the panels that should have no effect
    EnableColorAdjustments = true,
    EnableSplitToning = true,
    EnableDetail = true,
    EnableEffects = true,
    EnableCalibration = true,
    EnableGrayscaleMix = true,
    EnableToneCurve = true,
    EnableGradientBasedCorrections = false,
    EnablePaintBasedCorrections = false,
    EnableMaskGroupBasedCorrections = false,
    EnableRedEye = false,
    EnableRetouch = false,
    EnableDistractionRemoval = false,

    -- Auto flags
    AutoBrightness = false,
    AutoContrast = false,
    AutoExposure = false,
    AutoShadows = false,
    AutoTone = false,

    -- Chromatic Aberration (manual)
    ChromaticAberrationB = 0,
    ChromaticAberrationR = 0,

    -- Vignette (legacy)
    VignetteAmount = 0,
    VignetteMidpoint = 50,

    Treatment = "Color",
}

-- Keys to pass through unchanged from the current edit (internal LR state
-- that should not be zeroed — zeroing causes wrong rendering or errors).
DevelopDefaults.EXTRA_PASSTHROUGH_KEYS = {
    AutoWhiteVersion = true,
    CropConstrainAspectRatio = true,
    CropConstrainToUnitSquare = true,
    GrainSeed = true,
    HDREditMode = true,
    HDRMaxValue = true,
    LensProfileIsEmbedded = true,
    SDRBlend = true,
    SDRBrightness = true,
    SDRClarity = true,
    SDRContrast = true,
    SDRHighlights = true,
    SDRShadows = true,
    SDRWhites = true,
    Temperature = true,
    Tint = true,
    UprightCenterMode = true,
    UprightCenterNormX = true,
    UprightCenterNormY = true,
}

-- Linear tone curve (PV2012 default)
local LINEAR_CURVE = { 0, 0, 255, 255 }

-- Keys that need specific default values (not just 0/false/{}).
-- applyDevelopSettings merges, so we must explicitly set these —
-- omitting them keeps the after edit's values.
DevelopDefaults.EXPLICIT_DEFAULTS = {
    ToneCurve = { 0, 0, 255, 255 },
    ToneCurvePV2012 = LINEAR_CURVE,
    ToneCurvePV2012Red = LINEAR_CURVE,
    ToneCurvePV2012Green = LINEAR_CURVE,
    ToneCurvePV2012Blue = LINEAR_CURVE,
    CurveRefineSaturation = 50,
    Look = {
        Name = "Adobe Color",
        Amount = 1,
        UUID = "B952C231111CD8E0ECCF14B86BAA7077",
        SupportsAmount = false,
        SupportsMonochrome = false,
        SupportsOutputReferred = false,
    },
    FilterList = {},
    RedEyeInfo = {},
    RetouchInfo = {},
    MaskGroupBasedCorrections = {},
    LensBlur = {},
    DepthMapInfo = {},
    PointColors = {},
}

local function neutralize(value)
    local t = type(value)
    if t == "number" then return 0 end
    if t == "boolean" then return false end
    if t == "table" then return {} end
    return value
end

function DevelopDefaults.buildBeforeSettings(currentSettings)
    local geometry = {}
    for _, key in ipairs(DevelopDefaults.GEOMETRY_KEYS) do
        geometry[key] = true
    end

    -- Start from the current photo's full settings so every key gets an
    -- explicit value — applyDevelopSettings merges, so omitted keys leak.
    local before = {}
    for k, v in pairs(currentSettings) do
        if geometry[k] or DevelopDefaults.EXTRA_PASSTHROUGH_KEYS[k] then
            before[k] = v
        elseif DevelopDefaults.SETTINGS[k] ~= nil then
            before[k] = DevelopDefaults.SETTINGS[k]
        elseif DevelopDefaults.EXPLICIT_DEFAULTS[k] ~= nil then
            before[k] = DevelopDefaults.EXPLICIT_DEFAULTS[k]
        else
            before[k] = neutralize(v)
        end
    end

    -- Ensure all known defaults are present even if currentSettings lacks them
    for k, v in pairs(DevelopDefaults.SETTINGS) do
        if before[k] == nil then
            before[k] = v
        end
    end

    -- Also ensure explicit defaults are present (merge won't clear omitted keys)
    for k, v in pairs(DevelopDefaults.EXPLICIT_DEFAULTS) do
        if before[k] == nil then
            before[k] = v
        end
    end

    return before
end

return DevelopDefaults
