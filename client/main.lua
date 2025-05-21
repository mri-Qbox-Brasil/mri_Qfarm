local Config = require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Route = lib.require("client/modules/route")
local NoStart = lib.require("client/modules/no_start")
local InteractionHandler = lib.require("client/interaction/handler")

local function loadFarms()
    InteractionHandler.clear()
    Blips.clear()
    Route.clear()
    NoStart.clear()
    for k, v in pairs(Defaults.Farms) do
        if v.config.nostart then
            NoStart.add(v)
        elseif v.config.start["location"] then
            Route.add(v)
        end
    end
    Route.loadFarms()
    NoStart.loadFarms()
    if Config.Debug then
        print("^2[mri_Qfarm] Farms carregadas com sucesso^7")
    end
end

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            Utils.loadPlayerData(QBX.PlayerData)
            loadFarms()
        end
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            Blips.clear()
            Markers.clear()
            InteractionHandler.clear()
        end
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerLoaded",
    function()
        Utils.loadPlayerData(QBX.PlayerData)
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnJobUpdate",
    function(JobInfo)
        Utils.playerJob = JobInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnGangUpdate",
    function(GangInfo)
        Utils.playerGang = GangInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "mri_Qfarm:client:LoadFarms",
    function()
        Defaults.Farms = GlobalState.Farms or {}
        loadFarms()
    end
)
