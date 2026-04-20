local QBCore = exports["qb-core"]:GetCoreObject()
local Config = require("shared/config")

local Police = {}

function Police.alert(source, farm, itemName, alertConfig)
    local alertType = alertConfig.type or "drugsell"
    local coords = GetEntityCoords(GetPlayerPed(source))

    -- Corrigindo o erro com GetStreetNameAtCoord
    local streetName = "Desconhecido" -- Valor padrão caso não consiga obter o nome da rua

    -- Adicionando prints de debug
    if Config.Debug then
        print("^2[mri_Qfarm] Alerta policial acionado^7")
        print("^2[mri_Qfarm] - Jogador: " .. source .. "^7")
        print("^2[mri_Qfarm] - Fazenda: " .. farm.name .. "^7")
        print("^2[mri_Qfarm] - Item: " .. itemName .. "^7")
        print("^2[mri_Qfarm] - Tipo de alerta: " .. alertType .. "^7")
        print("^2[mri_Qfarm] - Coordenadas: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z .. "^7")
    end

    local message = locale("farm.alert_message", farm.name)

    -- Get all police officers
    local players = QBCore.Functions.GetQBPlayers()
    local policeCount = 0

    for _, player in pairs(players) do
        if player.PlayerData.job.name == "police" and player.PlayerData.job.onduty then
            policeCount = policeCount + 1
            -- Send notification to police officers
            TriggerClientEvent(
                "mri_Qfarm:client:PoliceAlert",
                player.PlayerData.source,
                {
                    type = alertType,
                    coords = coords,
                    streetName = streetName,
                    message = message,
                    farmName = farm.name,
                    itemName = itemName
                }
            )
            if Config.Debug then
                print("^2[mri_Qfarm] Alerta enviado para policial: " .. player.PlayerData.source .. "^7")
            end
        end
    end

    if Config.Debug then
        print("^2[mri_Qfarm] Total de policiais notificados: " .. policeCount .. "^7")
        print(("Police alert triggered from farm %s by player %s! Type: %s"):format(farm.name, source, alertType))
    end
end

function Police.checkAndAlert(src, cfg, itemName)
    local alertConfig = cfg.config.policeAlert or {}
    local itemCfg = cfg.config.items[itemName]
    local itemAlertConfig = itemCfg.policeAlert or {}

    -- Verifica se o alerta global está ativado OU se o item tem configuração específica
    local itemHasAlert = itemAlertConfig.chance ~= nil

    if (alertConfig.enabled or itemHasAlert) then
        -- Corrigindo a lógica para priorizar corretamente a chance do item
        local chance = alertConfig.chance or 0

        -- Se o item tiver uma configuração de chance específica, use-a
        if itemAlertConfig.chance ~= nil then
            chance = itemAlertConfig.chance
        end

        if Config.Debug then
            print("^2[mri_Qfarm] Verificando alerta policial para item: " .. itemName .. "^7")
            print("^2[mri_Qfarm] - Alerta global ativado: " .. (alertConfig.enabled and "Sim" or "Não") .. "^7")
            print("^2[mri_Qfarm] - Chance global: " .. (alertConfig.chance or 0) .. "%^7")
            print("^2[mri_Qfarm] - Item tem configuração específica: " .. (itemHasAlert and "Sim" or "Não") .. "^7")
            print(
                "^2[mri_Qfarm] - Chance do item: " ..
                    (itemAlertConfig.chance ~= nil and itemAlertConfig.chance or "não definida") .. "%^7"
            )
            print("^2[mri_Qfarm] - Chance final utilizada: " .. chance .. "%^7")
        end

        if math.random(1, 100) <= chance then
            -- Usa o tipo específico do item se existir, senão usa o tipo global
            local alertType = itemAlertConfig.type or alertConfig.type or "drugsell"

            -- Trigger police alert internally
            Police.alert(src, cfg, itemName, {
                type = alertType,
                chance = chance,
                enabled = true
            })
        else
            if Config.Debug then
                print("^3[mri_Qfarm] Alerta policial não acionado (chance: " .. chance .. "%)^7")
            end
        end
    else
        if Config.Debug then
            print("^3[mri_Qfarm] Alerta policial desativado para esta fazenda e item não tem configuração específica^7")
        end
    end
end

return Police
