local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"

local ReportPaths = {}

function ReportPaths.getReportDir()
    local base = LrPathUtils.child(
        LrPathUtils.getStandardFilePath("documents"),
        "Before and After Export"
    )
    local reportDir = LrPathUtils.child(base, "reports")
    if not LrFileUtils.exists(reportDir) then
        LrFileUtils.createAllDirectories(reportDir)
    end
    return reportDir
end

return ReportPaths
