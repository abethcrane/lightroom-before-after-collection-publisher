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
    -- White Balance: "As Shot" uses the camera's original values
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
    EnableGradientBasedCorrections = false,
    EnablePaintBasedCorrections = false,
    EnableRedEye = false,
    EnableRetouch = false,

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
}

function DevelopDefaults.buildBeforeSettings(currentSettings)
    local before = {}

    -- Start with all defaults
    for k, v in pairs(DevelopDefaults.SETTINGS) do
        before[k] = v
    end

    -- Overlay geometry from current edit
    for _, key in ipairs(DevelopDefaults.GEOMETRY_KEYS) do
        if currentSettings[key] ~= nil then
            before[key] = currentSettings[key]
        end
    end

    return before
end

return DevelopDefaults
