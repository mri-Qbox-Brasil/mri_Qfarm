local Menus = lib.require("client/modules/creator/menus")

local Creator = {}

local function manageFarms()
    Menus.manageFarms()
end

local function addMenu(exportName)
    exports[exportName]:AddManageMenu(
        {
            title = locale("creator.title"),
            description = locale("creator.description_title"),
            icon = "toolbox",
            iconAnimation = "fade",
            onSelectFunction = manageFarms,
            category = "manage"
        }
    )
end

function Creator.init()
    if GetResourceState("mri_Qmenu") == "started" then
        addMenu("mri_Qmenu")
    elseif GetResourceState("mri_Qbox") == "started" then
        addMenu("mri_Qbox")
    else
        lib.callback.register(
            "mri_Qfarm:manageFarmsMenu",
            function()
                manageFarms()
                return true
            end
        )
    end
end

return Creator
