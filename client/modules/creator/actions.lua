local Config = lib.require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = lib.require("client/defaults")

local function getItems()
    return exports.ox_inventory:Items()
end

local Actions = {}

local newFarm = {
    name = nil,
    config = {
        start = {
            location = nil,
            width = nil,
            length = nil
        },
        items = {},
        policeAlert = {
            enabled = false,
            chance = 30,
            type = "drugsell" -- Tipo de alerta padrão no ps-dispatch
        }
    },
    group = {
        name = nil,
        grade = 0
    }
}

local newItem = {
    min = nil,
    max = nil,
    randomRoute = false,
    unlimited = false,
    points = {},
    animation = Utils.getDefaultAnim(),
    collectTime = Defaults.CollectTime or 5000,
    collectItem = {
        name = nil,
        durability = 0
    },
    collectVehicle = nil
}

-- Definindo DefaultCollectTime localmente caso não venha de Defaults
local DefaultCollectTime = Defaults.CollectTime or 5000

local function ifThen(condition, ifTrue, ifFalse)
    if condition then
        return ifTrue
    end
    return ifFalse
end

local function delete(caption, tableObj, key)
    if Utils.confirmationDialog(caption) == "confirm" then
        if type(key) == "number" then
            table.remove(tableObj, key)
        else
            tableObj[key] = nil
        end
        return true
    end
end

function Actions.deleteFarm(args)
    local farm = Defaults.Farms[args.farmKey]
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.farm"), Defaults.Farms[args.farmKey].name),
        Defaults.Farms,
        args.farmKey
    )
    if result then
        lib.callback.await("mri_Qfarm:server:DeleteFarm", false, farm.farmId)
        args.callback()
    else
        if args.callbackCancel then
            args.callbackCancel(args.farmKey)
        end
    end
end

function Actions.deleteItem(args)
    local Items = getItems()
    local itemLabel = args.itemKey
    if Items[args.itemKey] then
        itemLabel = Items[args.itemKey].label
    end
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.item"), itemLabel),
        Defaults.Farms[args.farmKey].config.items,
        args.itemKey
    )
    if result then
        args.callback(
            {
                farmKey = args.farmKey
            }
        )
    else
        if args.callbackCancel then
            args.callbackCancel(
                {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey
                }
            )
        end
    end
end

function Actions.deletePoint(args)
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.point"), args.name),
        Defaults.Farms[args.farmKey].config.items[args.itemKey].points,
        args.pointKey
    )
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.deleteExtraItem(args)
    local Items = getItems()
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.extra_item"), Items[args.extraItemKey].label),
        Defaults.Farms[args.farmKey].config.items[args.itemKey].extraItems,
        args.extraItemKey
    )
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.exportFarm(args)
    lib.setClipboard(
        json.encode(
            Defaults.Farms[args.farmKey],
            {
                indent = true
            }
        )
    )
    lib.notify(
        {
            type = "success",
            description = locale("misc.exported")
        }
    )
    args.callback(args.farmKey)
end

function Actions.changeFarmLocation(args)
    local location = nil
    local result = Utils.getPedCoords()
    if result.result == "choose" then
        location = result.coords
    end
    if location then
        Defaults.Farms[args.farmKey].config.start = {
            location = location
        }
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(args.farmKey)
end

function Actions.changeFarmStart(args)
    local alert = lib.alertDialog(
        {
            header = locale("actions.farm.nostart.alert.title"),
            content = locale("actions.farm.nostart.alert.description"),
            centered = true,
            cancel = true,
            labels = {
                cancel = locale("actions.cancel"),
                confirm = locale("actions.confirm")
            }
        }
    )
    if alert == "confirm" then
        Defaults.Farms[args.farmKey].config.nostart = not Defaults.Farms[args.farmKey].config.nostart
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(args.farmKey)
end

