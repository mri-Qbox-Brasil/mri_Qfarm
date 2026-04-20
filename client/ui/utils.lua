local Utils = lib.require("shared/utils")

---@class UiUtils
local UiUtils = {}

--- Exibe uma caixa de diálogo de confirmação com o conteúdo fornecido.
-- @param content Texto a ser exibido na caixa de diálogo.
-- @return Retorna a ação selecionada pelo usuário ("confirm" ou "cancel").
function UiUtils.confirmationDialog(content, title)
    return lib.alertDialog(
        {
            header = title or locale("dialog.confirmation"),
            content = content,
            centered = true,
            cancel = true,
            labels = {
                cancel = locale("actions.cancel"),
                confirm = locale("actions.confirm")
            }
        }
    )
end

function UiUtils.textInputDialog(title, label, description, defaultValue, min, max)
    return lib.inputDialog(
        title,
        {
            {
                type = "input",
                label = label,
                description = description,
                default = defaultValue or "",
                required = true,
                min = min or nil,
                max = max or nil
            }
        }
    )
end

function UiUtils.numberInputDialog(title, label, description, defaultValue, min)
    return lib.inputDialog(
        title,
        {
            {
                type = "number",
                label = label,
                description = description,
                default = defaultValue or 0,
                required = true,
                min = min or 0
            }
        }
    )
end

function UiUtils.itemSelectInput(title, description, defaultValue)
    return lib.inputDialog(
        title,
        {
            {
                type = "select",
                label = locale("items.name"),
                description = description,
                default = defaultValue or "",
                options = Utils.getBaseItems(),
                required = true,
                searchable = true,
                clearable = true
            }
        }
    )
end

function UiUtils.farmSelectInput(title, description, defaultValue)
    return lib.inputDialog(
        title,
        {
            {
                type = "select",
                label = locale("actions.farm"),
                description = description,
                default = defaultValue or "",
                options = Utils.getFarms(),
                required = true,
                searchable = true,
                clearable = true
            }
        }
    )
end

return UiUtils
