local Utils = lib.require('client/utils')
local newFarm = {
    name = nil,
    config = {
        start = {
            location = nil,
            width = nil,
            length = nil
        },
        items = {}
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
    points = {},
    animation = Utils.GetDefaultAnim()
}

local function Delete(caption, tableObj, key)
    if Utils.ConfirmationDialog(caption) == 'confirm' then
        tableObj[key] = nil
        return true
    end
    return false
end

local function DeleteFarm(args)
    local result = Delete(locale('actions.confirmation_description', locale('actions.farm'), Farms[args.key].name), Farms, args.key)
    if result then
        TriggerServerEvent('mri_Qfarm:server:DeleteFarm', args.key)
        args.callback()
    else
        args.callbackCancel(args.key)
    end
end

local function DeleteItem(args)
    local result = Delete(locale('actions.confirmation_description', locale('actions.item'), Items[args.itemKey].label),
        Farms[args.farmKey].config.items, args.itemKey)
    if result then
        args.callback({
            key = args.farmKey
        })
    else
        args.callbackCancel({
            farmKey = args.farmKey,
            itemKey = args.itemKey
        })
    end
end

local function DeletePoint(args)
    local result = Delete(locale('actions.confirmation_description', locale('actions.point'), args.name),
        Farms[args.farmKey].config.items[args.itemKey].points, args.pointKey)
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

local function ExportFarm(args)
    lib.setClipboard(json.encode(Farms[args.key], {indent = true}))
    lib.notify({
        type = "success",
        description = "Copiado para a área de transferência."
    })
    args.callback(args.key)
end

local function ChangeFarmLocation(args)
    local location = nil
    local result = Utils.GetPedCoords()
    if result.result == 'choose' then
        location = result.coords
    end
    if location then
        Farms[args.key].config.start = {
            location = location,
            width = Config.FarmBoxWidth,
            length = Config.FarmBoxLength
        }
        lib.notify({
            type = 'success',
            description = locale('notify.updated')
        })
    end
    args.callback(args.key)
end

local function ChangePointLocation(args)
    local location = nil
    local result = Utils.GetPedCoords()
    if result.result == 'choose' then
        location = result.coords
    end
    if location then
        Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey] = location
        lib.notify({
            type = 'success',
            description = locale('notify.updated')
        })
    end
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey,
        pointKey = args.pointKey
    })
end

local function SetFarmName(args)
    local key = nil
    if args and args.key then
        key = args.key
    end
    local farm = {}
    if key then
        farm = Farms[key]
    else
        table.clone(newFarm, farm)
    end
    local input = lib.inputDialog(title, {{
        type = 'input',
        label = locale('creator.name'),
        description = locale('creator.description_name'),
        placeholder = locale('creator.placeholder_name'),
        default = farm.name,
        required = true
    }})
    if input then
        farm.name = input[1]
        if not key then
            key = #Farms + 1
            Farms[key] = farm
        end
        Farms[key] = farm
    end
    args.callback(key)
end

local function SetFarmGroup(args)
    local key = args.key
    local farm = Farms[key]
    local input = lib.inputDialog(title, {{
        type = 'select',
        label = locale('creator.group'),
        description = locale('creator.description_group'),
        options = Utils.GetBaseGroups(),
        default = farm.group['name'],
        required = true,
        searchable = true
    }})
    if input then
        farm.group['name'] = input[1]
        Farms[key] = farm
    end
    args.callback(key)
end

local function TeleportToFarm(args)
    Utils.TpToLoc(Farms[args.key].config.start.location)
    args.callback(args.key)
end

local function TeleportToPoint(args)
    Utils.TpToLoc(Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey])
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey,
        pointKey = args.pointKey
    })
end

local function SetFarmGrade(args)
    local key = args.key
    local farm = Farms[key]
    local input = lib.inputDialog(title, {{
        type = 'select',
        label = locale('creator.grade'),
        description = locale('creator.description_grade'),
        options = Utils.GetBaseGroups(true)[farm.group.name].grades,
        default = farm.group['grade'] or 0,
        required = true,
        searchable = true
    }})
    if input then
        farm.group['grade'] = input[1]
        Farms[key] = farm
    end
    args.callback(key)
end