function Actions.changeFarmAFK(args)
    local alert = lib.alertDialog(
        {
            header = locale("actions.farm.afk.alert.title"),
            content = locale("actions.farm.afk.alert.description"),
            centered = true,
            cancel = true,
            labels = {
                cancel = locale("actions.cancel"),
                confirm = locale("actions.confirm")
            }
        }
    )
    if alert == "confirm" then
        Defaults.Farms[args.farmKey].config.afk = not Defaults.Farms[args.farmKey].config.afk
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            callback = args.callback
        }
    )
end

function Actions.togglePoliceAlert(args)
    local alert = lib.alertDialog({
        header = locale("actions.farm.police_alert.alert.title"),
        content = locale("actions.farm.police_alert.alert.description"),
        centered = true,
        cancel = true,
        labels = {
            cancel = locale("actions.cancel"),
            confirm = locale("actions.confirm")
        }
    })

    if alert == "confirm" then
        if not Defaults.Farms[args.farmKey].config.policeAlert then
            Defaults.Farms[args.farmKey].config.policeAlert = {
                enabled = true,
                chance = 30,
                type = "drugsell"
            }
        else
            Defaults.Farms[args.farmKey].config.policeAlert.enabled = not Defaults.Farms[args.farmKey].config.policeAlert.enabled
        end

        lib.notify({
            type = "success",
            description = locale("notify.updated")
        })
    end
    args.callback(args.farmKey)
end

function Actions.setPoliceAlertChance(args)
    local farm = Defaults.Farms[args.farmKey]

    if not farm.config.policeAlert then
        farm.config.policeAlert = {
            enabled = true,
            chance = 30,
            type = "drugsell"
        }
    end

    local input = lib.inputDialog(
        locale("actions.farm.police_alert_chance"),
        {
            {
                type = "number",
                label = locale("actions.farm.police_alert_chance"),
                description = locale("actions.farm.description_police_alert_chance"),
                default = farm.config.policeAlert.chance or 30,
                required = true,
                min = 0,
                max = 100
            }
        }
    )

    if input then
        farm.config.policeAlert.chance = tonumber(input[1])
        lib.notify({
            type = "success",
            description = locale("notify.updated")
        })
    end
    args.callback(args.farmKey)
end

function Actions.setPoliceAlertType(args)
    local farm = Defaults.Farms[args.farmKey]

    if not farm.config.policeAlert then
        farm.config.policeAlert = {
            enabled = true,
            chance = 30,
            type = "drugsell"
        }
    end

    local alertTypes = {
        {value = "drugsell", label = locale("actions.farm.alert_types.drugsell")},
        {value = "susactivity", label = locale("actions.farm.alert_types.susactivity")},
        {value = "houserobbery", label = locale("actions.farm.alert_types.houserobbery")},
        {value = "storerobbery", label = locale("actions.farm.alert_types.storerobbery")}
    }

    local input = lib.inputDialog(
        locale("actions.farm.police_alert_type"),
        {
            {
                type = "select",
                label = locale("actions.farm.police_alert_type"),
                description = locale("actions.farm.description_police_alert_type"),
                default = farm.config.policeAlert.type or "drugsell",
                required = true,
                options = alertTypes
            }
        }
    )

    if input then
        farm.config.policeAlert.type = input[1]
        lib.notify({
            type = "success",
            description = locale("notify.updated")
        })
    end
    args.callback(args.farmKey)
end

function Actions.changePointLocation(args)
    local location = nil
    local result = Utils.getPedCoords()
    if result.result == "choose" then
        location = result.coords
    end
    if location then
        Defaults.Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey] = location
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            pointKey = args.pointKey
        }
    )
end

