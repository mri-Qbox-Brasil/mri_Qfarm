
lib.addCommand('managefarms', {
    help = 'Este comando gerencia os farms do servidor (Somente Admin).',
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent("mri_qfarm:Client:ManageFarms", source)
end)