local function SetItem(args)
    local farm = Farms[args.farmKey]
    local input = lib.inputDialog(locale('actions.item.change'), {{
        type = 'select',
        label = locale('items.name'),
        description = locale('items.description_name'),
        default = args.itemKey,
        options = Utils.GetBaseItems(),
        required = true,
        searchable = true,
        clearable = true
    }})
    if input then
        if input[1] ~= args.itemKey then
            local temp = {}
            table.clone(farm.config.items[args.itemKey] or newItem, temp)
            if farm.config.items[args.itemKey] then
                farm.config.items[args.itemKey] = nil
            end
            farm.config.items[input[1]] = temp
        end
    end
    args.callback({key = args.farmKey})
end

local function SetMinMax(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input = lib.inputDialog(locale('actions.item.minmax'), {{
        type = 'number',
        label = locale('items.min'),
        description = locale('items.description_min'),
        default = item.min or 0,
        required = true
    }, {
        type = 'number',
        label = locale('items.max'),
        description = locale('items.description_max'),
        default = item.max or 1,
        required = true
    }})
    if input then
        item.min = tonumber(input[1])
        item.max = tonumber(input[2])
    end
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

local function SetRandom(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input = lib.inputDialog(locale('actions.item.random'), {{
        type = 'checkbox',
        label = locale('actions.item.random'),
        description = locale('actions.item.description_random'),
        checked = item.randomRoute
    }})
    if input then
        item.randomRoute = input[1] or false
    end
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

local function SetAnimation(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    if Config.UseEmoteMenu then
        local input = lib.inputDialog(locale('actions.item.animation'), {{
            type = 'input',
            label = locale('actions.item.animation'),
            description = locale('actions.item.description_anim_name'),
            default = type(item.animation) ~= 'table' and item.animation or '',
            required = true
        }})
        if input then
            item.animation = input[1]
        end
    else
        local input = lib.inputDialog(locale('items.animation'), {{
            type = 'input',
            label = locale('anim.dict'),
            default = item.animation.dict or 'amb@prop_human_bum_bin@idle_a',
            required = true
        }, {
            type = 'input',
            label = locale('anim.anim'),
            default = item.animation.anim or 'idle_a',
            required = true
        }, {
            type = 'number',
            label = locale('anim.inspeed'),
            default = item.animation.inSpeed or 6.0,
            required = true
        }, {
            type = 'number',
            label = locale('anim.outspeed'),
            default = item.animation.outSpeed or -6.0,
            required = true
        }, {
            type = 'number',
            label = locale('anim.duration'),
            default = item.animation.duration or -1,
            required = true
        }, {
            type = 'number',
            label = locale('anim.flag'),
            default = item.animation.flag or 47,
            required = true
        }, {
            type = 'number',
            label = locale('anim.rate'),
            default = item.animation.rate or 0,
            required = true
        }, {
            type = 'number',
            label = locale('anim.x'),
            default = item.animation.x or 0,
            required = true
        }, {
            type = 'number',
            label = locale('anim.y'),
            default = item.animation.y or 0,
            required = true
        }, {
            type = 'number',
            label = locale('anim.z'),
            default = item.animation.z or 0,
            required = true
        }})
        if input then
            local _anim = item.animation or {}
            _anim.dict = input[1]
            _anim.anim = input[2]
            _anim.inSpeed = input[3]
            _anim.outSpeed = input[4]
            _anim.duration = input[5]
            _anim.flag = input[6]
            _anim.rate = input[7]
            _anim.x = input[8]
            _anim.y = input[9]
            _anim.z = input[10] or false
            item.animation = _anim
            return true, item
        end
    end
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

local function PointMenu(args)
    local ctx = {
        id = 'point_item',
        menu = 'list_points',
        title = args.name,

        options = {{
            title = locale('actions.point.change_location'),
            description = locale('actinos.point.description_change_location'),
            icon = 'location-dot',
            iconAnimation = Config.IconAnimation,
            onSelect = ChangePointLocation,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey,
                callback = PointMenu
            }
        }, {
            title = locale('actions.teleport'),
            description = locale('actions.description_teleport'),
            icon = 'location-dot',
            iconAnimation = Config.IconAnimation,
            onSelect = TeleportToPoint,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey,
                callback = PointMenu
            }
        }, {
            title = locale('actions.delete'),
            description = locale("actions.description_delete", locale("actions.point")),
            icon = 'trash',
            iconAnimation = Config.IconAnimation,
            iconColor = ColorScheme.danger,
            onSelect = DeletePoint,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey,
                name = args.name,
                callback = ListPoints
            }
        }}
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function AddPoints(args)
    local keepLoop = true
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    while keepLoop do
        Wait(0)
        local result = Utils.GetPedCoords()
        keepLoop = result.result == 'choose'
        if keepLoop then
            item.points[#item.points + 1] = result.coords
            lib.notify({
                type = 'success',
                description = 'Ponto adicionado.'
            })
        end
    end
    Farms[args.farmKey].config.items[args.itemKey] = item
    args.callback({
        farmKey = args.farmKey,
        itemKey = args.itemKey
    })
end

function ListPoints(args)
    local ctx = {
        id = 'list_points',
        menu = 'action_item',
        title = locale('menus.points', Items[args.itemKey].label),
        options = {{
            title = locale('actions.add_point'),
            description = locale('actions.description_add_point'),
            icon = 'square-plus',
            iconAnimation = Config.IconAnimation,
            onSelect = AddPoints,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ListPoints
            }
        }}
    }
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    for k, v in pairs(item.points) do
        ctx.options[#ctx.options + 1] = {
            title = Utils.GetLocationFormatted(v, k),
            description = string.format('X: %.2f, Y: %.2f, Z: %.2f', v.x, v.y, v.z),
            icon = 'map-pin',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = PointMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = k,
                name = Utils.GetLocationFormatted(v, k)
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function ItemActionMenu(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local ctx = {
        id = 'action_item',
        title = Items[args.itemKey].label,
        description = locale('actions.item.description_menu', item.randomRoute and 'Sim' or 'Não', item.min or 0, item.max or 1),
        menu = 'items_farm',
        options = {{
            title = locale('actions.item.change'),
            description = locale('actions.item.description_change'),
            icon = 'file-pen',
            iconAnimation = Config.IconAnimation,
            onSelect = SetItem,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ListItems
            }
        }, {
            title = locale('actions.item.minmax'),
            description = locale('actions.item.description_minmax'),
            icon = 'up-down',
            iconAnimation = Config.IconAnimation,
            onSelect = SetMinMax,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ItemActionMenu
            }
        }, {
            title = locale('actions.item.random'),
            description = locale('actions.item.description_random'),
            icon ='shuffle',
            iconAnimation = Config.IconAnimation,
            onSelect = SetRandom,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ItemActionMenu
            }
        }, {
            title = locale('actions.item.animation'),
            description = locale('actions.item.description_animation'),
            icon = 'person-walking',
            iconAnimation = Config.IconAnimation,
            onSelect = SetAnimation,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ItemActionMenu
            }
        }, {
            title = locale('actions.points'),
            description = locale('actions.description_points'),
            icon = 'location-crosshairs',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = ListPoints,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey
            }
        }, {
            title = locale('actions.delete'),
            description = locale("actions.description_delete", locale("actions.item")),
            icon = 'trash',
            iconAnimation = Config.IconAnimation,
            iconColor = ColorScheme.danger,
            onSelect = DeleteItem,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                callback = ListItems,
                callbackCancel = ItemActionMenu
            }
        }}
    }

    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListItems(args)
    local farm = Farms[args.key]
    local ctx = {
        id = 'items_farm',
        title = locale('menus.items'),
        menu = 'action_farm',
        description = farm.name,
        options = {{
            title = locale('actions.item.create'),
            description = locale('actions.item.description_create'),
            icon = 'square-plus',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = SetItem,
            args = {
                farmKey = args.key,
                callback = ListItems
            }
        }}
    }
    for k, v in pairs(farm.config.items) do
        ctx.options[#ctx.options + 1] = {
            title = Items[k].label,
            icon = string.format('%s/%s.png', ImageURL, Items[k].name),
            image = string.format('%s/%s.png', ImageURL, Items[k].name),
            metadata = Utils.GetItemMetadata(Items[k]),
            description = Items[k].description,
            onSelect = ItemActionMenu,
            args = {
                itemKey = k,
                farmKey = args.key
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function SaveFarm(args)
    TriggerServerEvent("mri_Qfarm:server:SaveFarm", Farms[args.key], args.key)
    args.callback(args.key)
end

local function ActionMenu(key)
    local farm = Farms[key]
    local groupName = 'Sem grupo'
    local grade = '0'
    local groups = Utils.GetBaseGroups(true)
    if farm.group['name'] then
        groupName = groups[farm.group.name].label
    end
    if farm.group['grade'] then
        grade = farm.group['grade']
    end
    local locationText = locale('actions.farm.change_location')
    if farm.config.start.location == nil then
        locationText = locale('actions.farm.set_location')
    end
    local ctx = {
        id = 'action_farm',
        description = string.format('%s: %s, %s: %s', locale('creator.group'), groupName, locale('creator.grade'), grade),
        title = farm.name:upper(),
        menu = 'list_farms',
        options = {{
            title = locale('actions.farm.rename'),
            description = locale('actions.farm.description_rename'),
            icon = 'file-pen',
            iconAnimation = Config.IconAnimation,
            onSelect = SetFarmName,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('creator.group'),
            description = locale('creator.description_group'),
            icon = 'users',
            iconAnimation = Config.IconAnimation,
            onSelect = SetFarmGroup,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('creator.grade'),
            description = locale('creator.description_grade'),
            icon = 'list-ol',
            iconAnimation = Config.IconAnimation,
            onSelect = SetFarmGrade,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locationText,
            icon = 'location-dot',
            iconAnimation = Config.IconAnimation,
            onSelect = ChangeFarmLocation,
            description = locale('actions.farm.description_location'),
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('actions.farm.items'),
            description = locale('actions.farm.description_items'),
            icon = 'rectangle-list',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = ListItems,
            args = {
                key = key
            }
        }, {
            title = locale('actions.teleport'),
            description = locale('actions.description_teleport'),
            icon = 'location-dot',
            iconAnimation = Config.IconAnimation,
            onSelect = TeleportToFarm,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('actions.export'),
            description = locale("actions.description_export", locale("actions.farm")),
            icon = 'copy',
            iconAnimation = Config.IconAnimation,
            onSelect = ExportFarm,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('actions.save'),
            description = locale("actions.description_save"),
            icon = 'floppy-disk',
            iconAnimation = Config.IconAnimation,
            onSelect = SaveFarm,
            args = {
                key = key,
                callback = ActionMenu
            }
        }, {
            title = locale('actions.delete'),
            description = locale("actions.description_delete", locale("actions.farm")),
            icon = 'trash',
            iconAnimation = Config.IconAnimation,
            iconColor = ColorScheme.danger,
            onSelect = DeleteFarm,
            args = {
                key = key,
                callback = ListFarm,
                callbackCancel = ActionMenu
            }
        }}
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListFarm()
    local ctx = {
        id = 'list_farms',
        menu = 'menu_farm',
        title = 'Listar Farms',
        options = {}
    }
    for k, v in pairs(Farms) do
        local groupName = locale('creator.no_group')
            local groups = Utils.GetBaseGroups(true)
        if v.group['name'] then
            groupName = groups[v.group.name].label
        end
        local description = locale('menus.description_farm', groupName)
        ctx.options[#ctx.options + 1] = {
            title = v.name:upper(),
            icon = 'warehouse',
            iconAnimation = Config.IconAnimation,
            description = description,
            metadata = Utils.GetMetadataFromFarm(k),
            onSelect = function()
                ActionMenu(k)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function ManageFarms()
    Items = exports.ox_inventory:Items()
    local ctx = {
        id = 'menu_farm',
        menu = 'menu_gerencial',
        title = locale('actions.farm.title'),
        options = {{
            title = locale('actions.farm.create'),
            description = locale('actions.farm.description_create'),
            icon = 'square-plus',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = SetFarmName,
            args = {
                callback = ListFarm
            }
        },{
            title = locale('actions.farm.list'),
            description = locale('actions.farm.description_list'),
            icon = 'list-ul',
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = ListFarm
        }
    }}
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

exports['mri_Qbox']:AddManageMenu(
    {
        title = 'Farms',
        description = 'Crie ou gerencie rotas de farm do servidor.',
        icon = 'tools',
        iconAnimation = 'fade',
        arrow = true,
        onSelectFunction = ManageFarms,
    }
)