function Actions.setFarmName(args)
    local key = nil
    if args and args.farmKey then
        key = args.farmKey
    end
    local farm = {}
    if key then
        farm = Defaults.Farms[key]
    else
        table.clone(newFarm, farm)
    end
    local input =
        lib.inputDialog(
        locale("actions.farm.title"), -- Use correct title
        {
            {
                type = "input",
                label = locale("creator.name"),
                description = locale("creator.description_name"),
                placeholder = locale("creator.placeholder_name"),
                default = farm.name,
                required = true
            }
        }
    )
    if input then
        farm.name = input[1]
        if not key then
            key = #Defaults.Farms + 1
            Defaults.Farms[key] = farm
        end
        Defaults.Farms[key] = farm
    end
    if args.callback then
        args.callback(key)
    end
end

function Actions.setFarmGroup(args)
    local key = args.farmKey
    local farm = Defaults.Farms[key]
    local input =
        lib.inputDialog(
        locale("actions.farm.title"),
        {
            {
                type = "multi-select",
                label = locale("creator.groups"),
                description = string.sub(locale("creator.description_group", ""), 1, -4),
                options = Utils.getBaseGroups(),
                default = farm.group["name"],
                required = false,
                searchable = true
            }
        }
    )
    if input then
        farm.group["name"] = input[1]
        Defaults.Farms[key] = farm
    end
    args.callback(key)
end

function Actions.teleportToFarm(args)
    Utils.tpToLoc(Defaults.Farms[args.farmKey].config.start.location)
    args.callback(args.farmKey)
end

function Actions.teleportToPoint(args)
    Utils.tpToLoc(Defaults.Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey])
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            pointKey = args.pointKey
        }
    )
end

function Actions.setFarmGrade(args)
    local key = args.farmKey
    local farm = Defaults.Farms[key]
    local input =
        lib.inputDialog(
        locale("actions.farm.title"),
        {
            {
                type = "number",
                label = locale("creator.grade"),
                description = locale("creator.description_grade", "0"),
                default = farm.group["grade"] or 0,
                required = true,
                searchable = true,
                min = 0
            }
        }
    )
    if input then
        farm.group["grade"] = tostring(input[1])
        Defaults.Farms[key] = farm
    end
    args.callback(key)
end

local function selItemInput(args, extra)
    return lib.inputDialog(
        locale("actions.item.select"),
        {
            {
                type = "select",
                label = locale("items.name"),
                description = locale("items.description_name"),
                default = (extra and (args["extraItemKey"] or "")) or args["itemKey"],
                options = Utils.getBaseItems(),
                required = true,
                searchable = true,
                clearable = true
            }
        }
    )
end

function Actions.setItem(args)
    local farm = Defaults.Farms[args.farmKey]
    local input = selItemInput(args)
    if input then
        if input[1] ~= args.itemKey then
            local temp = {}
            table.clone(farm.config.items[args.itemKey] or newItem, temp)
            if farm.config.items[args.itemKey] then
                farm.config.items[args.itemKey] = nil
            end
            farm.config.items[input[1]] = temp
            Defaults.Farms[args.farmKey] = farm
        end
    end
    args.callback(
        {
            farmKey = args.farmKey
        }
    )
end

local function selMinMaxInput(args)
    local input =
        lib.inputDialog(
        args.item.label,
        {
            {
                type = "number",
                label = locale("items.min"),
                description = locale("items.description_min"),
                default = args.item.min or 0,
                required = true,
                min = args.min,
                max = args.max
            },
            {
                type = "number",
                label = locale("items.max"),
                description = locale("items.description_max"),
                default = args.item.max or 1,
                required = true,
                min = args.min,
                max = args.max
            },
            {
                type = "textarea",
                min = 5,
                default = args.example,
                disabled = true
            }
        }
    )
    if input then
        if input[2] < input[1] then
            lib.notify(
                {
                    type = "error",
                    description = locale("error.invalid_range")
                }
            )
            input = selMinMaxInput(args)
        end
        return input
    end
end

