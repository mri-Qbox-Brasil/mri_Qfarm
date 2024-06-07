local QBCore = exports["qb-core"]:GetCoreObject()
Farms = GlobalState.Farms or {}
Items = exports.ox_inventory:Items()

local TestZones = { -- remover isso quando finalizar o script
    [1] = {
        name = "Farm 1",
        config = {
            start = {
                location = vector3(-1933.82, 2039.50, 140.83),
                width = 0.6,
                length = 0.6
            },
            items = {
                steel = {
                    min = 3,
                    max = 7,
                    randomRoute = false,
                    points = {
                        vector3(-1909.74, 2023.50, 140.84), vector3(-1909.64, 2019.05, 140.95),
                        vector3(-1909.25, 2014.75, 141.13), vector3(-1909.30, 2010.76, 141.47)
                    },
                    animation = {
                        dict = 'amb@prop_human_bum_bin@idle_a',
                        anim = 'idle_a',
                        inSpeed = 6.0,
                        outSpeed = -6.0,
                        duration = -1,
                        flag = 47,
                        rate = 0,
                        x = 0,
                        y = 0,
                        z = 0
                    }
                }
            }
        },
        group = {
            name = "police",
            grade = 0
        }
    }
}

function UpdateFarmZone(key, value)
    FarmZones[key] = value
    GlobalState:set('FarmZonesUpdate', {
        key = key,
        value = value
    }, true)
end

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

AddEventHandler('onServerResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        if not Config.Debug then
            Farms = MySQL.query.await("SELECT * FROM mri_farms", {}) or {}
        else
            Farms = TestZones
        end
        GlobalState:set('Farms', Farms, true)
    end
end)
