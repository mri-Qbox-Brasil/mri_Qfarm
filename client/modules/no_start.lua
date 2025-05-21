-- Farm com rotas, sem iniciar o turno
local ImageURL = "https://cfx-nui-ox_inventory/web/images"

local Config = require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local Farms = {}

local function add(item)
    local isPublic = Utils.isPublic(item)
    if
        isPublic or Utils.roleCheck(PlayerJob, item.group.name, item.group.grade) or
            Utils.roleCheck(PlayerGang, item.group.name, item.group.grade)
     then
        Utils.debug(string.format("Adding element: %s", item.name))
        Farms[item.name] = item
    else
        Utils.debug(string.format("Skipping element: %s", item.name))
    end
end

local function remove(name)
    Utils.debug(string.format("Removing element: %s", name))
    Farms[name] = nil
end

local function clear()
    if #Farms > 0 then
        for k, v in pairs(Farms) do
            remove(k)
        end
    end
end

local function loadFarms()
    for k, v in pairs(Farms) do
        for itemName, _ in pairs(v.config.items) do
            local item = Utils.items[itemName]
            if not (item == nil) then
                startAutoFarm(
                    {
                        farm = v,
                        itemName = itemName
                    }
                )
            end
        end
    end
end

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