function Actions.setName(args)
    local Items = getItems()
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("route.setname"),
        {
            {
                type = "input",
                label = locale("route.name"),
                description = locale("route.description"),
                default = item["customName"] or Items[args.itemKey].label,
                min = 5,
                max = 30
            }
        }
    )
    if input then
        item["customName"] = input[1]
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setMinMax(args)
    local Items = getItems()
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_minmax"),
            item = {
                label = Items[args.itemKey].label,
                min = item.min,
                max = item.max
            }
        }
    )
    if input then
        item.min = tonumber(input[1])
        item.max = tonumber(input[2])
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setCollectTime(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.collect_time"),
        {
            {
                type = "number",
                label = locale("items.collect_time"),
                description = locale("items.description_collect_time"),
                default = item.collectTime or DefaultCollectTime,
                required = true,
                min = 0
            }
        }
    )

    if input then
        item.collectTime = input[1] or DefaultCollectTime
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setCollectItem(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local collectItem = item["collectItem"] or {}
    local collectItemName = collectItem["name"]
    local input =
        lib.inputDialog(
        locale("actions.item.collect_item"),
        {
            {
                type = "select",
                label = locale("items.name"),
                description = locale("items.description_collect_item"),
                default = collectItemName or "",
                options = Utils.getBaseItems(),
                searchable = true,
                clearable = true
            }
        }
    )

    if input then
        if input[1] then
            collectItem["name"] = input[1]
            item["collectItem"] = collectItem
        else
            item["collectItem"] = nil
        end
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setItemDurability(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.item_durability"),
        {
            {
                type = "number",
                label = locale("items.durability"),
                description = locale("items.description_item_durability"),
                default = item["collectItem"]["durability"] or 0,
                required = true,
                min = 0,
                max = 100
            }
        }
    )

    if input then
        if input[1] then
            item["collectItem"]["durability"] = input[1]
        else
            item["collectItem"]["durability"] = nil
        end
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setGainStress(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local gainStress = item["gainStress"] or {min = 0, max = 1}
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_stress"),
            item = {
                label = locale("creator.stress"),
                min = item.min,
                max = item.max
            }
        }
    )
    if input then
        gainStress["min"] = tonumber(input[1]) or 0
        gainStress["max"] = tonumber(input[2]) or 0
        item["gainStress"] = gainStress
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setItemPoliceAlert(args)
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]

    if not item.policeAlert then
        item.policeAlert = {
            chance = farm.config.policeAlert and farm.config.policeAlert.chance or 30,
            type = farm.config.policeAlert and farm.config.policeAlert.type or "drugsell"
        }
    end

    local input = lib.inputDialog(
        locale("actions.item.police_alert"),
        {
            {
                type = "number",
                label = locale("actions.item.police_alert_chance"),
                description = locale("actions.item.description_police_alert_chance"),
                default = item.policeAlert.chance or 30,
                required = true,
                min = 0,
                max = 100
            }
        }
    )

    if input then
        item.policeAlert.chance = tonumber(input[1])
        lib.notify({
            type = "success",
            description = locale("notify.updated")
        })
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setItemPoliceAlertType(args)
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]

    if not item.policeAlert then
        item.policeAlert = {
            chance = farm.config.policeAlert and farm.config.policeAlert.chance or 30,
            type = farm.config.policeAlert and farm.config.policeAlert.type or "drugsell"
        }
    end

    local alertTypes = {
        {value = "drugsell", label = locale("actions.farm.alert_types.drugsell")},
        {value = "susactivity", label = locale("actions.farm.alert_types.susactivity")},
        {value = "houserobbery", label = locale("actions.farm.alert_types.houserobbery")},
        {value = "storerobbery", label = locale("actions.farm.alert_types.storerobbery")}
    }

    local input = lib.inputDialog(
        locale("actions.item.police_alert_type"),
        {
            {
                type = "select",
                label = locale("actions.item.police_alert_type"),
                description = locale("actions.item.description_police_alert_type"),
                default = item.policeAlert.type or "drugsell",
                required = true,
                options = alertTypes
            }
        }
    )

    if input then
        item.policeAlert.type = input[1]
        lib.notify({
            type = "success",
            description = locale("notify.updated")
        })
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.resetItemPoliceAlert(args)
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]

    item.policeAlert = nil

    lib.notify({
        type = "success",
        description = locale("notify.updated")
    })

    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

