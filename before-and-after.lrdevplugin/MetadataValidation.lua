local MetadataValidation = {}

function MetadataValidation.validatePhoto(photo, options)
    options = options or {}
    local issues = {}

    local title = photo:getFormattedMetadata("title")
    if not title or title == "" then
        issues[#issues + 1] = "missing title"
    end

    local camera = photo:getFormattedMetadata("cameraModel")
    if not camera or camera == "" then
        issues[#issues + 1] = "missing camera model"
    end

    local requiredCreator = options.requiredCreator
    if requiredCreator and requiredCreator ~= "" then
        local creator = photo:getFormattedMetadata("creator")
        if creator ~= requiredCreator then
            issues[#issues + 1] = "creator is '" .. tostring(creator)
                .. "', expected '" .. requiredCreator .. "'"
        end
    end

    return issues
end

return MetadataValidation
