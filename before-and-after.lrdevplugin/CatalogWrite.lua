local LrTasks = import "LrTasks"

local DEFAULT_TIMEOUT = 30

local CatalogWrite = {}

function CatalogWrite.doWrite(catalog, actionName, func, timeout)
    if catalog.hasWriteAccess then
        func()
        return true
    end

    local status = catalog:withWriteAccessDo(actionName, func, {
        timeout = timeout or DEFAULT_TIMEOUT,
    })
    return status == "executed"
end

-- Ensures catalog writes run inside a cooperative LrTask and never nest
-- withWriteAccessDo when publish/export already holds the write gate.
function CatalogWrite.runWithWriteAccess(catalog, actionName, func, timeout)
    if LrTasks.canYield() then
        return CatalogWrite.doWrite(catalog, actionName, func, timeout)
    end

    if catalog.hasWriteAccess then
        func()
        return true
    end

    return false
end

-- Run a catalog write from a non-yielding context (e.g. after nested export).
function CatalogWrite.runWithWriteAccessAsync(catalog, actionName, func, timeout, waitSeconds)
    if LrTasks.canYield() then
        return CatalogWrite.doWrite(catalog, actionName, func, timeout)
    end

    local state = { done = false, success = false }
    LrTasks.startAsyncTask(function()
        state.success = CatalogWrite.doWrite(catalog, actionName, func, timeout)
        state.done = true
    end, actionName)

    local deadline = os.clock() + (waitSeconds or 60)
    while not state.done and os.clock() < deadline do end
    return state.success
end

return CatalogWrite