function Actions.importFarm()
    local input = lib.inputDialog(
        locale("actions.import"),
        {
            {
                type = "input",
                label = locale("actions.farm.import_name"),
                description = locale("actions.farm.description_import_name"),
                required = true
            },
            {
                type = "textarea",
                label = locale("actions.farm.import_data"),
                description = locale("actions.farm.description_import_data"),
                required = true
            }
        }
    )

    if not input then return end

    local farmName = input[1]
    local farmData = input[2]

    local success, decodedData = pcall(function()
        return json.decode(farmData)
    end)

    if not success or not decodedData then
        lib.notify({
            type = "error",
            description = locale("actions.import_invalid_json")
        })
        return
    end

    local newFarm = {
        name = farmName,
        config = decodedData.config or {},
        group = decodedData.group or {}
    }

    if not newFarm.config.items then
        newFarm.config.items = {}
    end

    if not newFarm.config.start then
        newFarm.config.start = {}
    end

    local success = lib.callback.await("mri_Qfarm:server:SaveFarm", false, newFarm)

    if success then
        lib.notify({
            type = "success",
            description = locale("actions.imported")
        })

        TriggerEvent("mri_Qfarm:client:LoadFarms")
    else
        lib.notify({
            type = "error",
            description = locale("actions.not_imported")
        })
    end
end

function Actions.toggleDebugPoints(args)
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]

    item.debugPoints = not item.debugPoints

    Defaults.Farms[args.farmKey].config.items[args.itemKey] = item

    if item.debugPoints then
        item.debugBlips = {}
        item.debugZones = {}

        for i, point in ipairs(item.points) do
            local blip = AddBlipForCoord(point.x, point.y, point.z)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, 5)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Ponto De Coleta " .. i)
            EndTextCommandSetBlipName(blip)

            table.insert(item.debugBlips, blip)

            local zone = lib.zones.sphere({
                coords = vector3(point.x, point.y, point.z),
                radius = 1.0,
                debug = true,
                inside = function()
                end
            })

            table.insert(item.debugZones, zone)
        end

        lib.notify({
            type = "success",
            description = locale("actions.item.debug_enabled")
        })
    else
        if item.debugBlips then
            for _, blip in ipairs(item.debugBlips) do
                RemoveBlip(blip)
            end
            item.debugBlips = nil
        end

        if item.debugZones then
            for _, zone in ipairs(item.debugZones) do
                zone:remove()
            end
            item.debugZones = nil
        end

        lib.notify({
            type = "inform",
            description = locale("actions.item.debug_disabled")
        })
    end
    args.callback(args)
end

