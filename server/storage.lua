local SELECT_DATA = "SELECT * FROM mri_qfarm"
local INSERT_DATA = "INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)"
local UPDATE_DATA = "UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmId = ?"
local DELETE_DATA = "DELETE FROM mri_qfarm WHERE farmId = ?"

local Farms = GlobalState.Farms or {}

local function cleanNullPoints(config)
    for name, value in pairs(config.items) do
        local newPoints = {}
        for k, v in pairs(value.points) do
            newPoints[#newPoints + 1] = v
        end
        config.items[name].points = newPoints
    end
    return config
end

local function createFarm(farm)
    local result = MySQL.Sync.insert(INSERT_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group)})
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
        for k, v in ipairs(result) do
            local farm = {
                farmId = v.farmId,
                name = v.farmName,
                config = cleanNullPoints(json.decode(v.farmConfig)),
                group = json.decode(v.farmGroup)
            }
            Farms[k] = farm
        end
    end
    GlobalState:set("Farms", Farms, true)
    return true
end

local function updateFarm(farm)
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
