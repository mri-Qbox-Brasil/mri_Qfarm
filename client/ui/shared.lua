---@type UiUtils
local UiUtils = lib.require("client/ui/utils")

local function delete(caption, tableObj, key)
    if UiUtils.confirmationDialog(caption) == "confirm" then
        if type(key) == "number" then
            table.remove(tableObj, key)
        else
            tableObj[key] = nil
        end
        return true
    end
end

return {
    delete = delete
}
