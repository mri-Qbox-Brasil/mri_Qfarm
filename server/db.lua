AddEventHandler('onServerResourceStart', function(resource)
    -- if resource == GetCurrentResourceName() then
    --     MySQL.Sync.execute([[
    --         CREATE TABLE IF NOT EXISTS `mri_farms` (
    --             `farm_id` int(11) NOT NULL AUTO_INCREMENT,
    --             `farm_name` varchar(50),
    --             `farming_cfg` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin CHECK (json_valid(`crafting`)),
    --             `blipdata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin CHECK (json_valid(`blipdata`)),
    --             `jobs` longtext,
    --             PRIMARY KEY (`craft_id`)
    --         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    --     ]])
    --     MySQL.Sync.execute([[
    --         CREATE TABLE IF NOT EXISTS `mri_farm_items` (
    --             `farm_id` int(11) NOT NULL AUTO_INCREMENT,
    --             `item` varchar(50),
    --             `item_label` varchar(50),
    --             `recipe` longtext,
    --             `time` int(11),
    --             `amount` int(11)
    --         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    --     ]])
    -- end
end)
