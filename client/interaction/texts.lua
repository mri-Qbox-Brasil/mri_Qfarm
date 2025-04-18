local function showHelpNotification(text, delay, type, playSound)
    local type = type or 0
    local delay = delay or 5000
    local playSound = playSound or false
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandDisplayHelp(type, false, playSound, delay)
end

return {
    showHelpNotification = showHelpNotification
}
