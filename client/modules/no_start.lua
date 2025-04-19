local ImageURL = "https://cfx-nui-ox_inventory/web/images"

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
        if Config.Debug then
            print(string.format("Adding element: %s", item.name))
        end
        Farms[item.name] = item
    else
        if Config.Debug then
            print(string.format("Skipping element: %s", item.name))
        end
    end
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
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
    loadFarms = loadFarms,
}
