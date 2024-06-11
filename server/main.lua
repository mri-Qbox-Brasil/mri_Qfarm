local QBCore = exports["qb-core"]:GetCoreObject()
Farms = GlobalState.Farms or {}
Items = exports.ox_inventory:Items()

local _SELECT_DATA = 'SELECT * FROM mri_qfarm'
local _INSERT_DATA = 'INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)'
local _UPDATE_DATA = 'UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmName = ?'
local _DELETE_DATA = 'DELETE FROM mri_qfarm WHERE farmName = ?'
local _CREATE_TABLE = [[
    CREATE TABLE IF NOT EXISTS mri_qfarm (
        farmName varchar(100) NOT NULL,
        farmConfig LONGTEXT NULL,
        farmGroup LONGTEXT NULL,
        CONSTRAINT mri_qfarm_pk PRIMARY KEY (farmName)
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

local function onSqlAction(source, response)
    TriggerClientEvent('mri_qfarm:client:LoadFarms', -1)
    TriggerClientEvent('ox_lib:notify', source, response)
end

RegisterNetEvent("mri_Qfarm:server:SaveFarm", function(farm, index)
    local source = source
    local farmLocal = Farms[index]
    local response = { type = 'success', description = 'Sucesso ao salvar!'}
    if farmLocal then
        exports.oxmysql:execute(_UPDATE_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group), farm.name}, function (result)
            if result and result.affectedRows <= 0 then
                response.type = 'error'
                response.description = 'Erro ao salvar.'
            end
            Farms[index] = farm
            onSqlAction(source, response)
        end)
    else
        exports.oxmysql.insert_async(_INSERT_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group)}, function (result)
            if result and result.affectedRows <= 0 then
                response.type = 'error'
                response.description = 'Erro ao salvar.'
            end
            Farms[index] = farm
            onSqlAction(source, response)
        end)
    end
end)

RegisterNetEvent("mri_Qfarm:server:DeleteFarm", function(key)
    local response = { type = 'success', description = 'Farm excluído!'}
    local farm = Farms[key]
    print(key, json.encode(farm))
    exports.oxmysql:execute(_DELETE_DATA, {farm.name}, function (result)
        print(json.encode())
        if result and result.affectedRows <= 0 then
            response.type = 'error'
            response.description = 'Erro ao excluir.'
        end
        onSqlAction(source, response)
    end)
    Farms[key] = nil
    GlobalState:set('Farms', Farms, true)
    Wait(2000)
    TriggerClientEvent('mri_Qfarm:client:LoadFarms', -1)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        exports['mri_Qbox']:CreateTable(_CREATE_TABLE)
        local result = exports.oxmysql:query_async(_SELECT_DATA, {})
        local farms = {}
        if result and #result > 0 then
            for _, row in ipairs(result) do
                local zone = {
                    name = row.farmName,
                    config = json.decode(row.farmConfig),
                    group = json.decode(row.farmGroup)
                }
                farms[_] = zone
            end
        end
        Farms = farms
        GlobalState:set('Farms', Farms, true)
        Wait(2000)
        TriggerClientEvent('mri_Qfarm:client:LoadFarms', -1)
    end
end)