function Actions.setRandom(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.random"),
        {
            {
                type = "checkbox",
                label = locale("actions.item.random"),
                description = locale("actions.item.description_random"),
                checked = item.randomRoute
            }
        }
    )
    if input then
        item.randomRoute = input[1] or false
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setUnlimited(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.unlimited"),
        {
            {
                type = "checkbox",
                label = locale("actions.item.unlimited"),
                description = locale("actions.item.description_unlimited"),
                checked = item.unlimited
            }
        }
    )
    if input then
        item.unlimited = input[1] or false
        Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.setAnimation(args)
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    if Config.UseEmoteMenu then
        local input =
            lib.inputDialog(
            locale("actions.item.animation"),
            {
                {
                    type = "input",
                    label = locale("actions.item.animation"),
                    description = locale("actions.item.description_anim_name"),
                    default = type(item.animation) ~= "table" and item.animation or "",
                    required = true
                }
            }
        )
        if input then
            item.animation = input[1]
            Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
        end
    else
        local input =
            lib.inputDialog(
            locale("items.animation"),
            {
                {
                    type = "input",
                    label = locale("anim.dict"),
                    default = item.animation.dict or "amb@prop_human_bum_bin@idle_a",
                    required = true
                },
                {
                    type = "input",
                    label = locale("anim.anim"),
                    default = item.animation.anim or "idle_a",
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.inspeed"),
                    default = item.animation.inSpeed or 6.0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.outspeed"),
                    default = item.animation.outSpeed or -6.0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.duration"),
                    default = item.animation.duration or -1,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.flag"),
                    default = item.animation.flag or 47,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.rate"),
                    default = item.animation.rate or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.x"),
                    default = item.animation.x or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.y"),
                    default = item.animation.y or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.z"),
                    default = item.animation.z or 0,
                    required = true
                }
            }
        )
        if input then
            local _anim = item.animation or {}
            if type(item.animation) == "string" then
                _anim = {}
            end
            _anim['dict'] = input[1]
            _anim['anim'] = input[2]
            _anim['inSpeed'] = input[3]
            _anim['outSpeed'] = input[4]
            _anim['duration'] = input[5]
            _anim['flag'] = input[6]
            _anim['rate'] = input[7]
            _anim['x'] = input[8]
            _anim['y'] = input[9]
            _anim['z'] = input[10]
            item.animation = _anim
            Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
        end
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.addPoints(args)
    local keepLoop = true
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    while keepLoop do
        Wait(0)
        local result = Utils.getPedCoords()
        keepLoop = result.result == "choose"
        if keepLoop then
            item.points[#item.points + 1] = result.coords
            lib.notify(
                {
                    type = "success",
                    description = locale("actions.point.add")
                }
            )
        end
    end
    Defaults.Farms[args.farmKey].config.items[args.itemKey] = item
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function Actions.addExtraItem(args)
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItems = item["extraItems"] or {}
    local input = selItemInput(args, true)
    if input then
        extraItems[input[1]] = {
            min = 0,
            max = 1
        }
        item["extraItems"] = extraItems
        farm.config.items[args.itemKey] = item
        Defaults.Farms[args.farmKey] = farm
    else
        args.callback(args)
        return
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            extraItemKey = input[1]
        }
    )
end

function Actions.setMinMaxExtraItem(args)
    local Items = getItems()
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItems = item["extraItems"] or {}
    local extraItem = extraItems[args.extraItemKey]
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_minmax"),
            item = {
                label = Items[args.extraItemKey].label,
                min = extraItem.min,
                max = extraItem.max
            }
        }
    )
    if input then
        extraItems[args.extraItemKey].min = input[1] or 0
        extraItems[args.extraItemKey].max = input[2] or 1
        item["extraItems"] = extraItems
        farm.config.items[args.itemKey] = item
        Defaults.Farms[args.farmKey] = farm
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            extraItemKey = args.extraItemKey
        }
    )
end

function Actions.duplicateFarm(args)
    local farm = Defaults.Farms[args.farmKey]
    if not farm then return end

    local newFarm = {
        name = farm.name .. " (copy)",
        config = json.decode(json.encode(farm.config)),
        group = json.decode(json.encode(farm.group))
    }

    local success = lib.callback.await("mri_Qfarm:server:SaveFarm", false, newFarm)

    if success then
        lib.notify({
            type = "success",
            description = locale("actions.duplicated")
        })

        TriggerEvent("mri_Qfarm:client:LoadFarms")
    else
        lib.notify({
            type = "error",
            description = locale("actions.not_duplicated")
        })
    end
end

function Actions.saveFarm(args)
    lib.callback.await("mri_Qfarm:server:SaveFarm", false, Defaults.Farms[args.farmKey], args.farmKey)
    args.callback(args.farmKey)
end

return Actions
