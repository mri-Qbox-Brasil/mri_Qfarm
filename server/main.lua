local QBCore = exports["qb-core"]:GetCoreObject()

local FarmZones = {}

local TestZones = { -- remover isso quando finalizar o script
    [1] = {
        name = "Farm 1",
        config = {
            start = {
                location = vector3(-1869.88, 2056.65, 135.45),
                width = 0.6,
                length = 0.6
            },
            items = {
                steel = {
                    min = 3,
                    max = 7,
                    randomRoute = false,
                    points = {vector3(-2521.08, 2310.43, 33.22), vector3(-2512.07, 3619.26, 13.84)},
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
                },
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

local function itemAdd(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if (amount > 0) then
        Player.Functions.AddItem(item, amount, false)
        TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items[item], "add")
    end
end

local function isGang(Player)
    for _, job in pairs(Config.BlacklistedJobs) do
        if Player.PlayerData.job.name == job then
            return false
        end
    end
    return true
end

RegisterNetEvent("mri_Qfarm:server:getRewardItem", function(itemName, process, size, craft)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local PlayerJob = Player.PlayerData.job.name
    local PlayerGang = Player.PlayerData.gang.name
    if (PlayerJob ~= 'unemployed' and PlayerGang ~= 'none') and (#Config.BlacklistedJobs > 0) and
        (Config.FarmCheck or process == "craft") then
        for _, job in pairs(Config.BlacklistedJobs) do
            if PlayerJob == job then
                local name = string.format("[%s] %s %s(%s)", src, Player.PlayerData.charinfo.firstname,
                    Player.PlayerData.charinfo.lastname, Player.PlayerData.name)
                local errMsg = string.format(
                    "Tem um arrombado: '%s', com Emprego legal: '%s' e participando do ilegal: '%s'! :)", name,
                    PlayerJob, PlayerGang)
                print(errMsg)
                for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
                    if QBCore.Functions.HasPermission(Player.PlayerData.source, 'admin') then
                        TriggerClientEvent("QBCore:Notify", Player.PlayerData.source, errMsg, 'error', 7500)
                    end
                end
                -- TriggerEvent("ttc-smallresources:Server:SendWebhook", {
                --     issuer = "ttc",
                --     hook = "admin",
                --     color = {
                --         r = 255,
                --         g = 255,
                --         b = 0
                --     },
                --     title = "ALERTA - ADMIN",
                --     description = errMsg,
                --     content = "<@&890050177535209582>"
                -- })
                return
            end
        end
    end
    local cfg = nil
    local msg = nil
    if process == "farm" then
        if isGang(Player) then
            cfg = Farms[PlayerGang]
        else
            cfg = Farms[PlayerJob]
        end
    else
        if isGang(Player) then
            cfg = Crafts[PlayerGang][craft]
        else
            cfg = Crafts[PlayerJob][craft]
        end
    end

    if cfg == nil then
        local msg = Lang:t("error.job_not_found", {
            job = PlayerJob
        })
        if isGang then
            msg = Lang:t("error.gang_not_found", {
                gang = PlayerGang
            })
        end
        TriggerClientEvent("QBCore:Notify", src, msg, 'error')
        return
    end

    if (itemName == "cash") then
        Player.Functions.AddMoney("cash", size)
    else
        if (QBCore.Shared.Items[itemName] == nil) then
            print(string.format("Item: '%s' nao cadastrado!", itemName))
            TriggerClientEvent("QBCore:Notify", src, string.format("Erro ao processar item: %s", itemName), 'error')
            return
        end
        local itemCfg = cfg.items[itemName]
        if (itemCfg == nil) then
            print(string.format("Item: '%s' nao configurado!", itemName))
            TriggerClientEvent("QBCore:Notify", src, string.format("Erro ao processar item: %s", itemName), 'error')
            return
        end
        if (process == "farm") then
            itemAdd(src, itemName, math.random(itemCfg.min, itemCfg.max))
        else
            itemAdd(src, itemName, size)
        end
        if (itemCfg.extraItems) then
            for name, config in pairs(itemCfg.extraItems) do
                itemAdd(src, name, math.random(config.min, config.max))
            end
        end
    end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        if not Config.Debug then
            FarmZones = MySQL.query.await("SELECT * FROM mri_farms", {}) or {}
        else
            FarmZones = TestZones
        end
        GlobalState:set('FarmZones', FarmZones, true)
    end
end)
