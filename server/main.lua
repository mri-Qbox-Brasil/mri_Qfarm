local QBCore = exports["qb-core"]:GetCoreObject()
local Config = require("shared/config")
local Utils = require("shared/utils")
local Storage = lib.require("server/modules/storage")
local Police = lib.require("server/modules/police")
local DB = lib.require("server/modules/db")
local Callbacks = lib.require("server/modules/callbacks")
Callbacks.init()
local Farms = GlobalState.Farms or {}

lib.callback.register(
    "mri_Qfarm:server:getRewardItem",
    function(source, itemName, farmId)
        Utils.debug("getRewardItem: ", source, itemName, farmId)
        local src = source
        local cfg = nil

        for k, v in pairs(Farms) do
            if v.farmId == farmId then
                cfg = v
                Utils.debug(
                    string.format("Farm found: %s: %s\n%s", farmId, cfg.name, json.encode(cfg, {indent = true}))
                )
                break
            end
        end

        local msg = nil
        if not cfg then
            msg = locale("error.farm_not_found", farmId)
            Utils.debug(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        if (not Utils.items[itemName]) then
            msg = locale("error.item_not_found", itemName)
            Utils.debug(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        local itemCfg = cfg.config.items[itemName]

        if (not itemCfg) then
            msg = locale("error.item_cfg_not_found", itemName)
            Utils.debug(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        -- POLICE ALERT FEATURE START
        Police.checkAndAlert(src, cfg, itemName)
        -- POLICE ALERT FEATURE END

        local qtd = math.random(itemCfg.min or 0, itemCfg.max or 1)
        if not exports.ox_inventory:CanCarryItem(src, itemName, qtd) then
            return
        end

        Utils.itemAdd(src, itemName, qtd)
        if (itemCfg["extraItems"]) then
            for name, config in pairs(itemCfg.extraItems) do
                local qtd = math.random(config.min, config.max)
                if not exports.ox_inventory:CanCarryItem(src, itemName, qtd) then
                    return
                end

                Utils.itemAdd(src, name, qtd)
            end
        end
        return true
    end
)

AddEventHandler(
    "onResourceStart",
    function(resource)
        Wait(200)
        if resource == GetCurrentResourceName() then
            Storage.loadFarms()
            Utils.dispatchEvents(source)
        end
    end
)

if GetResourceState("mri_Qbox") ~= "started" then
    lib.addCommand(
        "managefarms",
        {
            help = locale("creator.description_title"),
            restricted = "group.admin"
        },
        function(source, args, raw)
            lib.callback("mri_Qfarm:manageFarmsMenu", source)
        end
    )
end
