local QBCore = exports["qb-core"]:GetCoreObject()
Farms = GlobalState.Farms or {}
Items = exports.ox_inventory:Items()

local SELECT_DATA = 'SELECT * FROM mri_qfarm'
local INSERT_DATA = 'INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)'
local UPDATE_DATA = 'UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmId = ?'
local DELETE_DATA = 'DELETE FROM mri_qfarm WHERE farmId = ?'
local CREATE_TABLE = [[
    CREATE TABLE IF NOT EXISTS mri_qfarm (
        farmId BIGINT AUTO_INCREMENT PRIMARY KEY,
        farmName VARCHAR(100) NOT NULL UNIQUE,
        farmConfig LONGTEXT NULL,
        farmGroup LONGTEXT NULL
    )
    ENGINE=InnoDB
    DEFAULT CHARSET=utf8mb4
    COLLATE=utf8mb4_general_ci;
]]

local function ItemAdd(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if (amount > 0) then
        Player.Functions.AddItem(item, amount, false)
        TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items[item], "add")
    end
end

local function dispatchEvents(source, response)
    GlobalState:set('Farms', Farms, true)
    Wait(2000)
    TriggerClientEvent('mri_Qfarm:client:LoadFarms', -1)
    if response then
        TriggerClientEvent('ox_lib:notify', source, response)
    end
end

local function locateFarm(id)
    for k, v in pairs(Farms) do
        if v.farmId == id then
            return k
        end
    end
end

RegisterNetEvent("mri_Qfarm:server:getRewardItem", function(itemName, groupName)
    local src = source
    local cfg = nil

    for k, v in pairs(Farms) do
        if v.group.name == groupName then
            cfg = v
            break
        end
    end

    local msg = nil
    if not cfg then
        msg = locale("error.group_not_found", groupName)
        print(msg)
        TriggerClientEvent("QBCore:Notify", src, msg, 'error')
        return
    end

    if (Items[itemName] == nil) then
        print(string.format("Item: '%s' nao cadastrado!", itemName))
        TriggerClientEvent("QBCore:Notify", src, string.format("Erro ao processar item: %s", itemName), 'error')
        return
    end

    local itemCfg = cfg.config.items[itemName]

    if (itemCfg == nil) then
        print(string.format("Item: '%s' nao configurado!", itemName))
        TriggerClientEvent("QBCore:Notify", src, string.format("Erro ao processar item: %s", itemName), 'error')
        return
    end

    local qtd = math.random(itemCfg.min, itemCfg.max)
    ItemAdd(src, itemName, qtd)
    if (itemCfg['extraItems']) then
        for name, config in pairs(itemCfg.extraItems) do
            ItemAdd(src, name, math.random(config.min, config.max))
        end
    end
end)

RegisterNetEvent("mri_Qfarm:server:SaveFarm", function(farm)
    local source = source
    local response = { type = 'success', description = 'Sucesso ao salvar!'}
    print(json.encode(farm))
    if farm.farmId then
        print('update')
        local affectedRows = MySQL.Sync.execute(UPDATE_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group), farm.farmId})
        if affectedRows <= 0 then
            response.type = 'error'
            response.description = 'Erro ao salvar.'
        end
        Farms[locateFarm(farm.farmId)] = farm
        dispatchEvents(source, response)
    else
        print('insert')
        local farmId = MySQL.Sync.insert(INSERT_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group)})
        if farmId <= 0 then
            response.type = 'error'
            response.description = 'Erro ao salvar.'
        else
            farm.farmId = farmId
            Farms[#Farms + 1] = farm
        end
        dispatchEvents(source, response)
    end
end)

RegisterNetEvent("mri_Qfarm:server:DeleteFarm", function(farmId)
    local source = source
    local response = { type = 'success', description = 'Farm excluído!'}
    if not farmId then
        TriggerClientEvent('ox_lib:notify', source, response)
        return
    end
    local affectedRows = MySQL.Sync.execute(DELETE_DATA, {farmId})
    if affectedRows <= 0 then
        response.type = 'error'
        response.description = 'Erro ao excluir.'
    end
    Farms[locateFarm(farmId)] = nil
    dispatchEvents(source, response)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        MySQL.Async.execute(CREATE_TABLE)
        local result = MySQL.Sync.fetchAll(SELECT_DATA, {})
        local farms = {}
        if result and #result > 0 then
            print('>0')
            for _, row in ipairs(result) do
                local zone = {
                    farmId = row.farmId,
                    name = row.farmName,
                    config = json.decode(row.farmConfig),
                    group = json.decode(row.farmGroup)
                }
                farms[_] = zone
            end
        end
        Farms = farms
        dispatchEvents(source)
    end
end)
