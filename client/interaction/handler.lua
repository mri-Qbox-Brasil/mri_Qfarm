local Config = require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Texts = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local function add(item)
    if item == nil then
        return
    end
    if Config.Interaction == "target" then
        item.data.inside = nil
        item.data.onExit = nil
        item.data.onEnter = nil
        Targets.add(item)
    elseif Config.Interaction == "marker" then
        Markers.add(item)
    elseif Config.Interaction == "zone" then
        Zones.add(item)
    end
end

local function remove(name)
    if name == nil then
        return
    end
    if Config.Interaction == "target" then
        Targets.remove(name)
    elseif Config.Interaction == "marker" then
        Markers.remove(name)
    elseif Config.Interaction == "zone" then
        Zones.remove(name)
    end
end

local function removeGroup(group)
    if group == nil then
        return
    end
    if Config.Interaction == "target" then
        Targets.removeGroup(group)
    elseif Config.Interaction == "marker" then
        Markers.removeGroup(group)
    elseif Config.Interaction == "zone" then
        Zones.removeGroup(group)
    end
end

local function clear()
    if Config.Interaction == "target" then
        Targets.clear()
    elseif Config.Interaction == "marker" then
        Markers.clear()
    elseif Config.Interaction == "zone" then
        Zones.clear()
    end
end

return {
    add = add,
    remove = remove,
    removeGroup = removeGroup,
    clear = clear
}
