local Config = require("shared/config")
local Utils = require ("shared/utils")

local SELECT_DATA = "SELECT * FROM mri_qfarm"
local INSERT_DATA = "INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)"
local UPDATE_DATA = "UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmId = ?"
local DELETE_DATA = "DELETE FROM mri_qfarm WHERE farmId = ?"

local Farms = GlobalState.Farms or {}

local function isNameTaken(name, excludeId)
    for _, farm in pairs(Farms) do
        if farm.name == name and (not excludeId or farm.farmId ~= excludeId) then
            return true
        end
    end
    return false
end

local function cleanNullPoints(config)
    if not config or not config.items then return config end
    for name, value in pairs(config.items) do
        if value.points then
            local newPoints = {}
            for k, v in pairs(value.points) do
                newPoints[#newPoints + 1] = v
            end
            config.items[name].points = newPoints
        end
    end
    return config
end

local function createFarm(farm)
    if isNameTaken(farm.name) then
        return -1 -- Special error code for duplicate name
    end
    local farmConfig = json.encode(farm.config or {})
    local farmGroup = json.encode(farm.group or {})
    local result = MySQL.Sync.insert(INSERT_DATA, {farm.name, farmConfig, farmGroup})
    if result > 0 then
        farm.farmId = result
        Farms[#Farms + 1] = farm
        GlobalState:set("Farms", Farms, true)
    end
    return result
end

local function loadFarms()
    local result = MySQL.Sync.fetchAll(SELECT_DATA, {})
    if result and #result > 0 then
        Farms = {} -- Clear local cache before loading
        for k, v in ipairs(result) do
            local config = {}
            local success, decoded = pcall(json.decode, v.farmConfig or "{}")
            if success then config = decoded else Utils.debug("Storage", "Failed to decode config for farm ID " .. v.farmId) end

            local group = {}
            local successGroup, decodedGroup = pcall(json.decode, v.farmGroup or "{}")
            if successGroup then group = decodedGroup end

            local farm = {
                farmId = v.farmId,
                name = v.farmName,
                config = cleanNullPoints(config),
                group = group
            }
            Farms[#Farms + 1] = farm
        end
    end
    GlobalState:set("Farms", Farms, true)
    return true
end

local function updateFarm(farm)
    if isNameTaken(farm.name, farm.farmId) then
        return -1 -- Special error code for duplicate name
    end
    local affectedRows = MySQL.Sync.execute(UPDATE_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group), farm.farmId})
    if affectedRows > 0 then
        Farms[Utils.findById(farm.farmId, Farms)] = farm
        GlobalState:set("Farms", Farms, true)
    end
    return affectedRows > 0
end

local function deleteFarm(farmId)
    local affectedRows = MySQL.Sync.execute(DELETE_DATA, {farmId})
    if affectedRows > 0 then
        Farms[Utils.findById(farmId, Farms)] = nil
    end
    GlobalState:set("Farms", Farms, true)
    return affectedRows > 0
end

return {
    createFarm = createFarm,
    loadFarms = loadFarms,
    updateFarm = updateFarm,
    deleteFarm = deleteFarm
}
