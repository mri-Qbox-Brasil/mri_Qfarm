local Config = lib.require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = lib.require("client/defaults")
local Actions = lib.require("client/modules/creator/actions")

local function getItems()
    return exports.ox_inventory:Items()
end

local Menus = {}

local manageFarms
local ListFarm
local actionMenu
local ListItems
local itemActionMenu
local configMenu
local listPoints
local pointMenu
local listExtraItems
local extraItemActionMenu

local function ifThen(condition, ifTrue, ifFalse)
    if condition then
        return ifTrue
    end
    return ifFalse
end

function pointMenu(args)
    local ctx = {
        id = "point_item",
        menu = "list_points",
        title = args.name,
        options = {
            {
                title = locale("actions.point.change_location"),
                description = locale("actions.point.description_change_location"),
                icon = "location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.changePointLocation,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    callback = pointMenu
                }
            },
            {
                title = locale("actions.teleport"),
                description = locale("actions.description_teleport"),
                icon = "location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.teleportToPoint,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    callback = pointMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.point")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = Defaults.ColorScheme.danger,
                onSelect = Actions.deletePoint,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    name = args.name,
                    callback = listPoints
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function listPoints(args)
    local Items = getItems()
    local ctx = {
        id = "list_points",
        menu = "action_item",
        title = locale("menus.points", Items[args.itemKey].label),
        options = {
            {
                title = locale("actions.add_point"),
                description = locale("actions.description_add_point"),
                icon = "square-plus",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.addPoints,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = listPoints
                }
            }
        }
    }
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    for k, v in pairs(item.points) do
        ctx.options[#ctx.options + 1] = {
            title = Utils.getLocationFormatted(v, k),
            description = string.format("X: %.2f, Y: %.2f, Z: %.2f", v.x, v.y, v.z),
            icon = "map-pin",
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = pointMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = k,
                name = Utils.getLocationFormatted(v, k)
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function extraItemActionMenu(args)
    local Items = getItems()
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItem = item["extraItems"][args.extraItemKey]
    local ctx = {
        id = "extra_item_action",
        menu = "list_extra_items",
        title = locale("menus.extra_items", Items[args.extraItemKey].label),
        description = locale("menu.description_extra_items", extraItem.min, extraItem.max),
        options = {
            {
                title = locale("actions.item.select"),
                icon = "box-open",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.addExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = extraItemActionMenu
                }
            },
            {
                title = locale("actions.item.minmax"),
                description = locale("actions.item.description_minmax", extraItem.min, extraItem.max),
                icon = "up-down",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setMinMaxExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    extraItemKey = args.extraItemKey,
                    callback = extraItemActionMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.item.title")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = Defaults.ColorScheme.danger,
                onSelect = Actions.deleteExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    extraItemKey = args.extraItemKey,
                    callback = listExtraItems
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function listExtraItems(args)
    if not args.farmKey then args = args[1] end

    local Items = getItems()
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local ctx = {
        id = "list_extra_items",
        menu = "config_item",
        title = locale("menus.extra_items", Items[args.itemKey].label),
        options = {}
    }
    ctx.options[#ctx.options + 1] = {
        title = locale("actions.item.add_extra_item"),
        description = locale("actions.item.description_add_extra_item"),
        icon = "square-plus",
        iconAnimation = Config.IconAnimation,
        onSelect = Actions.addExtraItem,
        args = {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            callback = listExtraItems
        }
    }
    for k, v in pairs(item.extraItems or {}) do
        ctx.options[#ctx.options + 1] = {
            title = Items[k].label,
            description = locale("items.extra_description", v.min, v.max),
            icon = string.format("%s/%s.png", Config.ImageURL, Items[k].name),
            iconAnimation = Config.IconAnimation,
            onSelect = extraItemActionMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                extraItemKey = k,
                callback = listExtraItems
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function configMenu(args)
    local Items = getItems()
    local farm = Defaults.Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]

    local DefaultCollectTime = Defaults.CollectTime or 5000

    local ctx = {
        id = "config_item",
        menu = "action_item",
        title = Items[args.itemKey].label,
        description = Items[args.itemKey].description,
        options = {
            {
                title = locale("actions.item.collect_time"),
                description = locale("actions.item.description_collect_time", item.collectTime or DefaultCollectTime),
                icon = "clock",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setCollectTime,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.collect_item"),
                description = locale(
                    "actions.item.description_collect_item",
                    item["collectItem"] and item["collectItem"]["name"] and Items[item["collectItem"]["name"]].label or
                        locale("misc.none")
                ),
                icon = "screwdriver-wrench",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setCollectItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.item_durability"),
                description = locale(
                    "actions.item.description_item_durability",
                    item["collectItem"] and item["collectItem"]["name"] and Items[item["collectItem"]["name"]].label or
                        locale("misc.none"),
                    item["collectItem"] and item["collectItem"]["durability"] or 0
                ),
                icon = "wrench",
                iconAnimation = Config.IconAnimation,
                disabled = item["collectItem"] == nil or item["collectItem"]["name"] == nil,
                onSelect = Actions.setItemDurability,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.gain_stress"),
                description = locale(
                    "actions.item.description_gain_stress",
                    item["gainStress"] and (item["gainStress"]["min"]) or 0,
                    item["gainStress"] and (item["gainStress"]["max"]) or 0
                ),
                icon = "face-tired",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setGainStress,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.police_alert"),
                description = locale("actions.item.description_police_alert",
                    item.policeAlert and item.policeAlert.chance or locale("actions.item.global_setting")),
                icon = "bell",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setItemPoliceAlert,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.police_alert_type"),
                description = locale("actions.item.description_police_alert_type",
                    item.policeAlert and item.policeAlert.type or locale("actions.item.global_setting")),
                icon = "triangle-exclamation",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setItemPoliceAlertType,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.reset_police_alert"),
                description = locale("actions.item.description_reset_police_alert"),
                icon = "rotate-left",
                iconAnimation = Config.IconAnimation,
                disabled = item.policeAlert == nil,
                onSelect = Actions.resetItemPoliceAlert,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.random"),
                description = locale(
                    "actions.item.description_random",
                    item.randomRoute and locale("misc.yes") or locale("misc.no")
                ),
                icon = "shuffle",
                iconColor = ifThen(item.randomRoute, Defaults.ColorScheme.success, Defaults.ColorScheme.danger),
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setRandom,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.unlimited"),
                description = locale(
                    "actions.item.description_unlimited",
                    item.unlimited and locale("misc.yes") or locale("misc.no")
                ),
                icon = "infinity",
                iconAnimation = Config.IconAnimation,
                iconColor = ifThen(item.unlimited, Defaults.ColorScheme.success, Defaults.ColorScheme.danger),
                onSelect = Actions.setUnlimited,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.extraItems"),
                description = locale("actions.item.description_extraItems"),
                icon = "list",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = listExtraItems,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function itemActionMenu(args)
    local Items = getItems()
    local item = Defaults.Farms[args.farmKey].config.items[args.itemKey]
    local ctx = {
        id = "action_item",
        title = item["customName"] and item["customName"] ~= "" and item["customName"] or Items[args.itemKey].label,
        description = Items[args.itemKey].description,
        menu = "items_farm",
        options = {
            {
                title = locale("actions.item.setname"),
                description = locale("actions.item.description_setname"),
                icon = "tag",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setName,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.select"),
                description = locale("actions.item.description_select"),
                icon = "box-open",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = ListItems
                }
            },
            {
                title = locale("actions.item.minmax"),
                description = locale("actions.item.description_minmax", item.min or 0, item.max or 0),
                icon = "up-down",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setMinMax,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.config"),
                description = locale("actions.item.description_config"),
                icon = "gear",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = configMenu,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.animation"),
                description = locale("actions.item.description_animation"),
                icon = "person-walking",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setAnimation,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.afk"),
                description = locale("actions.farm.afk.description", ifThen(Defaults.Farms[args.farmKey].config.afk, locale("misc.actived"), locale("misc.disabled"))),
                icon = "person-walking",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.changeFarmAFK,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.points"),
                description = locale("actions.item.description_points", #item.points),
                icon = "location-crosshairs",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = listPoints,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey
                }
            },
            {
                title = locale("actions.item.debug_points"),
                description = locale("actions.item.description_debug_points",
                    ifThen(item.debugPoints, locale("misc.yes"), locale("misc.no"))),
                icon = ifThen(item.debugPoints, "toggle-on", "toggle-off"),
                iconColor = ifThen(item.debugPoints, Defaults.ColorScheme.success, Defaults.ColorScheme.danger),
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.toggleDebugPoints,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.item.title")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = Defaults.ColorScheme.danger,
                onSelect = Actions.deleteItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = ListItems,
                    callbackCancel = itemActionMenu
                }
            }
        }
    }

    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListItems(args)
    if not args.farmKey then args = args[1] end

    local Items = getItems()
    local farm = Defaults.Farms[args.farmKey]
    local ctx = {
        id = "items_farm",
        title = locale("menus.items"),
        menu = "action_farm",
        description = farm.name,
        options = {
            {
                title = locale("actions.item.create"),
                description = locale("actions.item.description_create"),
                icon = "square-plus",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = Actions.setItem,
                args = {
                    farmKey = args.farmKey,
                    callback = ListItems
                }
            }
        }
    }
    if not farm or not farm.config then
        Utils.debug("ListItems", "Farm or config is nil")
        if callback then callback() end
        return
    end

    for k, v in pairs(farm.config.items or {}) do
        if Items[k] then
            ctx.options[#ctx.options + 1] = {
                title = v["customName"] and v["customName"] ~= "" and v["customName"] or Items[k].label,
                icon = string.format("%s/%s.png", Config.ImageURL, Items[k].name),
                image = string.format("%s/%s.png", Config.ImageURL, Items[k].name),
                metadata = Utils.getItemMetadata(Items[k]),
                description = Items[k].description,
                onSelect = itemActionMenu,
                args = {
                    itemKey = k,
                    farmKey = args.farmKey
                }
            }
        else
            ctx.options[#ctx.options + 1] = {
                title = locale("error.invalid_item", k),
                description = locale("error.invalid_item_description"),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = Defaults.ColorScheme.danger,
                onSelect = Actions.deleteItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = k,
                    callback = ListItems,
                    callbackCancel = ListItems
                }
            }
        end
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function actionMenu(key)
    if type(key) == "table" then key = key.farmKey end

    local farm = Defaults.Farms[key]
    if not farm then
        Utils.debug("actionMenu", "Farm is nil for key " .. tostring(key))
        return
    end

    local groupName = locale("creator.no_group")
    local grade = "0"
    local disableGradeSet = false

    farm.group = farm.group or {}
    farm.config = farm.config or { start = {} }
    farm.config.start = farm.config.start or {}

    if farm.group["name"] then
        groupName = Utils.getGroupsLabel(farm.group["name"])
    else
        disableGradeSet = true
    end
    if farm.group["grade"] then
        grade = farm.group["grade"]
    end
    local locationText = locale("actions.farm.change_location")
    if farm.config.start.location == nil then
        locationText = locale("actions.farm.set_location")
    end
    local startDescription = locale("actions.farm.nostart.description", farm.config.nostart and locale("misc.yes") or locale("misc.no"))

    local ctx = {
        id = "action_farm",
        title = (farm.name or "UNKNOWN"):upper(),
        menu = "list_farms",
        options = {
            {
                title = locale("actions.farm.rename"),
                description = locale("actions.farm.description_rename"),
                icon = "tag",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setFarmName,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("creator.groups"),
                description = locale("creator.description_group", groupName),
                icon = "users",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setFarmGroup,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("creator.grade"),
                description = locale("creator.description_grade", grade),
                icon = "list-ol",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setFarmGrade,
                disabled = disableGradeSet,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locationText,
                icon = "map-location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.changeFarmLocation,
                description = locale("actions.farm.description_location"),
                disabled = farm.config.nostart,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.farm.vehicle_requirement"),
                icon = ifThen(farm.config.requireVehicle, "toggle-on", "toggle-off"),
                iconAnimation = Config.IconAnimation,
                iconColor = ifThen(farm.config.requireVehicle, Defaults.ColorScheme.success, Defaults.ColorScheme.danger),
                onSelect = Actions.toggleFarmVehicleRequirement,
                description = locale(
                    "actions.farm.description_vehicle_requirement",
                    farm.config.requireVehicle and locale("misc.yes") or locale("misc.no")
                ),
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.farm.vehicle"),
                icon = "car-side",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.setFarmVehicle,
                description = locale(
                    "actions.farm.description_vehicle",
                    farm.config.vehicle or locale("misc.none")
                ),
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.farm.nostart.label"),
                icon = "bolt",
                iconAnimation = Config.IconAnimation,
                iconColor = ifThen(farm.config.nostart, Defaults.ColorScheme.success, Defaults.ColorScheme.danger),
                onSelect = Actions.changeFarmStart,
                description = startDescription,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.farm.items"),
                description = locale("actions.farm.description_items"),
                icon = "route",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = ListItems,
                args = {
                    farmKey = key
                }
            },
            {
                title = locale("actions.farm.police_alert.label"),
                description = locale("actions.farm.police_alert.description", ifThen(farm.config.policeAlert and farm.config.policeAlert.enabled, locale("misc.yes"), locale("misc.no"))),
                icon = "bell",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.togglePoliceAlert,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            }
        }
    }

    if farm.config.policeAlert and farm.config.policeAlert.enabled then
        table.insert(ctx.options, 8, {
            title = locale("actions.farm.police_alert_chance"),
            description = locale("actions.farm.description_police_alert_chance", farm.config.policeAlert.chance or 30),
            icon = "percent",
            iconAnimation = Config.IconAnimation,
            onSelect = Actions.setPoliceAlertChance,
            args = {
                farmKey = key,
                callback = actionMenu
            }
        })

        table.insert(ctx.options, 9, {
            title = locale("actions.farm.police_alert_type"),
            description = locale("actions.farm.description_police_alert_type", farm.config.policeAlert.type or "drugsell"),
            icon = "triangle-exclamation",
            iconAnimation = Config.IconAnimation,
            onSelect = Actions.setPoliceAlertType,
            args = {
                farmKey = key,
                callback = actionMenu
            }
        })
    end

    table.insert(ctx.options, {
        title = locale("actions.teleport"),
        description = locale("actions.description_teleport"),
        icon = "location-dot",
        iconAnimation = Config.IconAnimation,
        onSelect = Actions.teleportToFarm,
        disabled = farm.config.nostart,
        args = {
            farmKey = key,
            callback = actionMenu
        }
    })

    table.insert(ctx.options, {
        title = locale("actions.export"),
        description = locale("actions.description_export", locale("actions.farm.title")),
        icon = "share-from-square",
        iconAnimation = Config.IconAnimation,
        onSelect = Actions.exportFarm,
        args = {
            farmKey = key,
            callback = actionMenu
        }
    })

    table.insert(ctx.options, {
        title = locale("actions.duplicate"),
        description = locale("actions.description_duplicate", locale("actions.farm.title")),
        icon = "copy",
        iconAnimation = Config.IconAnimation,
        onSelect = Actions.duplicateFarm,
        args = {
            farmKey = key
        }
    })

    table.insert(ctx.options, {
        title = locale("actions.save"),
        description = locale("actions.description_save"),
        icon = "floppy-disk",
        iconAnimation = Config.IconAnimation,
        onSelect = Actions.saveFarm,
        args = {
            farmKey = key,
            callback = actionMenu
        }
    })

    table.insert(ctx.options, {
        title = locale("actions.delete"),
        description = locale("actions.description_delete", locale("actions.farm.title")),
        icon = "trash",
        iconAnimation = Config.IconAnimation,
        iconColor = Defaults.ColorScheme.danger,
        onSelect = Actions.deleteFarm,
        args = {
            farmKey = key,
            callback = ListFarm,
            callbackCancel = actionMenu
        }
    })

    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListFarm()
    local ctx = {
        id = "list_farms",
        menu = "menu_farm",
        title = locale("menus.farms"),
        description = locale("actions.farm.description_title", #Defaults.Farms),
        options = {}
    }
    for k, v in pairs(Defaults.Farms or {}) do
        local groupName = locale("creator.no_group")
        v.group = v.group or {}
        if v.group["name"] then
            groupName = Utils.getGroupsLabel(v.group["name"])
        end
        local description = locale("menus.description_farm", locale("creator.groups"), groupName)
        ctx.options[#ctx.options + 1] = {
            title = v.name:upper(),
            icon = "warehouse",
            iconAnimation = Config.IconAnimation,
            description = description,
            metadata = Utils.getMetadataFromFarm(k),
            onSelect = function()
                actionMenu(k)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function manageFarms()
    local Items = getItems()
    local ctx = {
        id = "menu_farm",
        menu = "menu_gerencial",
        title = locale("actions.farm.title"),
        description = locale("actions.farm.description_title", #Defaults.Farms),
        options = {
            {
                title = locale("actions.import"),
                description = locale("actions.description_import", locale("actions.farm.label")),
                icon = "file-import",
                iconAnimation = Config.IconAnimation,
                onSelect = Actions.importFarm,
                args = {
                    callback = ListFarm
                }
            },
            {
                title = locale("actions.farm.create"),
                description = locale("actions.farm.description_create"),
                icon = "square-plus",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = Actions.setFarmName,
                args = {
                    callback = ListFarm
                }
            },
            {
                title = locale("actions.farm.list"),
                description = locale("actions.farm.description_list"),
                icon = "list-ul",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = ListFarm
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

Menus.manageFarms = manageFarms
Menus.ListFarm = ListFarm
Menus.actionMenu = actionMenu
Menus.ListItems = ListItems
Menus.itemActionMenu = itemActionMenu
Menus.configMenu = configMenu
Menus.listPoints = listPoints
Menus.pointMenu = pointMenu
Menus.listExtraItems = listExtraItems
Menus.extraItemActionMenu = extraItemActionMenu

return Menus
