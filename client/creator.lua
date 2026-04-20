local Menus = lib.require("client/modules/creator/menus")

local function manageFarms()
    Menus.manageFarms()
end

if GetResourceState("mri_Qmenu") == "started" then
    exports["mri_Qmenu"]:AddManageMenu(
        {
            title = locale("creator.title"),
            description = locale("creator.description_title"),
            icon = "toolbox",
            iconAnimation = "fade",
            onSelectFunction = manageFarms,
            category = "manage"
        }
    )
else
    lib.callback.register(
        "mri_Qfarm:manageFarmsMenu",
        function()
            manageFarms()
            return true
        end
    )
end
